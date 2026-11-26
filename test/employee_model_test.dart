import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_movil/models/employee.dart';
import 'package:proyecto_final_movil/services/employee_repository.dart';

void main() {
  group('EmployeeRepository.code', () {
    test('rellena con ceros hasta tres dígitos', () {
      expect(EmployeeRepository.code(1), 'EMP001');
      expect(EmployeeRepository.code(3), 'EMP003');
      expect(EmployeeRepository.code(4), 'EMP004');
      expect(EmployeeRepository.code(9), 'EMP009');
      expect(EmployeeRepository.code(10), 'EMP010');
      expect(EmployeeRepository.code(99), 'EMP099');
      expect(EmployeeRepository.code(100), 'EMP100');
      expect(EmployeeRepository.code(1000), 'EMP1000');
    });
  });

  group('EmployeeCounter', () {
    test('calcula el siguiente EMP### y valida coherencia', () {
      const counter = EmployeeCounter(ultimoNumero: 3, ultimoId: 'EMP003');
      expect(counter.siguienteNumero, 4);
      expect(counter.siguienteId, 'EMP004');
      expect(counter.isConsistent, isTrue);

      const broken = EmployeeCounter(ultimoNumero: 3, ultimoId: 'EMP009');
      expect(broken.isConsistent, isFalse);
    });
  });

  group('Employee.fromMap', () {
    test('lee un documento empleado/EMP### existente', () {
      final employee = Employee.fromMap('EMP004', {
        'nombre': 'Ana',
        'apellido': 'Vargas',
        'cargo': 'Vendedor',
        'telefono': '+591 700-00000',
        'estado': true,
        'usuario_id': 'uid-ana',
        'fecha_ingreso': DateTime(2026, 1, 2),
      }, correo: 'ana@pharma.com');

      expect(employee, isNotNull);
      expect(employee!.id, 'EMP004');
      expect(employee.nombreCompleto, 'Ana Vargas');
      expect(employee.iniciales, 'AV');
      expect(employee.cargo, EmployeePosition.vendedor);
      expect(employee.usuarioId, 'uid-ana');
      expect(employee.correo, 'ana@pharma.com');
      expect(employee.estado, isTrue);
      expect(employee.fechaIngreso, DateTime(2026, 1, 2));
    });

    test('ignora documentos sin cargo válido o sin usuario_id', () {
      expect(
        Employee.fromMap('EMP900', {
          'nombre': 'Sin',
          'cargo': 'Administrador',
          'usuario_id': 'uid',
        }),
        isNull,
      );
      expect(
        Employee.fromMap('EMP901', {
          'nombre': 'Sin',
          'cargo': 'Repartidor',
        }),
        isNull,
      );
    });

    test('normaliza cargo y estado en texto', () {
      final employee = Employee.fromMap('EMP005', {
        'nombre': 'Luis',
        'apellido': 'Quispe',
        'cargo': 'repartidor',
        'estado': 'inactivo',
        'usuario_id': 'uid-luis',
      });
      expect(employee!.cargo, EmployeePosition.repartidor);
      expect(employee.estado, isFalse);
    });
  });

  group('EmployeeDraft', () {
    const draft = EmployeeDraft(
      nombre: 'Carlos',
      apellido: 'Mendoza',
      correo: 'Carlos@Pharma.com',
      telefono: '+591 700-11111',
      cargo: EmployeePosition.repartidor,
    );

    test('valida campos obligatorios y correo', () {
      expect(draft.validate(), isNull);
      expect(
        const EmployeeDraft(
          nombre: '',
          apellido: 'Mendoza',
          correo: 'c@pharma.com',
          telefono: '1',
          cargo: EmployeePosition.vendedor,
        ).validate(),
        isNotNull,
      );
      expect(
        const EmployeeDraft(
          nombre: 'Carlos',
          apellido: 'Mendoza',
          correo: 'sin-arroba',
          telefono: '1',
          cargo: EmployeePosition.vendedor,
        ).validate(),
        isNotNull,
      );
    });

    test('construye empleado y usuario vinculados', () {
      final employee = draft.employeeMap(
        usuarioId: 'uid-carlos',
        fechaIngreso: DateTime(2026, 2, 1),
      );
      expect(employee['cargo'], 'Repartidor');
      expect(employee['usuario_id'], 'uid-carlos');
      expect(employee['estado'], isTrue);
      expect(employee.keys, isNot(contains('correo')));

      final user = draft.userMap(
        empleadoId: 'EMP004',
        fechaRegistro: DateTime(2026, 2, 1),
      );
      expect(user['correo'], 'carlos@pharma.com');
      expect(user['rol'], 'repartidor');
      expect(user['empleado_id'], 'EMP004');
    });
  });
}
