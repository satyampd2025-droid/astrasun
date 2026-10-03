import 'dart:async';

import 'package:atulyaa_mill/api/erpnext_client.dart' show ServerRefused;
import 'package:atulyaa_mill/widgets/pull_to_reload.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen the way the real ones are built: it owns the future and reloads it.
class _Host extends StatefulWidget {
  const _Host(this.load);
  final Future<List<String>> Function() load;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Future<List<String>> _rows = widget.load();

  Future<void> _refresh() async {
    setState(() {
      _rows = widget.load();
    });
    try {
      await _rows;
    } on Object {
      // the list shows why it failed
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('en'),
    home: Scaffold(
      body: PullToReload.list<String>(
        future: _rows,
        onRefresh: _refresh,
        emptyText: 'Nothing here',
        emptyKey: const Key('empty'),
        cards: (context, rows) => [for (final r in rows) Text(r)],
      ),
    ),
  );
}

Future<void> pullDown(WidgetTester tester) async {
  await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1500);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('shows a spinner, then the rows', (tester) async {
    final answer = Completer<List<String>>();
    await tester.pumpWidget(_Host(() => answer.future));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    answer.complete(['first row']);
    await tester.pumpAndSettle();
    expect(find.text('first row'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('pulling down loads again and keeps the rows on screen while it does', (
    tester,
  ) async {
    var calls = 0;
    final second = Completer<List<String>>();
    await tester.pumpWidget(
      _Host(() {
        calls++;
        return calls == 1 ? Future.value(['row one']) : second.future;
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('row one'), findsOneWidget);

    await pullDown(tester);
    expect(calls, 2);
    expect(find.text('row one'), findsOneWidget);

    second.complete(['row two']);
    await tester.pumpAndSettle();
    expect(find.text('row two'), findsOneWidget);
    expect(find.text('row one'), findsNothing);
  });

  testWidgets('an empty list says so and can still be pulled down', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _Host(() async {
        calls++;
        return calls == 1 ? <String>[] : ['arrived'];
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('empty')), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);

    await pullDown(tester);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('arrived'), findsOneWidget);
    expect(find.byKey(const Key('empty')), findsNothing);
  });

  testWidgets('a failed load shows the reason and Try again loads it again', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _Host(() async {
        calls++;
        if (calls == 1) throw ServerRefused('Only the owner can see this');
        return ['allowed now'];
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Only the owner can see this'), findsOneWidget);

    await tester.tap(find.byKey(const Key('try-again')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('allowed now'), findsOneWidget);
    expect(find.byKey(const Key('load-failed')), findsNothing);
  });

  testWidgets('a failed load can also be pulled down to try again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _Host(() async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return ['back online'];
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('load-failed')), findsOneWidget);

    await pullDown(tester);
    await tester.pumpAndSettle();
    expect(find.text('back online'), findsOneWidget);
  });
}
