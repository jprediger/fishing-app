package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.*;
import com.univates.fishing_backend.entity.*;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.CatchRepository;
import com.univates.fishing_backend.repository.FishRepository;
import com.univates.fishing_backend.repository.UserRepository;
import com.univates.fishing_backend.repository.WaterBodyRepository;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import tools.jackson.databind.ObjectMapper;

@Service
@RequiredArgsConstructor
@Transactional
public class CatchService {

    private final CatchRepository catchRepository;
    private final UserRepository userRepository;
    private final FishRepository fishRepository;
    private final WaterBodyRepository waterBodyRepository;
    private final WeatherClient weatherClient;
    private final CatchPhotoService catchPhotoService;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public Page<CatchResponseDTO> findAll(Pageable pageable, String requesterEmail, Long speciesId) {
        Page<CatchRecord> page = speciesId == null
                ? catchRepository.findAll(pageable)
                : catchRepository.findBySpecies_Id(speciesId, pageable);
        return page.map(record -> toDto(record, requesterEmail));
    }

    @Transactional(readOnly = true)
    public Page<CatchResponseDTO> findAll(Pageable pageable, String requesterEmail, Long speciesId, String bbox) {
        return findAll(pageable, requesterEmail, speciesId, bbox, null);
    }

    @Transactional(readOnly = true)
    public Page<CatchResponseDTO> findAll(
            Pageable pageable, String requesterEmail, Long speciesId, String bbox, Long waterBodyId) {
        if (waterBodyId != null) {
            Pageable feedPageable = PageRequest.of(
                    pageable.getPageNumber(), pageable.getPageSize(), Sort.by(Sort.Direction.DESC, "createdAt"));
            Page<CatchRecord> page = catchRepository.findByWaterBody_Id(waterBodyId, feedPageable);
            return page.map(record -> toDto(record, requesterEmail));
        }

        if (bbox == null || bbox.isBlank()) {
            return findAll(pageable, requesterEmail, speciesId);
        }

        Bbox viewport = Bbox.parse(bbox);
        Page<CatchRecord> page = catchRepository.findAllInBbox(
                viewport.minLon(), viewport.minLat(), viewport.maxLon(), viewport.maxLat(), speciesId, pageable);
        return page.map(record -> toDto(record, requesterEmail));
    }

    @Transactional(readOnly = true)
    public Page<CatchResponseDTO> findMine(Pageable pageable, String requesterEmail, Long speciesId) {
        Page<CatchRecord> page = speciesId == null
                ? catchRepository.findByUser_Email(requesterEmail, pageable)
                : catchRepository.findByUser_EmailAndSpecies_Id(requesterEmail, speciesId, pageable);
        return page.map(record -> toDto(record, requesterEmail));
    }

    @Transactional(readOnly = true)
    public CatchResponseDTO findById(Long id, String requesterEmail) {
        return toDto(loadCatch(id), requesterEmail);
    }

    public CatchResponseDTO create(CatchRequestDTO dto, String requesterEmail) {
        User user = loadUser(requesterEmail);
        Fish species = loadFish(dto.speciesId());
        WaterBody waterBody = loadWaterBody(dto.waterBodyId());
        CatchRecord record = buildRecord(dto, user, species, waterBody);
        applyWeather(record);
        return toDto(catchRepository.save(record), requesterEmail);
    }

    public CatchResponseDTO update(Long id, CatchRequestDTO dto, String requesterEmail) {
        CatchRecord record = loadCatch(id);
        ensureOwner(record, requesterEmail);
        record.setWaterBody(loadWaterBody(dto.waterBodyId()));
        record.setLocation(toPoint(dto.location()));
        record.setLocationVisibility(dto.locationVisibility());
        record.setSpecies(loadFish(dto.speciesId()));
        record.setWeightGrams(dto.weightGrams());
        record.setLengthMm(dto.lengthMm());
        record.setDescription(dto.description());
        record.setFishingMethod(dto.fishingMethod());
        record.setPurpose(dto.purpose());
        record.setCaughtAt(dto.caughtAt());
        applyWeather(record);
        return toDto(catchRepository.save(record), requesterEmail);
    }

    public void delete(Long id, String requesterEmail) {
        CatchRecord record = loadCatch(id);
        ensureOwner(record, requesterEmail);
        catchPhotoService.deleteAllByCatch(record);
        catchRepository.delete(record);
    }

    private CatchRecord loadCatch(Long id) {
        return catchRepository
                .findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Catch not found with id: " + id));
    }

    private User loadUser(String email) {
        return userRepository
                .findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + email));
    }

    private Fish loadFish(Long id) {
        return fishRepository
                .findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Fish not found with id: " + id));
    }

    private WaterBody loadWaterBody(Long id) {
        return waterBodyRepository
                .findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Water body not found with id: " + id));
    }

    private CatchRecord buildRecord(CatchRequestDTO dto, User user, Fish species, WaterBody waterBody) {
        return CatchRecord.builder()
                .user(user)
                .waterBody(waterBody)
                .location(toPoint(dto.location()))
                .locationVisibility(dto.locationVisibility())
                .species(species)
                .weightGrams(dto.weightGrams())
                .lengthMm(dto.lengthMm())
                .description(dto.description())
                .fishingMethod(dto.fishingMethod())
                .purpose(dto.purpose())
                .caughtAt(dto.caughtAt())
                .build();
    }

    private void applyWeather(CatchRecord record) {
        Optional<WeatherDTO> weather = weatherClient.fetch(
                record.getLocation().getY(), record.getLocation().getX(), record.getCaughtAt());
        record.setWeather(weather.map(this::toWeather).orElse(null));
    }

    private Weather toWeather(WeatherDTO dto) {
        return Weather.builder()
                .temperatureC(dto.temperatureC())
                .condition(dto.condition())
                .windSpeedKmh(dto.windSpeedKmh())
                .windDirectionDeg(dto.windDirectionDeg())
                .humidityPct(dto.humidityPct())
                .pressureHpa(dto.pressureHpa())
                .code(dto.code())
                .capturedAt(dto.capturedAt())
                .source(dto.source())
                .build();
    }

    private CatchResponseDTO toDto(CatchRecord record, String requesterEmail) {
        boolean mine = isOwner(record, requesterEmail);
        LocationDTO location = record.getLocationVisibility() == LocationVisibility.EXACT || mine
                ? toLocationDTO(record.getLocation())
                : null;
        return new CatchResponseDTO(
                record.getId(),
                toAuthorDto(record.getUser()),
                toFishDto(record.getSpecies()),
                toWaterBodyDto(record.getWaterBody()),
                location,
                record.getLocationVisibility(),
                record.getWeightGrams(),
                record.getLengthMm(),
                record.getDescription(),
                record.getFishingMethod(),
                record.getPurpose(),
                record.getCaughtAt(),
                toWeatherDto(record.getWeather()),
                mine,
                record.getPhotos().stream().map(this::toPhotoDto).toList(),
                record.getCreatedAt(),
                record.getUpdatedAt());
    }

    private AuthorDTO toAuthorDto(User user) {
        if (user == null) return null;
        return new AuthorDTO(user.getId(), user.getName());
    }

    private boolean isOwner(CatchRecord record, String requesterEmail) {
        return record.getUser() != null
                && record.getUser().getEmail() != null
                && requesterEmail != null
                && record.getUser().getEmail().equalsIgnoreCase(requesterEmail);
    }

    private void ensureOwner(CatchRecord record, String requesterEmail) {
        if (!isOwner(record, requesterEmail)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Only the owner can modify this catch");
        }
    }

    private Point toPoint(LocationDTO location) {
        GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);
        Point point =
                geometryFactory.createPoint(new org.locationtech.jts.geom.Coordinate(location.lon(), location.lat()));
        point.setSRID(4326);
        return point;
    }

    private LocationDTO toLocationDTO(Point point) {
        if (point == null) return null;
        return new LocationDTO(point.getY(), point.getX());
    }

    private FishResponseDTO toFishDto(Fish fish) {
        return new FishResponseDTO(
                fish.getId(),
                fish.getName(),
                fish.getDescription(),
                fish.getRegion(),
                fish.getType(),
                fish.getIcon() == null ? null : new IconDTO(fish.getIcon().getPath()),
                fish.getCreatedAt(),
                fish.getUpdatedAt());
    }

    private WaterBodyResponseDTO toWaterBodyDto(WaterBody body) {
        Point centroid = body.getGeom() == null ? null : (Point) body.getGeom().getCentroid();
        return new WaterBodyResponseDTO(
                body.getId(),
                body.getName(),
                body.getWaterType(),
                null,
                body.getOsmId(),
                body.getSource(),
                centroid == null ? null : centroid.getX(),
                centroid == null ? null : centroid.getY(),
                null,
                null,
                body.getCreatedAt(),
                body.getUpdatedAt());
    }

    private WeatherDTO toWeatherDto(Weather weather) {
        if (weather == null) return null;
        return new WeatherDTO(
                weather.getTemperatureC(),
                weather.getCondition(),
                weather.getWindSpeedKmh(),
                weather.getWindDirectionDeg(),
                weather.getHumidityPct(),
                weather.getPressureHpa(),
                weather.getCode(),
                weather.getCapturedAt(),
                weather.getSource());
    }

    private CatchPhotoResponseDTO toPhotoDto(CatchPhoto photo) {
        return new CatchPhotoResponseDTO(photo.getId(), photo.getFilePath(), photo.getPosition(), photo.getCreatedAt());
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
