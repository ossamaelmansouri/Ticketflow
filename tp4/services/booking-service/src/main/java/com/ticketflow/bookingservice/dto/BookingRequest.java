package com.ticketflow.bookingservice.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/** @author Ossama Elmansouri */
public record BookingRequest(
        @NotNull @Positive Long eventId,
        @NotNull @Positive Long customerId,
        @Positive @Max(10) int quantity) {
}
