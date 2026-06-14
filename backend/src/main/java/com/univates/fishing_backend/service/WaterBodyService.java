package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.WaterBodyResponseDTO;
import com.univates.fishing_backend.entity.WaterType;
import com.univates.fishing_backend.repository.WaterBodyRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

import java.util.List;
import java.util.Optional;

@Service
@Transactional(readOnly = true)
public class WaterBodyService {

    private static final Bbox RS_FALLBACK_BBOX = new Bbox(-57.70, -33.90, -49.50, -27.00);

    private final WaterBodyRepository waterBodyRepository;
    private final ObjectMapper objectMapper;
    private final double nearestRadiusM;
    private final int maxFeatures;

    @Autowired
    public WaterBodyService(
        WaterBodyRepository waterBodyRepository,
        ObjectMapper objectMapper,
        @Value("${app.water-body.nearest-radius-m:5000}") double nearestRadiusM,
        @Value("${app.water-body.max-features:500}") int maxFeatures
    ) {
        this.waterBodyRepository = waterBodyRepository;
        this.objectMapper = objectMapper;
        this.nearestRadiusM = nearestRadiusM;
        this.maxFeatures = maxFeatures;
    }

    public List<WaterBodyResponseDTO> findInBbox(String bbox, Integer zoom) {
        Bbox viewport = bbox == null || bbox.isBlank()
            ? RS_FALLBACK_BBOX
            : Bbox.parse(bbox);
        Double simplifyTolerance = zoom == null ? null : zoomToTolerance(zoom);

        return waterBodyRepository.findInBbox(
                viewport.minLon(),
                viewport.minLat(),
                viewport.maxLon(),
                viewport.maxLat(),
                simplifyTolerance,
                maxFeatures)
            .stream()
            .map(this::toDto)
            .toList();
    }

    public Optional<WaterBodyResponseDTO> findNearest(double lat, double lon) {
        return waterBodyRepository.findNearest(lat, lon, nearestRadiusM)
            .map(this::toDto);
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
            row.getDistanceMeters(),
            row.getCreatedAt(),
            row.getUpdatedAt()
        );
    }

    private double zoomToTolerance(int zoom) {
        if (zoom <= 8) return 0.01;
        if (zoom <= 10) return 0.005;
        if (zoom <= 13) return 0.001;
        return 0.0;
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
