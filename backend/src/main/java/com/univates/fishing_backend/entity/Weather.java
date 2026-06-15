package com.univates.fishing_backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import lombok.*;

@Embeddable
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Weather {

    @Column(name = "weather_temperature_c", precision = 4, scale = 1)
    private BigDecimal temperatureC;

    @Enumerated(EnumType.STRING)
    @Column(name = "weather_condition", length = 32)
    private WeatherCondition condition;

    @Column(name = "weather_wind_speed_kmh", precision = 5, scale = 1)
    private BigDecimal windSpeedKmh;

    @Column(name = "weather_wind_direction_deg")
    private Integer windDirectionDeg;

    @Column(name = "weather_humidity_pct")
    private Integer humidityPct;

    @Column(name = "weather_pressure_hpa", precision = 6, scale = 1)
    private BigDecimal pressureHpa;

    @Column(name = "weather_code")
    private Integer code;

    @Column(name = "weather_captured_at")
    private OffsetDateTime capturedAt;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    @Column(name = "weather_source", length = 32)
    private WeatherSource source = WeatherSource.OPEN_METEO;
}
