package com.univates.fishing_backend.bootstrap;

/**
 * Contrato de um seed de dados. Implementações são descobertas como beans e
 * executadas pelo {@link SeedRunner} na ordem de {@link #order()}.
 *
 * <p>Cada {@code run()} deve ser <b>idempotente</b> (checar existência antes de
 * inserir) para que reinícios da aplicação não dupliquem dados.
 */
public interface DataSeeder {

    /** Ordem de execução (menor primeiro). */
    int order();

    /** Executa o seed. Deve ser idempotente. */
    void run();
}
