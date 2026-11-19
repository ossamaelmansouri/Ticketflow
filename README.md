# TicketFlow — TP Architecture microservices

**Auteur : Ossama Elmansouri**
Module : Architecture microservices (Pr. Ahaidous), 2026/2027
Stack : Java 21, Spring Boot 4.0.8, Spring Cloud 2025.1.2

Chaque TP se trouve dans son propre dossier et contient le projet TicketFlow complet tel qu'il est à la fin de ce TP. Chaque dossier se lance indépendamment des autres.

Le dossier [`ticketflow-config/`](ticketflow-config/) contient la configuration centralisée lue par Config Server à partir du TP3.

| TP | Dossier | Sujet | État |
|---|---|---|---|
| TP1 | [`tp1/`](tp1/) | Spring Cloud Gateway : route statique vers customer-service | Terminé |
| TP2 | [`tp2/`](tp2/) | Eureka : discovery-server, route `lb://customer-service`, option Discovery Locator | Terminé |
| TP3 | [`tp3/`](tp3/) | Config Server + GitHub : configuration centralisée, refresh sans redémarrage, profil dev | Terminé |
| TP4 | [`tp4/`](tp4/) | OpenFeign : booking-service appelle event-service par son nom Eureka, gestion des erreurs et délais | Terminé |
| TP5 | [`tp5/`](tp5/) | Circuit Breaker Resilience4j : ouverture mesurée, 404 ignorés, HALF_OPEN puis CLOSED | Terminé |
| TP6 | `tp6/` | — | À venir |
