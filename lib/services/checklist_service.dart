import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morro_do_peo/models/checklist.dart';
import 'package:morro_do_peo/models/checklist_question.dart';
import 'package:morro_do_peo/models/checklist_area.dart';
import 'package:morro_do_peo/services/morro_api_client.dart';
import 'package:morro_do_peo/services/morro_api_config.dart';

class ChecklistService {
  static final ChecklistService _instance = ChecklistService._internal();
  factory ChecklistService() => _instance;
  ChecklistService._internal();

  static const String _storageKey = 'cached_catalog';
  final MorroApiClient _api = MorroApiClient();
  List<Checklist> _checklists = [];
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final Map<String, dynamic> decoded = jsonDecode(data);
        
        final rawAreas = decoded['areas'] as List<dynamic>? ?? [];
        if (rawAreas.isNotEmpty) {
          ChecklistArea.setAreas(rawAreas.map((e) => ChecklistArea.fromJson(e as Map<String, dynamic>)).toList());
        }

        final rawChecklists = decoded['checklists'] as List<dynamic>? ?? [];
        if (rawChecklists.isNotEmpty) {
          _checklists = rawChecklists.map((e) => Checklist.fromJson(e as Map<String, dynamic>)).toList();
          debugPrint('[ChecklistService] Loaded ${_checklists.length} checklists from cache');
        } else {
          _checklists = _sampleChecklists;
        }
      } else {
        _checklists = _sampleChecklists;
      }
    } catch (e) {
      debugPrint('[ChecklistService] Error loading cache: $e');
      _checklists = _sampleChecklists;
    } finally {
      _isInitialized = true;
    }
  }

  Future<void> syncCatalog() async {
    try {
      debugPrint('[SYNC] Starting catalog sync...');
      final json = await _api.getJson('/catalog', query: {
        'farmId': MorroApiConfig.farmId,
      });

      final rawAreas = json['areas'] as List<dynamic>? ?? [];
      final rawChecklists = json['checklists'] as List<dynamic>? ?? [];
      final rawQuestions = json['questions'] as List<dynamic>? ?? [];

      if (rawAreas.isNotEmpty) {
        final areas = rawAreas.map((e) => ChecklistArea.fromJson(e as Map<String, dynamic>)).toList();
        ChecklistArea.setAreas(areas);
      }

      if (rawChecklists.isNotEmpty) {
        // Parse questions first
        final allQuestions = rawQuestions.map((e) => ChecklistQuestion.fromJson(e as Map<String, dynamic>)).toList();

        // Parse checklists and attach their questions
        _checklists = rawChecklists.map((c) {
          final map = c as Map<String, dynamic>;
          final id = map['id'] as String;
          
          // Re-parse with questions
          final base = Checklist.fromJson(map);
          return Checklist(
            id: base.id,
            areaId: base.areaId,
            name: base.name,
            simpleName: base.simpleName,
            description: base.description,
            estimatedMinutes: base.estimatedMinutes,
            icon: base.icon,
            version: base.version,
            questions: allQuestions.where((q) => rawQuestions.any((rq) => rq['id'] == q.id && rq['checklistId'] == id)).toList(),
            createdAt: base.createdAt,
            updatedAt: base.updatedAt,
          );
        }).toList();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKey, jsonEncode({
          'areas': rawAreas,
          'checklists': _checklists.map((e) => e.toJson()).toList(),
        }));
        debugPrint('[SYNC] Catalog updated: ${_checklists.length} checklists, ${rawAreas.length} areas');
      }
    } catch (e) {
      debugPrint('[SYNC] Catalog sync failed: $e');
    }
  }

  List<Checklist> getChecklistsByArea(String areaId) {
    return _checklists.where((c) => c.areaId == areaId).toList();
  }

  Checklist? getChecklistById(String id) {
    try {
      return _checklists.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static final List<Checklist> _sampleChecklists = [
    // Agriculture Checklists
    Checklist(
      id: 'agri-soil',
      areaId: 'agriculture',
      name: 'Preparo do Solo',
      simpleName: 'Preparar Solo',
      description: 'Verificar condições do solo antes do plantio',
      estimatedMinutes: 15,
      icon: Icons.landscape,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      questions: [
        ChecklistQuestion(
          id: 'agri-soil-1',
          order: 1,
          fullText: 'O solo está com umidade adequada para o trabalho?',
          simpleText: 'Solo úmido?',
          audioText: 'O solo está úmido o suficiente?',
          answerType: AnswerType.yesNo,
          icon: Icons.water_drop,
        ),
        ChecklistQuestion(
          id: 'agri-soil-2',
          order: 2,
          fullText: 'Há presença de pedras ou obstáculos no terreno?',
          simpleText: 'Tem pedras?',
          audioText: 'Encontrou pedras ou objetos no caminho?',
          answerType: AnswerType.yesNo,
          requiresPhoto: true,
          photoInstruction: 'Tire foto das pedras ou obstáculos',
          icon: Icons.warning,
        ),
        ChecklistQuestion(
          id: 'agri-soil-3',
          order: 3,
          fullText: 'O trator e implementos estão funcionando corretamente?',
          simpleText: 'Trator OK?',
          audioText: 'O trator está funcionando bem?',
          answerType: AnswerType.yesNo,
          icon: Icons.agriculture,
        ),
        ChecklistQuestion(
          id: 'agri-soil-4',
          order: 4,
          fullText: 'Qual a condição geral do terreno?',
          simpleText: 'Como está o terreno?',
          audioText: 'Como você avalia o terreno?',
          answerType: AnswerType.choice,
          choices: ['Ótimo', 'Bom', 'Regular', 'Ruim'],
          icon: Icons.terrain,
        ),
        ChecklistQuestion(
          id: 'agri-soil-5',
          order: 5,
          fullText: 'Tire uma foto do terreno preparado',
          simpleText: 'Foto do terreno',
          audioText: 'Tire uma foto mostrando o terreno',
          answerType: AnswerType.photo,
          requiresPhoto: true,
          photoInstruction: 'Mostre o terreno preparado',
          icon: Icons.camera_alt,
        ),
      ],
    ),
    Checklist(
      id: 'agri-plant',
      areaId: 'agriculture',
      name: 'Plantio',
      simpleName: 'Plantar',
      description: 'Checklist de plantio de sementes',
      estimatedMinutes: 20,
      icon: Icons.grass,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      questions: [
        ChecklistQuestion(
          id: 'agri-plant-1',
          order: 1,
          fullText: 'As sementes estão disponíveis e em bom estado?',
          simpleText: 'Sementes OK?',
          audioText: 'As sementes estão boas?',
          answerType: AnswerType.yesNo,
          icon: Icons.eco,
        ),
        ChecklistQuestion(
          id: 'agri-plant-2',
          order: 2,
          fullText: 'A plantadeira está calibrada corretamente?',
          simpleText: 'Plantadeira OK?',
          audioText: 'A plantadeira está regulada?',
          answerType: AnswerType.yesNo,
          icon: Icons.settings,
        ),
        ChecklistQuestion(
          id: 'agri-plant-3',
          order: 3,
          fullText: 'Quantos sacos de semente serão usados?',
          simpleText: 'Quantos sacos?',
          audioText: 'Quantos sacos de semente você vai usar?',
          answerType: AnswerType.number,
          icon: Icons.inventory,
        ),
        ChecklistQuestion(
          id: 'agri-plant-4',
          order: 4,
          fullText: 'Alguma observação sobre o plantio?',
          simpleText: 'Quer falar algo?',
          audioText: 'Quer deixar alguma observação?',
          answerType: AnswerType.audioNote,
          isRequired: false,
          icon: Icons.mic,
        ),
      ],
    ),
    Checklist(
      id: 'agri-harvest',
      areaId: 'agriculture',
      name: 'Colheita',
      simpleName: 'Colher',
      description: 'Checklist de colheita',
      estimatedMinutes: 25,
      icon: Icons.agriculture,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      questions: [
        ChecklistQuestion(
          id: 'agri-harvest-1',
          order: 1,
          fullText: 'A colheitadeira está funcionando bem?',
          simpleText: 'Colheitadeira OK?',
          audioText: 'A colheitadeira está funcionando?',
          answerType: AnswerType.yesNo,
          icon: Icons.agriculture,
        ),
        ChecklistQuestion(
          id: 'agri-harvest-2',
          order: 2,
          fullText: 'A cultura está pronta para colheita?',
          simpleText: 'Pronto pra colher?',
          audioText: 'A lavoura está no ponto de colher?',
          answerType: AnswerType.yesNo,
          requiresPhoto: true,
          photoInstruction: 'Foto da lavoura',
          icon: Icons.check_circle,
        ),
        ChecklistQuestion(
          id: 'agri-harvest-3',
          order: 3,
          fullText: 'Qual a condição da lavoura?',
          simpleText: 'Como está a lavoura?',
          audioText: 'Como você avalia a lavoura?',
          answerType: AnswerType.choice,
          choices: ['Excelente', 'Boa', 'Regular', 'Ruim'],
          icon: Icons.assessment,
        ),
      ],
    ),
    Checklist(
      id: 'agri-maintenance',
      areaId: 'agriculture',
      name: 'Manutenção Preventiva',
      simpleName: 'Ver Máquinas',
      description: 'Verificação de máquinas agrícolas',
      estimatedMinutes: 30,
      icon: Icons.build,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      questions: [
        ChecklistQuestion(
          id: 'agri-maint-1',
          order: 1,
          fullText: 'O nível de óleo do motor está adequado?',
          simpleText: 'Óleo OK?',
          audioText: 'O óleo do motor está no nível certo?',
          answerType: AnswerType.yesNo,
          icon: Icons.oil_barrel,
        ),
        ChecklistQuestion(
          id: 'agri-maint-2',
          order: 2,
          fullText: 'Os pneus estão em bom estado?',
          simpleText: 'Pneus OK?',
          audioText: 'Os pneus estão bons?',
          answerType: AnswerType.yesNo,
          requiresPhoto: true,
          photoInstruction: 'Foto dos pneus',
          icon: Icons.tire_repair,
        ),
        ChecklistQuestion(
          id: 'agri-maint-3',
          order: 3,
          fullText: 'Os filtros foram verificados?',
          simpleText: 'Filtros OK?',
          audioText: 'Você verificou os filtros?',
          answerType: AnswerType.yesNo,
          icon: Icons.filter_alt,
        ),
      ],
    ),

    // Livestock Checklists
    Checklist(
      id: 'live-feed',
      areaId: 'livestock',
      name: 'Alimentação do Gado',
      simpleName: 'Alimentar Gado',
      description: 'Checklist de alimentação dos animais',
      estimatedMinutes: 15,
      icon: Icons.restaurant,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      questions: [
        ChecklistQuestion(
          id: 'live-feed-1',
          order: 1,
          fullText: 'Os cochos estão limpos?',
          simpleText: 'Cochos limpos?',
          audioText: 'Os cochos de comida estão limpos?',
          answerType: AnswerType.yesNo,
          icon: Icons.cleaning_services,
        ),
        ChecklistQuestion(
          id: 'live-feed-2',
          order: 2,
          fullText: 'Há ração suficiente para hoje?',
          simpleText: 'Tem ração?',
          audioText: 'Tem ração suficiente para alimentar os animais hoje?',
          answerType: AnswerType.yesNo,
          icon: Icons.inventory_2,
        ),
        ChecklistQuestion(
          id: 'live-feed-3',
          order: 3,
          fullText: 'Os animais estão comendo normalmente?',
          simpleText: 'Gado come bem?',
          audioText: 'Os animais estão se alimentando bem?',
          answerType: AnswerType.yesNo,
          icon: Icons.pets,
        ),
        ChecklistQuestion(
          id: 'live-feed-4',
          order: 4,
          fullText: 'Quantos sacos de ração foram usados?',
          simpleText: 'Quantos sacos?',
          audioText: 'Quantos sacos de ração você usou?',
          answerType: AnswerType.number,
          icon: Icons.scale,
        ),
        ChecklistQuestion(
          id: 'live-feed-5',
          order: 5,
          fullText: 'Algum animal doente ou com comportamento estranho?',
          simpleText: 'Gado doente?',
          audioText: 'Você notou algum animal doente ou estranho?',
          answerType: AnswerType.yesNo,
          requiresPhoto: true,
          photoInstruction: 'Se sim, tire foto do animal',
          icon: Icons.medical_services,
        ),
      ],
    ),
    Checklist(
      id: 'live-water',
      areaId: 'livestock',
      name: 'Lavagem de Bebedouro',
      simpleName: 'Lavar Bebedouro',
      description: 'Limpeza e manutenção de bebedouros',
      estimatedMinutes: 20,
      icon: Icons.water,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      questions: [
        ChecklistQuestion(
          id: 'live-water-1',
          order: 1,
          fullText: 'O bebedouro foi esvaziado?',
          simpleText: 'Esvaziou?',
          audioText: 'Você esvaziou o bebedouro?',
          answerType: AnswerType.yesNo,
          icon: Icons.water_drop,
        ),
        ChecklistQuestion(
          id: 'live-water-2',
          order: 2,
          fullText: 'O bebedouro foi escovado?',
          simpleText: 'Escovou?',
          audioText: 'Você escovou o bebedouro?',
          answerType: AnswerType.yesNo,
          icon: Icons.brush,
        ),
        ChecklistQuestion(
          id: 'live-water-3',
          order: 3,
          fullText: 'A água está limpa e fresca?',
          simpleText: 'Água limpa?',
          audioText: 'A água ficou limpa?',
          answerType: AnswerType.yesNo,
          requiresPhoto: true,
          photoInstruction: 'Foto do bebedouro limpo',
          icon: Icons.opacity,
        ),
        ChecklistQuestion(
          id: 'live-water-4',
          order: 4,
          fullText: 'A boia está funcionando?',
          simpleText: 'Boia OK?',
          audioText: 'A boia do bebedouro está funcionando?',
          answerType: AnswerType.yesNo,
          icon: Icons.settings,
        ),
      ],
    ),
    Checklist(
      id: 'live-well',
      areaId: 'livestock',
      name: 'Poços Artesianos',
      simpleName: 'Ver Poço',
      description: 'Verificação de poços artesianos',
      estimatedMinutes: 15,
      icon: Icons.water,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      questions: [
        ChecklistQuestion(
          id: 'live-well-1',
          order: 1,
          fullText: 'A bomba está funcionando?',
          simpleText: 'Bomba OK?',
          audioText: 'A bomba do poço está funcionando?',
          answerType: AnswerType.yesNo,
          icon: Icons.power,
        ),
        ChecklistQuestion(
          id: 'live-well-2',
          order: 2,
          fullText: 'Há vazamento na tubulação?',
          simpleText: 'Tem vazamento?',
          audioText: 'Encontrou algum vazamento nos canos?',
          answerType: AnswerType.yesNo,
          requiresPhoto: true,
          photoInstruction: 'Se sim, tire foto do vazamento',
          icon: Icons.plumbing,
        ),
        ChecklistQuestion(
          id: 'live-well-3',
          order: 3,
          fullText: 'O nível da caixa d\'água está bom?',
          simpleText: 'Caixa cheia?',
          audioText: 'A caixa de água está com nível bom?',
          answerType: AnswerType.yesNo,
          icon: Icons.water_drop,
        ),
      ],
    ),
    Checklist(
      id: 'live-pasture',
      areaId: 'livestock',
      name: 'Montagem de Pastagem',
      simpleName: 'Ver Pasto',
      description: 'Verificação e montagem de pastagem',
      estimatedMinutes: 20,
      icon: Icons.grass,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      questions: [
        ChecklistQuestion(
          id: 'live-pasture-1',
          order: 1,
          fullText: 'O pasto está com altura adequada?',
          simpleText: 'Pasto bom?',
          audioText: 'O capim está na altura certa?',
          answerType: AnswerType.yesNo,
          requiresPhoto: true,
          photoInstruction: 'Foto do pasto',
          icon: Icons.grass,
        ),
        ChecklistQuestion(
          id: 'live-pasture-2',
          order: 2,
          fullText: 'As cercas estão em bom estado?',
          simpleText: 'Cercas OK?',
          audioText: 'As cercas estão boas?',
          answerType: AnswerType.yesNo,
          icon: Icons.fence,
        ),
        ChecklistQuestion(
          id: 'live-pasture-3',
          order: 3,
          fullText: 'Há ervas daninhas no pasto?',
          simpleText: 'Tem mato ruim?',
          audioText: 'Encontrou mato ruim ou erva daninha?',
          answerType: AnswerType.yesNo,
          requiresPhoto: true,
          photoInstruction: 'Se sim, tire foto das ervas',
          icon: Icons.warning,
        ),
        ChecklistQuestion(
          id: 'live-pasture-4',
          order: 4,
          fullText: 'Qual a condição geral do pasto?',
          simpleText: 'Como está?',
          audioText: 'Como você avalia o pasto?',
          answerType: AnswerType.choice,
          choices: ['Ótimo', 'Bom', 'Regular', 'Ruim'],
          icon: Icons.assessment,
        ),
      ],
    ),

    // Maintenance Checklists
    Checklist(
      id: 'maint-general',
      areaId: 'maintenance',
      name: 'Manutenção Geral',
      simpleName: 'Ver Tudo',
      description: 'Verificação geral de equipamentos',
      estimatedMinutes: 25,
      icon: Icons.build,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      questions: [
        ChecklistQuestion(
          id: 'maint-gen-1',
          order: 1,
          fullText: 'As ferramentas estão organizadas?',
          simpleText: 'Ferramentas OK?',
          audioText: 'As ferramentas estão no lugar?',
          answerType: AnswerType.yesNo,
          icon: Icons.construction,
        ),
        ChecklistQuestion(
          id: 'maint-gen-2',
          order: 2,
          fullText: 'O galpão está limpo?',
          simpleText: 'Galpão limpo?',
          audioText: 'O galpão está limpo e organizado?',
          answerType: AnswerType.yesNo,
          icon: Icons.warehouse,
        ),
        ChecklistQuestion(
          id: 'maint-gen-3',
          order: 3,
          fullText: 'Há algum equipamento quebrado?',
          simpleText: 'Algo quebrado?',
          audioText: 'Encontrou algum equipamento quebrado?',
          answerType: AnswerType.yesNo,
          requiresPhoto: true,
          photoInstruction: 'Se sim, tire foto do equipamento',
          icon: Icons.broken_image,
        ),
      ],
    ),

    // Daily Routine
    Checklist(
      id: 'daily-open',
      areaId: 'daily',
      name: 'Abertura do Dia',
      simpleName: 'Abrir Rotina',
      description: 'Rotina de abertura diária',
      estimatedMinutes: 10,
      icon: Icons.wb_sunny,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      questions: [
        ChecklistQuestion(
          id: 'daily-open-1',
          order: 1,
          fullText: 'Você chegou no horário?',
          simpleText: 'Chegou na hora?',
          audioText: 'Você chegou no horário certo?',
          answerType: AnswerType.yesNo,
          icon: Icons.access_time,
        ),
        ChecklistQuestion(
          id: 'daily-open-2',
          order: 2,
          fullText: 'Como está o tempo hoje?',
          simpleText: 'Tempo?',
          audioText: 'Como está o clima hoje?',
          answerType: AnswerType.choice,
          choices: ['Sol', 'Nublado', 'Chuva', 'Frio'],
          icon: Icons.wb_cloudy,
        ),
        ChecklistQuestion(
          id: 'daily-open-3',
          order: 3,
          fullText: 'Alguma observação inicial?',
          simpleText: 'Algo pra falar?',
          audioText: 'Quer deixar alguma observação?',
          answerType: AnswerType.audioNote,
          isRequired: false,
          icon: Icons.mic,
        ),
      ],
    ),
  ];
}
