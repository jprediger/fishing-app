package com.univates.fishing_backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.univates.fishing_backend.dto.LoginRequestDTO;
import com.univates.fishing_backend.dto.LoginResponseDTO;
import com.univates.fishing_backend.dto.RegisterRequestDTO;
import com.univates.fishing_backend.entity.Role;
import com.univates.fishing_backend.entity.User;
import com.univates.fishing_backend.exception.EmailAlreadyRegisteredException;
import com.univates.fishing_backend.repository.UserRepository;
import com.univates.fishing_backend.security.TokenService;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    @Mock
    private AuthenticationManager authenticationManager;

    @Mock
    private TokenService tokenService;

    @InjectMocks
    private AuthService authService;

    @Test
    void register_newEmail_savesHashedUserAsUser() {
        when(userRepository.existsByEmail("joao@univates.br")).thenReturn(false);
        when(passwordEncoder.encode("strongPass123")).thenReturn("HASH");

        authService.register(new RegisterRequestDTO("João", "Joao@Univates.BR", "strongPass123"));

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(captor.capture());
        User saved = captor.getValue();
        assertThat(saved.getEmail()).isEqualTo("joao@univates.br"); // normalizado
        assertThat(saved.getPassword()).isEqualTo("HASH"); // hash, não texto puro
        assertThat(saved.getRole()).isEqualTo(Role.USER);
    }

    @Test
    void register_existingEmail_throwsConflict() {
        when(userRepository.existsByEmail("joao@univates.br")).thenReturn(true);

        assertThatThrownBy(
                        () -> authService.register(new RegisterRequestDTO("João", "joao@univates.br", "strongPass123")))
                .isInstanceOf(EmailAlreadyRegisteredException.class);

        verify(userRepository, never()).save(any());
    }

    @Test
    void login_validCredentials_returnsTokenAndUser() {
        Authentication auth = new UsernamePasswordAuthenticationToken("joao@univates.br", "x");
        when(authenticationManager.authenticate(any())).thenReturn(auth);
        when(tokenService.generate(auth)).thenReturn(new TokenService.TokenResult("TOKEN", 604800));
        when(userRepository.findByEmail("joao@univates.br"))
                .thenReturn(Optional.of(User.builder()
                        .id(1L)
                        .name("João")
                        .email("joao@univates.br")
                        .role(Role.USER)
                        .active(true)
                        .build()));

        LoginResponseDTO response = authService.login(new LoginRequestDTO("joao@univates.br", "x"));

        assertThat(response.token()).isEqualTo("TOKEN");
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.expiresIn()).isEqualTo(604800);
        assertThat(response.user().email()).isEqualTo("joao@univates.br");
        assertThat(response.user().role()).isEqualTo(Role.USER);
    }

    @Test
    void login_invalidCredentials_propagatesAuthException() {
        when(authenticationManager.authenticate(any())).thenThrow(new BadCredentialsException("bad"));

        assertThatThrownBy(() -> authService.login(new LoginRequestDTO("joao@univates.br", "wrong")))
                .isInstanceOf(BadCredentialsException.class);
    }
}
