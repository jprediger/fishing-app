package com.univates.fishing_backend.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.univates.fishing_backend.config.TestcontainersConfiguration;
import com.univates.fishing_backend.dto.FishRequestDTO;
import com.univates.fishing_backend.dto.FishResponseDTO;
import com.univates.fishing_backend.dto.IconDTO;
import com.univates.fishing_backend.entity.FishType;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.service.FishService;
import java.time.OffsetDateTime;
import java.util.List;
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

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class FishControllerTest {

    @Autowired
    private WebApplicationContext ctx;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private FishService fishService;

    private MockMvc mockMvc;

    @BeforeEach
    void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(ctx).build();
    }

    private FishResponseDTO sampleResponse() {
        return new FishResponseDTO(
                1L,
                "Tucunaré",
                "Peixe predador de água doce",
                "Bacia Amazônica",
                FishType.FRESHWATER,
                new IconDTO("/icons/tucunare.png"),
                OffsetDateTime.now(),
                null);
    }

    private FishRequestDTO sampleRequest() {
        return new FishRequestDTO(
                "Tucunaré",
                "Peixe predador de água doce",
                "Bacia Amazônica",
                FishType.FRESHWATER,
                new IconDTO("/icons/tucunare.png"));
    }

    @Test
    void findAll_returns200WithPage() throws Exception {
        when(fishService.findAll(any(Pageable.class))).thenReturn(new PageImpl<>(List.of(sampleResponse())));

        mockMvc.perform(get("/api/fish"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].name").value("Tucunaré"))
                .andExpect(jsonPath("$.content[0].icon.path").value("/icons/tucunare.png"));
    }

    @Test
    void findById_fishExists_returns200() throws Exception {
        when(fishService.findById(1L)).thenReturn(sampleResponse());

        mockMvc.perform(get("/api/fish/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.type").value("FRESHWATER"));
    }

    @Test
    void findById_fishDoesNotExist_returns404() throws Exception {
        when(fishService.findById(99L)).thenThrow(new ResourceNotFoundException("Fish not found with id: 99"));

        mockMvc.perform(get("/api/fish/99"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    void create_validBody_returns201() throws Exception {
        when(fishService.create(any())).thenReturn(sampleResponse());

        mockMvc.perform(post("/api/fish")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(sampleRequest())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(1));
    }

    @Test
    void create_blankName_returns400() throws Exception {
        String json = "{\"name\":\"\",\"type\":\"FRESHWATER\",\"icon\":{\"path\":\"/icons/x.png\"}}";

        mockMvc.perform(post("/api/fish")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    void create_missingType_returns400() throws Exception {
        String json = "{\"name\":\"Tucunaré\",\"icon\":{\"path\":\"/icons/x.png\"}}";

        mockMvc.perform(post("/api/fish")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    void create_blankIconPath_returns400() throws Exception {
        String json = "{\"name\":\"Tucunaré\",\"type\":\"FRESHWATER\",\"icon\":{\"path\":\"\"}}";

        mockMvc.perform(post("/api/fish")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    void create_duplicateName_returns409() throws Exception {
        when(fishService.create(any()))
                .thenThrow(new DataIntegrityViolationException("Fish already registered: Tucunaré"));

        mockMvc.perform(post("/api/fish")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(sampleRequest())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409));
    }

    @Test
    void update_validBody_returns200() throws Exception {
        FishResponseDTO updated = new FishResponseDTO(
                1L,
                "Dourado",
                "Peixe de água doce",
                "Rio Paraná",
                FishType.FRESHWATER,
                new IconDTO("/icons/dourado.png"),
                OffsetDateTime.now(),
                OffsetDateTime.now());

        when(fishService.update(eq(1L), any())).thenReturn(updated);

        FishRequestDTO request = new FishRequestDTO(
                "Dourado", "Peixe de água doce", "Rio Paraná", FishType.FRESHWATER, new IconDTO("/icons/dourado.png"));

        mockMvc.perform(put("/api/fish/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Dourado"));
    }

    @Test
    void update_fishDoesNotExist_returns404() throws Exception {
        when(fishService.update(eq(99L), any())).thenThrow(new ResourceNotFoundException("Fish not found with id: 99"));

        mockMvc.perform(put("/api/fish/99")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(sampleRequest())))
                .andExpect(status().isNotFound());
    }

    @Test
    void delete_fishExists_returns204() throws Exception {
        doNothing().when(fishService).delete(1L);

        mockMvc.perform(delete("/api/fish/1")).andExpect(status().isNoContent());
    }

    @Test
    void delete_fishDoesNotExist_returns404() throws Exception {
        doThrow(new ResourceNotFoundException("Fish not found with id: 99"))
                .when(fishService)
                .delete(99L);

        mockMvc.perform(delete("/api/fish/99")).andExpect(status().isNotFound());
    }
}
