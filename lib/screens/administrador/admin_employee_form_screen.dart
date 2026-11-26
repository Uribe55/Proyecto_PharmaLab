import 'package:flutter/material.dart';

import '../../models/employee.dart';
import '../../services/employee_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text_field.dart';

/// Alta y edición de empleados EMP###.
class AdminEmployeeFormScreen extends StatefulWidget {
  const AdminEmployeeFormScreen({
    super.key,
    required this.repository,
    this.employee,
  });

  final EmployeeRepository repository;
  final Employee? employee;

  bool get isEditing => employee != null;

  @override
  State<AdminEmployeeFormScreen> createState() =>
      _AdminEmployeeFormScreenState();
}

class _AdminEmployeeFormScreenState extends State<AdminEmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;
  late final TextEditingController _correoController;
  late final TextEditingController _telefonoController;
  final _passwordController = TextEditingController();

  late EmployeePosition _cargo;
  late bool _estado;
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;
  String? _pendingUid;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    _nombreController = TextEditingController(text: employee?.nombre ?? '');
    _apellidoController = TextEditingController(text: employee?.apellido ?? '');
    _correoController = TextEditingController(text: employee?.correo ?? '');
    _telefonoController = TextEditingController(text: employee?.telefono ?? '');
    _cargo = employee?.cargo ?? EmployeePosition.vendedor;
    _estado = employee?.estado ?? true;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  EmployeeDraft get _draft => EmployeeDraft(
    nombre: _nombreController.text,
    apellido: _apellidoController.text,
    correo: _correoController.text,
    telefono: _telefonoController.text,
    cargo: _cargo,
    estado: _estado,
  );

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    if (widget.isEditing) {
      final original = widget.employee!;
      final updated = original.copyWith(
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        telefono: _telefonoController.text.trim(),
        cargo: _cargo,
        estado: _estado,
      );
      final error = await widget.repository.updateEmployee(updated);
      if (!mounted) return;
      setState(() => _saving = false);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Empleado actualizado correctamente.')),
      );
      Navigator.of(context).pop(true);
      return;
    }

    final result = await widget.repository.registerEmployee(
      draft: _draft,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _error = result.message;
      _pendingUid = result.partial ? result.uid : null;
    });
    if (result.partial) {
      await _showPartialDialog(result.uid!);
    }
  }

  Future<void> _showPartialDialog(String uid) async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Cuenta creada, perfil pendiente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La cuenta de Firebase Authentication se creó, pero Firestore '
                'no pudo guardar empleado/EMP### ni usuarios/{uid}. No se '
                'muestra éxito porque el registro está incompleto.',
              ),
              const SizedBox(height: 10),
              SelectableText(
                'UID: $uid',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                'Puedes corregir el error (contador, reglas o conexión) y usar '
                '"Completar perfil" para reintentar sin crear otra cuenta de '
                'Authentication. No repitas el alta con el mismo correo.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Completar perfil'),
          ),
        ],
      ),
    );
    if (retry == true && mounted) {
      await _completePending(uid);
    }
  }

  Future<void> _completePending(String uid) async {
    setState(() => _saving = true);
    final result = await widget.repository.completePendingRegistration(
      uid: uid,
      draft: _draft,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _error = result.message;
      _pendingUid = uid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageAppBar(
        title: widget.isEditing ? 'Editar empleado' : 'Nuevo empleado',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const Text('DOCUMENTO EMP###', style: AppText.eyebrow),
            const SizedBox(height: 7),
            Text(
              widget.isEditing
                  ? widget.employee!.id
                  : 'El ID se asigna al guardar',
              style: AppText.h1.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isEditing
                  ? 'El ID EMP### y el usuario_id no se modifican.'
                  : 'Se creará una cuenta en Authentication y un documento '
                        'empleado/EMP### con el UID vinculado.',
              style: AppText.muted,
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Nombre',
              hint: 'Ej. Carlos',
              controller: _nombreController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Ingresa el nombre.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Apellido',
              hint: 'Ej. Mendoza',
              controller: _apellidoController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Ingresa el apellido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Correo electrónico',
              hint: 'empleado@pharma.com',
              controller: _correoController,
              keyboardType: TextInputType.emailAddress,
              enabled: !widget.isEditing && _pendingUid == null,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final email = (value ?? '').trim();
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Ingresa un correo válido.';
                }
                return null;
              },
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 4),
              Text(
                'El correo pertenece a Firebase Authentication y no se cambia '
                'desde la app.',
                style: AppText.meta.copyWith(fontSize: 9.5),
              ),
            ],
            const SizedBox(height: 14),
            AppTextField(
              label: 'Teléfono',
              hint: '+591 700-00000',
              controller: _telefonoController,
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
              const SizedBox(height: 14),
              AppTextField(
                label: 'Contraseña temporal',
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
              const SizedBox(height: 4),
              Text(
                'No se guarda en Firestore. El empleado podrá cambiarla al '
                'iniciar sesión.',
                style: AppText.meta.copyWith(fontSize: 9.5),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Cargo', style: AppText.h3),
            const SizedBox(height: 9),
            for (final position in EmployeePosition.values) ...[
              _PositionOption(
                position: position,
                selected: _cargo == position,
                onTap: () => setState(() => _cargo = position),
              ),
              if (position != EmployeePosition.values.last)
                const SizedBox(height: 8),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _estado,
                onChanged: (value) => setState(() => _estado = value),
                activeThumbColor: AppColors.surface,
                activeTrackColor: AppColors.primary,
                secondary: const Icon(Icons.toggle_on_outlined, size: 21),
                title: const Text(
                  'Empleado activo',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: const Text(
                  'El estado se replica en usuarios y empleado',
                  style: AppText.meta,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 18),
              _ErrorBox(message: _error!),
              if (_pendingUid != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _completePending(_pendingUid!),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Completar perfil pendiente'),
                ),
              ],
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : (_pendingUid == null
                          ? _save
                          : () => _completePending(_pendingUid!)),
                icon: Icon(
                  widget.isEditing
                      ? Icons.save_outlined
                      : Icons.person_add_alt_1_rounded,
                  size: 18,
                ),
                label: Text(
                  _saving
                      ? 'Guardando…'
                      : widget.isEditing
                      ? 'Guardar cambios'
                      : 'Registrar empleado',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionOption extends StatelessWidget {
  const _PositionOption({
    required this.position,
    required this.selected,
    required this.onTap,
  });

  final EmployeePosition position;
  final bool selected;
  final VoidCallback onTap;

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
                child: Icon(
                  position == EmployeePosition.vendedor
                      ? Icons.point_of_sale_rounded
                      : Icons.local_shipping_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      position == EmployeePosition.vendedor
                          ? 'Revisa, aprueba y asigna pedidos.'
                          : 'Consulta sus entregas y registra incidencias.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              message,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
