package com.univates.fishing_backend.controller;

import com.univates.fishing_backend.dto.LoginRequestDTO;
import com.univates.fishing_backend.dto.LoginResponseDTO;
import com.univates.fishing_backend.dto.RegisterRequestDTO;
import com.univates.fishing_backend.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
@Tag(name = "Autenticação", description = "Registro e login de usuários")
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Registra um novo usuário (role USER)")
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "Usuário criado"),
        @ApiResponse(responseCode = "400", description = "Dados inválidos"),
        @ApiResponse(responseCode = "409", description = "E-mail já cadastrado")
    })
    public void register(@Valid @RequestBody RegisterRequestDTO request) {
        authService.register(request);
    }

    @PostMapping("/login")
    @Operation(summary = "Autentica e retorna um token JWT")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Autenticado"),
        @ApiResponse(responseCode = "401", description = "Credenciais inválidas")
    })
    public LoginResponseDTO login(@Valid @RequestBody LoginRequestDTO request) {
        return authService.login(request);
    }
}
