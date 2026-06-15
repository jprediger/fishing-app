package com.univates.fishing_backend.controller;

import com.univates.fishing_backend.dto.UpdateMeRequestDTO;
import com.univates.fishing_backend.dto.UserResponseDTO;
import com.univates.fishing_backend.service.MeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Profile;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/users/me")
@Profile("!seed")
@RequiredArgsConstructor
@Tag(name = "Current user", description = "Self-service for the authenticated user")
public class MeController {

    private final MeService meService;

    @GetMapping
    @Operation(summary = "Returns the authenticated user")
    @ApiResponse(responseCode = "200", description = "Current user")
    public UserResponseDTO me(Authentication authentication) {
        return meService.getByEmail(authentication.getName());
    }

    @PutMapping
    @Operation(summary = "Updates the authenticated user's own name/password")
    @ApiResponse(responseCode = "200", description = "User updated")
    public UserResponseDTO update(Authentication authentication, @Valid @RequestBody UpdateMeRequestDTO dto) {
        return meService.updateByEmail(authentication.getName(), dto);
    }

    @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Uploads the authenticated user's avatar")
    @ApiResponse(responseCode = "200", description = "Avatar updated")
    public UserResponseDTO uploadAvatar(Authentication authentication, @RequestPart("file") MultipartFile file) {
        return meService.updateAvatarByEmail(authentication.getName(), file);
    }

    @DeleteMapping("/avatar")
    @Operation(summary = "Removes the authenticated user's avatar")
    @ApiResponse(responseCode = "200", description = "Avatar removed")
    public UserResponseDTO deleteAvatar(Authentication authentication) {
        return meService.deleteAvatarByEmail(authentication.getName());
    }
}
