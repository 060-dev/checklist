# Prova de Conceito (POC) — Documentação do App (Flutter)

Este documento descreve **exatamente o que existe hoje** na prova de conceito do aplicativo (telas, fluxos, dados exibidos, dados informados pelo usuário e dados gerados durante o uso), com base no código atual do repositório.

> Fonte de verdade: arquivos em `lib/` (principalmente `lib/nav.dart`, `lib/state/app_session.dart`, `lib/models/*` e `lib/data/checklists_repository.dart`).

---

## 1) Visão geral do app

- App Flutter com navegação via **go_router**.
- Estado global simples via **Provider** (`ChangeNotifierProvider` para `AppSession`).
- Não há backend conectado. Persistência local existe **apenas** para lista de colaboradores (SharedPreferences).
- Checklists e perguntas são **hardcoded** (definições em `lib/data/checklists_repository.dart`).
- Algumas interações (gravação de áudio / foto / câmera) são **simulações/mocks** em UI (sem integração real de microfone/câmera).

Arquivos centrais:

- `lib/main.dart`: bootstrap + Provider.
- `lib/nav.dart`: rotas e redirecionamentos.
- `lib/state/app_session.dart`: estado da sessão do preenchimento, respostas, mock de áudio/foto, e geração do JSON final.
- `lib/models/checklist_models.dart`: modelos das definições (áreas, currais, checklists, perguntas, regras condicionais).
- `lib/data/checklists_repository.dart`: conteúdo dos checklists e perguntas (a “base” da POC).

---

## 2) Rotas e navegação (go_router)

Fonte: `lib/nav.dart`.

### 2.1) Tabela de rotas

| Nome | Path | Tela (Widget) |
|---|---|---|
| home | `/` | `HomePage` |
| collaborators | `/collaborators` | `OperatorSelectionPage` |
| areas | `/areas` | `OperationalAreaSelectionPage` |
| checklists | `/checklists` | `ChecklistSelectionPage` |
| pecuaria | `/pecuaria` | `PecuariaChecklistTypePage` |
| pecuariaGeneral | `/pecuaria/gerais` | `PecuariaGeneralChecklistSelectionPage` |
| pens | `/pecuaria/currais` | `PenSelectionPage` |
| penChecklists | `/pecuaria/currais/checklists` | `PenChecklistSelectionPage` |
| questions | `/checklists/:id/questions` | `ChecklistQuestionPage(checklistId: id)` |
| observation | `/observation` | `ObservationPromptPage` |
| observationRecord | `/observation/record` | `ObservationRecordPage` |
| review | `/review` | `ReviewSubmitPage` |
| success | `/success` | `SuccessPage` |

### 2.2) Regra de redirect (proteção do fluxo)

Fonte: `AppRouter.create(...).redirect` em `lib/nav.dart`.

- Se o usuário estiver em qualquer rota considerada “do fluxo”:
  - começa com `/areas`, `/checklists`, `/pecuaria`, `/observation`, `/review`, `/success`
- **E** `session.selectedOperator == null` (nenhum funcionário selecionado)
- Então o app redireciona para: **`/collaborators`**.

Ou seja: o app força seleção de funcionário antes de avançar no fluxo.

---

## 3) Estado global e dados gerados em runtime (AppSession)

Fonte: `lib/state/app_session.dart`.

### 3.1) Seleções do usuário (contexto da sessão)

Campos mantidos na sessão:

- `selectedOperator: Operator?`
  - selecionado em `OperatorSelectionPage`.
- `selectedArea: OperationalAreaDefinition?`
  - selecionado em `OperationalAreaSelectionPage`.
- `selectedPen: PenDefinition?`
  - selecionado em `PenSelectionPage` (apenas para checklists por curral).
- `selectedChecklist: ChecklistDefinition?`
  - definido em `startChecklist(checklist)` quando o usuário escolhe um checklist.
- `operationalResponsible: OperationalResponsible?`
  - usado **somente** para checklists **por curral** na Pecuária.
  - definido em `PenChecklistSelectionPage` (Tratador / Vaqueiro).

### 3.2) Tempo e progresso do preenchimento

- `startedAt: DateTime?` — setado no início do checklist (`startChecklist`).
- `finishedAt: DateTime?` — setado no envio (`finishNow`).

### 3.3) Respostas, alertas, campos extras, fotos e observação

Respostas são guardadas em:

- `_responsesByQuestionId: Map<String, ChecklistResponse>`

Onde `ChecklistResponse` contém:

- `answer: String` (ex.: `sim`, `nao`, `ok`)
- `level: ChecklistLevelOption?` (quando existe nível/nota)
- `generatedAlert: bool` (true se a resposta disparou alerta)
- `additionalFields: Map<String, AdditionalFieldValue>` (campos extras)
- `photo: PhotoMock?` (foto mock)

Observação final do checklist:

- `_observation: ObservationAudioMock?`
  - gravada (mock) em `ObservationRecordPage`.

### 3.4) Status “do dia” (simulação local, sem persistência)

O app mantém status **em memória** (perde ao reiniciar) para:

- Por curral (penId) e por checklist (checklistId):
  - `_penChecklistStatusByPenIdToday: Map<penId, Map<checklistId, PenChecklistStatus>>`
  - `PenChecklistStatus`: `pendente`, `parcial`, `preenchido`, `comAlerta`
  - `PenSelectionPage` usa `statusForPenToday(penId)` para exibir o status geral do curral.
  - `ReviewSubmitPage` atualiza o status do checklist por curral ao “Enviar checklist”.

- Para checklists gerais da Pecuária (por checklistId):
  - `_generalPecuariaChecklistStatusToday: Map<checklistId, ChecklistDayStatus>`
  - `ChecklistDayStatus`: `pendente`, `preenchido`, `comAlerta`
  - `PecuariaGeneralChecklistSelectionPage` mostra badge do status.
  - `ReviewSubmitPage` atualiza o status ao “Enviar checklist”.

### 3.5) JSON final gerado no envio

Fonte: `AppSession.buildFinalJson()`.

O JSON é gerado ao clicar **Enviar checklist** em `ReviewSubmitPage`. Ele é impresso no console via `debugPrint`.

Estrutura (campos e regras exatamente como o código monta):

```json
{
  "areaId": "...",                 // somente se area != null
  "areaTitulo": "...",            // somente se area != null
  "checklistId": "...",
  "checklistTitulo": "...",
  "aplicacaoPorCurral": true,
  "curral": { "id": "...", "nome": "..." },  // somente se appliesPerPen && pen != null
  "responsavelOperacional": "Tratador",            // somente se operationalResponsible != null
  "funcionario": { "id": "...", "nome": "..." },
  "dataHoraInicio": "YYYY-MM-DDTHH:mm:ss±HH:MM",
  "dataHoraFim": "YYYY-MM-DDTHH:mm:ss±HH:MM",
  "periodicidade": "...",          // somente se checklist.periodicity não vazio
  "respostas": [
    {
      "perguntaId": "...",
      "etapa": "Etapa 1",          // somente se q.stage não vazio
      "bloco": "...",              // somente se q.block não vazio
      "pergunta": "texto...",
      "resposta": "sim",
      "nivel": { "label": "...", "valor": 1 },  // somente se response.level != null
      "gerouAlerta": true,           // somente se response.generatedAlert
      "campoAdicional": {
        "id_do_campo": { "tipo": "texto", "valor": "..." }
        // OU
        "id_do_campo": {
          "tipo": "audio",
          "arquivoLocal": "...",
          "duracaoSegundos": 10,
          "transcricaoMock": "..." // somente se existir
        }
      },
      "foto": { "capturada": true, "arquivoLocal": "foto_mock.jpg" }
    }
  ],
  "observacao": {
    "possuiObservacao": false,
    "tipo": null,
    "arquivoLocal": null,
    "duracaoSegundos": null
  },
  "resumo": {
    "totalPerguntasRespondidas": 10,
    "totalAlertas": 2,
    "totalFotos": 3,
    "statusChecklistAposEnvio": "com_alerta"|"preenchido",

    // Flags adicionais condicionais (somente em casos específicos):
    "possuiQuantidadePorCurral": true,
    "possuiVoltagemInformada": true,
    "possuiAreaMedida": true,
    "possuiEstadoGeralInformado": true,
    "possuiOcorrencia": true
  },
  "status": "pronto_para_envio"
}
```

Observações importantes do JSON:

- `respostas`: percorre `checklist.questions` na ordem, e inclui apenas as perguntas que têm resposta registrada.
- `etapa` e `bloco` só aparecem se estiverem preenchidos na definição da pergunta.
- `campoAdicional` é um mapa por `fieldId` (ex.: `quantidade_por_curral`, `valor_voltagem_observada`, etc.).
- `observacao`: sempre existe, mas com `possuiObservacao=false` quando não gravou.
- Algumas flags em `resumo` são “hardcoded” por IDs específicos, conforme o código (ex.: `possuiVoltagemInformada` só para Ultra Denso).

### 3.6) Arquivos “locais” (mocks) gerados para áudio/foto

O app **não grava arquivo real**; ele cria nomes de arquivo “mock” para simular.

- Fotos (mock): `PhotoMock(localFile: ...)` vem de:
  - `ChecklistPhotoRequestDefinition.mockLocalFile` quando definido na pergunta, ou
  - `_defaultMockPhotoFile(questionId, penId)` em `ChecklistQuestionPage`.

- Observação em áudio (mock): `AppSession.buildObservationMockFilename()` retorna nomes diferentes por checklist/por curral.
  - Exemplos existentes no código:
    - `audio_alimentacao_mock.mp3`
    - `audio_abertura_diaria_mock.mp3`
    - `audio_ultra_denso_mock.mp3`
    - `audio_pocos_artesianos_mock.mp3`
    - `audio_montagem_nova_pastagem_mock.mp3`
    - `audio_analise_gado_mock.mp3`
    - Para checklists por curral específicos, há nomes com sufixo do curral.

---

## 4) Modelos de domínio usados na POC

### 4.1) Operador/Colaborador

Fonte: `lib/models/operator.dart`.

```dart
class Operator {
  final String id;
  final String farmId;
  final String name;
  final bool active;
}
```

Persistência local:

- `OperatorSelectionPage` salva e lê a lista de colaboradores em SharedPreferences:
  - chave: `collaborators_v1`
  - formato: JSON array de `Operator.toJson()`
  - existe um `farmId` fixo de demo: `morro-do-peao-demo`

### 4.2) Área operacional

Fonte: `OperationalAreaDefinition` em `lib/models/checklist_models.dart`.

Campos:
- `id`, `title`, `description`, `icon`

Repositório:
- `OperationalAreasRepository.available` contém 2 áreas:
  - `Agricultura` (`area_agricultura`)
  - `Pecuária` (`area_pecuaria`)

### 4.3) Curral (Pen)

Fonte: `PenDefinition` e `PensRepository` em `lib/models/checklist_models.dart`.

- `PensRepository.available` contém 12 currais:
  - `curral_01` a `curral_12` com nomes `Curral 1` a `Curral 12`

### 4.4) Definições de checklist e perguntas

Fonte: `lib/models/checklist_models.dart`.

Principais conceitos:

- `ChecklistDefinition`
  - `id`, `title`, `description`, `icon`, `areaId`
  - `appliesPerPen: bool` (se é por curral)
  - `responsible: OperationalResponsible?` (usado para organizar checklists por curral)
  - `periodicity: String?` (usado no JSON)
  - `questions: List<ChecklistQuestion>`

- `ChecklistQuestion`
  - `id`
  - `stage` (ex.: “Etapa 1”)
  - `block` (ex.: “BOIA / Cocho”)
  - `text` (texto na tela)
  - `audioText` (texto enviado para TTS)
  - `answerType: ChecklistAnswerType`
    - `simNao`, `simNaoOk`, `simNaoComNivel`
  - `options: List<String>` (ex.: `['sim','nao']`)
  - `required: bool`
  - Condicionais:
    - `displayWhen: ChecklistDisplayWhen?`
    - `displayWhenAny: List<ChecklistDisplayWhen>`
  - Alerta:
    - `alertWhenAnswer`, `alertMessage`
  - Interstitial:
    - `interstitial: ChecklistInterstitialDefinition?`
  - Campo adicional:
    - `additionalField: ChecklistAdditionalFieldDefinition?`
  - Nível/nota:
    - `level: ChecklistLevelDefinition?`
  - Foto:
    - `photoRequest: ChecklistPhotoRequestDefinition?`

---

## 5) Telas existentes (todas) e o que mostram / coletam

Nesta seção, cada tela inclui:

- **Rota**
- **O que aparece**
- **O que o usuário informa/seleciona**
- **O que é salvo/gerado**
- **Para onde navega**

### 5.1) HomePage

Fonte: `lib/screens/home_page.dart`

- **Rota:** `/`
- **UI:** imagem de fundo (`assets/images/background.png`), “badge” circular com logo (`assets/images/logo.png`), texto de boas-vindas e botão “Começar”.
- **Ação do usuário:** tocar em **Começar**.
- **Navegação:** `context.go('/collaborators')`.

### 5.2) OperatorSelectionPage (Funcionários)

Fonte: `lib/screens/operator_selection_page.dart`

- **Rota:** `/collaborators`
- **UI:**
  - Título “Funcionários”, subtítulo “Cadastre e selecione um funcionário”.
  - Botão “Cadastrar novo colaborador” (abre bottom sheet com TextField).
  - Lista de colaboradores (cards).
- **Dados lidos/gravação local:**
  - Lê e salva lista em SharedPreferences (`collaborators_v1`).
  - Se estiver vazio/corrompido, gera fallback fixo: Marcos, João, Maria, Pedro.
- **O que o usuário informa/seleciona:**
  - Seleciona um colaborador da lista.
  - Pode cadastrar novo colaborador informando um **nome** no bottom sheet.
- **O que é salvo/gerado:**
  - Ao selecionar: `AppSession.selectOperator(op)`.
  - Ao cadastrar: cria `Operator(id: 'op-<timestamp>', farmId: 'morro-do-peao-demo', name: <input>, active: true)` e salva em prefs.
- **Navegação:**
  - Selecionar colaborador: `context.go('/areas')`.
  - Voltar: `context.go('/')`.

### 5.3) OperationalAreaSelectionPage (Escolha a área)

Fonte: `lib/screens/operational_area_selection_page.dart`

- **Rota:** `/areas`
- **UI:**
  - Saudação “Olá, <nome>” se operador selecionado.
  - Lista de áreas (`OperationalAreasRepository.available`): Agricultura e Pecuária.
- **O que o usuário seleciona:**
  - Uma área operacional.
- **O que é salvo/gerado:**
  - `AppSession.selectOperationalArea(area)`.
  - Ao selecionar a área, também zera `selectedPen` no `AppSession`.
- **Navegação:**
  - Se área == Pecuária: `context.push('/pecuaria')`.
  - Caso contrário: `context.push('/checklists')`.

### 5.4) ChecklistSelectionPage (Checklists — Agricultura)

Fonte: `lib/screens/checklist_selection_page.dart`

- **Rota:** `/checklists`
- **UI:**
  - Saudação “Olá, <nome>”
  - Lista de checklists da área selecionada (default se nulo: Agricultura)
    - carregada via `ChecklistsRepository.availableForArea(areaId)`.
- **O que o usuário seleciona:**
  - Um checklist.
- **O que é salvo/gerado:**
  - `AppSession.startChecklist(checklist)`:
    - seta `selectedChecklist`
    - seta `startedAt=DateTime.now()`
    - limpa respostas, observação e interstitials já mostrados.
- **Navegação:**
  - Abre perguntas: `context.push('/checklists/<id>/questions')`.

### 5.5) PecuariaChecklistTypePage (Pecuária — tipo)

Fonte: `lib/screens/pecuaria_checklist_type_page.dart`

- **Rota:** `/pecuaria`
- **UI:**
  - Título “O que você quer preencher?”
  - Dois cards:
    - “Checklists por Curral”
    - “Checklists Gerais”
  - Mostra “Funcionário: <nome>” (se selecionado).
- **O que o usuário seleciona:**
  - O grupo de checklists.
- **Navegação:**
  - Por curral: `context.push('/pecuaria/currais')`
  - Gerais: `context.push('/pecuaria/gerais')`

### 5.6) PenSelectionPage (Selecionar curral)

Fonte: `lib/screens/pen_selection_page.dart`

- **Rota:** `/pecuaria/currais`
- **UI:**
  - Grid com 12 currais (`PensRepository.available`).
  - Cada card mostra nome do curral e um badge de status:
    - Status calculado por `session.statusForPenToday(penId)`.
- **O que o usuário seleciona:**
  - Um curral.
- **O que é salvo/gerado:**
  - `AppSession.selectPen(pen)`.
- **Navegação:**
  - `context.push('/pecuaria/currais/checklists')`.

### 5.7) PenChecklistSelectionPage (Checklists do curral, separados por responsável)

Fonte: `lib/screens/pen_checklist_selection_page.dart`

- **Rota:** `/pecuaria/currais/checklists`
- **UI (2 etapas na mesma tela):**
  1) Escolha de rotina/responsável (quando `session.operationalResponsible == null`)
     - Botões grandes:
       - Tratador (`OperationalResponsible.tratador`)
       - Vaqueiro (`OperationalResponsible.vaqueiro`)
  2) Lista de checklists filtrados por responsável
     - Filtra assim:
       - pega checklists da Pecuária onde `appliesPerPen == true`
       - e filtra por `checklist.responsible == session.operationalResponsible`.
- **O que o usuário seleciona:**
  - Uma rotina (Tratador/Vaqueiro).
  - Depois, um checklist.
- **O que é salvo/gerado:**
  - Ao escolher rotina: `AppSession.setOperationalResponsible(value)`.
  - Ao escolher checklist: `AppSession.startChecklist(checklist)`.
- **Navegação:**
  - Ao escolher checklist: `context.push('/checklists/<id>/questions')`.

### 5.8) PecuariaGeneralChecklistSelectionPage (Pecuária — Checklists gerais)

Fonte: `lib/screens/pecuaria_general_checklist_selection_page.dart`

- **Rota:** `/pecuaria/gerais`
- **UI:**
  - Lista de checklists da Pecuária onde `appliesPerPen == false`.
  - Cada card tem badge de status do dia:
    - `session.statusForGeneralChecklistToday(checklist.id)`.
- **O que o usuário seleciona:**
  - Um checklist geral.
- **O que é salvo/gerado:**
  - `AppSession.startChecklist(checklist)`.
- **Navegação:**
  - `context.push('/checklists/<id>/questions')`.

### 5.9) ChecklistQuestionPage (Perguntas do checklist)

Fonte: `lib/screens/checklist_question_page.dart`

- **Rota:** `/checklists/:id/questions`
- **Entrada:** `checklistId` via path parameter.
- **UI (por pergunta):**
  - Header com:
    - Área (se selecionada)
    - Título do checklist
    - Operador
    - Curral (apenas se `checklist.appliesPerPen`)
    - bloco (`q.block`) e etapa (`q.stage`) quando existem
    - progresso “Pergunta X de Y”
  - Card com texto da pergunta (`q.text`)
  - Botão “Ouvir pergunta”
    - chama TTS: `TtsService.instance.speak(q.audioText)`
  - Barra de respostas (`AnswerBar`) com botões para `options`.

#### 5.9.1) Tipos de resposta e opções exibidas

Existe uma defesa explícita no build:

- Se `q.answerType == ChecklistAnswerType.simNao` → opções forçadas para `['sim', 'nao']`.
- Se `q.answerType == ChecklistAnswerType.simNaoComNivel` → opções forçadas para `['sim', 'nao']`.
- Se `q.answerType == ChecklistAnswerType.simNaoOk` → usa `q.options`.

Ou seja: perguntas Sim/Não nunca exibem “OK”.

#### 5.9.2) O que acontece ao responder

Ao tocar em uma opção:

1) Salva resposta: `session.saveAnswer(questionId, answer)`.
2) Marca alerta se aplicável (`alertWhenAnswer` + `alertMessage`):
   - se disparar, abre bottom sheet **bloqueante** `ChecklistAlertSheet` com botão “Entendi”.
3) Se existe `interstitial` e a resposta bate (`whenAnswer`):
   - abre bottom sheet bloqueante `_ChecklistInterstitialSheet`.
   - deduplica por run usando `interstitial.id ?? q.id` e `AppSession._shownInterstitialIds`.
4) Se a pergunta tem `level` (e é required e atende `requiredWhenAnswer`):
   - abre `LevelSelectSheet`.
5) Se a pergunta tem `additionalField` e a resposta bate `requiredWhenAnswer`:
   - abre um bottom sheet para coletar `AdditionalFieldValue`.
   - existem sheets dedicados por `fieldId`:
     - `quantidade_por_curral` → `QuantidadePorCurralSheet`
     - `valor_voltagem_observada` → `VoltagemObservadaSheet`
     - `area_medida` → `AreaMedidaSheet`
     - demais → `AdditionalFieldSheet`
6) Se a pergunta tem `photoRequest` e a resposta bate `requiredWhenAnswer`:
   - abre `PhotoCaptureSheet` (simulação).
7) Recalcula visibilidade de perguntas condicionais e remove respostas que ficaram ocultas:
   - `session.removeResponses(hiddenQuestionIds)`.
8) Avança índice; se acabou, vai para `/observation`.

### 5.10) ObservationPromptPage (Pergunta de observação)

Fonte: `lib/screens/observation_prompt_page.dart`

- **Rota:** `/observation`
- **UI:** “Quer gravar alguma observação?”
- **Ação do usuário:**
  - “Sim, gravar áudio” → vai para gravação
  - “Não, finalizar” → vai para revisão
- **Navegação:**
  - `context.go('/observation/record')` ou `context.go('/review')`

### 5.11) ObservationRecordPage (Gravar observação)

Fonte: `lib/screens/observation_record_page.dart`

- **Rota:** `/observation/record`
- **UI:**
  - Indicador de gravação com segundos.
  - Botão iniciar/parar.
  - Após gravar, aparecem botões: “Ouvir áudio” (SnackBar mock), “Gravar novamente”, “Continuar”.
- **O que o usuário informa:**
  - Interação de gravação (mock).
- **O que é salvo/gerado:**
  - Ao parar: `AppSession.setObservationMock(ObservationAudioMock(...))`
    - `localFile` vem de `AppSession.buildObservationMockFilename()`
    - `durationSeconds` = `_seconds.clamp(3, 60)`
- **Navegação:**
  - “Continuar” → `context.go('/review')`

### 5.12) ReviewSubmitPage (Revisar checklist)

Fonte: `lib/screens/review_submit_page.dart`

- **Rota:** `/review`
- **UI (resumo):**
  - Mostra:
    - Área
    - Funcionário
    - Checklist (e ID do checklist em memória, usado para condições)
    - Curral (se aplica)
    - Rotina (se appliesPerPen)
  - Contadores:
    - quantidade de respostas `sim`, `nao`, `ok`
    - total de alertas
    - observação em áudio (sim/não)
    - “Campos extras: sim/não” (ou, no caso específico do checklist Colheita: “Observação sobre perdas”)
    - fotos anexadas: total
  - Mostra “conclusão por bloco” (se o checklist tem `block` nas perguntas visíveis):
    - para cada bloco, `preenchido` se todas as perguntas visíveis daquele bloco têm resposta.
  - Botão de ação: **Enviar checklist**.
  - Ação técnica (AppBar): **Ver JSON (técnico)**.

#### 5.12.1) “Ver JSON (técnico)”

- Abre bottom sheet com texto selecionável do JSON gerado por `session.buildFinalJsonPretty()`.
- Se der erro (sessão incompleta), mostra:
  - `{ "erro": "Sessão incompleta" }`

#### 5.12.2) “Enviar checklist”

Ao enviar:

1) `session.finishNow()`
2) Tenta gerar JSON (`buildFinalJson`), imprime em log.
3) Atualiza status “do dia” dependendo do tipo:
   - Se `checklist.appliesPerPen == true` e `pen != null`:
     - `PenChecklistStatus` = `comAlerta` se `session.hasAnyAlert()` senão `preenchido`
     - `session.updatePenChecklistStatusToday(penId, checklistId, status)`
     - configura tela de sucesso para voltar a `/pecuaria/currais/checklists`
   - Senão, se for “Pecuária geral” (`area.id == pecuaria` e checklist != null e `!appliesPerPen`):
     - `ChecklistDayStatus` = `comAlerta` se `hasAnyAlert` senão `preenchido`
     - `session.updateGeneralChecklistStatusToday(checklistId, status)`
     - configura sucesso para voltar a `/pecuaria/gerais`
   - Caso contrário (ex.: Agricultura):
     - configura sucesso para voltar a `/checklists`
4) Navega para `context.go('/success')`.

### 5.13) SuccessPage (Sucesso)

Fonte: `lib/screens/success_page.dart`

- **Rota:** `/success`
- **UI:**
  - Ícone de check
  - Título e mensagem (podem ser sobrescritos por `AppSession.prepareSuccess`).
  - Botão final com label e ícone variando (depende da rota de retorno).
- **O que é feito ao clicar voltar:**
  - `AppSession.resetChecklistRunOnly()`
    - limpa apenas dados do “run atual” (checklist selecionado, timestamps, respostas, observação, interstitials e overrides)
    - **mantém** `selectedOperator` e `selectedArea` para acelerar novo preenchimento
  - `context.go(returnLocation)`

---

## 6) Checklists existentes e perguntas (conteúdo exato)

Fonte: `lib/data/checklists_repository.dart`.

> Observação: as opções das perguntas são strings minúsculas (ex.: `sim`, `nao`, `ok`). A UI converte para “Sim”, “Não”, “Ok”.

### 6.1) Agricultura (`area_agricultura`)

#### 6.1.1) Checklist: Preparação do Solo (`checklist_preparacao_solo`)

- `appliesPerPen`: false
- Perguntas:
  1. `conferiu_checklist_precisa` — “Conferiu o checklist diário da Precisa?” (sim/nao)
  2. `conferiu_checklist_trator` — “Conferiu o checklist diário do trator?” (sim/nao)
  3. `conferiu_checklist_carregadeira` — “Conferiu o checklist diário da carregadeira?” (sim/nao)
  4. `maquina_apresenta_defeito` — “A máquina apresenta defeito?” (sim/nao) **alerta quando** `sim`: “Não sair do barracão. Avisar o responsável.”
  5. `recebeu_produtos` — “Recebeu os produtos para aplicação?” (sim/nao)
  6. `recebeu_mapeamento_area` — “Recebeu o mapeamento da área?” (sim/nao)
  7. `carregou_precisa_corretamente` — “Carregou a Precisa corretamente?” (sim/nao)
  8. `aplicou_conforme_mapa` — “Aplicou nas áreas conforme o mapa?” (sim/nao)
  9. `finalizou_talhao_planejamento` — “Finalizou o talhão conforme o planejamento?” (sim/nao)

#### 6.1.2) Checklist: Manutenção Preventiva (`checklist_manutencao_preventiva`)

- `appliesPerPen`: false
- Perguntas:
  1. `realizou_troca_oleo` — “Realizou troca de óleo?” (sim/nao)
  2. `verificou_estado_pneus` — “Verificou o estado dos pneus?” (sim/nao)
  3. `realizou_inspecao_geral_maquina` — “Realizou inspeção geral da máquina?” (sim/nao)
  4. `equipamento_apto_para_plantio` — “Equipamento apto para plantio?” (sim/nao) **alerta quando** `nao`: “Atenção: equipamento não apto para plantio. Avisar o responsável antes de continuar.”

#### 6.1.3) Checklist: Dessecação dos Talhões (`checklist_dessecacao_talhoes`)

- `appliesPerPen`: false
- Perguntas:
  1. `receita_preparada_conforme_planejamento` — “Receita preparada conforme planejamento agronômico?” (sim/nao)
  2. `vestiu_epi_completo` — “Vestiu EPI completo?” (sim/nao) **alerta quando** `nao`
  3. `colocou_meio_tanque_agua` — “Colocou meio tanque de água?” (sim/nao)
  4. `separou_herbicidas_corretos` — “Separou os herbicidas corretos?” (sim/nao)
  5. `mediu_volume_correto_produtos` — “Mediu o volume correto dos produtos?” (sim/nao) + campo adicional `volume_de_cada_produto` (texto/áudio) quando `sim`
  6. `completou_tanque_com_agua` — “Completou o tanque com água?” (sim/nao)
  7. `condicao_vento_adequada` — “Condição de vento entre 3 e 12 km/h?” (sim/nao) **alerta quando** `nao`
  8. `umidade_acima_55` — “Umidade acima de 55%?” (sim/nao) **alerta quando** `nao`
  9. `temperatura_abaixo_30` — “Temperatura abaixo de 30 graus?” (sim/nao) **alerta quando** `nao`
  10. `sem_chuva_no_momento` — “Está sem chuva no momento?” (sim/nao) **alerta quando** `nao`
  11. `aplicacao_conforme_talhao_definido` — “Aplicação realizada conforme talhão definido?” (sim/nao)
  12. `equipamento_limpo_apos_aplicacao` — “Equipamento limpo após aplicação?” (sim/nao) + foto quando `sim` (mock `foto_equipamento_limpo_mock.jpg`)
  13. `epi_armazenado_corretamente` — “EPI armazenado corretamente?” (sim/nao)

#### 6.1.4) Checklist: Plantio (`checklist_plantio`)

- `appliesPerPen`: false
- Perguntas:
  1. `recebeu_sementes` — “Recebeu sementes?” (sim/nao) + foto quando `sim` (mock `foto_sementes_recebidas_mock.jpg`)
  2. `armazenou_protegido_sol_chuva` — “Armazenou protegido de sol e chuva?” (sim/nao) **alerta quando** `nao`
  3. `preparou_calda_tratamento` — “Preparou calda para tratamento?” (sim/nao)
  4. `regulou_tratadora_corretamente` — “Regulou a tratadora corretamente?” (sim/nao) + foto quando `sim` (mock `foto_tratadora_regulada_mock.jpg`)
  5. `tratamento_realizado_padrao_100kg_min` — “Tratamento realizado no padrão de 100 kg por minuto?” (sim/nao) **alerta quando** `nao`
  6. `transporte_bag_tratado_correto` — “Transporte do bag tratado correto?” (sim/nao)
  7. `plantadeira_abastecida_corretamente` — “Plantadeira abastecida corretamente?” (sim/nao)
  8. `regulagem_realizada` — “Regulagem realizada?” (sim/nao)
  9. `nova_regulagem_ao_trocar_variedade` — “Nova regulagem ao trocar variedade?” (sim/nao)
  10. `projeto_linha_carregado_gps` — “Projeto de linha carregado no GPS?” (sim/nao) **alerta quando** `nao`

#### 6.1.5) Checklist: Tratamento de Sulco (`checklist_tratamento_sulco`)

- `appliesPerPen`: false
- Perguntas (todas sim/nao, com `stage`):
  - Etapa 1:
    1. `etapa_1_preparou_calda_biologicos_nutricao`
    2. `etapa_1_mediu_produtos_ibc_1000l`
    3. `etapa_1_transferiu_para_micron_com_bomba`
    4. `etapa_1_regulou_sistema_acoplado` (**alerta quando** `nao`)
  - Etapa 2:
    5. `etapa_2_preparou_calda_biologicos_nutricao`
    6. `etapa_2_mediu_produtos_ibc_1000l`
    7. `etapa_2_transferiu_para_micron_com_bomba`
    8. `etapa_2_regulou_sistema_acoplado` (**alerta quando** `nao`)

#### 6.1.6) Checklist: Operação Diária de Plantio (`checklist_operacao_diaria_plantio`)

- `appliesPerPen`: false
- Perguntas (todas sim/nao, com `stage` Etapa 1/2/3):
  - Etapa 1:
    1. `etapa_1_abastecimento_diario`
    2. `etapa_1_plantadeira_operando_conforme_gps` (**alerta quando** `nao`)
    3. `etapa_1_finalizou_talhao_conforme_planejamento`
  - Etapa 2:
    4. `etapa_2_abastecimento_diario`
    5. `etapa_2_plantadeira_operando_conforme_gps` (**alerta quando** `nao`)
    6. `etapa_2_finalizou_talhao_conforme_planejamento`
  - Etapa 3:
    7. `etapa_3_abastecimento_diario`
    8. `etapa_3_plantadeira_operando_conforme_gps` (**alerta quando** `nao`)
    9. `etapa_3_finalizou_talhao_conforme_planejamento`

> Nota: a palavra “continua” aparece no **texto** das perguntas da Etapa 2 e Etapa 3, mas não no ID.

#### 6.1.7) Checklist: Tratos Culturais Semanais (`checklist_tratos_culturais_semanais`)

- `periodicity`: `semanal`
- Perguntas:
  1. `receita_preparada_conforme_agronomo`
  2. `epi_utilizado` (**alerta quando** `nao`)
  3. `condicoes_ambientais_adequadas` (**alerta quando** `nao`)
  4. `aplicacao_realizada_corretamente`
  5. `equipamento_limpo_apos_uso` + foto quando `sim` (mock `foto_equipamento_limpo_apos_uso_mock.jpg`)
  6. `aplicacao_dentro_estrategia_25_dias_colheita` (**alerta quando** `nao`)

#### 6.1.8) Checklist: Colheita (`checklist_colheita`)

- `appliesPerPen`: false
- Perguntas:
  1. `cultura_estagio_fisiologico_correto` (**alerta quando** `nao`)
  2. `umidade_adequada_para_armazenagem` (**alerta quando** `nao`)
  3. `pre_regulagem_realizada`
  4. `regulagem_fina_realizada_campo`
  5. `avaliou_perdas_chao_copo_medidor_embrapa` + campo adicional `observacao_perdas_chao` (texto/áudio) quando `sim`
  6. `calibracao_ajustada_apos_contagem`
  7. `equipe_abastecimento_disponivel`
  8. `processo_realizado_todos_talhoes`
  9. `limpeza_pos_colheita_realizada` + foto quando `sim` (mock `foto_limpeza_pos_colheita_mock.jpg`)
  10. `encaminhado_manutencao_corretiva`

### 6.2) Pecuária (`area_pecuaria`)

#### 6.2.1) (Por curral) Checklist: Confinamento - Leitura 3B (`checklist_confinamento_leitura_3b`)

- `appliesPerPen`: true
- `responsible`: Tratador
- Perguntas (com blocos e níveis/fotos em alguns casos):
  - Bloco **BOIA / Cocho**
    1. `boia_registrar_nota_leitura_cocho` — sim/nao + **nível obrigatório** quando `sim` (0/1/2) + foto quando `sim`
    2. `boia_registrar_classificacao_quadro_fisico` — sim/nao
    3. `boia_informar_ricardo_resultado_leitura` — sim/nao
  - Bloco **BOSTA / Fezes**
    4. `bosta_registrar_avaliacao_fezes` — sim/nao + **nível obrigatório** quando `sim` (Boa/Média/Ruim) + foto quando `sim`
    5. `bosta_identificou_sinais_diarreia` — sim/nao; **alerta quando** `sim`; interstitial `bosta_followup_intro` quando `sim`
    6. `bosta_observou_animal_debilitado` — sim/nao; **alerta quando** `sim`; interstitial `bosta_followup_intro` quando `sim`
    7. `bosta_monitorou_animal_1_dia` — sim/nao; aparece quando ANY (`bosta_identificou_sinais_diarreia==sim` OR `bosta_observou_animal_debilitado==sim`)
    8. `bosta_animal_persiste_debilitado` — sim/nao; aparece quando ANY (mesma regra); **alerta quando** `sim`
    9. `bosta_removeu_animal_curral` — sim/nao; aparece quando ANY
    10. `bosta_realizou_medicacao` — sim/nao; aparece quando ANY
    11. `bosta_registrou_ocorrencia_obrigatoria` — sim/nao; aparece quando ANY; **alerta quando** `nao`
  - Bloco **BOI**
    12. `boi_realizou_leitura_visual_rumen` — sim/nao + foto quando `sim`
    13. `boi_registrar_resultado_leitura` — sim/nao + **nível obrigatório** quando `sim` (Baixo/Médio/Ideal)

#### 6.2.2) (Por curral) Checklist: Manutenção Preventiva do Curral (`checklist_manutencao_preventiva_curral`)

- `appliesPerPen`: true
- `responsible`: Vaqueiro
- Perguntas:
  1. `conferiu_estrutura_curral` — sim/nao
  2. `identificou_necessidade_reparo` — sim/nao; **alerta quando** `sim`
  3. `comunicou_diretoria_se_necessario` — sim/nao; aparece quando `identificou_necessidade_reparo==sim`; **alerta quando** `nao`

#### 6.2.3) (Por curral) Checklist: Lavagem de Bebedouro (`checklist_lavagem_bebedouro_curral`)

- `appliesPerPen`: true
- `responsible`: Tratador
- Perguntas:
  1. `foi_ate_bebedouro` — sim/nao; **alerta quando** `nao`
  2. `teria_coragem_provar_agua` — sim/nao; foto quando `sim`; interstitial quando `nao` (“Vamos fazer a limpeza do bebedouro...”) 
  3. `descartou_agua_suja` — sim/nao; aparece quando `teria_coragem_provar_agua==nao`
  4. `lavou_bebedouro_completamente` — sim/nao; aparece quando `teria_coragem_provar_agua==nao`; foto quando `sim`
  5. `reabasteceu_com_agua_limpa` — sim/nao; aparece quando `teria_coragem_provar_agua==nao`; **alerta quando** `nao`

#### 6.2.4) (Geral) Checklist: Alimentação (`checklist_alimentacao_pecuaria`)

- `appliesPerPen`: false
- Perguntas (com blocos):
  - Bloco **Conferência inicial**
    1. `checklist_diario_vagao_realizado` — sim/nao; **alerta quando** `nao`
    2. `checklist_trator_realizado` — sim/nao; **alerta quando** `nao`
    3. `checklist_carregadeira_realizado` — sim/nao; **alerta quando** `nao`
  - Bloco **Preparo do trato**
    4. `carregou_milho_soja_nupnio_corretamente` — sim/nao
    5. `carregou_silo` — sim/nao
    6. `esperou_7_minutos_vagao_misturar` — sim/nao; **alerta quando** `nao`
    7. `conferiu_quantidade_necessaria_por_curral` — sim/nao; campo adicional `quantidade_por_curral` quando `sim`
  - Bloco **Distribuição**
    8. `liberou_trato_corretamente` — sim/nao; **alerta quando** `nao`
    9. `conferiu_leitura_balanca` — sim/nao; **alerta quando** `nao`

#### 6.2.5) (Geral) Checklist: Abertura Diária (`checklist_abertura_diaria_pecuaria`)

- `appliesPerPen`: false
- Perguntas:
  - Bloco **Limpeza inicial**
    1. `descartou_agua_noite_anterior` — sim/nao; **alerta quando** `nao`
    2. `lavou_bebedouro_retirou_baba_lodo` — sim/nao; **alerta quando** `nao`; foto quando `sim` (mock `foto_bebedouro_abertura_diaria_mock.jpg`)
  - Bloco **Organização da área**
    3. `tirou_linha_choque_ultra_densos` — sim/nao; **alerta quando** `nao`
    4. `retirou_cercas_eletricas_dia_anterior` — sim/nao; **alerta quando** `nao`
  - Bloco **Montagem da nova área**
    5. `comecou_colocar_barras_novamente` — sim/nao
    6. `colocou_linhas` — sim/nao
    7. `fechou_nova_pastagem` — sim/nao; **alerta quando** `nao`

#### 6.2.6) (Geral) Checklist: Ultra Denso (`checklist_ultra_denso_pecuaria`)

- `appliesPerPen`: false
- Perguntas:
  - Bloco **Verificação elétrica**
    1. `conferiu_voltagem` — sim/nao; campo adicional `valor_voltagem_observada` quando `sim`; **alerta quando** `nao`
    2. `voltagem_abaixo_8000` — sim/nao; **alerta quando** `sim`; interstitial `ultra_denso_correcao_intro` quando `sim`
  - Bloco **Diagnóstico**
    3. `identificou_fuga_energia` — sim/nao; aparece quando `voltagem_abaixo_8000==sim`; **alerta quando** `sim`
  - Bloco **Correção**
    4. `corrigiu_problema` — sim/nao; aparece quando ANY (`voltagem_abaixo_8000==sim` OR `identificou_fuga_energia==sim`); **alerta quando** `nao`
  - Bloco **Validação final**
    5. `conferiu_retorno_voltagem` — sim/nao; aparece quando ANY (`voltagem_abaixo_8000==sim` OR `identificou_fuga_energia==sim` OR `corrigiu_problema==sim`); **alerta quando** `nao`

#### 6.2.7) (Geral) Checklist: Poços Artesianos (`checklist_pocos_artesianos_pecuaria`)

- `appliesPerPen`: false
- Perguntas:
  - Bloco **Verificação da bomba**
    1. `verificou_funcionamento_bomba` — sim/nao; **alerta quando** `nao`
  - Bloco **Verificação do painel**
    2. `painel_indica_normalidade` — sim/nao; **alerta quando** `nao`; foto quando `sim` (mock `foto_painel_poco_artesiano_mock.jpg`)
  - Bloco **Comunicação**
    3. `comunicou_diretoria_se_falha` — sim/nao; aparece quando ANY (`verificou_funcionamento_bomba==nao` OR `painel_indica_normalidade==nao`); **alerta quando** `nao`

#### 6.2.8) (Geral) Checklist: Montagem de Nova Pastagem (`checklist_montagem_nova_pastagem_pecuaria`)

- `appliesPerPen`: false
- Perguntas:
  - Bloco **Medição da área**
    1. `usou_app_medicao_area_diretoria` — sim/nao; **alerta quando** `nao`
    2. `medicao_dentro_padrao` — sim/nao; campo adicional `area_medida` quando `sim`; **alerta quando** `nao`
  - Bloco **Fechamento da área**
    3. `fechou_corretamente_ultradenso` — sim/nao; **alerta quando** `nao`; foto quando `sim` (mock `foto_ultradenso_fechado_pastagem_mock.jpg`)
  - Bloco **Registro final**
    4. `registrou_horario_planilha` — sim/nao; **alerta quando** `nao`

#### 6.2.9) (Geral) Checklist: Análise de Gado (`checklist_analise_gado_pecuaria`)

- `appliesPerPen`: false
- Perguntas:
  - Bloco **Análise programada**
    1. `realizou_analise_conforme_cronograma_rotativo` — sim/nao; **alerta quando** `nao`
  - Bloco **Estado do gado**
    2. `informou_estado_geral_gado` — sim/nao; campo adicional `estado_geral_gado` quando `sim`; **alerta quando** `nao`
  - Bloco **Ocorrência**
    3. `registrou_ocorrencia` — sim/nao; campo adicional `descricao_ocorrencia` quando `sim`; **alerta quando** `sim`

#### 6.2.10) (Geral) Checklist: Gado Cria - Rotina Diária (`checklist_gado_cria_rotina_diaria_pecuaria`)

- `appliesPerPen`: false
- Perguntas:
  - Bloco **Segurança inicial**
    1. `checklist_seguranca_cavalo_e_equipamentos` — sim/nao; **alerta quando** `nao`
  - Bloco **Observação do gado**
    2. `observou_estado_geral_gado` — sim/nao; campo adicional `estado_geral_gado` quando `sim`; **alerta quando** `nao`
    3. `verificou_bezerros_mamando` — sim/nao; **alerta quando** `nao`
  - Bloco **Pasto**
    4. `conferiu_dias_pasto_registrado` — sim/nao; campo adicional `dias_no_pasto` quando `sim`
  - Bloco **Água e sal**
    5. `agua_potavel_bebedouro` — sim/nao; **alerta quando** `nao`; foto quando `sim` (mock `foto_agua_potavel_bebedouro_gado_cria_mock.jpg`)
    6. `verificou_sal_disponivel` — sim/nao; **alerta quando** `nao`; foto quando `sim` (mock `foto_sal_disponivel_gado_cria_mock.jpg`)
  - Bloco **Cercas**
    7. `conferiu_cercas` — sim/nao; **alerta quando** `nao`
  - Bloco **Registros**
    8. `registrou_nascimentos` — sim/nao; campo adicional `numero_nascimentos` quando `sim`
    9. `realizou_contagem_gado` — sim/nao; campo adicional `numero_gado_contado` quando `sim`; **alerta quando** `nao`
  - Bloco **Ocorrências**
    10. `registrou_qualquer_ocorrencia` — sim/nao; campo adicional `descricao_ocorrencia` quando `sim`; **alerta quando** `sim`

---

## 7) Observações sobre funcionalidades “simuladas” (mocks)

Estas interações existem na UI, mas são simulações:

- **Gravação de áudio** em campos adicionais e observação:
  - não grava microfone real; cria `AudioMock` com `localFile`, `durationSeconds` e `transcriptionMock`.
- **Fotos**:
  - `PhotoCaptureSheet` sempre retorna `PhotoMock(captured: true, localFile: ...)`.
- **Playback de observação**:
  - “Ouvir áudio” só mostra `SnackBar` com texto “Simulação: áudio reproduzido (mock).”.

---

## 8) Arquivos relevantes para UI/tema

- `lib/theme.dart`: tema, cores, espaçamentos (`AppSpacing`), raios (`AppRadius`) e cores utilitárias (`AppColors`).
- `lib/components/responsive_body.dart`: padroniza largura máxima e padding responsivo.
- `assets/images/background.png` e `assets/images/logo.png`: usados na Home.
