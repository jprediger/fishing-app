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
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
@Transactional
public class MeService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final CatchPhotoStorageService catchPhotoStorageService;

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

    public UserResponseDTO updateAvatarByEmail(String email, MultipartFile file) {
        User user = loadByEmail(email);
        String previousAvatar = user.getAvatarPath();
        String stored = catchPhotoStorageService.store(file);
        user.setAvatarPath(stored);
        User saved = userRepository.save(user);
        if (previousAvatar != null && !previousAvatar.isBlank()) {
            catchPhotoStorageService.delete(previousAvatar);
        }
        return UserResponseDTO.from(saved);
    }

    public UserResponseDTO deleteAvatarByEmail(String email) {
        User user = loadByEmail(email);
        String previousAvatar = user.getAvatarPath();
        user.setAvatarPath(null);
        User saved = userRepository.save(user);
        if (previousAvatar != null && !previousAvatar.isBlank()) {
            catchPhotoStorageService.delete(previousAvatar);
        }
        return UserResponseDTO.from(saved);
    }

    private User loadByEmail(String email) {
        return userRepository
                .findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + email));
    }
}
