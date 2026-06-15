package com.univates.fishing_backend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.univates.fishing_backend.entity.WeatherCondition;
import com.univates.fishing_backend.entity.WeatherSource;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record WeatherDTO(
        BigDecimal temperatureC,
        WeatherCondition condition,
        BigDecimal windSpeedKmh,
        Integer windDirectionDeg,
        Integer humidityPct,
        BigDecimal pressureHpa,
        Integer code,
        OffsetDateTime capturedAt,
        WeatherSource source) {}
