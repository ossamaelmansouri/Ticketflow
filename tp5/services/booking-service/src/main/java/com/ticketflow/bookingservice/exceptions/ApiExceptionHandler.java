package com.ticketflow.bookingservice.exceptions;

import feign.FeignException;
import feign.RetryableException;
import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * Traduit les erreurs (locales et distantes) en réponses RFC 9457 (application/problem+json).
 * Une erreur d'event-service n'est jamais transformée en succès.
 *
 * @author Ossama Elmansouri
 */
@RestControllerAdvice
public class ApiExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler({EventNotFoundException.class, ResourceNotFoundException.class})
    ProblemDetail notFound(RuntimeException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    @ExceptionHandler(BookingRuleException.class)
    ProblemDetail rule(BookingRuleException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.getMessage());
    }

    @ExceptionHandler(UpstreamUnavailableException.class)
    ProblemDetail upstream(UpstreamUnavailableException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.SERVICE_UNAVAILABLE, ex.getMessage());
    }

    /*
     * TP5 section 4 - Filet de sécurité. BookingService traduit déjà ces cas ;
     * si une exception Feign ou Resilience4j remontait telle quelle, le 404 reste
     * 404 et l'accès distant en échec ou le circuit ouvert deviennent 503.
     */
    @ExceptionHandler(FeignException.NotFound.class)
    ProblemDetail remoteNotFound(FeignException.NotFound ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, "Resource not found in event-service");
    }

    @ExceptionHandler({RetryableException.class, CallNotPermittedException.class})
    ProblemDetail remoteUnavailable(Exception ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.SERVICE_UNAVAILABLE, "event-service unavailable");
    }
}
