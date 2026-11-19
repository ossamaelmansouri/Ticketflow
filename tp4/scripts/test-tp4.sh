#!/usr/bin/env bash
# TP4 - OpenFeign : booking-service appelle event-service
# Auteur : Ossama Elmansouri
# Usage : bash scripts/test-tp4.sh <phase>
#   nominal      sections 5 et 7 : Eureka, contrat direct, réservation via Feign, id absent
#   sans-event   event-service arrêté : l'erreur distante n'est pas un succès
set -uo pipefail

EUREKA=http://localhost:8761
EVENT=http://localhost:8082
BOOKING=http://localhost:8083
ok=0

step() { printf '\n===== %s =====\n' "$1"; }
show() { printf '$ %s\n' "$*"; "$@"; echo; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
check() { local desc=$1 got=$2 want=$3
  if [ "$got" = "$want" ]; then echo "OK : $desc ($got)"; else echo "ECHEC : $desc (obtenu $got, attendu $want)"; ok=1; fi; }
json='Content-Type: application/json'

case "${1:-}" in
nominal)
  step "5a. Eureka : EVENT-SERVICE et BOOKING-SERVICE inscrits"
  show curl -s -o /dev/null -w 'EVENT-SERVICE   : HTTP %{http_code}\n' -H 'Accept: application/json' "$EUREKA/eureka/apps/EVENT-SERVICE"
  show curl -s -o /dev/null -w 'BOOKING-SERVICE : HTTP %{http_code}\n' -H 'Accept: application/json' "$EUREKA/eureka/apps/BOOKING-SERVICE"

  step "Préparation : création et publication d'un événement sur event-service (8082)"
  show curl -s -i -X POST "$EVENT/api/events" -H "$json" \
    -d '{"title":"Concert Gnaoua","description":"Soiree TP4","venue":"Casablanca","startsAt":"2027-03-20T20:00:00Z","price":150.00,"capacity":3}'
  show curl -s -i -X POST "$EVENT/api/events/1/publish"
  show curl -s -i -X POST "$EVENT/api/events" -H "$json" \
    -d '{"title":"Brouillon","venue":"Rabat","startsAt":"2027-04-01T20:00:00Z","price":80.00,"capacity":50}'

  step "5b. Contrat direct : GET /api/events/1 sur 8082 - attendu 200"
  show curl -s -i "$EVENT/api/events/1"

  step "7a. Réservation via booking-service (8083) - Feign appelle event-service - attendu 201"
  show curl -s -i -X POST "$BOOKING/api/bookings" -H "$json" -d '{"eventId":1,"customerId":1,"quantity":2}'

  step "7b. Identifiant absent (eventId 999) - attendu 404, pas un succès"
  show curl -s -i -X POST "$BOOKING/api/bookings" -H "$json" -d '{"eventId":999,"customerId":1,"quantity":1}'

  step "7c. Événement non publié (DRAFT) - attendu 409"
  show curl -s -i -X POST "$BOOKING/api/bookings" -H "$json" -d '{"eventId":2,"customerId":1,"quantity":1}'

  step "7d. Plus assez de places (capacité 3, 2 déjà réservées) - attendu 409"
  show curl -s -i -X POST "$BOOKING/api/bookings" -H "$json" -d '{"eventId":1,"customerId":2,"quantity":2}'

  step "7e. Liste des réservations - une seule réservation enregistrée"
  show curl -s -i "$BOOKING/api/bookings"

  step "Vérifications automatiques"
  check "EVENT-SERVICE dans Eureka"   "$(code -H 'Accept: application/json' "$EUREKA/eureka/apps/EVENT-SERVICE")" 200
  check "BOOKING-SERVICE dans Eureka" "$(code -H 'Accept: application/json' "$EUREKA/eureka/apps/BOOKING-SERVICE")" 200
  check "contrat direct GET /api/events/1" "$(code "$EVENT/api/events/1")" 200
  check "id absent → 404 (pas 201)" "$(code -X POST "$BOOKING/api/bookings" -H "$json" -d '{"eventId":999,"customerId":1,"quantity":1}')" 404
  check "événement DRAFT → 409" "$(code -X POST "$BOOKING/api/bookings" -H "$json" -d '{"eventId":2,"customerId":1,"quantity":1}')" 409
  n=$(curl -s "$BOOKING/api/bookings" | grep -o '"id"' | wc -l | tr -d ' ')
  check "une seule réservation enregistrée (les erreurs n'ont rien créé)" "$n" 1
  curl -s "$BOOKING/api/bookings" | grep -q '"eventTitle":"Concert Gnaoua"' \
    && echo "OK : le titre vient d'event-service via Feign" || { echo "ECHEC : titre absent"; ok=1; }
  ;;
sans-event)
  step "event-service arrêté : réservation - attendu 503 (pas un succès)"
  show curl -s -i -X POST "$BOOKING/api/bookings" -H "$json" -d '{"eventId":1,"customerId":3,"quantity":1}'
  step "Vérifications automatiques"
  check "event-service indisponible → 503" "$(code -X POST "$BOOKING/api/bookings" -H "$json" -d '{"eventId":1,"customerId":3,"quantity":1}')" 503
  ;;
*) echo "phase inconnue" >&2; exit 2 ;;
esac
exit $ok
