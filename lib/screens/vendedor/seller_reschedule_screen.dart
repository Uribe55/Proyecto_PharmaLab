import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/status_chip.dart';

/// Reprogramación de una entrega fallida (RF-17).
///
/// El vendedor elige una nueva fecha; el pedido vuelve a "Aprobado" para que
/// pueda asignarse a un repartidor en la nueva visita.
class SellerRescheduleScreen extends StatefulWidget {
  const SellerRescheduleScreen({super.key, required this.order});

  final PharmacyOrder order;

  @override
  State<SellerRescheduleScreen> createState() => _SellerRescheduleScreenState();
}

class _SellerRescheduleScreenState extends State<SellerRescheduleScreen> {
  late DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 120)),
      helpText: 'Nueva fecha de entrega',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day, 10);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = PharmaService.instance.rescheduleOrder(widget.order, _date);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo reprogramar. Revisa el estado del pedido.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pedido ${widget.order.number} reprogramado para el '
          '${_formatDate(_date)}. Vuelve a "Aprobado" para asignar repartidor.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      appBar: const AppPageAppBar(title: 'Reprogramar entrega'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const Text('ENTREGA REPROGRAMADA', style: AppText.eyebrow),
          const SizedBox(height: 7),
          const Text('Define una nueva fecha.', style: AppText.h1),
          const SizedBox(height: 6),
          const Text(
            'La entrega no se cancela: el pedido vuelve al panel para que el '
            'vendedor asigne un repartidor en la nueva visita.',
            style: AppText.muted,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.number,
                        style: AppText.h3.copyWith(fontSize: 14),
                      ),
                    ),
                    StatusChip(status: order.status, compact: true),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  order.pharmacyName,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        order.address,
                        style: AppText.meta.copyWith(fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
                if (order.failureReason != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Intento fallido: ${order.failureReason}'
                      '${(order.failureNote ?? '').trim().isEmpty ? '' : ' · ${order.failureNote}'}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Nueva fecha de entrega', style: AppText.h3),
          const SizedBox(height: 10),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.event_outlined,
                        size: 19,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fecha seleccionada',
                            style: AppText.meta,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(_date),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.approvedBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.approvedText,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Al confirmar, el pedido cambia a "Aprobado" y aparece en '
                    'el panel del vendedor para asignar un repartidor.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: AppColors.approvedText,
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
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.event_repeat_rounded, size: 18),
            label: const Text('Confirmar reprogramación'),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final day = date.day.toString().padLeft(2, '0');
    return '$day de ${months[date.month - 1]} de ${date.year}';
  }
}
