package com.ticketflow.configserver;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.config.server.EnableConfigServer;

/**
 * TP3 - Config Server : lit le dépôt GitHub ticketflow-config et sert
 * les propriétés aux applications sur le port 8888.
 *
 * @author Ossama Elmansouri
 */
@SpringBootApplication
@EnableConfigServer
public class ConfigServerApplication {
    public static void main(String[] args) {
        SpringApplication.run(ConfigServerApplication.class, args);
    }
}
