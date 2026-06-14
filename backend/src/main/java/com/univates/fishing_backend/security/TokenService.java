package com.univates.fishing_backend.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.stream.Collectors;

@Service
public class TokenService {

    private final JwtEncoder encoder;
    private final long expirationSeconds;
    private final String issuer;

    public TokenService(
            JwtEncoder encoder,
            @Value("${app.jwt.expiration-seconds:3600}") long expirationSeconds,
            @Value("${app.jwt.issuer:fishing-backend}") String issuer) {
        this.encoder = encoder;
        this.expirationSeconds = expirationSeconds;
        this.issuer = issuer;
    }

    /**
     * Gera um JWT assinado (HS256) para o usuário autenticado.
     * As roles vão no claim "roles" sem o prefixo ROLE_; o resource server
     * reaplica o prefixo ao validar (ver SecurityConfig).
     */
    public TokenResult generate(Authentication authentication) {
        Instant now = Instant.now();
        Instant expiresAt = now.plusSeconds(expirationSeconds);

        String roles = authentication.getAuthorities().stream()
            .map(GrantedAuthority::getAuthority)
            .map(a -> a.replaceFirst("^ROLE_", ""))
            .collect(Collectors.joining(" "));

        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer(issuer)
            .issuedAt(now)
            .expiresAt(expiresAt)
            .subject(authentication.getName())
            .claim("roles", roles)
            .build();

        String token = encoder.encode(JwtEncoderParameters.from(claims)).getTokenValue();
        return new TokenResult(token, expirationSeconds);
    }

    public record TokenResult(String token, long expiresInSeconds) {}
}
