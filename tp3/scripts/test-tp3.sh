#!/usr/bin/env bash
# TP3 - Config Server & GitHub : vérifications du TP
# Auteur : Ossama Elmansouri
# Usage : bash scripts/test-tp3.sh <phase>
#   config         section 5  : Config Server lit le dépôt GitHub
#   initial        section 8  : services démarrés avec la configuration v1
#   avant-refresh  section 9  : v2 poussée sur GitHub, service encore en v1
#   refresh        section 9  : POST /actuator/refresh puis v2
#   profil-dev     section 10 : fichier customer-service-dev.yml servi par 8888
#   service-dev    section 10 : customer-service relancé avec le profil dev
set -uo pipefail

CONFIG=http://localhost:8888
EUREKA=http://localhost:8761
DIRECT=http://localhost:8081
GATEWAY=http://localhost:8080
SUFFIX=$(date +%s)
ok=0

step() { printf '\n===== %s =====\n' "$1"; }
show() { printf '$ %s\n' "$*"; "$@"; echo; }
check() { # description, commande...
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then echo "OK : $desc"; else echo "ECHEC : $desc"; ok=1; fi
}
contains() { curl -s "$1" | grep -q -- "$2"; }
message() { curl -s "$DIRECT/api/config/message"; }

case "${1:-}" in
config)
  step "5a. Santé du Config Server - attendu 200 UP"
  show curl -s -i "$CONFIG/actuator/health"
  step "5b. Configuration de customer-service lue dans GitHub"
  show curl -s -i "$CONFIG/customer-service/default/main"
  step "5c. Configuration de api-gateway lue dans GitHub"
  show curl -s -i "$CONFIG/api-gateway/default/main"
  step "Vérifications automatiques"
  check "customer-service : server.port présent"                    contains "$CONFIG/customer-service/default/main" '"server.port"'
  check "customer-service : eureka defaultZone (application.yml)"   contains "$CONFIG/customer-service/default/main" 'eureka.client.service-url.defaultZone'
  check "customer-service : ticketflow.message en v1"              contains "$CONFIG/customer-service/default/main" 'configuration v1'
  check "api-gateway : route lb://customer-service"                 contains "$CONFIG/api-gateway/default/main" 'lb://customer-service'
  check "label main"                                               contains "$CONFIG/customer-service/default/main" '"label":"main"'
  ;;
initial)
  step "8a. Eureka : CUSTOMER-SERVICE et API-GATEWAY UP, pas de CONFIG-SERVER"
  show curl -s -o /dev/null -w 'CUSTOMER-SERVICE : HTTP %{http_code}\n' -H 'Accept: application/json' "$EUREKA/eureka/apps/CUSTOMER-SERVICE"
  show curl -s -o /dev/null -w 'API-GATEWAY      : HTTP %{http_code}\n' -H 'Accept: application/json' "$EUREKA/eureka/apps/API-GATEWAY"
  show curl -s -o /dev/null -w 'CONFIG-SERVER    : HTTP %{http_code}\n' -H 'Accept: application/json' "$EUREKA/eureka/apps/CONFIG-SERVER"
  step "8b. Message lu dans la configuration - attendu v1"
  show curl -s -i "$DIRECT/api/config/message"
  step "8c. Routes de la gateway (venues de GitHub)"
  show curl -s -i "$GATEWAY/actuator/gateway/routes"
  step "8d. Flux métier via la gateway - attendu 201 puis 200"
  show curl -s -i -X POST "$GATEWAY/api/customers" -H 'Content-Type: application/json' \
    -d "{\"firstName\":\"Salma\",\"lastName\":\"Alaoui\",\"email\":\"salma.tp3.$SUFFIX@example.com\"}"
  show curl -s -i "$GATEWAY/api/customers"
  step "Vérifications automatiques"
  check "message v1"                        contains "$DIRECT/api/config/message" 'configuration v1'
  check "route lb://customer-service"       contains "$GATEWAY/actuator/gateway/routes" 'lb://customer-service'
  check "Salma présente via la gateway"     contains "$GATEWAY/api/customers" 'Salma'
  check "CONFIG-SERVER absent d'Eureka"     bash -c "[ \"\$(curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/json' $EUREKA/eureka/apps/CONFIG-SERVER)\" = 404 ]"
  ;;
avant-refresh)
  step "9a. Config Server après git push - attendu v2"
  show curl -s -i "$CONFIG/customer-service/default/main"
  step "9b. Service toujours en mémoire - attendu v1"
  show curl -s -i "$DIRECT/api/config/message"
  step "Vérifications automatiques"
  check "Config Server sert v2"          contains "$CONFIG/customer-service/default/main" 'configuration v2'
  check "le service renvoie encore v1"   contains "$DIRECT/api/config/message" 'configuration v1'
  ;;
refresh)
  step "9c. POST /actuator/refresh - attendu 200 et ticketflow.message"
  show curl -s -i -X POST "$DIRECT/actuator/refresh"
  step "9d. Message après refresh - attendu v2, sans redémarrage"
  show curl -s -i "$DIRECT/api/config/message"
  show curl -s -i "$GATEWAY/api/customers"
  step "Vérifications automatiques"
  check "message v2"                        contains "$DIRECT/api/config/message" 'configuration v2'
  check "Salma toujours présente (pas de redémarrage)" contains "$GATEWAY/api/customers" 'Salma'
  ;;
profil-dev)
  step "10a. Configuration du profil dev servie par 8888"
  show curl -s -i "$CONFIG/customer-service/dev/main"
  step "Vérifications automatiques"
  check "profil dev servi"   contains "$CONFIG/customer-service/dev/main" 'TicketFlow - profil dev'
  ;;
service-dev)
  step "10b. customer-service relancé avec -Dspring-boot.run.profiles=dev"
  show curl -s -i "$DIRECT/api/config/message"
  step "Vérifications automatiques"
  check "message du profil dev"  contains "$DIRECT/api/config/message" 'TicketFlow - profil dev'
  ;;
*) echo "phase inconnue" >&2; exit 2 ;;
esac
exit $ok
