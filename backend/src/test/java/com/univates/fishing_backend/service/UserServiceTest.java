package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.UserRequestDTO;
import com.univates.fishing_backend.dto.UserResponseDTO;
import com.univates.fishing_backend.dto.UserUpdateDTO;
import com.univates.fishing_backend.entity.User;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    private User sampleUser() {
        return User.builder()
            .id(1L)
            .name("John Smith")
            .email("john@example.com")
            .password("password123")
            .active(true)
            .createdAt(OffsetDateTime.now())
            .build();
    }

    @Test
    void findAll_returnsMappedPage() {
        Pageable pageable = PageRequest.of(0, 20);
        when(userRepository.findAll(pageable)).thenReturn(new PageImpl<>(List.of(sampleUser())));

        var result = userService.findAll(pageable);

        assertThat(result.getContent()).hasSize(1);
        assertThat(result.getContent().get(0).name()).isEqualTo("John Smith");
        assertThat(result.getContent().get(0).email()).isEqualTo("john@example.com");
    }

    @Test
    void findById_userExists_returnsDTO() {
        when(userRepository.findById(1L)).thenReturn(Optional.of(sampleUser()));

        UserResponseDTO result = userService.findById(1L);

        assertThat(result.id()).isEqualTo(1L);
        assertThat(result.name()).isEqualTo("John Smith");
    }

    @Test
    void findById_userDoesNotExist_throwsException() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userService.findById(99L))
            .isInstanceOf(ResourceNotFoundException.class)
            .hasMessageContaining("99");
    }

    @Test
    void create_validDto_savesAndReturnsDTO() {
        UserRequestDTO dto = new UserRequestDTO("Mary", "mary@example.com", "password123");

        User saved = User.builder()
            .id(2L).name("Mary").email("mary@example.com").password("password123")
            .active(true).createdAt(OffsetDateTime.now())
            .build();

        when(userRepository.existsByEmail("mary@example.com")).thenReturn(false);
        when(userRepository.save(any())).thenReturn(saved);

        UserResponseDTO result = userService.create(dto);

        assertThat(result.id()).isEqualTo(2L);
        assertThat(result.name()).isEqualTo("Mary");
        verify(userRepository).save(any(User.class));
    }

    @Test
    void create_duplicateEmail_throwsException() {
        UserRequestDTO dto = new UserRequestDTO("Mary", "mary@example.com", "password123");
        when(userRepository.existsByEmail("mary@example.com")).thenReturn(true);

        assertThatThrownBy(() -> userService.create(dto))
            .isInstanceOf(DataIntegrityViolationException.class)
            .hasMessageContaining("mary@example.com");

        verify(userRepository, never()).save(any());
    }

    @Test
    void update_userExists_updatesFieldsAndReturnsDTO() {
        User existing = sampleUser();
        UserUpdateDTO dto = new UserUpdateDTO("John Updated", "new@example.com", "newPassword", false);

        when(userRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.existsByEmailAndIdNot("new@example.com", 1L)).thenReturn(false);
        when(userRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        UserResponseDTO result = userService.update(1L, dto);

        assertThat(result.name()).isEqualTo("John Updated");
        assertThat(result.email()).isEqualTo("new@example.com");
        assertThat(result.active()).isFalse();

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(captor.capture());
        assertThat(captor.getValue().getPassword()).isEqualTo("newPassword");
    }

    @Test
    void update_blankPassword_keepsCurrentPassword() {
        User existing = sampleUser();
        UserUpdateDTO dto = new UserUpdateDTO("John", "john@example.com", "  ", true);

        when(userRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(userRepository.existsByEmailAndIdNot("john@example.com", 1L)).thenReturn(false);
        when(userRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        userService.update(1L, dto);

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(captor.capture());
        assertThat(captor.getValue().getPassword()).isEqualTo("password123");
    }

    @Test
    void update_userDoesNotExist_throwsException() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());
        UserUpdateDTO dto = new UserUpdateDTO("X", "x@example.com", null, true);

        assertThatThrownBy(() -> userService.update(99L, dto))
            .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void update_emailOfAnotherUser_throwsException() {
        when(userRepository.findById(1L)).thenReturn(Optional.of(sampleUser()));
        when(userRepository.existsByEmailAndIdNot("taken@example.com", 1L)).thenReturn(true);
        UserUpdateDTO dto = new UserUpdateDTO("John", "taken@example.com", null, true);

        assertThatThrownBy(() -> userService.update(1L, dto))
            .isInstanceOf(DataIntegrityViolationException.class)
            .hasMessageContaining("taken@example.com");

        verify(userRepository, never()).save(any());
    }

    @Test
    void delete_userExists_callsDeleteById() {
        when(userRepository.existsById(1L)).thenReturn(true);

        userService.delete(1L);

        verify(userRepository).deleteById(1L);
    }

    @Test
    void delete_userDoesNotExist_throwsException() {
        when(userRepository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> userService.delete(99L))
            .isInstanceOf(ResourceNotFoundException.class)
            .hasMessageContaining("99");
    }
}
