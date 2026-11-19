package com.ticketflow.bookingservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.openfeign.EnableFeignClients;

/**
 * TP4 - booking-service : réservations de places.
 * {@code @EnableFeignClients} active le scan des interfaces {@code @FeignClient}
 * (ici dans le sous-package clients, donc couvert par le scan par défaut).
 *
 * @author Ossama Elmansouri
 */
@SpringBootApplication
@EnableFeignClients
public class BookingServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(BookingServiceApplication.class, args);
    }
}
