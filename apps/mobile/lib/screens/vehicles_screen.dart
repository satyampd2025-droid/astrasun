import 'package:flutter/material.dart';

import '../api/erpnext_client.dart';
import '../api/models.dart';
import '../strings.dart';
import '../widgets/pull_to_reload.dart';

/// Owner and manager: the trucks the mill loads, each with its driver. The
/// warehouse picks one of these when it loads an order, and that driver's
/// phone then shows the order.
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key, required this.client});
  final ErpNextClient client;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  late Future<List<Vehicle>> _vehicles = widget.client.vehicles(all: true);

  void _reload() {
    setState(() {
      _vehicles = widget.client.vehicles(all: true);
    });
  }

  Future<void> _refresh() {
    _reload();
    return settled(_vehicles);
  }

  Future<void> _edit([Vehicle? v]) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final number = TextEditingController(text: v?.vehicleNo);
    final name = TextEditingController(text: v?.driverName);
    final phone = TextEditingController(text: v?.driverPhone);
    final login = TextEditingController(text: v?.driverUser);
    var available = v?.enabled ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(s.t(v == null ? 'Add vehicle' : 'Change vehicle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('vehicle-number'),
                  controller: number,
                  enabled: v == null,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: s.t('Vehicle number')),
                ),
                TextField(
                  key: const Key('driver-name'),
                  controller: name,
                  decoration: InputDecoration(
                    labelText: s.t('Driver or contact person'),
                  ),
                ),
                TextField(
                  key: const Key('driver-phone'),
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: s.t('Driver phone')),
                ),
                TextField(
                  key: const Key('driver-login'),
                  controller: login,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: s.t('Driver app login (optional)'),
                  ),
                ),
                SwitchListTile(
                  key: const Key('vehicle-available'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.t('Available for loading')),
                  value: available,
                  onChanged: (on) => setLocal(() => available = on),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.t('Back')),
            ),
            FilledButton(
              key: const Key('vehicle-save'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.t('Save')),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await widget.client.saveVehicle(
        vehicleNo: number.text.trim(),
        driverName: name.text.trim(),
        driverPhone: phone.text.trim().isEmpty ? null : phone.text.trim(),
        driverUser: login.text.trim().isEmpty ? null : login.text.trim(),
        enabled: available,
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.saveFailed(e))));
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('Vehicles')),
        actions: [RefreshButton(onPressed: _refresh)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-vehicle'),
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: Text(s.t('Add vehicle')),
      ),
      body: PullToReload.list<Vehicle>(
        future: _vehicles,
        onRefresh: _refresh,
        emptyText: s.t('No vehicles yet'),
        emptyKey: const Key('no-vehicles'),
        cards: (context, vehicles) => [
          for (final v in vehicles)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              child: ListTile(
                key: Key('vehicle-${v.vehicleNo}'),
                onTap: () => _edit(v),
                title: Text(
                  v.vehicleNo,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(
                  [
                    v.driverName,
                    if ((v.driverPhone ?? '').isNotEmpty) v.driverPhone!,
                    if (!v.enabled) s.t('Not available'),
                  ].join(' - '),
                ),
                trailing: const Icon(Icons.edit_outlined),
              ),
            ),
        ],
      ),
    );
  }
}
