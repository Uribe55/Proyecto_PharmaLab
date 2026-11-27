import '../../widgets/staff_filter_chip.dart';
import '../../widgets/admin_scroll_layout.dart';

import 'package:flutter/material.dart';

import '../../widgets/delivery_card.dart';
import '../../widgets/empty_state.dart';
import '../../theme/app_theme.dart';

import '../../data/datasources/firestore_logistics_data_source.dart';
import '../../data/repositories/logistics_repository.dart';
import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../viewmodels/logistics_view_model.dart';
import '../../widgets/app_header.dart';

/// Vista remota sin precios ni acceso a documentos comerciales del repartidor.
class RemoteLogisticsScreen extends StatefulWidget {
  const RemoteLogisticsScreen({
    super.key,
    this.history = false,
    this.order,
    this.repository,
  });
  final LogisticsRepository? repository;
  final bool history;
  final PharmacyOrder? order;
  @override
  State<RemoteLogisticsScreen> createState() => _RemoteLogisticsScreenState();
}

class _RemoteLogisticsScreenState extends State<RemoteLogisticsScreen> {
  late final vm = LogisticsViewModel(
    widget.repository ?? FirestoreLogisticsDataSource(),
  );
  late final deliveries = vm.repository.watchDeliveries();
  late final drivers = vm.repository.watchDrivers();
  String? selected;
  String? _filter;

  Widget get _tabHeader => AppTabHeader(
    title: widget.history
        ? 'Historial de entregas'
        : PharmaService.instance.role.name == 'repartidor'
        ? 'Mis entregas'
        : 'Entregas',
    showLogo: true,
  );

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  Future<void> result(Future<bool> operation) async {
    final ok = await operation;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Operación guardada en Firestore.' : vm.error!),
      ),
    );
    if (ok && widget.order != null) Navigator.of(context).pop();
  }

  Future<void> fail(DeliveryRecord d) async {
    String reason = 'Farmacia cerrada';
    final note = TextEditingController();
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Entrega fallida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: reason,
                isExpanded: true,
                items: [
                  for (final r in [
                    'Farmacia cerrada',
                    'Cliente ausente',
                    'Dirección incorrecta',
                    'Cliente rechazó la entrega',
                    'Otro motivo',
                  ])
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) => update(() => reason = v!),
              ),
              TextField(
                controller: note,
                maxLength: 180,
                decoration: const InputDecoration(labelText: 'Observación'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
    final confirmed = await Navigator.of(context).push(route);
    final observation = note.text;
    await route.completed;
    note.dispose();
    if (confirmed == true && mounted) {
      await result(
        vm.transition(d, 'fallida', reason: reason, note: observation),
      );
    }
  }

  Future<void> startDelivery(DeliveryRecord delivery) async {
    if (vm.busy || delivery.data['from_cache'] == true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar reparto'),
        content: const Text(
          '¿Confirmas que iniciarás el recorrido de esta entrega?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Iniciar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && !vm.busy) {
      await result(vm.transition(delivery, 'en_ruta'));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => Scaffold(
      appBar: widget.order == null
          ? null
          : AppPageAppBar(
              title: widget.order != null
                  ? 'Asignar repartidor'
                  : widget.history
                  ? 'Historial de entregas'
                  : PharmaService.instance.role.name == 'repartidor'
                  ? 'Mis entregas'
                  : 'Entregas',
            ),
      body: SafeArea(
        child: widget.order != null
            ? StreamBuilder<List<LogisticsDriver>>(
                stream: drivers,
                builder: (context, s) {
                  if (s.hasError) {
                    return const Center(
                      child: Text('No se pudieron consultar los repartidores.'),
                    );
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(widget.order!.number),
                      Text(widget.order!.address),
                      if (s.data!.isEmpty)
                        const Text('Sin repartidores activos.'),
                      for (final d in s.data!)
                        ListTile(
                          title: Text(d.name),
                          subtitle: Text(d.id),
                          selected: selected == d.id,
                          onTap: vm.busy
                              ? null
                              : () => setState(() => selected = d.id),
                        ),
                      FilledButton(
                        onPressed: selected == null || vm.busy
                            ? null
                            : () => result(vm.assign(widget.order!, selected!)),
                        child: const Text('Confirmar asignación'),
                      ),
                    ],
                  );
                },
              )
            : StreamBuilder<List<DeliveryRecord>>(
                stream: deliveries,
                builder: (context, s) {
                  if (s.hasError) {
                    return AdminScrollList(
                      headerPrefix: _tabHeader,
                      padding: const EdgeInsets.all(20),
                      children: const [
                        Text(
                          'No se pudieron consultar las entregas. Revisa tu sesión y permisos.',
                        ),
                      ],
                    );
                  }
                  if (!s.hasData) {
                    return AdminScrollList(
                      headerPrefix: _tabHeader,
                      padding: const EdgeInsets.all(20),
                      children: const [
                        Center(child: CircularProgressIndicator()),
                      ],
                    );
                  }
                  final driver =
                      PharmaService.instance.role.name == 'repartidor';
                  final records = deliveryList(
                    s.data!,
                    history: widget.history,
                    filter: _filter,
                  );
                  return AdminScrollList(
                    headerPrefix: _tabHeader,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Text(
                        widget.history ? 'ENTREGAS COMPLETADAS' : 'LOGÍSTICA',
                        style: AppText.eyebrow,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.history
                            ? 'Entregas completadas'
                            : 'Tu operación de entrega',
                        style: AppText.h1,
                      ),
                      const SizedBox(height: 12),
                      if (!widget.history)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final entry in const <String?, String>{
                                null: 'Todas',
                                'asignada': 'Asignadas',
                                'en_ruta': 'En ruta',
                                'entregado': 'Entregadas',
                                'fallida': 'Fallidas',
                              }.entries)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: StaffFilterChip(
                                    label: entry.value,
                                    selected: _filter == entry.key,
                                    onTap: () =>
                                        setState(() => _filter = entry.key),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (records.isEmpty)
                        const EmptyState(
                          icon: Icons.local_shipping_outlined,
                          title: 'Sin entregas en esta vista',
                          description: 'Las entregas aparecerán aquí cuando correspondan a la categoría seleccionada.',
                        ),
                      for (final d in records)
                        DeliveryCard(
                          delivery: d,
                          showDriver: !driver,
                          amount: !driver && d.data['total'] is num
                              ? (d.data['total'] as num).toDouble()
                              : null,
                          actions: [
                            if (!widget.history &&
                                driver &&
                                [
                                  'spark_logistics_v1',
                                  'transactional_logistics_v1',
                                ].contains(d.data['schema_version'])) ...[
                              if (d.data['from_cache'] == true)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Esperando sincronización con el servidor. Las acciones estarán disponibles al confirmar los datos.',
                                  ),
                                ),
                              if (vm.busy) const LinearProgressIndicator(),
                              if (d.state == 'asignada')
                                FilledButton.icon(
                                  icon: const Icon(
                                    Icons.local_shipping_outlined,
                                  ),
                                  onPressed:
                                      vm.busy || d.data['from_cache'] == true
                                      ? null
                                      : () => startDelivery(d),
                                  label: const Text('Iniciar reparto'),
                                ),
                              if (d.state == 'en_ruta') ...[
                                FilledButton(
                                  onPressed:
                                      vm.busy || d.data['from_cache'] == true
                                      ? null
                                      : () => result(
                                          vm.transition(d, 'entregado'),
                                        ),
                                  child: const Text('Confirmar entrega'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      vm.busy || d.data['from_cache'] == true
                                      ? null
                                      : () => fail(d),
                                  child: const Text(
                                    'REGISTRAR ENTREGA FALLIDA',
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                    ],
                  );
                },
              ),
      ),
    ),
  );
}
