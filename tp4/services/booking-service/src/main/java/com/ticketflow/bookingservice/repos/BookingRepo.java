package com.ticketflow.bookingservice.repos;

import com.ticketflow.bookingservice.entities.Booking;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** @author Ossama Elmansouri */
public interface BookingRepo extends JpaRepository<Booking, Long> {

    /** Nombre de places déjà réservées pour un événement. */
    @Query("select coalesce(sum(b.quantity), 0) from Booking b where b.eventId = :eventId")
    int sumQuantityByEventId(@Param("eventId") Long eventId);
}
