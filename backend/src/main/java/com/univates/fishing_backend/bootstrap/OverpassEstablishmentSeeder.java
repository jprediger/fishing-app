package com.univates.fishing_backend.bootstrap;

import com.univates.fishing_backend.entity.Establishment;
import com.univates.fishing_backend.entity.EstablishmentCategory;
import com.univates.fishing_backend.repository.EstablishmentRepository;
import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Importa estabelecimentos de pesca do OpenStreetMap (via Overpass) para o RS.
 * Idempotente: faz upsert por {@code osm_id}. Cada POI vira um ponto (nós usam lat/lon
 * direto; ways/relations usam o centro retornado por {@code out center}).
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "app.seed.establishments", havingValue = "true")
@RequiredArgsConstructor
public class OverpassEstablishmentSeeder implements DataSeeder {

    private static final String OVERPASS_URL = "https://overpass-api.de/api/interpreter";
    private static final String OVERPASS_QUERY =
            """
        [out:json][timeout:120];
        area["ISO3166-2"="BR-RS"]->.rs;
        (
          nwr["shop"="fishing"](area.rs);
          nwr["leisure"="fishing"](area.rs);
          nwr["leisure"="slipway"](area.rs);
          nwr["leisure"="marina"](area.rs);
          nwr["club"="fishing"](area.rs);
        );
        out center;
        """;

    private final EstablishmentRepository establishmentRepository;
    private final ObjectMapper objectMapper;

    @Override
    public int order() {
        return 300;
    }

    @Override
    @Transactional
    public void run() {
        OverpassResponse response = fetchOverpass();
        List<EstablishmentCandidate> candidates = response.elements().stream()
                .map(this::toCandidate)
                .flatMap(Optional::stream)
                .sorted(Comparator.comparingLong(EstablishmentCandidate::osmId))
                .toList();

        log.info("Establishment seed: {} POIs candidatos", candidates.size());
        for (EstablishmentCandidate candidate : candidates) {
            upsert(candidate);
        }
    }

    private void upsert(EstablishmentCandidate candidate) {
        Establishment establishment = establishmentRepository
                .findByOsmId(candidate.osmId())
                .map(existing -> {
                    existing.setName(candidate.name());
                    existing.setCategory(candidate.category());
                    existing.setAddress(candidate.address());
                    existing.setPhone(candidate.phone());
                    existing.setGeom(candidate.geom());
                    existing.setSource(candidate.source());
                    return existing;
                })
                .orElseGet(() -> Establishment.builder()
                        .osmId(candidate.osmId())
                        .name(candidate.name())
                        .category(candidate.category())
                        .address(candidate.address())
                        .phone(candidate.phone())
                        .geom(candidate.geom())
                        .source(candidate.source())
                        .build());

        establishmentRepository.save(establishment);
    }

    private OverpassResponse fetchOverpass() {
        try {
            HttpClient client = HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(30))
                    .build();

            HttpRequest request = HttpRequest.newBuilder(URI.create(OVERPASS_URL))
                    .timeout(Duration.ofSeconds(180))
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

    private Optional<EstablishmentCandidate> toCandidate(JsonNode element) {
        JsonNode tags = element.path("tags");
        String name = text(tags, "name");
        if (name == null) {
            // POIs sem nome não são úteis para a busca por texto; ignorados.
            return Optional.empty();
        }

        double[] lonLat = resolveLonLat(element);
        if (lonLat == null) {
            log.debug("Establishment seed: coordenada ausente para osm {}", element.path("id"));
            return Optional.empty();
        }

        @SuppressWarnings("unchecked")
        Map<String, String> tagMap = objectMapper.convertValue(tags, Map.class);
        Point geom = point(lonLat[0], lonLat[1]);
        return Optional.of(new EstablishmentCandidate(
                element.path("id").asLong(),
                name,
                deriveCategory(tagMap),
                buildAddress(tagMap),
                phone(tagMap),
                geom,
                "OSM"));
    }

    /** Nós trazem lat/lon no topo; ways/relations trazem em {@code center}. */
    private double[] resolveLonLat(JsonNode element) {
        if (element.has("lat") && element.has("lon")) {
            return new double[] {
                element.path("lon").asDouble(), element.path("lat").asDouble()
            };
        }
        JsonNode center = element.path("center");
        if (center.has("lat") && center.has("lon")) {
            return new double[] {
                center.path("lon").asDouble(), center.path("lat").asDouble()
            };
        }
        return null;
    }

    private EstablishmentCategory deriveCategory(Map<String, String> tags) {
        if ("fishing".equalsIgnoreCase(tags.get("shop"))) {
            return EstablishmentCategory.LOJA_PESCA;
        }
        if ("fishing".equalsIgnoreCase(tags.get("leisure"))) {
            return EstablishmentCategory.PESQUEIRO;
        }
        if ("marina".equalsIgnoreCase(tags.get("leisure"))) {
            return EstablishmentCategory.MARINA;
        }
        if ("slipway".equalsIgnoreCase(tags.get("leisure"))) {
            return EstablishmentCategory.RAMPA;
        }
        if ("fishing".equalsIgnoreCase(tags.get("club"))) {
            return EstablishmentCategory.CLUBE;
        }
        return EstablishmentCategory.OUTRO;
    }

    private String buildAddress(Map<String, String> tags) {
        StringBuilder address = new StringBuilder();
        appendIfPresent(address, tags.get("addr:street"));
        String number = tags.get("addr:housenumber");
        if (number != null && !number.isBlank() && !address.isEmpty()) {
            address.append(", ").append(number.trim());
        }
        appendIfPresent(address, tags.get("addr:suburb"));
        appendIfPresent(address, tags.get("addr:city"));
        String result = address.toString();
        return result.isBlank() ? null : truncate(result, 512);
    }

    private void appendIfPresent(StringBuilder builder, String value) {
        if (value == null || value.isBlank()) {
            return;
        }
        if (!builder.isEmpty()) {
            builder.append(" - ");
        }
        builder.append(value.trim());
    }

    private String phone(Map<String, String> tags) {
        String phone = tags.getOrDefault("phone", tags.get("contact:phone"));
        return phone == null || phone.isBlank() ? null : truncate(phone.trim(), 40);
    }

    private String truncate(String value, int max) {
        return value.length() <= max ? value : value.substring(0, max);
    }

    private Point point(double lon, double lat) {
        Point point = new GeometryFactory(new PrecisionModel(), 4326).createPoint(new Coordinate(lon, lat));
        point.setSRID(4326);
        return point;
    }

    private String text(JsonNode node, String field) {
        JsonNode value = node.get(field);
        return value == null || value.isNull() ? null : value.asText();
    }

    record OverpassResponse(List<JsonNode> elements) {}

    record EstablishmentCandidate(
            Long osmId,
            String name,
            EstablishmentCategory category,
            String address,
            String phone,
            Point geom,
            String source) {}
}
