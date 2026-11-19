#!/usr/bin/env bash
# TP1 - Gateway API : rejoue les tests du TP
# Auteur : Ossama Elmansouri
# Prérequis : customer-service sur 8081 et api-gateway sur 8080 démarrés.
set -euo pipefail

DIRECT=http://localhost:8081
GATEWAY=http://localhost:8080
SUFFIX=$(date +%s)

step() { printf '\n===== %s =====\n' "$1"; }

# Extrait l'identifiant final de l'en-tête Location d'une réponse curl -i
location_id() { grep -i '^location:' | tr -d '\r' | awk -F/ '{print $NF}'; }

step "1. POST direct (8081) - attendu 201"
RESP=$(curl -s -i -X POST "$DIRECT/api/customers" \
  -H 'Content-Type: application/json' \
  -d "{\"firstName\":\"Mohamed\",\"lastName\":\"Amine\",\"email\":\"med.$SUFFIX@example.com\"}")
echo "$RESP"
ID_CUSTOMER=$(echo "$RESP" | location_id)
echo ">> ID_CUSTOMER=$ID_CUSTOMER"

step "2. GET direct (8081) - attendu 200"
curl -s -i "$DIRECT/api/customers/$ID_CUSTOMER"; echo
curl -s -i "$DIRECT/api/customers"; echo

step "3. GET via gateway (8080) - attendu 200 + X-Served-By"
curl -s -i "$GATEWAY/api/customers/$ID_CUSTOMER"; echo

step "4. POST via gateway (8080) - attendu 201"
RESP=$(curl -s -i -X POST "$GATEWAY/api/customers" \
  -H 'Content-Type: application/json' \
  -d "{\"firstName\":\"Amine\",\"lastName\":\"Bennani\",\"email\":\"amine.gateway.$SUFFIX@example.com\"}")
echo "$RESP"
ID_AMINE=$(echo "$RESP" | location_id)
echo ">> ID_AMINE=$ID_AMINE"

step "5. GET + liste via gateway - attendu 200 + X-Served-By"
curl -s -i "$GATEWAY/api/customers/$ID_AMINE"; echo
curl -s -i "$GATEWAY/api/customers"; echo

step "6. Routes Actuator"
curl -s -i "$GATEWAY/actuator/gateway/routes"; echo

step "Vérification automatique de l'en-tête X-Served-By"
if curl -s -D - -o /dev/null "$GATEWAY/api/customers" | grep -qi '^x-served-by: api-gateway'; then
  echo "OK : la réponse via 8080 porte X-Served-By: api-gateway"
else
  echo "ECHEC : en-tête X-Served-By absent" >&2; exit 1
fi
