import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digiledger/screens/transactions/transaction_list_screen.dart';

void main() {
  testWidgets(
      'TransactionListScreen renders header, stat cards, filter bar and view toggle without errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TransactionListScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Total Transactions'), findsOneWidget);
    expect(find.text('Total Amount'), findsOneWidget);
    expect(find.text('Total Charges'), findsOneWidget);
    expect(find.text('Total Profit'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    expect(find.text('Card View'), findsOneWidget);
    expect(find.text('Table View'), findsOneWidget);
  });
}