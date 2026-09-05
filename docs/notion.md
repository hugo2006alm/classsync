# Notion

ClassSync targets Notion API `2026-03-11` and its data-source model.

Expected semantic structure:

```text
ISEP
├─ Lista de Cadeiras
├─ Cadeiras Ativas
├─ Histórico de Resumos
└─ Cadernos
   ├─ 2º Ano - 2º Semestre
   └─ 3º Ano - 1º Semestre
```

Runtime setup searches accessible data sources and asks the user to confirm mappings. IDs are installation data, never source constants.

`Lista de Cadeiras` is canonical. Only rows where `Status = In progress` are classifier candidates. `Histórico de Resumos` receives `Nome`, `Data`, `Cadeira`, and optionally additive ClassSync properties. Schema changes require explicit confirmation and never rename or remove properties.

Pages are created empty and their remote top-level child count is used as the
append checkpoint. Regenerate, reclassify, and republish operations keep the
persisted page ID, replace its properties/body, and retry against that same page.
