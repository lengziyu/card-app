import 'package:cardfi/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only treats a recently created auth identity as a registration', () {
    const user = AuthUser(
      id: 'user-1',
      email: 'member@example.com',
      displayName: 'Member',
      emailVerified: true,
      createdAt: '2026-08-26T10:00:00.000Z',
    );

    expect(
      user.appearsRecentlyRegistered(
        now: DateTime.parse('2026-08-26T10:30:00.000Z'),
      ),
      isTrue,
    );
    expect(
      user.appearsRecentlyRegistered(
        now: DateTime.parse('2026-08-26T13:00:00.000Z'),
      ),
      isFalse,
    );
  });

  test('does not guess registration without an identity creation time', () {
    const user = AuthUser(
      id: 'legacy-user',
      email: null,
      displayName: 'Legacy',
      emailVerified: true,
    );

    expect(user.appearsRecentlyRegistered(), isFalse);
  });
}
