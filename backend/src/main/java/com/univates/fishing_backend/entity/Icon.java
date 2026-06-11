package com.univates.fishing_backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Ícone associado a um peixe. Embutido na própria entidade {@link Fish}.
 */
@Embeddable
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Icon {

    @Column(name = "icon_path", length = 512)
    private String path;
}
