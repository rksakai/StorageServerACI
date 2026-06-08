# ============================================================
# 0. Carregar variáveis do .env
# ============================================================
if [ ! -f .env ]; then
  fail "Arquivo .env não encontrado. Execute 01_setup_azure.sh primeiro."
fi
set -a && source .env && set +a
log "Variáveis carregadas do .env"


# ============================================================
# 1. Verificar se a imagem existe no ACR
# ============================================================
log "Verificando imagem no ACR..."
IMAGE_EXISTS=$(az acr repository show \
  --name "$ACR_NAME" \
  --image "$APP_IMAGE_NAME:$APP_IMAGE_TAG" \
  --query name -o tsv 2>/dev/null || echo "")
if [ -z "$IMAGE_EXISTS" ]; then
  fail "Imagem '$APP_IMAGE_NAME:$APP_IMAGE_TAG' não encontrada no ACR '$ACR_NAME'. Execute 02_build_push.sh primeiro."
fi
ok "Imagem encontrada: $ACR_LOGIN_SERVER/$APP_IMAGE_NAME:$APP_IMAGE_TAG"


# ============================================================
# 2. Remover ACI anterior (se existir)
# ============================================================
log "Verificando se já existe um ACI com o nome '$ACI_NAME'..."
ACI_EXISTS=$(az container show \
  --name "$ACI_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query name -o tsv 2>/dev/null || echo "")
if [ -n "$ACI_EXISTS" ]; then
  echo "⚠️  ACI '$ACI_NAME' já existe. Removendo para redeploy..."
  az container delete \
    --name "$ACI_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --yes \
    --output none
  ok "ACI anterior removido"
fi


# ============================================================
# 3. Verificar disponibilidade do DNS Label
# ============================================================
log "Verificando DNS label '$ACI_DNS_LABEL.$LOCATION.azurecontainer.io'..."
# Nota: não há CLI direto para checar DNS de ACI, mas o deploy falhará
# se o label estiver em uso. Um hash aleatório já garante unicidade na
# maioria dos casos.
ok "DNS label configurado: $ACI_DNS_LABEL"


# ============================================================
# 4. Criar Azure Container Instance
# ============================================================
log "Criando Azure Container Instance '$ACI_NAME'..."
az container create \
  --name "$ACI_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$ACR_LOGIN_SERVER/$APP_IMAGE_NAME:$APP_IMAGE_TAG" \
  --registry-login-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_USERNAME" \
  --registry-password "$ACR_PASSWORD" \
  --dns-name-label "$ACI_DNS_LABEL" \
  --location "$LOCATION" \
  --os-type Linux \
  --cpu 1 \
  --memory 1.5 \
  --ports 8080 \
  --protocol TCP \
  --restart-policy Always \
  --environment-variables \
    AZURE_STORAGE_ACCOUNT_NAME="$STORAGE_ACCOUNT" \
    AZURE_STORAGE_CONTAINER_NAME="$STORAGE_CONTAINER" \
    APP_PORT=8080 \
    MAX_UPLOAD_MB=500 \
  --secure-environment-variables \
    AZURE_STORAGE_ACCOUNT_KEY="$STORAGE_KEY" \
  --output none
ok "Container Instance criado"


# ============================================================
# 5. Aguardar container ficar em estado Running
# ============================================================
log "Aguardando container entrar em estado 'Running' (timeout: 3 min)..."
TIMEOUT=180
ELAPSED=0
INTERVAL=10
while true; do
  STATE=$(az container show \
    --name "$ACI_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "instanceView.state" -o tsv 2>/dev/null || echo "Unknown")

  echo "    Estado atual: $STATE (${ELAPSED}s)"

  if [ "$STATE" = "Running" ]; then
    ok "Container em execução!"
    break
  fi

  if [ "$STATE" = "Failed" ]; then
    fail "Container entrou em estado 'Failed'. Verifique os logs com: az container logs --name $ACI_NAME --resource-group $RESOURCE_GROUP"
  fi

  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "⚠️  Timeout atingido. O container pode ainda estar iniciando."
    break
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done


# ============================================================
# 6. Obter FQDN e IP público
# ============================================================
log "Obtendo endereço da aplicação..."
FQDN=$(az container show \
  --name "$ACI_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "ipAddress.fqdn" -o tsv)
PUBLIC_IP=$(az container show \
  --name "$ACI_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "ipAddress.ip" -o tsv)


# ============================================================
# 7. Salvar URL no .env
# ============================================================
echo "" >> .env
echo "# ACI — gerado por 03_deploy_aci.sh" >> .env
echo "ACI_FQDN=$FQDN" >> .env
echo "ACI_IP=$PUBLIC_IP" >> .env
echo "ACI_URL=http://$FQDN:8080" >> .env
ok "URL salva no .env"


# ============================================================
# 8. Exibir logs iniciais
# ============================================================
log "Logs iniciais do container..."
sleep 5
az container logs \
  --name "$ACI_NAME" \
  --resource-group "$RESOURCE_GROUP" || true


# ============================================================
# 9. Resumo final
# ============================================================
echo ""
echo "============================================================"
echo "✅ Deploy concluído com sucesso!"
echo "============================================================"
echo "  Container  : $ACI_NAME"
echo "  IP Público : $PUBLIC_IP"
echo "  URL        : http://$FQDN:8080"
echo "============================================================"
echo ""
echo "Comandos úteis:"
echo ""
echo "  # Ver logs em tempo real:"
echo "  az container logs --name $ACI_NAME --resource-group $RESOURCE_GROUP --follow"
echo ""
echo "  # Ver status detalhado:"
echo "  az container show --name $ACI_NAME --resource-group $RESOURCE_GROUP --output table"
echo ""
echo "  # Reiniciar container:"
echo "  az container restart --name $ACI_NAME --resource-group $RESOURCE_GROUP"
echo ""
echo "  # Excluir container:"
echo "  az container delete --name $ACI_NAME --resource-group $RESOURCE_GROUP --yes"