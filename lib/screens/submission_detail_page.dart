import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:morro_do_peo/models/checklist_area.dart';
import 'package:morro_do_peo/models/checklist_submission.dart';
import 'package:morro_do_peo/services/checklist_service.dart';
import 'package:morro_do_peo/services/submission_service.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:intl/intl.dart';

class SubmissionDetailPage extends StatefulWidget {
  final String submissionId;

  const SubmissionDetailPage({
    super.key,
    required this.submissionId,
  });

  @override
  State<SubmissionDetailPage> createState() => _SubmissionDetailPageState();
}

class _SubmissionDetailPageState extends State<SubmissionDetailPage> {
  final SubmissionService _submissionService = SubmissionService();
  final ChecklistService _checklistService = ChecklistService();
  bool _isLoading = true;
  ChecklistSubmission? _submission;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _submissionService.init();
      _submission = _submissionService.getSubmissionById(widget.submissionId);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_submission == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: const Center(child: Text('Checklist não encontrado')),
      );
    }

    final submission = _submission!;
    final area = ChecklistArea.getAreas().firstWhere(
      (a) => a.id == submission.areaId,
      orElse: () => ChecklistArea.getAreas().first,
    );
    final checklist = _checklistService.getChecklistById(submission.checklistId);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes'),
        backgroundColor: area.color,
        foregroundColor: AppColors.onColorFor(area.color),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/manager');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: area.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: area.color.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: area.color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          checklist?.icon ?? Icons.checklist,
                          color: AppColors.onColorFor(area.color),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              submission.checklistName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.emphasisColor(area.color),
                              ),
                            ),
                            Text(
                              submission.areaName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.emphasisColor(area.color).withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(submission.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Info cards
            _buildInfoCard(
              icon: Icons.person,
              title: 'Operador',
              value: submission.userName,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildInfoCard(
              icon: Icons.location_on,
              title: 'Fazenda',
              value: submission.farmName,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildInfoCard(
              icon: Icons.access_time,
              title: 'Início',
              value: dateFormat.format(submission.startedAt),
              color: AppColors.accentBlue,
            ),
            if (submission.completedAt != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildInfoCard(
                icon: Icons.check_circle,
                title: 'Conclusão',
                value: dateFormat.format(submission.completedAt!),
                color: AppColors.success,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            // Summary
            Text(
              'Resumo',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.quiz,
                    value: '${submission.answeredQuestions}/${submission.totalQuestions}',
                    label: 'Perguntas',
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.warning_amber,
                    value: submission.problemsFound.toString(),
                    label: 'Problemas',
                    color: submission.problemsFound > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.photo_camera,
                    value: submission.photosCount.toString(),
                    label: 'Fotos',
                    color: AppColors.accentBlue,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildSummaryCard(
                    icon: Icons.mic,
                    value: submission.audioNotesCount.toString(),
                    label: 'Áudios',
                    color: AppColors.secondaryOrange,
                  ),
                ),
              ],
            ),
            // Problems section
            if (submission.problemsFound > 0) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Problemas Encontrados',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...submission.answers
                  .where((a) => a.hasProblem)
                  .map((answer) => _buildProblemCard(answer, checklist)),
            ],
            // Answers section
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Respostas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...submission.answers.map((answer) => _buildAnswerCard(answer, checklist)),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SubmissionStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case SubmissionStatus.synced:
        color = AppColors.success;
        label = 'Enviado';
        icon = Icons.cloud_done;
        break;
      case SubmissionStatus.pendingSync:
        color = AppColors.warning;
        label = 'Pendente';
        icon = Icons.cloud_upload;
        break;
      case SubmissionStatus.inProgress:
        color = AppColors.info;
        label = 'Em andamento';
        icon = Icons.edit;
        break;
      case SubmissionStatus.failed:
        color = AppColors.error;
        label = 'Falhou';
        icon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: FontSizes.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: FontSizes.headlineMedium,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: FontSizes.bodySmall,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemCard(QuestionAnswer answer, dynamic checklist) {
    final question = checklist?.questions.firstWhere(
      (q) => q.id == answer.questionId,
      orElse: () => null,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: AppColors.error, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question?.simpleText ?? 'Pergunta',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                if (answer.problemDescription != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    answer.problemDescription!,
                    style: TextStyle(
                      color: AppColors.error.withValues(alpha: 0.8),
                      fontSize: FontSizes.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(QuestionAnswer answer, dynamic checklist) {
    final theme = Theme.of(context);
    final question = checklist?.questions.firstWhere(
      (q) => q.id == answer.questionId,
      orElse: () => null,
    );

    String answerText = '';
    if (answer.boolAnswer != null) {
      answerText = answer.boolAnswer! ? 'Sim' : 'Não';
    } else if (answer.numberAnswer != null) {
      answerText = answer.numberAnswer.toString();
    } else if (answer.selectedChoice != null) {
      answerText = answer.selectedChoice!;
    } else if (answer.textAnswer != null) {
      answerText = answer.textAnswer!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: answer.hasProblem
              ? AppColors.error.withValues(alpha: 0.5)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question?.simpleText ?? 'Pergunta',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  answerText.isNotEmpty ? answerText : '-',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (answer.photoPath != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.photo, color: AppColors.accentBlue, size: 20),
            ),
          if (answer.audioPath != null)
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.secondaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.mic, color: AppColors.secondaryOrange, size: 20),
            ),
        ],
      ),
    );
  }
}
