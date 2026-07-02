#!/bin/bash
# =============================================================================
# CyberLab 2030 — create-instance.sh
# Script de retry para provisionamento de instância Ampere no OCI
#
# Uso: bash create-instance.sh
# Requisitos: OCI CLI configurado (Cloud Shell já vem configurado)
# Repositório: cyberlab-oracle-infra/scripts/
# Refs: ADR-001, RUNBOOK-001
# =============================================================================

COMPARTMENT_ID="ocid1.tenancy.oc1..aaaaaaaaaz4xxqbtjldjmtjfooxjxxedk5yf4cmfs3rgfy7aztrc4j314yq"
SUBNET_ID="ocid1.subnet.oc1.sa-saopaulo-1.aaaaaaaab3m5yrokwjxgnx6kugvtuuggt54lteannwu6oraksevlmiaudmwq"
IMAGE_ID="ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaykprsp6bp43gbjn5uemsqe7a3yvh6pnw2d2lhc722actyg2inl6a"
AVAILABILITY_DOMAIN="TxQC:SA-SAOPAULO-1-AD-1"
SHAPE="VM.Standard.A1.Flex"
INSTANCE_NAME="Cyberlab-wazuh-manager"
SSH_KEY_FILE="$HOME/.ssh/id_rsa.pub"

# =============================================================================
# Validações
# =============================================================================

if [ ! -f "$SSH_KEY_FILE" ]; then
  echo "Erro: chave pública SSH não encontrada em $SSH_KEY_FILE"
  echo "Execute primeiro: echo 'sua-chave-publica' > ~/.ssh/id_rsa.pub"
  exit 1
fi

echo "============================================="
echo " CyberLab Instance Creator"
echo "============================================="
echo " Shape:    $SHAPE"
echo " OCPUs:    1 | RAM: 6GB"
echo " Image:    Canonical Ubuntu 24.04 aarch64"
echo " Subnet:   public subnet-cyberlab-vcn"
echo " AD:       $AVAILABILITY_DOMAIN"
echo "============================================="
echo " Tentando a cada 60 segundos... Ctrl+C para parar."
echo ""

ATTEMPT=1

while true; do
  echo "[$(date '+%H:%M:%S')] Tentativa #$ATTEMPT..."

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
    echo "[$(date '+%H:%M:%S')] Sem capacidade no AD-1. Aguardando 60s..."
    sleep 60

  elif echo "$RESULT" | grep -q "lifecycle-state"; then
    echo ""
    echo "============================================="
    echo " INSTANCIA CRIADA COM SUCESSO!"
    echo "============================================="
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
" 2>/dev/null || echo "$RESULT"
    break

  elif echo "$RESULT" | grep -q "NotAuthorizedOrNotFound"; then
    echo "[$(date '+%H:%M:%S')] Erro de permissao (IAM ainda propagando)."
    echo "Aguarde algumas horas e tente novamente."
    echo "Detalhes: $RESULT"
    break

  else
    echo "[$(date '+%H:%M:%S')] Resposta inesperada:"
    echo "$RESULT"
    echo ""
    echo "Se o erro for 'CannotParseRequest', use o console OCI para criar a instancia."
    echo "Consulte: cyberlab-oracle-infra/runbooks/RUNBOOK-001-oci-instance-provisioning.md"
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
done
