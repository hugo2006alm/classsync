import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'Portal passwords preserve significant whitespace across restart',
    () async {
      await SecureCredentialStore().write(
        CredentialKey.portalPassword,
        ' password with spaces ',
      );
      expect(
        await SecureCredentialStore().read(CredentialKey.portalPassword),
        ' password with spaces ',
      );
    },
  );
}
