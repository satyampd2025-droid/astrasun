import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Shows the phone's print screen for a bill, where the Wi-Fi printer is picked.
/// A variable, so tests can stand in for the print screen.
Future<void> Function(Uint8List pdf, String name) billPrinter =
    (pdf, name) async {
      await Printing.layoutPdf(onLayout: (_) async => pdf, name: name);
    };
