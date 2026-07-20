import 'package:card_app/features/profile/data/local_guest_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists the complete guest state as one versioned snapshot', () async {
    final repository = LocalGuestStateRepository();
    final submission = LocalSubmission.fromDraft(
      const LocalSubmissionDraft(
        category: LocalSubmissionCategory.recommendation,
        description: '建议收录这张公开资料完整的卡片',
        link: 'https://example.com/card',
      ),
      createdAt: DateTime.utc(2026, 7, 19, 10, 30),
    );

    await repository.save(
      LocalGuestState(
        addedCardIds: const ['etherfi-core', 'n26-standard'],
        favoriteCardIds: const ['n26-standard'],
        favoriteArticleIds: const ['article-1'],
        recentCardIds: const ['n26-standard', 'etherfi-core'],
        submissions: [submission],
      ),
    );

    final restored = await LocalGuestStateRepository().load();
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
  });

  test(
    'ignores a corrupt local snapshot instead of breaking startup',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalGuestStateRepository.storageKey: '{not-json',
      });

      expect(await LocalGuestStateRepository().load(), isNull);
    },
  );
}
