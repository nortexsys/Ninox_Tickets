import 'package:ninox_client/ninox_client.dart' as ninox;
import 'package:paperdrop_core/paperdrop_core.dart' as core;
import 'package:test/test.dart';

void main() {
  test('the package resolves inside the workspace and sees paperdrop_core', () {
    expect(ninox.packageName, 'ninox_client');
    expect(core.packageName, 'paperdrop_core');
  });
}
