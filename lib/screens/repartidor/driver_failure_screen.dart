import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';

/// Registro de una entrega fallida con su motivo (RF-17).
class DriverFailureScreen extends StatefulWidget {
  const DriverFailureScreen({super.key, required this.order});

  final PharmacyOrder order;

  static const List<String> reasons = [
    'La farmacia estaba cerrada',
    'No encontré la dirección',
    'El responsable no estaba disponible',
    'La farmacia rechazó el pedido',
    'Problema con el vehículo o la carga',
    'Otro motivo',
  ];

  @override
  State<DriverFailureScreen> createState() => _DriverFailureScreenState();
}

class _DriverFailureScreenState extends State<DriverFailureScreen> {
  final _noteController = TextEditingController();
  String? _reason;
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el motivo de la incidencia.')),
      );
      return;
    }

    setState(() => _submitting = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar incidencia'),
        content: Text(
          'La entrega del pedido ${widget.order.number} quedará como fallida '
          'por “${reason.toLowerCase()}”.',
          style: AppText.muted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Revisar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Registrar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _submitting = false);
      return;
    }

    final sync = SyncService.instance;
    if (sync.isOffline) {
      sync.queueDelivery(
        widget.order,
        delivered: false,
        reason: reason,
        note: _noteController.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incidencia guardada sin conexión. Se sincronizará al reconectar.',
          ),
        ),
      );
    } else {
      PharmaService.instance.markDeliveryFailed(
        widget.order,
        reason: reason,
        note: _noteController.text,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incidencia registrada.')));
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageAppBar(title: 'Entrega fallida'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const Text('INCIDENCIA DE ENTREGA', style: AppText.eyebrow),
          const SizedBox(height: 7),
          const Text('¿Qué ocurrió con la entrega?', style: AppText.h1),
          const SizedBox(height: 6),
          Text(
            'Pedido ${widget.order.number} · ${widget.order.pharmacyName}. '
            'El vendedor y el administrador verán el motivo registrado.',
            style: AppText.muted,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (final reason in DriverFailureScreen.reasons) ...[
                  _ReasonTile(
                    label: reason,
                    selected: _reason == reason,
                    onTap: () => setState(() => _reason = reason),
                  ),
                  if (reason != DriverFailureScreen.reasons.last)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Detalle adicional (opcional)', style: AppText.label),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: 180,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'Ej. La farmacia cerró antes del horario previsto.',
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.dangerBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.danger,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Registra la incidencia solo después de intentar la '
                    'entrega en el domicilio indicado.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.35),
            ),
            icon: const Icon(Icons.report_gmailerrorred_rounded, size: 18),
            label: const Text('Registrar entrega fallida'),
          ),
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : AppColors.surface,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
