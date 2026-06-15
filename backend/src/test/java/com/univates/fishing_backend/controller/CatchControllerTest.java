package com.univates.fishing_backend.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.univates.fishing_backend.config.TestcontainersConfiguration;
import com.univates.fishing_backend.dto.CatchRequestDTO;
import com.univates.fishing_backend.dto.CatchResponseDTO;
import com.univates.fishing_backend.dto.FishResponseDTO;
import com.univates.fishing_backend.dto.LocationDTO;
import com.univates.fishing_backend.dto.WaterBodyResponseDTO;
import com.univates.fishing_backend.entity.FishType;
import com.univates.fishing_backend.entity.FishingMethod;
import com.univates.fishing_backend.entity.FishingPurpose;
import com.univates.fishing_backend.entity.LocationVisibility;
import com.univates.fishing_backend.entity.WaterType;
import com.univates.fishing_backend.service.CatchPhotoService;
import com.univates.fishing_backend.service.CatchService;
import java.time.OffsetDateTime;
import java.util.List;
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
import tools.jackson.databind.ObjectMapper;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class CatchControllerTest {

    @Autowired
    private WebApplicationContext ctx;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private CatchService catchService;

    @MockitoBean
    private CatchPhotoService catchPhotoService;

    private MockMvc mockMvc;

    @BeforeEach
    void setup() {
        mockMvc =
                MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    @Test
    @WithMockUser(username = "demo@fishing.local", roles = "USER")
    void create_returns201() throws Exception {
        when(catchService.create(any(CatchRequestDTO.class), anyString())).thenReturn(sampleCatch(true));

        mockMvc.perform(post("/api/catches")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsBytes(sampleRequest())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(1));
    }

    @Test
    @WithMockUser(username = "demo@fishing.local", roles = "USER")
    void findById_riverOnly_omitsLocation() throws Exception {
        when(catchService.findById(1L, "demo@fishing.local")).thenReturn(sampleCatch(false));

        mockMvc.perform(get("/api/catches/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.location").doesNotExist())
                .andExpect(jsonPath("$.locationVisibility").value("RIVER_ONLY"));
    }

    @Test
    @WithMockUser(username = "demo@fishing.local", roles = "USER")
    void findById_exact_includesLocation() throws Exception {
        when(catchService.findById(1L, "demo@fishing.local")).thenReturn(sampleCatch(true));

        mockMvc.perform(get("/api/catches/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.location.lat").value(-30.0))
                .andExpect(jsonPath("$.location.lon").value(-51.0));
    }

    @Test
    @WithMockUser(username = "demo@fishing.local", roles = "USER")
    void findAll_withWaterBodyId_usesFeedOrdering() throws Exception {
        when(catchService.findAll(any(), anyString(), any(), any(), any()))
                .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(sampleCatch(true))));

        mockMvc.perform(get("/api/catches").param("waterBodyId", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(1));
    }

    private CatchRequestDTO sampleRequest() {
        return new CatchRequestDTO(
                1L,
                new LocationDTO(-30.0, -51.0),
                LocationVisibility.EXACT,
                1L,
                1200,
                450,
                "Boa captura",
                FishingMethod.ARREMESSO,
                FishingPurpose.SPORT,
                OffsetDateTime.parse("2026-06-14T12:00:00Z"));
    }

    private CatchResponseDTO sampleCatch(boolean exact) {
        return new CatchResponseDTO(
                1L,
                new com.univates.fishing_backend.dto.AuthorDTO(10L, "Demo"),
                new FishResponseDTO(
                        1L, "Tucunaré", "desc", "RS", FishType.FRESHWATER, null, OffsetDateTime.now(), null),
                new WaterBodyResponseDTO(
                        1L,
                        "Guaíba",
                        WaterType.RIVER,
                        null,
                        123L,
                        "OSM",
                        -50.95,
                        -30.05,
                        null,
                        null,
                        OffsetDateTime.now(),
                        null),
                exact ? new LocationDTO(-30.0, -51.0) : null,
                exact ? LocationVisibility.EXACT : LocationVisibility.RIVER_ONLY,
                1200,
                450,
                "Boa captura",
                FishingMethod.ARREMESSO,
                FishingPurpose.SPORT,
                OffsetDateTime.parse("2026-06-14T12:00:00Z"),
                null,
                true,
                List.of(),
                OffsetDateTime.now(),
                null);
    }
}
