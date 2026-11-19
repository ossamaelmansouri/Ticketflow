package com.ticketflow.bookingservice.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * TP5 - Seuils du circuit breaker qui protège les appels vers event-service.
 * Valeurs lues dans ticketflow-config/booking-service.yml
 * (préfixe ticketflow.resilience.event-service).
 *
 * @author Ossama Elmansouri
 */
@ConfigurationProperties(prefix = "ticketflow.resilience.event-service")
public record EventServiceResilienceProperties(
        int slidingWindowSize,
        int minimumNumberOfCalls,
        float failureRateThreshold,
        Duration waitInOpenState,
        int permittedCallsInHalfOpenState,
        Duration timeLimit) {

    public EventServiceResilienceProperties {
        if (slidingWindowSize <= 0) slidingWindowSize = 10;
        if (minimumNumberOfCalls <= 0) minimumNumberOfCalls = 5;
        if (failureRateThreshold <= 0) failureRateThreshold = 50;
        if (waitInOpenState == null) waitInOpenState = Duration.ofSeconds(10);
        if (permittedCallsInHalfOpenState <= 0) permittedCallsInHalfOpenState = 3;
        if (timeLimit == null) timeLimit = Duration.ofSeconds(4);
    }
}
