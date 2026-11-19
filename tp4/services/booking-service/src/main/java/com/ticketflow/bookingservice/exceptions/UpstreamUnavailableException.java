package com.ticketflow.bookingservice.exceptions;

/**
 * event-service n'a pas pu répondre (aucune instance, délai dépassé, erreur 5xx) : HTTP 503.
 *
 * @author Ossama Elmansouri
 */
public class UpstreamUnavailableException extends RuntimeException {

    public UpstreamUnavailableException(String message, Throwable cause) {
        super(message, cause);
    }
}
