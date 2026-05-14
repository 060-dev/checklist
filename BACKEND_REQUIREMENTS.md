# Backend Requirements — Morro do Peão (Checklists Operacionais)

Este documento descreve os requisitos mínimos e recomendados para um backend que atenda corretamente o aplicativo **Morro do Peão**.

O app foi desenhado para uso rural com conectividade instável. Portanto, o backend precisa suportar **idempotência**, **sincronização incremental** e **upload de anexos** (fotos/áudios) com **retentativas**.

---

## 1) Objetivos do backend

1. Permitir autenticação e autorização de usuários.
2. Organizar o acesso por **organização/fazenda** e permitir múltiplas unidades/áreas.
3. Prover o catálogo de **checklists** (áreas, checklists, perguntas, regras de anexos).
4. Receber **submissões** de checklists (respostas + anexos) com **idempotência** baseada em `clientSubmissionId`.
5. Permitir **histórico** e **auditoria** (quem enviou, quando, status, alterações).
6. Facilitar sincronização offline-first: o cliente pode enviar “mais tarde” e reenviar sem duplicar.

---

## 2) Conceitos e entidades

### 2.1 Organização / Fazenda / Unidade / Área

O app precisa de um “escopo” para dados:

- `organization` (ex.: Cooperativa / Empresa)
- `farm` (ex.: Morro do Peão)
- `unit` (opcional, ex.: Sede / Lote 1 / Lote 2)
- `area` (ex.: Agricultura, Pecuária, Rotina)

Recomendação: `farm` pertence a `organization`. `unit` pertence a `farm`. `area` pertence a `farm` (e opcionalmente a `unit`).

### 2.2 Usuários, Operadores e Perfis de acesso

O app tem pelo menos dois perfis conceituais:

- **Operador**: preenche checklists.
- **Gestor** (quando habilitado): visualiza histórico, pendências, problemas, relatórios.

Requisito: o backend deve suportar **RBAC** (Role Based Access Control), pelo menos:

- `roles`: `operator`, `manager`, `admin`
- `permissions`: leitura/escrita em checklists, usuários, submissões, auditoria.

O app também pode ter “operadores” como entidade separada de “usuário autenticado”:

- Em alguns cenários, o operador pode **não ter login individual** (seleção por lista no dispositivo).
- Nesse caso, o backend deve permitir submissões com `operatorId` que referencia um operador cadastrado (ou aceitar `operatorName` + resolver/normalizar no servidor).

### 2.3 Checklists / Perguntas

O app consome um catálogo de checklists:

- `checklistArea`
- `checklist`
- `question`
- `choices` (quando aplicável)
- regras de anexo: `requiresPhoto`, `allowsAudio`, etc.

Importante: o backend deve versionar checklists (por exemplo, `checklist.version`) para rastrear com qual versão uma submissão foi feita.

### 2.4 Submissões (envios)

Uma submissão representa um checklist preenchido.

Campos essenciais:

- `id` (server)
- `clientSubmissionId` (gerado no cliente; **idempotente**)
- `checklistId`
- `operatorId`
- `farmId` / `organizationId`
- `startedAt`, `completedAt`
- `answers[]`
- `attachments[]`
- `status` (server-side)

Estados sugeridos no servidor:

- `received` (payload recebido)
- `processing` (validando/armazenando anexos)
- `completed` (ok)
- `rejected` (payload inválido)

---

## 3) Autenticação e autorização

### 3.1 Autenticação

Requisito mínimo:

- `Authorization: Bearer <token>` em todas as rotas protegidas.
- Tokens JWT (ou sessão similar) com `userId`, `roles`, `organizationId` e/ou `farmIds`.

Endpoints sugeridos:

#### `POST /auth/login`

**Request**
```json
{ "email": "user@fazenda.com", "password": "..." }
```

**Response**
```json
{ "accessToken": "...", "refreshToken": "...", "expiresIn": 3600 }
```

#### `POST /auth/refresh`

**Request**
```json
{ "refreshToken": "..." }
```

**Response**
```json
{ "accessToken": "...", "expiresIn": 3600 }
```

### 3.2 Seleção de perfil/ambiente

O app pode precisar escolher “em qual fazenda/unidade” o usuário está atuando.

Opções:

1) Token já inclui o `farmId` ativo.
2) Usuário seleciona após login e o backend retorna um `sessionContextId`.

Endpoint sugerido:

#### `GET /me/context`

**Response**
```json
{
  "user": { "id": "...", "name": "...", "roles": ["operator"] },
  "organizations": [{ "id": "org-1", "name": "..." }],
  "farms": [{ "id": "farm-1", "name": "Morro do Peão" }],
  "units": [{ "id": "unit-1", "name": "Sede" }]
}
```

---

## 4) Catálogo de dados (sync de leitura)

O cliente precisa baixar e atualizar o catálogo (áreas, checklists e perguntas).

Requisito: endpoints devem suportar **sincronização incremental**, por exemplo via:

- `updatedSince` (timestamp ISO8601)
- ETag
- ou versão global `catalogVersion`

Endpoints sugeridos:

### `GET /catalog`

**Query**
- `farmId=<id>`
- `updatedSince=2026-01-01T00:00:00Z` (opcional)

**Response**
```json
{
  "serverTime": "2026-05-13T12:00:00Z",
  "catalogVersion": 42,
  "areas": [
    { "id": "daily", "name": "Rotina", "color": "#D99A00", "updatedAt": "..." }
  ],
  "checklists": [
    {
      "id": "daily-open",
      "areaId": "daily",
      "name": "Abertura do Dia",
      "version": 3,
      "estimatedMinutes": 5,
      "updatedAt": "..."
    }
  ],
  "questions": [
    {
      "id": "daily-open-1",
      "checklistId": "daily-open",
      "type": "yes_no",
      "text": "Portão principal aberto?",
      "requiresPhoto": false,
      "allowsAudio": true,
      "choices": null,
      "order": 1,
      "updatedAt": "..."
    }
  ]
}
```

---

## 5) Operadores (lista para seleção)

Mesmo com autenticação, o fluxo do app pode pedir seleção do operador.

### `GET /operators`

**Query**
- `farmId=<id>`
- `active=true` (opcional)

**Response**
```json
{ "operators": [ { "id": "op-1", "name": "Maria" }, { "id": "op-2", "name": "João" } ] }
```

### `POST /operators`

Permite criar/gerenciar operadores (perfil gestor/admin).

---

## 6) Envio de checklist (offline-first)

O envio deve ser **idempotente** usando `clientSubmissionId`.

### 6.1 Payload de submissão (sugerido)

#### `POST /submissions`

**Headers**
- `Authorization: Bearer ...`
- `Idempotency-Key: <clientSubmissionId>` (opcional, mas recomendado)

**Request**
```json
{
  "clientSubmissionId": "c0b5b3d0-...",
  "farmId": "farm-1",
  "checklistId": "daily-open",
  "checklistVersion": 3,
  "operatorId": "op-1",
  "startedAt": "2026-05-13T10:00:00Z",
  "completedAt": "2026-05-13T10:05:00Z",
  "answers": [
    {
      "questionId": "daily-open-1",
      "value": true,
      "notes": "Tudo ok",
      "attachments": ["att-local-1"]
    }
  ],
  "attachments": [
    {
      "localId": "att-local-1",
      "questionId": "daily-open-1",
      "type": "photo",
      "fileName": "photo_1710000000.jpg",
      "mimeType": "image/jpeg",
      "size": 182731
    }
  ],
  "device": {
    "platform": "android",
    "appVersion": "1.0.0",
    "deviceTime": "2026-05-13T10:05:00Z"
  }
}
```

**Response (201 ou 200 se idempotente)**
```json
{
  "submission": {
    "id": "sub-123",
    "clientSubmissionId": "c0b5b3d0-...",
    "status": "received",
    "createdAt": "2026-05-13T10:05:10Z"
  },
  "upload": {
    "mode": "direct" ,
    "attachments": [
      {
        "localId": "att-local-1",
        "uploadUrl": "https://...signed-url...",
        "headers": { "Content-Type": "image/jpeg" },
        "expiresAt": "2026-05-13T10:20:00Z"
      }
    ]
  }
}
```

### 6.2 Upload de anexos

Requisito (para este projeto): o backend deve **armazenar localmente** os anexos (fotos/áudios), isto é, salvar os arquivos no próprio backend (ex.: disco/volume persistente do servidor) e manter referência no banco de dados.

Observação importante (para não misturar anexos entre perguntas):
- `localId` deve ser **único por anexo** dentro de uma submissão.
- O backend deve armazenar e expor a associação **anexo -> questionId** (ex.: `attachment.questionId`).

### Opção A (preferida aqui): upload direto para o backend (armazenamento local)

1) Cliente cria a submissão (`POST /submissions`) informando a lista de anexos (metadados) no payload.
2) Cliente faz upload do arquivo para o backend.
3) Backend salva o arquivo localmente, vincula ao `submissionId` e retorna um `attachmentId` (server).

Endpoints sugeridos:

#### `POST /submissions/{id}/attachments`

- Content-Type: `multipart/form-data`
- Campos sugeridos:
  - `localId` (string)
  - `questionId` (string) — **obrigatório** para anexos de perguntas
  - `type` (string) — `photo` | `audio` (ajuda validação/debug)
  - `file` (binário)

**Response**
```json
{
  "attachment": {
    "id": "att-123",
    "localId": "att-local-1",
    "type": "photo",
    "mimeType": "image/jpeg",
    "size": 182731,
    "storage": {
      "provider": "local",
      "path": "farm-1/sub-123/att-123.jpg"
    }
  }
}
```

#### `POST /submissions/{id}/attachments/complete`

**Request**
```json
{ "uploaded": [ { "localId": "att-local-1", "ok": true } ] }
```

**Response**
```json
{ "status": "completed" }
```

### Opção B (opcional): URLs assinadas para storage externo

Se no futuro for desejado usar S3/GCS/etc, pode-se manter o mesmo fluxo de criação/confirmação, retornando `uploadUrl`/headers por anexo.

---

## 7) Retentativas, erros e idempotência

### 7.1 Idempotência

Regra obrigatória:

- Se `clientSubmissionId` já existir, o backend deve **retornar o mesmo recurso** e não criar duplicata.
- O backend deve permitir que o cliente repita o `POST /submissions` múltiplas vezes.

### 7.2 Erros transitórios vs permanentes

O cliente fará retry automático para:

- timeouts
- 502/503/504
- falha de rede / sem internet

O backend deve:

- retornar `400/422` para erros de validação (não adianta retry)
- retornar `409` apenas se houver conflito não-idempotente (idealmente não ocorrer)

**Resposta de erro recomendada**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Campo X é obrigatório",
    "details": [{ "field": "operatorId", "message": "Obrigatório" }],
    "retryable": false
  }
}
```

### 7.3 Estados offline no cliente

O backend não “vê” offline diretamente, mas precisa suportar:

- submissões chegando fora de ordem
- grande atraso entre `completedAt` e `receivedAt`
- duplicidade de tentativas

---

## 8) Histórico e consulta

### `GET /submissions`

**Query**
- `farmId`
- `date=YYYY-MM-DD` (opcional)
- `operatorId` (opcional)
- `areaId` (opcional)
- `status` (opcional)
- paginação

**Response**
```json
{
  "items": [
    {
      "id": "sub-123",
      "clientSubmissionId": "...",
      "checklistId": "daily-open",
      "operatorId": "op-1",
      "completedAt": "...",
      "status": "completed",
      "problemsFound": 1
    }
  ],
  "nextCursor": null
}
```

### `GET /submissions/{id}`

Retorna detalhes completos, incluindo answers e links de anexos.

---

## 9) Auditoria e logs

Recomendado (para rastreabilidade):

- logar tentativas e status de processamento
- armazenar `device` + IP + userId
- trilha de auditoria para alterações em catálogos e usuários

Campos recomendados em auditoria:

- `actorUserId`
- `action`
- `entityType`, `entityId`
- `timestamp`
- `metadata`

---

## 10) Regras de negócio mínimas

1. `clientSubmissionId` é único por submissão no mundo (UUID recomendado).
2. `operatorId` deve existir e estar ativo (quando aplicável).
3. `checklistId` deve existir e estar ativo.
4. `answers` devem bater com as perguntas do checklist (ou ao menos serem aceitas com validação “best effort”).
5. Upload de anexos deve estar vinculado à submissão.
6. Se anexos não forem enviados, o backend deve permitir completar sem anexos apenas quando a pergunta não exigir.
