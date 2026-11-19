#!/usr/bin/env bash
# TP5 - Circuit Breaker Resilience4j : scénario de l'exercice (section 5)
# Auteur : Ossama Elmansouri
# Usage : bash scripts/test-tp5.sh <phase>
#   preparation   crée et publie l'événement 1 (capacité 50) sur event-service
#   ignore-404    5 réservations sur un id absent (404), puis une réservation valide
#   panne         event-service arrêté : 10 réservations séquentielles, statut et durée
#   retour        event-service relancé : après 10 s, HALF_OPEN puis CLOSED
set -uo pipefail

EVENT=http://localhost:8082
RESERVATION_URL=http://localhost:8083/api/bookings
RESERVATION_JSON='{"eventId":1,"customerId":1,"quantity":1}'
ok=0

step() { printf '\n===== %s =====\n' "$1"; }
show() { printf '$ %s\n' "$*"; "$@"; echo; }
check() { local desc=$1 got=$2 want=$3
  if [ "$got" = "$want" ]; then echo "OK : $desc ($got)"; else echo "ECHEC : $desc (obtenu $got, attendu $want)"; ok=1; fi; }
book() { curl -sS -o /dev/null -w '%{http_code}' -X POST "$RESERVATION_URL" -H 'Content-Type: application/json' --data "$1"; }

case "${1:-}" in
preparation)
  step "Préparation : événement 1 créé et publié sur event-service"
  show curl -s -i -X POST "$EVENT/api/events" -H 'Content-Type: application/json' \
    -d '{"title":"Concert Gnaoua","description":"Soiree TP5","venue":"Casablanca","startsAt":"2027-03-20T20:00:00Z","price":150.00,"capacity":50}'
  show curl -s -i -X POST "$EVENT/api/events/1/publish"
  ;;
ignore-404)
  step "5a. Identifiant absent, répété 5 fois - attendu 404 à chaque fois"
  for i in $(seq 1 5); do
    printf 'Réservation eventId=999 n°%d - ' "$i"
    curl -sS -o /dev/null -w 'HTTP %{http_code} - %{time_total}s\n' -X POST "$RESERVATION_URL" \
      -H 'Content-Type: application/json' --data '{"eventId":999,"customerId":1,"quantity":1}'
  done
  step "5b. Réservation valide ensuite - attendu 201 (les 404 n'ont pas ouvert le circuit)"
  show curl -sS -i -X POST "$RESERVATION_URL" -H 'Content-Type: application/json' --data "$RESERVATION_JSON"
  step "Vérifications automatiques"
  check "id absent → 404" "$(book '{"eventId":999,"customerId":1,"quantity":1}')" 404
  check "réservation valide après les 404 → 201" "$(book "$RESERVATION_JSON")" 201
  ;;
panne)
  step "5c. event-service arrêté : 10 réservations séquentielles"
  printf '$ RESERVATION_URL=%s\n$ RESERVATION_JSON=%s\n' "$RESERVATION_URL" "$RESERVATION_JSON"
  codes=""
  for i in $(seq 1 10); do
    printf "Réservation %02d - " "$i"
    line=$(curl -sS -o /dev/null -w "HTTP %{http_code} - %{time_total}s" \
      -X POST "$RESERVATION_URL" -H "Content-Type: application/json" --data "$RESERVATION_JSON")
    echo "$line"; codes="$codes ${line:5:3}"
  done
  step "Vérifications automatiques"
  bad=$(echo $codes | tr ' ' '\n' | grep -vc '^503$')
  check "aucune des 10 réservations confirmée (toutes 503)" "$bad" 0
  ;;
retour)
  step "5d. event-service relancé, attente de la fin de l'état OPEN puis 3 appels de test (HALF_OPEN)"
  for i in 1 2 3 4; do
    printf "Réservation de retour %d - " "$i"
    curl -sS -o /dev/null -w "HTTP %{http_code} - %{time_total}s\n" \
      -X POST "$RESERVATION_URL" -H "Content-Type: application/json" --data "$RESERVATION_JSON"
  done
  step "Vérifications automatiques"
  check "le service répond de nouveau (circuit refermé)" "$(book "$RESERVATION_JSON")" 201
  ;;
*) echo "phase inconnue" >&2; exit 2 ;;
esac
exit $ok
