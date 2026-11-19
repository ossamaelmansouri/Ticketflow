package com.ticketflow.bookingservice.service;

import com.ticketflow.bookingservice.clients.EventClient;
import com.ticketflow.bookingservice.clients.EventResponse;
import com.ticketflow.bookingservice.dto.BookingRequest;
import com.ticketflow.bookingservice.entities.Booking;
import com.ticketflow.bookingservice.exceptions.BookingRuleException;
import com.ticketflow.bookingservice.exceptions.EventNotFoundException;
import com.ticketflow.bookingservice.exceptions.ResourceNotFoundException;
import com.ticketflow.bookingservice.exceptions.UpstreamUnavailableException;
import com.ticketflow.bookingservice.repos.BookingRepo;
import feign.FeignException;
import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import java.util.concurrent.CompletionException;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeoutException;
import org.springframework.cloud.client.circuitbreaker.NoFallbackAvailableException;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * TP4/TP5 - Cas métier de réservation. Le client Feign est injecté ici (pas dans le
 * contrôleur) : l'événement est vérifié auprès d'event-service avant d'enregistrer.
 *
 * @author Ossama Elmansouri
 */
@Service
public class BookingService {

    private final EventClient eventClient;
    private final BookingRepo repo;

    public BookingService(EventClient eventClient, BookingRepo repo) {
        this.eventClient = eventClient;
        this.repo = repo;
    }

    /**
     * Appel synchrone GET /api/events/{id} via OpenFeign, protégé par le circuit
     * breaker EventClientgetByIdLong (TP5).
     * <ul>
     *   <li>404 distant → {@link EventNotFoundException} (404) ; ignoré par le circuit ;</li>
     *   <li>circuit OPEN ({@link CallNotPermittedException}) → 503 immédiat, sans appel réseau ;</li>
     *   <li>autre erreur (connexion, délai, 5xx) → {@link UpstreamUnavailableException} (503).</li>
     * </ul>
     * Aucun repli ne renvoie un événement « disponible » : une panne n'est jamais une réservation.
     */
    public EventResponse validateEvent(Long eventId) {
        try {
            return eventClient.getById(eventId);
        } catch (RuntimeException ex) {
            throw translate(eventId, unwrap(ex));
        }
    }

    /** Sans fallback, Spring Cloud CircuitBreaker enveloppe l'erreur dans NoFallbackAvailableException. */
    private static Throwable unwrap(Throwable ex) {
        Throwable t = ex;
        while ((t instanceof NoFallbackAvailableException || t instanceof ExecutionException
                || t instanceof CompletionException) && t.getCause() != null) {
            t = t.getCause();
        }
        return t;
    }

    private static RuntimeException translate(Long eventId, Throwable cause) {
        if (cause instanceof FeignException.NotFound) {
            return new EventNotFoundException(eventId);
        }
        if (cause instanceof CallNotPermittedException) {
            return new UpstreamUnavailableException(
                    "event-service unavailable: circuit breaker OPEN, call rejected without network call", cause);
        }
        if (cause instanceof FeignException fe) {
            return new UpstreamUnavailableException(
                    "event-service unavailable (status " + fe.status() + "): " + firstLine(fe.getMessage()), fe);
        }
        if (cause instanceof TimeoutException) {
            return new UpstreamUnavailableException("event-service unavailable: time limit exceeded", cause);
        }
        if (cause instanceof RuntimeException re) {
            return re;
        }
        return new UpstreamUnavailableException("event-service unavailable: " + cause, cause);
    }

    /** L'appel distant a lieu avant la transaction locale : on ne garde pas de transaction ouverte pendant le HTTP. */
    public Booking create(BookingRequest request) {
        EventResponse event = validateEvent(request.eventId());
        if (!event.isPublished()) {
            throw new BookingRuleException(
                    "Event " + event.id() + " is " + event.status() + ": only PUBLISHED events can be booked");
        }
        return save(request, event);
    }

    /**
     * Contrôle simple du nombre de places. Limite connue : deux réservations
     * simultanées peuvent passer le contrôle en même temps (pas de verrou ici).
     */
    private Booking save(BookingRequest request, EventResponse event) {
        int alreadyBooked = repo.sumQuantityByEventId(event.id());
        int remaining = event.capacity() - alreadyBooked;
        if (request.quantity() > remaining) {
            throw new BookingRuleException("Not enough seats for event " + event.id()
                    + ": requested " + request.quantity() + ", remaining " + remaining);
        }
        return repo.save(new Booking(event.id(), event.title(), request.customerId(),
                request.quantity(), event.price()));
    }

    @Transactional(readOnly = true)
    public Booking get(Long id) {
        return repo.findById(id).orElseThrow(() -> new ResourceNotFoundException("Booking " + id + " not found"));
    }

    @Transactional(readOnly = true)
    public List<Booking> list() {
        return repo.findAll();
    }

    private static String firstLine(String message) {
        if (message == null) {
            return "no detail";
        }
        int i = message.indexOf('\n');
        return i < 0 ? message : message.substring(0, i);
    }
}
