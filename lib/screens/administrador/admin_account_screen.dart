import 'package:flutter/material.dart';

import '../shared/employee_account_screen.dart';

class AdminAccountScreen extends StatelessWidget {
  const AdminAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployeeAccountScreen(title: 'Mi cuenta');
  }
}
