package com.univates.fishing_backend.controller;

import com.univates.fishing_backend.dto.UserProfileDTO;
import com.univates.fishing_backend.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Profile;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
@Profile("!seed")
@RequiredArgsConstructor
@Tag(name = "Users", description = "Public user profile")
public class UserController {

    private final UserService userService;

    @GetMapping("/{id}")
    @Operation(summary = "Returns a public user profile")
    public UserProfileDTO findById(@PathVariable Long id) {
        return userService.getProfile(id);
    }
}
