import 'package:flutter/material.dart';

import '../services/pharma_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/pharma_logo.dart';
import 'cliente_farmacia/client_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commercialNameController = TextEditingController();
  final _nitController = TextEditingController();
  final _responsibleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  bool _termsError = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _commercialNameController.dispose();
    _nitController.dispose();
    _responsibleController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _termsError = !_acceptedTerms;
    });

    final formValid = _formKey.currentState!.validate();
    if (!formValid || !_acceptedTerms) return;

    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final error = PharmaService.instance.register(
      commercialName: _commercialNameController.text,
      nit: _nitController.text,
      responsible: _responsibleController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ClientShell()),
      (route) => false,
    );
  }

  Future<void> _showTerms() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Condiciones de uso'),
        content: const SingleChildScrollView(
          child: Text(
            'Esta aplicación se utiliza para realizar pedidos de insumos y '
            'productos farmacéuticos a PharmaLab. Los datos registrados deben '
            'corresponder a una farmacia o laboratorio habilitado.\n\n'
            'Los precios y existencias mostrados son informativos y se '
            'confirman al momento de aprobar cada pedido.',
            style: AppText.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const PharmaLogo(compact: true),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REGISTRO DE CLIENTE',
                            style: AppText.eyebrow,
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'Conectemos tu laboratorio.',
                            style: AppText.h1,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Registra tu farmacia o laboratorio para '
                            'realizar pedidos.',
                            style: AppText.muted,
                          ),
                          const SizedBox(height: 24),
                          AppTextField(
                            label: 'Nombre comercial',
                            hint: 'Nombre comercial',
                            controller: _commercialNameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: _requiredValidator(
                              'Ingresa el nombre comercial.',
                            ),
                          ),
                          const SizedBox(height: 15),
                          AppTextField(
                            label: 'NIT',
                            hint: 'NIT',
                            controller: _nitController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final nit = value?.trim() ?? '';
                              if (nit.isEmpty) return 'Ingresa el NIT.';
                              if (nit.length < 7) {
                                return 'El NIT debe tener al menos 7 dígitos.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          AppTextField(
                            label: 'Nombre del responsable',
                            hint: 'Nombre del responsable',
                            controller: _responsibleController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: _requiredValidator(
                              'Ingresa el nombre del responsable.',
                            ),
                          ),
                          const SizedBox(height: 15),
                          AppTextField(
                            label: 'Teléfono',
                            hint: 'Teléfono',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              if (phone.isEmpty) return 'Ingresa un teléfono.';
                              if (phone.replaceAll(RegExp(r'\D'), '').length < 7) {
                                return 'Ingresa un teléfono válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          AppTextField(
                            label: 'Dirección de entrega',
                            hint: 'Dirección de entrega',
                            controller: _addressController,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            validator: _requiredValidator(
                              'Ingresa la dirección de entrega.',
                            ),
                          ),
                          const SizedBox(height: 15),
                          AppTextField(
                            label: 'Correo electrónico',
                            hint: 'nombre@laboratorio.bo',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) {
                                return 'Ingresa un correo electrónico.';
                              }
                              final valid = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email);
                              if (!valid) {
                                return 'Ingresa un correo electrónico válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          AppTextField(
                            label: 'Contraseña',
                            hint: 'Mínimo 6 caracteres',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 19,
                                color: AppColors.muted,
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.isEmpty) {
                                return 'Crea una contraseña.';
                              }
                              if (password.length < 6) {
                                return 'La contraseña debe tener al menos 6 caracteres.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () => setState(() {
                              _acceptedTerms = !_acceptedTerms;
                              _termsError = false;
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _acceptedTerms,
                                      onChanged: (value) => setState(() {
                                        _acceptedTerms = value ?? false;
                                        _termsError = false;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: GestureDetector(
                                        onTap: _showTerms,
                                        child: Text.rich(
                                          TextSpan(
                                            text: 'Acepto las ',
                                            style: AppText.muted.copyWith(
                                              fontSize: 11.5,
                                            ),
                                            children: const [
                                              TextSpan(
                                                text: 'condiciones de uso',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_termsError) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Debes aceptar las condiciones de uso.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
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
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text('Crear cuenta'),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Ya tengo una cuenta'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String? Function(String?) _requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }
}
