package com.ticketflow.bookingservice.exceptions;

/** Réservation inconnue : HTTP 404. @author Ossama Elmansouri */
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }
}
