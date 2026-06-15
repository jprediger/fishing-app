package com.univates.fishing_backend.service;

import com.univates.fishing_backend.dto.EstablishmentResponseDTO;
import com.univates.fishing_backend.entity.EstablishmentCategory;
import com.univates.fishing_backend.repository.EstablishmentRepository;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class EstablishmentService {

    private final EstablishmentRepository establishmentRepository;
    private final double defaultRadiusM;
    private final int maxResults;

    @Autowired
    public EstablishmentService(
            EstablishmentRepository establishmentRepository,
            @Value("${app.establishment.default-radius-m:10000}") double defaultRadiusM,
            @Value("${app.establishment.max-results:100}") int maxResults) {
        this.establishmentRepository = establishmentRepository;
        this.defaultRadiusM = defaultRadiusM;
        this.maxResults = maxResults;
    }

    /**
     * Busca estabelecimentos combinando filtros opcionais de texto, categoria e proximidade.
     * Quando {@code lat}/{@code lon} são informados, retorna ordenado por distância e aplica o
     * raio (usando o default se {@code radiusM} for nulo). {@code limit} é limitado ao máximo
     * configurado.
     */
    public List<EstablishmentResponseDTO> search(
            String q, EstablishmentCategory category, Double lat, Double lon, Double radiusM, Integer limit) {
        boolean hasPoint = lat != null && lon != null;
        if ((lat == null) != (lon == null)) {
            throw new IllegalArgumentException("Informe lat e lon juntos para busca por proximidade.");
        }

        Double effectiveRadius = hasPoint ? (radiusM == null ? defaultRadiusM : radiusM) : null;
        int effectiveLimit = limit == null || limit <= 0 ? maxResults : Math.min(limit, maxResults);
        String normalizedQ = q == null || q.isBlank() ? null : q.trim();
        String categoryName = category == null ? null : category.name();

        return establishmentRepository
                .search(normalizedQ, categoryName, lat, lon, effectiveRadius, effectiveLimit)
                .stream()
                .map(this::toDto)
                .toList();
    }

    private EstablishmentResponseDTO toDto(EstablishmentRepository.EstablishmentRow row) {
        return new EstablishmentResponseDTO(
                row.getId(),
                row.getName(),
                EstablishmentCategory.valueOf(row.getCategory()),
                row.getAddress(),
                row.getPhone(),
                row.getLon(),
                row.getLat(),
                row.getDistanceMeters(),
                row.getOsmId(),
                row.getSource(),
                toOffsetDateTime(row.getCreatedAt()),
                toOffsetDateTime(row.getUpdatedAt()));
    }

    private OffsetDateTime toOffsetDateTime(Instant instant) {
        return instant == null ? null : OffsetDateTime.ofInstant(instant, ZoneOffset.UTC);
    }
}
