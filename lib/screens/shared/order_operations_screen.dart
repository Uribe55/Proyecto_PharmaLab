import 'package:flutter/material.dart';

import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/order_lifecycle_panel.dart';

class OrderOperationsScreen extends StatelessWidget {
  const OrderOperationsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: PharmaService.instance,
    builder: (context, _) {
      final service = PharmaService.instance;
      return Scaffold(
        appBar: const AppPageAppBar(title: 'Cancelaciones e incidencias'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${service.orders.where((o) => o.pendingCancellation != null).length} solicitudes pendientes · ${service.orders.fold(0, (sum, o) => sum + o.incidents.length)} incidencias',
              style: AppText.label,
            ),
            if (service.usesFirebase)
              const Text(
                'Operaciones reales todavía no integradas. Los pedidos de demostración viven en memoria.',
                style: AppText.muted,
              ),
            if (service.orders.isEmpty)
              const Text(
                'Sin pedidos disponibles para esta cuenta.',
                style: AppText.muted,
              ),
            for (final order in service.orders)
              ExpansionTile(
                title: Text(order.number),
                subtitle: Text('${order.pharmacyName} · ${order.status.label}'),
                children: [OrderLifecyclePanel(order: order)],
              ),
          ],
        ),
      );
    },
  );
}
