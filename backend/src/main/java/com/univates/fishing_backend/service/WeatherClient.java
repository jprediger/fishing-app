package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.WeatherDTO;
import java.time.OffsetDateTime;
import java.util.Optional;

public interface WeatherClient {

    Optional<WeatherDTO> fetch(double lat, double lon, OffsetDateTime caughtAt);
}
