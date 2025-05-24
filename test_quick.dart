import 'package:native_mdns_scanner/native_mdns_scanner.dart';

void main() {
  print('✅ Package import successful');
  final scanner = NativeMdnsScanner();
  print('✅ Scanner creation successful');
  scanner.dispose();
  print('✅ All tests passed!');
}
