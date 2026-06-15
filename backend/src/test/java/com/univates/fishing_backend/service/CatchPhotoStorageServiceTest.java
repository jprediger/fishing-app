package com.univates.fishing_backend.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;

class CatchPhotoStorageServiceTest {

    @TempDir
    Path tempDir;

    @Test
    void store_acceptsJpegWithoutExplicitContentTypeWhenFilenameHasExtension() throws IOException {
        CatchPhotoStorageService storageService = new CatchPhotoStorageService(tempDir.toString());

        String stored = storageService.store(
                new MockMultipartFile("files", "photo.JPG", "application/octet-stream", new byte[] {1, 2, 3}));

        assertThat(stored).endsWith(".jpg");
        assertThat(Files.exists(tempDir.resolve(stored))).isTrue();
    }

    @Test
    void store_acceptsImageJpgContentType() throws IOException {
        CatchPhotoStorageService storageService = new CatchPhotoStorageService(tempDir.toString());

        String stored =
                storageService.store(new MockMultipartFile("files", "photo.bin", "image/jpg", new byte[] {1, 2, 3}));

        assertThat(stored).endsWith(".jpg");
        assertThat(Files.exists(tempDir.resolve(stored))).isTrue();
    }
}
