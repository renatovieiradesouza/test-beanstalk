package com.example.hellowar;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class HelloWarApplication extends SpringBootServletInitializer {

    @GetMapping("/")
    public String hello() {
        return "Hello World from WAR WORLD CUP FANTASY FINALS";
    }

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
        return builder.sources(HelloWarApplication.class);
    }

    public static void main(String[] args) {
        SpringApplication.run(HelloWarApplication.class, args);
    }
}


