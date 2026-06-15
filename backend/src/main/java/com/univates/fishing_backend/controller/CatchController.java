package com.univates.fishing_backend.controller;

import com.univates.fishing_backend.dto.CatchPhotoResponseDTO;
import com.univates.fishing_backend.dto.CatchRequestDTO;
import com.univates.fishing_backend.dto.CatchResponseDTO;
import com.univates.fishing_backend.service.CatchPhotoService;
import com.univates.fishing_backend.service.CatchService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/catches")
@RequiredArgsConstructor
@Tag(name = "Catch records", description = "Registro de pesca")
public class CatchController {

    private final CatchService catchService;
    private final CatchPhotoService catchPhotoService;

    @GetMapping
    @Operation(summary = "List catch records")
    public Page<CatchResponseDTO> findAll(
        Authentication authentication,
        @PageableDefault(size = 20, sort = "id") Pageable pageable,
        @RequestParam(required = false) Long speciesId
    ) {
        return catchService.findAll(pageable, authentication.getName(), speciesId);
    }

    @GetMapping("/mine")
    @Operation(summary = "List current user's catch records")
    public Page<CatchResponseDTO> mine(
        Authentication authentication,
        @PageableDefault(size = 20, sort = "id") Pageable pageable,
        @RequestParam(required = false) Long speciesId
    ) {
        return catchService.findMine(pageable, authentication.getName(), speciesId);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Find a catch record by id")
    public CatchResponseDTO findById(@PathVariable Long id, Authentication authentication) {
        return catchService.findById(id, authentication.getName());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a catch record")
    public CatchResponseDTO create(Authentication authentication, @Valid @RequestBody CatchRequestDTO dto) {
        return catchService.create(dto, authentication.getName());
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a catch record")
    public CatchResponseDTO update(@PathVariable Long id, Authentication authentication, @Valid @RequestBody CatchRequestDTO dto) {
        return catchService.update(id, dto, authentication.getName());
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a catch record")
    public void delete(@PathVariable Long id, Authentication authentication) {
        catchService.delete(id, authentication.getName());
    }

    @PostMapping(value = "/{id}/photos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload catch photos")
    public List<CatchPhotoResponseDTO> uploadPhotos(
        @PathVariable Long id,
        Authentication authentication,
        @RequestPart("files") List<MultipartFile> files
    ) {
        return catchPhotoService.uploadPhotos(id, authentication.getName(), files);
    }

    @DeleteMapping("/{id}/photos/{photoId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a catch photo")
    public void deletePhoto(@PathVariable Long id, @PathVariable Long photoId, Authentication authentication) {
        catchPhotoService.deletePhoto(id, photoId, authentication.getName());
    }
}
