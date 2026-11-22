import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text_field.dart';

/// Alta y edición de usuarios internos (RF-19).
class AdminUserFormScreen extends StatefulWidget {
  const AdminUserFormScreen({super.key, this.user});

  final AppUser? user;

  bool get isEditing => user != null;

  @override
  State<AdminUserFormScreen> createState() => _AdminUserFormScreenState();
}

class _AdminUserFormScreenState extends State<AdminUserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _passwordController = TextEditingController();

  late UserRole _role;
  late bool _active;
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;

  bool get _isClient => widget.user?.role == UserRole.cliente;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _role = user?.role ?? UserRole.vendedor;
    _active = user?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final service = PharmaService.instance;
    String? error;

    if (widget.isEditing) {
      final original = widget.user!;
      error = service.updateUser(
        user: original,
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        role: _isClient ? UserRole.cliente : _role,
      );

      if (error == null) {
        final updated = service.users.firstWhere(
          (user) => user.id == original.id,
          orElse: () => original,
        );
        if (updated.active != _active) {
          error = service.setUserActive(updated, _active);
        }
      }
    } else {
      error = service.createUser(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        role: _role,
        password: _passwordController.text,
      );
    }

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Usuario actualizado correctamente.'
              : 'Usuario creado correctamente.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageAppBar(
        title: widget.isEditing ? 'Editar usuario' : 'Nuevo usuario',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const Text('DATOS DE LA CUENTA', style: AppText.eyebrow),
            const SizedBox(height: 7),
            Text(
              widget.isEditing ? 'Actualiza el usuario.' : 'Crea un usuario.',
              style: AppText.h1.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isEditing
                  ? 'Los cambios se aplican de inmediato en el sistema.'
                  : 'La cuenta podrá iniciar sesión con el correo y la '
                        'contraseña que definas.',
              style: AppText.muted,
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Nombre completo',
              hint: 'Ej. Ana Vargas',
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Ingresa el nombre completo.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Correo electrónico',
              hint: 'nombre@pharmalab.bo',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final email = (value ?? '').trim();
                if (email.isEmpty) return 'Ingresa el correo electrónico.';
                final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                    .hasMatch(email);
                return valid ? null : 'Ingresa un correo válido.';
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Teléfono',
              hint: '+591 700-00000',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: widget.isEditing
                  ? TextInputAction.done
                  : TextInputAction.next,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Ingresa un teléfono de contacto.';
                }
                return null;
              },
            ),
            if (!widget.isEditing) ...[
              const SizedBox(height: 16),
              AppTextField(
                label: 'Contraseña inicial',
                hint: 'Mínimo 6 caracteres',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                    color: AppColors.muted,
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 22),
            const Text('Rol y permisos', style: AppText.h3),
            const SizedBox(height: 9),
            if (_isClient)
              _ClientRoleCard(user: widget.user!)
            else
              for (final role in const [
                UserRole.vendedor,
                UserRole.repartidor,
                UserRole.administrador,
              ]) ...[
                _RoleOption(
                  role: role,
                  selected: _role == role,
                  onTap: () => setState(() => _role = role),
                ),
                if (role != UserRole.administrador) const SizedBox(height: 8),
              ],
            if (widget.isEditing) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  activeThumbColor: AppColors.surface,
                  activeTrackColor: AppColors.primary,
                  secondary: const Icon(Icons.toggle_on_outlined, size: 21),
                  title: const Text(
                    'Cuenta activa',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                  subtitle: const Text(
                    'Si la desactivas, el usuario no podrá iniciar sesión',
                    style: AppText.meta,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: Icon(
                  widget.isEditing
                      ? Icons.save_outlined
                      : Icons.person_add_alt_1_rounded,
                  size: 18,
                ),
                label: Text(
                  widget.isEditing ? 'Guardar cambios' : 'Crear usuario',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientRoleCard extends StatelessWidget {
  const _ClientRoleCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cuenta de cliente farmacia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'El rol de las cuentas de farmacia no se modifica desde este '
                  'panel. Puedes actualizar sus datos de contacto y su estado.',
                  style: AppText.meta.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (role) {
    UserRole.vendedor => Icons.point_of_sale_rounded,
    UserRole.repartidor => Icons.local_shipping_outlined,
    UserRole.administrador => Icons.admin_panel_settings_outlined,
    UserRole.cliente => Icons.storefront_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.mint.withValues(alpha: 0.6)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
            ],
          ),
        ),
      ),
    );
  }
}
