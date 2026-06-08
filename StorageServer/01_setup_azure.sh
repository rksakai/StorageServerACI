#!/bin/bash
set -e  # Para execução em caso de erro

# ============================================================
# CONFIGURAÇÕES — edite antes de executar
# ============================================================
RESOURCE_GROUP="rg-upload-app"
LOCATION="brazilsouth"
STORAGE_ACCOUNT="stgupload$(openssl rand -hex 4)"   # nome único, max 24 chars
STORAGE_CONTAINER="uploads"
ACR_NAME="acrupload$(openssl rand -hex 4)"           # nome único
ACI_NAME="aci-upload-app"
ACI_DNS_LABEL="upload-app-$(openssl rand -hex 4)"   # nome único
APP_IMAGE_NAME="storage-uploader"
APP_IMAGE_TAG="latest"


# ============================================================
# Funções auxiliares
# ============================================================
log()  { echo ""; echo ">>> $1"; }
ok()   { echo "✅ $1"; }
fail() { echo "❌ $1"; exit 1; }


# ============================================================
# 0. Verificar dependências
# ============================================================
log "Verificando dependências..."
command -v az      > /dev/null 2>&1 || fail "Azure CLI não encontrado. Instale em: https://aka.ms/installazurecli"
command -v openssl > /dev/null 2>&1 || fail "openssl não encontrado."

# Verifica se está logado no Azure
ACCOUNT=$(az account show --query name -o tsv 2>/dev/null) || \
  fail "Não autenticado no Azure. Execute: az login"
ok "Azure CLI OK — Conta: $ACCOUNT"


# ============================================================
# 1. Selecionar Subscription (opcional — descomente se necessário)
# ============================================================
# az account set --subscription "<subscription-id-ou-nome>"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
ok "Subscription: $SUBSCRIPTION_ID"


# ============================================================
# 2. Criar Resource Group
# ============================================================
log "Criando Resource Group '$RESOURCE_GROUP'..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none
ok "Resource Group criado: $RESOURCE_GROUP ($LOCATION)"


# ============================================================
# 3. Criar Storage Account
# ============================================================
log "Criando Storage Account '$STORAGE_ACCOUNT'..."
# Valida disponibilidade do nome
AVAILABLE=$(az storage account check-name \
  --name "$STORAGE_ACCOUNT" \
  --query nameAvailable -o tsv)
if [ "$AVAILABLE" != "true" ]; then
  fail "Nome '$STORAGE_ACCOUNT' indisponível. Tente novamente (novo hash será gerado)."
fi
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Hot \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 \
  --https-only true \
  --output none
ok "Storage Account criado: $STORAGE_ACCOUNT"


# ============================================================
# 4. Obter chave do Storage Account
# ============================================================
log "Obtendo chave do Storage Account..."
STORAGE_KEY=$(az storage account keys list \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query "[0].value" -o tsv)
[ -z "$STORAGE_KEY" ] && fail "Não foi possível obter a chave do Storage Account."
ok "Chave obtida com sucesso"


# ============================================================
# 5. Criar Blob Container
# ============================================================
log "Criando Blob Container '$STORAGE_CONTAINER'..."
az storage container create \
  --name "$STORAGE_CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --public-access off \
  --output none
ok "Blob Container criado: $STORAGE_CONTAINER"


# ============================================================
# 6. Criar Azure Container Registry (ACR)
# ============================================================
log "Criando Azure Container Registry '$ACR_NAME'..."
# Valida disponibilidade do nome
ACR_AVAILABLE=$(az acr check-name \
  --name "$ACR_NAME" \
  --query nameAvailable -o tsv)
if [ "$ACR_AVAILABLE" != "true" ]; then
  fail "Nome do ACR '$ACR_NAME' indisponível. Tente novamente."
fi
az acr create \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Basic \
  --admin-enabled true \
  --output none
ok "ACR criado: $ACR_NAME"


# ============================================================
# 7. Obter credenciais do ACR
# ============================================================
log "Obtendo credenciais do ACR..."
ACR_LOGIN_SERVER=$(az acr show \
  --name "$ACR_NAME" \
  --query loginServer -o tsv)
ACR_USERNAME=$(az acr credential show \
  --name "$ACR_NAME" \
  --query username -o tsv)
ACR_PASSWORD=$(az acr credential show \
  --name "$ACR_NAME" \
  --query "passwords[0].value" -o tsv)
[ -z "$ACR_LOGIN_SERVER" ] && fail "Não foi possível obter o login server do ACR."
ok "Credenciais ACR obtidas: $ACR_LOGIN_SERVER"


# ============================================================
# 8. Salvar variáveis em .env
# ============================================================
log "Salvando variáveis em .env..."
cat > .env > $1"; }
ok()   { echo "✅ $1"; }
fail() { echo "❌ $1"; exit 1; }