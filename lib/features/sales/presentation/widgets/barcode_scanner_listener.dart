import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Listens for fast keystroke streams sent by handheld Bluetooth/USB
/// barcode scanners in HID keyboard mode (ending with Enter).
class BarcodeScannerListener extends StatefulWidget {
  const BarcodeScannerListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.focusNode,
    this.enabled = true,
  });

  final Widget child;
  final ValueChanged<String> onBarcodeScanned;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  State<BarcodeScannerListener> createState() => _BarcodeScannerListenerState();
}

class _BarcodeScannerListenerState extends State<BarcodeScannerListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeystroke = DateTime.now();
  int _burstCount = 0;

  static const int burstThresholdMs = 50;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!widget.enabled) {
      _buffer.clear();
      _burstCount = 0;
      return false;
    }

    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final elapsed = now.difference(_lastKeystroke).inMilliseconds;
    _lastKeystroke = now;

    // If interval between keystrokes is too large (> 500ms), reset buffer
    if (elapsed > 500) {
      _buffer.clear();
      _burstCount = 0;
    } else if (elapsed <= burstThresholdMs) {
      _burstCount++;
    }

    final isSuffix = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.tab;

    if (isSuffix) {
      final code = _buffer.toString().trim();
      _buffer.clear();
      final wasBurst = _burstCount >= 1;
      _burstCount = 0;
      if (code.isNotEmpty) {
        widget.onBarcodeScanned(code);
        return true; // handled
      }
      return wasBurst;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty && !char.contains(RegExp(r'[\r\n\t]'))) {
      _buffer.write(char);
      // Consume event if rapid keystroke burst is detected from scanner
      if (_burstCount >= 1) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
