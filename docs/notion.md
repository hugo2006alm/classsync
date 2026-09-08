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

## New-user workspace

Recommended onboarding is a duplicate-able Notion template. Publish an empty
ClassSync parent page with **Duplicate as template** enabled. A new user
duplicates it into their own workspace, creates a Notion integration, shares
the copied parent page with that integration, then lets ClassSync discover the
two copied data sources.

Public template:

<https://checker-dryer-7e3.notion.site/ClassSync-Template-3d387b0ef0908153a466c7aa2f8f7332>

The app's Library queries `Histórico de Resumos`, resolves each `Cadeira`
relation against `Lista de Cadeiras`, and groups pages by academic year and
semester. Selecting a lecture reads its Notion blocks inside ClassSync; the
external Notion page remains one tap away.

Opening a class uses a separate relation-filtered query for only its 20 newest
Notion summaries, sorted by `Data` descending. This keeps completed classes
useful when their summaries were created on another device without downloading
the full history. Full page blocks are fetched only after a summary is opened.

ClassSync can later offer **Create workspace** instead. The user must first
grant an integration `insert content` access and select a parent page. The app
can then create the databases and properties under that page through Notion's
API. A token alone does not authorize access to arbitrary private pages.

`Lista de Cadeiras` is canonical. Only rows where `Status = In progress` are classifier candidates. `Histórico de Resumos` receives `Nome`, `Data`, `Cadeira`, and optionally additive ClassSync properties. Schema changes require explicit confirmation and never rename or remove properties.

Generated blocks live inside revision-marked ClassSync-owned toggles. Append
checkpoints use those markers instead of total page-child count. Regenerate,
reclassify, and republish keep the persisted page ID and replace only
ClassSync-owned content, preserving user notes and template blocks.
