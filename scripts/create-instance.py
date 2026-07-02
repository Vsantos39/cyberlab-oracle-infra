#!/usr/bin/env python3
"""
=============================================================================
CyberLab 2030 — create-instance.py (v2)
Script de retry para provisionamento de instância Ampere no OCI (via CLI)

Uso:
    python3 create-instance.py                  # roda em primeiro plano
    nohup python3 create-instance.py &           # roda em background
    tail -f create-instance.log                  # acompanha em outra aba

Requisitos: OCI CLI configurado (Cloud Shell já vem configurado)
Repositório: cyberlab-oracle-infra/scripts/
Refs: ADR-001, RUNBOOK-001

v2 — mudanças após investigação de causa raiz (ver RUNBOOK-001):
- CannotParseRequest confirmado como ruído/falso positivo da CLI 3.73.1
  nesta tenancy — não é causa de bloqueio real (validado via Console,
  que retornou "Out of host capacity" com o mesmo payload). Agora é
  tratado como retryable, com contador de ocorrências consecutivas.
- Estatísticas por tipo de resultado, logadas periodicamente.
- NotAuthorizedOrNotFound permanece fatal (já confirmamos que IAM está
  correto, então se aparecer de novo é sinal de algo nesse deploy
  específico, exige investigação manual).
"""

import subprocess
import json
import time
import logging
import sys
from datetime import datetime

# =============================================================================
# Configuração — ajuste conforme seu ambiente
# =============================================================================
COMPARTMENT_ID = "ocid1.tenancy.oc1..aaaaaaaaaz4xxqbtjldjmtjfooxjxxedk5yf4cmfs3rgfy7aztrc4j314yq"
SUBNET_ID = "ocid1.subnet.oc1.sa-saopaulo-1.aaaaaaaab3m5yrokwjxgnx6kugvtuuggt54lteannwu6oraksevlmiaudmwq"
IMAGE_ID = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaykprsp6bp43gbjn5uemsqe7a3yvh6pnw2d2lhc722actyg2inl6a"
AVAILABILITY_DOMAIN = "TxQC:SA-SAOPAULO-1-AD-1"
SHAPE = "VM.Standard.A1.Flex"
INSTANCE_NAME = "Cyberlab-wazuh-manager"
SSH_KEY_FILE = "~/.ssh/id_rsa.pub"

RETRY_INTERVAL_SECONDS = 60
CANNOTPARSE_MAX_CONSECUTIVE = 10   # 10x seguidas foge do padrão esperado — para e avisa
STATS_EVERY_N_ATTEMPTS = 10
LOG_FILE = "create-instance.log"

# =============================================================================
# Setup de logging (console + arquivo)
# =============================================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("cyberlab")


def build_command() -> list:
    return [
        "oci", "compute", "instance", "launch",
        "--compartment-id", COMPARTMENT_ID,
        "--availability-domain", AVAILABILITY_DOMAIN,
        "--subnet-id", SUBNET_ID,
        "--image-id", IMAGE_ID,
        "--shape", SHAPE,
        "--shape-config", '{"ocpus": 1.0, "memoryInGBs": 6.0}',
        "--display-name", INSTANCE_NAME,
        "--ssh-authorized-keys-file", SSH_KEY_FILE,
        "--assign-public-ip", "true",
    ]


def run_attempt() -> tuple[str, str]:
    """Executa o comando oci e retorna (status, raw_output)."""
    result = subprocess.run(build_command(), capture_output=True, text=True)
    output = (result.stdout or "") + (result.stderr or "")

    if "Out of host capacity" in output:
        return "capacity", output
    if "lifecycle-state" in output and result.returncode == 0:
        return "success", output
    if "CannotParseRequest" in output:
        return "parse_error", output
    if "NotAuthorizedOrNotFound" in output:
        return "iam_error", output
    return "unexpected", output


def print_success(raw_output: str):
    try:
        data = json.loads(raw_output)
        inst = data.get("data", {})
        log.info("=" * 45)
        log.info(" INSTÂNCIA CRIADA COM SUCESSO!")
        log.info("=" * 45)
        log.info(f" ID:      {inst.get('id', '')}")
        log.info(f" Status:  {inst.get('lifecycle-state', '')}")
        log.info(f" Shape:   {inst.get('shape', '')}")
        log.info(f" AD:      {inst.get('availability-domain', '')}")
        log.info("")
        log.info(" Aguarde o status RUNNING e pegue o IP público no console OCI.")
    except (json.JSONDecodeError, AttributeError):
        log.info("Instância criada, mas não foi possível parsear o JSON de resposta:")
        log.info(raw_output)


class Stats:
    def __init__(self):
        self.capacity = 0
        self.parse_error = 0
        self.unexpected = 0
        self.attempts = 0
        self.start_time = time.time()

    def print(self):
        elapsed = int(time.time() - self.start_time)
        hours, minutes = elapsed // 3600, (elapsed % 3600) // 60
        log.info(f"--- Estatísticas (tempo decorrido: {hours}h{minutes}m) ---")
        log.info(f"    Out of capacity:     {self.capacity}")
        log.info(f"    CannotParseRequest:  {self.parse_error}")
        log.info(f"    Inesperado:          {self.unexpected}")
        log.info(f"    Total de tentativas: {self.attempts}")


def main():
    log.info("=" * 45)
    log.info(" CyberLab Instance Creator v2 (Python)")
    log.info("=" * 45)
    log.info(f" Shape:    {SHAPE}")
    log.info(f" OCPUs:    1 | RAM: 6GB")
    log.info(f" AD:       {AVAILABILITY_DOMAIN}")
    log.info(f" Log file: {LOG_FILE}")
    log.info("=" * 45)
    log.info(f" Tentando a cada {RETRY_INTERVAL_SECONDS}s... Ctrl+C para parar.\n")

    stats = Stats()
    consecutive_parse_errors = 0

    try:
        while True:
            stats.attempts += 1
            log.info(f"Tentativa #{stats.attempts}...")
            status, output = run_attempt()

            if status == "capacity":
                stats.capacity += 1
                consecutive_parse_errors = 0
                log.warning("Sem capacidade no AD-1. Aguardando...")

            elif status == "success":
                print_success(output)
                stats.print()
                break

            elif status == "parse_error":
                # Confirmado como falso positivo da CLI nesta tenancy — não bloqueia de verdade.
                stats.parse_error += 1
                consecutive_parse_errors += 1
                log.warning(
                    f"CannotParseRequest (ruído conhecido da CLI, ver RUNBOOK-001). "
                    f"Ocorrência consecutiva #{consecutive_parse_errors}. Retentando..."
                )
                if consecutive_parse_errors >= CANNOTPARSE_MAX_CONSECUTIVE:
                    log.error(
                        f"AVISO: {CANNOTPARSE_MAX_CONSECUTIVE} ocorrências consecutivas de "
                        "CannotParseRequest — foge do padrão esperado (era pontual). Parando "
                        "para investigação manual."
                    )
                    stats.print()
                    break

            elif status == "iam_error":
                log.error(
                    "Erro de permissão reportado pela CLI (NotAuthorizedOrNotFound). "
                    "Já confirmamos que IAM/policy/grupo estão corretos (ver RUNBOOK-001) — "
                    "isso pode estar mascarando outra falha real. Detalhes:"
                )
                log.error(output)
                stats.print()
                break

            else:  # unexpected
                stats.unexpected += 1
                consecutive_parse_errors = 0
                log.error("Resposta inesperada da CLI:")
                log.error(output)
                log.error(
                    "Consulte: cyberlab-oracle-infra/runbooks/RUNBOOK-001-oci-instance-provisioning.md"
                )
                stats.print()
                break

            if stats.attempts % STATS_EVERY_N_ATTEMPTS == 0:
                stats.print()

            time.sleep(RETRY_INTERVAL_SECONDS)

    except KeyboardInterrupt:
        log.info("\nInterrompido pelo usuário (Ctrl+C).")
        stats.print()


if __name__ == "__main__":
    main()
