# Plano 0003 — Seed de espécies de peixes do RS

- **Status:** Proposto
- **Data:** 2026-06-14
- **Relacionado:** [Spec 0001 (registro de pesca)](../specs/0001-registro-de-pesca.md)

## Objetivo

Popular o catálogo `fish` com as **espécies de peixes conhecidas no Rio Grande do
Sul**, para que o registro de pesca ([Spec 0001](../specs/0001-registro-de-pesca.md))
tenha de onde selecionar a espécie (FK obrigatória `species_id → fish`).

**Decisões herdadas da spec:** lista plana (sem filtro fino por região/ambiente);
o seletor mostra todas as espécies do seed.

## Diagnóstico (situação atual)

- Tabela `fish` já existe (`V3__create_fish.sql`): colunas `id`, `name`,
  `description`, `region`, `type`, `icon_path`, `created_at` (NOT NULL),
  `updated_at`. `name` tem unique (`uk_fish_name`).
- `type` é o enum **`FishType`**: `FRESHWATER`, `SALTWATER`, `BRACKISH`.
- **Imagem da espécie já existe:** `@Embedded Icon icon` → coluna `icon_path`
  (VARCHAR 512), exposta como `{ "icon": { "path": ... } }`. O front já faz o
  parse (`Fish.iconPath`, `fish.dart:46`) mas **ainda não renderiza** — o
  `_FishAvatar` sempre mostra o placeholder `Icons.set_meal` (`search_screen.dart:357`).
- `GET /api/fish` existe e é **paginado** (default 20, `FishController:29`).
  **Exige autenticação** (`SecurityConfig:61` — `GET /api/**` → `authenticated()`),
  o que é suficiente: o usuário estará logado ao registrar a pesca.
- Escrita (`POST /api/fish`) exige **ADMIN** → semear via API é inconveniente;
  **migration é o caminho**.

## ⚠️ Pré-requisitos / numeração Flyway

- Versões hoje: `V1`, `V2` (duplicada — ver plano 0001), `V3`. O plano 0001
  reserva `V4` para PostGIS/`water_body`.
- **Use a próxima versão livre no momento da implementação.** Como referência,
  este seed pode ser **`V5__seed_fish_rs.sql`** (após o `V4` do plano 0001). Se
  for implementado **antes** do plano 0001, use `V4` aqui e renumere o 0001 —
  Flyway, por padrão, não aplica versões fora de ordem.
- `created_at` é NOT NULL e **não tem default**; a auditoria JPA (`@CreatedDate`)
  só preenche em `persist`, **não** em SQL bruto → o seed precisa informar
  `now()` explicitamente.

## Abordagem

Migration versionada com `INSERT ... ON CONFLICT (name) DO NOTHING` (idempotente
e segura mesmo se alguma espécie já existir). Reaplicar é inofensivo.

> Alternativa considerada: migration **repetível** (`R__seed_fish_rs.sql`) para
> editar a lista com facilidade. Descartada por enquanto — seed de catálogo é
> melhor como versionado (roda uma vez, histórico claro). Pode migrar depois.

## Migration `V5__seed_fish_rs.sql` (rascunho)

```sql
INSERT INTO fish (name, description, region, type, created_at) VALUES
  -- Água doce
  ('Traíra',     'Predador comum em lagoas e açudes.',            'Rio Grande do Sul', 'FRESHWATER', now()),
  ('Jundiá',     'Bagre de água doce, muito pescado no RS.',      'Rio Grande do Sul', 'FRESHWATER', now()),
  ('Dourado',    'Esportivo; presente na bacia do rio Uruguai.',  'Bacia do Uruguai',  'FRESHWATER', now()),
  ('Grumatã',    'Peixe de cardume comum nos rios do sul.',       'Rio Grande do Sul', 'FRESHWATER', now()),
  ('Lambari',    'Pequeno peixe de água doce, abundante.',        'Rio Grande do Sul', 'FRESHWATER', now()),
  ('Carpa',      'Espécie introduzida, comum em açudes.',         'Rio Grande do Sul', 'FRESHWATER', now()),
  ('Tilápia',    'Espécie introduzida, muito difundida.',         'Rio Grande do Sul', 'FRESHWATER', now()),
  ('Black bass', 'Introduzido; alvo de pesca esportiva.',         'Rio Grande do Sul', 'FRESHWATER', now()),
  ('Cará',       'Ciclídeo nativo de águas calmas.',              'Rio Grande do Sul', 'FRESHWATER', now()),
  ('Piava',      'Peixe de água doce de cardume.',                'Rio Grande do Sul', 'FRESHWATER', now()),
  ('Cascudo',    'Peixe de fundo, couraçado.',                    'Rio Grande do Sul', 'FRESHWATER', now()),
  ('Bagre',      'Diversas espécies de bagre de água doce.',      'Rio Grande do Sul', 'FRESHWATER', now()),
  -- Salobra (estuários / Lagoa dos Patos)
  ('Tainha',     'Abundante no inverno; estuários e Lagoa dos Patos.', 'Lagoa dos Patos', 'BRACKISH', now()),
  ('Peixe-rei',  'Comum na Lagoa dos Patos e no litoral.',        'Lagoa dos Patos',   'BRACKISH', now()),
  ('Linguado',   'Peixe achatado de fundo, estuarino.',           'Litoral / estuários','BRACKISH', now()),
  -- Salgada (litoral)
  ('Corvina',    'Costeira; comum na pesca de praia.',            'Litoral Sul',       'SALTWATER', now()),
  ('Robalo',     'Muito procurado no litoral.',                   'Litoral Sul',       'SALTWATER', now()),
  ('Enchova',    'Predador costeiro; pesca esportiva.',           'Litoral Sul',       'SALTWATER', now()),
  ('Pampo',      'Peixe de praia, brigador.',                     'Litoral Sul',       'SALTWATER', now()),
  ('Papa-terra', 'Comum na pesca de praia (betara).',             'Litoral Sul',       'SALTWATER', now()),
  ('Pescada',    'Peixe costeiro do litoral sul.',                'Litoral Sul',       'SALTWATER', now())
ON CONFLICT (name) DO NOTHING;
```

- `icon_path` (imagem da espécie) fica **nulo** — o seed não popula imagens.
- Lista é um **conjunto inicial curado**, fácil de estender em novas migrations.

### Imagem da espécie (decisão)

- **Reaproveitar `icon_path`** como o campo de imagem da espécie. **Sem mudança
  de schema** — não criar coluna nova (seria redundante com o campo existente).
- Seed deixa nulo; imagens podem ser preenchidas depois (via admin/`PUT /api/fish`).

## Backend — nada novo, só verificar

- `GET /api/fish` já serve o picker (paginado). Para o seletor (~21 espécies),
  uma página basta; o app pode pedir `size` maior (já usa `size=50`).
- Confirmar que o catálogo retorna as espécies após a migration (teste de
  integração com testcontainers).

## App — consumo (parte do registro de pesca, Spec 0001)

- O seletor de espécie no fluxo de criação consome `/api/fish` (lista simples).
- Fora do escopo deste plano implementar a tela — aqui o objetivo é só **ter os
  dados**. A tela vem no plano de implementação da Spec 0001.

### Renderização da imagem com fallback (pequena tarefa de front)

- Hoje o `_FishAvatar` (`search_screen.dart`) ignora `iconPath` e sempre mostra
  o placeholder. Ajustar para: **se `iconPath != null` → `Image.network` (com
  `errorBuilder`/`loadingBuilder`); senão → cair para o avatar default atual**
  (`Icons.set_meal` colorido por habitat).
- Como o seed deixa `icon_path` nulo, o comportamento padrão visível continua
  sendo o placeholder — o fallback é justamente o caminho normal por enquanto.

## Ordem de execução

1. Definir a versão Flyway livre (coordenar com 0001 e conflito V2).
2. Criar a migration `V5__seed_fish_rs.sql`.
3. Subir o backend e validar via `GET /api/fish`.
4. Teste de integração cobrindo a presença das espécies.

## Critérios de aceite

- [ ] Migration aplica em banco limpo sem erro.
- [ ] `GET /api/fish` retorna as espécies do RS após a migration.
- [ ] Reaplicar/rodar em banco já populado não duplica nem quebra (idempotente).
- [ ] Cada espécie tem `name`, `type` (FishType válido) e `created_at` preenchidos.

## Questões em aberto

- Validar a lista de espécies com alguém que conheça a pesca local (cobertura e
  nomes populares corretos para o RS).
