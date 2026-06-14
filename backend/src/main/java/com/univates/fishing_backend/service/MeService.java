package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.UpdateMeRequestDTO;
import com.univates.fishing_backend.dto.UserResponseDTO;
import com.univates.fishing_backend.entity.User;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional
public class MeService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional(readOnly = true)
    public UserResponseDTO getByEmail(String email) {
        return UserResponseDTO.from(loadByEmail(email));
    }

    public UserResponseDTO updateByEmail(String email, UpdateMeRequestDTO dto) {
        User user = loadByEmail(email);
        user.setName(dto.name());
        if (dto.password() != null && !dto.password().isBlank()) {
            user.setPassword(passwordEncoder.encode(dto.password()));
        }
        return UserResponseDTO.from(userRepository.save(user));
    }

    private User loadByEmail(String email) {
        return userRepository.findByEmail(email)
            .orElseThrow(() -> new ResourceNotFoundException("User not found: " + email));
    }
}
