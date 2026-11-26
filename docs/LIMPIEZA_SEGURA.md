# Limpieza segura de PharmaLab — 26/11/2026

Rama conservada: `pedidos-firestore-transaccionales`. No se descartaron cambios de trabajo ni se modificó el índice de Git. No hubo commit, merge, push, despliegue ni acceso a datos de producción.

## Diagnóstico previo

Tamaño inicial: **1.611.458.948 bytes** (1.611,46 MB decimales; 1,501 GiB), 17.064 archivos, incluyendo `.git` y archivos ocultos. Se miden longitudes lógicas de archivos; el espacio físico asignado por Windows puede variar.

| Categoría | Bytes iniciales | Tratamiento |
| --- | ---: | --- |
| Compilaciones `build/` | 1.302.456.279 | Regenerables; `flutter clean` |
| Dependencias `functions/node_modules/` | 188.605.563 | Instaladas por `npm ci` durante la verificación previa; eliminadas |
| Caché `.dart_tool/` | 102.918.395 | Eliminada y regenerada mínimamente para continuar desarrollando |
| Caché `android/.gradle/` | 10.062.452 | Eliminada; Gradle la recrea al compilar |
| Logs de raíz | 3.967.188 | Salidas de Firebase/pruebas, eliminadas |
| Resto | 3.449.071 | Incluye fuentes, configuración, pruebas, Git y respaldos; conservados salvo logs identificados |

Las 20 carpetas y los 20 archivos más grandes están registrados en `limpieza-medicion.json`. Los tamaños de carpetas anidadas se solapan y no deben sumarse. Dos APK de 94.341.868 bytes tenían SHA-256 idéntico y estaban dentro de `build/`; ambos eran salidas duplicadas de compilación.

No había archivos rastreados en las cuatro carpetas principales de limpieza. Se preservaron todos los archivos modificados y no confirmados de la etapa de logística. Se creó un manifiesto SHA-256 de 292 archivos fuera de los artefactos y logs para comprobar su integridad después de la operación.

## Elementos eliminados y conservados

Se eliminaron artefactos Flutter, cachés Dart, Gradle y Kotlin locales, `functions/node_modules` y logs generados. También se identificó y retiró `android/hs_err_pid28016.log` (530.417 bytes), un informe antiguo de fallo de memoria JVM; no era código ni un respaldo. `limpieza-eliminados.json` registra las rutas retiradas directamente; la limpieza de Flutter se realizó con `flutter clean`.

Las dependencias Node tenían lockfile v3 con 294 entradas y procedían de la instalación reproducible de la verificación anterior. Se conservaron `functions/package.json`, `functions/package-lock.json`, código, pruebas y fixtures. No se reinstalaron dependencias Node después de borrarlas.

Se conservaron:

- `lib/`, `test/`, `assets/`, `docs/`, `scripts/`, `functions/src/`, `functions/test/` y configuraciones de plataformas.
- Firebase: `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `lib/firebase_options.dart` y `android/app/google-services.json`.
- Gradle Wrapper completo y archivos Gradle; no se alteraron versiones ni plugins.
- Respaldos únicos `.firebase/audit-backup` y `.firebase/phone-backup` (17.825 bytes en conjunto).
- `.git`, lockfiles y todos los avances locales de logística.
- SDK y cachés globales de Flutter, Dart, Node y Gradle fuera del proyecto.

`.firebaserc` y `ios/Runner/GoogleService-Info.plist` ya estaban ausentes antes de la limpieza. No se crearon ni se eliminaron. La configuración Android existente se conserva.

Los archivos grandes que deben conservarse incluyen `functions/package-lock.json` (~134 KB), `android/gradle/wrapper/gradle-wrapper.jar` (~54 KB), el código del dashboard (~47 KB y ~44 KB por archivo), el repositorio del dashboard (~35 KB) y `firestore.rules` (~33 KB). No se deduplicaron fuentes ni fixtures por similitud.

## Gitignore

Se mantuvieron las exclusiones existentes de compilaciones, `.dart_tool`, Gradle, cobertura, Firebase temporal, logs y secretos. Se agregaron exclusiones para `node_modules` anidados, `test-results`, temporales `.tmp/.temp`, volcados `.hprof` y claves `.pem/.key`. No se ignoraron reglas, Firebase client config, código ni fixtures. No se utilizó `git rm` ni se cambió el índice.

## Verificación y recuperación

- `flutter pub get`: correcto; lockfile sin cambios.
- `flutter analyze`: sin incidencias.
- `flutter test`: **153 pruebas aprobadas**.
- Compilación Android: `flutter build apk --debug --target-platform android-arm64` **correcta**, en 128,2 segundos. El APK y los artefactos de verificación fueron retirados después.
- Reglas: archivos y fixtures conservados con su contenido original. No se reinstaló Node ni se repitieron pruebas de reglas para evitar recrear 189 MB; la ejecución anterior de la etapa 6 aprobó 69 pruebas.

Para continuar:

```powershell
flutter pub get
flutter run
```

Solo cuando se necesiten las herramientas y pruebas Node:

```powershell
npm.cmd --prefix functions ci --ignore-scripts --no-audit --no-fund
```

Para una compilación Android, Gradle y Flutter regeneran automáticamente sus cachés locales. No hace falta reinstalar sus SDK.

## Evitar acumulación

Ejecutar `flutter clean` al terminar verificaciones o antes de archivar el proyecto; después `flutter pub get` deja preparada la resolución de paquetes. Eliminar `functions/node_modules` cuando termine el trabajo de pruebas Node, manteniendo su lockfile. Evitar guardar copias de APK dentro del repositorio. Las reglas `.gitignore` previenen subidas accidentales, pero no reducen por sí solas el espacio local.

## Resultado final

El proyecto queda en aproximadamente **3,03 MB**, frente a **1.611,46 MB** iniciales. Se liberaron aproximadamente **1.608,43 MB** (1,50 GiB), una reducción del **99,81 %**. El valor exacto en bytes se registra en `limpieza-medicion.json`, incluyendo `.git`, archivos ocultos y estos informes.

La verificación volvió a generar 1.223.070.161 bytes en `build/`, 102.971.086 bytes en `.dart_tool/` y 2.551.225 bytes en `android/.gradle/`. Todos esos artefactos se retiraron. Solo se regeneró la configuración mínima de paquetes `.dart_tool/` (~34 KB) mediante un último `flutter pub get`.

Los **292 archivos protegidos** conservan exactamente sus hashes originales después de compilar y limpiar. Esto incluye código, pruebas, configuración Firebase, reglas, lockfiles, Wrapper y respaldos. `git diff --check` pasó. No hay eliminaciones de archivos rastreados, ni APK de verificación ni `node_modules` restante.

Git conserva todos los cambios previos de logística. Esta tarea únicamente añade la modificación de `.gitignore` y los informes/manifiestos de limpieza en `docs/`. Los avisos de Git sobre su archivo global `ignore` sin permiso de lectura no impidieron revisar el estado ni la integridad de los archivos del proyecto.
