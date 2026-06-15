package com.univates.fishing_backend.entity;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

@Entity
@Table(name = "establishment")
@EntityListeners(AuditingEntityListener.class)
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Establishment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 40)
    private EstablishmentCategory category;

    @Column(length = 512)
    private String address;

    @Column(length = 40)
    private String phone;

    @JdbcTypeCode(SqlTypes.GEOMETRY)
    @Column(nullable = false, columnDefinition = "geometry(Point,4326)")
    private Point geom;

    @Column(name = "osm_id")
    private Long osmId;

    @Builder.Default
    @Column(nullable = false, length = 50)
    private String source = "OSM";

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;
}
