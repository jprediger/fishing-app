package com.univates.fishing_backend.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import lombok.*;
import org.locationtech.jts.geom.Point;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

@Entity
@Table(name = "catch_record")
@EntityListeners(AuditingEntityListener.class)
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CatchRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "water_body_id", nullable = false)
    private WaterBody waterBody;

    @Column(nullable = false, columnDefinition = "geometry(Point,4326)")
    private Point location;

    @Enumerated(EnumType.STRING)
    @Column(name = "location_visibility", nullable = false, length = 20)
    private LocationVisibility locationVisibility;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "species_id", nullable = false)
    private Fish species;

    @Column(name = "weight_grams")
    private Integer weightGrams;

    @Column(name = "length_mm")
    private Integer lengthMm;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "fishing_method", nullable = false, length = 20)
    private FishingMethod fishingMethod;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private FishingPurpose purpose;

    @Column(name = "caught_at", nullable = false)
    private OffsetDateTime caughtAt;

    @Embedded
    private Weather weather;

    @OneToMany(mappedBy = "catchRecord", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<CatchPhoto> photos = new ArrayList<>();

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;
}
