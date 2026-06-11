package com.univates.fishing_backend.controller;

import com.univates.fishing_backend.dto.FishRequestDTO;
import com.univates.fishing_backend.dto.FishResponseDTO;
import com.univates.fishing_backend.service.FishService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/fish")
@RequiredArgsConstructor
@Tag(name = "Fish", description = "Fish CRUD operations")
public class FishController {

    private final FishService fishService;

    @GetMapping
    @Operation(summary = "List all fish (paginated)")
    @ApiResponse(responseCode = "200", description = "Page returned successfully")
    public Page<FishResponseDTO> findAll(@PageableDefault(size = 20, sort = "id") Pageable pageable) {
        return fishService.findAll(pageable);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Find a fish by id")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Fish found"),
        @ApiResponse(responseCode = "404", description = "Fish not found")
    })
    public FishResponseDTO findById(@PathVariable Long id) {
        return fishService.findById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a new fish")
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "Fish created"),
        @ApiResponse(responseCode = "400", description = "Invalid data"),
        @ApiResponse(responseCode = "409", description = "Fish already registered")
    })
    public FishResponseDTO create(@Valid @RequestBody FishRequestDTO dto) {
        return fishService.create(dto);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update an existing fish")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Fish updated"),
        @ApiResponse(responseCode = "400", description = "Invalid data"),
        @ApiResponse(responseCode = "404", description = "Fish not found"),
        @ApiResponse(responseCode = "409", description = "Fish already registered")
    })
    public FishResponseDTO update(@PathVariable Long id, @Valid @RequestBody FishRequestDTO dto) {
        return fishService.update(id, dto);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a fish")
    @ApiResponses({
        @ApiResponse(responseCode = "204", description = "Fish deleted"),
        @ApiResponse(responseCode = "404", description = "Fish not found")
    })
    public void delete(@PathVariable Long id) {
        fishService.delete(id);
    }
}
