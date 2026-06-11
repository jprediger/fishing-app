package com.univates.fishing_backend.controller;

import com.univates.fishing_backend.config.TestcontainersConfiguration;
import com.univates.fishing_backend.dto.UserRequestDTO;
import com.univates.fishing_backend.dto.UserResponseDTO;
import com.univates.fishing_backend.dto.UserUpdateDTO;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;
import tools.jackson.databind.ObjectMapper;

import java.time.OffsetDateTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class UserControllerTest {

    @Autowired
    private WebApplicationContext ctx;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private UserService userService;

    private MockMvc mockMvc;

    @BeforeEach
    void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(ctx).build();
    }

    private UserResponseDTO sampleResponse() {
        return new UserResponseDTO(1L, "John Smith", "john@example.com",
            true, OffsetDateTime.now(), null);
    }

    @Test
    void findAll_returns200WithPage() throws Exception {
        when(userService.findAll(any(Pageable.class)))
            .thenReturn(new PageImpl<>(List.of(sampleResponse())));

        mockMvc.perform(get("/api/users"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content[0].name").value("John Smith"));
    }

    @Test
    void findById_userExists_returns200() throws Exception {
        when(userService.findById(1L)).thenReturn(sampleResponse());

        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.email").value("john@example.com"));
    }

    @Test
    void findById_userDoesNotExist_returns404() throws Exception {
        when(userService.findById(99L))
            .thenThrow(new ResourceNotFoundException("User not found with id: 99"));

        mockMvc.perform(get("/api/users/99"))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void create_validBody_returns201() throws Exception {
        UserRequestDTO request = new UserRequestDTO("John Smith", "john@example.com", "password123");

        when(userService.create(any())).thenReturn(sampleResponse());

        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsBytes(request)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1));
    }

    @Test
    void create_blankName_returns400() throws Exception {
        String json = "{\"name\":\"\",\"email\":\"john@example.com\",\"password\":\"password123\"}";

        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    void create_invalidEmail_returns400() throws Exception {
        String json = "{\"name\":\"John\",\"email\":\"not-an-email\",\"password\":\"password123\"}";

        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    void create_duplicateEmail_returns409() throws Exception {
        UserRequestDTO request = new UserRequestDTO("John", "john@example.com", "password123");

        when(userService.create(any()))
            .thenThrow(new DataIntegrityViolationException("E-mail already registered: john@example.com"));

        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsBytes(request)))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.status").value(409));
    }

    @Test
    void update_validBody_returns200() throws Exception {
        UserUpdateDTO request = new UserUpdateDTO("John Updated", "john@example.com", null, true);

        UserResponseDTO updated = new UserResponseDTO(1L, "John Updated", "john@example.com",
            true, OffsetDateTime.now(), OffsetDateTime.now());

        when(userService.update(eq(1L), any())).thenReturn(updated);

        mockMvc.perform(put("/api/users/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsBytes(request)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("John Updated"));
    }

    @Test
    void update_userDoesNotExist_returns404() throws Exception {
        UserUpdateDTO request = new UserUpdateDTO("X", "x@example.com", null, true);

        when(userService.update(eq(99L), any()))
            .thenThrow(new ResourceNotFoundException("User not found with id: 99"));

        mockMvc.perform(put("/api/users/99")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsBytes(request)))
            .andExpect(status().isNotFound());
    }

    @Test
    void delete_userExists_returns204() throws Exception {
        doNothing().when(userService).delete(1L);

        mockMvc.perform(delete("/api/users/1"))
            .andExpect(status().isNoContent());
    }

    @Test
    void delete_userDoesNotExist_returns404() throws Exception {
        doThrow(new ResourceNotFoundException("User not found with id: 99"))
            .when(userService).delete(99L);

        mockMvc.perform(delete("/api/users/99"))
            .andExpect(status().isNotFound());
    }
}
