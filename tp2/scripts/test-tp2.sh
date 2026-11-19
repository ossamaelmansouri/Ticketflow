#!/usr/bin/env bash
# TP2 - Discovery Service : rejoue les vérifications du TP
# Auteur : Ossama Elmansouri
# Usage :
#   bash scripts/test-tp2.sh explicite   # sections 5 à 8 (route lb:// explicite)
#   bash scripts/test-tp2.sh locator     # section 10 (Discovery Locator activé)
# Prérequis : discovery-server (8761), customer-service (8081) et api-gateway (8080) démarrés.
set -uo pipefail

EUREKA=http://localhost:8761
DIRECT=http://localhost:8081
GATEWAY=http://localhost:8080
PHASE=${1:-explicite}
SUFFIX=$(date +%s)

step() { printf '\n===== %s =====\n' "$1"; }
show() { printf '$ %s\n' "$*"; "$@"; echo; }

if [ "$PHASE" = "explicite" ]; then
  step "5. Registre Eureka - attendu 200"
  show curl -s -i -H 'Accept: application/json' "$EUREKA/eureka/apps"

  step "6. CUSTOMER-SERVICE dans Eureka - attendu 200, status UP, port 8081"
  show curl -s -i -H 'Accept: application/json' "$EUREKA/eureka/apps/CUSTOMER-SERVICE"

  step "8a. API-GATEWAY dans Eureka - attendu 200, status UP"
  show curl -s -o /dev/null -w 'HTTP %{http_code}\n' -H 'Accept: application/json' "$EUREKA/eureka/apps/API-GATEWAY"

  step "8b. POST via gateway - attendu 201 + Location + X-Served-By"
  show curl -s -i -X POST "$GATEWAY/api/customers" \
    -H 'Content-Type: application/json' \
    -d "{\"firstName\":\"Yasmine\",\"lastName\":\"El Amrani\",\"email\":\"yasmine.tp2.$SUFFIX@example.com\"}"

  step "8c. Liste via gateway et en direct - attendu 200"
  show curl -s -i "$GATEWAY/api/customers"
  show curl -s -i "$DIRECT/api/customers"

  step "8d. Routes Actuator - attendu uri lb://customer-service"
  show curl -s -i "$GATEWAY/actuator/gateway/routes"

  step "Vérifications automatiques"
  ok=0
  curl -s -H 'Accept: application/json' "$EUREKA/eureka/apps/CUSTOMER-SERVICE" | grep -q '"status":"UP"' \
    && echo "OK : CUSTOMER-SERVICE est UP dans Eureka" || { echo "ECHEC : CUSTOMER-SERVICE absent ou pas UP"; ok=1; }
  curl -s -H 'Accept: application/json' "$EUREKA/eureka/apps/API-GATEWAY" | grep -q '"status":"UP"' \
    && echo "OK : API-GATEWAY est UP dans Eureka" || { echo "ECHEC : API-GATEWAY absent ou pas UP"; ok=1; }
  curl -s -D - -o /dev/null "$GATEWAY/api/customers" | grep -qi '^x-served-by: api-gateway' \
    && echo "OK : X-Served-By présent via 8080" || { echo "ECHEC : X-Served-By absent"; ok=1; }
  curl -s "$GATEWAY/actuator/gateway/routes" | grep -q 'lb://customer-service' \
    && echo "OK : la route utilise lb://customer-service" || { echo "ECHEC : uri lb:// absente"; ok=1; }
  exit $ok
fi

if [ "$PHASE" = "locator" ]; then
  step "10.2a. Route explicite /api/customers - attendu 200 + X-Served-By"
  show curl -s -i "$GATEWAY/api/customers"

  step "10.2b. Route générée par le Locator /customer-service/api/customers - attendu 200, mêmes données"
  show curl -s -i "$GATEWAY/customer-service/api/customers"

  step "10.2c. Mauvais chemin /customer-service/customers - attendu 404 (le service recevrait /customers)"
  show curl -s -i "$GATEWAY/customer-service/customers"

  step "10.2d. Routes Actuator - route explicite + route générée"
  show curl -s -i "$GATEWAY/actuator/gateway/routes"

  step "Vérifications automatiques"
  ok=0
  a=$(curl -s "$GATEWAY/api/customers"); b=$(curl -s "$GATEWAY/customer-service/api/customers")
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/customer-service/api/customers")" = "200" ] \
    && echo "OK : la route du Locator répond 200" || { echo "ECHEC : route du Locator"; ok=1; }
  [ "$a" = "$b" ] && echo "OK : mêmes données sur les deux routes" || { echo "ECHEC : données différentes"; ok=1; }
  curl -s "$GATEWAY/actuator/gateway/routes" | grep -q 'ReactiveCompositeDiscoveryClient_CUSTOMER-SERVICE\|CUSTOMER-SERVICE' \
    && echo "OK : route générée pour CUSTOMER-SERVICE visible dans Actuator" || { echo "ECHEC : route générée absente"; ok=1; }
  exit $ok
fi

echo "Phase inconnue : $PHASE (explicite | locator)" >&2
exit 2
