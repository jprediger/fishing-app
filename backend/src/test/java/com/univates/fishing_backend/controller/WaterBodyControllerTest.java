package com.univates.fishing_backend.controller;

import com.univates.fishing_backend.config.TestcontainersConfiguration;
import com.univates.fishing_backend.dto.WaterBodyResponseDTO;
import com.univates.fishing_backend.entity.WaterType;
import com.univates.fishing_backend.service.WaterBodyService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;
import tools.jackson.databind.ObjectMapper;

import java.time.OffsetDateTime;
import java.util.List;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class WaterBodyControllerTest {

    @Autowired
    private WebApplicationContext ctx;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private WaterBodyService waterBodyService;

    private MockMvc mockMvc;

    @BeforeEach
    void setup() {
        mockMvc = MockMvcBuilders.webAppContextSetup(ctx).build();
    }

    @Test
    void findInBbox_returnsGeoJsonList() throws Exception {
        WaterBodyResponseDTO dto = new WaterBodyResponseDTO(
            1L,
            "Guaíba",
            WaterType.RIVER,
            objectMapper.readTree("""
                {"type":"LineString","coordinates":[[-51.0,-30.0],[-50.9,-30.1]]}
                """),
            123L,
            "OSM",
            -50.95,
            -30.05,
            OffsetDateTime.parse("2026-06-14T12:00:00Z"),
            null
        );
        when(waterBodyService.findInBbox(null)).thenReturn(List.of(dto));

        mockMvc.perform(get("/api/water-bodies")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].name").value("Guaíba"))
            .andExpect(jsonPath("$[0].geometry.type").value("LineString"))
            .andExpect(jsonPath("$[0].centerLat").value(-30.05));
    }
}
