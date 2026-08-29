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
  });

  final Widget child;
  final ValueChanged<String> onBarcodeScanned;
  final FocusNode? focusNode;

  @override
  State<BarcodeScannerListener> createState() => _BarcodeScannerListenerState();
}

class _BarcodeScannerListenerState extends State<BarcodeScannerListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeystroke = DateTime.now();

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
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    // If interval between keystrokes is too large (> 500ms), reset buffer
    if (now.difference(_lastKeystroke).inMilliseconds > 500) {
      _buffer.clear();
    }
    _lastKeystroke = now;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString().trim();
      _buffer.clear();
      if (code.isNotEmpty) {
        widget.onBarcodeScanned(code);
        return true; // handled
      }
      return false;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty && !char.contains(RegExp(r'[\r\n\t]'))) {
      _buffer.write(char);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
