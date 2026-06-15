package com.univates.fishing_backend.service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class CatchPhotoStorageService {

    private static final Set<String> ALLOWED_CONTENT_TYPES =
            Set.of("image/jpeg", "image/jpg", "image/png", "image/webp");
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of(".jpg", ".jpeg", ".png", ".webp");

    private final Path uploadsDir;

    public CatchPhotoStorageService(@Value("${app.uploads.dir:uploads}") String uploadsDir) {
        this.uploadsDir = Path.of(uploadsDir).toAbsolutePath().normalize();
    }

    public String store(MultipartFile file) {
        validate(file);
        try {
            Files.createDirectories(uploadsDir);
            String extension = extensionFor(file);
            String fileName = UUID.randomUUID() + extension;
            Path target = uploadsDir.resolve(fileName).normalize();
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
            return fileName;
        } catch (IOException ex) {
            throw new IllegalStateException("Failed to store upload", ex);
        }
    }

    public void delete(String relativePath) {
        try {
            if (relativePath == null || relativePath.isBlank()) {
                return;
            }
            Files.deleteIfExists(uploadsDir.resolve(relativePath).normalize());
        } catch (IOException ex) {
            throw new IllegalStateException("Failed to delete upload", ex);
        }
    }

    private void validate(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Photo is required");
        }
        if (file.getSize() > 8L * 1024L * 1024L) {
            throw new IllegalArgumentException("Photo must be at most 8 MB");
        }
        String contentType = normalizeContentType(file.getContentType());
        if (ALLOWED_CONTENT_TYPES.contains(contentType)) {
            return;
        }
        if (isMissingContentType(contentType) && hasAllowedExtension(file.getOriginalFilename())) {
            return;
        }
        throw new IllegalArgumentException("Unsupported photo type");
    }

    private boolean isMissingContentType(String contentType) {
        return contentType == null || contentType.isBlank() || "application/octet-stream".equals(contentType);
    }

    private boolean hasAllowedExtension(String originalFilename) {
        if (originalFilename == null) {
            return false;
        }
        String lower = originalFilename.toLowerCase(Locale.ROOT);
        return ALLOWED_EXTENSIONS.stream().anyMatch(lower::endsWith);
    }

    private String normalizeContentType(String contentType) {
        return contentType == null ? null : contentType.toLowerCase(Locale.ROOT).trim();
    }

    private String extensionFor(MultipartFile file) {
        String original = file.getOriginalFilename();
        if (original != null) {
            String lower = original.toLowerCase(Locale.ROOT);
            if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return ".jpg";
            if (lower.endsWith(".png")) return ".png";
            if (lower.endsWith(".webp")) return ".webp";
        }
        return switch (normalizeContentType(file.getContentType())) {
            case "image/jpeg", "image/jpg" -> ".jpg";
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            default -> ".bin";
        };
    }
}
