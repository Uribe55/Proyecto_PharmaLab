import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/contact_edit_dialog.dart';
import '../../widgets/user_avatar.dart';
import '../login_screen.dart';

/// Pantalla de cuenta común para vendedor, repartidor y administrador.
///
/// [extraSections] permite añadir bloques propios de cada rol, por ejemplo la
/// configuración de trabajo sin conexión del repartidor (RF-18).
class EmployeeAccountScreen extends StatefulWidget {
  const EmployeeAccountScreen({
    super.key,
    required this.title,
    this.extraSections = const [],
  });

  final String title;
  final List<Widget> extraSections;

  @override
  State<EmployeeAccountScreen> createState() => _EmployeeAccountScreenState();
}

class _EmployeeAccountScreenState extends State<EmployeeAccountScreen> {
  bool _savingProfile = false;

  /// RF-01: el repartidor edita nombre, teléfono y dirección.
  Future<void> _editProfile(AppUser user) async {
    final draft = await showDialog<ContactDraft>(
      context: context,
      builder: (_) => ContactEditDialog(
        initial: (name: user.name, phone: user.phone, address: user.address),
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
      SnackBar(content: Text(warning ?? 'Datos de contacto actualizados.')),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Deseas salir de tu cuenta de PharmaLab?',
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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final user = PharmaService.instance.currentUser;
        if (user == null) return const SizedBox.shrink();

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                AppTabHeader(title: widget.title),
                const SizedBox(height: 6),
                Center(child: UserAvatar(size: 78, user: user)),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: AppText.h1.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Center(child: _RoleBadge(role: user.role)),
                const SizedBox(height: 7),
                Text(
                  'PharmaLab Bolivia · Cuenta de ${user.role.label.toLowerCase()}',
                  textAlign: TextAlign.center,
                  style: AppText.meta,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Datos de la cuenta', style: AppText.h3),
                      ),
                      if (user.role == UserRole.repartidor)
                        TextButton.icon(
                          onPressed: _savingProfile
                              ? null
                              : () => _editProfile(user),
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
                _Card(
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Correo electrónico',
                        value: user.email,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: user.phone.trim().isEmpty
                            ? 'Sin teléfono registrado'
                            : user.phone,
                      ),
                      if (user.address.trim().isNotEmpty) ...[
                        const Divider(),
                        _InfoRow(
                          icon: Icons.location_on_outlined,
                          label: 'Dirección',
                          value: user.address,
                        ),
                      ],
                      const Divider(),
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Rol asignado',
                        value: user.role.label,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.verified_user_outlined,
                        label: 'Estado',
                        value: user.active
                            ? 'Cuenta activa'
                            : 'Cuenta desactivada',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Permisos de tu rol'),
                const SizedBox(height: 10),
                _Card(
                  child: Column(
                    children: [
                      for (
                        var i = 0;
                        i < user.role.permissions.length;
                        i++
                      ) ...[
                        _PermissionRow(text: user.role.permissions[i]),
                        if (i < user.role.permissions.length - 1)
                          const Divider(),
                      ],
                    ],
                  ),
                ),
                for (final section in widget.extraSections) ...[
                  const SizedBox(height: 24),
                  section,
                ],
                const SizedBox(height: 26),
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

/// Sección de contenido con título para las pantallas de cuenta.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        const SizedBox(height: 10),
        _Card(child: child),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: AppText.h3),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  IconData get _icon => switch (role) {
    UserRole.cliente => Icons.storefront_outlined,
    UserRole.vendedor => Icons.point_of_sale_rounded,
    UserRole.repartidor => Icons.local_shipping_outlined,
    UserRole.administrador => Icons.admin_panel_settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            role.label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
