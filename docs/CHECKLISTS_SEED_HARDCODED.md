# Seed (hardcoded) — Checklists da POC

Este arquivo documenta **exatamente** os checklists que existem hoje hardcoded no app, conforme `lib/data/checklists_repository.dart` (lista `ChecklistsRepository.available`).

Objetivo: permitir que o backend crie um **seed** com as mesmas definições (IDs, textos, regras condicionais, campos adicionais, níveis e solicitações de foto).

> Observação importante sobre ícones: no app eles são `IconData` (ex.: `Icons.agriculture`). Aqui foram serializados como `iconDart` (string) contendo o identificador Dart, pois isso é o que existe hardcoded hoje.

---

## JSON (fonte de verdade para seed)

```json
{
  "source": {
    "file": "lib/data/checklists_repository.dart",
    "list": "ChecklistsRepository.available"
  },
  "enums": {
    "OperationalResponsible": ["tratador", "vaqueiro", "outro"],
    "ChecklistAnswerType": ["simNao", "simNaoOk", "simNaoComNivel"],
    "AdditionalFieldInputType": ["textOrAudio"]
  },
  "areas": [
    {
      "id": "area_agricultura",
      "title": "Agricultura"
    },
    {
      "id": "area_pecuaria",
      "title": "Pecuária"
    }
  ],
  "checklists": [
    {
      "id": "checklist_preparacao_solo",
      "title": "Preparação do Solo",
      "description": "Conferência antes, durante e depois da aplicação",
      "iconDart": "Icons.agriculture",
      "areaId": "area_agricultura",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "conferiu_checklist_precisa",
          "text": "Conferiu o checklist diário da Precisa?",
          "audioText": "Conferiu o checklist diário da Precisa?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "conferiu_checklist_trator",
          "text": "Conferiu o checklist diário do trator?",
          "audioText": "Conferiu o checklist diário do trator?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "conferiu_checklist_carregadeira",
          "text": "Conferiu o checklist diário da carregadeira?",
          "audioText": "Conferiu o checklist diário da carregadeira?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "maquina_apresenta_defeito",
          "text": "A máquina apresenta defeito?",
          "audioText": "A máquina apresenta defeito? Se sim, não sair do barracão.",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "sim",
          "alertMessage": "Não sair do barracão. Avisar o responsável."
        },
        {
          "id": "recebeu_produtos",
          "text": "Recebeu os produtos para aplicação?",
          "audioText": "Recebeu os produtos para aplicação, como calcário, gesso, pó de rocha, fosfato ou cama de frango?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "recebeu_mapeamento_area",
          "text": "Recebeu o mapeamento da área?",
          "audioText": "Recebeu o mapeamento da área, com a zona de manejo?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "carregou_precisa_corretamente",
          "text": "Carregou a Precisa corretamente?",
          "audioText": "Carregou a Precisa corretamente?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "aplicou_conforme_mapa",
          "text": "Aplicou nas áreas conforme o mapa?",
          "audioText": "Aplicou nas áreas conforme o mapa da diretoria?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "finalizou_talhao_planejamento",
          "text": "Finalizou o talhão conforme o planejamento?",
          "audioText": "Finalizou o talhão conforme o planejamento?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        }
      ]
    },
    {
      "id": "checklist_manutencao_preventiva",
      "title": "Manutenção Preventiva",
      "description": "Óleo, pneus, inspeção e aptidão da máquina",
      "iconDart": "Icons.handyman_rounded",
      "areaId": "area_agricultura",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "realizou_troca_oleo",
          "text": "Realizou troca de óleo?",
          "audioText": "Realizou troca de óleo?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "verificou_estado_pneus",
          "text": "Verificou o estado dos pneus?",
          "audioText": "Verificou o estado dos pneus?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "realizou_inspecao_geral_maquina",
          "text": "Realizou inspeção geral da máquina?",
          "audioText": "Realizou inspeção geral da máquina?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "equipamento_apto_para_plantio",
          "text": "Equipamento apto para plantio?",
          "audioText": "O equipamento está apto para o plantio?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: equipamento não apto para plantio. Avisar o responsável antes de continuar."
        }
      ]
    },
    {
      "id": "checklist_dessecacao_talhoes",
      "title": "Dessecação dos Talhões",
      "description": "Receita, EPI, herbicidas, clima, aplicação e limpeza",
      "iconDart": "Icons.cleaning_services_rounded",
      "areaId": "area_agricultura",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "receita_preparada_conforme_planejamento",
          "text": "Receita preparada conforme planejamento agronômico?",
          "audioText": "A receita foi preparada conforme o planejamento agronômico?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "vestiu_epi_completo",
          "text": "Vestiu EPI completo?",
          "audioText": "Vestiu o EPI completo?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o operador deve vestir o EPI completo antes de continuar."
        },
        {
          "id": "colocou_meio_tanque_agua",
          "text": "Colocou meio tanque de água?",
          "audioText": "Colocou meio tanque de água?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "separou_herbicidas_corretos",
          "text": "Separou os herbicidas corretos?",
          "audioText": "Separou os herbicidas corretos?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "mediu_volume_correto_produtos",
          "text": "Mediu o volume correto dos produtos?",
          "audioText": "Mediu o volume correto de cada produto?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "volume_de_cada_produto",
            "label": "Qual o volume de cada produto?",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Informe ou grave o volume de cada produto"
          }
        },
        {
          "id": "completou_tanque_com_agua",
          "text": "Completou o tanque com água?",
          "audioText": "Completou o tanque com água?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "condicao_vento_adequada",
          "text": "Condição de vento entre 3 e 12 km/h?",
          "audioText": "A condição de vento está entre três e doze quilômetros por hora?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a condição pode estar inadequada para aplicação. Avisar o responsável."
        },
        {
          "id": "umidade_acima_55",
          "text": "Umidade acima de 55%?",
          "audioText": "A umidade está acima de cinquenta e cinco por cento?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a condição pode estar inadequada para aplicação. Avisar o responsável."
        },
        {
          "id": "temperatura_abaixo_30",
          "text": "Temperatura abaixo de 30 graus?",
          "audioText": "A temperatura está abaixo de trinta graus?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a condição pode estar inadequada para aplicação. Avisar o responsável."
        },
        {
          "id": "sem_chuva_no_momento",
          "text": "Está sem chuva no momento?",
          "audioText": "Está sem chuva no momento?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a condição pode estar inadequada para aplicação. Avisar o responsável."
        },
        {
          "id": "aplicacao_conforme_talhao_definido",
          "text": "Aplicação realizada conforme talhão definido?",
          "audioText": "A aplicação foi realizada conforme o talhão definido?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "equipamento_limpo_apos_aplicacao",
          "text": "Equipamento limpo após aplicação?",
          "audioText": "O equipamento foi limpo após a aplicação?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto do equipamento limpo",
            "instruction": "Tire uma foto do equipamento limpo após a aplicação.",
            "mockLocalFile": "foto_equipamento_limpo_mock.jpg"
          }
        },
        {
          "id": "epi_armazenado_corretamente",
          "text": "EPI armazenado corretamente?",
          "audioText": "O EPI foi armazenado corretamente?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        }
      ]
    },
    {
      "id": "checklist_plantio",
      "title": "Plantio",
      "description": "Sementes, tratamento, regulagem, abastecimento e GPS",
      "iconDart": "Icons.agriculture_rounded",
      "areaId": "area_agricultura",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "recebeu_sementes",
          "text": "Recebeu sementes?",
          "audioText": "Recebeu as sementes?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto das sementes recebidas",
            "instruction": "Tire uma foto das sementes recebidas.",
            "mockLocalFile": "foto_sementes_recebidas_mock.jpg"
          }
        },
        {
          "id": "armazenou_protegido_sol_chuva",
          "text": "Armazenou protegido de sol e chuva?",
          "audioText": "Armazenou as sementes protegidas do sol e da chuva?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: as sementes devem ficar protegidas do sol e da chuva. Avisar o responsável."
        },
        {
          "id": "preparou_calda_tratamento",
          "text": "Preparou calda para tratamento?",
          "audioText": "Preparou a calda para o tratamento?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "regulou_tratadora_corretamente",
          "text": "Regulou a tratadora corretamente?",
          "audioText": "Regulou a tratadora corretamente?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto da tratadora regulada",
            "instruction": "Tire uma foto da tratadora regulada corretamente.",
            "mockLocalFile": "foto_tratadora_regulada_mock.jpg"
          }
        },
        {
          "id": "tratamento_realizado_padrao_100kg_min",
          "text": "Tratamento realizado no padrão de 100 kg por minuto?",
          "audioText": "O tratamento foi realizado no padrão de cem quilos por minuto?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o tratamento não está no padrão esperado de 100 quilos por minuto. Avisar o responsável."
        },
        {
          "id": "transporte_bag_tratado_correto",
          "text": "Transporte do bag tratado correto?",
          "audioText": "O transporte do bag tratado está correto?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "plantadeira_abastecida_corretamente",
          "text": "Plantadeira abastecida corretamente?",
          "audioText": "A plantadeira foi abastecida corretamente?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "regulagem_realizada",
          "text": "Regulagem realizada?",
          "audioText": "A regulagem foi realizada?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "nova_regulagem_ao_trocar_variedade",
          "text": "Nova regulagem ao trocar variedade?",
          "audioText": "Foi feita nova regulagem ao trocar a variedade?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "projeto_linha_carregado_gps",
          "text": "Projeto de linha carregado no GPS?",
          "audioText": "O projeto de linha foi carregado no GPS?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o projeto de linha deve estar carregado no GPS antes de iniciar. Avisar o responsável."
        }
      ]
    },
    {
      "id": "checklist_tratamento_sulco",
      "title": "Tratamento de Sulco",
      "description": "Calda, produtos no IBC, transferência para Micron e regulagem do sistema",
      "iconDart": "Icons.water_drop_rounded",
      "areaId": "area_agricultura",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "etapa_1_preparou_calda_biologicos_nutricao",
          "stage": "Etapa 1",
          "text": "Preparou a calda de biológicos e nutrição?",
          "audioText": "Preparou a calda de biológicos e nutrição?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_1_mediu_produtos_ibc_1000l",
          "stage": "Etapa 1",
          "text": "Mediu corretamente os produtos no IBC de 1000 litros?",
          "audioText": "Mediu corretamente os produtos no IBC de mil litros?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_1_transferiu_para_micron_com_bomba",
          "stage": "Etapa 1",
          "text": "Transferiu para o Micron com bomba?",
          "audioText": "Transferiu para o Micron com bomba?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_1_regulou_sistema_acoplado",
          "stage": "Etapa 1",
          "text": "Regulou o sistema acoplado?",
          "audioText": "Regulou o sistema acoplado?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o sistema acoplado precisa estar regulado antes de continuar. Avisar o responsável."
        },
        {
          "id": "etapa_2_preparou_calda_biologicos_nutricao",
          "stage": "Etapa 2",
          "text": "Preparou novamente a calda de biológicos e nutrição?",
          "audioText": "Preparou novamente a calda de biológicos e nutrição?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_2_mediu_produtos_ibc_1000l",
          "stage": "Etapa 2",
          "text": "Mediu novamente os produtos no IBC de 1000 litros?",
          "audioText": "Mediu novamente os produtos no IBC de mil litros?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_2_transferiu_para_micron_com_bomba",
          "stage": "Etapa 2",
          "text": "Transferiu novamente para o Micron com bomba?",
          "audioText": "Transferiu novamente para o Micron com bomba?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_2_regulou_sistema_acoplado",
          "stage": "Etapa 2",
          "text": "Regulou novamente o sistema acoplado?",
          "audioText": "Regulou novamente o sistema acoplado?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o sistema acoplado precisa estar regulado antes de continuar. Avisar o responsável."
        }
      ]
    },
    {
      "id": "checklist_operacao_diaria_plantio",
      "title": "Operação Diária de Plantio",
      "description": "Abastecimento diário, operação com GPS e finalização do talhão",
      "iconDart": "Icons.event_available_rounded",
      "areaId": "area_agricultura",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "etapa_1_abastecimento_diario",
          "stage": "Etapa 1",
          "text": "Fez o abastecimento diário?",
          "audioText": "Fez o abastecimento diário com diesel, biológico e sementes?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_1_plantadeira_operando_conforme_gps",
          "stage": "Etapa 1",
          "text": "Plantadeira operando conforme GPS?",
          "audioText": "A plantadeira está operando conforme o GPS?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a plantadeira deve operar conforme o GPS. Avisar o responsável."
        },
        {
          "id": "etapa_1_finalizou_talhao_conforme_planejamento",
          "stage": "Etapa 1",
          "text": "Finalizou o talhão conforme planejamento?",
          "audioText": "Finalizou o talhão conforme o planejamento?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_2_abastecimento_diario",
          "stage": "Etapa 2",
          "text": "Fez novamente o abastecimento diário?",
          "audioText": "Fez novamente o abastecimento diário com diesel, biológico e sementes?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_2_plantadeira_operando_conforme_gps",
          "stage": "Etapa 2",
          "text": "Plantadeira continua operando conforme GPS?",
          "audioText": "A plantadeira continua operando conforme o GPS?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a plantadeira deve continuar operando conforme o GPS. Avisar o responsável."
        },
        {
          "id": "etapa_2_finalizou_talhao_conforme_planejamento",
          "stage": "Etapa 2",
          "text": "Finalizou o talhão conforme planejamento?",
          "audioText": "Finalizou o talhão conforme o planejamento?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_3_abastecimento_diario",
          "stage": "Etapa 3",
          "text": "Fez novamente o abastecimento diário?",
          "audioText": "Fez novamente o abastecimento diário com diesel, biológico e sementes?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "etapa_3_plantadeira_operando_conforme_gps",
          "stage": "Etapa 3",
          "text": "Plantadeira continua operando conforme GPS?",
          "audioText": "A plantadeira continua operando conforme o GPS?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a plantadeira deve continuar operando conforme o GPS. Avisar o responsável."
        },
        {
          "id": "etapa_3_finalizou_talhao_conforme_planejamento",
          "stage": "Etapa 3",
          "text": "Finalizou o talhão conforme planejamento?",
          "audioText": "Finalizou o talhão conforme o planejamento?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        }
      ]
    },
    {
      "id": "checklist_tratos_culturais_semanais",
      "title": "Tratos Culturais Semanais",
      "description": "Receita, EPI, ambiente, aplicação, limpeza e estratégia antes da colheita",
      "iconDart": "Icons.eco_rounded",
      "areaId": "area_agricultura",
      "appliesPerPen": false,
      "periodicity": "semanal",
      "questions": [
        {
          "id": "receita_preparada_conforme_agronomo",
          "text": "Receita preparada conforme o agrônomo?",
          "audioText": "A receita foi preparada conforme orientação do agrônomo?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "epi_utilizado",
          "text": "EPI utilizado?",
          "audioText": "O EPI foi utilizado corretamente?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o EPI deve ser utilizado corretamente antes de continuar. Avisar o responsável."
        },
        {
          "id": "condicoes_ambientais_adequadas",
          "text": "Condições ambientais adequadas?",
          "audioText": "As condições ambientais estão adequadas para a aplicação?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: as condições ambientais podem estar inadequadas para a aplicação. Avisar o responsável."
        },
        {
          "id": "aplicacao_realizada_corretamente",
          "text": "Aplicação realizada corretamente?",
          "audioText": "A aplicação foi realizada corretamente?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "equipamento_limpo_apos_uso",
          "text": "Equipamento limpo após uso?",
          "audioText": "O equipamento foi limpo após o uso?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto do equipamento limpo",
            "instruction": "Tire uma foto do equipamento limpo após o uso.",
            "mockLocalFile": "foto_equipamento_limpo_apos_uso_mock.jpg"
          }
        },
        {
          "id": "aplicacao_dentro_estrategia_25_dias_colheita",
          "text": "Aplicação dentro da estratégia?",
          "audioText": "A aplicação está dentro da estratégia, até vinte e cinco dias antes da colheita?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: verificar se a aplicação está dentro da estratégia, até 25 dias antes da colheita. Avisar o responsável."
        }
      ]
    },
    {
      "id": "checklist_colheita",
      "title": "Colheita",
      "description": "Estágio da cultura, umidade, regulagem, perdas, limpeza e manutenção",
      "iconDart": "Icons.grain_rounded",
      "areaId": "area_agricultura",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "cultura_estagio_fisiologico_correto",
          "text": "Cultura no estágio fisiológico correto?",
          "audioText": "A cultura está no estágio fisiológico correto para a colheita?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: verificar com o responsável se a cultura está no estágio correto para colheita."
        },
        {
          "id": "umidade_adequada_para_armazenagem",
          "text": "Umidade adequada para armazenagem?",
          "audioText": "A umidade está adequada para armazenagem?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a umidade pode não estar adequada para armazenagem. Avisar o responsável."
        },
        {
          "id": "pre_regulagem_realizada",
          "text": "Pré-regulagem realizada?",
          "audioText": "A pré-regulagem foi realizada?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "regulagem_fina_realizada_campo",
          "text": "Regulagem fina realizada no campo?",
          "audioText": "A regulagem fina foi realizada no campo?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "avaliou_perdas_chao_copo_medidor_embrapa",
          "text": "Avaliou perdas no chão?",
          "audioText": "Avaliou as perdas no chão usando o copo medidor da Embrapa?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "observacao_perdas_chao",
            "label": "Quer informar o resultado da avaliação?",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: perdas dentro do aceitável, perdas altas ou necessidade de ajuste"
          }
        },
        {
          "id": "calibracao_ajustada_apos_contagem",
          "text": "Calibração ajustada após contagem?",
          "audioText": "A calibração foi ajustada após a contagem?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "equipe_abastecimento_disponivel",
          "text": "Equipe de abastecimento disponível?",
          "audioText": "A equipe de abastecimento está disponível?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "processo_realizado_todos_talhoes",
          "text": "Processo realizado em todos os talhões?",
          "audioText": "O processo foi realizado em todos os talhões?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "limpeza_pos_colheita_realizada",
          "text": "Limpeza pós-colheita realizada?",
          "audioText": "A limpeza pós-colheita foi realizada?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto da limpeza pós-colheita",
            "instruction": "Tire uma foto mostrando a limpeza pós-colheita realizada.",
            "mockLocalFile": "foto_limpeza_pos_colheita_mock.jpg"
          }
        },
        {
          "id": "encaminhado_manutencao_corretiva",
          "text": "Encaminhado para manutenção corretiva?",
          "audioText": "O equipamento foi encaminhado para manutenção corretiva?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        }
      ]
    },
    {
      "id": "checklist_confinamento_leitura_3b",
      "title": "Confinamento - Leitura 3B",
      "description": "Checklist 3B por curral (boia, bosta e boi)",
      "iconDart": "Icons.pets_rounded",
      "areaId": "area_pecuaria",
      "appliesPerPen": true,
      "responsible": "tratador",
      "questions": [
        {
          "id": "boia_registrar_nota_leitura_cocho",
          "block": "BOIA / Cocho",
          "text": "Registrar nota para leitura de cocho antes do novo abastecimento?",
          "audioText": "Registrar nota para leitura de cocho antes do novo abastecimento?",
          "answerType": "simNaoComNivel",
          "options": ["sim", "nao"],
          "required": true,
          "level": {
            "label": "Nota da leitura de cocho",
            "required": true,
            "requiredWhenAnswer": "sim",
            "options": [
              {"label": "0 - Lambeu", "value": 0},
              {"label": "1 - Ideal", "value": 1},
              {"label": "2 - Sobra", "value": 2}
            ]
          },
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto do cocho",
            "instruction": "Tire uma foto do cocho antes do novo abastecimento."
          }
        },
        {
          "id": "boia_registrar_classificacao_quadro_fisico",
          "block": "BOIA / Cocho",
          "text": "Registrar classificação no quadro físico?",
          "audioText": "Registrar classificação no quadro físico?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "boia_informar_ricardo_resultado_leitura",
          "block": "BOIA / Cocho",
          "text": "Informar Ricardo para colocar resultado da leitura no sistema?",
          "audioText": "Informar Ricardo para colocar o resultado da leitura no sistema?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "bosta_registrar_avaliacao_fezes",
          "block": "BOSTA / Fezes",
          "text": "Registrar avaliação das fezes?",
          "audioText": "Registrar avaliação das fezes?",
          "answerType": "simNaoComNivel",
          "options": ["sim", "nao"],
          "required": true,
          "level": {
            "label": "Classificação das fezes",
            "required": true,
            "requiredWhenAnswer": "sim",
            "options": [
              {"label": "Boa", "value": "boa"},
              {"label": "Média", "value": "media"},
              {"label": "Ruim", "value": "ruim"}
            ]
          },
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto das fezes",
            "instruction": "Tire uma foto que ajude a registrar a avaliação das fezes."
          }
        },
        {
          "id": "bosta_identificou_sinais_diarreia",
          "block": "BOSTA / Fezes",
          "text": "Identificou sinais de diarreia?",
          "audioText": "Identificou sinais de diarreia?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "sim",
          "alertMessage": "Atenção: sinais de diarreia identificados. Seguir as etapas de monitoramento e avisar o responsável.",
          "interstitial": {
            "id": "bosta_followup_intro",
            "whenAnswer": "sim",
            "message": "Foi identificada uma situação que precisa de acompanhamento.\n\nVamos registrar as próximas etapas.",
            "buttonLabel": "Continuar"
          }
        },
        {
          "id": "bosta_observou_animal_debilitado",
          "block": "BOSTA / Fezes",
          "text": "Observou animal debilitado?",
          "audioText": "Observou animal debilitado, com bunda suja ou magreza?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "sim",
          "alertMessage": "Atenção: animal debilitado identificado. Seguir as etapas de monitoramento.",
          "interstitial": {
            "id": "bosta_followup_intro",
            "whenAnswer": "sim",
            "message": "Foi identificada uma situação que precisa de acompanhamento.\n\nVamos registrar as próximas etapas.",
            "buttonLabel": "Continuar"
          }
        },
        {
          "id": "bosta_monitorou_animal_1_dia",
          "block": "BOSTA / Fezes",
          "text": "Monitorou o animal por 1 dia?",
          "audioText": "Monitorou o animal por um dia?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhenAny": [
            {"questionId": "bosta_identificou_sinais_diarreia", "answer": "sim"},
            {"questionId": "bosta_observou_animal_debilitado", "answer": "sim"}
          ]
        },
        {
          "id": "bosta_animal_persiste_debilitado",
          "block": "BOSTA / Fezes",
          "text": "Animal persiste debilitado?",
          "audioText": "O animal continua debilitado? Se sim, avisar a diretoria.",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhenAny": [
            {"questionId": "bosta_identificou_sinais_diarreia", "answer": "sim"},
            {"questionId": "bosta_observou_animal_debilitado", "answer": "sim"}
          ],
          "alertWhenAnswer": "sim",
          "alertMessage": "Atenção: animal persiste debilitado. Avisar a diretoria."
        },
        {
          "id": "bosta_removeu_animal_curral",
          "block": "BOSTA / Fezes",
          "text": "Removeu o animal do curral?",
          "audioText": "Removeu o animal do curral?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhenAny": [
            {"questionId": "bosta_identificou_sinais_diarreia", "answer": "sim"},
            {"questionId": "bosta_observou_animal_debilitado", "answer": "sim"}
          ]
        },
        {
          "id": "bosta_realizou_medicacao",
          "block": "BOSTA / Fezes",
          "text": "Realizou medicação do animal conforme instruções da diretoria?",
          "audioText": "Realizou a medicação do animal de acordo com as instruções da diretoria?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhenAny": [
            {"questionId": "bosta_identificou_sinais_diarreia", "answer": "sim"},
            {"questionId": "bosta_observou_animal_debilitado", "answer": "sim"}
          ]
        },
        {
          "id": "bosta_registrou_ocorrencia_obrigatoria",
          "block": "BOSTA / Fezes",
          "text": "Registrou ocorrência no checklist?",
          "audioText": "Registrou a ocorrência no checklist? Esse registro é obrigatório.",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhenAny": [
            {"questionId": "bosta_identificou_sinais_diarreia", "answer": "sim"},
            {"questionId": "bosta_observou_animal_debilitado", "answer": "sim"}
          ],
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o registro da ocorrência é obrigatório."
        },
        {
          "id": "boi_realizou_leitura_visual_rumen",
          "block": "BOI",
          "text": "Realizou leitura visual do rúmen?",
          "audioText": "Realizou leitura visual do rúmen, observando o triângulo esquerdo?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto do animal",
            "instruction": "Tire uma foto que ajude a registrar a leitura visual do rúmen."
          }
        },
        {
          "id": "boi_registrar_resultado_leitura",
          "block": "BOI",
          "text": "Registrar resultado da leitura?",
          "audioText": "Registrar o resultado da leitura do boi?",
          "answerType": "simNaoComNivel",
          "options": ["sim", "nao"],
          "required": true,
          "level": {
            "label": "Resultado da leitura",
            "required": true,
            "requiredWhenAnswer": "sim",
            "options": [
              {"label": "Baixo", "value": "baixo"},
              {"label": "Médio", "value": "medio"},
              {"label": "Ideal", "value": "ideal"}
            ]
          }
        }
      ]
    },
    {
      "id": "checklist_manutencao_preventiva_curral",
      "title": "Manutenção Preventiva do Curral",
      "description": "Estrutura do curral, necessidade de reparo e comunicação à diretoria",
      "iconDart": "Icons.construction_rounded",
      "areaId": "area_pecuaria",
      "appliesPerPen": true,
      "responsible": "vaqueiro",
      "questions": [
        {
          "id": "conferiu_estrutura_curral",
          "text": "Conferiu a estrutura do curral?",
          "audioText": "Conferiu a estrutura do curral?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "identificou_necessidade_reparo",
          "text": "Identificou necessidade de reparo?",
          "audioText": "Identificou necessidade de reparo no curral?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "sim",
          "alertMessage": "Atenção: foi identificada necessidade de reparo no curral. Comunicar a diretoria se necessário."
        },
        {
          "id": "comunicou_diretoria_se_necessario",
          "text": "Comunicou a diretoria se necessário?",
          "audioText": "Comunicou a diretoria se necessário?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhen": {"questionId": "identificou_necessidade_reparo", "answer": "sim"},
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: se há necessidade de reparo, a diretoria deve ser comunicada."
        }
      ]
    },
    {
      "id": "checklist_lavagem_bebedouro_curral",
      "title": "Lavagem de Bebedouro",
      "description": "Verificação da água, descarte, lavagem e reabastecimento",
      "iconDart": "Icons.water_drop_rounded",
      "areaId": "area_pecuaria",
      "appliesPerPen": true,
      "responsible": "tratador",
      "questions": [
        {
          "id": "foi_ate_bebedouro",
          "text": "Foi até o bebedouro?",
          "audioText": "Você foi até o bebedouro?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: é necessário ir até o bebedouro para realizar a verificação."
        },
        {
          "id": "teria_coragem_provar_agua",
          "text": "Teria coragem de provar a água?",
          "audioText": "Você teria coragem de provar a água do bebedouro?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto da água do bebedouro",
            "instruction": "Tire uma foto mostrando a água do bebedouro."
          },
          "interstitial": {
            "whenAnswer": "nao",
            "message": "Vamos fazer a limpeza do bebedouro.\n\nAgora registre as etapas de descarte, lavagem e reabastecimento.",
            "buttonLabel": "Continuar"
          }
        },
        {
          "id": "descartou_agua_suja",
          "text": "Descartou a água suja?",
          "audioText": "Descartou a água suja do bebedouro?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhen": {"questionId": "teria_coragem_provar_agua", "answer": "nao"}
        },
        {
          "id": "lavou_bebedouro_completamente",
          "text": "Lavou o bebedouro completamente?",
          "audioText": "Lavou o bebedouro completamente?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhen": {"questionId": "teria_coragem_provar_agua", "answer": "nao"},
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto do bebedouro lavado",
            "instruction": "Tire uma foto mostrando o bebedouro limpo após a lavagem."
          }
        },
        {
          "id": "reabasteceu_com_agua_limpa",
          "text": "Reabasteceu com água limpa?",
          "audioText": "Reabasteceu o bebedouro com água limpa?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhen": {"questionId": "teria_coragem_provar_agua", "answer": "nao"},
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o bebedouro precisa ser reabastecido com água limpa antes de finalizar."
        }
      ]
    },
    {
      "id": "checklist_alimentacao_pecuaria",
      "title": "Alimentação",
      "description": "Checklist operacional para preparo, mistura e liberação do trato",
      "iconDart": "Icons.restaurant_rounded",
      "areaId": "area_pecuaria",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "checklist_diario_vagao_realizado",
          "block": "Conferência inicial",
          "text": "Checklist diário do vagão realizado?",
          "audioText": "O checklist diário do vagão foi realizado?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Avisar o responsável antes de continuar."
        },
        {
          "id": "checklist_trator_realizado",
          "block": "Conferência inicial",
          "text": "Checklist do trator realizado?",
          "audioText": "O checklist do trator foi realizado?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Avisar o responsável antes de continuar."
        },
        {
          "id": "checklist_carregadeira_realizado",
          "block": "Conferência inicial",
          "text": "Checklist da carregadeira realizado?",
          "audioText": "O checklist da carregadeira foi realizado?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Avisar o responsável antes de continuar."
        },
        {
          "id": "carregou_milho_soja_nupnio_corretamente",
          "block": "Preparo do trato",
          "text": "Carregou milho, soja e núcleo corretamente?",
          "audioText": "Carregou milho, soja e núcleo corretamente?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "carregou_silo",
          "block": "Preparo do trato",
          "text": "Carregou silo?",
          "audioText": "Carregou o silo?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "esperou_7_minutos_vagao_misturar",
          "block": "Preparo do trato",
          "text": "Esperou 7 minutos para o vagão misturar?",
          "audioText": "Esperou sete minutos para o vagão misturar?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Avisar o responsável antes de continuar."
        },
        {
          "id": "conferiu_quantidade_necessaria_por_curral",
          "block": "Preparo do trato",
          "text": "Conferiu a quantidade necessária por curral?",
          "audioText": "Conferiu a quantidade necessária por curral?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "quantidade_por_curral",
            "label": "Quantidade por curral",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: Curral 1, 300 quilos. Curral 2, 280 quilos."
          }
        },
        {
          "id": "liberou_trato_corretamente",
          "block": "Distribuição",
          "text": "Liberou o trato corretamente?",
          "audioText": "Liberou o trato corretamente, controlando a tampa?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Avisar o responsável antes de continuar."
        },
        {
          "id": "conferiu_leitura_balanca",
          "block": "Distribuição",
          "text": "Conferiu a leitura da balança?",
          "audioText": "Conferiu a leitura da balança, com atenção ao visor?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Avisar o responsável antes de continuar."
        }
      ]
    },
    {
      "id": "checklist_abertura_diaria_pecuaria",
      "title": "Abertura Diária",
      "description": "Limpeza, retirada de cercas, linhas, barras e abertura da pastagem",
      "iconDart": "Icons.wb_sunny_rounded",
      "areaId": "area_pecuaria",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "descartou_agua_noite_anterior",
          "block": "Limpeza inicial",
          "text": "Descartou a água da noite anterior?",
          "audioText": "Descartou a água da noite anterior?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. A água da noite anterior deve ser descartada antes da abertura diária. Avisar o responsável antes de continuar."
        },
        {
          "id": "lavou_bebedouro_retirou_baba_lodo",
          "block": "Limpeza inicial",
          "text": "Lavou o bebedouro?",
          "audioText": "Lavou o bebedouro, retirando baba e lodo?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. O bebedouro deve ser lavado, retirando baba e lodo. Avisar o responsável antes de continuar.",
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto do bebedouro limpo",
            "instruction": "Tire uma foto mostrando o bebedouro limpo após a retirada de baba e lodo.",
            "mockLocalFile": "foto_bebedouro_abertura_diaria_mock.jpg"
          }
        },
        {
          "id": "tirou_linha_choque_ultra_densos",
          "block": "Organização da área",
          "text": "Tirou a linha de choque dos ultra densos?",
          "audioText": "Tirou a linha de choque em todos os ultra densos?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Conferir a retirada da linha de choque dos ultra densos. Avisar o responsável antes de continuar."
        },
        {
          "id": "retirou_cercas_eletricas_dia_anterior",
          "block": "Organização da área",
          "text": "Retirou as cercas elétricas do dia anterior?",
          "audioText": "Retirou as cercas elétricas que foram utilizadas no dia anterior?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Retirar as cercas elétricas utilizadas no dia anterior. Avisar o responsável antes de continuar."
        },
        {
          "id": "comecou_colocar_barras_novamente",
          "block": "Montagem da nova área",
          "text": "Começou a colocar as barras novamente?",
          "audioText": "Começou a colocar as barras novamente?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "colocou_linhas",
          "block": "Montagem da nova área",
          "text": "Colocou as linhas?",
          "audioText": "Colocou as linhas?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true
        },
        {
          "id": "fechou_nova_pastagem",
          "block": "Montagem da nova área",
          "text": "Fechou a nova pastagem?",
          "audioText": "Fechou a nova pastagem?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. A nova pastagem precisa ser fechada antes de finalizar a abertura diária. Avisar o responsável antes de continuar."
        }
      ]
    },
    {
      "id": "checklist_ultra_denso_pecuaria",
      "title": "Ultra Denso",
      "description": "Verificação de voltagem, fuga e correção elétrica",
      "iconDart": "Icons.bolt_rounded",
      "areaId": "area_pecuaria",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "conferiu_voltagem",
          "block": "Verificação elétrica",
          "text": "Conferiu a voltagem?",
          "audioText": "Conferiu a voltagem? O ideal é no mínimo oito mil volts.",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "valor_voltagem_observada",
            "label": "Informe ou grave a voltagem observada",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: 8200 volts"
          },
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. A voltagem precisa ser conferida. O ideal é no mínimo 8000 volts. Avisar o responsável antes de continuar."
        },
        {
          "id": "voltagem_abaixo_8000",
          "block": "Verificação elétrica",
          "text": "Está abaixo de 8000 volts?",
          "audioText": "A voltagem está abaixo de oito mil volts?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "sim",
          "alertMessage": "Atenção: condição não conforme. A voltagem está abaixo do ideal. É necessário verificar a causa. Avisar o responsável antes de continuar.",
          "interstitial": {
            "id": "ultra_denso_correcao_intro",
            "whenAnswer": "sim",
            "message": "Atenção\n\nFoi identificada uma situação que precisa de correção.\n\nVamos registrar a correção e a conferência final.",
            "buttonLabel": "Continuar"
          }
        },
        {
          "id": "identificou_fuga_energia",
          "block": "Diagnóstico",
          "text": "Identificou fuga de energia?",
          "audioText": "Identificou fuga de energia na linha, como fio no chão ou fio encostando na cerca?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhen": {"questionId": "voltagem_abaixo_8000", "answer": "sim"},
          "alertWhenAnswer": "sim",
          "alertMessage": "Atenção: condição não conforme. Foi identificada fuga de energia. O problema precisa ser corrigido. Avisar o responsável antes de continuar."
        },
        {
          "id": "corrigiu_problema",
          "block": "Correção",
          "text": "Corrigiu o problema?",
          "audioText": "Corrigiu o problema identificado?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhenAny": [
            {"questionId": "voltagem_abaixo_8000", "answer": "sim"},
            {"questionId": "identificou_fuga_energia", "answer": "sim"}
          ],
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. O problema precisa ser corrigido antes de finalizar o checklist. Avisar o responsável antes de continuar."
        },
        {
          "id": "conferiu_retorno_voltagem",
          "block": "Validação final",
          "text": "Conferiu o retorno da voltagem?",
          "audioText": "Conferiu o retorno da voltagem depois da correção?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhenAny": [
            {"questionId": "voltagem_abaixo_8000", "answer": "sim"},
            {"questionId": "identificou_fuga_energia", "answer": "sim"},
            {"questionId": "corrigiu_problema", "answer": "sim"}
          ],
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. É necessário conferir se a voltagem voltou ao normal. Avisar o responsável antes de continuar."
        }
      ]
    },
    {
      "id": "checklist_pocos_artesianos_pecuaria",
      "title": "Poços Artesianos",
      "description": "Verificação da bomba, painel e comunicação de falhas",
      "iconDart": "Icons.water_rounded",
      "areaId": "area_pecuaria",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "verificou_funcionamento_bomba",
          "block": "Verificação da bomba",
          "text": "Verificou o funcionamento da bomba?",
          "audioText": "Verificou o funcionamento da bomba?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Avisar o responsável antes de continuar."
        },
        {
          "id": "painel_indica_normalidade",
          "block": "Verificação do painel",
          "text": "Painel indica normalidade?",
          "audioText": "O painel indica normalidade?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Avisar o responsável antes de continuar.",
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto do painel",
            "instruction": "Tire uma foto mostrando o painel indicando normalidade.",
            "mockLocalFile": "foto_painel_poco_artesiano_mock.jpg"
          }
        },
        {
          "id": "comunicou_diretoria_se_falha",
          "block": "Comunicação",
          "text": "Comunicou a diretoria se houve falha?",
          "audioText": "Comunicou a diretoria se houve falha?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "displayWhenAny": [
            {"questionId": "verificou_funcionamento_bomba", "answer": "nao"},
            {"questionId": "painel_indica_normalidade", "answer": "nao"}
          ],
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: condição não conforme. Avisar o responsável antes de continuar."
        }
      ]
    },
    {
      "id": "checklist_montagem_nova_pastagem_pecuaria",
      "title": "Montagem de Nova Pastagem",
      "description": "Medição da área, fechamento do ultradenso e registro de horário",
      "iconDart": "Icons.grass_rounded",
      "areaId": "area_pecuaria",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "usou_app_medicao_area_diretoria",
          "block": "Medição da área",
          "text": "Usou o app de medição na área passada pela diretoria?",
          "audioText": "Usou o aplicativo de medição na área passada pela diretoria?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a área deve ser medida conforme orientação da diretoria antes de montar a nova pastagem."
        },
        {
          "id": "medicao_dentro_padrao",
          "block": "Medição da área",
          "text": "Medição dentro do padrão?",
          "audioText": "A medição está dentro do padrão de aproximadamente um vírgula quatro hectares?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "area_medida",
            "label": "Informe ou grave a área medida",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: 1,4 hectares"
          },
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a medição está fora do padrão esperado. Avisar o responsável antes de continuar."
        },
        {
          "id": "fechou_corretamente_ultradenso",
          "block": "Fechamento da área",
          "text": "Fechou corretamente o ultradenso?",
          "audioText": "Fechou corretamente o ultradenso?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o ultradenso precisa ser fechado corretamente antes de finalizar.",
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto do ultradenso fechado",
            "instruction": "Tire uma foto mostrando o ultradenso fechado corretamente.",
            "mockLocalFile": "foto_ultradenso_fechado_pastagem_mock.jpg"
          }
        },
        {
          "id": "registrou_horario_planilha",
          "block": "Registro final",
          "text": "Registrou o horário na planilha?",
          "audioText": "Registrou o horário na planilha?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o horário deve ser registrado na planilha."
        }
      ]
    },
    {
      "id": "checklist_analise_gado_pecuaria",
      "title": "Análise de Gado",
      "description": "Análise conforme cronograma, estado geral do gado e ocorrências",
      "iconDart": "Icons.monitor_heart_rounded",
      "areaId": "area_pecuaria",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "realizou_analise_conforme_cronograma_rotativo",
          "block": "Análise programada",
          "text": "Realizou análise conforme cronograma rotativo?",
          "audioText": "Realizou a análise conforme o cronograma rotativo?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a análise deve seguir o cronograma rotativo definido."
        },
        {
          "id": "informou_estado_geral_gado",
          "block": "Estado do gado",
          "text": "Informou o estado geral do gado?",
          "audioText": "Informou o estado geral do gado?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "estado_geral_gado",
            "label": "Informe ou grave o estado geral do gado",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: gado calmo, alimentando bem, sem ocorrência aparente"
          },
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o estado geral do gado deve ser informado."
        },
        {
          "id": "registrou_ocorrencia",
          "block": "Ocorrência",
          "text": "Registrou ocorrência?",
          "audioText": "Registrou alguma ocorrência?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "descricao_ocorrencia",
            "label": "Descreva ou grave a ocorrência",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: animal mancando, animal isolado, queda de cerca, comportamento estranho"
          },
          "alertWhenAnswer": "sim",
          "alertMessage": "Atenção: ocorrência registrada. Avisar o responsável, se necessário."
        }
      ]
    },
    {
      "id": "checklist_gado_cria_rotina_diaria_pecuaria",
      "title": "Gado Cria - Rotina Diária",
      "description": "Segurança, observação do gado, bezerros, água, sal, cercas, nascimentos e contagem",
      "iconDart": "Icons.pets_rounded",
      "areaId": "area_pecuaria",
      "appliesPerPen": false,
      "questions": [
        {
          "id": "checklist_seguranca_cavalo_e_equipamentos",
          "block": "Segurança inicial",
          "text": "Fez o checklist de segurança do cavalo e equipamentos?",
          "audioText": "Fez o checklist de segurança do cavalo e dos equipamentos?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o checklist de segurança do cavalo e dos equipamentos deve ser feito antes da rotina."
        },
        {
          "id": "observou_estado_geral_gado",
          "block": "Observação do gado",
          "text": "Observou o estado geral do gado?",
          "audioText": "Observou o estado geral do gado?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "estado_geral_gado",
            "label": "Informe ou grave o estado geral do gado",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: gado calmo, saudável, sem alteração aparente"
          },
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o estado geral do gado deve ser observado."
        },
        {
          "id": "verificou_bezerros_mamando",
          "block": "Observação do gado",
          "text": "Verificou bezerros mamando?",
          "audioText": "Verificou se os bezerros estão mamando?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: verificar bezerros que podem não estar mamando corretamente."
        },
        {
          "id": "conferiu_dias_pasto_registrado",
          "block": "Pasto",
          "text": "Conferiu os dias no pasto?",
          "audioText": "Conferiu os dias no pasto registrados?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "dias_no_pasto",
            "label": "Informe ou grave os dias no pasto",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: lote está há 3 dias no pasto"
          }
        },
        {
          "id": "agua_potavel_bebedouro",
          "block": "Água e sal",
          "text": "Água potável no bebedouro?",
          "audioText": "Tem água potável no bebedouro?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: o bebedouro precisa ter água potável.",
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto do bebedouro",
            "instruction": "Tire uma foto mostrando a água potável no bebedouro.",
            "mockLocalFile": "foto_agua_potavel_bebedouro_gado_cria_mock.jpg"
          }
        },
        {
          "id": "verificou_sal_disponivel",
          "block": "Água e sal",
          "text": "Verificou sal disponível?",
          "audioText": "Verificou se há sal disponível?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: verificar a disponibilidade de sal.",
          "photoRequest": {
            "requiredWhenAnswer": "sim",
            "label": "Tirar foto do sal disponível",
            "instruction": "Tire uma foto mostrando o sal disponível.",
            "mockLocalFile": "foto_sal_disponivel_gado_cria_mock.jpg"
          }
        },
        {
          "id": "conferiu_cercas",
          "block": "Cercas",
          "text": "Conferiu as cercas?",
          "audioText": "Conferiu as cercas?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: as cercas precisam ser conferidas."
        },
        {
          "id": "registrou_nascimentos",
          "block": "Registros",
          "text": "Registrou nascimentos?",
          "audioText": "Registrou os nascimentos?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "numero_nascimentos",
            "label": "Qual o número de nascimentos?",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: 2 nascimentos"
          }
        },
        {
          "id": "realizou_contagem_gado",
          "block": "Registros",
          "text": "Realizou contagem do gado?",
          "audioText": "Realizou a contagem do gado?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "numero_gado_contado",
            "label": "Qual o número contado?",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: 127 animais"
          },
          "alertWhenAnswer": "nao",
          "alertMessage": "Atenção: a contagem do gado deve ser realizada."
        },
        {
          "id": "registrou_qualquer_ocorrencia",
          "block": "Ocorrências",
          "text": "Registrou alguma ocorrência?",
          "audioText": "Registrou qualquer ocorrência?",
          "answerType": "simNao",
          "options": ["sim", "nao"],
          "required": true,
          "additionalField": {
            "id": "descricao_ocorrencia",
            "label": "Descreva ou grave a ocorrência",
            "inputType": "textOrAudio",
            "requiredWhenAnswer": "sim",
            "placeholder": "Exemplo: animal machucado, bezerro sem mamar, cerca caída, falta de água"
          },
          "alertWhenAnswer": "sim",
          "alertMessage": "Atenção: ocorrência registrada. Avisar o responsável, se necessário."
        }
      ]
    }
  ]
}
```

---

## Notas de modelagem (apenas o que existe na POC)

- `areaId` só possui dois valores na POC: `area_agricultura` e `area_pecuaria` (ver `OperationalAreasRepository`).
- `appliesPerPen=true` significa “checklist por curral”. Na POC, isso existe apenas na **Pecuária**.
- `responsible` (quando presente) existe para checklists **por curral** e hoje usa somente `tratador` e `vaqueiro`.
- `displayWhen` / `displayWhenAny` representam regras condicionais de exibição de perguntas.
- `additionalField` é o campo complementar (texto/áudio) solicitado dependendo de uma resposta.
- `level` é o “nível/nota” exigido em perguntas do tipo `simNaoComNivel`.
- `photoRequest` indica solicitação de foto. Alguns itens possuem `mockLocalFile` (nome do arquivo usado na POC quando a foto é mockada).
