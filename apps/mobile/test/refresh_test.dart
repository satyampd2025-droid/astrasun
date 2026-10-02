import 'package:atulyaa_mill/api/demo_client.dart';
import 'package:atulyaa_mill/api/models.dart';
import 'package:atulyaa_mill/screens/approvals_screen.dart';
import 'package:atulyaa_mill/screens/dashboard_screen.dart';
import 'package:atulyaa_mill/screens/deliveries_screen.dart';
import 'package:atulyaa_mill/screens/dues_screen.dart';
import 'package:atulyaa_mill/screens/loading_screen.dart';
import 'package:atulyaa_mill/screens/my_orders_screen.dart';
import 'package:atulyaa_mill/screens/production_screens.dart';
import 'package:atulyaa_mill/screens/reports_screen.dart';
import 'package:atulyaa_mill/screens/trucks_screen.dart';
import 'package:atulyaa_mill/screens/wheat_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The demo server that counts how often each list was asked for.
class _Counting extends DemoClient {
  _Counting() : super('Mill Owner');
  final calls = <String, int>{};

  Future<T> _hit<T>(String name, Future<T> Function() answer) {
    calls[name] = (calls[name] ?? 0) + 1;
    return answer();
  }

  @override
  Future<List<Order>> myOrders() => _hit('orders', super.myOrders);
  @override
  Future<List<Order>> pendingApprovals() => _hit('orders', super.pendingApprovals);
  @override
  Future<List<LoadingTask>> loadingQueue() => _hit('trucks', super.loadingQueue);
  @override
  Future<List<LoadingTask>> trucksToInvoice() => _hit('trucks', super.trucksToInvoice);
  @override
  Future<List<LoadingTask>> trucksToDispatch() => _hit('trucks', super.trucksToDispatch);
  @override
  Future<List<LoadingTask>> myDeliveries() => _hit('trucks', super.myDeliveries);
  @override
  Future<List<Due>> dues() => _hit('dues', super.dues);
  @override
  Future<List<WheatTruck>> wheatTrucks() => _hit('wheat', super.wheatTrucks);
  @override
  Future<List<StockRow>> stock() => _hit('stock', super.stock);
  @override
  Future<List<PackSku>> packSkus() => _hit('skus', super.packSkus);
  @override
  Future<DayView> today() => _hit('day', super.today);
  @override
  Future<Pnl> profitAndLoss() => _hit('pnl', super.profitAndLoss);
}

Future<void> pullDown(WidgetTester tester) async {
  await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1500);
  await tester.pumpAndSettle();
}

void main() {
  // Every screen that lists something, and what it asks the server for
  final screens = <String, (Widget Function(_Counting), String)>{
    'My orders': ((c) => MyOrdersScreen(client: c), 'orders'),
    'Approve orders': ((c) => ApprovalsScreen(client: c), 'orders'),
    'Loading queue': ((c) => LoadingScreen(client: c), 'trucks'),
    'Bills and payments': (
      (c) => TrucksScreen(client: c, mode: TruckMode.invoice),
      'trucks',
    ),
    'Send trucks': (
      (c) => TrucksScreen(client: c, mode: TruckMode.dispatch),
      'trucks',
    ),
    'My deliveries': ((c) => DeliveriesScreen(client: c), 'trucks'),
    'Customer dues': ((c) => DuesScreen(client: c, canCollect: true), 'dues'),
    'Weighbridge': ((c) => WeighbridgeScreen(client: c), 'wheat'),
    'Check wheat lot': ((c) => LabScreen(client: c), 'wheat'),
    'Stock': ((c) => StockScreen(client: c), 'stock'),
    'Pack bags': ((c) => PackScreen(client: c), 'skus'),
    'Today at the mill': ((c) => DashboardScreen(client: c), 'day'),
    'Alerts': ((c) => AlertsScreen(client: c), 'day'),
    'Reports': ((c) => ReportsScreen(client: c), 'pnl'),
  };

  for (final entry in screens.entries) {
    final (build, asked) = entry.value;

    testWidgets('${entry.key}: pull down to load it again', (tester) async {
      final client = _Counting();
      await tester.pumpWidget(
        MaterialApp(locale: const Locale('en'), home: build(client)),
      );
      await tester.pumpAndSettle();
      expect(client.calls[asked], 1);

      await pullDown(tester);
      expect(client.calls[asked], 2);
    });

    testWidgets('${entry.key}: the refresh button loads it again', (tester) async {
      final client = _Counting();
      await tester.pumpWidget(
        MaterialApp(locale: const Locale('en'), home: build(client)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('refresh')));
      await tester.pumpAndSettle();
      expect(client.calls[asked], 2);
    });
  }
}
