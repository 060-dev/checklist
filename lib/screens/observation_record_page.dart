import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/components/responsive_body.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

class ObservationRecordPage extends StatefulWidget {
  const ObservationRecordPage({super.key});

  @override
  State<ObservationRecordPage> createState() => _ObservationRecordPageState();
}

class _ObservationRecordPageState extends State<ObservationRecordPage> {
  bool _recording = false;
  bool _recorded = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _recording = true;
      _recorded = false;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _recording = false;
      _recorded = true;
    });

    final localFile = context.read<AppSession>().buildObservationMockFilename();

    context.read<AppSession>().setObservationMock(
          ObservationAudioMock(recorded: true, localFile: localFile, durationSeconds: _seconds.clamp(3, 60)),
        );
  }

  void _reset() {
    _timer?.cancel();
    context.read<AppSession>().setObservationMock(null);
    setState(() {
      _recording = false;
      _recorded = false;
      _seconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text('Gravar observação'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gravar observação',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Fale o que aconteceu no campo.',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              _RecordingIndicator(recording: _recording, seconds: _seconds),
              const Spacer(),
              if (!_recorded) ...[
                SizedBox(
                  height: 72,
                  child: FilledButton.icon(
                    onPressed: _recording ? _stop : _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    ),
                    icon: Icon(_recording ? Icons.stop : Icons.mic, color: theme.colorScheme.onPrimary, size: 28),
                    label: Text(
                      _recording ? 'Parar gravação' : 'Iniciar gravação',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 64,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Simulação: áudio reproduzido (mock).'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.28), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    ),
                    icon: Icon(Icons.play_arrow, color: theme.colorScheme.primary, size: 28),
                    label: Text('Ouvir áudio', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 64,
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.28), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    ),
                    icon: Icon(Icons.refresh, color: theme.colorScheme.primary, size: 24),
                    label: Text('Gravar novamente', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 72,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/review'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    ),
                    icon: Icon(Icons.arrow_forward, color: theme.colorScheme.onPrimary, size: 24),
                    label: Text('Continuar', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  final bool recording;
  final int seconds;

  const _RecordingIndicator({required this.recording, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = recording ? AppColors.errorLight : theme.colorScheme.surface;
    final border = recording ? AppColors.error.withValues(alpha: 0.35) : theme.colorScheme.primary.withValues(alpha: 0.16);
    final iconColor = recording ? AppColors.error : theme.colorScheme.primary;
    final label = recording ? 'Gravando...' : 'Pronto para gravar';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: border, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(recording ? Icons.mic : Icons.mic_none, color: iconColor, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: AppSpacing.xs),
                Text('${seconds}s', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
