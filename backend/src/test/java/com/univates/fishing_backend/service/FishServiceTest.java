package com.univates.fishing_backend.service;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import com.univates.fishing_backend.dto.FishRequestDTO;
import com.univates.fishing_backend.dto.FishResponseDTO;
import com.univates.fishing_backend.dto.IconDTO;
import com.univates.fishing_backend.entity.Fish;
import com.univates.fishing_backend.entity.FishType;
import com.univates.fishing_backend.entity.Icon;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.FishRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

@ExtendWith(MockitoExtension.class)
class FishServiceTest {

    @Mock
    private FishRepository fishRepository;

    @InjectMocks
    private FishService fishService;

    private Fish sampleFish() {
        return Fish.builder()
                .id(1L)
                .name("Tucunaré")
                .description("Peixe predador de água doce")
                .region("Bacia Amazônica")
                .type(FishType.FRESHWATER)
                .icon(new Icon("/icons/tucunare.png"))
                .createdAt(OffsetDateTime.now())
                .build();
    }

    private FishRequestDTO sampleRequest() {
        return new FishRequestDTO(
                "Tucunaré",
                "Peixe predador de água doce",
                "Bacia Amazônica",
                FishType.FRESHWATER,
                new IconDTO("/icons/tucunare.png"));
    }

    @Test
    void findAll_returnsMappedPage() {
        Pageable pageable = PageRequest.of(0, 20);
        when(fishRepository.findAll(pageable)).thenReturn(new PageImpl<>(List.of(sampleFish())));

        var result = fishService.findAll(pageable);

        assertThat(result.getContent()).hasSize(1);
        assertThat(result.getContent().get(0).name()).isEqualTo("Tucunaré");
        assertThat(result.getContent().get(0).type()).isEqualTo(FishType.FRESHWATER);
        assertThat(result.getContent().get(0).icon().path()).isEqualTo("/icons/tucunare.png");
    }

    @Test
    void findById_fishExists_returnsDTO() {
        when(fishRepository.findById(1L)).thenReturn(Optional.of(sampleFish()));

        FishResponseDTO result = fishService.findById(1L);

        assertThat(result.id()).isEqualTo(1L);
        assertThat(result.name()).isEqualTo("Tucunaré");
    }

    @Test
    void findById_fishDoesNotExist_throwsException() {
        when(fishRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> fishService.findById(99L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("99");
    }

    @Test
    void create_validDto_savesAndReturnsDTO() {
        FishRequestDTO dto = sampleRequest();

        when(fishRepository.existsByName("Tucunaré")).thenReturn(false);
        when(fishRepository.save(any())).thenAnswer(invocation -> {
            Fish f = invocation.getArgument(0);
            f.setId(2L);
            return f;
        });

        FishResponseDTO result = fishService.create(dto);

        assertThat(result.id()).isEqualTo(2L);
        assertThat(result.name()).isEqualTo("Tucunaré");
        assertThat(result.icon().path()).isEqualTo("/icons/tucunare.png");
        verify(fishRepository).save(any(Fish.class));
    }

    @Test
    void create_duplicateName_throwsException() {
        FishRequestDTO dto = sampleRequest();
        when(fishRepository.existsByName("Tucunaré")).thenReturn(true);

        assertThatThrownBy(() -> fishService.create(dto))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("Tucunaré");

        verify(fishRepository, never()).save(any());
    }

    @Test
    void update_fishExists_updatesFieldsAndReturnsDTO() {
        Fish existing = sampleFish();
        FishRequestDTO dto = new FishRequestDTO(
                "Dourado", "Peixe de água doce", "Rio Paraná", FishType.FRESHWATER, new IconDTO("/icons/dourado.png"));

        when(fishRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(fishRepository.existsByNameAndIdNot("Dourado", 1L)).thenReturn(false);
        when(fishRepository.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

        FishResponseDTO result = fishService.update(1L, dto);

        assertThat(result.name()).isEqualTo("Dourado");
        assertThat(result.region()).isEqualTo("Rio Paraná");

        ArgumentCaptor<Fish> captor = ArgumentCaptor.forClass(Fish.class);
        verify(fishRepository).save(captor.capture());
        assertThat(captor.getValue().getIcon().getPath()).isEqualTo("/icons/dourado.png");
    }

    @Test
    void update_fishDoesNotExist_throwsException() {
        when(fishRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> fishService.update(99L, sampleRequest()))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void update_nameOfAnotherFish_throwsException() {
        when(fishRepository.findById(1L)).thenReturn(Optional.of(sampleFish()));
        when(fishRepository.existsByNameAndIdNot("Tucunaré", 1L)).thenReturn(true);

        assertThatThrownBy(() -> fishService.update(1L, sampleRequest()))
                .isInstanceOf(DataIntegrityViolationException.class)
                .hasMessageContaining("Tucunaré");

        verify(fishRepository, never()).save(any());
    }

    @Test
    void delete_fishExists_callsDeleteById() {
        when(fishRepository.existsById(1L)).thenReturn(true);

        fishService.delete(1L);

        verify(fishRepository).deleteById(1L);
    }

    @Test
    void delete_fishDoesNotExist_throwsException() {
        when(fishRepository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> fishService.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("99");
    }
}
