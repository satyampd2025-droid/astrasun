import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/order_card.dart';
import '../widgets/voice_text_field.dart';

void _snack(BuildContext context, String text, {Key? key}) =>
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text, key: key)));

Widget _number(
  String key,
  TextEditingController c,
  String label,
  VoidCallback changed, {
  String? suffix,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextField(
    key: Key(key),
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => changed(),
    decoration: InputDecoration(labelText: label, suffixText: suffix ?? 'kg'),
  ),
);

double _n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

/// Production: one shift's wheat in and flour out, with live extraction %.
class MillingScreen extends StatefulWidget {
  const MillingScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<MillingScreen> createState() => _MillingScreenState();
}

class _MillingScreenState extends State<MillingScreen> {
  final _wheat = TextEditingController();
  final _water = TextEditingController();
  final _atta = TextEditingController();
  final _maida = TextEditingController();
  final _sooji = TextEditingController();
  final _chokar = TextEditingController();
  late final Future<double> _available = widget.client.wheatAvailable();
  String _shift = 'Morning';
  MillResult? _last;

  double get _flour => _n(_atta) + _n(_maida) + _n(_sooji);
  double get _out => _flour + _n(_chokar);
  double get _extraction => _n(_wheat) > 0 ? _flour / _n(_wheat) * 100 : 0;

  Future<void> _save() async {
    final s = S.of(context);
    try {
      final r = await widget.client.recordBatch(
        shift: _shift,
        wheatKg: _n(_wheat),
        waterKg: _n(_water),
        attaKg: _n(_atta),
        maidaKg: _n(_maida),
        soojiKg: _n(_sooji),
        chokarKg: _n(_chokar),
      );
      if (!mounted) return;
      setState(() => _last = r);
      for (final c in [_wheat, _water, _atta, _maida, _sooji, _chokar]) {
        c.clear();
      }
    } on Exception {
      if (mounted) {
        _snack(
          context,
          s.t('Could not save. Try again.'),
          key: const Key('save-failed'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    void changed() => setState(() {});
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Start milling batch'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<double>(
            future: _available,
            builder: (context, snap) => snap.hasData
                ? Text(
                    '${s.t('Wheat in stock')}: ${snap.data!.round()} kg',
                    key: const Key('wheat-stock'),
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              for (final x in const ['Morning', 'Afternoon', 'Night'])
                ButtonSegment(value: x, label: Text(s.t(x))),
            ],
            selected: {_shift},
            onSelectionChanged: (v) => setState(() => _shift = v.first),
          ),
          const SizedBox(height: 16),
          _number('wheat', _wheat, s.t('Wheat ground'), changed),
          _number('water', _water, s.t('Tempering water'), changed),
          const Divider(),
          _number('atta', _atta, s.t('Atta'), changed),
          _number('maida', _maida, s.t('Maida'), changed),
          _number('sooji', _sooji, s.t('Sooji'), changed),
          _number('chokar', _chokar, s.t('Chokar'), changed),
          if (_n(_wheat) > 0)
            Text(
              '${s.t('Extraction')}: ${_extraction.toStringAsFixed(1)}%  '
              '(${s.t('Total output')}: ${_out.round()} kg)',
              key: const Key('extraction-preview'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('save-batch'),
            icon: const Icon(Icons.precision_manufacturing_outlined),
            label: Text(s.t('Save batch')),
            onPressed: _n(_wheat) > 0 && _out > 0 ? _save : null,
          ),
          if (_last != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _last!.lowYield
                  ? const Color(0xFFFBE9E7)
                  : const Color(0xFFE6F2EC),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _last!.lowYield
                      ? s.t('Low yield: {0}% extraction, loss {1} kg', [
                          _last!.extractionPct.toStringAsFixed(1),
                          _last!.lossKg.round(),
                        ])
                      : s.t('Batch saved: {0}% extraction', [
                          _last!.extractionPct.toStringAsFixed(1),
                        ]),
                  key: Key(_last!.lowYield ? 'low-yield' : 'batch-saved'),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Production: a machine stopped. Machine, minutes, reason (voice works).
class DowntimeScreen extends StatefulWidget {
  const DowntimeScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<DowntimeScreen> createState() => _DowntimeScreenState();
}

class _DowntimeScreenState extends State<DowntimeScreen> {
  final _machine = TextEditingController();
  final _minutes = TextEditingController();
  final _reason = TextEditingController();

  Future<void> _save() async {
    final s = S.of(context);
    try {
      await widget.client.reportDowntime(
        _machine.text.trim(),
        _n(_minutes).round(),
        _reason.text.trim(),
      );
      if (!mounted) return;
      _snack(context, s.t('Downtime saved'));
      _machine.clear();
      _minutes.clear();
      _reason.clear();
    } on Exception {
      if (mounted) {
        _snack(
          context,
          s.t('Could not save. Try again.'),
          key: const Key('save-failed'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Report downtime'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('machine'),
            controller: _machine,
            decoration: InputDecoration(labelText: s.t('Machine')),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('minutes'),
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: s.t('Minutes stopped')),
          ),
          const SizedBox(height: 12),
          VoiceTextField(
            key: const Key('reason'),
            controller: _reason,
            label: s.t('Reason'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('save-downtime'),
            icon: const Icon(Icons.report_problem_outlined),
            label: Text(s.t('Save')),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// Packing: choose a bag size, say how many bags, bulk flour and empty bags are used.
class PackScreen extends StatefulWidget {
  const PackScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<PackScreen> createState() => _PackScreenState();
}

class _PackScreenState extends State<PackScreen> {
  late Future<List<PackSku>> _skus = widget.client.packSkus();

  Future<void> _pack(PackSku sku, String bags) async {
    final s = S.of(context);
    try {
      await widget.client.pack(sku, int.tryParse(bags) ?? 0);
      if (mounted) _snack(context, s.t('Packed: {0} bags', [bags]));
    } on Exception {
      if (mounted) {
        _snack(
          context,
          s.t('Could not save. Try again.'),
          key: const Key('save-failed'),
        );
      }
    }
    setState(() {
      _skus = widget.client.packSkus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Pack bags'))),
      body: FutureBuilder<List<PackSku>>(
        future: _skus,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final k in snap.data!) _PackCard(sku: k, onPack: _pack),
            ],
          );
        },
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  _PackCard({required this.sku, required this.onPack});
  final PackSku sku;
  final void Function(PackSku, String) onPack;
  final _bags = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sku.name, style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${s.t('Packed bags')}: ${sku.packedBags.round()}   '
              '${s.t('Empty bags')}: ${sku.emptyBags.round()}   '
              '${s.t('Bulk flour')}: ${sku.bulkKg.round()} kg',
            ),
            Text(
              s.t('Can pack up to {0} bags', [sku.canPack]),
              key: Key('can-${sku.code}'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: Key('bags-${sku.code}'),
              controller: _bags,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.t('Bags to pack')),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: Key('pack-${sku.code}'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(s.t('Pack')),
              onPressed: () => onPack(sku, _bags.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everyone: wheat, bulk flour and packed bags on hand.
class StockScreen extends StatelessWidget {
  const StockScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Stock'))),
      body: FutureBuilder<List<StockRow>>(
        future: client.stock(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(s.t('Cannot reach the server. Check the internet.')),
            );
          }
          final rows = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final kind in const ['Raw', 'Bulk', 'Packed']) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    s.t(kind),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final r in rows.where((r) => r.kind == kind))
                  Card(
                    color: Colors.white,
                    child: ListTile(
                      key: Key('stock-${r.code}'),
                      title: Text(r.name, style: const TextStyle(fontSize: 18)),
                      trailing: Text(
                        '${_group(r.qty)} ${s.t(r.unit)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _group(double v) => rupees(v).substring(1);
}
