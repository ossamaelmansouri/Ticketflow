# TP3 — Configuration centralisée avec Config Server et GitHub

**Auteur : Ossama Elmansouri**
Module : Architecture microservices (Pr. Ahaidous), 2026/2027

## Objectif

Sortir la configuration de TicketFlow du code : les fichiers de configuration sont versionnés dans GitHub, `config-server` (port 8888) les lit et les sert aux applications. On prouve ensuite qu'une valeur métier peut changer **sans redémarrer** `customer-service`.

```
Configuration : GitHub (ticketflow-config) → config-server :8888 → customer-service, api-gateway
Découverte    : api-gateway + customer-service ↔ discovery-server (Eureka) :8761
Trafic métier : client → api-gateway :8080 → customer-service :8081
```

Config Server n'est ni un registre ni un proxy : il n'est pas client Eureka, et `discovery-server` garde sa configuration locale (pas de dépendance circulaire au démarrage).

## Dépôt de configuration

Comme le demande l'énoncé, la configuration est dans un dépôt GitHub séparé : **[ossamaelmansouri/ticketflow-config](https://github.com/ossamaelmansouri/ticketflow-config)**, branche `main`, fichiers à la racine. Son historique suit les étapes du TP :

| Commit | Message | Étape |
|---|---|---|
| `e7903de` | Centraliser la configuration TicketFlow | Sections 2 et 3 (message v1) |
| `3dd8f4b` | Modifier le message TicketFlow | Section 9 (message v2) |
| `f8c5732` | Ajouter le profil dev | Section 10 |
| `6237488` | Ajouter event-service et booking-service (TP4, TP5) | Suite de la série |

Le champ `version` renvoyé par Config Server correspond à ces commits (par exemple `e7903de…` au démarrage, puis `3dd8f4b…` après le push de v2).

## Travail réalisé

| Section | Fichier | Modification |
|---|---|---|
| 2 | `application.yml` (dépôt ticketflow-config) | Propriétés partagées : URL Eureka, `prefer-ip-address` |
| 2 | `customer-service.yml` (dépôt ticketflow-config) | Port 8081, Actuator `health,info,refresh`, `ticketflow.message` |
| 3 | `api-gateway.yml` (dépôt ticketflow-config) | Port 8080, route explicite `lb://customer-service`, Locator désactivé, Actuator gateway en lecture seule |
| 4 | `pom.xml` + `services/config-server/` | Module `config-server` : `spring-cloud-config-server`, Actuator, `@EnableConfigServer` |
| 5 | `config-server/.../application.yml` | Port 8888, backend Git `${CONFIG_GIT_URI}`, label `main`, `clone-on-start`, `refresh-rate: 0` |
| 6 | POM de `customer-service` et `api-gateway` | `spring-cloud-starter-config` |
| 6 | `customer-service/.../application.properties` | Seulement le nom, l'import obligatoire `configserver:http://localhost:8888`, le label et JPA |
| 6 | `api-gateway/.../application.yml` | Configuration minimale : nom, import, label |
| 7 | `controllers/ConfigDemoController.java` | `GET /api/config/message`, bean `@RefreshScope` |
| 9 | `customer-service.yml` (dépôt ticketflow-config) | Message v1 → v2 (commit poussé) |
| 10 | `customer-service-dev.yml` (dépôt ticketflow-config) | Profil `dev` |
| 12 | `customer-service/src/test/resources/application.properties` | Tests isolés : `spring.cloud.config.enabled=false`, Eureka désactivé, `ticketflow.message` fourni |
| — | `customer-service.yml` (dépôt ticketflow-config) | Correctif `eureka.client.refresh.enable: false` (voir « Dépannage rencontré ») |

## Exécution

Depuis `tp3/` :

```bash
export CONFIG_GIT_URI=https://github.com/ossamaelmansouri/ticketflow-config.git
./mvnw -pl services/config-server spring-boot:run       # 1. 8888 (rester actif)
./mvnw -pl services/discovery-server spring-boot:run    # 2. 8761
./mvnw -pl services/customer-service spring-boot:run    # 3. 8081
./mvnw -pl services/api-gateway spring-boot:run         # 4. 8080

bash scripts/test-tp3.sh config          # section 5
bash scripts/test-tp3.sh initial         # section 8
# git push du message v2, puis :
bash scripts/test-tp3.sh avant-refresh   # section 9 : 8888 en v2, service en v1
bash scripts/test-tp3.sh refresh         # section 9 : POST /actuator/refresh, puis v2
bash scripts/test-tp3.sh profil-dev      # section 10
# relancer customer-service avec -Dspring-boot.run.profiles=dev, puis :
bash scripts/test-tp3.sh service-dev
```

## Résultats obtenus (exécution du 19/11/2026)

### Section 5 : Config Server lit GitHub

`/actuator/health` → `200 UP`. `/customer-service/default/main` et `/api-gateway/default/main` → `200`, `label: main`, `version` = commit Git lu. `propertySources` contient le fichier du service **et** `application.yml` partagé (`server.port`, `eureka.client.service-url.defaultZone`, `ticketflow.message`).

| Capture | Contenu |
|---|---|
| ![](captures/capture-12-config-customer-service.png) | Configuration de customer-service servie par 8888 |
| ![](captures/capture-13-config-api-gateway.png) | Configuration de api-gateway (route `lb://`) |
| ![](captures/capture-14-verifications-config.png) | Vérifications : toutes OK |

### Section 8 : démarrage avec la configuration de GitHub

![Tableau de bord Eureka](captures/capture-10-eureka-dashboard.png)

*CUSTOMER-SERVICE et API-GATEWAY sont UP. Config Server n'apparaît pas dans le registre, comme attendu.*

| Capture | Contenu |
|---|---|
| ![](captures/capture-22-message-v1.png) | `GET /api/config/message` sur 8081 → v1 |
| ![](captures/capture-23-routes-gateway.png) | Route de la gateway venue de GitHub : `lb://customer-service` |
| ![](captures/capture-24-flux-metier.png) | Flux métier via 8080 : POST 201 (Salma), GET 200, `X-Served-By` |
| ![](captures/capture-25-verifications-demarrage.png) | Vérifications : toutes OK |

### Section 9 : modifier GitHub sans redémarrer

| Moment | Config Server (8888) | Service (8081) |
|---|---|---|
| Démarrage | v1 | **v1** |
| Après `git push` de v2, avant refresh | v2 | **v1** |
| Après `POST /actuator/refresh` (200, clés `config.client.version`, `ticketflow.message`) | v2 | **v2** |

Aucun processus n'a été arrêté : Salma est toujours dans la liste après le refresh.

| Capture | Contenu |
|---|---|
| ![](captures/capture-31-config-server-v2.png) | Après le push : 8888 sert v2 |
| ![](captures/capture-32-service-encore-v1.png) | Le service répond encore v1 |
| ![](captures/capture-41-post-refresh-200.png) | `POST /actuator/refresh` → 200 + clés modifiées |
| ![](captures/capture-42-message-v2.png) | Message v2, Salma toujours présente |

### Section 10 : profil dev

| Capture | Contenu |
|---|---|
| ![](captures/capture-51-config-profil-dev.png) | `/customer-service/dev/main` : le fichier `-dev` l'emporte |
| ![](captures/capture-61-service-profil-dev.png) | Service relancé avec `profiles=dev` → « TicketFlow - profil dev » |

### Tests unitaires (section 12)

`./mvnw -pl services/customer-service test` : **7 tests, 0 échec, BUILD SUCCESS** (`captures/07-tests-unitaires.txt`), sans Config Server ni Eureka démarrés.

Les sorties brutes sont dans [`captures/`](captures/) : fichiers `01` à `07`, logs `log-*.log`, et `00-git-push.txt` avec les commits poussés vers ticketflow-config. Le tableau de bord Eureka est une capture Edge headless ; les autres images reprennent les sorties des tests.

## Dépannage rencontré

**Symptôme.** Au premier passage, `POST /actuator/refresh` répondait **500** (`captures/00-refresh-500-avant-correctif.txt`). Le message passait quand même en v2.

![](captures/capture-00-refresh-500-avant-correctif.png)

**Cause.** Le log montre `NullPointerException` dans `DiscoveryClient.updateInstanceRemoteStatus`, appelé depuis `RefreshScope.refreshAll`. Par défaut, le refresh recrée aussi le **client Eureka**, et cette recréation échoue. Le bean `ConfigDemoController` était bien recréé (d'où la v2), mais la réponse globale était une erreur.

**Correction.** `eureka.client.refresh.enable: false` dans `customer-service.yml` (dépôt de configuration). Le client Eureka n'est plus recréé pendant un refresh, ce qui n'est pas nécessaire pour recharger `ticketflow.message`. Le scénario complet a ensuite été rejoué avec le correctif. Depuis, `POST /actuator/refresh` répond **200** avec la liste des clés modifiées.

## Bilan

- La configuration est centralisée et versionnée : chaque changement est un commit Git, visible dans l'historique.
- `refresh-rate: 0` fait relire Git à chaque requête de config, mais **ne pousse rien** vers les applications. Il faut un `POST /actuator/refresh` sur chaque instance concernée (ou un mécanisme comme Spring Cloud Bus).
- `@RefreshScope` suffit pour une propriété simple. Un port, une DataSource ou les routes de la gateway demandent un redémarrage contrôlé.
- **Sécurité** : Config Server expose la configuration en HTTP. Aucun secret n'est dans les fichiers. Pour un dépôt privé, il faut un jeton passé par variable d'environnement (`CONFIG_GIT_TOKEN`), jamais commité.
