package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.WeatherDTO;
import com.univates.fishing_backend.entity.WeatherCondition;
import com.univates.fishing_backend.entity.WeatherSource;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.Comparator;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class OpenMeteoWeatherClient implements WeatherClient {

    private static final Duration TIMEOUT = Duration.ofSeconds(5);
    private static final int RECENT_DAYS_THRESHOLD = 5;

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(3))
        .build();

    @Override
    public Optional<WeatherDTO> fetch(double lat, double lon, OffsetDateTime caughtAt) {
        try {
            URI uri = isRecent(caughtAt) ? forecastUri(lat, lon) : archiveUri(lat, lon, caughtAt);
            HttpRequest request = HttpRequest.newBuilder(uri)
                .timeout(TIMEOUT)
                .GET()
                .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                return Optional.empty();
            }
            JsonNode root = objectMapper.readTree(response.body());
            JsonNode hourly = root.get("hourly");
            if (hourly == null || !hourly.has("time")) {
                return Optional.empty();
            }
            int index = nearestHourIndex(hourly.get("time"), caughtAt).orElse(-1);
            if (index < 0) {
                return Optional.empty();
            }
            Integer code = readInt(hourly.get("weather_code"), index);
            return Optional.of(new WeatherDTO(
                readDecimal(hourly.get("temperature_2m"), index),
                code == null ? null : WeatherCondition.fromCode(code),
                readDecimal(hourly.get("wind_speed_10m"), index),
                readInt(hourly.get("wind_direction_10m"), index),
                readInt(hourly.get("relative_humidity_2m"), index),
                readDecimal(hourly.get("surface_pressure"), index),
                code,
                caughtAt,
                WeatherSource.OPEN_METEO
            ));
        } catch (Exception ex) {
            return Optional.empty();
        }
    }

    private boolean isRecent(OffsetDateTime caughtAt) {
        return caughtAt.isAfter(OffsetDateTime.now(ZoneOffset.UTC).minusDays(RECENT_DAYS_THRESHOLD));
    }

    private URI forecastUri(double lat, double lon) {
        return URI.create(
            "https://api.open-meteo.com/v1/forecast"
                + "?latitude=" + lat
                + "&longitude=" + lon
                + "&timezone=UTC"
                + "&past_days=" + RECENT_DAYS_THRESHOLD
                + "&hourly=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,relative_humidity_2m,surface_pressure"
        );
    }

    private URI archiveUri(double lat, double lon, OffsetDateTime caughtAt) {
        LocalDate date = caughtAt.toLocalDate();
        String start = URLEncoder.encode(date.toString(), StandardCharsets.UTF_8);
        String end = URLEncoder.encode(date.toString(), StandardCharsets.UTF_8);
        return URI.create(
            "https://archive-api.open-meteo.com/v1/archive"
                + "?latitude=" + lat
                + "&longitude=" + lon
                + "&timezone=UTC"
                + "&start_date=" + start
                + "&end_date=" + end
                + "&hourly=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,relative_humidity_2m,surface_pressure"
        );
    }

    private Optional<Integer> nearestHourIndex(JsonNode timeArray, OffsetDateTime caughtAt) {
        if (timeArray == null || !timeArray.isArray() || timeArray.isEmpty()) {
            return Optional.empty();
        }
        return java.util.stream.IntStream.range(0, timeArray.size())
            .boxed()
            .min(Comparator.comparingLong(i -> Math.abs(
                caughtAt.toEpochSecond() - parseTime(timeArray.get(i).asText()).toEpochSecond()
            )));
    }

    private OffsetDateTime parseTime(String text) {
        try {
            return OffsetDateTime.parse(text);
        } catch (DateTimeParseException ignored) {
            return LocalDateTime.parse(text).atOffset(ZoneOffset.UTC);
        }
    }

    private BigDecimal readDecimal(JsonNode array, int index) {
        if (array == null || !array.isArray() || index < 0 || index >= array.size() || array.get(index).isNull()) {
            return null;
        }
        return BigDecimal.valueOf(array.get(index).asDouble());
    }

    private Integer readInt(JsonNode array, int index) {
        if (array == null || !array.isArray() || index < 0 || index >= array.size() || array.get(index).isNull()) {
            return null;
        }
        return array.get(index).asInt();
    }
}
