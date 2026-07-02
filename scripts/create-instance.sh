#!/bin/bash
# =============================================================================
# CyberLab 2030 — create-instance.sh (v2)
# Script de retry para provisionamento de instância Ampere no OCI
#
# Uso:
#   bash create-instance.sh                 # roda em primeiro plano
#   nohup bash create-instance.sh &          # roda em background, sobrevive ao fechar o terminal
#   tail -f create-instance.log              # acompanha o log em outra aba
#
# Requisitos: OCI CLI configurado (Cloud Shell já vem configurado)
# Repositório: cyberlab-oracle-infra/scripts/
# Refs: ADR-001, RUNBOOK-001
#
# v2 — mudanças após investigação de causa raiz (ver RUNBOOK-001):
#   - CannotParseRequest confirmado como ruído/falso positivo da CLI 3.73.1,
#     não é causa de bloqueio real. Agora é tratado como retryable, com
#     contador próprio, em vez de parar o script.
#   - Log persistente em arquivo (create-instance.log), com timestamp.
#   - Contadores de estatística por tipo de resultado, exibidos ao final
#     ou a cada 10 tentativas.
# =============================================================================
COMPARTMENT_ID="ocid1.tenancy.oc1..aaaaaaaaaz4xxqbtjldjmtjfooxjxxedk5yf4cmfs3rgfy7aztrc4j314yq"
SUBNET_ID="ocid1.subnet.oc1.sa-saopaulo-1.aaaaaaaab3m5yrokwjxgnx6kugvtuuggt54lteannwu6oraksevlmiaudmwq"
IMAGE_ID="ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaykprsp6bp43gbjn5uemsqe7a3yvh6pnw2d2lhc722actyg2inl6a"
AVAILABILITY_DOMAIN="TxQC:SA-SAOPAULO-1-AD-1"
SHAPE="VM.Standard.A1.Flex"
INSTANCE_NAME="Cyberlab-wazuh-manager"
SSH_KEY_FILE="$HOME/.ssh/id_rsa.pub"
LOG_FILE="create-instance.log"

RETRY_INTERVAL_SECONDS=60
CANNOTPARSE_MAX_CONSECUTIVE=10   # se der 10x seguidas, algo mudou de verdade — para e avisa

# =============================================================================
# Setup
# =============================================================================
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [ ! -f "$SSH_KEY_FILE" ]; then
  log "Erro: chave pública SSH não encontrada em $SSH_KEY_FILE"
  log "Execute primeiro: ssh-keygen -t rsa -f ~/.ssh/id_rsa -N ''"
  exit 1
fi

log "============================================="
log " CyberLab Instance Creator v2"
log "============================================="
log " Shape:    $SHAPE"
log " OCPUs:    1 | RAM: 6GB"
log " Image:    Canonical Ubuntu 24.04 aarch64"
log " Subnet:   public subnet-cyberlab-vcn"
log " AD:       $AVAILABILITY_DOMAIN"
log " Log file: $LOG_FILE"
log "============================================="
log " Tentando a cada ${RETRY_INTERVAL_SECONDS}s... Ctrl+C para parar (ou 'kill' se em background)."
log ""

ATTEMPT=1
CAPACITY_COUNT=0
PARSE_ERROR_COUNT=0
PARSE_ERROR_CONSECUTIVE=0
UNEXPECTED_COUNT=0
START_TIME=$(date +%s)

print_stats() {
  local elapsed=$(( $(date +%s) - START_TIME ))
  local hours=$((elapsed / 3600))
  local minutes=$(((elapsed % 3600) / 60))
  log "--- Estatísticas (tempo decorrido: ${hours}h${minutes}m) ---"
  log "    Out of capacity:     $CAPACITY_COUNT"
  log "    CannotParseRequest:  $PARSE_ERROR_COUNT"
  log "    Inesperado:          $UNEXPECTED_COUNT"
  log "    Total de tentativas: $((ATTEMPT - 1))"
}

while true; do
  log "Tentativa #$ATTEMPT..."
  RESULT=$(oci compute instance launch \
    --compartment-id "$COMPARTMENT_ID" \
    --availability-domain "$AVAILABILITY_DOMAIN" \
    --subnet-id "$SUBNET_ID" \
    --image-id "$IMAGE_ID" \
    --shape "$SHAPE" \
    --shape-config '{"ocpus": 1.0, "memoryInGBs": 6.0}' \
    --display-name "$INSTANCE_NAME" \
    --ssh-authorized-keys-file "$SSH_KEY_FILE" \
    --assign-public-ip true \
    2>&1)

  if echo "$RESULT" | grep -q "Out of host capacity"; then
    CAPACITY_COUNT=$((CAPACITY_COUNT + 1))
    PARSE_ERROR_CONSECUTIVE=0
    log "Sem capacidade no AD-1. Aguardando ${RETRY_INTERVAL_SECONDS}s..."

  elif echo "$RESULT" | grep -q "lifecycle-state"; then
    log ""
    log "============================================="
    log " INSTÂNCIA CRIADA COM SUCESSO!"
    log "============================================="
    echo "$RESULT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
inst = data.get('data', {})
print(' ID:        ', inst.get('id',''))
print(' Status:    ', inst.get('lifecycle-state',''))
print(' Shape:     ', inst.get('shape',''))
print(' AD:        ', inst.get('availability-domain',''))
print('')
print(' Aguarde o status RUNNING e pegue o IP publico no console OCI.')
" | tee -a "$LOG_FILE"
    print_stats
    break

  elif echo "$RESULT" | grep -q "CannotParseRequest"; then
    # Confirmado como falso positivo/ruído da CLI — não é bloqueio real.
    # Retry normalmente, mas monitora ocorrências consecutivas.
    PARSE_ERROR_COUNT=$((PARSE_ERROR_COUNT + 1))
    PARSE_ERROR_CONSECUTIVE=$((PARSE_ERROR_CONSECUTIVE + 1))
    log "CannotParseRequest (ruído conhecido da CLI, ver RUNBOOK-001). Ocorrência consecutiva #$PARSE_ERROR_CONSECUTIVE. Retentando..."
    if [ "$PARSE_ERROR_CONSECUTIVE" -ge "$CANNOTPARSE_MAX_CONSECUTIVE" ]; then
      log "AVISO: $CANNOTPARSE_MAX_CONSECUTIVE ocorrências consecutivas de CannotParseRequest."
      log "Isso foge do padrão esperado (era pontual). Pare e investigue antes de continuar."
      print_stats
      break
    fi

  elif echo "$RESULT" | grep -q "NotAuthorizedOrNotFound"; then
    log "Erro de permissão reportado pela CLI (NotAuthorizedOrNotFound)."
    log "ATENÇÃO: já confirmamos por teste que IAM/policy/grupo estão corretos (ver RUNBOOK-001)."
    log "Esse texto pode estar mascarando outro erro. Detalhes:"
    log "$RESULT"
    print_stats
    break

  else
    UNEXPECTED_COUNT=$((UNEXPECTED_COUNT + 1))
    PARSE_ERROR_CONSECUTIVE=0
    log "Resposta inesperada:"
    log "$RESULT"
    log ""
    log "Consulte: cyberlab-oracle-infra/runbooks/RUNBOOK-001-oci-instance-provisioning.md"
    print_stats
    break
  fi

  # Estatísticas a cada 10 tentativas, pra acompanhar sem poluir o log
  if [ $((ATTEMPT % 10)) -eq 0 ]; then
    print_stats
  fi

  ATTEMPT=$((ATTEMPT + 1))
  sleep "$RETRY_INTERVAL_SECONDS"
done
