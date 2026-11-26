# Limpieza selectiva conservando Gradle — 26/11/2026

Rama: `pedidos-firestore-transaccionales`. Se preservaron todos los cambios de trabajo previos. Esta tarea añade únicamente este informe y `limpieza-selectiva-verificacion.json`; no modifica código, configuración, índice de Git ni documentos anteriores.

## Espacio

| Categoría | Tamaño inicial decimal |
| --- | ---: |
| Proyecto completo, incluidos ocultos y `.git` | 1.322,81 MB (1,232 GiB) |
| `build/` | 1.225,55 MB |
| `.dart_tool/` | 91,66 MB |
| `android/.gradle/`, conservado | 2,58 MB |

El inventario inicial contó 2.810 archivos. Las 20 carpetas y los 20 archivos más grandes están en `limpieza-selectiva-verificacion.json`. Las carpetas anidadas se solapan: sus tamaños no deben sumarse. Los mayores archivos eran bibliotecas nativas de compilación, dos copias de APK de ~94,36 MB y archivos Dart compilados de ~79,60 MB.

**Resultado: aproximadamente 5,72 MB finales y 1.317,09 MB recuperados (99,57 %).** La medición exacta final en bytes consta en el JSON. Los tamaños son lógicos; Windows puede mostrar valores de espacio asignado diferentes.

## Comprobaciones previas

- `flutter analyze`: sin incidencias.
- `flutter test`: 153 pruebas aprobadas.
- Pruebas JavaScript y fixtures: los seis archivos existentes en `functions/test/` se conservaron. No se instalaron dependencias Node ni se repitieron pruebas de reglas que las requieren.
- Se revisaron la rama, el estado de Git, `.gitignore`, los contenidos y la procedencia de las rutas seleccionadas. Ningún archivo de esas rutas estaba rastreado.

## Limpieza realizada

Solo se retiraron estas rutas, comprobando previamente que sus destinos absolutos permanecieran dentro del proyecto y no contuvieran enlaces:

| Ruta | Bytes retirados después de las pruebas |
| --- | ---: |
| `build/` | 1.302.666.975 |
| `.dart_tool/flutter_build/` | 80.321.621 |
| `.dart_tool/hooks_runner/` | 22.615.662 |

Las pruebas previas generaron nuevos artefactos; por eso los bytes retirados superan la diferencia entre la medición inicial y la final. No había `node_modules`, cobertura, `test-results` ni logs de raíz que justificaran otra eliminación.

No se ejecutó `flutter clean`, `gradlew --stop`, compilación Android, `flutter run`, sincronización completa de Gradle ni instalación Node. No se finalizaron procesos Java/Gradle ni se tocaron cachés globales.

## Entorno protegido

Los 298 archivos del manifiesto protegido conservaron exactamente sus hashes SHA-256. Incluyen fuentes, pruebas, documentos anteriores, scripts, Firebase, lockfiles y configuración de plataformas.

Se conservaron expresamente:

- `.vscode/settings.json`, con `java.import.gradle.java.home` apuntando a Java 21 de Android Studio y `java.gradle.buildServer.enabled: "off"`.
- Los tres scripts Gradle Kotlin, `gradle.properties`, `local.properties`, Wrapper, `gradlew` y `gradlew.bat`.
- `android/.gradle/` (~2,58 MB), `android/.kotlin/`, Gradle User Home y las cachés globales.
- `.dart_tool/package_config.json`, `package_graph.json`, `version` y metadatos del editor (~34 KB en conjunto). No es necesario regenerarlos ahora.
- Respaldos únicos `.firebase/audit-backup` y `.firebase/phone-backup`, reglas, índices, configuraciones Firebase y todos los avances de logística.

Entre los archivos grandes conservados están `android/.gradle/.../executionHistory.bin` (~2,28 MB), `fileHashes.bin` (~179 KB), `functions/package-lock.json` (~134 KB), el Wrapper (~54 KB) y las fuentes del dashboard. No se sacrificaron estos archivos para alcanzar una cifra de tamaño.

`.gitignore` ya excluía compilaciones, `.dart_tool`, `node_modules`, cobertura, logs y salidas temporales. Se comprobó que `.vscode/settings.json` no está ignorado. No fue necesario modificar exclusiones.

## Comprobación posterior y límites

Se verificaron nuevamente hashes, archivos esenciales Android/Firebase, presencia de pruebas, estado de Git y `git diff --check`. No hay eliminaciones de archivos rastreados ni cambios nuevos en fuentes o configuraciones. Los cambios anteriores siguen sin confirmar; no hubo commit, merge ni push.

No se hizo compilación ni sincronización posterior a la limpieza, conforme a lo solicitado. La evidencia funcional de esta tarea corresponde al análisis y las 153 pruebas ejecutados **antes** de retirar artefactos. La compilación Android correcta de la sesión anterior no se presenta como una nueva comprobación. Conservar la configuración y las cachés de Gradle evita repetir las acciones de limpieza anteriores; no implica garantizar que nunca pueda aparecer otro error externo del editor.

Para regenerar dependencias solo si se necesitan:

```powershell
flutter pub get
npm.cmd --prefix functions ci --ignore-scripts --no-audit --no-fund
```

Flutter recreará las subcarpetas de compilación al ejecutar pruebas o compilar. Una compilación Android puede volver a generar más de 1 GB en `build/`; ese crecimiento corresponde a artefactos regenerables. Retirarlos al terminar verificaciones no requiere borrar las cachés Gradle ni cambiar la configuración del editor. No se modificó Firebase real.
