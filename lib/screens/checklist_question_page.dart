import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/data/checklists_repository.dart';
import 'package:morro_do_peo/models/checklist_models.dart';
import 'package:morro_do_peo/services/tts_service.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class ChecklistQuestionPage extends StatefulWidget {
  final String checklistId;

  const ChecklistQuestionPage({super.key, required this.checklistId});

  @override
  State<ChecklistQuestionPage> createState() => _ChecklistQuestionPageState();
}

class _ChecklistQuestionPageState extends State<ChecklistQuestionPage> {
  int _index = 0;
  bool _busy = false;

  ChecklistDefinition? get _checklist =>
      ChecklistsRepository.byId(widget.checklistId);

  List<ChecklistQuestion> _activeQuestionsFor(
      AppSession session, ChecklistDefinition checklist) {
    final answers = session.responsesByQuestionId;
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
        final prev = answers[cond.questionId]?.answer;
        visible = prev == cond.answer;
      }

      if (visible && any.isNotEmpty) {
        visible = false;
        for (final rule in any) {
          final prev = answers[rule.questionId]?.answer;
          if (prev == rule.answer) {
            visible = true;
            break;
          }
        }
      }

      if (visible) out.add(q);
    }
    return out;
  }

  Iterable<String> _hiddenQuestionIdsFor(
      AppSession session, ChecklistDefinition checklist) {
    final activeIds =
        _activeQuestionsFor(session, checklist).map((q) => q.id).toSet();
    return checklist.questions
        .map((q) => q.id)
        .where((id) => !activeIds.contains(id));
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _answer(ChecklistQuestion q, String answer) async {
    if (_busy) return;
    setState(() => _busy = true);

    final session = context.read<AppSession>();
    session.saveAnswer(questionId: q.id, answer: answer);

    final shouldAlert = q.alertWhenAnswer != null &&
        q.alertWhenAnswer == answer &&
        (q.alertMessage ?? '').trim().isNotEmpty;
    session.markAlert(questionId: q.id, generated: shouldAlert);
    if (shouldAlert) {
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (context) => ChecklistAlertSheet(message: q.alertMessage!),
      );
    }

    if (!mounted) return;

    final interstitial = q.interstitial;
    if (interstitial != null && interstitial.whenAnswer == answer) {
      final key = (interstitial.id ?? q.id).trim();
      final alreadyShown = key.isNotEmpty && session.hasShownInterstitial(key);
      if (!alreadyShown) {
        await showModalBottomSheet<void>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          builder: (context) => _ChecklistInterstitialSheet(
              message: interstitial.message,
              buttonLabel: interstitial.buttonLabel),
        );
        if (key.isNotEmpty) session.markInterstitialShown(key);
      }
    }

    if (!mounted) return;

    await _maybeCollectLevel(q: q, answer: answer);
    if (!mounted) return;

    await _maybeCollectAdditionalField(q: q, answer: answer);
    if (!mounted) return;

    await _maybeCollectPhoto(q: q, answer: answer);

    // If this answer changes conditional visibility, clear any responses
    // from now-hidden questions so the final JSON + counts stay consistent.
    final checklist = _checklist;
    if (checklist != null) {
      final hidden = _hiddenQuestionIdsFor(session, checklist);
      session.removeResponses(hidden);
    }

    if (!mounted) return;
    final next = _index + 1;
    final active = (checklist == null)
        ? const <ChecklistQuestion>[]
        : _activeQuestionsFor(session, checklist);
    final total = active.length;

    if (next >= total) {
      setState(() => _busy = false);
      context.go('/observation');
      return;
    }

    setState(() {
      _index = next;
      _busy = false;
    });
  }

  Future<void> _maybeCollectAdditionalField(
      {required ChecklistQuestion q, required String answer}) async {
    final def = q.additionalField;
    if (def == null) return;
    if (answer != def.requiredWhenAnswer) return;

    final value = await showModalBottomSheet<AdditionalFieldValue>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => def.id == 'quantidade_por_curral'
          ? const QuantidadePorCurralSheet()
          : def.id == 'valor_voltagem_observada'
              ? const VoltagemObservadaSheet()
              : def.id == 'area_medida'
                  ? const AreaMedidaSheet()
                  : AdditionalFieldSheet(definition: def),
    );
    if (!mounted) return;
    if (value != null) {
      context
          .read<AppSession>()
          .setAdditionalField(questionId: q.id, fieldId: def.id, value: value);
    }
  }

  Future<void> _maybeCollectPhoto(
      {required ChecklistQuestion q, required String answer}) async {
    final def = q.photoRequest;
    if (def == null) return;
    if (answer != def.requiredWhenAnswer) return;

    final xFile =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (!mounted) return;
    if (xFile == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/${const Uuid().v4()}.jpg';
    await File(xFile.path).copy(destPath);
    if (!mounted) return;
    context.read<AppSession>().setPhoto(
          questionId: q.id,
          photo: ChecklistPhoto(localFile: destPath),
        );
  }

  Future<void> _maybeCollectLevel(
      {required ChecklistQuestion q, required String answer}) async {
    final def = q.level;
    if (def == null) return;
    final requiredWhen = def.requiredWhenAnswer;
    if (requiredWhen != null && requiredWhen != answer) return;
    if (!def.required) return;

    final picked = await showModalBottomSheet<ChecklistLevelOption>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => LevelSelectSheet(definition: def),
    );
    if (!mounted) return;
    if (picked != null) {
      context.read<AppSession>().setLevel(questionId: q.id, level: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final op = session.selectedOperator;
    final pen = session.selectedPen;
    final checklist = _checklist;
    if (checklist == null) {
      return const Scaffold(
          body: Center(child: Text('Checklist não encontrado')));
    }

    final questions = _activeQuestionsFor(session, checklist);
    if (questions.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Sem perguntas para este checklist.')));
    }

    final idx = _index.clamp(0, questions.length - 1);
    final q = questions[idx];

    // Defesa: garante que perguntas "Sim/Não" nunca exibam a opção "OK",
    // mesmo que a fonte de dados esteja desatualizada.
    final effectiveOptions = switch (q.answerType) {
      ChecklistAnswerType.simNao => const ['sim', 'nao'],
      ChecklistAnswerType.simNaoOk => q.options,
      ChecklistAnswerType.simNaoComNivel => const ['sim', 'nao'],
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () {
            if (_busy) return;
            if (_index == 0) {
              context.pop();
              return;
            }
            setState(
                () => _index = (_index - 1).clamp(0, questions.length - 1));
          },
        ),
        title: Text(checklist.title),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderMeta(
                areaTitle: session.selectedArea?.title,
                checklistTitle: checklist.title,
                operatorName: op?.name ?? '',
                penName: checklist.appliesPerPen ? pen?.name : null,
                progressText: 'Pergunta ${idx + 1} de ${questions.length}',
                stageText: q.stage,
                blockText: q.block,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: QuestionCard(text: q.text),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AudioButton(
                      onPressed: () => TtsService.instance.speak(q.audioText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AnswerBar(
                enabled: !_busy,
                options: effectiveOptions,
                onAnswer: (ans) => _answer(q, ans),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderMeta extends StatelessWidget {
  final String? areaTitle;
  final String checklistTitle;
  final String operatorName;
  final String? penName;
  final String progressText;
  final String? stageText;
  final String? blockText;

  const _HeaderMeta({
    required this.areaTitle,
    required this.checklistTitle,
    required this.operatorName,
    required this.progressText,
    this.stageText,
    this.penName,
    this.blockText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = (stageText ?? '').trim();
    final block = (blockText ?? '').trim();
    final pen = (penName ?? '').trim();
    final area = (areaTitle ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (area.isNotEmpty)
          Text(
            area,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800),
          ),
        if (area.isNotEmpty) const SizedBox(height: AppSpacing.xs),
        Text(
          checklistTitle,
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (operatorName.trim().isNotEmpty)
          Text(
            operatorName,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800),
          ),
        if (pen.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            pen,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        if (block.isNotEmpty) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.22)),
              ),
              child: Text(
                'Bloco: $block',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (stage.isNotEmpty) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.22)),
              ),
              child: Text(
                stage,
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          progressText,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class QuestionCard extends StatelessWidget {
  final String text;

  const QuestionCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: primary.withValues(alpha: 0.16), width: 2),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900, height: 1.15),
        ),
      ),
    );
  }
}

class AudioButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AudioButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.28),
              width: 2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl)),
        ),
        icon: Icon(Icons.volume_up, color: theme.colorScheme.primary, size: 28),
        label: Text(
          'Ouvir pergunta',
          style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class AnswerBar extends StatelessWidget {
  final bool enabled;
  final List<String> options;
  final ValueChanged<String> onAnswer;

  const AnswerBar(
      {super.key,
      required this.enabled,
      required this.options,
      required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    for (final opt in options) {
      buttons.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: AnswerButton(
              enabled: enabled,
              answer: opt,
              onPressed: () => onAnswer(opt),
            ),
          ),
        ),
      );
    }

    return Row(children: buttons);
  }
}

class AnswerButton extends StatelessWidget {
  final bool enabled;
  final String answer;
  final VoidCallback onPressed;

  const AnswerButton(
      {super.key,
      required this.enabled,
      required this.answer,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final normalized = answer.toLowerCase();
    final label = normalized == 'sim'
        ? 'Sim'
        : normalized == 'nao'
            ? 'Não'
            : normalized == 'ok'
                ? 'Ok'
                : answer;

    final isOk = normalized == 'ok';
    final background = isOk ? theme.colorScheme.surface : primary;
    final foreground = isOk ? primary : theme.colorScheme.onPrimary;
    final border = isOk
        ? BorderSide(color: primary.withValues(alpha: 0.35), width: 2)
        : BorderSide.none;

    return SizedBox(
      height: 72,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            side: border,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleLarge
              ?.copyWith(color: foreground, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class ChecklistAlertSheet extends StatelessWidget {
  final String message;

  const ChecklistAlertSheet({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.warning_rounded,
                    color: AppColors.warning, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Atenção',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.35)),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 64,
            child: FilledButton(
              onPressed: () => context.pop(),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl)),
              ),
              child: Text('Entendi',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Debug: alerta bloqueante',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _ChecklistInterstitialSheet extends StatelessWidget {
  final String message;
  final String buttonLabel;

  const _ChecklistInterstitialSheet(
      {required this.message, required this.buttonLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900, height: 1.25),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 64,
              child: FilledButton(
                onPressed: () => context.pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl)),
                ),
                child: Text(
                  buttonLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VoltagemObservadaSheet extends StatefulWidget {
  const VoltagemObservadaSheet({super.key});

  @override
  State<VoltagemObservadaSheet> createState() => _VoltagemObservadaSheetState();
}

class _VoltagemObservadaSheetState extends State<VoltagemObservadaSheet> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  bool _recording = false;
  bool _playing = false;
  int _seconds = 0;
  Timer? _timer;
  String? _recordedPath;
  AdditionalFieldValue? _value;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerSub?.cancel();
    _controller.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${const Uuid().v4()}.m4a';
    _timer?.cancel();
    setState(() { _recording = true; _seconds = 0; _recordedPath = null; _value = null; });
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordedPath = path;
      if (path != null) {
        _value = AdditionalFieldValue.audio(RecordedAudio(localFile: path, durationSeconds: _seconds.clamp(1, 3600)));
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _player.stop();
    } else if (_recordedPath != null) {
      await _player.play(DeviceFileSource(_recordedPath!));
    }
  }

  void _confirmText() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    setState(() => _value = AdditionalFieldValue.text(t));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.bolt_rounded,
                    color: theme.colorScheme.primary, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Text('Voltagem observada',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Fale ou informe a voltagem observada.',
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _recording ? Icons.mic : (_recordedPath != null ? Icons.check_circle : Icons.mic_none),
                  color: _recording ? AppColors.error : (_recordedPath != null ? AppColors.success : theme.colorScheme.primary),
                  size: 26,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _recording
                        ? 'Gravando... ${_seconds}s'
                        : (_recordedPath != null ? 'Gravado (${_seconds}s)' : 'Gravar áudio (recomendado)'),
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_recordedPath != null) ...[
            SizedBox(
              height: 64,
              child: OutlinedButton.icon(
                onPressed: _togglePlayback,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.28), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                ),
                icon: Icon(_playing ? Icons.stop : Icons.play_arrow, color: theme.colorScheme.primary, size: 26),
                label: Text(
                  _playing ? 'Parar áudio' : 'Ouvir áudio',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 56,
              child: TextButton.icon(
                onPressed: _startRecording,
                icon: Icon(Icons.refresh, color: theme.colorScheme.primary, size: 22),
                label: Text('Gravar novamente', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                onPressed: _recording ? _stopRecording : _startRecording,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                ),
                icon: Icon(_recording ? Icons.stop : Icons.mic, color: theme.colorScheme.onPrimary, size: 26),
                label: Text(
                  _recording ? 'Parar gravação' : 'Gravar áudio',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            style: theme.textTheme.titleMedium,
            decoration: InputDecoration(
              hintText: 'Exemplo: 8200 volts',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              suffixIcon: IconButton(
                tooltip: 'Confirmar valor',
                onPressed: _confirmText,
                icon: Icon(Icons.check, color: theme.colorScheme.primary),
              ),
            ),
            onSubmitted: (_) => _confirmText(),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 72,
            child: FilledButton.icon(
              onPressed: _value == null ? null : () => context.pop(_value),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                disabledBackgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl)),
              ),
              icon: Icon(Icons.forward,
                  color: theme.colorScheme.onPrimary, size: 26),
              label: Text(
                'Continuar',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdditionalFieldSheet extends StatefulWidget {
  final ChecklistAdditionalFieldDefinition definition;

  const AdditionalFieldSheet({super.key, required this.definition});

  @override
  State<AdditionalFieldSheet> createState() => _AdditionalFieldSheetState();
}

class _AdditionalFieldSheetState extends State<AdditionalFieldSheet> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;
  bool _submitted = false;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${const Uuid().v4()}.m4a';
    _timer?.cancel();
    setState(() { _recording = true; _seconds = 0; });
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() { _recording = false; _submitted = true; });
    if (path != null) {
      context.pop(AdditionalFieldValue.audio(RecordedAudio(localFile: path, durationSeconds: _seconds.clamp(1, 3600))));
    }
  }

  void _submitText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitted = true);
    context.pop(AdditionalFieldValue.text(text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final def = widget.definition;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.edit_note_rounded,
                    color: theme.colorScheme.primary, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Text(def.label,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            def.placeholder,
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            style: theme.textTheme.titleMedium,
            decoration: InputDecoration(
              hintText: def.placeholder,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
            onSubmitted: (_) => _submitText(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: _submitted ? null : _submitText,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl)),
                    ),
                    icon: Icon(Icons.check,
                        color: theme.colorScheme.onPrimary, size: 24),
                    label: Text('Confirmar',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 64,
            child: OutlinedButton.icon(
              onPressed: _submitted
                  ? null
                  : () => context.pop<AdditionalFieldValue?>(null),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.28),
                    width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl)),
              ),
              icon: Icon(Icons.forward,
                  color: theme.colorScheme.primary, size: 24),
              label: Text(
                'Seguir sem detalhar',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Icon(_recording ? Icons.mic : Icons.mic_none,
                    color: theme.colorScheme.primary, size: 26),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _recording
                        ? 'Gravando... ${_seconds}s'
                        : 'Ou gravar áudio',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 72,
            child: OutlinedButton.icon(
              onPressed: _submitted
                  ? null
                  : _recording
                      ? _stopRecording
                      : _startRecording,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.28),
                    width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl)),
              ),
              icon: Icon(_recording ? Icons.stop : Icons.mic,
                  color: theme.colorScheme.primary, size: 28),
              label: Text(
                _recording ? 'Parar gravação' : 'Gravar áudio',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet dedicada para o campo "quantidade por curral" do checklist de Alimentação.
/// Priorizamos áudio (público com baixa familiaridade com digitação).
class QuantidadePorCurralSheet extends StatefulWidget {
  const QuantidadePorCurralSheet({super.key});

  @override
  State<QuantidadePorCurralSheet> createState() =>
      _QuantidadePorCurralSheetState();
}

/// Sheet dedicada para o campo "área medida" do checklist de Montagem de Nova Pastagem.
/// Priorizamos áudio (público com baixa familiaridade com digitação).
class AreaMedidaSheet extends StatefulWidget {
  const AreaMedidaSheet({super.key});

  @override
  State<AreaMedidaSheet> createState() => _AreaMedidaSheetState();
}

class _AreaMedidaSheetState extends State<AreaMedidaSheet> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerSub;
  bool _showText = false;
  bool _recording = false;
  bool _playing = false;
  int _seconds = 0;
  Timer? _timer;
  String? _recordedPath;
  AdditionalFieldValue? _value;

  @override
  void initState() {
    super.initState();
    _playerSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerSub?.cancel();
    _controller.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${const Uuid().v4()}.m4a';
    _timer?.cancel();
    setState(() { _recording = true; _seconds = 0; _recordedPath = null; _value = null; });
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordedPath = path;
      if (path != null) {
        _value = AdditionalFieldValue.audio(RecordedAudio(localFile: path, durationSeconds: _seconds.clamp(1, 3600)));
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _player.stop();
    } else if (_recordedPath != null) {
      await _player.play(DeviceFileSource(_recordedPath!));
    }
  }

  void _submitText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _value = AdditionalFieldValue.text(text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.straighten_rounded,
                    color: theme.colorScheme.primary, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Text('Área medida',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Fale ou informe a área medida.',
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_recordedPath != null) ...[
            SizedBox(
              height: 64,
              child: OutlinedButton.icon(
                onPressed: _togglePlayback,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.28), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                ),
                icon: Icon(_playing ? Icons.stop : Icons.play_arrow, color: theme.colorScheme.primary, size: 26),
                label: Text(
                  _playing ? 'Parar áudio' : 'Ouvir áudio (${_seconds}s)',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 56,
              child: TextButton.icon(
                onPressed: _startRecording,
                icon: Icon(Icons.refresh, color: theme.colorScheme.primary, size: 22),
                label: Text('Gravar novamente', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                onPressed: _recording ? _stopRecording : _startRecording,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                ),
                icon: Icon(_recording ? Icons.stop : Icons.mic, color: theme.colorScheme.onPrimary, size: 28),
                label: Text(
                  _recording ? 'Parar gravação (${_seconds}s)' : 'Gravar áudio',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 64,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showText = !_showText),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.28),
                    width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl)),
              ),
              icon: Icon(
                  _showText
                      ? Icons.keyboard_hide_rounded
                      : Icons.keyboard_rounded,
                  color: theme.colorScheme.primary,
                  size: 24),
              label: Text(
                _showText ? 'Fechar digitação' : 'Digitar área',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (_showText) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'Exemplo: 1,4 hectares',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg)),
                suffixIcon: IconButton(
                  tooltip: 'Confirmar',
                  onPressed: _submitText,
                  icon: Icon(Icons.check, color: theme.colorScheme.primary),
                ),
              ),
              onSubmitted: (_) => _submitText(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 72,
            child: FilledButton.icon(
              onPressed: _value == null ? null : () => context.pop(_value),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                disabledBackgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl)),
              ),
              icon: Icon(Icons.forward,
                  color: theme.colorScheme.onPrimary, size: 26),
              label: Text(
                'Continuar',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantidadePorCurralSheetState extends State<QuantidadePorCurralSheet> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  bool _showText = false;
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission || !mounted) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${const Uuid().v4()}.m4a';
    _timer?.cancel();
    setState(() { _recording = true; _seconds = 0; });
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path != null) {
      context.pop(AdditionalFieldValue.audio(RecordedAudio(localFile: path, durationSeconds: _seconds.clamp(1, 3600))));
    }
  }

  void _submitText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.pop(AdditionalFieldValue.text(text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.scale_rounded,
                    color: theme.colorScheme.primary, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Text('Quantidade por curral',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Fale ou informe a quantidade de trato para cada curral.',
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 72,
            child: FilledButton.icon(
              onPressed: _recording ? _stopRecording : _startRecording,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl)),
              ),
              icon: Icon(_recording ? Icons.stop : Icons.mic,
                  color: theme.colorScheme.onPrimary, size: 28),
              label: Text(
                _recording ? 'Parar gravação (${_seconds}s)' : 'Gravar áudio',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 64,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showText = !_showText),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.28),
                    width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl)),
              ),
              icon: Icon(
                  _showText
                      ? Icons.keyboard_hide_rounded
                      : Icons.keyboard_rounded,
                  color: theme.colorScheme.primary,
                  size: 24),
              label: Text(
                _showText ? 'Fechar digitação' : 'Digitar quantidade',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (_showText) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              textInputAction: TextInputAction.done,
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText:
                    'Exemplo: Curral 1, 300 quilos. Curral 2, 280 quilos.',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 64,
              child: FilledButton.icon(
                onPressed: _submitText,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl)),
                ),
                icon: Icon(Icons.check,
                    color: theme.colorScheme.onPrimary, size: 24),
                label: Text(
                  'Continuar',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LevelSelectSheet extends StatelessWidget {
  final ChecklistLevelDefinition definition;

  const LevelSelectSheet({super.key, required this.definition});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.tune_rounded,
                    color: theme.colorScheme.primary, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Text(definition.label,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...definition.options.map(
            (opt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SizedBox(
                height: 64,
                child: FilledButton(
                  onPressed: () => context.pop(opt),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                  child: Text(
                    opt.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
