#!/usr/bin/env bash
# ST-04: tworzy Azure Communication Services z domeną zarządzaną przez Azure i włącza wysyłkę w aplikacji.
# Uruchamiać w Azure Cloud Shell (Bash), po provision.sh. Można uruchomić ponownie.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-jewelrunner-backend}"
APP="${APP:-jewelrunner-app}"
COMM="${COMM:-jewelrunner-comm}"
EMAIL_SERVICE="${EMAIL_SERVICE:-jewelrunner-email}"
DATA_LOCATION="${DATA_LOCATION:-europe}"

az extension add --name communication --upgrade --only-show-errors

echo "1/5 Usługa Communication Services"
az communication show --name "$COMM" --resource-group "$RESOURCE_GROUP" -o none 2>/dev/null \
  || az communication create --name "$COMM" --resource-group "$RESOURCE_GROUP" --location global --data-location "$DATA_LOCATION" -o none

echo "2/5 Usługa e-mail"
az communication email show --name "$EMAIL_SERVICE" --resource-group "$RESOURCE_GROUP" -o none 2>/dev/null \
  || az communication email create --name "$EMAIL_SERVICE" --resource-group "$RESOURCE_GROUP" --location global --data-location "$DATA_LOCATION" -o none

echo "3/5 Domena zarządzana przez Azure"
az communication email domain show --domain-name AzureManagedDomain --email-service-name "$EMAIL_SERVICE" --resource-group "$RESOURCE_GROUP" -o none 2>/dev/null \
  || az communication email domain create --domain-name AzureManagedDomain --email-service-name "$EMAIL_SERVICE" \
       --resource-group "$RESOURCE_GROUP" --location global --domain-management AzureManaged -o none
DOMAIN_ID="$(az communication email domain show --domain-name AzureManagedDomain --email-service-name "$EMAIL_SERVICE" --resource-group "$RESOURCE_GROUP" --query id -o tsv)"
SENDER_DOMAIN="$(az communication email domain show --domain-name AzureManagedDomain --email-service-name "$EMAIL_SERVICE" --resource-group "$RESOURCE_GROUP" --query mailFromSenderDomain -o tsv)"

echo "4/5 Połączenie domeny z usługą"
az communication update --name "$COMM" --resource-group "$RESOURCE_GROUP" --linked-domains "$DOMAIN_ID" -o none

echo "5/5 Ustawienia aplikacji"
CONNECTION="$(az communication list-key --name "$COMM" --resource-group "$RESOURCE_GROUP" --query primaryConnectionString -o tsv)"
SETTINGS="$(mktemp)"
trap 'rm -f "$SETTINGS"' EXIT
CONNECTION="$CONNECTION" SENDER="DoNotReply@$SENDER_DOMAIN" python3 - >"$SETTINGS" <<'PY'
import json
import os

print(json.dumps({
    "EMAIL_BACKEND": "acs",
    "ACS_CONNECTION_STRING": os.environ["CONNECTION"],
    "EMAIL_SENDER": os.environ["SENDER"],
}))
PY
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$APP" --settings "@$SETTINGS" -o none

echo "Gotowe. Nadawca: DoNotReply@$SENDER_DOMAIN"
echo "Wdróż nową paczkę: az webapp deploy --resource-group $RESOURCE_GROUP --name $APP --src-path jewelrunner.zip --type zip"
