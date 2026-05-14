import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:morro_do_peo/models/checklist_area.dart';
import 'package:morro_do_peo/models/checklist_question.dart';
import 'package:morro_do_peo/services/checklist_service.dart';
import 'package:morro_do_peo/services/draft_submission_service.dart';
import 'package:morro_do_peo/theme.dart';
import 'package:morro_do_peo/components/question_progress.dart';
import 'package:morro_do_peo/components/audio_button.dart';
import 'package:morro_do_peo/components/large_action_button.dart';

class QuestionPage extends StatefulWidget {
  final String checklistId;
  final int questionIndex;
  final String? operatorName;
  final String? operatorId;

  const QuestionPage({
    super.key,
    required this.checklistId,
    required this.questionIndex,
    this.operatorName,
    this.operatorId,
  });

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  bool? _yesNoAnswer;
  String? _selectedChoice;
  int? _numberAnswer;
  bool _hasPhoto = false;
  bool _isPhotoUploading = false;
  Uint8List? _photoBytes;
  bool _hasAudio = false;
  bool _isAudioUploading = false;
  String? _observation;
  final DraftSubmissionService _drafts = DraftSubmissionService();

  bool _didTouchNumber = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadDraftForCurrentQuestion());
    });
  }

  @override
  void didUpdateWidget(covariant QuestionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checklistId != widget.checklistId ||
        oldWidget.questionIndex != widget.questionIndex ||
        oldWidget.operatorName != widget.operatorName) {
      // O go_router pode reutilizar o mesmo State ao trocar apenas os parâmetros da rota.
      // Então precisamos limpar o estado transitório (foto/áudio) ao mudar de pergunta.
      _resetTransientState();
      unawaited(_loadDraftForCurrentQuestion());
    }
  }

  void _resetTransientState() {
    if (!mounted) return;
    setState(() {
      _yesNoAnswer = null;
      _selectedChoice = null;
      _numberAnswer = null;
      _didTouchNumber = false;
      _hasPhoto = false;
      _isPhotoUploading = false;
      _photoBytes = null;
      _hasAudio = false;
      _isAudioUploading = false;
      _observation = null;
    });
  }

  Future<void> _loadDraftForCurrentQuestion() async {
    final op = widget.operatorName;
    if (op == null || op.trim().isEmpty) return;
    final checklist = ChecklistService().getChecklistById(widget.checklistId);
    if (checklist == null) return;
    if (widget.questionIndex >= checklist.questions.length) return;
    final q = checklist.questions[widget.questionIndex];

    try {
      final draft = await _drafts.loadDraft(
          checklistId: widget.checklistId, operatorName: op);
      final answers = (draft['answers'] as List?)
              ?.whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList() ??
          <Map<String, dynamic>>[];
      Map<String, dynamic>? current;
      for (final a in answers) {
        if (a['questionId'] == q.id) {
          current = a;
          break;
        }
      }
      if (current == null) return;

      final value = current['value'];
      Uint8List? photo;
      final photoBase64 = current['photoBase64'];
      if (photoBase64 is String && photoBase64.isNotEmpty) {
        try {
          photo = base64Decode(photoBase64);
        } catch (e) {
          debugPrint('Failed to decode saved photo for question=${q.id}: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        if (value is bool) _yesNoAnswer = value;
        if (value is int) _numberAnswer = value;
        if (value is String) _selectedChoice = value;
        _didTouchNumber = (current?['touched'] as bool?) ?? (value is int);
        _observation = (current?['notes'] as String?);
        _photoBytes = photo;
        _hasPhoto = photo != null;
        _hasAudio = (current?['audioRef'] as String?) != null;
      });
    } catch (e) {
      debugPrint('Failed to load draft for question: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checklistService = ChecklistService();
    final checklist = checklistService.getChecklistById(widget.checklistId);

    if (checklist == null ||
        widget.questionIndex >= checklist.questions.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: const Center(child: Text('Pergunta não encontrada')),
      );
    }

    final question = checklist.questions[widget.questionIndex];
    final area = ChecklistArea.getAreas().firstWhere(
      (a) => a.id == checklist.areaId,
      orElse: () => ChecklistArea.getAreas().first,
    );
    final isLastQuestion =
        widget.questionIndex == checklist.questions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(checklist.simpleName),
        backgroundColor: area.color,
        foregroundColor: AppColors.onColorFor(area.color),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => _showExitDialog(context, area.color),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: QuestionProgress(
                currentQuestion: widget.questionIndex + 1,
                totalQuestions: checklist.questions.length,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: area.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        question.icon,
                        size: 40,
                        color: AppColors.emphasisColor(area.color),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Question text
                    Text(
                      question.simpleText,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const SizedBox(height: AppSpacing.xl),
                    // Answer options based on type
                    _buildAnswerWidget(question, area.color),
                    if (_shouldShowRequiredHint(question)) ...[
                      const SizedBox(height: AppSpacing.md),
                      _RequiredHint(color: area.color),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    // Optional photo button
                    if (question.requiresPhoto && !_hasPhoto)
                      _buildPhotoButton(
                          question.photoInstruction ?? 'Tire uma foto'),
                    if (_hasPhoto) _buildPhotoConfirmation(),
                    const SizedBox(height: AppSpacing.md),
                    // Optional observation
                    if (question.answerType != AnswerType.audioNote)
                      _buildObservationSection(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
            // Navigation
            _buildNavigationButtons(
                context, area.color, question, isLastQuestion),
          ],
        ),
      ),
    );
  }

  bool _shouldShowRequiredHint(ChecklistQuestion question) {
    if (!question.isRequired) return false;
    if (_isPhotoUploading || _isAudioUploading) return false;
    return !_isAnswerComplete(question);
  }

  Widget _buildAnswerWidget(ChecklistQuestion question, Color color) {
    switch (question.answerType) {
      case AnswerType.yesNo:
        return _buildYesNoButtons(color);
      case AnswerType.choice:
        return _buildChoiceButtons(question.choices ?? [], color);
      case AnswerType.number:
        return _buildNumberInput(color);
      case AnswerType.photo:
        return const SizedBox.shrink(); // Photo is handled separately
      case AnswerType.audioNote:
        return AudioRecordButton(
          onUploadingChanged: (isUploading) {
            setState(() => _isAudioUploading = isUploading);
          },
          onRecorded: (path) => setState(() => _hasAudio = true),
        );
    }
  }

  Widget _buildYesNoButtons(Color color) {
    return Row(
      children: [
        Expanded(
          child: _AnswerButton(
            label: 'Sim',
            icon: Icons.check_circle,
            color: AppColors.success,
            isSelected: _yesNoAnswer == true,
            onPressed: () => setState(() => _yesNoAnswer = true),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _AnswerButton(
            label: 'Não',
            icon: Icons.cancel,
            color: AppColors.error,
            isSelected: _yesNoAnswer == false,
            onPressed: () => setState(() => _yesNoAnswer = false),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceButtons(List<String> choices, Color color) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: choices.map((choice) {
        final isSelected = _selectedChoice == choice;
        return GestureDetector(
          onTap: () => setState(() => _selectedChoice = choice),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: color,
                width: isSelected ? 3 : 2,
              ),
            ),
            child: Text(
              choice,
              style: TextStyle(
                fontSize: FontSizes.titleMedium,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.onColorFor(color)
                    : AppColors.emphasisColor(color),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumberInput(Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NumberButton(
              icon: Icons.remove,
              color: color,
              onPressed: () {
                final current = _numberAnswer;
                if (current == null) {
                  setState(() {
                    _numberAnswer = 0;
                    _didTouchNumber = true;
                  });
                  return;
                }
                if (current > 0) {
                  setState(() {
                    _numberAnswer = current - 1;
                    _didTouchNumber = true;
                  });
                }
              },
            ),
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: color, width: 2),
              ),
              child: Text(
                _numberAnswer == null ? '—' : '${_numberAnswer!}',
                style: TextStyle(
                  fontSize: FontSizes.displaySmall,
                  fontWeight: FontWeight.w800,
                  color: AppColors.emphasisColor(color),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            _NumberButton(
              icon: Icons.add,
              color: color,
              onPressed: () {
                setState(() {
                  _numberAnswer = (_numberAnswer ?? 0) + 1;
                  _didTouchNumber = true;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoButton(String instruction) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  instruction,
                  style: TextStyle(
                    color: AppColors.info,
                    fontSize: FontSizes.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: AppButtonSizes.largeHeight,
          child: ElevatedButton.icon(
            onPressed: _isPhotoUploading ? null : () => _capturePhoto(),
            icon: Icon(
              _isPhotoUploading ? Icons.cloud_upload : Icons.camera_alt,
              size: 32,
              color: Colors.white,
            ),
            label: const Text(
              'Tirar Foto',
              style: TextStyle(
                fontSize: FontSizes.titleMedium,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isPhotoUploading ? AppColors.info : AppColors.accentBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        ),
        if (_isPhotoUploading) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Enviando foto...',
                style: TextStyle(
                  fontSize: FontSizes.bodyMedium,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoConfirmation() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Foto enviada com sucesso!',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: FontSizes.bodyLarge,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isPhotoUploading ? null : () => _capturePhoto(),
                child: Text(
                  'Tirar outra',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (_photoBytes != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(_photoBytes!, fit: BoxFit.cover),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildObservationSection() {
    if (_hasAudio) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.info),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, color: AppColors.info),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _isAudioUploading ? 'Enviando áudio...' : 'Áudio enviado!',
                style: TextStyle(
                  color: AppColors.info,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.info),
              onPressed: () => setState(() => _hasAudio = false),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _recordObservation(),
      icon: const Icon(Icons.mic, size: 24),
      label: const Text(
        'Falar Observação',
        style: TextStyle(
          fontSize: FontSizes.labelLarge,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context, Color color,
      ChecklistQuestion question, bool isLast) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.questionIndex > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final op = widget.operatorName;
                  final opId = widget.operatorId;
                  final opQuery = (op != null && op.trim().isNotEmpty)
                      ? 'op=${Uri.encodeComponent(op)}'
                      : null;
                  final opIdQuery = (opId != null && opId.trim().isNotEmpty)
                      ? 'opId=${Uri.encodeComponent(opId)}'
                      : null;
                  final query = [
                    if (opQuery != null) opQuery,
                    if (opIdQuery != null) opIdQuery
                  ].join('&');
                  final suffix = query.isNotEmpty ? '?$query' : '';
                  context.go(
                      '/question/${widget.checklistId}/${widget.questionIndex - 1}$suffix');
                },
                icon: const Icon(Icons.arrow_back, size: 24),
                label: const Text(
                  '',
                  style: TextStyle(
                    fontSize: FontSizes.labelLarge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppButtonSizes.mediumHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
          if (widget.questionIndex > 0) const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed:
                  _canProceed(question) ? () => _goNext(context, isLast) : null,
              icon: Icon(
                isLast ? Icons.check : Icons.arrow_forward,
                size: 24,
                color: AppColors.onColorFor(color),
              ),
              label: Text(
                isLast ? 'Revisar' : 'Avançar',
                style: TextStyle(
                  fontSize: FontSizes.titleMedium,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onColorFor(color),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                minimumSize: const Size(0, AppButtonSizes.mediumHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed(ChecklistQuestion question) {
    if (_isPhotoUploading || _isAudioUploading) return false;
    if (!question.isRequired) return true;
    return _isAnswerComplete(question);
  }

  bool _isAnswerComplete(ChecklistQuestion question) {
    switch (question.answerType) {
      case AnswerType.yesNo:
        return _yesNoAnswer != null;
      case AnswerType.choice:
        return _selectedChoice != null && _selectedChoice!.trim().isNotEmpty;
      case AnswerType.number:
        // Para evitar avançar sem interação, exigimos que o operador tenha mexido no número.
        return _didTouchNumber;
      case AnswerType.photo:
        return _hasPhoto;
      case AnswerType.audioNote:
        return _hasAudio;
    }
  }

  void _goNext(BuildContext context, bool isLast) {
    unawaited(_persistCurrentAnswer());
    final op = widget.operatorName;
    final opId = widget.operatorId;
    final opQuery = (op != null && op.trim().isNotEmpty)
        ? 'op=${Uri.encodeComponent(op)}'
        : null;
    final opIdQuery = (opId != null && opId.trim().isNotEmpty)
        ? 'opId=${Uri.encodeComponent(opId)}'
        : null;
    final query = [
      if (opQuery != null) opQuery,
      if (opIdQuery != null) opIdQuery
    ].join('&');
    final suffix = query.isNotEmpty ? '?$query' : '';
    if (isLast) {
      context.go('/review/${widget.checklistId}$suffix');
    } else {
      context.go(
          '/question/${widget.checklistId}/${widget.questionIndex + 1}$suffix');
    }
  }

  Future<void> _persistCurrentAnswer() async {
    final op = widget.operatorName;
    if (op == null || op.trim().isEmpty) return;
    final checklist = ChecklistService().getChecklistById(widget.checklistId);
    if (checklist == null) return;
    if (widget.questionIndex >= checklist.questions.length) return;
    final q = checklist.questions[widget.questionIndex];

    final Map<String, dynamic> answer = <String, dynamic>{};
    switch (q.answerType) {
      case AnswerType.yesNo:
        answer['value'] = _yesNoAnswer;
        break;
      case AnswerType.choice:
        answer['value'] = _selectedChoice;
        break;
      case AnswerType.number:
        answer['value'] = _numberAnswer;
        answer['touched'] = _didTouchNumber;
        break;
      case AnswerType.photo:
        // foto é salva em anexos
        answer['value'] = _hasPhoto;
        break;
      case AnswerType.audioNote:
        answer['value'] = _hasAudio;
        break;
    }
    if (_observation != null && _observation!.trim().isNotEmpty) {
      answer['notes'] = _observation!.trim();
    }

    // IMPORTANT: foto precisa ser por-pergunta.
    // Se o State for reutilizado e o usuário avançar, não podemos carregar a foto antiga
    // em uma pergunta que não pede foto.
    if (q.requiresPhoto && _photoBytes != null) {
      answer['photoBase64'] = base64Encode(_photoBytes!);
      answer['photoMimeType'] = 'image/jpeg';
    }

    if (q.answerType == AnswerType.audioNote && _hasAudio) {
      // áudio é simulado; armazenamos apenas um marcador.
      answer['audioRef'] = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
    }

    await _drafts.upsertAnswer(
      checklistId: widget.checklistId,
      operatorName: op,
      questionId: q.id,
      answer: answer,
    );
  }

  Future<void> _capturePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 82,
        maxWidth: 1600,
      );

      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        _photoBytes = bytes;
        _isPhotoUploading = true;
        _hasPhoto = false;
      });

      // Simular envio
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() {
        _isPhotoUploading = false;
        _hasPhoto = true;
      });
    } catch (e) {
      debugPrint('Failed to capture photo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir a câmera.')),
      );
    }
  }

  void _recordObservation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Gravar Observação',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AudioRecordButton(
              onUploadingChanged: (isUploading) {
                setState(() {
                  _isAudioUploading = isUploading;
                  if (isUploading) _hasAudio = true;
                });
              },
              onRecorded: (path) {
                setState(() => _hasAudio = true);
                context.pop();
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context, Color color) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);

        void exitChecklist() {
          context.pop();
          final op = widget.operatorName;
          final opId = widget.operatorId;
          final opQuery = (op != null && op.trim().isNotEmpty)
              ? 'op=${Uri.encodeComponent(op)}'
              : null;
          final opIdQuery = (opId != null && opId.trim().isNotEmpty)
              ? 'opId=${Uri.encodeComponent(opId)}'
              : null;
          final query = [
            if (opQuery != null) opQuery,
            if (opIdQuery != null) opIdQuery
          ].join('&');
          final suffix = query.isNotEmpty ? '?$query' : '';
          context.go('/areas$suffix');
        }

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: SafeArea(
            top: false,
            bottom: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(Icons.warning_amber_rounded,
                              color: theme.colorScheme.error, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Sair do checklist?',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Seu progresso será perdido.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Primary action first (big, easy to tap)
                    LargeActionButton(
                      label: 'Continuar preenchendo',
                      icon: Icons.arrow_back_rounded,
                      color: theme.colorScheme.primary,
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LargeActionButton(
                      label: 'Sair',
                      icon: Icons.exit_to_app_rounded,
                      color: theme.colorScheme.error,
                      isOutlined: true,
                      onPressed: exitChecklist,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;

  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: color,
            width: isSelected ? 3 : 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: FontSizes.titleLarge,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _NumberButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}

class _RequiredHint extends StatelessWidget {
  final Color color;

  const _RequiredHint({required this.color});

  @override
  Widget build(BuildContext context) {
    final onColor = AppColors.emphasisColor(color);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, color: onColor, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Selecione uma opção para continuar',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: onColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
