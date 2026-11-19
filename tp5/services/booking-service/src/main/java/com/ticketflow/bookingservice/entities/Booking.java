package com.ticketflow.bookingservice.entities;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;

/**
 * TP4 - Réservation. Le titre et le prix unitaire sont une copie des valeurs
 * lues dans event-service au moment de la réservation.
 *
 * @author Ossama Elmansouri
 */
@Entity
@Table(name = "bookings")
public class Booking {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long eventId;

    @Column(nullable = false)
    private String eventTitle;

    @Column(nullable = false)
    private Long customerId;

    @Column(nullable = false)
    private int quantity;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal unitPrice;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal totalPrice;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    protected Booking() {
        // requis par JPA
    }

    public Booking(Long eventId, String eventTitle, Long customerId, int quantity, BigDecimal unitPrice) {
        this.eventId = eventId;
        this.eventTitle = eventTitle;
        this.customerId = customerId;
        this.quantity = quantity;
        this.unitPrice = unitPrice;
        this.totalPrice = unitPrice.multiply(BigDecimal.valueOf(quantity));
    }

    public Long getId() { return id; }
    public Long getEventId() { return eventId; }
    public String getEventTitle() { return eventTitle; }
    public Long getCustomerId() { return customerId; }
    public int getQuantity() { return quantity; }
    public BigDecimal getUnitPrice() { return unitPrice; }
    public BigDecimal getTotalPrice() { return totalPrice; }
    public Instant getCreatedAt() { return createdAt; }
}
