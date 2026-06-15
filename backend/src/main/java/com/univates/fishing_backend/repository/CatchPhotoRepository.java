package com.univates.fishing_backend.repository;

import com.univates.fishing_backend.entity.CatchPhoto;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CatchPhotoRepository extends JpaRepository<CatchPhoto, Long> {

    List<CatchPhoto> findAllByCatchRecordId(Long catchRecordId);

    Optional<CatchPhoto> findByIdAndCatchRecordId(Long id, Long catchRecordId);
}
