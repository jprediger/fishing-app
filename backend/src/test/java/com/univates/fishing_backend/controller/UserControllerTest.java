package com.univates.fishing_backend.controller;

import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.univates.fishing_backend.config.TestcontainersConfiguration;
import com.univates.fishing_backend.dto.UserProfileDTO;
import com.univates.fishing_backend.entity.Role;
import com.univates.fishing_backend.service.UserService;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class UserControllerTest {

    @Autowired
    private WebApplicationContext ctx;

    @MockitoBean
    private UserService userService;

    private MockMvc mockMvc;

    @BeforeEach
    void setup() {
        mockMvc =
                MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    @Test
    @WithMockUser(username = "demo@fishing.local", roles = "USER")
    void getProfile_returnsPublicDataWithoutEmail() throws Exception {
        when(userService.getProfile(1L)).thenReturn(sampleProfile());

        mockMvc.perform(get("/api/users/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.name").value("Ana"))
                .andExpect(jsonPath("$.avatarPath").value("avatars/ana.webp"))
                .andExpect(jsonPath("$.role").value("ADMIN"))
                .andExpect(jsonPath("$.catchCount").value(12))
                .andExpect(jsonPath("$.speciesCount").value(5))
                .andExpect(jsonPath("$.waterBodyCount").value(3))
                .andExpect(jsonPath("$.email").doesNotExist());
    }

    private UserProfileDTO sampleProfile() {
        return new UserProfileDTO(
                1L, "Ana", "avatars/ana.webp", Role.ADMIN, OffsetDateTime.parse("2024-01-10T12:00:00Z"), 12L, 5L, 3L);
    }
}
