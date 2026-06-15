package com.univates.fishing_backend.controller;

import com.univates.fishing_backend.dto.EstablishmentResponseDTO;
import com.univates.fishing_backend.entity.EstablishmentCategory;
import com.univates.fishing_backend.service.EstablishmentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/establishments")
@RequiredArgsConstructor
@Tag(name = "Establishments", description = "Estabelecimentos de pesca (lojas, pesqueiros, marinas...)")
public class EstablishmentController {

    private final EstablishmentService establishmentService;

    @GetMapping
    @Operation(
            summary = "Busca estabelecimentos de pesca",
            description = "Combina filtros opcionais: texto no nome (q), categoria e proximidade (lat/lon + radiusM)."
                    + " Com lat/lon, retorna ordenado por distância e preenche distanceMeters.")
    @ApiResponse(responseCode = "200", description = "Lista retornada com sucesso")
    public List<EstablishmentResponseDTO> search(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) EstablishmentCategory category,
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lon,
            @RequestParam(required = false) Double radiusM,
            @RequestParam(required = false) Integer limit) {
        return establishmentService.search(q, category, lat, lon, radiusM, limit);
    }
}
