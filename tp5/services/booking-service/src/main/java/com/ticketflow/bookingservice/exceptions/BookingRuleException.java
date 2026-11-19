package com.ticketflow.bookingservice.exceptions;

/**
 * Règle métier non respectée (événement non publié, plus assez de places) : HTTP 409.
 *
 * @author Ossama Elmansouri
 */
public class BookingRuleException extends RuntimeException {

    public BookingRuleException(String message) {
        super(message);
    }
}
