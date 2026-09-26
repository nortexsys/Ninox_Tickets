import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart' as ninox;
import 'package:paperdrop/app/paperdrop_app.dart';
import 'package:paperdrop_core/paperdrop_core.dart' as core;

void main() {
  testWidgets('the shell starts and shows the product name', (tester) async {
    await tester.pumpWidget(const PaperdropApp());
    expect(find.text('Paperdrop for Ninox'), findsOneWidget);
  });

  test('the app sees both workspace packages', () {
    expect(core.packageName, 'paperdrop_core');
    expect(ninox.packageName, 'ninox_client');
  });
}
