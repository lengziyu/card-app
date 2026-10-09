import 'dart:async';
import 'dart:convert';

import 'package:cardfi/core/network/api_client.dart';
import 'package:cardfi/core/network/api_exception.dart';
import 'package:cardfi/core/theme/app_colors.dart';
import 'package:cardfi/core/theme/app_theme.dart';
import 'package:cardfi/features/ledger/data/ledger_repository.dart';
import 'package:cardfi/features/ledger/domain/ledger_models.dart';
import 'package:cardfi/features/ledger/presentation/ledger_editors.dart';
import 'package:cardfi/features/ledger/presentation/ledger_workspace_page.dart';
import 'package:cardfi/features/pro/domain/bill_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _card = <String, dynamic>{
  'id': 'personal-one',
  'catalogCardId': 'product',
  'productName': 'Example Card',
  'nickname': 'Travel',
  'last4': '0123',
  'form': 'physical',
  'archived': false,
  'revision': 1,
};
final _entry = <String, dynamic>{
  'id': 'entry-one',
  'userCardId': 'personal-one',
  'type': 'expense',
  'state': 'posted',
  'occurredOn': ledgerDay(DateTime.now()),
  'money': {'amount': '10', 'currency': 'USD'},
  'original': null,
  'fee': null,
  'note': '',
  'revision': 1,
  'source': 'manual',
  'cardSnapshot': {
    'productName': 'Example Card',
    'nickname': 'Travel',
    'last4': '0123',
  },
};

LedgerRepository _repository(
  FutureOr<http.Response> Function(http.Request) handler, {
  String? Function()? currentSubject,
  Future<String?> Function()? token,
}) {
  final client = ApiClient(
    client: MockClient((request) async => handler(request)),
    baseUrl: 'https://example.test',
  );
  addTearDown(client.close);
  return LedgerRepository(
    client,
    subject: 'alice',
    currentSubject: currentSubject ?? () => 'alice',
    accessToken: token ?? () async => 'token',
  );
}

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response _read(http.Request request) {
  if (request.url.path.endsWith('/cards')) {
    return _json({
      'cards': [_card],
    });
  }
  if (request.url.path.endsWith('/summary')) {
    return _json({
      'summary': {
        'currencies': [
          {
            'currency': 'USD',
            'spent': '500',
            'refunds': '0',
            'fees': '1',
            'cashback': '2',
            'net': '498',
            'count': 50,
          },
        ],
        'pendingCount': 2,
      },
    });
  }
  if (request.url.path.endsWith('/entries')) {
    return _json({
      'entries': [_entry],
      'nextCursor': null,
    });
  }
  return _json({}, 404);
}

void main() {
  test('bill dates preserve the printed calendar day across timezones', () {
    expect(
      ledgerDay(ledgerDateFromText('2026-10-01T00:30:00+08:00')!),
      '2026-10-01',
    );
    expect(
      ledgerDay(ledgerDateFromText('2026-09-30T23:30:00-07:00')!),
      '2026-09-30',
    );
    for (final input in [
      '2026-02-30',
      '1899-12-31',
      '2200-01-01',
      '',
      'unknown',
    ]) {
      expect(ledgerDateFromText(input), isNull);
    }
  });

  testWidgets('incomplete imports require currency and flag missing date', (
    tester,
  ) async {
    var writes = 0;
    final repo = _repository((request) {
      if (request.method == 'POST') writes++;
      return _read(request);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerEntryEditor(
          repository: repo,
          cards: [PersonalCard.fromJson(_card)],
          importBill: BillRecord.fromJson({
            'id': 'partial',
            'confirmed': {
              'deduction': {'amount': '10'},
            },
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('ledger-currency')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('识别账单缺少有效日期，请核对发生日期。'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('ledger-entry-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('ledger-entry-save')));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('请填写有效币种代码'), findsOneWidget);
  });

  testWidgets('iOS edge gesture returns from editor then workspace', (
    tester,
  ) async {
    final session = ValueNotifier(true);
    addTearDown(session.dispose);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const Scaffold(body: Text('outside')),
      ),
    );
    nav.currentState!.push(
      ledgerRoute(
        nav.currentContext!,
        LedgerWorkspacePage(
          repository: _repository(_read),
          catalog: const [],
          sessionChanges: session,
          sessionValid: () => true,
          onBack: () => nav.currentState!.pop(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger-add-entry')));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(1, 300), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ledger-entry-editor')), findsNothing);
    expect(find.byKey(const Key('ledger-home-page')), findsOneWidget);
    await tester.dragFrom(const Offset(1, 300), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(find.text('outside'), findsOneWidget);
  });

  testWidgets(
    'bill import requires explicit review and preserves source identity',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final repo = _repository((request) {
        if (request.method == 'POST') {
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          return _json({'entry': _entry});
        }
        return _read(request);
      });
      final bill = BillRecord.fromJson({
        'id': 'scanned-one',
        'status': 'draft',
        'revision': 1,
        'confirmed': {
          'cardLast4': '9999',
          'original': {'amount': '100', 'currency': 'CNY'},
          'deduction': {'amount': '14', 'currency': 'USDT'},
        },
        'recognized': {},
        'calculationInputs': {},
        'metrics': {},
        'cardBinding': {'cardId': 'product'},
      });
      await tester.pumpWidget(
        MaterialApp(
          home: LedgerEntryEditor(
            repository: repo,
            cards: [PersonalCard.fromJson(_card)],
            initialCardId: 'personal-one',
            importBill: bill,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('识别的卡片或末四位与所选卡片不同，请核对。'), findsOneWidget);
      final save = find.byKey(const Key('ledger-entry-save'));
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(find.text('请先核对识别结果和卡片归属'), findsOneWidget);
      final review = find.byKey(const Key('ledger-import-review'));
      await tester.ensureVisible(review);
      await tester.pumpAndSettle();
      await tester.tap(review);
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(writes.single['sourceBillId'], 'scanned-one');
      expect(writes.single['state'], 'draft');
      expect(writes.single['userCardId'], 'personal-one');
      expect(writes.single['money'], {'amount': '14', 'currency': 'USDT'});
    },
  );
  test('money validation uses bounded exact decimal strings', () {
    for (final valid in ['0.00000001', '10.20', '999999999999.12345678']) {
      expect(validLedgerAmount(valid), isTrue);
    }
    for (final invalid in [
      '0',
      '-1',
      'NaN',
      '1e3',
      '1.123456789',
      '1000000000000',
      '',
    ]) {
      expect(validLedgerAmount(invalid), isFalse);
    }
    expect(validLedgerAmount('0', allowZero: true), isTrue);
    expect(containsSensitiveLedgerText('Card 4242 4242 4242 4242'), isTrue);
    expect(containsSensitiveLedgerText('４２４２\n４２４２\n４２４２\n４２４２'), isTrue);
    expect(containsSensitiveLedgerText('Tail 0123'), isFalse);
  });

  test(
    'card parsing never displays a full number from a malformed response',
    () {
      expect(
        PersonalCard.fromJson({..._card, 'last4': '4242424242424242'}).last4,
        isEmpty,
      );
      expect(PersonalCard.fromJson(_card).label, 'Travel · •••• 0123');
    },
  );

  test(
    'repository does not send after identity changes while token is loading',
    () async {
      var subject = 'alice', sent = false;
      final token = Completer<String?>();
      final repo = _repository(
        (_) {
          sent = true;
          return _json({});
        },
        currentSubject: () => subject,
        token: () => token.future,
      );
      final future = repo.cards();
      subject = 'bob';
      token.complete('alice-token');
      await expectLater(
        future,
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'SESSION_CHANGED',
          ),
        ),
      );
      expect(sent, isFalse);
    },
  );

  test('late responses are discarded on account switch', () async {
    var subject = 'alice';
    final response = Completer<http.Response>(), sent = Completer<void>();
    final repo = _repository((_) {
      sent.complete();
      return response.future;
    }, currentSubject: () => subject);
    final future = repo.cards();
    await sent.future;
    subject = 'bob';
    response.complete(
      _json({
        'cards': [_card],
      }),
    );
    await expectLater(
      future,
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'SESSION_CHANGED',
        ),
      ),
    );
  });

  test(
    'writes preserve request identity and never submit client owner IDs',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final repo = _repository((request) {
        expect(request.headers['authorization'], 'Bearer token');
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _json({'card': _card});
      });
      final card = PersonalCard.fromJson(_card);
      await repo.saveCard(card.toInput(), requestId: 'retry-key');
      await repo.saveCard(card.toInput(), requestId: 'retry-key');
      expect(bodies[0], bodies[1]);
      expect(bodies[0].containsKey('userId'), isFalse);
      await repo.saveCard(card.toInput(), existing: card, requestId: 'unused');
      expect(bodies.last['expectedRevision'], 1);
      expect(bodies.last.containsKey('requestId'), isFalse);
    },
  );

  test(
    'account deletion tolerates absent service but blocks other cleanup failures',
    () async {
      final absent = _repository((_) => _json({'code': 'NOT_FOUND'}, 404));
      await absent.eraseForAccountDeletion();
      final offline = _repository(
        (_) => _json({'code': 'UNAVAILABLE', 'message': 'unavailable'}, 503),
      );
      await expectLater(
        offline.eraseForAccountDeletion(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  testWidgets('monthly summary uses server totals, not visible entry count', (
    tester,
  ) async {
    final repo = _repository(_read);
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerHomePage(
          repository: repo,
          catalog: const [],
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('500'), findsOneWidget);
    expect(find.text('10'), findsNothing);
    expect(find.byKey(const Key('ledger-add-entry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'full-number paste is rejected rather than keeping its first four digits',
    (tester) async {
      final repo = _repository(_read);
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalCardEditor(
            repository: repo,
            catalog: const [],
            existing: PersonalCard.fromJson(_card),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('personal-card-last4'));
      await tester.enterText(field, '4242424242424242');
      expect(tester.widget<TextFormField>(field).controller!.text, '0123');
      await tester.enterText(field, '5678');
      expect(tester.widget<TextFormField>(field).controller!.text, '5678');
    },
  );

  testWidgets(
    'manual entry submits one confirmed record without fabricated recognition',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final repo = _repository((request) {
        if (request.method == 'POST') {
          writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          return _json({'entry': _entry});
        }
        return _read(request);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: LedgerEntryEditor(
            repository: repo,
            cards: [PersonalCard.fromJson(_card)],
            initialCardId: 'personal-one',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('ledger-amount')), '25.10');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('ledger-entry-save'));
      await tester.scrollUntilVisible(
        save,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(writes.single['money'], {'amount': '25.10', 'currency': 'CNY'});
      expect(writes.single['state'], 'posted');
      expect(writes.single.containsKey('recognized'), isFalse);
      expect(writes.single.containsKey('sourceBillId'), isFalse);
    },
  );

  testWidgets(
    'account switch removes an open editor and private data immediately',
    (tester) async {
      final session = ValueNotifier(true);
      addTearDown(session.dispose);
      final repo = _repository(_read);
      await tester.pumpWidget(
        MaterialApp(
          home: LedgerWorkspacePage(
            repository: repo,
            catalog: const [],
            sessionChanges: session,
            sessionValid: () => session.value,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ledger-add-entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ledger-entry-editor')), findsOneWidget);
      session.value = false;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ledger-entry-editor')), findsNothing);
      expect(find.textContaining('Travel'), findsNothing);
      expect(find.text('账号已切换，请重新打开账本'), findsOneWidget);
    },
  );

  testWidgets('narrow screen and large text keep ledger and editors usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _repository(_read);
    Widget host(Widget child) => MaterialApp(
      builder: (_, child) => MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 800),
          textScaler: TextScaler.linear(1.7),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: child,
    );
    await tester.pumpWidget(
      host(LedgerHomePage(repository: repo, catalog: const [], onBack: () {})),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      host(
        LedgerEntryEditor(
          repository: repo,
          cards: [PersonalCard.fromJson(_card)],
          initialCardId: 'personal-one',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('ledger-entry-save')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('offscreen fields are validated and first error is revealed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var writes = 0;
    final repo = _repository((request) {
      if (request.method == 'POST') writes++;
      return _read(request);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerEntryEditor(
          repository: repo,
          cards: [PersonalCard.fromJson(_card)],
          initialCardId: 'personal-one',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('ledger-entry-save'));
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('请输入有效金额（最多 8 位小数）'), findsOneWidget);
    expect(
      find.byKey(const Key('ledger-amount')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back respects pending save and then returns to ledger', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var writes = 0;
    final repo = _repository((request) {
      if (request.method == 'POST') {
        writes++;
        return response.future;
      }
      return _read(request);
    });
    final session = ValueNotifier(true);
    addTearDown(session.dispose);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: Text('outside')),
      ),
    );
    nav.currentState!.push(
      ledgerRoute(
        nav.currentContext!,
        LedgerWorkspacePage(
          repository: repo,
          catalog: const [],
          sessionChanges: session,
          sessionValid: () => true,
          onBack: () => nav.currentState!.pop(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger-add-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('•••• 0123 · Travel').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ledger-amount')), '12');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('ledger-entry-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('ledger-entry-save')));
    await tester.pump();
    expect(writes, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ledger-entry-editor')), findsOneWidget);
    response.complete(_json({'entry': _entry}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ledger-home-page')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('outside'), findsOneWidget);
  });

  testWidgets('archived cards keep related refunds but cannot start spending', (
    tester,
  ) async {
    final card = PersonalCard.fromJson({..._card, 'archived': true});
    final repo = _repository(
      (request) => request.url.path.endsWith('/cards')
          ? _json({
              'cards': [
                {..._card, 'archived': true},
              ],
            })
          : _read(request),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerHomePage(
          repository: repo,
          catalog: const [],
          initialCard: card,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final add = find.byKey(const Key('ledger-add-entry'));
    await tester.scrollUntilVisible(
      add,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(add).onPressed, isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerEntryEditor(
          repository: repo,
          cards: [card],
          related: LedgerEntry.fromJson(_entry),
          initialType: 'refund',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('•••• 0123 · Travel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('past-month save changes the visible month', (tester) async {
    final queries = <String?>[];
    final repo = _repository((request) {
      if (request.method == 'POST') {
        return _json({
          'entry': {..._entry, 'occurredOn': '2025-03-02'},
        });
      }
      if (request.url.path.endsWith('/entries')) {
        queries.add(request.url.queryParameters['month']);
      }
      return _read(request);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerHomePage(
          repository: repo,
          catalog: const [],
          initialCard: PersonalCard.fromJson(_card),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ledger-add-entry')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ledger-amount')), '10');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('ledger-entry-save')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('ledger-entry-save')));
    await tester.pumpAndSettle();
    expect(queries.last, '2025-03');
    expect(find.text('2025-03'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('card manager and forms fit narrow large text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppColors.configure(brightness);
      addTearDown(() => AppColors.configure(Brightness.light));
      final repo = _repository(_read);
      Widget host(Widget page) => MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            padding: const EdgeInsets.only(bottom: 34),
          ),
          child: child!,
        ),
        home: page,
      );
      for (final page in [
        PersonalCardsPage(repository: repo, catalog: const [], onBack: () {}),
        PersonalCardEditor(
          repository: repo,
          catalog: const [],
          existing: PersonalCard.fromJson(_card),
        ),
        LedgerEntryEditor(
          repository: repo,
          cards: [PersonalCard.fromJson(_card)],
          existing: LedgerEntry.fromJson(_entry),
        ),
      ]) {
        await tester.pumpWidget(host(page));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -2400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
