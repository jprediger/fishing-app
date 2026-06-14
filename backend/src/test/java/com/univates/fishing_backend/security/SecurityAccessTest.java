package com.univates.fishing_backend.security;

import com.univates.fishing_backend.config.TestcontainersConfiguration;
import com.univates.fishing_backend.dto.FishResponseDTO;
import com.univates.fishing_backend.dto.IconDTO;
import com.univates.fishing_backend.dto.LoginResponseDTO;
import com.univates.fishing_backend.dto.UserResponseDTO;
import com.univates.fishing_backend.entity.FishType;
import com.univates.fishing_backend.entity.Role;
import com.univates.fishing_backend.service.AuthService;
import com.univates.fishing_backend.service.FishService;
import com.univates.fishing_backend.service.MeService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import java.time.OffsetDateTime;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class SecurityAccessTest {

    @Autowired private WebApplicationContext ctx;

    @MockitoBean private FishService fishService;
    @MockitoBean private MeService meService;
    @MockitoBean private AuthService authService;

    private MockMvc mockMvc;

    @BeforeEach
    void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(ctx)
            .apply(springSecurity())
            .build();
    }

    private static final String FISH_JSON =
        "{\"name\":\"Tucunaré\",\"type\":\"FRESHWATER\",\"icon\":{\"path\":\"/i.png\"}}";

    @Test
    void getCatalog_unauthenticated_returns401() throws Exception {
        mockMvc.perform(get("/api/fish")).andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser
    void getCatalog_authenticated_returns200() throws Exception {
        when(fishService.findById(1L)).thenReturn(sampleFish());
        mockMvc.perform(get("/api/fish/1")).andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "USER")
    void writeCatalog_asUser_returns403() throws Exception {
        mockMvc.perform(post("/api/fish")
                .contentType(MediaType.APPLICATION_JSON).content(FISH_JSON))
            .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void writeCatalog_asAdmin_returns201() throws Exception {
        when(fishService.create(any())).thenReturn(sampleFish());
        mockMvc.perform(post("/api/fish")
                .contentType(MediaType.APPLICATION_JSON).content(FISH_JSON))
            .andExpect(status().isCreated());
    }

    @Test
    @WithMockUser(username = "demo@fishing.local", roles = "USER")
    void updateOwnProfile_asUser_returns200() throws Exception {
        when(meService.updateByEmail(anyString(), any())).thenReturn(sampleUser());
        mockMvc.perform(put("/api/users/me")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Novo Nome\"}"))
            .andExpect(status().isOk());
    }

    @Test
    void login_isPublic() throws Exception {
        when(authService.login(any())).thenReturn(
            LoginResponseDTO.bearer("TOKEN", 604800, sampleUser()));
        mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"demo@fishing.local\",\"password\":\"demo12345\"}"))
            .andExpect(status().isOk());
    }

    private FishResponseDTO sampleFish() {
        return new FishResponseDTO(1L, "Tucunaré", "desc", "RS", FishType.FRESHWATER,
            new IconDTO("/i.png"), OffsetDateTime.now(), null);
    }

    private UserResponseDTO sampleUser() {
        return new UserResponseDTO(1L, "Demo", "demo@fishing.local", Role.USER,
            true, OffsetDateTime.now(), null);
    }
}
