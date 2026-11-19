package com.ticketflow.bookingservice.config;

import feign.FeignException;
import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;
import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig.SlidingWindowType;
import io.github.resilience4j.timelimiter.TimeLimiterConfig;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.cloud.circuitbreaker.resilience4j.Resilience4JCircuitBreakerFactory;
import org.springframework.cloud.client.circuitbreaker.Customizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * TP5 - Configuration du circuit breaker autour de EventClient#getById(Long).
 * <p>
 * Avec spring.cloud.openfeign.circuitbreaker.alphanumeric-ids.enabled=true,
 * l'instance générée par OpenFeign s'appelle {@value #INSTANCE}.
 *
 * @author Ossama Elmansouri
 */
@Configuration
@EnableConfigurationProperties(EventServiceResilienceProperties.class)
public class ResilienceConfig {

    /** Nom de l'instance de circuit breaker générée pour EventClient#getById(Long). */
    public static final String INSTANCE = "EventClientgetByIdLong";

    private static final Logger log = LoggerFactory.getLogger(ResilienceConfig.class);

    /**
     * Règles du circuit :
     * fenêtre glissante par nombre d'appels, calcul à partir de minimumNumberOfCalls,
     * ouverture au-delà du seuil d'échec, passage en HALF_OPEN au premier appel
     * après waitInOpenState. Les 404 et 400 (erreurs du client, pas pannes du service)
     * sont ignorés : ni échec, ni succès.
     */
    static CircuitBreakerConfig circuitBreakerConfig(EventServiceResilienceProperties p) {
        return CircuitBreakerConfig.custom()
                .slidingWindowType(SlidingWindowType.COUNT_BASED)
                .slidingWindowSize(p.slidingWindowSize())
                .minimumNumberOfCalls(p.minimumNumberOfCalls())
                .failureRateThreshold(p.failureRateThreshold())
                .waitDurationInOpenState(p.waitInOpenState())
                .permittedNumberOfCallsInHalfOpenState(p.permittedCallsInHalfOpenState())
                .ignoreExceptions(FeignException.NotFound.class, FeignException.BadRequest.class)
                .build();
    }

    /** Instances déjà équipées des journaux d'événements (évite d'ajouter un abonné à chaque appel). */
    private final Set<String> observedBreakers = ConcurrentHashMap.newKeySet();

    @Bean
    Customizer<Resilience4JCircuitBreakerFactory> eventServiceCircuitBreaker(EventServiceResilienceProperties p) {
        return factory -> {
            factory.configure(builder -> builder.circuitBreakerConfig(circuitBreakerConfig(p)), INSTANCE);
            // Spring Cloud CircuitBreaker 5.0.x lit la limite de temps dans le
            // TimeLimiterRegistry (et non dans configure(...)) : sans cette ligne,
            // la valeur par défaut de 1 s s'applique (constaté pendant les tests).
            factory.getTimeLimiterRegistry().addConfiguration(INSTANCE,
                    TimeLimiterConfig.custom().timeoutDuration(p.timeLimit()).build());
            // Le customizer est rappelé à chaque création du wrapper : on n'abonne
            // les journaux qu'une fois par circuit.
            factory.addCircuitBreakerCustomizer(cb -> {
                if (!observedBreakers.add(cb.getName())) {
                    return;
                }
                cb.getEventPublisher()
                        .onStateTransition(e -> log.warn("Circuit {} : {}", e.getCircuitBreakerName(),
                                e.getStateTransition()))
                        .onCallNotPermitted(e -> log.warn("Circuit {} OPEN : appel refusé sans appel réseau",
                                e.getCircuitBreakerName()))
                        .onIgnoredError(e -> log.info("Circuit {} : erreur ignorée ({})", e.getCircuitBreakerName(),
                                e.getThrowable().getClass().getSimpleName()))
                        .onError(e -> log.info("Circuit {} : échec compté ({}, {} ms), taux = {} %",
                                e.getCircuitBreakerName(), e.getThrowable().getClass().getSimpleName(),
                                e.getElapsedDuration().toMillis(), cb.getMetrics().getFailureRate()));
            }, INSTANCE);
            log.info("Circuit breaker {} configuré : {}", INSTANCE, p);
        };
    }
}
