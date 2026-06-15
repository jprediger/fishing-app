# Plano 0006 — Design system: migração de cores hardcoded para o `colorScheme`

- **Status:** Proposto
- **Data:** 2026-06-15
- **Relacionado:** `app/lib/theme/app_colors.dart`, `app/lib/theme/app_theme.dart`,
  `app/lib/main.dart`

## Objetivo

Consolidar um design system coerente com **tema claro e escuro**. A fundação já
está pronta (ver Diagnóstico). Falta a migração: trocar as **~70 cores fixas**
(`Colors.white/black/grey/...`) espalhadas pelas telas por **tokens do
`ColorScheme`** (`Theme.of(context).colorScheme`), para que o app inteiro
responda a `ThemeMode.system` (claro/escuro).

## Diagnóstico (situação atual)

**Fundação — feita neste passo:**

- `app/lib/theme/app_colors.dart`: tokens de **marca** (identidade), independentes
  de tema — `primary`, `secondary`, `deep`, `sand`, `waterGradient`. `surface`
  mantido só por compatibilidade.
- `app/lib/theme/app_theme.dart`: `AppTheme.light` / `AppTheme.dark`, ambos
  derivados da mesma seed via `ColorScheme.fromSeed(..., brightness:)`. Component
  themes (appBar, card, navBar, chip) já referenciam tokens do `colorScheme`.
- `main.dart`: usa `theme/darkTheme/themeMode: system`; `AppColors` foi movido e é
  **re-exportado** de `main.dart` (`export 'theme/app_colors.dart'`), então
  `import '../main.dart'` nas telas continua funcionando durante a migração.

**O que falta (escopo deste plano):** as telas ainda têm cores fixas que **não
respondem ao tema**. No dark mode elas ficam erradas (texto preto em fundo
escuro, cards brancos etc.). São ~70 ocorrências em 12 arquivos.

## Mapa de tradução (regra geral)

| Hardcode atual | Token do tema |
| --- | --- |
| `Colors.white` (fundo de card/superfície) | `colorScheme.surface` |
| `Colors.white` (texto/ícone sobre gradiente de água) | **manter** `Colors.white` (gradiente é da marca, claro nos dois temas) |
| `Colors.black87` / `Colors.black` (texto principal) | `colorScheme.onSurface` |
| `Colors.black54` (texto secundário) | `colorScheme.onSurfaceVariant` |
| `Colors.black45` / `Colors.black38` (texto terciário) | `colorScheme.onSurfaceVariant` (ajustar alpha) |
| `Colors.black26` (ícones/chevron sutis) | `colorScheme.outlineVariant` / `onSurfaceVariant` |
| `Colors.black12` (divisores, sombras leves de borda) | `colorScheme.outlineVariant` (borda) ou manter sombra com `colorScheme.shadow` |
| `Colors.black.withValues(alpha: ...)` (sombras) | `colorScheme.shadow.withValues(alpha: ...)` |
| `Colors.red` (estado de erro) | `colorScheme.error` |
| `Colors.orange` (aviso "aproximado") | manter (sem token de warning no M3) ou definir token próprio |
| `AppColors.deep` (texto/destaque) | **caso a caso**: identidade → manter; texto → `colorScheme.onSurface` |
| `AppColors.primary` / `.secondary` / `.sand` / `.waterGradient` | **manter** (identidade de marca) |

Regra mental: **cor de marca/identidade → `AppColors`** (fica). **Cor de
fundo/superfície/texto → `colorScheme`** (migra).

## Como migrar (uma tela por vez)

Para cada arquivo: dentro do `build`, capturar `final cs = Theme.of(context).colorScheme;`
e trocar os hardcodes pela tradução acima. Onde a cor está em `const` (ex.:
`const TextStyle(color: Colors.black54)`), remover o `const` para poder ler `cs`.

Cuidado especial com os **gradientes de água**: textos/ícones brancos sobre
`AppColors.waterGradient` **permanecem brancos** (cabeçalhos de `profile`,
`search`, `auth`, `map`). O que migra são as superfícies "chapadas" (cards,
sheets, fundos de lista, FABs brancos).

## Inventário por arquivo (ordem sugerida: do mais simples ao mais complexo)

1. **`screens/auth_gate.dart`** (2) — `Colors.white` sobre gradiente → manter.
   Provável que não precise mudar nada além de revisar.
2. **`screens/auth_widgets.dart`** (3) — brancos sobre gradiente → manter.
3. **`screens/login_screen.dart`** (1) — branco no botão `AppColors.primary` → manter.
4. **`screens/register_screen.dart`** (1) — idem login.
5. **`screens/edit_profile_screen.dart`** (1) — idem (branco sobre primary).
6. **`screens/fish_picker_sheet.dart`** (1) — `Colors.black12` (sombra/borda) →
   `colorScheme.shadow`/`outlineVariant`.
7. **`screens/catch_detail_screen.dart`** (2) — `Colors.black12` (bordas/sombras).
8. **`screens/catch_form_screen.dart`** (5) — `black.withAlpha`, `white`,
   `black12`, `black54` → `onSurface`/`surface`/`outlineVariant`/`onSurfaceVariant`.
9. **`screens/profile_screen.dart`** (~13) — cabeçalho em gradiente (brancos
   **mantêm**); migrar os `black54`/`black26` da lista de opções e o avatar
   `Colors.white` (vira `colorScheme.surface`).
10. **`screens/search_screen.dart`** (~10) — cabeçalho gradiente (mantém brancos);
    migrar `black87`/`black54`/`black45`/`black26` dos resultados e o `fillColor`
    do campo de busca.
11. **`screens/map_screen.dart`** (~40) — **o maior**. Muitos cards brancos, FABs,
    sombras `black.withAlpha`, textos `black87`/`black54`. Migrar por seção
    (sheets, cards de info, FABs, legendas de marcador). Os marcadores com
    `Shadow(Colors.black38)` podem manter para legibilidade sobre o mapa.

> Total ≈ 70 ocorrências. `main.dart` já não tem mais hardcodes após a fundação.

## Critérios de aceite

- `grep -rn "Colors\.\(white\|black\|grey\)" app/lib/screens` retorna **apenas**
  os casos intencionais sobre gradiente/mapa (documentados com comentário curto).
- App roda em `ThemeMode.system`; alternar o tema do dispositivo troca claro↔escuro
  sem texto ilegível nem card branco no escuro.
- `bash scripts/validate.sh` verde (analyze + format + testes).

## Fora de escopo

- Toggle manual de tema na UI (decisão atual: seguir o sistema).
- Tipografia/spacing tokens (`app_spacing.dart`) — pode virar plano futuro.
- Persistência de preferência de tema.
