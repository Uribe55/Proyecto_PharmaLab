import 'package:flutter/material.dart';

import '../../viewmodels/cart_view_model.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/contact_edit_dialog.dart';
import '../../widgets/client_header.dart';
import '../login_screen.dart' show LoginScreen;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _savingProfile = false;

  /// RF-01: el cliente edita nombre, teléfono y dirección.
  Future<void> _editProfile() async {
    final pharmacy = PharmaService.instance.pharmacy;
    final user = PharmaService.instance.currentUser;
    final draft = await showDialog<ContactDraft>(
      context: context,
      builder: (_) => ContactEditDialog(
        initial: (
          name: user?.name ?? pharmacy.responsible,
          phone: pharmacy.phone,
          address: pharmacy.address,
        ),
      ),
    );
    if (draft == null || !mounted) return;

    setState(() => _savingProfile = true);
    final warning = await PharmaService.instance.updateOwnProfile(
      name: draft.name,
      phone: draft.phone,
      address: draft.address,
    );

    if (!mounted) return;
    setState(() => _savingProfile = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          warning ?? 'Datos de contacto actualizados correctamente.',
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Deseas salir de tu cuenta? Tu carrito se vaciará.',
          style: AppText.muted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    PharmaService.instance.logout();
    CartViewModel.instance.clear();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ayuda y soporte'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Si tienes problemas con un pedido, el stock o tus datos de '
              'entrega, comunícate con el equipo comercial de PharmaLab.',
              style: AppText.muted,
            ),
            SizedBox(height: 14),
            _SupportRow(icon: Icons.phone_outlined, text: '+591 4 452-8890'),
            SizedBox(height: 8),
            _SupportRow(
              icon: Icons.mail_outline_rounded,
              text: 'soporte@pharmalab.bo',
            ),
            SizedBox(height: 8),
            _SupportRow(
              icon: Icons.schedule_rounded,
              text: 'Lunes a viernes · 08:00 a 18:00',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAbout() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Acerca de PharmaLab'),
        content: const Text(
          'PharmaLab es el sistema móvil de gestión de pedidos y entregas '
          'para una distribuidora de insumos médicos.\n\n'
          'Versión 1.0.0 · Cochabamba, Bolivia.',
          style: AppText.muted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final pharmacy = PharmaService.instance.pharmacy;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                const ClientTabHeader(title: 'Mi cuenta'),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 78,
                    height: 78,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.07),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      pharmacy.initials,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  pharmacy.responsible,
                  textAlign: TextAlign.center,
                  style: AppText.h1.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Cliente',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'PharmaLab Bolivia · Cuenta de farmacia',
                  textAlign: TextAlign.center,
                  style: AppText.meta,
                ),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Datos de la farmacia', style: AppText.h3),
                      ),
                      TextButton.icon(
                        onPressed: _savingProfile ? null : _editProfile,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: _savingProfile
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Editar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _ProfileInfoRow(
                          icon: Icons.store_outlined,
                          label: 'Nombre comercial',
                          value: pharmacy.commercialName,
                        ),
                        const Divider(),
                        _ProfileInfoRow(
                          icon: Icons.badge_outlined,
                          label: 'NIT',
                          value: pharmacy.nit,
                        ),
                        const Divider(),
                        _ProfileInfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Dirección de entrega',
                          value: pharmacy.address,
                        ),
                        const Divider(),
                        _ProfileInfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Teléfono',
                          value: pharmacy.phone,
                        ),
                        const Divider(),
                        _ProfileInfoRow(
                          icon: Icons.mail_outline_rounded,
                          label: 'Correo electrónico',
                          value: pharmacy.email,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Preferencias', style: AppText.h3),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _notificationsEnabled,
                            onChanged: (value) =>
                                setState(() => _notificationsEnabled = value),
                            activeThumbColor: AppColors.surface,
                            activeTrackColor: AppColors.primary,
                            secondary: const Icon(
                              Icons.notifications_none_rounded,
                              size: 20,
                            ),
                            title: const Text(
                              'Notificaciones de pedidos',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink,
                              ),
                            ),
                            subtitle: const Text(
                              'Avisos de estado y entregas',
                              style: AppText.meta,
                            ),
                          ),
                          const Divider(),
                          SwitchListTile(
                            value:
                                PharmaService
                                    .instance
                                    .currentUser
                                    ?.tieneDeudaVencida ??
                                false,
                            onChanged: (value) {
                              PharmaService.instance.setDebtStatus(
                                hasDebt: value,
                              );
                              setState(() {});
                            },
                            activeThumbColor: AppColors.surface,
                            activeTrackColor: AppColors.danger,
                            secondary: const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 20,
                            ),
                            title: const Text(
                              'Simular deuda vencida',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink,
                              ),
                            ),
                            subtitle: const Text(
                              'Demuestra el bloqueo del checkout (RF-07)',
                              style: AppText.meta,
                            ),
                          ),
                          const Divider(),
                          _ProfileActionRow(
                            icon: Icons.help_outline_rounded,
                            label: 'Ayuda y soporte',
                            onTap: _showHelp,
                          ),
                          const Divider(),
                          _ProfileActionRow(
                            icon: Icons.info_outline_rounded,
                            label: 'Acerca de PharmaLab',
                            onTap: _showAbout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _confirmLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(
                          color: AppColors.danger,
                          width: 0.8,
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Cerrar sesión'),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'PharmaLab · Versión 1.0.0',
                  textAlign: TextAlign.center,
                  style: AppText.meta,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.meta.copyWith(fontSize: 10)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}
