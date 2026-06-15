package com.univates.fishing_backend;

import com.univates.fishing_backend.config.TestcontainersConfiguration;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class FishingBackendApplicationTests {

    @Test
    void contextLoads() {}
}
