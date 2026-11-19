# TP1 — Ajouter une Spring Cloud Gateway à TicketFlow

**Auteur : Ossama Elmansouri**
Module : Architecture microservices (Pr. Ahaidous), 2026/2027

## Objectif

Ajouter un service `api-gateway` (Spring Cloud Gateway, WebFlux) qui sert de point d'entrée HTTP unique et route les requêtes `/api/customers/**` vers `customer-service`.

```
client ──► api-gateway (localhost:8080) ──► customer-service (localhost:8081)
```

- Point de départ : branche `feature/step-01-customer-service` du dépôt du cours.
- Versions : Java 21, Spring Boot 4.0.8, Spring Cloud 2025.1.2 (BOM importé par `ticketflow-parent`).

## Travail réalisé

| Étape | Fichier | Modification |
|---|---|---|
| 5 | `pom.xml` (racine) | Ajout du module `services/api-gateway` dans `<modules>` |
| 6 | `services/api-gateway/pom.xml` | Starter `spring-cloud-starter-gateway-server-webflux`, Actuator, tests. Pas de Spring MVC ni de starter Servlet, pas de versions individuelles |
| 7 | `services/api-gateway/src/main/java/com/ticketflow/apigateway/ApiGatewayApplication.java` | Classe de démarrage `@SpringBootApplication` |
| 8 | `services/api-gateway/src/main/resources/application.yml` | Port 8080, route statique `customer-service` vers `http://localhost:8081`, filtre `X-Served-By`, endpoints Actuator `health,info,gateway` |
| — | `scripts/test-tp1.sh` | Script qui rejoue tous les tests curl du TP |

### La route déclarée

- `id: customer-service` : nom de la route, visible dans `/actuator/gateway/routes`.
- `uri: http://localhost:8081` : cible écrite en dur. Il n'y a ni Eureka, ni `lb://`, ni load-balancing à cette étape.
- `predicates: Path=/api/customers/**` : la route s'applique à toute URL qui commence par `/api/customers`.
- `filters: AddResponseHeader=X-Served-By, api-gateway` : ajoute à la réponse un en-tête qui prouve le passage par la gateway.

## Exécution

Toutes les commandes se lancent depuis le dossier `tp1/`.

```bash
# Vérifier l'environnement
java -version          # doit afficher 21
./mvnw -version

# Terminal 1 : customer-service (port 8081)
./mvnw -pl services/customer-service spring-boot:run

# Terminal 2 : api-gateway (port 8080)
./mvnw -pl services/api-gateway spring-boot:run

# Terminal 3 : tests
bash scripts/test-tp1.sh
```

## Tests et résultats attendus

```bash
# 1. Création directe (8081) → HTTP 201 + en-tête Location: /api/customers/{id}
curl -i -X POST http://localhost:8081/api/customers \
  -H 'Content-Type: application/json' \
  -d '{"firstName":"Mohamed","lastName":"Amine","email":"med@example.com"}'

# 2. Lecture directe → HTTP 200
curl -i http://localhost:8081/api/customers/ID_CUSTOMER
curl -i http://localhost:8081/api/customers

# 3. Même lecture via la gateway → HTTP 200, même corps + X-Served-By: api-gateway
curl -i http://localhost:8080/api/customers/ID_CUSTOMER

# 4. Création via la gateway → HTTP 201
curl -i -X POST http://localhost:8080/api/customers \
  -H 'Content-Type: application/json' \
  -d '{"firstName":"Amine","lastName":"Bennani","email":"amine.gateway@example.com"}'

# 5. Lecture et liste via la gateway → HTTP 200 + X-Served-By: api-gateway
curl -i http://localhost:8080/api/customers/ID_AMINE
curl -i http://localhost:8080/api/customers

# 6. Routes connues de la gateway (Actuator)
curl -i http://localhost:8080/actuator/gateway/routes
```

Captures d'écran à ajouter dans `captures/` après exécution : démarrage des deux services, réponse directe sur 8081, même réponse via 8080 avec l'en-tête `X-Served-By`, et sortie de `/actuator/gateway/routes`.

## Bilan

- Un appel direct sur 8081 contourne la gateway. Le même appel sur 8080 est routé vers `customer-service` et reçoit l'en-tête `X-Served-By: api-gateway`.
- `customer-service` reste seul responsable des données client. La gateway apporte un point d'entrée unique et le routage HTTP.
- **Limite volontaire** : la cible `http://localhost:8081` est écrite en dur. Si le service change d'adresse ou tourne en plusieurs instances, il faut modifier la configuration. La découverte de services (Eureka, `lb://`) traitera ce problème dans un TP suivant.
