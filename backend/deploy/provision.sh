#!/usr/bin/env bash
# Tworzy serwer aplikacji i konfigurację na Azure. Bazę PostgreSQL tworzysz wcześniej w portalu (AZURE.md, krok 1).
# Uruchamiać w Azure Cloud Shell (Bash). Skrypt można bezpiecznie uruchomić ponownie.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-jewelerunner-backend}"
LOCATION="${LOCATION:-polandcentral}"
PLAN="jewelrunner-plan"
APP="${APP:-jewelrunner-app}"
DB_SERVER="${DB_SERVER:-jewelrunner-db}"
DB_NAME="jewelrunner"
RUNTIME="${RUNTIME:-PYTHON:3.13}"

echo "Subskrypcja: $(az account show --query name -o tsv)"
az group show --name "$RESOURCE_GROUP" --query name -o tsv >/dev/null

SKU="$(az postgres flexible-server show --resource-group "$RESOURCE_GROUP" --name "$DB_SERVER" --query sku.name -o tsv)"
if [ "$SKU" != "Standard_B1ms" ]; then
  echo "Baza $DB_SERVER ma wariant $SKU zamiast Standard_B1ms. Przerywam, żeby nie ponosić kosztów." >&2
  exit 1
fi
DB_HOST="$(az postgres flexible-server show --resource-group "$RESOURCE_GROUP" --name "$DB_SERVER" --query fullyQualifiedDomainName -o tsv)"
DB_USER="$(az postgres flexible-server show --resource-group "$RESOURCE_GROUP" --name "$DB_SERVER" --query administratorLogin -o tsv)"

read -r -s -p "Hasło administratora bazy $DB_SERVER: " DB_PASSWORD
echo

az postgres flexible-server db create --resource-group "$RESOURCE_GROUP" --server-name "$DB_SERVER" --name "$DB_NAME" -o none || echo "Baza już istnieje lub nie dało się jej utworzyć, idę dalej."

az appservice plan create --resource-group "$RESOURCE_GROUP" --name "$PLAN" --location "$LOCATION" --is-linux --sku F1 -o none
az webapp create --resource-group "$RESOURCE_GROUP" --plan "$PLAN" --name "$APP" --runtime "$RUNTIME" -o none
az webapp update --resource-group "$RESOURCE_GROUP" --name "$APP" --https-only true -o none
az webapp config set --resource-group "$RESOURCE_GROUP" --name "$APP" --startup-file "bash deploy/startup.sh" -o none

URL="https://$(az webapp show --resource-group "$RESOURCE_GROUP" --name "$APP" --query defaultHostName -o tsv)"

# Ustawienia idą przez plik z prawami tylko dla właściciela, żeby hasła nie było w poleceniu.
SETTINGS="$(mktemp)"
trap 'rm -f "$SETTINGS"' EXIT
DB_USER="$DB_USER" DB_PASSWORD="$DB_PASSWORD" DB_HOST="$DB_HOST" DB_NAME="$DB_NAME" URL="$URL" python3 - >"$SETTINGS" <<'PY'
import json
import os
from urllib.parse import quote

env = os.environ
print(json.dumps({
    "DATABASE_URL": f"postgresql+psycopg://{quote(env['DB_USER'], safe='')}:{quote(env['DB_PASSWORD'], safe='')}"
                    f"@{env['DB_HOST']}:5432/{env['DB_NAME']}?sslmode=require",
    "ENVIRONMENT": "production",
    "CORS_ORIGINS": env["URL"],
    "PORTAL_URL": env["URL"],
    "PORTAL_DIST": "portal_dist",
    "EMAIL_BACKEND": "none",
    "SCM_DO_BUILD_DURING_DEPLOYMENT": "true",
}))
PY
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$APP" --settings "@$SETTINGS" -o none

echo "Gotowe. Adres aplikacji: $URL"
echo "Wdrożenie: az webapp deploy --resource-group $RESOURCE_GROUP --name $APP --src-path jewelrunner.zip --type zip"
