package com.univates.fishing_backend.repository;

import com.univates.fishing_backend.entity.CatchRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CatchRepository extends JpaRepository<CatchRecord, Long> {

    Page<CatchRecord> findByUser_Email(String email, Pageable pageable);

    Page<CatchRecord> findBySpecies_Id(Long speciesId, Pageable pageable);

    Page<CatchRecord> findByUser_EmailAndSpecies_Id(String email, Long speciesId, Pageable pageable);
}
