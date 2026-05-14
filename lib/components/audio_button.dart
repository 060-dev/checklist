import 'package:flutter/material.dart';
import 'package:morro_do_peo/theme.dart';

class AudioPlayButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPlay;

  const AudioPlayButton({
    super.key,
    required this.text,
    this.onPlay,
  });

  @override
  State<AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<AudioPlayButton>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _simulatePlay() {
    setState(() => _isPlaying = true);
    _animationController.repeat();
    widget.onPlay?.call();

    // Simulate audio playback
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isPlaying = false);
        _animationController.stop();
        _animationController.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isPlaying ? null : _simulatePlay,
        icon: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) => Icon(
            _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
            size: 28,
            color: _isPlaying ? AppColors.info : AppColors.primaryGreen,
          ),
        ),
        label: Text(
          _isPlaying ? 'Ouvindo...' : 'Ouvir Pergunta',
          style: TextStyle(
            fontSize: FontSizes.labelLarge,
            fontWeight: FontWeight.w600,
            color: _isPlaying ? AppColors.info : AppColors.primaryGreen,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: _isPlaying ? AppColors.info : AppColors.primaryGreen,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}

class AudioRecordButton extends StatefulWidget {
  final Function(String?)? onRecorded;
  final ValueChanged<bool>? onUploadingChanged;

  const AudioRecordButton({
    super.key,
    this.onRecorded,
    this.onUploadingChanged,
  });

  @override
  State<AudioRecordButton> createState() => _AudioRecordButtonState();
}

class _AudioRecordButtonState extends State<AudioRecordButton> {
  bool _isRecording = false;
  bool _hasRecording = false;
  bool _isUploading = false;
  int _recordingSeconds = 0;

  Future<void> _toggleRecording() async {
    if (_isUploading) return;

    if (_isRecording) {
      setState(() {
        _isRecording = false;
        _isUploading = true;
        _hasRecording = false;
      });
      widget.onUploadingChanged?.call(true);

      // Simula “enviar áudio”
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _hasRecording = true;
      });
      widget.onUploadingChanged?.call(false);
      widget.onRecorded?.call('recording_${DateTime.now().millisecondsSinceEpoch}.wav');
    } else {
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _hasRecording = false;
      });
      _startTimer();
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_isRecording && mounted) {
        setState(() => _recordingSeconds++);
        return true;
      }
      return false;
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final btnColor = _isUploading
        ? AppColors.info
        : (_isRecording ? AppColors.error : AppColors.accentBlue);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: btnColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: btnColor.withValues(alpha: 0.25), width: 2),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: AppButtonSizes.largeHeight,
                child: ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  icon: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        _isUploading ? Icons.cloud_upload : (_isRecording ? Icons.stop : Icons.mic),
                        size: 30,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  label: Text(
                    _isUploading
                        ? 'Enviando áudio...'
                        : (_isRecording
                            ? 'Gravando ${_formatTime(_recordingSeconds)}'
                            : (_hasRecording ? 'Gravar de novo' : 'Gravar áudio')),
                    style: const TextStyle(
                      fontSize: FontSizes.titleMedium,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                ),
              ),
              if (_isRecording) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Microfone ativo',
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
          ),
        ),
        if (_hasRecording) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.success),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Áudio enviado com sucesso!',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: FontSizes.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
