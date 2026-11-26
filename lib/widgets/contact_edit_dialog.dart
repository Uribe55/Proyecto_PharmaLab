import 'package:flutter/material.dart';

import '../widgets/app_text_field.dart';

typedef ContactDraft = ({String name, String phone, String address});

/// Los controladores pertenecen al diálogo hasta que termina su animación.
class ContactEditDialog extends StatefulWidget {
  const ContactEditDialog({super.key, required this.initial});
  final ContactDraft initial;
  @override
  State<ContactEditDialog> createState() => _ContactEditDialogState();
}

class _ContactEditDialogState extends State<ContactEditDialog> {
  late final name = TextEditingController(text: widget.initial.name);
  late final phone = TextEditingController(text: widget.initial.phone);
  late final address = TextEditingController(text: widget.initial.address);
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Editar datos de contacto'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            label: 'Nombre completo',
            hint: 'Nombre y apellido',
            controller: name,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Teléfono',
            hint: '+591 700-00000',
            controller: phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Dirección',
            hint: 'Calle, número y ciudad',
            controller: address,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
        },
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop<ContactDraft>((
            name: name.text,
            phone: phone.text,
            address: address.text,
          ));
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
