# cyberlab-oracle-infra

Repositório de infraestrutura Oracle Cloud para o [CyberLab 2030](https://github.com/Vsantos39/cyberlab-core).

Contém runbooks, scripts e evidências relacionados ao provisionamento e operação da infraestrutura OCI que suporta os labs de segurança do projeto.

---

## Governança

Este repositório segue os padrões definidos em [cyberlab-core](https://github.com/Vsantos39/cyberlab-core):
- Nomenclatura de arquivos: `TIPO-NNN-descricao.md`
- Estrutura de runbooks: conforme template em `cyberlab-core/docs/templates/`
- Decisões de plataforma: documentadas em `cyberlab-core/docs/architecture/ADR-001-platform-choice.md`

---

## Infraestrutura atual

| Recurso | Nome | Status |
|---|---|---|
| Tenancy | vsantostech23 | ✅ Ativo |
| Home region | Brazil East (São Paulo) — sa-saopaulo-1 | ✅ Ativo |
| VCN | cyberlab-vcn (10.0.0.0/16) | ✅ Criada |
| Subnet pública | public subnet-cyberlab-vcn (10.0.0.0/24) | ✅ Criada |
| Subnet privada | private subnet-cyberlab-vcn (10.0.1.0/24) | ✅ Criada |
| Internet Gateway | Internet gateway-cyberlab-vcn | ✅ Ativo |
| NAT Gateway | NAT gateway-cyberlab-vcn | ✅ Ativo |
| Service Gateway | Service gateway-cyberlab-vcn | ✅ Ativo |
| Instância Ampere | Cyberlab-wazuh-manager | ⏳ Pendente (out of capacity) |

---

## Estrutura do repositório

```
cyberlab-oracle-infra/
├── README.md                          # este arquivo
├── runbooks/
│   ├── RUNBOOK-001-oci-instance-provisioning.md   # provisionamento da instância Ampere
│   └── RUNBOOK-002-wazuh-install.md               # (futuro) instalação do Wazuh
├── scripts/
│   └── create-instance.sh            # script de retry via OCI CLI (Cloud Shell)
└── evidence/
    └── 2026-07-01-vcn-criada/        # prints e logs da sessão de provisionamento
```

---

## Runbooks disponíveis

| ID | Título | Status |
|---|---|---|
| RUNBOOK-001 | Provisionamento de instância Ampere no OCI | ✅ Documentado |
| RUNBOOK-002 | Instalação e configuração do Wazuh | ⏳ Pendente |

---

## Referências

- [ADR-001 — Decisão de plataforma](https://github.com/Vsantos39/cyberlab-core/blob/main/docs/architecture/ADR-001-platform-choice.md)
- [Console Oracle Cloud](https://cloud.oracle.com)
- [Documentação OCI CLI](https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/)
