import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_lock_provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _digits = [];
  bool _isSetupMode = false;
  List<String>? _firstEntry;
  bool _confirming = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  static const int _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lock = Provider.of<AppLockProvider>(context, listen: false);
      _isSetupMode = lock.needsSetup;
      if (!_isSetupMode && lock.biometricAvailable) {
        _tryBiometric();
      }
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _tryBiometric() async {
    final lock = Provider.of<AppLockProvider>(context, listen: false);
    await lock.tryBiometric();
  }

  void _onDigit(String d) {
    if (_digits.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() => _digits.add(d));
    if (_digits.length == _pinLength) {
      _submit();
    }
  }

  void _onDelete() {
    if (_digits.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _digits.removeLast());
  }

  Future<void> _submit() async {
    final pin = _digits.join();
    final lock = Provider.of<AppLockProvider>(context, listen: false);

    if (_isSetupMode) {
      if (!_confirming) {
        setState(() {
          _firstEntry = List.from(_digits);
          _digits.clear();
          _confirming = true;
        });
        return;
      }
      // Confirm step
      if (pin == _firstEntry!.join()) {
        await lock.setupPin(pin);
      } else {
        _shake();
        setState(() {
          _digits.clear();
          _firstEntry = null;
          _confirming = false;
        });
        _showSnack('Codes don\'t match. Try again.');
      }
    } else {
      final ok = await lock.unlock(pin);
      if (!ok) {
        _shake();
        setState(() => _digits.clear());
      }
    }
  }

  void _shake() {
    HapticFeedback.heavyImpact();
    _shakeCtrl.forward(from: 0);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lock = Provider.of<AppLockProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Icon + title
              const Icon(Icons.favorite_rounded, size: 48, color: Color(0xFFE94560)),
              const SizedBox(height: 16),
              Text(
                _isSetupMode
                    ? (_confirming ? 'Confirm your code' : 'Set a secret code')
                    : 'Enter your secret code',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              if (_isSetupMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _confirming
                        ? 'Re-enter the 4-digit code'
                        : 'Choose a 4-digit code to protect your chat',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 40),

              // PIN indicators
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) {
                  final offset = _shakeCtrl.isAnimating
                      ? (_shakeAnim.value * ((_shakeCtrl.value * 8).round().isEven ? 1 : -1))
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (i) {
                    final filled = i < _digits.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: filled ? 18 : 16,
                      height: filled ? 18 : 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? const Color(0xFFE94560)
                            : Colors.white.withValues(alpha: 0.25),
                        boxShadow: filled
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFE94560).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),

              if (lock.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    lock.error!,
                    style: const TextStyle(
                      color: Color(0xFFE94560),
                      fontSize: 13,
                    ),
                  ),
                ),

              const Spacer(flex: 2),

              // Number pad
              _NumberPad(onDigit: _onDigit, onDelete: _onDelete),

              const SizedBox(height: 24),

              // Biometric button (unlock mode only)
              if (!_isSetupMode && lock.biometricAvailable)
                TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                  label: const Text(
                    'Use biometric',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;

  const _NumberPad({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) {
              return const SizedBox(width: 80, height: 72);
            }
            if (key == '⌫') {
              return _PadButton(
                label: key,
                isAction: true,
                onTap: onDelete,
              );
            }
            return _PadButton(
              label: key,
              onTap: () => onDigit(key),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _PadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAction;

  const _PadButton({
    required this.label,
    required this.onTap,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 72,
        alignment: Alignment.center,
        child: isAction
            ? Icon(Icons.backspace_outlined, color: Colors.white70, size: 22)
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w300,
                ),
              ),
      ),
    );
  }
}
