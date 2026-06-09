# Fishing Backend

API REST do aplicativo de pesca (Univates). Spring Boot 4 + Java 21 + PostgreSQL.

## Stack

| Camada        | Tecnologia                                         |
|---------------|----------------------------------------------------|
| Linguagem     | Java 21                                            |
| Framework     | Spring Boot 4.0.x                                  |
| Persistência  | Spring Data JPA + Hibernate                        |
| Banco         | PostgreSQL 16                                      |
| Migrations    | Flyway                                             |
| Validação     | Jakarta Bean Validation                            |
| Documentação  | springdoc-openapi 3.x + Scalar                     |
| Observabilidade | Spring Boot Actuator + Micrometer (Prometheus)   |
| Boilerplate   | Lombok                                             |
| Build         | Gradle (wrapper)                                   |
| Testes        | JUnit 5 + Mockito + Testcontainers (Postgres real) |

## Arquitetura

Arquitetura em camadas com separação entre entidade de persistência e DTOs de transporte:

```
controller/   → expõe as rotas REST, valida o request, não conhece o banco
service/      → regra de negócio + transações, converte Entity <-> DTO
repository/   → acesso a dados (Spring Data JPA)
entity/       → mapeamento JPA (tabelas)
dto/          → records imutáveis de entrada/saída da API
exception/    → tratamento global de erros (RestControllerAdvice + RFC 7807)
config/       → configuração (OpenAPI, JPA Auditing)
```

Princípios aplicados:

- **Entidade nunca é exposta na API** — entra/sai sempre via DTO (Java 21 `record`).
- **DTO de Request ≠ DTO de Update** — o update exige `ativo`, a criação não.
- **Transações no service** — leitura com `@Transactional(readOnly = true)`, escrita transacional.
- **Erros padronizados (RFC 7807)** — `GlobalExceptionHandler` retorna `ProblemDetail` (padrão Spring 6+).
- **Schema versionado** — Flyway gerencia migrations; `ddl-auto=validate` em produção.
- **Auditoria automática** — `@CreatedDate` / `@LastModifiedDate` via JPA Auditing.
- **Paginação** — `GET /api/produtos` aceita `?page=0&size=20&sort=id`.

## Pré-requisitos

- JDK 21
- Docker + Docker Compose (para o banco)

## Como rodar (desenvolvimento)

O backend roda **direto na máquina** (hot reload via Spring Boot DevTools); só a infra fica em container.

```bash
# 1. Sobe Postgres + pgAdmin
docker compose up -d

# 2. Roda o backend (Flyway aplica migrations, DevTools recarrega ao compilar)
./gradlew bootRun
```

A API sobe em `http://localhost:8080`.

> Hot reload: na IDE (IntelliJ com *Build project automatically*, ou o "Run" do VS Code), salvar um `.java` dispara o restart automático em ~1s. Pelo terminal, rode `./gradlew compileJava` em outro terminal para disparar o reload.

## Como rodar (stack completo / produção)

Sobe tudo em container (backend buildado a partir do `Dockerfile` multi-stage):

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

## Documentação da API

Com a aplicação rodando:

- **Scalar UI:** http://localhost:8080/docs
- **OpenAPI JSON:** http://localhost:8080/v3/api-docs

A UI é renderizada via [Scalar](https://scalar.com/) carregado por CDN. O `ScalarController` serve um HTML estático que aponta para o JSON gerado pelo springdoc em `/v3/api-docs`.

## Observabilidade (Actuator)

- **Health:** http://localhost:8080/actuator/health
- **Info:** http://localhost:8080/actuator/info
- **Métricas (Prometheus):** http://localhost:8080/actuator/prometheus

## Endpoints

Base: `/api/produtos`

| Método | Rota                 | Descrição           | Sucesso |
|--------|----------------------|---------------------|---------|
| GET    | `/api/produtos`      | Lista (paginado)    | 200     |
| GET    | `/api/produtos/{id}` | Busca por id        | 200     |
| POST   | `/api/produtos`      | Cria                | 201     |
| PUT    | `/api/produtos/{id}` | Atualiza            | 200     |
| DELETE | `/api/produtos/{id}` | Remove              | 204     |

Parâmetros de paginação: `?page=0&size=20&sort=id,asc`

Exemplo de criação:

```bash
curl -X POST http://localhost:8080/api/produtos \
  -H "Content-Type: application/json" \
  -d '{"nome":"Vara de pesca","descricao":"Carbono 2.4m","preco":199.90,"quantidadeEstoque":10}'
```

Formato de erro (RFC 7807 `ProblemDetail`):

```json
{
  "type": "about:blank",
  "title": "Recurso não encontrado",
  "status": 404,
  "detail": "Produto não encontrado com id: 99",
  "instance": "/api/produtos/99",
  "timestamp": "2026-06-09T12:00:00Z"
}
```

## Testes

```bash
./gradlew test
```

Usam **Testcontainers** — um container Postgres 16 real é levantado automaticamente, garantindo paridade com produção. Requer Docker disponível.

## Migrations (Flyway)

As migrations ficam em `src/main/resources/db/migration/` no padrão `V{n}__{descricao}.sql`.

| Versão | Arquivo                      | Descrição         |
|--------|------------------------------|-------------------|
| V1     | `V1__create_produtos.sql`    | Cria tabela produtos |

Em produção, o Hibernate está em modo `validate` — qualquer divergência entre o schema e as entidades gera erro na startup antes de atender requests.

## Configuração

Valores via variáveis de ambiente (com defaults para dev em `application.properties`):

| Variável                     | Default (dev)                                |
|------------------------------|----------------------------------------------|
| `SPRING_PROFILES_ACTIVE`     | `dev`                                        |
| `SPRING_DATASOURCE_URL`      | `jdbc:postgresql://localhost:5440/fishingdb` |
| `SPRING_DATASOURCE_USERNAME` | `fishing`                                    |
| `SPRING_DATASOURCE_PASSWORD` | `fishing123`                                 |

Em produção, copie `.env.example` para `.env` e ajuste `POSTGRES_PASSWORD`. O `.env` é lido pelo Docker Compose e **não** é versionado.

### Profiles

| Profile | `show-sql` | `health.show-details` | Quando                         |
|---------|------------|-----------------------|--------------------------------|
| `dev`   | `true`     | `always`              | default; `./gradlew bootRun`   |
| `prod`  | `false`    | `when-authorized`     | `docker-compose.prod.yml`      |

Propriedades fixas relevantes:

| Propriedade                          | Valor                  | Nota                                      |
|--------------------------------------|------------------------|-------------------------------------------|
| `spring.jpa.hibernate.ddl-auto`      | `validate`             | Hibernate só valida o schema; Flyway cria |
| `spring.mvc.problemdetails.enabled`  | `true`                 | Habilita RFC 7807 no Spring MVC           |
| `management.endpoints.web.exposure.include` | `health,info,prometheus` | Actuator expõe o mínimo + métricas |

## Estrutura de pastas

```
backend/
├── src/main/java/com/univates/fishing_backend/
│   ├── FishingBackendApplication.java
│   ├── config/           # JpaConfig (@EnableJpaAuditing), OpenApiConfig
│   ├── controller/       # ProdutoController, ScalarController
│   ├── service/          # ProdutoService
│   ├── repository/       # ProdutoRepository
│   ├── entity/           # Produto (JPA + Auditing)
│   ├── dto/              # ProdutoRequestDTO, ProdutoResponseDTO, ProdutoUpdateDTO (records)
│   └── exception/        # GlobalExceptionHandler (ProblemDetail), ResourceNotFoundException
├── src/main/resources/
│   ├── application.properties
│   └── db/migration/     # V1__create_produtos.sql
├── src/test/java/.../
│   ├── config/           # TestcontainersConfiguration
│   ├── controller/       # ProdutoControllerTest (@SpringBootTest + Testcontainers)
│   └── service/          # ProdutoServiceTest (Mockito puro)
├── docker-compose.yml          # infra de dev (Postgres + pgAdmin)
├── docker-compose.prod.yml     # stack completo (+ app com healthcheck)
├── Dockerfile                  # build de produção (multi-stage)
└── build.gradle
```
