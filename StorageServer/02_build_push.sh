#!/bin/bash
set -e  # Para execução em caso de erro
# ============================================================
# Carrega variáveis do .env gerado pelo script 01
# ============================================================
if [ ! -f .env ]; then
  echo "❌ Arquivo .env não encontrado. Execute 01_setup_azure.sh primeiro."
  exit 1
fi
set -a && source .env && set +a
echo "============================================================"
echo " Build & Push — $APP_IMAGE_NAME:$APP_IMAGE_TAG"
echo " ACR: $ACR_LOGIN_SERVER"
echo "============================================================"
# ============================================================
# 1. Verificar se Docker está rodando
# ============================================================
echo ""
echo ">>> Verificando Docker..."
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker não está rodando. Inicie o Docker Desktop e tente novamente."
  exit 1
fi
echo "✅ Docker OK"
# ============================================================
# 2. Autenticar no Azure Container Registry
# ============================================================
echo ""
echo ">>> Autenticando no ACR '$ACR_NAME'..."
az acr login --name "$ACR_NAME"
echo "✅ Login ACR OK"
# ============================================================
# 3. Build da imagem Docker
# ============================================================
echo ""
echo ">>> Fazendo build da imagem..."
docker build \
  --platform linux/amd64 \
  --tag "$APP_IMAGE_NAME:$APP_IMAGE_TAG" \
  --file Dockerfile \
  .
echo "✅ Build concluído"
# ============================================================
# 4. Taguear para o ACR
# ============================================================
echo ""
echo ">>> Tagueando imagem para o ACR..."
docker tag \
  "$APP_IMAGE_NAME:$APP_IMAGE_TAG" \
  "$ACR_LOGIN_SERVER/$APP_IMAGE_NAME:$APP_IMAGE_TAG"
echo "✅ Tag aplicada: $ACR_LOGIN_SERVER/$APP_IMAGE_NAME:$APP_IMAGE_TAG"
# ============================================================
# 5. Push para o ACR
# ============================================================
echo ""
echo ">>> Enviando imagem para o ACR..."
docker push "$ACR_LOGIN_SERVER/$APP_IMAGE_NAME:$APP_IMAGE_TAG"
echo "✅ Push concluído"
# ============================================================
# 6. Confirmar que a imagem chegou no ACR
# ============================================================
echo ""
echo ">>> Verificando imagem no ACR..."
az acr repository show-tags \
  --name "$ACR_NAME" \
  --repository "$APP_IMAGE_NAME" \
  --output table
echo ""
echo "============================================================"
echo "✅ Imagem publicada com sucesso!"
echo "   $ACR_LOGIN_SERVER/$APP_IMAGE_NAME:$APP_IMAGE_TAG"
echo "============================================================"
echo ""
echo "Próximo passo: execute ./03_deploy_aci.sh"








#!/bin/bash
set -e
if [ ! -f .env ]; then
  echo "❌ Arquivo .env não encontrado. Execute 01_setup_azure.sh primeiro."
  exit 1
fi
set -a && source .env && set +a
echo ">>> Enviando código para build no ACR (sem Docker local)..."
az acr build \
  --registry "$ACR_NAME" \
  --image "$APP_IMAGE_NAME:$APP_IMAGE_TAG" \
  --platform linux/amd64 \
  --file Dockerfile \
  .
echo ""
echo "✅ Build e push concluídos diretamente no ACR!"
echo "   $ACR_LOGIN_SERVER/$APP_IMAGE_NAME:$APP_IMAGE_TAG"
echo ""
echo "Próximo passo: execute ./03_deploy_aci.sh"