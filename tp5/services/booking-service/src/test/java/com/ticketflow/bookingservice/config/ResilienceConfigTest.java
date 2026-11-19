package com.ticketflow.bookingservice.config;

import static org.assertj.core.api.Assertions.assertThat;

import feign.FeignException;
import feign.Request;
import feign.Response;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreaker.State;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;

/**
 * TP5 - Vérifie les règles du circuit avec les seuils du TP (sans réseau ni Spring).
 *
 * @author Ossama Elmansouri
 */
class ResilienceConfigTest {

    private static final EventServiceResilienceProperties TP5 = new EventServiceResilienceProperties(
            10, 5, 50, Duration.ofSeconds(10), 3, Duration.ofSeconds(4));

    private static CircuitBreaker newBreaker() {
        return CircuitBreaker.of(ResilienceConfig.INSTANCE, ResilienceConfig.circuitBreakerConfig(TP5));
    }

    private static FeignException feign(int status) {
        Request request = Request.create(Request.HttpMethod.GET, "http://event-service/api/events/1",
                Map.of(), null, StandardCharsets.UTF_8, null);
        return FeignException.errorStatus("EventClient#getById(Long)",
                Response.builder().status(status).reason("x").request(request).headers(Map.of()).build());
    }

    private static void fail(CircuitBreaker cb, Throwable t) {
        cb.onError(0, TimeUnit.MILLISECONDS, t);
    }

    @Test
    void opensOnFifthConsecutiveFailure() {
        CircuitBreaker cb = newBreaker();
        for (int i = 1; i <= 4; i++) {
            fail(cb, feign(503));
            assertThat(cb.getState()).as("après %d échecs", i).isEqualTo(State.CLOSED);
        }
        fail(cb, feign(503));
        assertThat(cb.getState()).isEqualTo(State.OPEN);
        assertThat(cb.tryAcquirePermission()).as("OPEN : appel refusé").isFalse();
    }

    @Test
    void twoFailuresOutOfFiveDoNotOpen() {
        CircuitBreaker cb = newBreaker();
        fail(cb, feign(503));
        fail(cb, feign(503));
        for (int i = 0; i < 3; i++) {
            cb.onSuccess(0, TimeUnit.MILLISECONDS);
        }
        assertThat(cb.getMetrics().getFailureRate()).isEqualTo(40f);
        assertThat(cb.getState()).isEqualTo(State.CLOSED);
    }

    @Test
    void notFoundAndBadRequestAreIgnored() {
        CircuitBreaker cb = newBreaker();
        for (int i = 0; i < 6; i++) {
            fail(cb, feign(404));
        }
        fail(cb, feign(400));
        assertThat(cb.getMetrics().getNumberOfFailedCalls()).isZero();
        assertThat(cb.getMetrics().getNumberOfBufferedCalls()).isZero();
        assertThat(cb.getState()).isEqualTo(State.CLOSED);
    }
}
