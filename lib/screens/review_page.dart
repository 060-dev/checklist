import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:morro_do_peo/models/checklist_area.dart';
import 'package:morro_do_peo/models/checklist_submission.dart';
import 'package:morro_do_peo/services/checklist_service.dart';
import 'package:morro_do_peo/services/draft_submission_service.dart';
import 'package:morro_do_peo/services/submission_service.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/components/large_action_button.dart';

class ReviewPage extends StatefulWidget {
  final String checklistId;
  final String? operatorName;
  final String? operatorId;

  const ReviewPage({
    super.key,
    required this.checklistId,
    this.operatorName,
    this.operatorId,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _isSending = false;
  final DraftSubmissionService _drafts = DraftSubmissionService();
  final SubmissionService _submissions = SubmissionService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checklistService = ChecklistService();
    final checklist = checklistService.getChecklistById(widget.checklistId);

    if (checklist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: const Center(child: Text('Checklist não encontrado')),
      );
    }

    final area = ChecklistArea.getAreas().firstWhere(
      (a) => a.id == checklist.areaId,
      orElse: () => ChecklistArea.getAreas().first,
    );

    // Simulated data for the prototype
    final totalQuestions = checklist.questions.length;
    final answeredQuestions = totalQuestions;
    final problemsFound = 1; // Simulated
    final photosCount = 2; // Simulated

    final op = widget.operatorName;
    final opQuery = (op != null && op.trim().isNotEmpty) ? 'op=${Uri.encodeComponent(op)}' : null;
    final opId = widget.operatorId;
    final opIdQuery = (opId != null && opId.trim().isNotEmpty) ? 'opId=${Uri.encodeComponent(opId)}' : null;
    final query = [if (opQuery != null) opQuery, if (opIdQuery != null) opIdQuery].join('&');
    final suffix = query.isNotEmpty ? '?$query' : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar'),
        backgroundColor: area.color,
        foregroundColor: AppColors.onColorFor(area.color),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () {
            context.go('/question/${widget.checklistId}/${totalQuestions - 1}$suffix');
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Success icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 56,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Checklist Completo!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      checklist.simpleName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Summary cards
                    _buildSummaryCard(
                      icon: Icons.quiz,
                      title: 'Perguntas Respondidas',
                      value: '$answeredQuestions de $totalQuestions',
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildSummaryCard(
                      icon: Icons.warning_amber,
                      title: 'Problemas Encontrados',
                      value: problemsFound.toString(),
                      color: problemsFound > 0 ? AppColors.warning : AppColors.success,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildSummaryCard(
                      icon: Icons.camera_alt,
                      title: 'Fotos Tiradas',
                      value: photosCount.toString(),
                      color: AppColors.accentBlue,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Offline indicator
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi, color: AppColors.info),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Dados serão enviados quando houver internet',
                              style: TextStyle(
                                color: AppColors.info,
                                fontSize: FontSizes.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  LargeActionButton(
                    label: _isSending ? 'Enviando...' : 'Enviar Checklist',
                    icon: _isSending ? Icons.hourglass_top : Icons.send,
                    color: area.color,
                    onPressed: _isSending ? () {} : () => _sendChecklist(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LargeActionButton(
                    label: 'Revisar Respostas',
                    icon: Icons.edit,
                    color: theme.colorScheme.onSurfaceVariant,
                    isOutlined: true,
                    onPressed: () {
                      context.go('/question/${widget.checklistId}/0$suffix');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: FontSizes.bodyLarge,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: FontSizes.titleLarge,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _sendChecklist(BuildContext context) async {
    final theme = Theme.of(context);
    setState(() => _isSending = true);

    try {
      await _submissions.init();
      final op = widget.operatorName?.trim();
      final operatorName = (op != null && op.isNotEmpty) ? op : 'Operador';

      final draft = await _drafts.loadDraft(checklistId: widget.checklistId, operatorName: operatorName);
      final answers = (draft['answers'] as List?)?.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() ?? <Map<String, dynamic>>[];

      // Cria uma submissão local (histórico) e enfileira para envio.
      final checklist = ChecklistService().getChecklistById(widget.checklistId);
      final area = checklist != null
          ? ChecklistArea.getAreas().firstWhere((a) => a.id == checklist.areaId, orElse: () => ChecklistArea.getAreas().first)
          : ChecklistArea.getAreas().first;

      final submission = await _submissions.createSubmission(
        checklistId: widget.checklistId,
        checklistName: checklist?.simpleName ?? widget.checklistId,
        areaId: area.id,
        areaName: area.name,
        totalQuestions: checklist?.questions.length ?? answers.length,
        operatorId: widget.operatorId ?? operatorName,
        operatorName: operatorName,
      );

      // Mapeia respostas do draft para o modelo local.
      // Nota: como o protótipo não possui backend real, guardamos o essencial.
      final List<QuestionAnswer> mappedAnswers = answers.map((a) {
        return QuestionAnswer(
          questionId: (a['questionId'] as String?) ?? 'unknown',
          textAnswer: a['value'] is String ? a['value'] as String : null,
          boolAnswer: a['value'] is bool ? a['value'] as bool : null,
          numberAnswer: a['value'] is int ? a['value'] as int : (a['value'] is num ? (a['value'] as num).toInt() : null),
          selectedChoice: a['value'] is String ? a['value'] as String : null,
          photoPath: a['photoBase64'] != null ? 'base64:${(a['photoBase64'] as String).length}' : null,
          audioPath: a['audioRef'] as String?,
          hasProblem: false,
          problemDescription: a['notes'] as String?,
        );
      }).toList();

      await _submissions.updateSubmission(
        submission.copyWith(
          answers: mappedAnswers,
          answeredQuestions: mappedAnswers.length,
          photosCount: mappedAnswers.where((e) => e.photoPath != null).length,
          audioNotesCount: mappedAnswers.where((e) => e.audioPath != null).length,
        ),
      );

      // Monta payload para o backend (SubmissionCreate) + anexos.
      final now = DateTime.now();
      final operatorId = (widget.operatorId != null && widget.operatorId!.trim().isNotEmpty) ? widget.operatorId!.trim() : operatorName;
      final attachmentItems = <Map<String, dynamic>>[];
      final attachmentMetas = <Map<String, dynamic>>[];

      final backendAnswers = answers.map((a) {
        final qid = (a['questionId'] as String?) ?? 'unknown';
        final notes = (a['notes'] as String?)?.trim();
        final localAttachments = <String>[];

        final photoBase64 = a['photoBase64'];
        if (photoBase64 is String && photoBase64.isNotEmpty) {
          final localId = 'photo_$qid';
          localAttachments.add(localId);
          attachmentItems.add({
            'localId': localId,
            'questionId': qid,
            'type': 'photo',
            'base64': photoBase64,
            'mimeType': (a['photoMimeType'] as String?) ?? 'image/jpeg',
            'fileName': 'foto_$qid.jpg',
          });
          attachmentMetas.add({
            'localId': localId,
            'questionId': qid,
            'type': 'photo',
            'fileName': 'foto_$qid.jpg',
            'mimeType': (a['photoMimeType'] as String?) ?? 'image/jpeg',
          });
        }

        return <String, dynamic>{
          'questionId': qid,
          'value': a['value'],
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (localAttachments.isNotEmpty) 'attachments': localAttachments,
        };
      }).toList();

      final backendPayload = <String, dynamic>{
        'clientSubmissionId': submission.id,
        'farmId': submission.farmId,
        'checklistId': submission.checklistId,
        'checklistVersion': checklist?.version ?? 1,
        'operatorId': operatorId,
        'startedAt': submission.startedAt.toIso8601String(),
        'completedAt': now.toIso8601String(),
        'answers': backendAnswers,
        if (attachmentMetas.isNotEmpty) 'attachments': attachmentMetas,
        'device': {
          'platform': theme.platform.name,
          'deviceTime': now.toIso8601String(),
        },
      };

      await _submissions.completeSubmission(
        submission.id,
        backendPayload: backendPayload,
        backendAttachments: attachmentItems.isNotEmpty ? {'items': attachmentItems} : null,
      );
      await _drafts.clearDraft(checklistId: widget.checklistId, operatorName: operatorName);

      if (!mounted) return;
      final opQuery = (operatorName.trim().isNotEmpty) ? 'op=${Uri.encodeComponent(operatorName)}' : null;
      final opId = widget.operatorId;
      final opIdQuery = (opId != null && opId.trim().isNotEmpty) ? 'opId=${Uri.encodeComponent(opId)}' : null;
      final result = _submissions.pendingQueueCount.value > 0 ? 'queued' : 'sent';
      final suffix = [if (opQuery != null) opQuery, if (opIdQuery != null) opIdQuery, 'result=$result'].join('&');
      if (!context.mounted) return;
      context.go('/success/${widget.checklistId}?$suffix');
    } catch (e) {
      debugPrint('Failed to send checklist: $e');
      if (!mounted) return;
      final op = widget.operatorName;
      final opQuery = (op != null && op.trim().isNotEmpty) ? 'op=${Uri.encodeComponent(op)}' : null;
      final opId = widget.operatorId;
      final opIdQuery = (opId != null && opId.trim().isNotEmpty) ? 'opId=${Uri.encodeComponent(opId)}' : null;
      final suffix = [
        if (opQuery != null) opQuery,
        if (opIdQuery != null) opIdQuery,
        'result=queued',
      ].join('&');
      if (!context.mounted) return;
      context.go('/success/${widget.checklistId}?$suffix');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
