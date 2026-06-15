package com.univates.fishing_backend.bootstrap;

import com.univates.fishing_backend.entity.WaterBody;
import com.univates.fishing_backend.entity.WaterType;
import com.univates.fishing_backend.repository.WaterBodyRepository;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.*;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@Slf4j
@Component
@ConditionalOnProperty(name = "app.seed.water-bodies", havingValue = "true")
@RequiredArgsConstructor
public class OverpassWaterBodySeeder implements DataSeeder {

    private static final String OVERPASS_URL = "https://overpass-api.de/api/interpreter";
    private static final String OVERPASS_QUERY =
            """
        [out:json][timeout:180];
        area["ISO3166-2"="BR-RS"]->.rs;
        (
          way["natural"="water"]["name"](area.rs);
          relation["natural"="water"]["name"](area.rs);
          way["waterway"="river"]["name"](area.rs);
          relation["waterway"="river"]["name"](area.rs);
        );
        out geom;
        """;

    private final WaterBodyRepository waterBodyRepository;
    private final ObjectMapper objectMapper;

    @Override
    public int order() {
        return 200;
    }

    @Override
    @Transactional
    public void run() {
        OverpassResponse response = fetchOverpass();
        List<WaterSeedCandidate> candidates = response.elements().stream()
                .map(this::toCandidate)
                .flatMap(Optional::stream)
                .sorted(Comparator.comparingLong(WaterSeedCandidate::osmId))
                .toList();

        log.info("WaterBody seed: {} feições candidatas", candidates.size());
        for (WaterSeedCandidate candidate : candidates) {
            upsert(candidate);
        }
    }

    private void upsert(WaterSeedCandidate candidate) {
        WaterBody body = waterBodyRepository
                .findByOsmId(candidate.osmId())
                .map(existing -> {
                    existing.setName(candidate.name());
                    existing.setWaterType(candidate.waterType());
                    existing.setGeom(candidate.geometry());
                    existing.setSource(candidate.source());
                    return existing;
                })
                .orElseGet(() -> WaterBody.builder()
                        .osmId(candidate.osmId())
                        .name(candidate.name())
                        .waterType(candidate.waterType())
                        .geom(candidate.geometry())
                        .source(candidate.source())
                        .build());

        waterBodyRepository.save(body);
    }

    private OverpassResponse fetchOverpass() {
        try {
            HttpClient client = HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(30))
                    .build();

            HttpRequest request = HttpRequest.newBuilder(URI.create(OVERPASS_URL))
                    .timeout(Duration.ofSeconds(240))
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .header("User-Agent", "fishing-app/1.0")
                    .POST(HttpRequest.BodyPublishers.ofString(
                            "data=" + URLEncoder.encode(OVERPASS_QUERY, StandardCharsets.UTF_8)))
                    .build();

            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("Overpass retornou status " + response.statusCode());
            }

            return objectMapper.readValue(response.body(), OverpassResponse.class);
        } catch (IOException | InterruptedException e) {
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            throw new IllegalStateException("Falha ao consultar Overpass", e);
        }
    }

    private Optional<WaterSeedCandidate> toCandidate(JsonNode element) {
        String type = text(element, "type");
        long osmId = element.path("id").asLong();
        String name = text(element.path("tags"), "name");
        if (name == null || type == null) {
            return Optional.empty();
        }

        Map<String, String> tags = objectMapper.convertValue(element.path("tags"), Map.class);
        WaterType waterType = deriveWaterType(tags);
        Geometry geometry =
                switch (type) {
                    case "way" -> parseWayGeometry(element, waterType);
                    case "relation" -> parseRelationGeometry(element, waterType);
                    default -> null;
                };

        if (geometry == null || geometry.isEmpty()) {
            log.debug("WaterBody seed: geometria ausente para osm {}", osmId);
            return Optional.empty();
        }

        geometry.setSRID(4326);
        return Optional.of(new WaterSeedCandidate(osmId, name, waterType, geometry, "OSM"));
    }

    private Geometry parseWayGeometry(JsonNode element, WaterType waterType) {
        List<Coordinate> coordinates = readCoordinates(element.path("geometry"));
        if (coordinates.size() < 2) {
            return null;
        }

        if (isClosed(coordinates) && isPolygonLike(waterType)) {
            return polygonFromRing(coordinates);
        }

        return geometryFactory().createLineString(coordinates.toArray(Coordinate[]::new));
    }

    private Geometry parseRelationGeometry(JsonNode element, WaterType waterType) {
        List<Coordinate> coordinates = readCoordinates(element.path("geometry"));
        if (coordinates.size() >= 4 && isClosed(coordinates) && isPolygonLike(waterType)) {
            return polygonFromRing(coordinates);
        }
        if (coordinates.size() >= 2) {
            return geometryFactory().createLineString(coordinates.toArray(Coordinate[]::new));
        }

        List<Geometry> memberGeometries = new ArrayList<>();
        for (JsonNode member : element.path("members")) {
            List<Coordinate> memberCoordinates = readCoordinates(member.path("geometry"));
            if (memberCoordinates.size() < 2) {
                continue;
            }
            Geometry geometry = isClosed(memberCoordinates) && isPolygonLike(waterType)
                    ? polygonFromRing(memberCoordinates)
                    : geometryFactory().createLineString(memberCoordinates.toArray(Coordinate[]::new));
            memberGeometries.add(geometry);
        }

        if (memberGeometries.isEmpty()) {
            return null;
        }

        if (memberGeometries.stream().allMatch(Polygon.class::isInstance)) {
            return geometryFactory()
                    .createMultiPolygon(
                            memberGeometries.stream().map(Polygon.class::cast).toArray(Polygon[]::new));
        }

        if (memberGeometries.stream().allMatch(LineString.class::isInstance)) {
            return geometryFactory()
                    .createMultiLineString(memberGeometries.stream()
                            .map(LineString.class::cast)
                            .toArray(LineString[]::new));
        }

        return memberGeometries.getFirst();
    }

    private Polygon polygonFromRing(List<Coordinate> coordinates) {
        Coordinate[] shellCoords = coordinates.toArray(Coordinate[]::new);
        LinearRing shell = geometryFactory().createLinearRing(shellCoords);
        return geometryFactory().createPolygon(shell);
    }

    private List<Coordinate> readCoordinates(JsonNode geometryNode) {
        List<Coordinate> coordinates = new ArrayList<>();
        for (JsonNode point : geometryNode) {
            double lon = point.path("lon").asDouble(Double.NaN);
            double lat = point.path("lat").asDouble(Double.NaN);
            if (!Double.isNaN(lon) && !Double.isNaN(lat)) {
                coordinates.add(new Coordinate(lon, lat));
            }
        }
        return coordinates;
    }

    private boolean isClosed(List<Coordinate> coordinates) {
        if (coordinates.size() < 4) {
            return false;
        }
        Coordinate first = coordinates.getFirst();
        Coordinate last = coordinates.getLast();
        return first.x == last.x && first.y == last.y;
    }

    private boolean isPolygonLike(WaterType waterType) {
        return waterType != WaterType.RIVER;
    }

    private WaterType deriveWaterType(Map<String, String> tags) {
        String waterway = tags.get("waterway");
        if ("river".equalsIgnoreCase(waterway)) {
            return WaterType.RIVER;
        }

        String water = tags.get("water");
        if (water == null) {
            return WaterType.LAKE;
        }

        return switch (water.toLowerCase()) {
            case "reservoir" -> WaterType.RESERVOIR;
            case "pond", "basin" -> WaterType.POND;
            case "lagoon", "lagoons" -> WaterType.LAGOON;
            default -> WaterType.LAKE;
        };
    }

    private GeometryFactory geometryFactory() {
        return new GeometryFactory(new PrecisionModel(), 4326);
    }

    private String text(JsonNode node, String field) {
        JsonNode value = node.get(field);
        return value == null || value.isNull() ? null : value.asText();
    }

    record OverpassResponse(List<JsonNode> elements) {}

    record WaterSeedCandidate(Long osmId, String name, WaterType waterType, Geometry geometry, String source) {}
}
