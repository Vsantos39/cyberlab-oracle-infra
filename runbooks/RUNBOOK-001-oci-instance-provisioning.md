# Runbook: Provisionamento de Instância Ampere no Oracle Cloud

**Owner:** Viviane Santos | **Frequência:** Sob demanda (primeiro provisionamento e recriações)
**Criado em:** 2026-07-01 | **Última execução:** 2026-07-01
**Repositório:** cyberlab-oracle-infra
**ADR de referência:** cyberlab-core / ADR-001-platform-choice

---

## Objetivo

Provisionar uma instância Ampere ARM (VM.Standard.A1.Flex) no Oracle Cloud Free Tier para o CyberLab 2030, dentro de uma VCN já existente com topologia pública/privada. Este runbook cobre desde a criação da VCN até a instância pronta para acesso SSH.

---

## Pré-requisitos

- [ ] Conta Oracle Cloud ativa (Free Tier ou Pay As You Go)
- [ ] Home region definida — no CyberLab: `Brazil East (São Paulo) / sa-saopaulo-1`
- [ ] Acesso ao console OCI: https://cloud.oracle.com
- [ ] Par de chaves SSH disponível (`.pem` privada + `.pub` pública) ou disponibilidade para gerar um novo par
- [ ] Limite Always Free Ampere disponível: 2 OCPUs / 12GB RAM (verificar em Governance → Limits)

> **Atenção:** A home region é permanente após o cadastro. No CyberLab, a região é São Paulo com 1 único availability domain (AD-1). Não há fallback de AD em caso de falta de capacidade.

---

## Parte 1: Criação da VCN

> Se a VCN `cyberlab-vcn` já existir, pule para a Parte 2.

### Passo 1.1 — Acessar o VCN Wizard

Navegação: Menu (≡) → **Networking** → **Virtual Cloud Networks** → **Start VCN Wizard**

Selecione: **"Create VCN with Internet Connectivity"** → **Start VCN Wizard**

**Resultado esperado:** Tela de configuração da VCN

**Se falhar:** Verificar se o compartment `vsantostech23 (root)` está selecionado no seletor lateral

---

### Passo 1.2 — Configurar a VCN

Preencha os campos:

| Campo | Valor |
|---|---|
| VCN name | `cyberlab-vcn` |
| Compartment | `vsantostech23 (root)` |
| VCN IPv4 CIDR block | `10.0.0.0/16` |
| Enable IPv6 | Desligado |
| Use DNS hostnames | Ligado |
| Public subnet CIDR | `10.0.0.0/24` |
| Private subnet CIDR | `10.0.1.0/24` |

Clique em **Next** → revisar o resumo → **Create**

**Resultado esperado:** VCN criada com os seguintes recursos automáticos:
- `public subnet-cyberlab-vcn` (10.0.0.0/24) com Internet Gateway
- `private subnet-cyberlab-vcn` (10.0.1.0/24) com NAT Gateway e Service Gateway
- Route tables e Security Lists separadas por subnet

**Se falhar:** Verificar se já existe uma VCN com o mesmo nome no compartment

---

## Parte 2: Criação da Instância Ampere

### Passo 2.1 — Iniciar criação da instância

Navegação: Menu (≡) → **Compute** → **Instances** → **Create Instance**

---

### Passo 2.2 — Basic information

| Campo | Valor |
|---|---|
| Name | `Cyberlab-wazuh-manager` |
| Create in compartment | `vsantostech23 (root)` |
| Availability domain | `AD 1 — TxQC:SA-SAOPAULO-1-AD-1` |
| Capacity type | On-demand capacity |

> São Paulo possui apenas 1 availability domain. Não é possível trocar de AD em caso de falta de capacidade.

---

### Passo 2.3 — Image and shape

**Image:**
1. Clique em **Change image**
2. Aba **Platform images**
3. Selecione **Canonical Ubuntu 24.04 Minimal aarch64**
4. Build: `2026.04.30-1` (ou o mais recente disponível)
5. Clique em **Select image**

**Image OCID de referência (build 2026.04.30-1):**
```
ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaykprsp6bp43gbjn5uemsqe7a3yvh6pnw2d2lhc722actyg2inl6a
```

> Para confirmar o OCID da imagem atual, acesse a URL de listagem de imagens da API:
> `https://iaas.sa-saopaulo-1.oraclecloud.com/20160918/images?compartmentId=<TENANCY_OCID>&operatingSystem=Canonical+Ubuntu&operatingSystemVersion=24.04+Minimal+aarch64&shape=VM.Standard.A1.Flex`

**Shape:**
1. Clique em **Change shape**
2. Aba **Ampere**
3. Selecione `VM.Standard.A1.Flex` — confirme que aparece o badge **"Always Free-eligible"**
4. Configure os sliders:

| Recurso | Valor |
|---|---|
| Number of OCPUs | `2` |
| Amount of memory (GB) | `12` |

> Estes são os limites máximos do Always Free a partir de mid-2026. Não ultrapasse esses valores para evitar cobrança.

**Resultado esperado:** Shape build exibe "Virtual machine, 2 core OCPU, 12 GB memory, 2 Gbps network bandwidth"

---

### Passo 2.4 — Security (seção 2)

| Campo | Valor |
|---|---|
| Shielded instance | Desligado |
| Security attributes | Nenhum |

Deixe os padrões sem alteração.

---

### Passo 2.5 — Networking (seção 3)

**Primary network:**
- Selecione: **"Select existing virtual cloud network"**
- Virtual cloud network: `cyberlab-vcn`

**Subnet:**
- Selecione: **"Select existing subnet"**
- Subnet: `public subnet-cyberlab-vcn`

**Public IPv4 address assignment:**
- Toggle: **Ligado** (Automatically assign public IPv4 address)

> **Bug conhecido:** Se você criar a VCN e a instância no mesmo fluxo (usando "Create new virtual cloud network"), o toggle de IP público fica bloqueado porque a subnet ainda não existe de verdade no sistema. Solução: criar a VCN pelo wizard dedicado primeiro, depois criar a instância selecionando a VCN existente.

**IPv6:** Deixe desligado.

---

### Passo 2.6 — SSH keys (ainda na seção 3)

- Selecione: **"Generate a key pair for me"**
- Clique em **Download private key** — salve o arquivo `.pem` em local seguro
- Clique em **Download public key** — salve o arquivo `.pub`

> **Crítico:** A chave privada só pode ser baixada neste momento. Não é possível recuperá-la depois. Sem ela, não há acesso SSH à instância.

Armazenar as chaves em: pasta local segura, fora de repositório público e fora de pasta sincronizada com nuvem sem criptografia.

**Formato do arquivo de chave pública** (exemplo):
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... ssh-key-2026-06-30
```

---

### Passo 2.7 — Storage (seção 4)

| Campo | Valor |
|---|---|
| Specify a custom boot volume size | Desligado (padrão: 46.6 GB) |
| Use in-transit encryption | Ligado |
| Encrypt with a key you manage | Desligado |
| Block volumes | Nenhum |

> Não ative o custom boot volume size. O padrão de 46.6 GB está dentro da cota gratuita de 200 GB total. Valores acima podem gerar cobrança.

---

### Passo 2.8 — Review e criação

Revise os campos antes de confirmar:

| Item | Valor esperado |
|---|---|
| Name | `Cyberlab-wazuh-manager` |
| Image | Canonical Ubuntu 24.04 Minimal aarch64 |
| Shape | VM.Standard.A1.Flex — **Always Free-eligible** |
| OCPUs / RAM | 2 / 12 GB |
| VCN | cyberlab-vcn |
| Subnet | public subnet-cyberlab-vcn |
| Public IPv4 | Yes |
| SSH keys | ssh-rsa AA... (chave presente) |
| Boot volume custom size | — (padrão) |

> O botão **"View estimated cost"** pode exibir ~R$10,45/mês mesmo para recursos Always Free — isso é um bug de UX da Oracle. O custo real é determinado pelo badge "Always Free-eligible" no shape e pelo boot volume dentro da cota, não por esse painel.

Clique em **Create**.

**Resultado esperado:** Instância criada com status `Provisioning`, transitando para `Running` em 2-5 minutos.

**Se der "Out of host capacity":** Ver seção de Troubleshooting abaixo.

---

## Parte 3: Configuração pós-criação

### Passo 3.1 — Anotar o IP público

Após a instância estar `Running`:
Compute → Instances → `Cyberlab-wazuh-manager` → campo **Public IP address**

Anote o IP — ele será usado para todas as conexões SSH.

---

### Passo 3.2 — Restringir acesso SSH na Security List

Navegação: Networking → Virtual Cloud Networks → `cyberlab-vcn` → `public subnet-cyberlab-vcn` → `default security list for cyberlab-vcn` → **Edit** → Ingress Rules

Altere a regra de entrada da porta 22:

| Campo | Valor atual (padrão) | Valor correto |
|---|---|---|
| Source CIDR | `0.0.0.0/0` | `<seu-ip-publico>/32` |
| Protocol | TCP | TCP |
| Destination port | 22 | 22 |

> Para descobrir seu IP público atual: https://ifconfig.me ou `curl ifconfig.me` no terminal.

**Resultado esperado:** Acesso SSH restrito ao seu IP. Qualquer outra origem recebe timeout.

---

### Passo 3.3 — Primeiro acesso SSH

No terminal local (WSL, PowerShell, ou terminal Linux):

```bash
# Ajustar permissão da chave (obrigatório no Linux/WSL)
chmod 600 /caminho/para/chave-privada.pem

# Conectar
ssh -i /caminho/para/chave-privada.pem ubuntu@<IP-PUBLICO>
```

**Resultado esperado:** Prompt `ubuntu@cyberlab-wazuh-manager:~$`

**Se falhar com "Permission denied":** Verificar se a chave `.pem` correta está sendo usada e se a permissão foi ajustada (`chmod 600`).

**Se falhar com timeout:** Verificar Security List — o IP de origem pode ter mudado.

---

## Verificação final

- [ ] Instância com status `Running` no console OCI
- [ ] IP público visível nos detalhes da instância
- [ ] Acesso SSH funcionando: `ssh -i chave.pem ubuntu@<IP>`
- [ ] Security List com porta 22 restrita ao IP pessoal
- [ ] Boot volume dentro da cota gratuita (46.6 GB padrão)
- [ ] Chave privada `.pem` salva em local seguro

---

## Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| "Out of host capacity" ao criar instância | Sem capacidade Ampere disponível no único AD de São Paulo | Tentar novamente em outro horário (madrugada no horário de Brasília costuma ter menos disputa). Não há outro AD para fallback em São Paulo |
| Toggle de IP público bloqueado na criação da instância | Bug ao criar VCN e instância no mesmo fluxo — subnet não existe de verdade ainda | Criar a VCN pelo wizard dedicado (Networking → VCN Wizard) primeiro, depois criar a instância selecionando a VCN existente |
| "Estimated cost" exibe ~R$10,45/mês | Bug de UX da Oracle — calculadora genérica não aplica desconto Always Free | Ignorar. Verificar que shape tem badge "Always Free-eligible" e boot volume está no padrão |
| OCI CLI retorna 404 para operações de compute/network | IAM de conta nova ainda propagando policies | Aguardar algumas horas. Operações de `oci iam` funcionam; operações de `oci compute` e `oci network` são afetadas temporariamente |
| "CannotParseRequest" no OCI CLI ao lançar instância | Combinação de parâmetros incompatíveis na versão 3.73.1 do CLI | Usar o console OCI para criação da instância. CLI pode ser usado para outras operações após propagação do IAM |
| SSH com "Permission denied (publickey)" | Chave privada errada ou permissão incorreta | Verificar arquivo `.pem` correto; rodar `chmod 600 chave.pem` no Linux/WSL |
| SSH com timeout | Security List bloqueando o IP | Verificar IP atual (`curl ifconfig.me`) e atualizar a regra de ingresso na Security List |

---

## Rollback

Para destruir a instância e começar do zero:

1. Compute → Instances → `Cyberlab-wazuh-manager` → **Terminate**
2. Marcar **"Permanently delete the attached boot volume"**
3. Confirmar

> A VCN pode ser mantida para reutilização. Apenas a instância precisa ser recriada.

Para destruir tudo (incluindo VCN):
1. Terminar a instância primeiro (aguardar status `Terminated`)
2. Networking → Virtual Cloud Networks → `cyberlab-vcn` → **Terminate**

---

## Histórico de execuções

| Data | Executado por | Resultado | Observações |
|---|---|---|---|
| 2026-07-01 | Viviane Santos | Parcial (VCN criada ✅, instância pendente ⏳) | Out of host capacity no AD-1 de São Paulo. Bug de toggle de IP público contornado criando VCN pelo wizard dedicado primeiro. Restrições de IAM em conta nova impediram uso do OCI CLI para criação via script de retry. IMAGE OCID correto obtido via API direta: `ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaykprsp6bp43gbjn5uemsqe7a3yvh6pnw2d2lhc722actyg2inl6a` |
