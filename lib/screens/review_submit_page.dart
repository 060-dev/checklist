import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/data/checklists_repository.dart';
import 'package:morro_do_peo/models/checklist_models.dart';
import 'package:morro_do_peo/services/offline_queue_service.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class ReviewSubmitPage extends StatelessWidget {
  const ReviewSubmitPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<AppSession>();
    final op = session.selectedOperator;
    final checklist = session.selectedChecklist;
    final area = session.selectedArea;
    final pen = session.selectedPen;
    final responsibleLabel = session.operationalResponsible?.label;

    final sim = session.countAnswer('sim');
    final nao = session.countAnswer('nao');
    final ok = session.countAnswer('ok');
    final hasObs = session.observation != null;
    final hasAdditional = session.hasAnyAdditionalField();
    final hasLossesObservation = (checklist?.id == ChecklistsRepository.colheitaId)
        ? (session.responsesByQuestionId['avaliou_perdas_chao_copo_medidor_embrapa']?.additionalFields['observacao_perdas_chao'] != null)
        : null;
    final photoCount = session.photoCount();
    final hasPhoto = photoCount > 0;
    final alertCount = session.alertCount();

    final blockCompletion = <String, bool>{};
    if (checklist != null) {
      final visible = _visibleQuestions(checklist: checklist, session: session);
      final byBlock = <String, List<String>>{};
      for (final q in visible) {
        final b = (q.block ?? '').trim();
        if (b.isEmpty) continue;
        (byBlock[b] ??= []).add(q.id);
      }
      for (final entry in byBlock.entries) {
        final allAnswered = entry.value.every((id) => session.responsesByQuestionId.containsKey(id));
        blockCompletion[entry.key] = allAnswered;
      }
    }

    final hasQuantidadePorCurral = session.responsesByQuestionId['conferiu_quantidade_necessaria_por_curral']?.additionalFields['quantidade_por_curral'] != null;
    final hasVoltagemInformada = (checklist?.id == ChecklistsRepository.ultraDensoPecuariaId)
        ? (session.responsesByQuestionId['conferiu_voltagem']?.additionalFields['valor_voltagem_observada'] != null)
        : null;
    final hasAreaMedida = (checklist?.id == ChecklistsRepository.montagemNovaPastagemPecuariaId)
        ? (session.responsesByQuestionId['medicao_dentro_padrao']?.additionalFields['area_medida'] != null)
        : null;

    final hasEstadoGeralGado = (checklist?.id == ChecklistsRepository.analiseGadoPecuariaId)
        ? (session.responsesByQuestionId['informou_estado_geral_gado']?.additionalFields['estado_geral_gado'] != null)
        : null;
    final hasOcorrenciaGado = (checklist?.id == ChecklistsRepository.analiseGadoPecuariaId)
        ? (session.responsesByQuestionId['registrou_ocorrencia']?.answer == 'sim')
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text('Revisar checklist'),
        actions: [
          IconButton(
            tooltip: 'Ver JSON (técnico)',
            onPressed: () => _showJson(context),
            icon: Icon(Icons.code, color: theme.colorScheme.primary),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryCard(
                areaTitle: area?.title,
                operatorName: op?.name ?? '-',
                checklistTitle: checklist?.title ?? '-',
                checklistId: checklist?.id,
                penName: checklist?.appliesPerPen == true ? (pen?.name ?? '-') : null,
                responsibleLabel: (checklist?.appliesPerPen == true) ? responsibleLabel : null,
                blockCompletion: blockCompletion,
                sim: sim,
                nao: nao,
                ok: ok,
                showOk: ok > 0,
                hasObservation: hasObs,
                hasAdditional: hasAdditional,
                hasLossesObservation: hasLossesObservation,
                hasQuantidadePorCurral: hasQuantidadePorCurral,
                hasVoltagemInformada: hasVoltagemInformada,
                hasAreaMedida: hasAreaMedida,
                hasEstadoGeralGado: hasEstadoGeralGado,
                hasOcorrenciaGado: hasOcorrenciaGado,
                hasPhoto: hasPhoto,
                photoCount: photoCount,
                alertCount: alertCount,
              ),
              const Spacer(),
              SizedBox(
                height: 72,
                child: FilledButton.icon(
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    session.finishNow();
                    try {
                      final payload = session.buildFinalJson();
                      debugPrint('CHECKLIST_JSON: ${jsonEncode(payload)}');
                      if (kDebugMode) debugPrint(session.buildFinalJsonPretty());
                      await OfflineQueueService.instance.enqueue(
                        payload: payload,
                        checklistId: checklist?.id,
                        operatorId: session.selectedOperator?.id,
                      );
                    } catch (e) {
                      debugPrint('Failed to build final JSON: $e');
                    }

                    final isPerPen = checklist?.appliesPerPen == true;
                    if (isPerPen && pen != null) {
                      final status = session.hasAnyAlert() ? PenChecklistStatus.comAlerta : PenChecklistStatus.preenchido;
                      if (checklist != null) {
                        session.updatePenChecklistStatusToday(penId: pen.id, checklistId: checklist.id, status: status);
                      }
                      session.prepareSuccess(
                        title: session.hasAnyAlert() ? 'Checklist salvo com alerta' : 'Checklist salvo',
                        message: checklist == null
                            ? (session.hasAnyAlert() ? '${pen.name} registrado com alerta.' : '${pen.name} registrado com sucesso.')
                            : (session.hasAnyAlert()
                                ? '${checklist.title} de ${pen.name} registrado com alerta. Existe uma ocorrência que precisa de atenção.'
                                : '${checklist.title} de ${pen.name} registrado com sucesso.'),
                        returnLocation: '/pecuaria/currais/checklists',
                        returnLabel: 'Voltar para checklists do curral',
                        isQueued: true,
                      );
                    } else {
                      final isPecuariaGeneral = (area?.id == OperationalAreasRepository.pecuariaId) && checklist != null && !checklist.appliesPerPen;
                      if (isPecuariaGeneral) {
                        final status = session.hasAnyAlert() ? ChecklistDayStatus.comAlerta : ChecklistDayStatus.preenchido;
                        session.updateGeneralChecklistStatusToday(checklistId: checklist.id, status: status);
                        session.prepareSuccess(
                          title: session.hasAnyAlert() ? 'Checklist salvo com alerta' : 'Checklist salvo',
                          message: session.hasAnyAlert()
                              ? '${checklist.title} registrada. Existe uma condição que precisa de atenção.'
                              : '${checklist.title} registrada com sucesso.',
                          returnLocation: '/pecuaria/gerais',
                          returnLabel: 'Voltar para checklists gerais',
                          isQueued: true,
                        );
                      } else {
                        session.prepareSuccess(
                          title: 'Checklist salvo',
                          message: 'Seu checklist foi registrado.',
                          returnLocation: '/checklists',
                          returnLabel: 'Voltar para checklists',
                          isQueued: true,
                        );
                      }
                    }
                    router.go('/success');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                  icon: Icon(Icons.send, color: theme.colorScheme.onPrimary, size: 24),
                  label: Text(
                    'Enviar checklist',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJson(BuildContext context) {
    final session = context.read<AppSession>();
    String jsonText;
    try {
      jsonText = session.buildFinalJsonPretty();
    } catch (_) {
      jsonText = '{\n  "erro": "Sessão incompleta"\n}';
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => _JsonSheet(jsonText: jsonText),
    );
  }

  List<ChecklistQuestion> _visibleQuestions({required ChecklistDefinition checklist, required AppSession session}) {
    final out = <ChecklistQuestion>[];
    for (final q in checklist.questions) {
      final cond = q.displayWhen;
      final any = q.displayWhenAny;
      if (cond == null && any.isEmpty) {
        out.add(q);
        continue;
      }
      var visible = true;
      if (cond != null) {
        final prev = session.answerFor(cond.questionId);
        visible = prev == cond.answer;
      }
      if (visible && any.isNotEmpty) {
        visible = any.any((rule) => session.answerFor(rule.questionId) == rule.answer);
      }
      if (visible) out.add(q);
    }
    return out;
  }
}

class _SummaryCard extends StatelessWidget {
  final String? areaTitle;
  final String operatorName;
  final String checklistTitle;
  final String? checklistId;
  final String? penName;
  final String? responsibleLabel;
  final Map<String, bool> blockCompletion;
  final int sim;
  final int nao;
  final int ok;
  final bool showOk;
  final bool hasObservation;
  final bool hasAdditional;
  final bool? hasLossesObservation;
  final bool hasQuantidadePorCurral;
  final bool? hasVoltagemInformada;
  final bool? hasAreaMedida;
  final bool? hasEstadoGeralGado;
  final bool? hasOcorrenciaGado;
  final bool hasPhoto;
  final int photoCount;
  final int alertCount;

  const _SummaryCard({
    required this.areaTitle,
    required this.operatorName,
    required this.checklistTitle,
    required this.checklistId,
    required this.penName,
    required this.responsibleLabel,
    required this.blockCompletion,
    required this.sim,
    required this.nao,
    required this.ok,
    required this.showOk,
    required this.hasObservation,
    required this.hasAdditional,
    required this.hasLossesObservation,
    required this.hasQuantidadePorCurral,
    required this.hasVoltagemInformada,
    required this.hasAreaMedida,
    required this.hasEstadoGeralGado,
    required this.hasOcorrenciaGado,
    required this.hasPhoto,
    required this.photoCount,
    required this.alertCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: primary.withValues(alpha: 0.16), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((areaTitle ?? '').trim().isNotEmpty) ...[
            Text('Área: ${areaTitle!}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text('Funcionário: $operatorName', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.xs),
          Text('Checklist: $checklistTitle', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          if ((penName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Curral: $penName', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          ],
          if ((responsibleLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Rotina: $responsibleLabel', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (blockCompletion.isNotEmpty) ...[
            for (final entry in blockCompletion.entries) ...[
              Row(
                children: [
                  Icon(entry.value ? Icons.check_circle : Icons.radio_button_unchecked, color: entry.value ? AppColors.success : theme.colorScheme.onSurfaceVariant, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('${entry.key}: ${entry.value ? 'preenchido' : 'pendente'}', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
          _CountRow(label: 'Sim', value: sim, color: AppColors.success),
          const SizedBox(height: AppSpacing.sm),
          _CountRow(label: 'Não', value: nao, color: AppColors.error),
          if (showOk) ...[
            const SizedBox(height: AppSpacing.sm),
            _CountRow(label: 'Ok', value: ok, color: AppColors.info),
          ],
          const SizedBox(height: AppSpacing.sm),
          _CountRow(label: 'Alertas', value: alertCount, color: AppColors.warning),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Icon(hasObservation ? Icons.mic : Icons.mic_none, color: primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Observação em áudio: ${hasObservation ? 'Sim' : 'Não'}',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (checklistId == ChecklistsRepository.colheitaId && hasLossesObservation != null)
            Row(
              children: [
                Icon(hasLossesObservation! ? Icons.mic : Icons.mic_none, color: primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Observação sobre perdas: ${hasLossesObservation! ? 'Sim' : 'Não'}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(hasAdditional ? Icons.check_circle : Icons.radio_button_unchecked, color: primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Campos extras: ${hasAdditional ? 'Sim' : 'Não'}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          if (checklistId == ChecklistsRepository.alimentacaoPecuariaId) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(hasQuantidadePorCurral ? Icons.check_circle : Icons.radio_button_unchecked, color: primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Quantidade por curral: ${hasQuantidadePorCurral ? 'Informada' : 'Não informada'}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
          if (checklistId == ChecklistsRepository.ultraDensoPecuariaId && hasVoltagemInformada != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(hasVoltagemInformada! ? Icons.check_circle : Icons.radio_button_unchecked, color: primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Voltagem informada: ${hasVoltagemInformada! ? 'Sim' : 'Não'}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
          if (checklistId == ChecklistsRepository.montagemNovaPastagemPecuariaId && hasAreaMedida != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(hasAreaMedida! ? Icons.check_circle : Icons.radio_button_unchecked, color: primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Área medida: ${hasAreaMedida! ? 'Informada' : 'Não informada'}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
          if (checklistId == ChecklistsRepository.analiseGadoPecuariaId && hasEstadoGeralGado != null && hasOcorrenciaGado != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(hasEstadoGeralGado! ? Icons.check_circle : Icons.radio_button_unchecked, color: primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Estado geral informado: ${hasEstadoGeralGado! ? 'Sim' : 'Não'}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(hasOcorrenciaGado! ? Icons.warning_rounded : Icons.check_circle, color: primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Ocorrência registrada: ${hasOcorrenciaGado! ? 'Sim' : 'Não'}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(hasPhoto ? Icons.photo : Icons.photo_outlined, color: primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Fotos anexadas: $photoCount',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CountRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text('$label:', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800))),
        Text('$value', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
      ],
    );
  }
}

class _JsonSheet extends StatelessWidget {
  final String jsonText;

  const _JsonSheet({required this.jsonText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.code, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('JSON gerado', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.16)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SelectableText(
                  jsonText,
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
