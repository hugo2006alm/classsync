import 'package:classsync/core/security/secure_credential_store.dart';
import 'package:classsync/domain/settings/fireflies_connection.dart';
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

  test('named Fireflies source keeps stable identity metadata', () async {
    final validatedAt = DateTime.utc(2026, 9, 14, 9, 42);
    await SecureCredentialStore().writeFirefliesConnections([
      FirefliesConnection(
        id: 'stable-source-id',
        name: 'My Fireflies',
        apiKey: 'api-key',
        firefliesUserId: 'fireflies-user-id',
        accountEmail: 'owner@example.com',
        validatedAt: validatedAt,
      ),
    ]);

    final restored =
        (await SecureCredentialStore().readFirefliesConnections()).single;
    expect(restored.id, 'stable-source-id');
    expect(restored.firefliesUserId, 'fireflies-user-id');
    expect(restored.accountEmail, 'owner@example.com');
    expect(restored.validatedAt, validatedAt);
  });

  test('duplicate Fireflies account identity is rejected', () async {
    await expectLater(
      SecureCredentialStore().writeFirefliesConnections(const [
        FirefliesConnection(
          id: 'source-one',
          name: 'First',
          apiKey: 'key-one',
          firefliesUserId: 'same-user',
        ),
        FirefliesConnection(
          id: 'source-two',
          name: 'Second',
          apiKey: 'key-two',
          firefliesUserId: 'same-user',
        ),
      ]),
      throwsFormatException,
    );
  });

  test('removing one Fireflies source preserves remaining source', () async {
    final store = SecureCredentialStore();
    const remaining = FirefliesConnection(
      id: 'source-two',
      name: 'Second',
      apiKey: 'key-two',
    );
    await store.writeFirefliesConnections(const [
      FirefliesConnection(id: 'source-one', name: 'First', apiKey: 'key-one'),
      remaining,
    ]);

    await store.writeFirefliesConnections(const [remaining]);

    final restored = await store.readFirefliesConnections();
    expect(restored, hasLength(1));
    expect(restored.single.id, 'source-two');
    expect(restored.single.apiKey, 'key-two');
  });
}
