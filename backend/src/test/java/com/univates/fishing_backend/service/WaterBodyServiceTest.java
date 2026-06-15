package com.univates.fishing_backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.univates.fishing_backend.dto.WaterBodyResponseDTO;
import com.univates.fishing_backend.entity.WaterType;
import com.univates.fishing_backend.repository.WaterBodyRepository;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import tools.jackson.databind.ObjectMapper;

@ExtendWith(MockitoExtension.class)
class WaterBodyServiceTest {

    @Mock
    private WaterBodyRepository waterBodyRepository;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void findInBbox_withoutParam_usesFallbackBounds() {
        WaterBodyService waterBodyService = new WaterBodyService(waterBodyRepository, objectMapper, 5000d, 500);
        WaterBodyRepository.WaterBodyViewportRow row = row();
        when(waterBodyRepository.findInBbox(-57.70, -33.90, -49.50, -27.00, null, 500))
                .thenReturn(List.of(row));

        List<WaterBodyResponseDTO> result = waterBodyService.findInBbox(null, null);

        assertThat(result).hasSize(1);
        assertThat(result.getFirst().waterType()).isEqualTo(WaterType.RIVER);
        assertThat(result.getFirst().geometry().get("type").asText()).isEqualTo("LineString");
    }

    @Test
    void findInBbox_invalidParam_throws() {
        WaterBodyService waterBodyService = new WaterBodyService(waterBodyRepository, objectMapper, 5000d, 500);
        assertThatThrownBy(() -> waterBodyService.findInBbox("1,2,3", null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void findInBbox_parsesRequestedViewport() {
        WaterBodyService waterBodyService = new WaterBodyService(waterBodyRepository, objectMapper, 5000d, 500);
        WaterBodyRepository.WaterBodyViewportRow row = row();
        when(waterBodyRepository.findInBbox(-51.5, -30.5, -51.0, -30.0, 0.005, 500))
                .thenReturn(List.of(row));

        List<WaterBodyResponseDTO> result = waterBodyService.findInBbox("-51.5,-30.5,-51.0,-30.0", 10);

        assertThat(result).hasSize(1);
        assertThat(result.getFirst().osmId()).isEqualTo(123L);
    }

    @Test
    void findNearest_withinRadius_returnsDto() {
        WaterBodyService waterBodyService = new WaterBodyService(waterBodyRepository, objectMapper, 5000d, 500);
        WaterBodyRepository.WaterBodyViewportRow row = row();
        when(waterBodyRepository.findNearest(-30.05, -50.95, 5000d)).thenReturn(java.util.Optional.of(row));

        var result = waterBodyService.findNearest(-30.05, -50.95);

        assertThat(result).isPresent();
        assertThat(result.orElseThrow().distanceMeters()).isEqualTo(123.4d);
    }

    @Test
    void findNearest_outsideRadius_returnsEmpty() {
        WaterBodyService waterBodyService = new WaterBodyService(waterBodyRepository, objectMapper, 5000d, 500);
        when(waterBodyRepository.findNearest(-30.05, -50.95, 5000d)).thenReturn(java.util.Optional.empty());

        var result = waterBodyService.findNearest(-30.05, -50.95);

        assertThat(result).isEmpty();
    }

    private WaterBodyRepository.WaterBodyViewportRow row() {
        WaterBodyRepository.WaterBodyViewportRow row =
                org.mockito.Mockito.mock(WaterBodyRepository.WaterBodyViewportRow.class);
        when(row.getId()).thenReturn(1L);
        when(row.getName()).thenReturn("Guaíba");
        when(row.getWaterType()).thenReturn("RIVER");
        when(row.getGeomGeoJson())
                .thenReturn(
                        """
            {"type":"LineString","coordinates":[[-51.0,-30.0],[-50.9,-30.1]]}
            """);
        when(row.getOsmId()).thenReturn(123L);
        when(row.getSource()).thenReturn("OSM");
        when(row.getCenterLon()).thenReturn(-50.95);
        when(row.getCenterLat()).thenReturn(-30.05);
        when(row.getDistanceMeters()).thenReturn(123.4d);
        when(row.getCreatedAt()).thenReturn(OffsetDateTime.parse("2026-06-14T12:00:00Z"));
        when(row.getUpdatedAt()).thenReturn(null);
        return row;
    }
}
