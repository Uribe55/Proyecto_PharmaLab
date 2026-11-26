import '../models/app_user.dart';
import '../models/order.dart';
import '../models/pharmacy.dart';
import '../models/product.dart';

/// Catálogo ficticio utilizado mientras no existe un backend.
///
/// Las cuatro categorías corresponden al alcance corregido del informe:
/// reactivos de química sanguínea, reactivos de inmunología, equipos de
/// laboratorio e insumos clínicos (RF-02 y RF-03).
List<Product> buildSeedProducts() {
  return [
    // Reactivos de química sanguínea
    Product(
      id: 'p-001',
      name: 'Glucosa oxidasa (reactivo)',
      brand: 'Wiener Lab',
      presentation: 'Kit x 100 determinaciones',
      category: ProductCategory.reactivosQuimicaSanguinea,
      price: 320.00,
      stock: 45,
      description:
          'Reactivo líquido listo para usar en la determinación enzimática '
          'de glucosa en suero o plasma.',
      isFeatured: true,
      unitOfMeasure: 'Kit',
      requiresExpiry: true,
    ),
    Product(
      id: 'p-002',
      name: 'Colesterol total (reactivo)',
      brand: 'Wiener Lab',
      presentation: 'Kit x 200 determinaciones',
      category: ProductCategory.reactivosQuimicaSanguinea,
      price: 480.00,
      stock: 32,
      description:
          'Reactivo para la cuantificación colorimétrica de colesterol total '
          'en suero. Incluye calibrador y control de calidad.',
      unitOfMeasure: 'Kit',
      requiresExpiry: true,
    ),
    Product(
      id: 'p-003',
      name: 'Creatinina (reactivo)',
      brand: 'Biosystems',
      presentation: 'Kit x 100 determinaciones',
      category: ProductCategory.reactivosQuimicaSanguinea,
      price: 295.00,
      stock: 28,
      description:
          'Reactivo de Jaffé modificado para la determinación de creatinina '
          'sérica y urinaria.',
      unitOfMeasure: 'Kit',
      requiresExpiry: true,
    ),
    Product(
      id: 'p-004',
      name: 'Urea UV (reactivo)',
      brand: 'Biosystems',
      presentation: 'Kit x 100 determinaciones',
      category: ProductCategory.reactivosQuimicaSanguinea,
      price: 310.00,
      stock: 22,
      description:
          'Reactivo UV para la determinación de urea en suero o plasma. '
          'Presentación lista para usar en analizadores automáticos.',
      unitOfMeasure: 'Kit',
      requiresExpiry: true,
    ),
    Product(
      id: 'p-005',
      name: 'ALT/GPT (reactivo)',
      brand: 'Wiener Lab',
      presentation: 'Kit x 100 determinaciones',
      category: ProductCategory.reactivosQuimicaSanguinea,
      price: 340.00,
      stock: 18,
      description:
          'Reactivo cinético para la determinación de alanina '
          'aminotransferasa en suero.',
      unitOfMeasure: 'Kit',
      requiresExpiry: true,
    ),
    Product(
      id: 'p-006',
      name: 'Ácido úrico (reactivo)',
      brand: 'Biosystems',
      presentation: 'Kit x 100 determinaciones',
      category: ProductCategory.reactivosQuimicaSanguinea,
      price: 285.00,
      stock: 8,
      description:
          'Reactivo colorimétrico para la cuantificación de ácido úrico en '
          'suero y orina.',
      unitOfMeasure: 'Kit',
      requiresExpiry: true,
    ),

    // Reactivos de inmunología
    Product(
      id: 'p-007',
      name: 'TSH ELISA',
      brand: 'DRG Instruments',
      presentation: 'Kit x 96 pocillos',
      category: ProductCategory.reactivosInmunologia,
      price: 890.00,
      stock: 14,
      description:
          'Ensayo inmunoenzimático para la cuantificación de hormona '
          'estimulante de la tiroides en suero.',
      isFeatured: true,
      unitOfMeasure: 'Kit',
      requiresExpiry: true,
    ),
    Product(
      id: 'p-008',
      name: 'Dengue NS1 Ag',
      brand: 'SD Biosensor',
      presentation: 'Kit x 25 pruebas',
      category: ProductCategory.reactivosInmunologia,
      price: 1150.00,
      stock: 20,
      description:
          'Prueba rápida inmunocromatográfica para la detección del antígeno '
          'NS1 del virus del dengue.',
      isFeatured: true,
      unitOfMeasure: 'Kit',
      requiresExpiry: true,
    ),
    Product(
      id: 'p-009',
      name: 'VIH 1/2 Ag/Ab',
      brand: 'Abbott',
      presentation: 'Kit x 50 pruebas',
      category: ProductCategory.reactivosInmunologia,
      price: 980.00,
      stock: 12,
      description:
          'Prueba inmunocromatográfica para la detección combinada de '
          'antígenos y anticuerpos del VIH 1 y 2.',
      unitOfMeasure: 'Kit',
      requiresExpiry: true,
    ),
    Product(
      id: 'p-010',
      name: 'HBsAg ELISA',
      brand: 'DRG Instruments',
      presentation: 'Kit x 96 pocillos',
      category: ProductCategory.reactivosInmunologia,
      price: 760.00,
      stock: 16,
      description:
          'Ensayo inmunoenzimático para la detección del antígeno de '
          'superficie del virus de la hepatitis B.',
      unitOfMeasure: 'Kit',
      requiresExpiry: true,
    ),

    // Equipos de laboratorio
    Product(
      id: 'p-011',
      name: 'Analizador de química semiautomático',
      brand: 'Mindray',
      presentation: 'Equipo · 1 unidad',
      category: ProductCategory.equiposLaboratorio,
      price: 38500.00,
      stock: 2,
      description:
          'Analizador semiautomático para pruebas de química clínica con '
          'lectura de microplacas y gestión de resultados.',
      unitOfMeasure: 'Equipo',
      requiresExpiry: false,
    ),
    Product(
      id: 'p-012',
      name: 'Microscopio binocular',
      brand: 'Olympus',
      presentation: 'Equipo · 1 unidad',
      category: ProductCategory.equiposLaboratorio,
      price: 12900.00,
      stock: 3,
      description:
          'Microscopio óptico binocular con objetivos de 4x, 10x, 40x y 100x '
          'para laboratorio clínico.',
      unitOfMeasure: 'Equipo',
      requiresExpiry: false,
    ),
    Product(
      id: 'p-013',
      name: 'Centrífuga de laboratorio',
      brand: 'Hettich',
      presentation: 'Equipo · 1 unidad',
      category: ProductCategory.equiposLaboratorio,
      price: 8750.00,
      stock: 4,
      description:
          'Centrífuga de mesa con rotor para tubos de 15 mL y control de '
          'velocidad y tiempo.',
      isFeatured: true,
      unitOfMeasure: 'Equipo',
      requiresExpiry: false,
    ),
    Product(
      id: 'p-014',
      name: 'Incubadora de microplacas',
      brand: 'Labnet',
      presentation: 'Equipo · 1 unidad',
      category: ProductCategory.equiposLaboratorio,
      price: 6900.00,
      stock: 2,
      description:
          'Incubadora con control digital de temperatura para microplacas de '
          '96 pocillos usadas en ELISA.',
      unitOfMeasure: 'Equipo',
      requiresExpiry: false,
    ),

    // Insumos clínicos
    Product(
      id: 'p-015',
      name: 'Guantes de nitrilo M',
      brand: 'Medline',
      presentation: 'Caja x 100 unidades',
      category: ProductCategory.insumosClinicos,
      price: 95.00,
      stock: 40,
      description:
          'Guantes de examen sin polvo, talla mediana. Caja con 100 unidades '
          'para uso clínico y de laboratorio.',
      isFeatured: true,
      unitOfMeasure: 'Caja',
    ),
    Product(
      id: 'p-016',
      name: 'Puntas de micropipeta 200 µL',
      brand: 'Axygen',
      presentation: 'Bolsa x 1000 unidades',
      category: ProductCategory.insumosClinicos,
      price: 210.00,
      stock: 55,
      description:
          'Puntas estériles con filtro para micropipetas de 200 µL. Bolsa con '
          '1000 unidades.',
      unitOfMeasure: 'Bolsa',
    ),
    Product(
      id: 'p-017',
      name: 'Tubos de ensayo 5 mL',
      brand: 'Falcon',
      presentation: 'Bolsa x 500 unidades',
      category: ProductCategory.insumosClinicos,
      price: 180.00,
      stock: 36,
      description:
          'Tubos de polipropileno de 5 mL con tapa de rosca, aptos para '
          'centrifugación y almacenamiento de muestras.',
      unitOfMeasure: 'Bolsa',
    ),
    Product(
      id: 'p-018',
      name: 'Mascarillas quirúrgicas',
      brand: 'Medline',
      presentation: 'Caja x 50 unidades',
      category: ProductCategory.insumosClinicos,
      price: 25.00,
      stock: 0,
      description:
          'Mascarillas quirúrgicas de tres capas con sujetador nasal. '
          'Caja con 50 unidades.',
      unitOfMeasure: 'Caja',
    ),
  ];
}

/// Pedidos de ejemplo para mostrar el historial y el seguimiento.
List<PharmacyOrder> buildSeedOrders(PharmacyProfile pharmacy) {
  return [
    PharmacyOrder(
      number: 'PL-2026-0842',
      createdAt: DateTime(2026, 6, 18, 9, 30),
      status: OrderStatus.enRuta,
      customerId: 'u-cliente',
      pharmacyName: pharmacy.commercialName,
      address: pharmacy.address,
      contactName: pharmacy.responsible,
      contactPhone: pharmacy.phone,
      notes: 'Entregar en horario de la mañana.',
      driverId: 'u-carlos',
      driverName: 'Carlos Mendoza',
      items: const [
        OrderLine(
          productId: 'p-001',
          name: 'Glucosa oxidasa (reactivo)',
          brand: 'Wiener Lab',
          presentation: 'Kit x 100 determinaciones',
          unitPrice: 320.00,
          quantity: 3,
        ),
        OrderLine(
          productId: 'p-013',
          name: 'Centrífuga de laboratorio',
          brand: 'Hettich',
          presentation: 'Equipo · 1 unidad',
          unitPrice: 8750.00,
          quantity: 2,
        ),
        OrderLine(
          productId: 'p-007',
          name: 'TSH ELISA',
          brand: 'DRG Instruments',
          presentation: 'Kit x 96 pocillos',
          unitPrice: 890.00,
          quantity: 1,
        ),
      ],
    ),
    PharmacyOrder(
      number: 'PL-2026-0841',
      createdAt: DateTime(2026, 6, 15, 16, 10),
      status: OrderStatus.pendiente,
      customerId: 'u-cliente',
      pharmacyName: pharmacy.commercialName,
      address: pharmacy.address,
      contactName: pharmacy.responsible,
      contactPhone: pharmacy.phone,
      items: const [
        OrderLine(
          productId: 'p-009',
          name: 'VIH 1/2 Ag/Ab',
          brand: 'Abbott',
          presentation: 'Kit x 50 pruebas',
          unitPrice: 980.00,
          quantity: 2,
        ),
        OrderLine(
          productId: 'p-017',
          name: 'Tubos de ensayo 5 mL',
          brand: 'Falcon',
          presentation: 'Bolsa x 500 unidades',
          unitPrice: 180.00,
          quantity: 4,
        ),
      ],
    ),
    PharmacyOrder(
      number: 'PL-2026-0816',
      createdAt: DateTime(2026, 6, 8, 11, 5),
      status: OrderStatus.entregado,
      customerId: 'u-cliente',
      pharmacyName: pharmacy.commercialName,
      address: pharmacy.address,
      contactName: pharmacy.responsible,
      contactPhone: pharmacy.phone,
      driverId: 'u-carlos',
      driverName: 'Carlos Mendoza',
      deliveredAt: DateTime(2026, 6, 8, 12, 40),
      items: const [
        OrderLine(
          productId: 'p-003',
          name: 'Creatinina (reactivo)',
          brand: 'Biosystems',
          presentation: 'Kit x 100 determinaciones',
          unitPrice: 295.00,
          quantity: 5,
        ),
        OrderLine(
          productId: 'p-010',
          name: 'HBsAg ELISA',
          brand: 'DRG Instruments',
          presentation: 'Kit x 96 pocillos',
          unitPrice: 760.00,
          quantity: 2,
        ),
      ],
    ),
    PharmacyOrder(
      number: 'PL-2026-0809',
      createdAt: DateTime(2026, 6, 2, 8, 45),
      status: OrderStatus.aprobado,
      customerId: 'u-cliente',
      pharmacyName: pharmacy.commercialName,
      address: pharmacy.address,
      contactName: pharmacy.responsible,
      contactPhone: pharmacy.phone,
      notes: 'Llamar antes de llegar.',
      items: const [
        OrderLine(
          productId: 'p-016',
          name: 'Puntas de micropipeta 200 µL',
          brand: 'Axygen',
          presentation: 'Bolsa x 1000 unidades',
          unitPrice: 210.00,
          quantity: 2,
        ),
        OrderLine(
          productId: 'p-015',
          name: 'Guantes de nitrilo M',
          brand: 'Medline',
          presentation: 'Caja x 100 unidades',
          unitPrice: 95.00,
          quantity: 3,
        ),
      ],
    ),
    PharmacyOrder(
      number: 'PL-2026-0839',
      createdAt: DateTime(2026, 6, 12, 15, 20),
      status: OrderStatus.pendiente,
      customerId: 'u-san-rafael',
      pharmacyName: 'Farmacia San Rafael',
      address: 'Av. Ballivián 1250, Calacoto, La Paz',
      contactName: 'Juan Flores',
      contactPhone: '+591 712-45890',
      notes: 'Facturar a nombre de la farmacia.',
      items: const [
        OrderLine(
          productId: 'p-009',
          name: 'VIH 1/2 Ag/Ab',
          brand: 'Abbott',
          presentation: 'Kit x 50 pruebas',
          unitPrice: 980.00,
          quantity: 2,
        ),
        OrderLine(
          productId: 'p-017',
          name: 'Tubos de ensayo 5 mL',
          brand: 'Falcon',
          presentation: 'Bolsa x 500 unidades',
          unitPrice: 180.00,
          quantity: 6,
        ),
        OrderLine(
          productId: 'p-001',
          name: 'Glucosa oxidasa (reactivo)',
          brand: 'Wiener Lab',
          presentation: 'Kit x 100 determinaciones',
          unitPrice: 320.00,
          quantity: 1,
        ),
      ],
    ),
    PharmacyOrder(
      number: 'PL-2026-0838',
      createdAt: DateTime(2026, 6, 10, 9, 15),
      status: OrderStatus.entregado,
      customerId: 'u-san-rafael',
      pharmacyName: 'Farmacia San Rafael',
      address: 'Av. Ballivián 1250, Calacoto, La Paz',
      contactName: 'Juan Flores',
      contactPhone: '+591 712-45890',
      driverId: 'u-daniela',
      driverName: 'Daniela Ríos',
      deliveredAt: DateTime(2026, 6, 10, 11, 5),
      items: const [
        OrderLine(
          productId: 'p-002',
          name: 'Colesterol total (reactivo)',
          brand: 'Wiener Lab',
          presentation: 'Kit x 200 determinaciones',
          unitPrice: 480.00,
          quantity: 4,
        ),
        OrderLine(
          productId: 'p-007',
          name: 'TSH ELISA',
          brand: 'DRG Instruments',
          presentation: 'Kit x 96 pocillos',
          unitPrice: 890.00,
          quantity: 1,
        ),
      ],
    ),
  ];
}

/// Usuarios internos de PharmaLab para la demostración local (RF-19).
List<AppUser> buildSeedEmployees() {
  return const [
    AppUser(
      id: 'u-ana',
      name: 'Ana Vargas',
      email: 'anav@ven.pharma.com',
      phone: '+591 707-22110',
      role: UserRole.vendedor,
    ),
    AppUser(
      id: 'u-carlos',
      name: 'Carlos Mendoza',
      email: 'carlosm@rep.pharma.com',
      phone: '+591 707-33441',
      role: UserRole.repartidor,
      address: 'Av. Blanco Galindo km 5, Cochabamba',
    ),
    AppUser(
      id: 'u-luis',
      name: 'Luis Quispe',
      email: 'luisq@rep.pharma.com',
      phone: '+591 707-44552',
      role: UserRole.repartidor,
      address: 'Calle Ayacucho 234, Cochabamba',
    ),
    AppUser(
      id: 'u-daniela',
      name: 'Daniela Ríos',
      email: 'danielar@rep.pharma.com',
      phone: '+591 707-55663',
      role: UserRole.repartidor,
      address: 'Av. América 1450, Cochabamba',
    ),
    AppUser(
      id: 'u-laura',
      name: 'Laura Rojas',
      email: 'laurar@admin.pharma.com',
      phone: '+591 707-66774',
      role: UserRole.administrador,
    ),
  ];
}
