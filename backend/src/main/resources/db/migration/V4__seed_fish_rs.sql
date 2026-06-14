-- Seed: espécies de peixes conhecidas no Rio Grande do Sul (plano 0003).
-- Idempotente: ON CONFLICT (name) DO NOTHING -> reaplicar/rodar em banco
-- já populado não duplica nem quebra. created_at é NOT NULL sem default e a
-- auditoria JPA não atua em SQL bruto -> informa now() explicitamente.
INSERT INTO fish (name, description, region, type, created_at) VALUES
  -- Água doce
  ('Traíra',     'Predador comum em lagoas e açudes.',                  'Rio Grande do Sul',  'FRESHWATER', now()),
  ('Jundiá',     'Bagre de água doce, muito pescado no RS.',            'Rio Grande do Sul',  'FRESHWATER', now()),
  ('Dourado',    'Esportivo; presente na bacia do rio Uruguai.',        'Bacia do Uruguai',   'FRESHWATER', now()),
  ('Grumatã',    'Peixe de cardume comum nos rios do sul.',             'Rio Grande do Sul',  'FRESHWATER', now()),
  ('Lambari',    'Pequeno peixe de água doce, abundante.',              'Rio Grande do Sul',  'FRESHWATER', now()),
  ('Carpa',      'Espécie introduzida, comum em açudes.',               'Rio Grande do Sul',  'FRESHWATER', now()),
  ('Tilápia',    'Espécie introduzida, muito difundida.',               'Rio Grande do Sul',  'FRESHWATER', now()),
  ('Black bass', 'Introduzido; alvo de pesca esportiva.',               'Rio Grande do Sul',  'FRESHWATER', now()),
  ('Cará',       'Ciclídeo nativo de águas calmas.',                    'Rio Grande do Sul',  'FRESHWATER', now()),
  ('Piava',      'Peixe de água doce de cardume.',                      'Rio Grande do Sul',  'FRESHWATER', now()),
  ('Cascudo',    'Peixe de fundo, couraçado.',                          'Rio Grande do Sul',  'FRESHWATER', now()),
  ('Bagre',      'Diversas espécies de bagre de água doce.',            'Rio Grande do Sul',  'FRESHWATER', now()),
  -- Salobra (estuários / Lagoa dos Patos)
  ('Tainha',     'Abundante no inverno; estuários e Lagoa dos Patos.',  'Lagoa dos Patos',    'BRACKISH',   now()),
  ('Peixe-rei',  'Comum na Lagoa dos Patos e no litoral.',              'Lagoa dos Patos',    'BRACKISH',   now()),
  ('Linguado',   'Peixe achatado de fundo, estuarino.',                 'Litoral / estuários','BRACKISH',   now()),
  -- Salgada (litoral)
  ('Corvina',    'Costeira; comum na pesca de praia.',                  'Litoral Sul',        'SALTWATER',  now()),
  ('Robalo',     'Muito procurado no litoral.',                         'Litoral Sul',        'SALTWATER',  now()),
  ('Enchova',    'Predador costeiro; pesca esportiva.',                 'Litoral Sul',        'SALTWATER',  now()),
  ('Pampo',      'Peixe de praia, brigador.',                           'Litoral Sul',        'SALTWATER',  now()),
  ('Papa-terra', 'Comum na pesca de praia (betara).',                   'Litoral Sul',        'SALTWATER',  now()),
  ('Pescada',    'Peixe costeiro do litoral sul.',                      'Litoral Sul',        'SALTWATER',  now())
ON CONFLICT (name) DO NOTHING;
