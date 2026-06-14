package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.WaterBodyResponseDTO;
import com.univates.fishing_backend.entity.WaterType;
import com.univates.fishing_backend.repository.WaterBodyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WaterBodyService {

    private static final Bbox RS_FALLBACK_BBOX = new Bbox(-57.70, -33.90, -49.50, -27.00);

    private final WaterBodyRepository waterBodyRepository;
    private final ObjectMapper objectMapper;

    public List<WaterBodyResponseDTO> findInBbox(String bbox) {
        Bbox viewport = bbox == null || bbox.isBlank()
            ? RS_FALLBACK_BBOX
            : Bbox.parse(bbox);

        return waterBodyRepository.findInBbox(
                viewport.minLon(),
                viewport.minLat(),
                viewport.maxLon(),
                viewport.maxLat())
            .stream()
            .map(this::toDto)
            .toList();
    }

    private WaterBodyResponseDTO toDto(WaterBodyRepository.WaterBodyViewportRow row) {
        JsonNode geometry = toJsonNode(row.getGeomGeoJson());
        return new WaterBodyResponseDTO(
            row.getId(),
            row.getName(),
            WaterType.valueOf(row.getWaterType()),
            geometry,
            row.getOsmId(),
            row.getSource(),
            row.getCenterLon(),
            row.getCenterLat(),
            row.getCreatedAt(),
            row.getUpdatedAt()
        );
    }

    private JsonNode toJsonNode(String json) {
        try {
            return json == null ? objectMapper.nullNode() : objectMapper.readTree(json);
        } catch (Exception e) {
            throw new IllegalStateException("Falha ao converter geometria para GeoJSON", e);
        }
    }

    record Bbox(double minLon, double minLat, double maxLon, double maxLat) {
        static Bbox parse(String bbox) {
            String[] parts = bbox.split(",");
            if (parts.length != 4) {
                throw new IllegalArgumentException("bbox inválido. Use minLon,minLat,maxLon,maxLat");
            }
            try {
                double minLon = Double.parseDouble(parts[0].trim());
                double minLat = Double.parseDouble(parts[1].trim());
                double maxLon = Double.parseDouble(parts[2].trim());
                double maxLat = Double.parseDouble(parts[3].trim());
                if (minLon >= maxLon || minLat >= maxLat) {
                    throw new IllegalArgumentException("bbox inválido. Coordenadas fora de ordem");
                }
                return new Bbox(minLon, minLat, maxLon, maxLat);
            } catch (NumberFormatException ex) {
                throw new IllegalArgumentException("bbox inválido. Coordenadas devem ser numéricas");
            }
        }
    }
}
