package com.univates.fishing_backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.Mockito.*;

import com.univates.fishing_backend.dto.CatchRequestDTO;
import com.univates.fishing_backend.dto.CatchResponseDTO;
import com.univates.fishing_backend.dto.LocationDTO;
import com.univates.fishing_backend.entity.*;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.CatchRepository;
import com.univates.fishing_backend.repository.FishRepository;
import com.univates.fishing_backend.repository.UserRepository;
import com.univates.fishing_backend.repository.WaterBodyRepository;
import java.time.OffsetDateTime;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class CatchServiceTest {

    @Mock
    private CatchRepository catchRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private FishRepository fishRepository;

    @Mock
    private WaterBodyRepository waterBodyRepository;

    @Mock
    private WeatherClient weatherClient;

    @Mock
    private CatchPhotoService catchPhotoService;

    @InjectMocks
    private CatchService catchService;

    @Test
    void create_persistsCatchRecordAndReturnsDto() {
        when(userRepository.findByEmail("demo@fishing.local")).thenReturn(Optional.of(sampleUser()));
        when(fishRepository.findById(1L)).thenReturn(Optional.of(sampleFish()));
        when(waterBodyRepository.findById(2L)).thenReturn(Optional.of(sampleWaterBody()));
        when(weatherClient.fetch(anyDouble(), anyDouble(), org.mockito.ArgumentMatchers.any(OffsetDateTime.class)))
                .thenReturn(Optional.empty());
        when(catchRepository.save(any())).thenAnswer(invocation -> {
            CatchRecord record = invocation.getArgument(0);
            record.setId(99L);
            return record;
        });

        CatchRequestDTO dto = sampleRequest();
        CatchResponseDTO result = catchService.create(dto, "demo@fishing.local");

        assertThat(result.id()).isEqualTo(99L);
        assertThat(result.mine()).isTrue();
        assertThat(result.location()).isNotNull();
        assertThat(result.location().lat()).isEqualTo(-30.0);
        assertThat(result.waterBody().id()).isEqualTo(2L);
        assertThat(result.species().id()).isEqualTo(1L);

        ArgumentCaptor<CatchRecord> captor = ArgumentCaptor.forClass(CatchRecord.class);
        verify(catchRepository).save(captor.capture());
        CatchRecord saved = captor.getValue();
        assertThat(saved.getUser().getEmail()).isEqualTo("demo@fishing.local");
        assertThat(saved.getLocation().getSRID()).isEqualTo(4326);
        assertThat(saved.getLocation().getX()).isEqualTo(-51.0);
        assertThat(saved.getLocation().getY()).isEqualTo(-30.0);
    }

    @Test
    void findById_owner_seesExactLocation() {
        CatchRecord record = sampleRecord(LocationVisibility.RIVER_ONLY, "owner@fishing.local");
        when(catchRepository.findById(1L)).thenReturn(Optional.of(record));

        CatchResponseDTO result = catchService.findById(1L, "owner@fishing.local");

        assertThat(result.mine()).isTrue();
        assertThat(result.location()).isNotNull();
        assertThat(result.locationVisibility()).isEqualTo(LocationVisibility.RIVER_ONLY);
    }

    @Test
    void findById_otherUser_hidesLocation_whenRiverOnly() {
        CatchRecord record = sampleRecord(LocationVisibility.RIVER_ONLY, "owner@fishing.local");
        when(catchRepository.findById(1L)).thenReturn(Optional.of(record));

        CatchResponseDTO result = catchService.findById(1L, "other@fishing.local");

        assertThat(result.mine()).isFalse();
        assertThat(result.location()).isNull();
    }

    @Test
    void findById_missingRecord_throwsNotFound() {
        when(catchRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> catchService.findById(99L, "demo@fishing.local"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    private CatchRequestDTO sampleRequest() {
        return new CatchRequestDTO(
                2L,
                new LocationDTO(-30.0, -51.0),
                LocationVisibility.EXACT,
                1L,
                1200,
                450,
                "Boa captura",
                FishingMethod.ARREMESSO,
                FishingPurpose.SPORT,
                OffsetDateTime.parse("2026-06-14T12:00:00Z"));
    }

    private User sampleUser() {
        return sampleUser("demo@fishing.local");
    }

    private User sampleUser(String email) {
        return User.builder()
                .id(10L)
                .name("Demo")
                .email(email)
                .active(true)
                .role(Role.USER)
                .build();
    }

    private Fish sampleFish() {
        return Fish.builder()
                .id(1L)
                .name("Tucunaré")
                .type(FishType.FRESHWATER)
                .description("desc")
                .region("RS")
                .icon(new Icon("/i.png"))
                .build();
    }

    private WaterBody sampleWaterBody() {
        GeometryFactory gf = new GeometryFactory(new PrecisionModel(), 4326);
        return WaterBody.builder()
                .id(2L)
                .name("Guaíba")
                .waterType(WaterType.RIVER)
                .source("OSM")
                .geom(gf.createPoint(new org.locationtech.jts.geom.Coordinate(-51.0, -30.0)))
                .build();
    }

    private CatchRecord sampleRecord(LocationVisibility visibility, String email) {
        GeometryFactory gf = new GeometryFactory(new PrecisionModel(), 4326);
        Point location = gf.createPoint(new org.locationtech.jts.geom.Coordinate(-51.0, -30.0));
        location.setSRID(4326);
        return CatchRecord.builder()
                .id(1L)
                .user(sampleUser(email))
                .waterBody(sampleWaterBody())
                .location(location)
                .locationVisibility(visibility)
                .species(sampleFish())
                .weightGrams(1200)
                .lengthMm(450)
                .description("Boa captura")
                .fishingMethod(FishingMethod.ARREMESSO)
                .purpose(FishingPurpose.SPORT)
                .caughtAt(OffsetDateTime.parse("2026-06-14T12:00:00Z"))
                .build();
    }
}
