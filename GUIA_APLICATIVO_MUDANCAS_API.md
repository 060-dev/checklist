# Aplicativo: o que mudou na API

Atualização publicada em produção em 07/09/2026.

## Resumo para quem vai implementar

**O acesso não mudou.** O aplicativo continua usando a chave compartilhada e a
seleção de perfil na lista de colaboradores. Nada precisa ser refeito no login.

As mudanças são todas aditivas: campos e filtros novos que o aplicativo pode
adotar no seu ritmo. Um cliente que ignorar tudo o que está abaixo continua
funcionando como antes.

| Mudança | Precisa de ação no app? |
| --- | --- |
| `completion_status` nas execuções | Opcional, recomendado |
| `date_from`/`date_to` nas ocorrências | Opcional |
| Prioridades exibidas como Padrão/Crítico/Urgente | Sim, se a interface mostra rótulos |
| Vários currais em uma execução | Sim, se o layout assume um curral |
| Agrupamento de checklists repetidos | Opcional, melhora a navegação |
| Respostas numéricas e perguntas condicionais | Sim, se ainda não implementadas |

## Endereço e autenticação

Base de produção: `https://morropeao.yplanejamento.com.br`.
O endereço técnico `https://morro-do-peao-gis-gvygf4qquq-uc.a.run.app` também
aponta para o serviço. As rotas do aplicativo seguem sob `/api/mobile/v1`.

Cabeçalho em todas as chamadas, inclusive download de áudio e anexos:

```http
X-API-Key: <CHAVE_COMPARTILHADA>
```

Também é aceito `Authorization: Bearer <CHAVE>`. Não use a chave na URL. O
envelope permanece `success`, `data`, `message`, `errors`, com a lista em
`data.items` e paginação.

`GET /api/mobile/v1/employees` continua devolvendo todos os colaboradores
ativos, e as rotas por pessoa continuam aceitando qualquer `employee_id`
retornado nessa lista.

Registros, IDs, atribuições, tarefas, respostas e anexos existentes foram
preservados na atualização. Não é preciso recadastrar pessoas nem recriar
checklists.

### Erros a tratar

| HTTP | Significado e ação |
| --- | --- |
| 401 | Chave ausente, inválida, expirada ou revogada. Não repetir a fila; pedir configuração de acesso válido. |
| 404 | Registro não encontrado ou não pertencente à pessoa da rota. |
| 422 | Dados inválidos, período invertido, pergunta obrigatória ausente ou resposta incompatível com as condições. Exibir o erro e permitir corrigir. |

## Conclusão no prazo e com atraso

`status` continua com os valores anteriores, inclusive `completed`. As execuções
passam a trazer um campo adicional, `completion_status`:

| Valor | Exibição sugerida |
| --- | --- |
| `open` | Aberto, dentro do prazo |
| `overdue` | Atrasado, ainda não concluído |
| `completed_on_time` | Concluído no prazo |
| `completed_late` | Concluído com atraso |

O limite é `due_at`; concluir exatamente nesse instante conta como no prazo. O
atraso não apaga nem invalida respostas, e uma tarefa já iniciada também pode
ficar atrasada. Prefira `completion_status` para exibir o resultado e mantenha
`status` para os fluxos de execução. Interprete as datas da API com o fuso
correto, nunca comparando textos locais.

## Ocorrências: filtro de datas

A listagem aceita o período junto com os filtros existentes e a paginação:

```http
GET /api/mobile/v1/employees/123/occurrences?date_from=2026-09-01&date_to=2026-09-07
```

O período considera a **criação** da ocorrência e inclui os dois dias, no fuso
`America/Sao_Paulo` da produção. Período invertido devolve 422.

## Prioridades das ocorrências

Os valores aceitos são `normal`, `high` e `urgent`, exibidos como **Padrão**,
**Crítico** e **Urgente**. Registros antigos gravados como `low` foram
normalizados para `normal` na atualização.

Atenção ao gerar cliente a partir do `openapi.json`: o enum `OccurrencePriority`
ainda declara `low` por compatibilidade do modelo, mas o servidor responde
**422** ao recebê-lo. Trate apenas os três valores acima como válidos e não
ofereça `low` na interface. Também não envie `standard` nem `critical`: esses
nomes pertencem ao módulo de compras, não às ocorrências.

## Vários currais em uma execução

Uma atribuição pode agora abranger vários currais, com uma única execução e uma
resposta para o conjunto. O contrato não mudou: o campo continua sendo
`location`, uma string.

O que muda é o conteúdo. Quando há mais de um curral, os nomes vêm ordenados e
separados por `"; "`:

```json
{"location": "Curral 01; Curral 02"}
```

Exiba o texto completo. Se o layout hoje assume um curral só, verifique
truncamento e quebra de linha: o campo combinado pode ter até 160 caracteres. Os
nomes individuais nunca contêm `;`, então dividir por `"; "` é seguro caso queira
mostrá-los como lista.

Quando cada curral exigir respostas separadas, o administrador mantém
atribuições separadas — o aplicativo não precisa decidir isso.

## Agrupamento de checklists repetidos

Sugestão de navegação, sem mudança de contrato: agrupe os itens recebidos por
`checklist_id`, abrindo as atribuições e execuções de cada curral dentro do
grupo, em vez de vários cartões soltos. Por exemplo, um grupo “Leitura de Coxo”
que abre os currais internamente.

Não junte respostas de execuções diferentes nem substitua seus IDs: cada
execução continua sendo enviada individualmente.

## Respostas numéricas e perguntas condicionais

O tipo `answerType=number` e as condições `displayWhen`/`displayWhenAny` fazem
parte do contrato e devem ser respeitados. Números aceitam zero, negativos e
decimais; envie número JSON finito:

```json
{"answers": {"quantidade": {"answer": 0.5}}}
```

Exemplo de bifurcação:

```json
[
  {"id":"escolha","text":"Escolha","audioText":"Escolha","answerType":"singleChoice","options":["A","B"],"required":true},
  {"id":"quantidade","text":"Quantidade","audioText":"Quantidade","answerType":"number","required":true,"displayWhen":{"questionId":"escolha","answer":"A"}},
  {"id":"observacao","text":"Observação","audioText":"Observação","answerType":"text","required":true,"displayWhen":{"questionId":"escolha","answer":"B"}}
]
```

Ao responder A, mostrar e exigir `quantidade`; ao responder B, `observacao`.

Regras a respeitar:

- Reavaliar as condições sempre que uma resposta mudar, inclusive em cadeia.
- Remover do envio as respostas e evidências de perguntas que ficaram ocultas.
- Não exigir pergunta obrigatória enquanto estiver oculta.
- `displayWhenAny` combina suas condições com OU; havendo também `displayWhen`,
  as duas precisam ser atendidas.
- Dependências só apontam para perguntas anteriores.

Evidências condicionais existentes continuam válidas.

## Roteiro de homologação

- Concluir uma execução com número zero, negativo e decimal e conferir as
  respostas no painel administrativo.
- Testar as duas ramificações de uma pergunta condicional, mudando a resposta
  inicial antes de enviar, e confirmar que a pergunta oculta não é exigida.
- Comparar uma conclusão no prazo e outra atrasada, conferindo
  `completion_status` nos quatro estados.
- Filtrar ocorrências por período, incluindo a virada do dia em São Paulo e um
  período invertido (deve dar 422).
- Abrir uma atribuição com dois currais e conferir a exibição de `location`.
- Conferir o agrupamento sem misturar IDs de execução.
- Confirmar que históricos e IDs antigos continuam disponíveis.

## Sobre o acesso por pessoa

O acesso individual por colaborador foi retirado desta entrega, a pedido, por
falta de prazo para a implementação no aplicativo. A chave compartilhada segue
válida e a seleção de perfil continua funcionando como sempre.

Isso significa que o servidor **não distingue** quem está usando o aplicativo:
qualquer pessoa com a chave pode escolher qualquer perfil e ver os dados dele.
Enquanto for assim, trate a chave compartilhada como um segredo de operação —
não a publique em repositório, loja de aplicativos ou canal aberto — e prefira
instalar o aplicativo apenas em aparelhos controlados pela fazenda.

O suporte está preparado no banco para quando houver prazo: basta emitir uma
credencial por pessoa e passar a exigi-la. Nada no aplicativo precisa mudar
antes dessa decisão.
