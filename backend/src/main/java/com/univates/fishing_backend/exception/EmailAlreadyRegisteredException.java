package com.univates.fishing_backend.exception;

public class EmailAlreadyRegisteredException extends RuntimeException {

    public EmailAlreadyRegisteredException(String email) {
        super("E-mail já cadastrado: " + email);
    }
}
