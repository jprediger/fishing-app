package com.univates.fishing_backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import com.univates.fishing_backend.entity.*;
import com.univates.fishing_backend.repository.CatchPhotoRepository;
import com.univates.fishing_backend.repository.CatchRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

@ExtendWith(MockitoExtension.class)
class CatchPhotoServiceTest {

    @Mock
    private CatchRepository catchRepository;

    @Mock
    private CatchPhotoRepository catchPhotoRepository;

    @Mock
    private CatchPhotoStorageService storageService;

    @InjectMocks
    private CatchPhotoService catchPhotoService;

    @Test
    void uploadPhotos_ownerSavesMetadataAndReturnsDtos() {
        CatchRecord record = sampleRecord();
        when(catchRepository.findById(1L)).thenReturn(Optional.of(record));
        when(catchPhotoRepository.save(any())).thenAnswer(invocation -> {
            CatchPhoto photo = invocation.getArgument(0);
            photo.setId(photo.getPosition().longValue() + 10);
            return photo;
        });
        when(storageService.store(any())).thenReturn("photo-1.jpg", "photo-2.jpg");

        var result = catchPhotoService.uploadPhotos(
                1L,
                "owner@fishing.local",
                List.of(
                        new MockMultipartFile("files", "one.jpg", "image/jpeg", new byte[] {1}),
                        new MockMultipartFile("files", "two.jpg", "image/jpeg", new byte[] {2})));

        assertThat(result).hasSize(2);
        assertThat(result.get(0).position()).isZero();
        assertThat(result.get(1).position()).isEqualTo(1);
        verify(storageService, times(2)).store(any());

        ArgumentCaptor<CatchPhoto> captor = ArgumentCaptor.forClass(CatchPhoto.class);
        verify(catchPhotoRepository, times(2)).save(captor.capture());
        assertThat(captor.getAllValues())
                .extracting(CatchPhoto::getFilePath)
                .containsExactly("photo-1.jpg", "photo-2.jpg");
    }

    @Test
    void deletePhoto_ownerDeletesFileAndRow() {
        CatchRecord record = sampleRecord();
        CatchPhoto photo = CatchPhoto.builder()
                .id(20L)
                .catchRecord(record)
                .filePath("photo-1.jpg")
                .position(0)
                .build();
        when(catchRepository.findById(1L)).thenReturn(Optional.of(record));
        when(catchPhotoRepository.findByIdAndCatchRecordId(20L, 1L)).thenReturn(Optional.of(photo));

        catchPhotoService.deletePhoto(1L, 20L, "owner@fishing.local");

        verify(storageService).delete("photo-1.jpg");
        verify(catchPhotoRepository).delete(photo);
    }

    private CatchRecord sampleRecord() {
        return CatchRecord.builder()
                .id(1L)
                .user(User.builder()
                        .id(10L)
                        .email("owner@fishing.local")
                        .name("Owner")
                        .password("x")
                        .role(Role.USER)
                        .active(true)
                        .build())
                .waterBody(WaterBody.builder()
                        .id(2L)
                        .name("Guaíba")
                        .waterType(WaterType.RIVER)
                        .source("OSM")
                        .build())
                .location(new org.locationtech.jts.geom.GeometryFactory()
                        .createPoint(new org.locationtech.jts.geom.Coordinate(-51.0, -30.0)))
                .locationVisibility(LocationVisibility.RIVER_ONLY)
                .species(Fish.builder()
                        .id(3L)
                        .name("Tucunaré")
                        .type(FishType.FRESHWATER)
                        .build())
                .caughtAt(OffsetDateTime.parse("2026-06-14T12:00:00Z"))
                .build();
    }
}
