import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/badge_widget.dart';
import 'package:mobile/widgets/stat_card.dart';
import 'package:mobile/utils/formatters.dart';

void main() {
  test('Formatters format currency in INR with Rupee symbol', () {
    final formatted = Formatters.formatCurrency(14500);
    expect(formatted, contains('₹'));
    expect(formatted, contains('14,500'));
  });

  test('Formatters parse serial numbers by comma, space, and newline', () {
    const raw = 'HZ-540-01, HZ-540-02\nHZ-540-03  HZ-540-04';
    final serials = Formatters.parseSerials(raw);
    expect(serials.length, 4);
    expect(serials[0], 'HZ-540-01');
    expect(serials[3], 'HZ-540-04');
  });

  testWidgets('BadgeWidget renders text and applies styling', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BadgeWidget(
            text: 'Available',
            type: BadgeType.success,
          ),
        ),
      ),
    );

    expect(find.text('Available'), findsOneWidget);
  });

  testWidgets('StatCard displays label, value and subtext correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Total Available',
            value: '24 Panels',
            subtext: 'In warehouse',
            icon: Icons.inventory,
          ),
        ),
      ),
    );

    expect(find.text('TOTAL AVAILABLE'), findsOneWidget);
    expect(find.text('24 Panels'), findsOneWidget);
    expect(find.text('In warehouse'), findsOneWidget);
  });
}
