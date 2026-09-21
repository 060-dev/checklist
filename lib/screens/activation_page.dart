import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:morro_do_peo/services/tts_service.dart';
import 'package:morro_do_peo/state/app_session.dart';
import 'package:morro_do_peo/theme.dart';

/// First-time activation gate: scan the farm's printed QR code, or type the
/// fallback 5-digit PIN (also used by Google Play reviewers).
class ActivationPage extends StatefulWidget {
  const ActivationPage({super.key});

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _manualMode = false;
  bool _submitting = false;
  String _pin = '';
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String rawInput) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final session = context.read<AppSession>();
    final ok = await session.activateWithCode(rawInput);
    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      unawaited(TtsService.instance.speak('Aplicativo ativado com sucesso.'));
      context.go('/api');
      return;
    }

    HapticFeedback.heavyImpact();
    unawaited(TtsService.instance.speak('Código inválido. Tente novamente.'));
    setState(() {
      _submitting = false;
      _errorText = 'Código inválido. Tente novamente.';
      _pin = '';
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_submitting) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;
    _submit(raw);
  }

  void _onDigit(String digit) {
    if (_submitting || _pin.length >= 5) return;
    setState(() {
      _errorText = null;
      _pin += digit;
    });
    if (_pin.length == 5) _submit(_pin);
  }

  void _onBackspace() {
    if (_submitting || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _toggleManualMode() {
    setState(() {
      _manualMode = !_manualMode;
      _errorText = null;
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ativar aplicativo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _manualMode
                    ? 'Digite o código de 5 dígitos'
                    : 'Aponte a câmera para o QR Code da fazenda',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: _manualMode ? _buildManualEntry() : _buildScanner(),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_errorText != null) ...[
                _ErrorBanner(message: _errorText!),
                const SizedBox(height: AppSpacing.md),
              ],
              TextButton.icon(
                onPressed: _submitting ? null : _toggleManualMode,
                icon: Icon(_manualMode ? Icons.qr_code_scanner : Icons.dialpad),
                label: Text(
                  _manualMode ? 'Usar câmera' : 'Digitar código manualmente',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) =>
                _ScannerError(onUseManual: _toggleManualMode),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
          if (_submitting)
            const ColoredBox(
              color: Colors.black45,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManualEntry() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PinDots(length: _pin.length),
        const SizedBox(height: AppSpacing.xl),
        _Keypad(
          enabled: !_submitting,
          onDigit: _onDigit,
          onBackspace: _onBackspace,
        ),
      ],
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < length;
        return Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? theme.colorScheme.primary : Colors.transparent,
            border: Border.all(color: theme.colorScheme.primary, width: 2),
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  static const List<String> _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '',
    '0',
    '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.3,
        children: _keys.map((key) {
          if (key.isEmpty) return const SizedBox.shrink();
          return _KeypadButton(
            label: key,
            enabled: enabled,
            onTap: () => key == '⌫' ? onBackspace() : onDigit(key),
          );
        }).toList(),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: enabled ? onTap : null,
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.onUseManual});

  final VoidCallback onUseManual;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Não foi possível acessar a câmera.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: onUseManual,
                child: const Text('Digitar código manualmente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
