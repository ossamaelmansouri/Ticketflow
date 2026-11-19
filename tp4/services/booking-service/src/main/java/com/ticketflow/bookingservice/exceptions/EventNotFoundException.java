package com.ticketflow.bookingservice.exceptions;

/**
 * L'événement demandé n'existe pas : event-service a répondu 404.
 * booking-service le présente aussi en 404 (et non en succès).
 *
 * @author Ossama Elmansouri
 */
public class EventNotFoundException extends RuntimeException {

    public EventNotFoundException(Long eventId) {
        super("Event " + eventId + " not found (event-service answered 404)");
    }
}
