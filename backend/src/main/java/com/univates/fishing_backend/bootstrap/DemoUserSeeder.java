package com.univates.fishing_backend.bootstrap;

import com.univates.fishing_backend.entity.Role;
import com.univates.fishing_backend.entity.User;
import com.univates.fishing_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Usuário USER de demonstração, só em ambientes com {@code app.seed.demo.enabled=true}
 * (tipicamente dev). Idempotente.
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.seed.demo.enabled", havingValue = "true")
public class DemoUserSeeder implements DataSeeder {

    private static final String DEMO_EMAIL = "demo@fishing.local";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public int order() {
        return 10;
    }

    @Override
    @Transactional
    public void run() {
        if (userRepository.existsByEmail(DEMO_EMAIL)) {
            return;
        }
        userRepository.save(User.builder()
                .name("Demo User")
                .email(DEMO_EMAIL)
                .password(passwordEncoder.encode("demo12345"))
                .role(Role.USER)
                .active(true)
                .build());
        log.info("Seed demo: USER de demonstração criado ({})", DEMO_EMAIL);
    }
}
