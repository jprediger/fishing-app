---
description: Roda a validação robusta (lint + format + testes) de frontend e backend
argument-hint: "[--frontend|--backend] [--fix] [--fast]"
allowed-tools: Bash(./scripts/validate.sh *), Bash(scripts/validate.sh *)
---

Rode o script de validação do projeto e interprete o resultado:

```
./scripts/validate.sh $ARGUMENTS
```

O script valida **frontend (Flutter)** e **backend (Spring Boot)**:

- **Frontend:** `dart format` (check), `flutter analyze --fatal-infos`, `flutter test`.
- **Backend:** `spotlessCheck` (Palantir Java Format), `./gradlew test` + JaCoCo. Os
  testes usam Testcontainers e exigem Docker; sem Docker, os testes são pulados
  (marcados como SKIP) e só roda lint + compilação.

Flags úteis: `--fix` aplica os formatadores automaticamente, `--fast` pula os
testes lentos, `--frontend`/`--backend` limitam o escopo.

Depois de rodar:

1. Se **tudo passou**, confirme em uma linha (mencione etapas puladas, se houver).
2. Se **algo falhou**, mostre a etapa que falhou e a causa raiz a partir da saída.
   - Falhas de formatação → sugira/rode `./scripts/validate.sh --fix`.
   - Falhas de lint/análise → proponha a correção no código.
   - Falhas de teste → identifique o teste e o motivo; não relaxe a asserção só
     para passar — corrija a regressão ou explique por que o comportamento mudou.
3. Não conclua que "passou" sem o exit code 0 do script.
