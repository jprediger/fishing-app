package com.univates.fishing_backend.controller;

import com.univates.fishing_backend.dto.WaterBodyResponseDTO;
import com.univates.fishing_backend.service.WaterBodyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/water-bodies")
@RequiredArgsConstructor
@Tag(name = "Water bodies", description = "Corpos d'água geográficos")
public class WaterBodyController {

    private final WaterBodyService waterBodyService;

    @GetMapping
    @Operation(summary = "Lista corpos d'água por viewport")
    @ApiResponse(responseCode = "200", description = "Lista retornada com sucesso")
    public List<WaterBodyResponseDTO> findInBbox(
            @RequestParam(required = false) String bbox, @RequestParam(required = false) Integer zoom) {
        return waterBodyService.findInBbox(bbox, zoom);
    }

    @GetMapping("/nearest")
    @Operation(summary = "Resolve o corpo d'água mais próximo de um ponto")
    @ApiResponse(responseCode = "200", description = "Corpo d'água encontrado")
    @ApiResponse(responseCode = "404", description = "Nenhum corpo d'água no raio configurado")
    public ResponseEntity<WaterBodyResponseDTO> findNearest(@RequestParam double lat, @RequestParam double lon) {
        return waterBodyService.findNearest(lat, lon).map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound()
                .build());
    }
}
