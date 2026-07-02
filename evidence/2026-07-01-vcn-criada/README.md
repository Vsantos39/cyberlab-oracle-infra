# Evidência — Criação da VCN (2026-07-01)

**Data:** 2026-07-01
**Executado por:** Viviane Santos
**Refs:** ADR-001, RUNBOOK-001

---

## Contexto

Primeira sessão de provisionamento de infraestrutura OCI do CyberLab 2030.
Resultado parcial: VCN criada com sucesso, instância Ampere pendente por falta de capacidade no AD-1.

---

## Artefatos desta sessão

| Arquivo | Descrição |
|---|---|
| `01-conta-criada.png` | E-mail de confirmação de criação da conta Oracle Cloud |
| `02-resource-explorer.png` | Console OCI mostrando tenancy `vsantostech23` ativa na região Brazil East (São Paulo) |
| `03-vcn-wizard-config.png` | Configuração da VCN no wizard: nome `cyberlab-vcn`, CIDR 10.0.0.0/16 |
| `04-vcn-subnets.png` | Subnets configuradas: pública 10.0.0.0/24 e privada 10.0.1.0/24 |
| `05-vcn-gateways.png` | Gateways criados: Internet Gateway, NAT Gateway e Service Gateway |
| `06-vcn-security-lists.png` | Security Lists e Route Tables separadas por subnet |
| `07-instance-shape.png` | Shape VM.Standard.A1.Flex com badge Always Free-eligible, 2 OCPUs / 12GB |
| `08-instance-networking.png` | Networking com IP público ativo na public subnet-cyberlab-vcn |
| `09-instance-review.png` | Tela de revisão final antes de criar a instância |
| `10-out-of-capacity.png` | Erro "Out of host capacity" no AD-1 (sa-saopaulo-1) |

---

## Resultado

| Recurso | Status |
|---|---|
| Conta Oracle Cloud | ✅ Criada |
| VCN cyberlab-vcn | ✅ Criada |
| public subnet-cyberlab-vcn | ✅ Criada |
| private subnet-cyberlab-vcn | ✅ Criada |
| Internet Gateway | ✅ Ativo |
| NAT Gateway | ✅ Ativo |
| Service Gateway | ✅ Ativo |
| Instância Cyberlab-wazuh-manager | ⏳ Pendente — out of host capacity AD-1 |

---

## Observações

- São Paulo possui apenas 1 availability domain — não há fallback de AD
- O toggle de IP público trava quando a VCN é criada inline na tela de instância — solução: criar a VCN pelo wizard dedicado primeiro
- O OCI CLI versão 3.73.1 retorna `CannotParseRequest` ao tentar `oci compute instance launch` em conta nova — operações de compute ficaram bloqueadas por restrição de IAM em propagação
- IMAGE OCID correto obtido via API direta (não estava disponível na documentação pública indexada): `ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaykprsp6bp43gbjn5uemsqe7a3yvh6pnw2d2lhc722actyg2inl6a`
- IMAGE OCID correto obtido via API direta (não estava disponível na documentação pública indexada): `ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaykprsp6bp43gbjn5uemsqe7a3yvh6pnw2d2lhc722actyg2inl6a`
