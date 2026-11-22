import '../models/app_user.dart';
import '../models/order.dart';
import '../models/pharmacy.dart';
import '../models/product.dart';

/// Catálogo ficticio utilizado mientras no existe un backend.
List<Product> buildSeedProducts() {
  return [
    // Genéricos
    Product(
      id: 'p-001',
      name: 'Paracetamol 500 mg',
      brand: 'Genfar',
      presentation: 'Caja x 20 tabletas',
      category: ProductCategory.genericos,
      price: 8.50,
      stock: 120,
      description:
          'Analgésico y antipirético de uso frecuente. Presentación en tabletas '
          'de 500 mg para dispensación en farmacia.',
      isFeatured: true,
    ),
    Product(
      id: 'p-002',
      name: 'Ibuprofeno 400 mg',
      brand: 'Bagó',
      presentation: 'Caja x 20 tabletas',
      category: ProductCategory.genericos,
      price: 12.00,
      stock: 95,
      description:
          'Antiinflamatorio no esteroideo indicado para dolor y fiebre. '
          'Caja con 20 tabletas recubiertas de 400 mg.',
    ),
    Product(
      id: 'p-003',
      name: 'Amoxicilina 500 mg',
      brand: 'Farmindustria',
      presentation: 'Caja x 21 cápsulas',
      category: ProductCategory.genericos,
      price: 28.50,
      stock: 60,
      description:
          'Antibiótico de amplio espectro. Dispensación bajo receta médica. '
          'Caja con 21 cápsulas de 500 mg.',
    ),
    Product(
      id: 'p-004',
      name: 'Omeprazol 20 mg',
      brand: 'Inti',
      presentation: 'Caja x 30 cápsulas',
      category: ProductCategory.genericos,
      price: 22.00,
      stock: 84,
      description:
          'Inhibidor de la bomba de protones para el tratamiento de afecciones '
          'gástricas. Caja con 30 cápsulas de liberación retardada.',
    ),
    Product(
      id: 'p-005',
      name: 'Losartán 50 mg',
      brand: 'Genfar',
      presentation: 'Caja x 30 tabletas',
      category: ProductCategory.genericos,
      price: 35.00,
      stock: 45,
      description:
          'Antihipertensivo indicado para el control de la presión arterial. '
          'Caja con 30 tabletas recubiertas de 50 mg.',
    ),
    Product(
      id: 'p-006',
      name: 'Metformina 850 mg',
      brand: 'Bagó',
      presentation: 'Caja x 30 tabletas',
      category: ProductCategory.genericos,
      price: 18.75,
      stock: 8,
      description:
          'Antidiabético oral para el control de la glucosa en sangre. '
          'Caja con 30 tabletas de 850 mg.',
    ),

    // Insumos
    Product(
      id: 'p-007',
      name: 'Guantes de nitrilo M',
      brand: 'Medline',
      presentation: 'Caja x 100 unidades',
      category: ProductCategory.insumos,
      price: 95.00,
      stock: 40,
      description:
          'Guantes de examen sin polvo, talla mediana. Caja con 100 unidades '
          'para uso clínico y de laboratorio.',
      isFeatured: true,
    ),
    Product(
      id: 'p-008',
      name: 'Jeringas desechables 5 ml',
      brand: 'Becton Dickinson',
      presentation: 'Caja x 100 unidades',
      category: ProductCategory.insumos,
      price: 68.00,
      stock: 55,
      description:
          'Jeringas estériles de 5 ml con aguja. Caja con 100 unidades de un '
          'solo uso.',
    ),
    Product(
      id: 'p-009',
      name: 'Tiras reactivas de glucosa',
      brand: 'Accu-Chek',
      presentation: 'Frasco x 50 tiras',
      category: ProductCategory.insumos,
      price: 145.00,
      stock: 24,
      description:
          'Tiras reactivas para la medición de glucosa capilar. Frasco con '
          '50 tiras compatibles con glucómetros Accu-Chek.',
      isFeatured: true,
    ),
    Product(
      id: 'p-010',
      name: 'Gasas estériles 10x10',
      brand: 'Cureband',
      presentation: 'Paquete x 10 unidades',
      category: ProductCategory.insumos,
      price: 12.50,
      stock: 130,
      description:
          'Gasas de algodón estériles de 10 x 10 cm. Paquete con 10 unidades '
          'para curaciones.',
    ),
    Product(
      id: 'p-011',
      name: 'Algodón hidrófilo 500 g',
      brand: 'Farmex',
      presentation: 'Bolsa x 500 g',
      category: ProductCategory.insumos,
      price: 32.00,
      stock: 18,
      description:
          'Algodón hidrófilo de alta absorbencia. Bolsa de 500 g para uso '
          'médico y de curación.',
    ),
    Product(
      id: 'p-012',
      name: 'Mascarillas quirúrgicas',
      brand: 'Medline',
      presentation: 'Caja x 50 unidades',
      category: ProductCategory.insumos,
      price: 25.00,
      stock: 0,
      description:
          'Mascarillas quirúrgicas de tres capas con sujetador nasal. '
          'Caja con 50 unidades.',
    ),

    // Vitaminas
    Product(
      id: 'p-013',
      name: 'Vitamina C 1000 mg',
      brand: 'Bayer',
      presentation: 'Frasco x 60 tabletas',
      category: ProductCategory.vitaminas,
      price: 48.00,
      stock: 70,
      description:
          'Suplemento de vitamina C de 1000 mg por tableta. Frasco con '
          '60 tabletas efervescentes.',
      isFeatured: true,
    ),
    Product(
      id: 'p-014',
      name: 'Complejo B',
      brand: 'Lafar',
      presentation: 'Caja x 30 tabletas',
      category: ProductCategory.vitaminas,
      price: 26.00,
      stock: 90,
      description:
          'Complejo de vitaminas del grupo B para apoyo del sistema nervioso '
          'y energético. Caja con 30 tabletas.',
    ),
    Product(
      id: 'p-015',
      name: 'Vitamina D3 2000 UI',
      brand: 'Procaps',
      presentation: 'Frasco x 60 cápsulas',
      category: ProductCategory.vitaminas,
      price: 65.00,
      stock: 32,
      description:
          'Suplemento de vitamina D3 de 2000 UI por cápsula. Frasco con '
          '60 cápsulas blandas.',
    ),
    Product(
      id: 'p-016',
      name: 'Multivitamínico adulto',
      brand: 'Bayer',
      presentation: 'Frasco x 30 tabletas',
      category: ProductCategory.vitaminas,
      price: 55.00,
      stock: 12,
      description:
          'Fórmula multivitamínica y mineral para adultos. Frasco con '
          '30 tabletas de liberación prolongada.',
    ),
    Product(
      id: 'p-017',
      name: 'Zinc 50 mg',
      brand: 'Genfar',
      presentation: 'Caja x 30 tabletas',
      category: ProductCategory.vitaminas,
      price: 21.50,
      stock: 65,
      description:
          'Suplemento de zinc de 50 mg por tableta. Caja con 30 tabletas '
          'para apoyo inmunológico.',
    ),
    Product(
      id: 'p-018',
      name: 'Omega 3 1000 mg',
      brand: 'Procaps',
      presentation: 'Frasco x 60 cápsulas',
      category: ProductCategory.vitaminas,
      price: 78.00,
      stock: 26,
      description:
          'Ácidos grasos esenciales omega 3 de 1000 mg por cápsula. Frasco '
          'con 60 cápsulas blandas.',
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
          name: 'Paracetamol 500 mg',
          brand: 'Genfar',
          presentation: 'Caja x 20 tabletas',
          unitPrice: 8.50,
          quantity: 3,
        ),
        OrderLine(
          productId: 'p-013',
          name: 'Vitamina C 1000 mg',
          brand: 'Bayer',
          presentation: 'Frasco x 60 tabletas',
          unitPrice: 48.00,
          quantity: 2,
        ),
        OrderLine(
          productId: 'p-007',
          name: 'Guantes de nitrilo M',
          brand: 'Medline',
          presentation: 'Caja x 100 unidades',
          unitPrice: 95.00,
          quantity: 1,
        ),
      ],
    ),
    PharmacyOrder(
      number: 'PL-2026-0841',
      createdAt: DateTime(2026, 6, 15, 16, 10),
      status: OrderStatus.pendiente,
      pharmacyName: pharmacy.commercialName,
      address: pharmacy.address,
      contactName: pharmacy.responsible,
      contactPhone: pharmacy.phone,
      items: const [
        OrderLine(
          productId: 'p-009',
          name: 'Tiras reactivas de glucosa',
          brand: 'Accu-Chek',
          presentation: 'Frasco x 50 tiras',
          unitPrice: 145.00,
          quantity: 2,
        ),
        OrderLine(
          productId: 'p-010',
          name: 'Gasas estériles 10x10',
          brand: 'Cureband',
          presentation: 'Paquete x 10 unidades',
          unitPrice: 12.50,
          quantity: 4,
        ),
      ],
    ),
    PharmacyOrder(
      number: 'PL-2026-0816',
      createdAt: DateTime(2026, 6, 8, 11, 5),
      status: OrderStatus.entregado,
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
          name: 'Amoxicilina 500 mg',
          brand: 'Farmindustria',
          presentation: 'Caja x 21 cápsulas',
          unitPrice: 28.50,
          quantity: 5,
        ),
        OrderLine(
          productId: 'p-014',
          name: 'Complejo B',
          brand: 'Lafar',
          presentation: 'Caja x 30 tabletas',
          unitPrice: 26.00,
          quantity: 2,
        ),
      ],
    ),
    PharmacyOrder(
      number: 'PL-2026-0809',
      createdAt: DateTime(2026, 6, 2, 8, 45),
      status: OrderStatus.aprobado,
      pharmacyName: pharmacy.commercialName,
      address: pharmacy.address,
      contactName: pharmacy.responsible,
      contactPhone: pharmacy.phone,
      notes: 'Llamar antes de llegar.',
      items: const [
        OrderLine(
          productId: 'p-008',
          name: 'Jeringas desechables 5 ml',
          brand: 'Becton Dickinson',
          presentation: 'Caja x 100 unidades',
          unitPrice: 68.00,
          quantity: 2,
        ),
        OrderLine(
          productId: 'p-011',
          name: 'Algodón hidrófilo 500 g',
          brand: 'Farmex',
          presentation: 'Bolsa x 500 g',
          unitPrice: 32.00,
          quantity: 3,
        ),
      ],
    ),
    PharmacyOrder(
      number: 'PL-2026-0839',
      createdAt: DateTime(2026, 6, 12, 15, 20),
      status: OrderStatus.pendiente,
      pharmacyName: 'Farmacia San Rafael',
      address: 'Av. Ballivián 1250, Calacoto, La Paz',
      contactName: 'Juan Flores',
      contactPhone: '+591 712-45890',
      notes: 'Facturar a nombre de la farmacia.',
      items: const [
        OrderLine(
          productId: 'p-009',
          name: 'Tiras reactivas de glucosa',
          brand: 'Accu-Chek',
          presentation: 'Frasco x 50 tiras',
          unitPrice: 145.00,
          quantity: 2,
        ),
        OrderLine(
          productId: 'p-010',
          name: 'Gasas estériles 10x10',
          brand: 'Cureband',
          presentation: 'Paquete x 10 unidades',
          unitPrice: 12.50,
          quantity: 6,
        ),
        OrderLine(
          productId: 'p-013',
          name: 'Vitamina C 1000 mg',
          brand: 'Bayer',
          presentation: 'Frasco x 60 tabletas',
          unitPrice: 48.00,
          quantity: 1,
        ),
      ],
    ),
    PharmacyOrder(
      number: 'PL-2026-0838',
      createdAt: DateTime(2026, 6, 10, 9, 15),
      status: OrderStatus.entregado,
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
          name: 'Ibuprofeno 400 mg',
          brand: 'Bagó',
          presentation: 'Caja x 20 tabletas',
          unitPrice: 12.00,
          quantity: 4,
        ),
        OrderLine(
          productId: 'p-007',
          name: 'Guantes de nitrilo M',
          brand: 'Medline',
          presentation: 'Caja x 100 unidades',
          unitPrice: 95.00,
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
      email: 'ana@pharmalab.bo',
      phone: '+591 707-22110',
      role: UserRole.vendedor,
    ),
    AppUser(
      id: 'u-carlos',
      name: 'Carlos Mendoza',
      email: 'carlos@pharmalab.bo',
      phone: '+591 707-33441',
      role: UserRole.repartidor,
    ),
    AppUser(
      id: 'u-luis',
      name: 'Luis Quispe',
      email: 'luis@pharmalab.bo',
      phone: '+591 707-44552',
      role: UserRole.repartidor,
    ),
    AppUser(
      id: 'u-daniela',
      name: 'Daniela Ríos',
      email: 'daniela@pharmalab.bo',
      phone: '+591 707-55663',
      role: UserRole.repartidor,
    ),
    AppUser(
      id: 'u-laura',
      name: 'Laura Rojas',
      email: 'laura@pharmalab.bo',
      phone: '+591 707-66774',
      role: UserRole.administrador,
    ),
  ];
}
