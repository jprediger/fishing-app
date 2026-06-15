package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.UserProfileDTO;
import com.univates.fishing_backend.entity.User;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.CatchRepository;
import com.univates.fishing_backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional
public class UserService {

    private final UserRepository userRepository;
    private final CatchRepository catchRepository;

    @Transactional(readOnly = true)
    public UserProfileDTO getProfile(Long id) {
        User user = loadActiveUser(id);
        return new UserProfileDTO(
                user.getId(),
                user.getName(),
                user.getAvatarPath(),
                user.getRole(),
                user.getCreatedAt(),
                catchRepository.countByUser_Id(id),
                catchRepository.countDistinctSpeciesByUser_Id(id),
                catchRepository.countDistinctWaterBodyByUser_Id(id));
    }

    private User loadActiveUser(Long id) {
        User user = userRepository
                .findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with id: " + id));
        if (!Boolean.TRUE.equals(user.getActive())) {
            throw new ResourceNotFoundException("User not found with id: " + id);
        }
        return user;
    }
}
