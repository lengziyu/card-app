import 'package:cardfi/features/profile/data/local_guest_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists a complete snapshot under the authenticated user', () async {
    final repository = LocalGuestStateRepository();
    const userId = 'supabase:user-one';
    final submission = LocalSubmission(
      id: 'recommendation-1',
      category: LocalSubmissionCategory.recommendation,
      description: '建议收录这张公开资料完整的卡片',
      link: 'https://example.com/card',
      createdAt: DateTime.utc(2026, 7, 19, 10, 30),
      updatedAt: DateTime.utc(2026, 7, 20, 8),
      status: LocalSubmissionStatus.accepted,
      statusNote: '资料来源符合收录要求。',
      adminReply: '已加入下一批资料更新。',
      repliedAt: DateTime.utc(2026, 7, 20, 8),
    );

    await repository.save(
      userId,
      LocalGuestState(
        addedCardIds: const ['etherfi-core', 'n26-standard'],
        favoriteCardIds: const ['n26-standard'],
        favoriteArticleIds: const ['article-1'],
        recentCardIds: const ['n26-standard', 'etherfi-core'],
        submissions: [submission],
      ),
    );

    final restored = await LocalGuestStateRepository().load(userId);
    expect(restored, isNotNull);
    expect(restored!.addedCardIds, ['etherfi-core', 'n26-standard']);
    expect(restored.favoriteCardIds, ['n26-standard']);
    expect(restored.favoriteArticleIds, ['article-1']);
    expect(restored.recentCardIds, ['n26-standard', 'etherfi-core']);
    expect(
      restored.submissions.single.category,
      LocalSubmissionCategory.recommendation,
    );
    expect(restored.submissions.single.description, '建议收录这张公开资料完整的卡片');
    expect(restored.submissions.single.link, 'https://example.com/card');
    expect(restored.submissions.single.status, LocalSubmissionStatus.accepted);
    expect(restored.submissions.single.statusNote, '资料来源符合收录要求。');
    expect(restored.submissions.single.adminReply, '已加入下一批资料更新。');
  });

  test('keeps local snapshots isolated between users', () async {
    final repository = LocalGuestStateRepository();
    await repository.save(
      'user-a',
      const LocalGuestState(
        addedCardIds: ['etherfi-core'],
        favoriteCardIds: [],
        favoriteArticleIds: [],
        recentCardIds: [],
        submissions: [],
      ),
    );
    await repository.save(
      'user-b',
      const LocalGuestState(
        addedCardIds: ['bybit-card'],
        favoriteCardIds: [],
        favoriteArticleIds: [],
        recentCardIds: [],
        submissions: [],
      ),
    );

    expect((await repository.load('user-a'))!.addedCardIds, ['etherfi-core']);
    expect((await repository.load('user-b'))!.addedCardIds, ['bybit-card']);
  });

  test(
    'ignores a corrupt local snapshot instead of breaking startup',
    () async {
      const userId = 'corrupt-user';
      SharedPreferences.setMockInitialValues({
        LocalGuestStateRepository.storageKeyForUser(userId): '{not-json',
      });

      expect(await LocalGuestStateRepository().load(userId), isNull);
    },
  );

  test('removes the unsafe legacy unscoped snapshot', () async {
    SharedPreferences.setMockInitialValues({
      LocalGuestStateRepository.legacyStorageKey: '{"addedCardIds":[]}',
    });

    await LocalGuestStateRepository().clearLegacyState();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.containsKey(LocalGuestStateRepository.legacyStorageKey),
      isFalse,
    );
  });
}
