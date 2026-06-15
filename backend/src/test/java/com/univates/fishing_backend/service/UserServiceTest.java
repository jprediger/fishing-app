package com.univates.fishing_backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.univates.fishing_backend.dto.UserProfileDTO;
import com.univates.fishing_backend.entity.Role;
import com.univates.fishing_backend.entity.User;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.CatchRepository;
import com.univates.fishing_backend.repository.UserRepository;
import java.time.OffsetDateTime;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private CatchRepository catchRepository;

    @InjectMocks
    private UserService userService;

    @Test
    void getProfile_returnsPublicProfileWithStats() {
        when(userRepository.findById(1L)).thenReturn(Optional.of(sampleUser()));
        when(catchRepository.countByUser_Id(1L)).thenReturn(12L);
        when(catchRepository.countDistinctSpeciesByUser_Id(1L)).thenReturn(5L);
        when(catchRepository.countDistinctWaterBodyByUser_Id(1L)).thenReturn(3L);

        UserProfileDTO profile = userService.getProfile(1L);

        assertThat(profile.id()).isEqualTo(1L);
        assertThat(profile.name()).isEqualTo("Ana");
        assertThat(profile.avatarPath()).isEqualTo("avatars/ana.webp");
        assertThat(profile.role()).isEqualTo(Role.ADMIN);
        assertThat(profile.memberSince()).isEqualTo(OffsetDateTime.parse("2024-01-10T12:00:00Z"));
        assertThat(profile.catchCount()).isEqualTo(12L);
        assertThat(profile.speciesCount()).isEqualTo(5L);
        assertThat(profile.waterBodyCount()).isEqualTo(3L);
    }

    @Test
    void getProfile_missingOrInactiveUser_throwsNotFound() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userService.getProfile(99L)).isInstanceOf(ResourceNotFoundException.class);
    }

    private User sampleUser() {
        return User.builder()
                .id(1L)
                .name("Ana")
                .email("ana@fishing.local")
                .avatarPath("avatars/ana.webp")
                .role(Role.ADMIN)
                .active(true)
                .createdAt(OffsetDateTime.parse("2024-01-10T12:00:00Z"))
                .build();
    }
}
