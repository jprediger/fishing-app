package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.LoginRequestDTO;
import com.univates.fishing_backend.dto.LoginResponseDTO;
import com.univates.fishing_backend.dto.RegisterRequestDTO;
import com.univates.fishing_backend.dto.UserResponseDTO;
import com.univates.fishing_backend.entity.Role;
import com.univates.fishing_backend.entity.User;
import com.univates.fishing_backend.exception.EmailAlreadyRegisteredException;
import com.univates.fishing_backend.repository.UserRepository;
import com.univates.fishing_backend.security.TokenService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@Profile("!seed")
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final TokenService tokenService;

    @Transactional
    public void register(RegisterRequestDTO request) {
        String email = normalizeEmail(request.email());
        if (userRepository.existsByEmail(email)) {
            throw new EmailAlreadyRegisteredException(email);
        }

        User user = User.builder()
                .name(request.name())
                .email(email)
                .password(passwordEncoder.encode(request.password()))
                .role(Role.USER)
                .active(true)
                .build();

        userRepository.save(user);
        log.info("Novo usuário registrado: {}", user.getEmail());
    }

    @Transactional(readOnly = true)
    public LoginResponseDTO login(LoginRequestDTO request) {
        String email = normalizeEmail(request.email());
        Authentication authentication =
                authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(email, request.password()));

        TokenService.TokenResult result = tokenService.generate(authentication);
        User user = userRepository
                .findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("Usuário autenticado não encontrado: " + email));

        return LoginResponseDTO.bearer(result.token(), result.expiresInSeconds(), UserResponseDTO.from(user));
    }

    private String normalizeEmail(String email) {
        return email == null ? null : email.trim().toLowerCase();
    }
}
