package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.CatchPhotoResponseDTO;
import com.univates.fishing_backend.entity.CatchPhoto;
import com.univates.fishing_backend.entity.CatchRecord;
import com.univates.fishing_backend.exception.ResourceNotFoundException;
import com.univates.fishing_backend.repository.CatchPhotoRepository;
import com.univates.fishing_backend.repository.CatchRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional
public class CatchPhotoService {

    private final CatchRepository catchRepository;
    private final CatchPhotoRepository catchPhotoRepository;
    private final CatchPhotoStorageService storageService;

    public List<CatchPhotoResponseDTO> uploadPhotos(Long catchId, String requesterEmail, List<MultipartFile> files) {
        CatchRecord record = loadOwnedCatch(catchId, requesterEmail);
        int currentCount = record.getPhotos().size();
        if (currentCount + files.size() > 8) {
            throw new IllegalArgumentException("A catch record can have at most 8 photos");
        }
        int startPosition = currentCount;
        List<CatchPhoto> savedPhotos = new java.util.ArrayList<>();
        for (int i = 0; i < files.size(); i++) {
            MultipartFile file = files.get(i);
            String relativePath = storageService.store(file);
            CatchPhoto photo = CatchPhoto.builder()
                .catchRecord(record)
                .filePath(relativePath)
                .position(startPosition + i)
                .build();
            savedPhotos.add(catchPhotoRepository.save(photo));
        }
        record.getPhotos().addAll(savedPhotos);
        return record.getPhotos().stream()
            .sorted(java.util.Comparator.comparingInt(CatchPhoto::getPosition))
            .map(this::toDto)
            .toList();
    }

    public void deletePhoto(Long catchId, Long photoId, String requesterEmail) {
        CatchRecord record = loadOwnedCatch(catchId, requesterEmail);
        CatchPhoto photo = catchPhotoRepository.findByIdAndCatchRecordId(photoId, catchId)
            .orElseThrow(() -> new ResourceNotFoundException("Photo not found: " + photoId));
        storageService.delete(photo.getFilePath());
        record.getPhotos().remove(photo);
        catchPhotoRepository.delete(photo);
    }

    public void deleteAllByCatch(CatchRecord record) {
        for (CatchPhoto photo : List.copyOf(record.getPhotos())) {
            storageService.delete(photo.getFilePath());
        }
        record.getPhotos().clear();
    }

    private CatchRecord loadOwnedCatch(Long catchId, String requesterEmail) {
        CatchRecord record = catchRepository.findById(catchId)
            .orElseThrow(() -> new ResourceNotFoundException("Catch not found with id: " + catchId));
        if (!record.getUser().getEmail().equalsIgnoreCase(requesterEmail)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Only the owner can manage photos");
        }
        return record;
    }

    private CatchPhotoResponseDTO toDto(CatchPhoto photo) {
        return new CatchPhotoResponseDTO(
            photo.getId(),
            photo.getFilePath(),
            photo.getPosition(),
            photo.getCreatedAt()
        );
    }
}
