package com.univates.fishing_backend.bootstrap;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.univates.fishing_backend.entity.Role;
import com.univates.fishing_backend.entity.User;
import com.univates.fishing_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class AdminUserSeederTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    private AdminUserSeeder seeder() {
        return new AdminUserSeeder(
                userRepository, passwordEncoder, "Admin@Fishing.local", "admin12345", "Administrator");
    }

    @Test
    void run_whenAbsent_createsAdminWithHashedPassword() {
        when(userRepository.existsByEmail("admin@fishing.local")).thenReturn(false);
        when(passwordEncoder.encode("admin12345")).thenReturn("HASH");

        seeder().run();

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(captor.capture());
        User saved = captor.getValue();
        assertThat(saved.getEmail()).isEqualTo("admin@fishing.local");
        assertThat(saved.getPassword()).isEqualTo("HASH");
        assertThat(saved.getRole()).isEqualTo(Role.ADMIN);
    }

    @Test
    void run_isIdempotent_whenAdminAlreadyExists() {
        lenient().when(passwordEncoder.encode("admin12345")).thenReturn("HASH");
        when(userRepository.existsByEmail("admin@fishing.local")).thenReturn(false, true);

        AdminUserSeeder seeder = seeder();
        seeder.run(); // cria
        seeder.run(); // já existe → não recria

        verify(userRepository, times(1)).save(any(User.class));
    }
}
