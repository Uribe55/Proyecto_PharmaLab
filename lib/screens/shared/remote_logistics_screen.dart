import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/datasources/firestore_logistics_data_source.dart';
import '../../data/repositories/logistics_repository.dart';
import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../viewmodels/logistics_view_model.dart';
import '../../widgets/app_header.dart';

/// Vista remota sin precios ni acceso a documentos comerciales del repartidor.
class RemoteLogisticsScreen extends StatefulWidget {
  const RemoteLogisticsScreen({super.key, this.history = false, this.order});
  final bool history;
  final PharmacyOrder? order;
  @override
  State<RemoteLogisticsScreen> createState() => _RemoteLogisticsScreenState();
}

class _RemoteLogisticsScreenState extends State<RemoteLogisticsScreen> {
  late final vm = LogisticsViewModel(FirestoreLogisticsDataSource());
  late final deliveries = vm.repository.watchDeliveries();
  late final drivers = vm.repository.watchDrivers();
  String? selected;
  String dateLabel(dynamic value) {
    final date = value is Timestamp ? value.toDate() : null;
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

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
    final confirmed = await showDialog<bool>(
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
    final observation = note.text;
    note.dispose();
    if (confirmed == true && mounted) {
      await result(
        vm.transition(d, 'fallida', reason: reason, note: observation),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => Scaffold(
      appBar: AppPageAppBar(
        title: widget.order != null ? 'Asignar repartidor' : 'Entregas reales',
      ),
      body: widget.order != null
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
                  return const Center(
                    child: Text(
                      'No se pudieron consultar las entregas. Revisa tu sesión y permisos.',
                    ),
                  );
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final driver = PharmaService.instance.role.name == 'repartidor';
                final records = s.data!
                    .where(
                      (d) =>
                          !driver ||
                          widget.history ==
                              [
                                'entregado',
                                'fallida',
                                'Entregado',
                                'Fallida',
                              ].contains(d.data['estado']),
                    )
                    .toList();
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (records.isEmpty)
                      const Text('No hay entregas en esta vista.'),
                    for (final d in records)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${d.data['numero_comercial'] ?? d.id} · ${d.data['pedido_numero'] ?? d.data['id_pedido']}',
                              ),
                              Text('Estado: ${d.data['estado']}'),
                              Text(
                                'Asignación: ${dateLabel(d.data['fecha_creacion'])}',
                              ),
                              for (final line
                                  in d.data['detalles_historicos'] as List? ??
                                      [])
                                Text(
                                  'Detalle ${line['id_detalle_pedido']}: ${line['cantidad_programada']} programadas, ${line['cantidad_entregada']} entregadas',
                                ),
                              Text(
                                '${d.data['farmacia'] ?? ''}\n${d.data['direccion'] ?? 'Dirección histórica no disponible'}\n${d.data['referencia'] ?? ''}',
                              ),
                              Text(
                                '${d.data['contacto'] ?? ''} ${d.data['telefono'] ?? ''}',
                              ),
                              Text(
                                'Producto: ${d.data['producto_nombre'] ?? d.data['producto'] ?? 'Consultar detalle histórico'} · Cantidad: ${d.data['cantidad'] ?? '—'}',
                              ),
                              if (d.data['motivo'] != null)
                                Text(
                                  '${d.data['motivo']} ${d.data['observacion'] ?? ''}',
                                ),
                              if (d.data['fecha_estado'] != null)
                                Text(dateLabel(d.data['fecha_estado'])),
                              if (driver &&
                                  d.data['schema_version'] ==
                                      'spark_logistics_v1') ...[
                                if (d.data['estado'] == 'asignada')
                                  FilledButton(
                                    onPressed: vm.busy
                                        ? null
                                        : () => result(
                                            vm.transition(d, 'en_ruta'),
                                          ),
                                    child: const Text('INICIAR REPARTO'),
                                  ),
                                if (d.data['estado'] == 'en_ruta') ...[
                                  FilledButton(
                                    onPressed: vm.busy
                                        ? null
                                        : () => result(
                                            vm.transition(d, 'entregado'),
                                          ),
                                    child: const Text('MARCAR COMO ENTREGADO'),
                                  ),
                                  OutlinedButton(
                                    onPressed: vm.busy ? null : () => fail(d),
                                    child: const Text(
                                      'REGISTRAR ENTREGA FALLIDA',
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    ),
  );
}
