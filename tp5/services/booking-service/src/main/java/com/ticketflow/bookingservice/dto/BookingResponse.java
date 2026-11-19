package com.ticketflow.bookingservice.dto;

import com.ticketflow.bookingservice.entities.Booking;
import java.math.BigDecimal;
import java.time.Instant;

/** @author Ossama Elmansouri */
public record BookingResponse(
        Long id,
        Long eventId,
        String eventTitle,
        Long customerId,
        int quantity,
        BigDecimal unitPrice,
        BigDecimal totalPrice,
        Instant createdAt) {

    public static BookingResponse from(Booking b) {
        return new BookingResponse(b.getId(), b.getEventId(), b.getEventTitle(), b.getCustomerId(),
                b.getQuantity(), b.getUnitPrice(), b.getTotalPrice(), b.getCreatedAt());
    }
}
