import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/load_error.dart';
import '../widgets/voice_text_field.dart';

String kg(double v) => '${v.round()} kg';

void _failed(BuildContext context, Object error) {
  final s = S.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        s.saveFailed(error),
        key: const Key('save-failed'),
      ),
    ),
  );
}

/// Gate / purchase: a truck of wheat arrives with the supplier's slip.
class GateEntryScreen extends StatefulWidget {
  const GateEntryScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<GateEntryScreen> createState() => _GateEntryScreenState();
}

class _GateEntryScreenState extends State<GateEntryScreen> {
  final _vehicle = TextEditingController();
  final _slip = TextEditingController();
  final _rate = TextEditingController();
  late final Future<List<Customer>> _suppliers = widget.client.suppliers();
  Customer? _supplier;
  bool _saving = false;

  bool get _ready =>
      _supplier != null &&
      _vehicle.text.trim().isNotEmpty &&
      (double.tryParse(_slip.text) ?? 0) > 0 &&
      (double.tryParse(_rate.text) ?? 0) > 0;

  Future<void> _save() async {
    final s = S.of(context);
    setState(() => _saving = true);
    try {
      final t = await widget.client.gateIn(
        _supplier!,
        _vehicle.text.trim(),
        double.parse(_slip.text),
        double.parse(_rate.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.vehicleNo}: ${s.t('Truck entered')}')),
      );
      setState(() {
        _supplier = null;
        _vehicle.clear();
        _slip.clear();
        _rate.clear();
      });
    } on Exception catch (e) {
      if (mounted) _failed(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Truck entry'))),
      body: FutureBuilder<List<Customer>>(
        future: _suppliers,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<Customer>(
                key: const Key('pick-supplier'),
                initialValue: _supplier,
                isExpanded: true,
                decoration: InputDecoration(labelText: s.t('Supplier')),
                items: [
                  for (final c in snap.data!)
                    DropdownMenuItem(
                      value: c,
                      key: Key('supplier-${c.name}'),
                      child: Text(c.displayName),
                    ),
                ],
                onChanged: (c) => setState(() => _supplier = c),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('vehicle'),
                controller: _vehicle,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: s.t('Vehicle number')),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('slip'),
                controller: _slip,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: s.t('Weight on supplier slip (kg)'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('rate'),
                controller: _rate,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: s.t('Rate per quintal'),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('save-truck'),
                icon: const Icon(Icons.login),
                label: Text(s.t('Enter truck')),
                onPressed: _ready && !_saving ? _save : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shared list screen: loads trucks, rebuilds after each action.
abstract class _TruckListState<T extends StatefulWidget> extends State<T> {
  ErpNextClient get client;
  String get title;
  bool wanted(WheatTruck t);
  Widget card(BuildContext context, WheatTruck t);

  late Future<List<WheatTruck>> trucks = client.wheatTrucks();

  void reload() {
    setState(() {
      trucks = client.wheatTrucks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t(title))),
      body: FutureBuilder<List<WheatTruck>>(
        future: trucks,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return LoadError(snap.error);
          final list = snap.data!.where(wanted).toList();
          if (list.isEmpty) {
            return Center(
              child: Text(
                s.t('No trucks waiting'),
                key: const Key('no-trucks'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final t in list) card(context, t)],
          );
        },
      ),
    );
  }
}

Widget _header(BuildContext context, WheatTruck t) {
  final s = S.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              t.vehicleNo,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Chip(label: Text(s.t(t.status))),
        ],
      ),
      Text(t.supplierName),
      Text('${s.t('Supplier slip')}: ${kg(t.partyWeightKg)}'),
      if (t.grossKg > 0) Text('${s.t('Loaded weight')}: ${kg(t.grossKg)}'),
    ],
  );
}

/// Gate: weigh the loaded truck in, and the empty truck out once released.
class WeighbridgeScreen extends StatefulWidget {
  const WeighbridgeScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<WeighbridgeScreen> createState() => _WeighbridgeState();
}

class _WeighbridgeState extends _TruckListState<WeighbridgeScreen> {
  @override
  ErpNextClient get client => widget.client;
  @override
  String get title => 'Weighbridge';
  @override
  bool wanted(WheatTruck t) => t.status == 'At Gate' || t.status == 'Released';

  Future<void> _weigh(WheatTruck t, String reading) async {
    final s = S.of(context);
    final value = double.tryParse(reading) ?? 0;
    try {
      if (t.status == 'At Gate') {
        await client.weighIn(t, value);
      } else {
        final done = await client.weighOut(t, value);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              done.weightAlert
                  ? s.t('Weight is different from the slip: {0}', [
                      kg(done.weightGapKg),
                    ])
                  : s.t('Wheat received: {0}', [kg(done.netKg)]),
              key: Key(done.weightAlert ? 'weight-alert' : 'received'),
            ),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) _failed(context, e);
    }
    reload();
  }

  @override
  Widget card(BuildContext context, WheatTruck t) {
    final s = S.of(context);
    final controller = TextEditingController();
    final loaded = t.status == 'At Gate';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, t),
            const SizedBox(height: 12),
            TextField(
              key: Key('reading-${t.name}'),
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: s.t(
                  loaded
                      ? 'Loaded truck weight (kg)'
                      : 'Empty truck weight (kg)',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: Key('weigh-${t.name}'),
              icon: const Icon(Icons.scale_outlined),
              label: Text(
                s.t(loaded ? 'Save loaded weight' : 'Unloaded, save'),
              ),
              onPressed: () => _weigh(t, controller.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lab: moisture, foreign matter and broken grain, then release, hold or reject.
class LabScreen extends StatefulWidget {
  const LabScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<LabScreen> createState() => _LabState();
}

class _LabState extends _TruckListState<LabScreen> {
  @override
  ErpNextClient get client => widget.client;
  @override
  String get title => 'Check wheat lot';
  @override
  bool wanted(WheatTruck t) =>
      t.status == 'Weighed In' || t.status == 'On Hold';

  Future<void> _decide(
    WheatTruck t,
    String decision,
    String moisture,
    String foreign,
    String broken,
    String remarks,
  ) async {
    try {
      await client.checkWheat(
        t,
        moisture: double.tryParse(moisture) ?? -1,
        foreignMatter: double.tryParse(foreign) ?? -1,
        broken: double.tryParse(broken) ?? -1,
        decision: decision,
        remarks: remarks,
      );
    } on Exception catch (e) {
      if (mounted) _failed(context, e);
    }
    reload();
  }

  @override
  Widget card(BuildContext context, WheatTruck t) =>
      _LabCard(key: ValueKey(t.name), truck: t, onDecide: _decide);
}

class _LabCard extends StatefulWidget {
  const _LabCard({super.key, required this.truck, required this.onDecide});
  final WheatTruck truck;
  final Future<void> Function(
    WheatTruck,
    String,
    String,
    String,
    String,
    String,
  )
  onDecide;

  @override
  State<_LabCard> createState() => _LabCardState();
}

class _LabCardState extends State<_LabCard> {
  final _moisture = TextEditingController();
  final _foreign = TextEditingController();
  final _broken = TextEditingController();
  final _remarks = TextEditingController();

  Widget _field(String key, TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: Key('$key-${widget.truck.name}'),
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: '%'),
    ),
  );

  void _go(String decision) => widget.onDecide(
    widget.truck,
    decision,
    _moisture.text.trim(),
    _foreign.text.trim(),
    _broken.text.trim(),
    _remarks.text.trim(),
  );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = widget.truck.name;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, widget.truck),
            const SizedBox(height: 12),
            _field('moisture', _moisture, s.t('Moisture')),
            _field('foreign', _foreign, s.t('Foreign matter')),
            _field('broken', _broken, s.t('Broken grain')),
            VoiceTextField(
              key: Key('remarks-$name'),
              controller: _remarks,
              label: s.t('Reason'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: Key('release-$name'),
              icon: const Icon(Icons.check),
              label: Text(s.t('Release')),
              onPressed: () => _go('Release'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('hold-$name'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => _go('Hold'),
                    child: Text(s.t('Hold')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: Key('reject-$name'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: const Color(0xFFB23A30),
                    ),
                    onPressed: () => _go('Reject'),
                    child: Text(s.t('Reject')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
