package com.univates.fishing_backend.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.charset.StandardCharsets;
import java.util.List;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

class TokenServiceTest {

    @Test
    void generate_signsAndDecodesTokenWithHs256() {
        SecretKey key = new SecretKeySpec(
                "dev-secret-troque-em-producao-0123456789abcdef".getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        var encoder = new org.springframework.security.oauth2.jwt.NimbusJwtEncoder(
                new com.nimbusds.jose.jwk.source.ImmutableSecret<>(key));
        var decoder = NimbusJwtDecoder.withSecretKey(key).build();
        var tokenService = new TokenService(encoder, 604800, "fishing-backend");

        var auth = new UsernamePasswordAuthenticationToken(
                "demo@fishing.local", "x", List.of(new SimpleGrantedAuthority("ROLE_USER")));

        TokenService.TokenResult result = tokenService.generate(auth);

        assertThat(result.expiresInSeconds()).isEqualTo(604800);
        assertThat(result.token()).isNotBlank();

        var jwt = decoder.decode(result.token());
        assertThat(jwt.getSubject()).isEqualTo("demo@fishing.local");
        assertThat(jwt.getClaimAsString("roles")).isEqualTo("USER");
        assertThat(jwt.getHeaders().get("alg")).isEqualTo("HS256");
    }
}
