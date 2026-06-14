package com.univates.fishing_backend.bootstrap;

import com.univates.fishing_backend.entity.Role;
import com.univates.fishing_backend.entity.User;
import com.univates.fishing_backend.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Garante a existência de um usuário ADMIN inicial em todos os perfis.
 *
 * <p>Credenciais vêm de {@code app.admin.email} / {@code app.admin.password}
 * (env {@code APP_ADMIN_EMAIL} / {@code APP_ADMIN_PASSWORD}). Em prod não há
 * default — a aplicação falha ao subir se faltarem. Em dev o perfil fornece
 * valores de teste. Idempotente: só cria se o e-mail ainda não existir.
 */
@Slf4j
@Component
public class AdminUserSeeder implements DataSeeder {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final String email;
    private final String password;
    private final String name;

    public AdminUserSeeder(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            @Value("${app.admin.email}") String email,
            @Value("${app.admin.password}") String password,
            @Value("${app.admin.name:Administrator}") String name) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.email = email;
        this.password = password;
        this.name = name;
    }

    @Override
    public int order() {
        return 0;
    }

    @Override
    @Transactional
    public void run() {
        String normalized = email.trim().toLowerCase();
        if (userRepository.existsByEmail(normalized)) {
            log.debug("Seed admin: usuário {} já existe, ignorando", normalized);
            return;
        }

        userRepository.save(User.builder()
            .name(name)
            .email(normalized)
            .password(passwordEncoder.encode(password))
            .role(Role.ADMIN)
            .active(true)
            .build());

        log.info("Seed admin: ADMIN criado ({})", normalized);
    }
}
