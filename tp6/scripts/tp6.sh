#!/usr/bin/env bash
# TP6 - Apache Kafka en ligne de commande : exécution automatisée des exercices
# Auteur : Ossama Elmansouri
#
# Lancé depuis tp6/ sur la machine hôte (Git Bash), Docker Desktop démarré.
# Les « terminaux » T1, T2... de l'énoncé sont des consommateurs lancés en
# arrière-plan dans le conteneur (docker exec -d), chacun avec un client.id
# distinct et sa sortie dans /tmp/<nom>.txt.
#
# Usage : bash scripts/tp6.sh <dossier_captures>
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash : ne pas convertir /opt/kafka/bin en chemin Windows

CAP=${1:-captures}
mkdir -p "$CAP"
cd "$(dirname "$0")/../kafka-tp"
T=ticketflow.payment.succeeded

# --- outils --------------------------------------------------------------
out=/dev/null
section() { out="$CAP_ABS/$1"; : > "$out"; echo ">> $1"; }
step()    { printf '\n===== %s =====\n' "$1" >> "$out"; }
note()    { printf '%s\n' "$*" >> "$out"; }
# k : commande Kafka dans le conteneur, affichée puis exécutée
k() {
  printf '$ %s\n' "$*" | sed 's/\$BS/kafka:9092/g' >> "$out"
  docker exec kafka sh -c "cd /opt/kafka/bin && BS=kafka:9092 && $*" >> "$out" 2>&1
  echo >> "$out"
}
# produce <clé:valeur ou valeur>... : producteur console alimenté par l'entrée standard
produce() {
  local keyed=$1; shift
  local props=""; [ "$keyed" = key ] && props="--property parse.key=true --property key.separator=:"
  printf '$ ./kafka-console-producer.sh --bootstrap-server kafka:9092 --topic %s %s\n' "$T" "$props" >> "$out"
  for l in "$@"; do printf '> %s\n' "$l" >> "$out"; done
  printf '%s\n' "$@" | docker exec -i kafka sh -c \
    "cd /opt/kafka/bin && ./kafka-console-producer.sh --bootstrap-server kafka:9092 --topic $T $props" >> "$out" 2>&1
  echo >> "$out"
}
# bg <nom> <groupe> [options] : consommateur en arrière-plan (= un terminal de l'énoncé)
bg() {
  local name=$1 group=$2; shift 2
  printf '[%s] $ ./kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic %s --group %s %s --property print.partition=true --property print.key=true\n' \
    "$name" "$T" "$group" "$*" >> "$out"
  docker exec -d kafka sh -c "cd /opt/kafka/bin && ./kafka-console-consumer.sh --bootstrap-server kafka:9092 \
    --topic $T --group $group $* --consumer-property client.id=$name \
    --property print.partition=true --property print.key=true > /tmp/$name.txt 2>&1"
}
# client[.]id : la ligne de commande de pkill elle-même ne correspond pas au motif
stopbg()  { docker exec kafka sh -c "pkill -f 'client[.]id=$1\$\|client[.]id=$1 ' || true"; note "[$1] arrêté (Ctrl+C)"; }
showbg()  { note "--- sortie du terminal $1 ---"; docker exec kafka sh -c "cat /tmp/$1.txt" >> "$out" 2>&1; echo >> "$out"; }
CAP_ABS=$(cd "$CAP" && pwd)

# --- 0. Démarrage --------------------------------------------------------
section 00-demarrage.txt
step "Docker"
docker version --format 'Docker client {{.Client.Version}} / serveur {{.Server.Version}}' >> "$out" 2>&1
docker compose down -v >/dev/null 2>&1
docker compose -f docker-compose.enonce.yml down >/dev/null 2>&1

step "Essai avec le docker-compose.yml de l'énoncé (deux listeners sur le port 9092)"
note '$ docker compose -f docker-compose.enonce.yml up -d'
docker compose -f docker-compose.enonce.yml up -d >> "$out" 2>&1
sleep 15
note '$ docker ps -a --filter name=kafka'
docker ps -a --filter name=kafka --format 'table {{.Names}}\t{{.Status}}' >> "$out" 2>&1
note '$ docker compose -f docker-compose.enonce.yml logs kafka   (extrait)'
docker compose -f docker-compose.enonce.yml logs kafka 2>&1 | grep -i -E "different port|IllegalArgument|requirement failed|Exception" | head -5 >> "$out"
docker compose -f docker-compose.enonce.yml down >/dev/null 2>&1

step "Démarrage avec le docker-compose.yml corrigé"
note '$ docker compose up -d'
docker compose up -d >> "$out" 2>&1
for i in $(seq 1 60); do
  docker compose logs kafka 2>&1 | grep -q "Kafka Server started" && break; sleep 2
done
note '$ docker compose logs kafka | grep "Kafka Server started"'
docker compose logs kafka 2>&1 | grep "Kafka Server started" | head -1 >> "$out"
note '$ docker ps --filter name=kafka'
docker ps --filter name=kafka --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' >> "$out" 2>&1
echo >> "$out"
k 'ls kafka-*.sh | head -20'

# --- 1. Topics -----------------------------------------------------------
section 01-exercice1-topics.txt
step "Créer, lister et décrire ticketflow.payment.succeeded"
k "./kafka-topics.sh --bootstrap-server \$BS --create --topic $T --partitions 3 --replication-factor 1"
k "./kafka-topics.sh --bootstrap-server \$BS --list"
k "./kafka-topics.sh --bootstrap-server \$BS --describe --topic $T"
step "Les deux autres topics du chapitre"
k "./kafka-topics.sh --bootstrap-server \$BS --create --topic ticketflow.payment.failed --partitions 3 --replication-factor 1"
k "./kafka-topics.sh --bootstrap-server \$BS --create --topic ticketflow.booking.cancelled --partitions 3 --replication-factor 1"
k "./kafka-topics.sh --bootstrap-server \$BS --list"
step "Essai : facteur de réplication 3 sur un seul broker (erreur attendue)"
k "./kafka-topics.sh --bootstrap-server \$BS --create --topic ticketflow.test.rf3 --partitions 3 --replication-factor 3"

# --- 2. Produire / consommer ---------------------------------------------
section 02-exercice2-produire-consommer.txt
step "Terminal 2 : producteur, trois lignes"
produce nokey '{"bookingId":1,"amount":300.00}' '{"bookingId":2,"amount":150.00}' '{"bookingId":3,"amount":90.00}'
step "Terminal 1 : consommateur --from-beginning (les 3 messages)"
k "./kafka-console-consumer.sh --bootstrap-server \$BS --topic $T --from-beginning --timeout-ms 8000"
step "Constat : relecture --from-beginning (rien n'a été supprimé)"
k "./kafka-console-consumer.sh --bootstrap-server \$BS --topic $T --from-beginning --timeout-ms 8000"
step "Constat : sans --from-beginning, rien ne s'affiche (auto.offset.reset=latest)"
k "./kafka-console-consumer.sh --bootstrap-server \$BS --topic $T --timeout-ms 8000"

# --- 3. Clés, partitions, offsets ----------------------------------------
section 03-exercice3-cles-partitions-offsets.txt
step "Producteur avec clés (8 lignes)"
produce key \
  'booking-10:{"event":"PaymentSucceeded","bookingId":10}' \
  'booking-11:{"event":"PaymentSucceeded","bookingId":11}' \
  'booking-10:{"event":"BookingConfirmed","bookingId":10}' \
  'booking-12:{"event":"PaymentSucceeded","bookingId":12}' \
  'booking-11:{"event":"BookingConfirmed","bookingId":11}' \
  'booking-10:{"event":"TicketIssued","bookingId":10}' \
  'booking-12:{"event":"BookingConfirmed","bookingId":12}' \
  'booking-11:{"event":"TicketIssued","bookingId":11}'
step "Relecture avec partition, offset et clé"
k "./kafka-console-consumer.sh --bootstrap-server \$BS --topic $T --from-beginning --timeout-ms 8000 --property print.partition=true --property print.offset=true --property print.key=true"
step "Offsets de fin par partition (somme attendue : 11)"
k "./kafka-get-offsets.sh --bootstrap-server \$BS --topic $T"
step "Offsets de début (--time -2)"
k "./kafka-get-offsets.sh --bootstrap-server \$BS --topic $T --time -2"
step "Lecture ciblée : la partition la plus remplie, à partir de l'offset 1, 2 messages"
P=$(docker exec kafka sh -c "cd /opt/kafka/bin && ./kafka-get-offsets.sh --bootstrap-server kafka:9092 --topic $T" | tr -d '\r' | sort -t: -k3 -n | tail -1 | cut -d: -f2)
k "./kafka-console-consumer.sh --bootstrap-server \$BS --topic $T --partition ${P:-0} --offset 1 --max-messages 2 --property print.offset=true --property print.partition=true"

# --- 4. Groupes et rééquilibrage ------------------------------------------
section 04-exercice4-groupes-reequilibrage.txt
G=notification-service
step "T1 et T2 : deux consommateurs du groupe $G (--from-beginning)"
bg T1 $G --from-beginning
bg T2 $G --from-beginning
sleep 12
step "T3 : répartition des partitions (attendu 2 + 1)"
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --describe --group $G"
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --describe --group $G --members"
step "T3 : publication avec clés (booking-20/21/22)"
produce key 'booking-20:{"event":"PaymentSucceeded"}' 'booking-21:{"event":"PaymentSucceeded"}' 'booking-22:{"event":"PaymentSucceeded"}' \
            'booking-20:{"event":"BookingConfirmed"}' 'booking-21:{"event":"BookingConfirmed"}' 'booking-22:{"event":"BookingConfirmed"}'
sleep 3
showbg T1; showbg T2

step "Rééquilibrage : arrêt de T2"
stopbg T2
sleep 8
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --describe --group $G"
docker exec kafka sh -c ": > /tmp/T1.txt"
produce key 'booking-20:{"event":"TicketIssued"}' 'booking-21:{"event":"TicketIssued"}' 'booking-22:{"event":"TicketIssued"}'
sleep 3
note "(sortie de T1 vidée avant cette publication : seuls les nouveaux messages apparaissent)"
showbg T1
step "Relance de T2 : nouveau rééquilibrage"
bg T2 $G
sleep 10
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --describe --group $G"

step "Retard (lag) : arrêt de T1 et T2, puis 5 messages publiés"
stopbg T1; stopbg T2
sleep 8
produce key 'booking-23:{"n":1}' 'booking-24:{"n":2}' 'booking-25:{"n":3}' 'booking-26:{"n":4}' 'booking-27:{"n":5}'
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --describe --group $G"
step "Reprise d'un consommateur du groupe, sans --from-beginning : exactement les 5 messages manqués"
k "./kafka-console-consumer.sh --bootstrap-server \$BS --topic $T --group $G --timeout-ms 10000 --property print.partition=true --property print.key=true"
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --describe --group $G"

step "Un second groupe : analytics relit tout depuis le début"
k "./kafka-console-consumer.sh --bootstrap-server \$BS --topic $T --group analytics --from-beginning --timeout-ms 10000 --property print.partition=true"
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --list"

step "Rejouer l'historique : reset des offsets de $G"
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --group $G --topic $T --reset-offsets --to-earliest --dry-run"
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --group $G --topic $T --reset-offsets --to-earliest --execute"
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --describe --group $G"
note "Relance d'un consommateur du groupe : nombre de messages relus"
printf '$ ./kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic %s --group %s --timeout-ms 10000 | wc -l\n' "$T" "$G" >> "$out"
docker exec kafka sh -c "cd /opt/kafka/bin && ./kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic $T --group $G --timeout-ms 10000 2>/dev/null | wc -l" >> "$out" 2>&1
echo >> "$out"

step "Question : quatre consommateurs dans le groupe pour 3 partitions"
for c in C1 C2 C3 C4; do bg $c $G; done
sleep 15
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --describe --group $G --members"
for c in C1 C2 C3 C4; do stopbg $c; done
sleep 5

# --- 5. Rétention et configuration ---------------------------------------
section 05-exercice5-retention-compaction.txt
step "Configuration du topic, rétention réduite à 1 minute, puis remise à la valeur par défaut"
k "./kafka-configs.sh --bootstrap-server \$BS --entity-type topics --entity-name $T --describe"
k "./kafka-configs.sh --bootstrap-server \$BS --entity-type topics --entity-name $T --alter --add-config retention.ms=60000"
k "./kafka-configs.sh --bootstrap-server \$BS --entity-type topics --entity-name $T --describe"
k "./kafka-configs.sh --bootstrap-server \$BS --entity-type topics --entity-name $T --alter --delete-config retention.ms"
k "./kafka-configs.sh --bootstrap-server \$BS --entity-type topics --entity-name $T --describe"
step "Optionnel : topic compacté ticketflow.booking.status"
k "./kafka-topics.sh --bootstrap-server \$BS --create --topic ticketflow.booking.status --partitions 1 --replication-factor 1 --config cleanup.policy=compact"
printf '$ ./kafka-console-producer.sh --bootstrap-server kafka:9092 --topic ticketflow.booking.status --property parse.key=true --property key.separator=:\n> booking-30:PENDING\n> booking-30:CONFIRMED\n> booking-30:CANCELLED\n' >> "$out"
printf 'booking-30:PENDING\nbooking-30:CONFIRMED\nbooking-30:CANCELLED\n' | docker exec -i kafka sh -c \
  "cd /opt/kafka/bin && ./kafka-console-producer.sh --bootstrap-server kafka:9092 --topic ticketflow.booking.status --property parse.key=true --property key.separator=:" >> "$out" 2>&1
echo >> "$out"
k "./kafka-console-consumer.sh --bootstrap-server \$BS --topic ticketflow.booking.status --from-beginning --timeout-ms 8000 --property print.key=true"

# --- 6. Listeners et réseau Docker ---------------------------------------
section 06-exercice6-listeners-reseau.txt
step "1) Adresse « Docker » kafka:9092 depuis un conteneur du réseau kafka-tp : doit fonctionner"
note '$ docker run --rm --network kafka-tp apache/kafka:4.0.0 /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list'
docker run --rm --network kafka-tp apache/kafka:4.0.0 /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list >> "$out" 2>&1
echo >> "$out"
step "2) Adresse « hôte » localhost:9092 depuis ce même conteneur : doit échouer"
note "(l'énoncé répète par erreur kafka:9092 dans cette seconde commande ; le test porte sur localhost:9092)"
note '$ docker run --rm --network kafka-tp apache/kafka:4.0.0 /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list'
start=$(date +%s)
timeout 90 docker run --rm --name tf-test-localhost --network kafka-tp apache/kafka:4.0.0 \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list 2>&1 | grep -v "^\s*at " | head -8 >> "$out"
note "(durée : $(( $(date +%s) - start )) s)"
docker rm -f tf-test-localhost >/dev/null 2>&1
step "2 bis) Listener EXTERNAL joint depuis le réseau Docker (kafka:9094) : connexion initiale OK, puis adresse annoncée localhost:9092 injoignable"
note '$ docker run --rm --network kafka-tp apache/kafka:4.0.0 /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9094 --list'
start=$(date +%s)
timeout 90 docker run --rm --name tf-test-external --network kafka-tp apache/kafka:4.0.0 \
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9094 --list 2>&1 | grep -v "^\s*at " | head -8 >> "$out"
note "(durée : $(( $(date +%s) - start )) s)"
docker rm -f tf-test-external >/dev/null 2>&1
step "3) Depuis la machine hôte : le port localhost:9092 répond"
note '$ bash -c "echo > /dev/tcp/localhost/9092"   (test de connexion TCP depuis la machine)'
if (echo > /dev/tcp/localhost/9092) 2>/dev/null; then note "connexion TCP établie sur localhost:9092 (port publié vers le listener EXTERNAL)"; else note "connexion impossible"; fi

# --- 7. Scénario TicketFlow ----------------------------------------------
section 07-exercice7-scenario-ticketflow.txt
step "T1 et T2 : deux consommateurs du groupe notification-service (sans --from-beginning)"
docker exec kafka sh -c "cd /opt/kafka/bin && ./kafka-consumer-groups.sh --bootstrap-server kafka:9092 --group notification-service --topic $T --reset-offsets --to-latest --execute" >/dev/null 2>&1
bg T1 notification-service
bg T2 notification-service
sleep 12
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --describe --group notification-service --members"
step "T3 : booking-service publie 9 événements, clé = bookingId, réservations alternées"
produce key \
  'booking-40:{"event":"PaymentSucceeded","bookingId":40}' \
  'booking-41:{"event":"PaymentSucceeded","bookingId":41}' \
  'booking-42:{"event":"PaymentSucceeded","bookingId":42}' \
  'booking-40:{"event":"BookingConfirmed","bookingId":40}' \
  'booking-41:{"event":"BookingConfirmed","bookingId":41}' \
  'booking-42:{"event":"BookingConfirmed","bookingId":42}' \
  'booking-40:{"event":"TicketIssued","bookingId":40}' \
  'booking-41:{"event":"TicketIssued","bookingId":41}' \
  'booking-42:{"event":"TicketIssued","bookingId":42}'
sleep 4
showbg T1; showbg T2
step "Arrêt de T1, puis trois nouveaux événements de booking-40"
stopbg T1
sleep 8
docker exec kafka sh -c ": > /tmp/T2.txt"
produce key 'booking-40:{"event":"RefundRequested","bookingId":40}' 'booking-40:{"event":"RefundApproved","bookingId":40}' 'booking-40:{"event":"BookingCancelled","bookingId":40}'
sleep 4
note "(sortie de T2 vidée avant cette publication)"
showbg T2
k "./kafka-consumer-groups.sh --bootstrap-server \$BS --describe --group notification-service"
stopbg T2

# --- 8. Nettoyage ---------------------------------------------------------
section 08-nettoyage.txt
step "Suppression des topics du TP"
for t in ticketflow.payment.succeeded ticketflow.payment.failed ticketflow.booking.cancelled ticketflow.booking.status; do
  k "./kafka-topics.sh --bootstrap-server \$BS --delete --topic $t"
done
k "./kafka-topics.sh --bootstrap-server \$BS --list"
step "stop / start : les données du conteneur sont conservées"
k "./kafka-topics.sh --bootstrap-server \$BS --create --topic ticketflow.persistance.test --partitions 1 --replication-factor 1"
note '$ docker compose stop'; docker compose stop >> "$out" 2>&1
note '$ docker compose start'; docker compose start >> "$out" 2>&1
sleep 15
k "./kafka-topics.sh --bootstrap-server \$BS --list"
step "down : le conteneur et ses données sont supprimés"
note '$ docker compose down'; docker compose down >> "$out" 2>&1
note '$ docker compose up -d'; docker compose up -d >> "$out" 2>&1
for i in $(seq 1 30); do docker compose logs kafka 2>&1 | grep -q "Kafka Server started" && break; sleep 2; done
k "./kafka-topics.sh --bootstrap-server \$BS --list"
note "(liste vide : le topic ticketflow.persistance.test a disparu avec le conteneur)"
note '$ docker compose down'; docker compose down >> "$out" 2>&1

echo "TP6 termine"
