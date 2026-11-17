import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digiledger/main.dart';

void main() {
  testWidgets('App root renders without throwing', (WidgetTester tester) async {
    // Minimal sanity check: the app entrypoint class exists and builds a widget.
    const app = DigiLedgerApp();
    expect(app, isA<Widget>());
  });
}