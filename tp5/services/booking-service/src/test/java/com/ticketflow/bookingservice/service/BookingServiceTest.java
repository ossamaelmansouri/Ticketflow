package com.ticketflow.bookingservice.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.ticketflow.bookingservice.clients.EventClient;
import com.ticketflow.bookingservice.clients.EventResponse;
import com.ticketflow.bookingservice.dto.BookingRequest;
import com.ticketflow.bookingservice.entities.Booking;
import com.ticketflow.bookingservice.exceptions.BookingRuleException;
import com.ticketflow.bookingservice.exceptions.EventNotFoundException;
import com.ticketflow.bookingservice.exceptions.UpstreamUnavailableException;
import com.ticketflow.bookingservice.repos.BookingRepo;
import feign.FeignException;
import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import org.springframework.cloud.client.circuitbreaker.NoFallbackAvailableException;
import feign.Request;
import feign.Response;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * TP4 - Tests unitaires du cas de réservation, avec un EventClient simulé.
 *
 * @author Ossama Elmansouri
 */
class BookingServiceTest {

    private EventClient eventClient;
    private BookingRepo repo;
    private BookingService service;

    @BeforeEach
    void setUp() {
        eventClient = mock(EventClient.class);
        repo = mock(BookingRepo.class);
        service = new BookingService(eventClient, repo);
        when(repo.save(any(Booking.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private static EventResponse event(long id, String status, int capacity) {
        return new EventResponse(id, "Concert", "desc", "Casablanca",
                Instant.parse("2027-01-15T20:00:00Z"), new BigDecimal("150.00"), capacity, status,
                Instant.parse("2026-11-19T10:00:00Z"));
    }

    private static FeignException feignError(int status) {
        Request request = Request.create(Request.HttpMethod.GET, "http://event-service/api/events/99",
                Map.of(), null, StandardCharsets.UTF_8, null);
        Response response = Response.builder().status(status).reason("error").request(request)
                .headers(Map.of()).build();
        return FeignException.errorStatus("EventClient#getById(Long)", response);
    }

    @Test
    void createsBookingWhenEventIsPublished() {
        when(eventClient.getById(1L)).thenReturn(event(1, "PUBLISHED", 100));

        Booking booking = service.create(new BookingRequest(1L, 7L, 2));

        assertThat(booking.getEventTitle()).isEqualTo("Concert");
        assertThat(booking.getTotalPrice()).isEqualByComparingTo("300.00");
    }

    @Test
    void remote404BecomesEventNotFound() {
        when(eventClient.getById(99L)).thenThrow(feignError(404));

        assertThatThrownBy(() -> service.create(new BookingRequest(99L, 7L, 1)))
                .isInstanceOf(EventNotFoundException.class)
                .hasMessageContaining("99");
        verify(repo, never()).save(any());
    }

    @Test
    void remote503BecomesUpstreamUnavailable() {
        when(eventClient.getById(1L)).thenThrow(feignError(503));

        assertThatThrownBy(() -> service.create(new BookingRequest(1L, 7L, 1)))
                .isInstanceOf(UpstreamUnavailableException.class);
        verify(repo, never()).save(any());
    }

    @Test
    void draftEventIsRejected() {
        when(eventClient.getById(2L)).thenReturn(event(2, "DRAFT", 100));

        assertThatThrownBy(() -> service.create(new BookingRequest(2L, 7L, 1)))
                .isInstanceOf(BookingRuleException.class)
                .hasMessageContaining("DRAFT");
    }

    @Test
    void notEnoughSeatsIsRejected() {
        when(eventClient.getById(1L)).thenReturn(event(1, "PUBLISHED", 5));
        when(repo.sumQuantityByEventId(1L)).thenReturn(4);

        assertThatThrownBy(() -> service.create(new BookingRequest(1L, 7L, 2)))
                .isInstanceOf(BookingRuleException.class)
                .hasMessageContaining("remaining 1");
    }

    // --- TP5 : erreurs vues à travers le circuit breaker ---

    @Test
    void wrappedNotFoundStaysNotFound() {
        when(eventClient.getById(99L)).thenThrow(
                new NoFallbackAvailableException("No fallback available.", feignError(404)));

        assertThatThrownBy(() -> service.create(new BookingRequest(99L, 7L, 1)))
                .isInstanceOf(EventNotFoundException.class);
    }

    @Test
    void openCircuitBecomesUpstreamUnavailable() {
        CircuitBreaker cb = CircuitBreaker.ofDefaults("EventClientgetByIdLong");
        cb.transitionToOpenState();
        when(eventClient.getById(1L)).thenThrow(new NoFallbackAvailableException("No fallback available.",
                CallNotPermittedException.createCallNotPermittedException(cb)));

        assertThatThrownBy(() -> service.create(new BookingRequest(1L, 7L, 1)))
                .isInstanceOf(UpstreamUnavailableException.class)
                .hasMessageContaining("OPEN");
        verify(repo, never()).save(any());
    }
}
