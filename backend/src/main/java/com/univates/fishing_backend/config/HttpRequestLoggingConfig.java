package com.univates.fishing_backend.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.core.Ordered;
import org.springframework.web.filter.OncePerRequestFilter;

@Configuration
@Profile("dev")
public class HttpRequestLoggingConfig {

    private static final Logger log = LoggerFactory.getLogger(HttpRequestLoggingConfig.class);

    @Bean
    public FilterRegistrationBean<OncePerRequestFilter> httpRequestLoggingFilter() {
        OncePerRequestFilter filter = new OncePerRequestFilter() {
            @Override
            protected void doFilterInternal(
                    HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
                    throws ServletException, IOException {
                long startedAt = System.nanoTime();
                try {
                    filterChain.doFilter(request, response);
                } finally {
                    long elapsedMs = (System.nanoTime() - startedAt) / 1_000_000;
                    String queryString = request.getQueryString();
                    String origin = request.getHeader("Origin");
                    log.info(
                            "[HTTP] {} {}{} origin={} -> {} ({} ms)",
                            request.getMethod(),
                            request.getRequestURI(),
                            queryString == null ? "" : "?" + queryString,
                            origin == null ? "-" : origin,
                            response.getStatus(),
                            elapsedMs);
                }
            }
        };

        FilterRegistrationBean<OncePerRequestFilter> bean = new FilterRegistrationBean<>(filter);
        bean.setOrder(Ordered.HIGHEST_PRECEDENCE);
        return bean;
    }
}
