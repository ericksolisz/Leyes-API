package com.example.LeyesAPI;

import org.springframework.boot.SpringApplication;

public class TestLeyesApiApplication {

	public static void main(String[] args) {
		SpringApplication.from(LeyesApiApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
