package com.ticketflow.bookingservice.clients;

import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

/**
 * TP4 - Client OpenFeign vers event-service.
 * <p>
 * {@code name = "event-service"} est le spring.application.name d'event-service :
 * Eureka + Spring Cloud LoadBalancer choisissent l'instance. Pas d'attribut
 * {@code url}, qui contournerait la découverte. L'appel ne passe pas par la gateway.
 *
 * @author Ossama Elmansouri
 */
@FeignClient(name = "event-service")
public interface EventClient {

    /** Reprend exactement le contrat d'event-service : GET /api/events/{id}. */
    @GetMapping("/api/events/{id}")
    EventResponse getById(@PathVariable("id") Long id);
}
