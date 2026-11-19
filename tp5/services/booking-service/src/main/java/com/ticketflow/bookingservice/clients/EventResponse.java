package com.ticketflow.bookingservice.clients;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * TP4 - Vue côté booking-service du JSON renvoyé par GET /api/events/{id}.
 * <p>
 * Les champs reprennent exactement ceux du record EventResponse d'event-service
 * (aucune propriété inventée). Le statut est gardé en String pour ne pas coupler
 * booking-service à l'enum interne d'event-service.
 *
 * @author Ossama Elmansouri
 */
public record EventResponse(
        Long id,
        String title,
        String description,
        String venue,
        Instant startsAt,
        BigDecimal price,
        int capacity,
        String status,
        Instant createdAt) {

    public boolean isPublished() {
        return "PUBLISHED".equals(status);
    }
}
