package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.FishRequestDTO;
import com.univates.fishing_backend.dto.FishResponseDTO;
import com.univates.fishing_backend.dto.IconDTO;
import com.univates.fishing_backend.entity.Fish;
import com.univates.fishing_backend.entity.Icon;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.FishRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional
public class FishService {

    private final FishRepository fishRepository;

    @Transactional(readOnly = true)
    public Page<FishResponseDTO> findAll(Pageable pageable) {
        return fishRepository.findAll(pageable).map(this::toResponseDTO);
    }

    @Transactional(readOnly = true)
    public FishResponseDTO findById(Long id) {
        return fishRepository
                .findById(id)
                .map(this::toResponseDTO)
                .orElseThrow(() -> new ResourceNotFoundException("Fish not found with id: " + id));
    }

    public FishResponseDTO create(FishRequestDTO dto) {
        if (fishRepository.existsByName(dto.name())) {
            throw new DataIntegrityViolationException("Fish already registered: " + dto.name());
        }
        Fish fish = Fish.builder()
                .name(dto.name())
                .description(dto.description())
                .region(dto.region())
                .type(dto.type())
                .icon(new Icon(dto.icon().path()))
                .build();
        return toResponseDTO(fishRepository.save(fish));
    }

    public FishResponseDTO update(Long id, FishRequestDTO dto) {
        Fish fish = fishRepository
                .findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Fish not found with id: " + id));

        if (fishRepository.existsByNameAndIdNot(dto.name(), id)) {
            throw new DataIntegrityViolationException("Fish already registered: " + dto.name());
        }

        fish.setName(dto.name());
        fish.setDescription(dto.description());
        fish.setRegion(dto.region());
        fish.setType(dto.type());
        fish.setIcon(new Icon(dto.icon().path()));

        return toResponseDTO(fishRepository.save(fish));
    }

    public void delete(Long id) {
        if (!fishRepository.existsById(id)) {
            throw new ResourceNotFoundException("Fish not found with id: " + id);
        }
        fishRepository.deleteById(id);
    }

    private FishResponseDTO toResponseDTO(Fish fish) {
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
}
