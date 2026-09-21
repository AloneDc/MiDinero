# Validación reproducible

## En este entorno

Windows puede comprobar archivos, referencias de proyecto, plist/XML/JSON, gramática
Swift y sintaxis de scripts. Nada de eso expande `@Model`/`#Predicate`, comprueba los
tipos de SwiftUI ni ejecuta App Intents. No se considera equivalente a `xcodebuild`.

```powershell
python scripts/verify_static.py
python -m compileall -q scripts
python -m pip install --target .validation-tools tree-sitter==0.25.2 tree-sitter-swift==0.7.3 openstep-parser==2.0.3
$env:PYTHONPATH = (Join-Path (Get-Location) '.validation-tools')
python scripts/verify_static.py --parse-swift --parse-project
git diff --check
```

El parser es una herramienta de desarrollo opcional, aislada e ignorada por Git.
No hay paquetes externos en el proyecto iOS ni en `Package.swift`.

## Pipeline real en Mac y GitHub Actions

```bash
xcode-select -p
xcodebuild -version
xcrun swift --version
open MiDinero.xcodeproj
bash scripts/validate_mac.sh
# Selección opcional: SIMULATOR_ID=<UUID> bash scripts/validate_mac.sh
```

Necesita Xcode 16+ y Python 3.10+. Instala un runtime iOS compatible si no existe.
El workflow `.github/workflows/ios-ci.yml` usa el mismo pipeline en `macos-15`,
en una matriz explícita Xcode 16.4 / 26.2:

1. Registra macOS, arquitectura, Xcode, Swift, SDK, revisión y targets/schemes.
2. Detecta dispositivos con `simctl` y destinos con `xcodebuild -showdestinations`.
   Prioriza un iPhone instalado del SDK detectado, lo arranca y Xcode resuelve
   su UUID explícito, aunque inicialmente solo anuncie destinos genéricos.
3. Compila Debug y `build-for-testing`, sin signing para Simulator.
4. Enumera con `test-without-building -enumerate-tests`, ejecuta todas las pruebas
   con `test-without-building` y lee resultados reales mediante `xcresulttool`.
   El inventario esperado es 25 pruebas unitarias/integración y 1 de UI. No se
   acepta un resultado verde con pruebas ausentes, omitidas o no ejecutadas.
5. Compila Release para Simulator y conserva todos los diagnósticos.

Los artefactos `xcode-evidence-<xcode>-<run>-<attempt>` conservan durante 14 días logs,
comandos y códigos de salida en `result.json`, inventario descubierto, resúmenes
JSON y bundles `.xcresult`. El directorio local `build/ci-evidence/` no se
sobrescribe: muévelo antes de repetir. Las seis pruebas Python (cinco del parser y
una del bloqueo de distribución sin credenciales) son complementarias; no se suman
al conteo de XCTest/XCUITest.

Un job independiente usa Xcode 26.2 para `generic/platform=iOS`: Release build,
archive sin firma, validación estructural (arm64, SDK, Info.plist, icono, privacidad,
App Intents, frameworks y dSYM) y empaquetado del xcarchive. Reproducir en Mac:

```bash
export DEVELOPER_DIR=/Applications/Xcode_26.2.app/Contents/Developer
python3 scripts/ci/validate_device.py
```

Los comandos y resultados están en `build/device-evidence/result.json`; el artefacto
`device-evidence-<run>-<attempt>` incluye logs, metadata generada y archive `.tar.gz`
sin firma durante 14 días. Mover los directorios `build/device-evidence/` y
`build/device/MiDinero.xcarchive` antes de repetir. No es una IPA instalable.
La firma/TestFlight y su workflow futuro se describen en
[DEVICE_READINESS.md](DEVICE_READINESS.md); los pasos físicos en
[IPHONE_TEST_PLAN.md](IPHONE_TEST_PLAN.md).

`swift test` ejecuta por separado las 17 pruebas Foundation. No sustituye los
25 tests del target alojado en la app ni XCUITest. El scheme compartido inyecta
`MIDINERO_UI_TEST_STORE` únicamente para tests; Launch normal no lo hereda.
La prueba UI usa un UUID nuevo y lo conserva para su reapertura.

Revisar warnings de concurrencia con `SWIFT_STRICT_CONCURRENCY=complete`, expansión
de SwiftData y extracción de metadata App Intents. Corregir cualquier fallo y repetir
el comando. No eliminar una base personal para hacer pasar una prueba.

## Matriz funcional y visual

El XCUITest automatiza registro, reapertura, edición, reporte, cancelación de
borrado y eliminación. Las pruebas unitarias verifican cálculos, validaciones,
CSV y persistencia. Los resultados y capturas reales están en
[ASTRA_EVALUATION.md](ASTRA_EVALUATION.md#fase-2--validación-xcode).
VoiceOver, Dynamic Type, modo oscuro, errores por disco lleno y Siri/Atajos del
sistema requieren todavía la revisión manual descrita a continuación.

| Escenario | Resultado esperado |
| --- | --- |
| Instalación limpia | Sin movimientos ficticios; categorías predeterminadas |
| App: 12.50, Comida, sin nota | Guarda una vez; feedback; gasto/total/conteo actualizados |
| App: ingreso 100 en Tipo y fecha | Ingreso separado; balance 87.50 tras el gasto anterior |
| Monto 0, negativo, 1,000, texto o >2 decimales | Error; ningún movimiento nuevo |
| Editar gasto a 20, categoría Transporte | Mismo ID/createdAt; nuevo total/categoría; sin duplicado |
| Editar fecha al mes anterior | Sale de los totales del mes actual; entra en el mes anterior |
| Cerrar y volver a abrir app | Datos conservados |
| Cancelar confirmación de borrar | El movimiento permanece |
| Confirmar borrado y reabrir | Movimiento ausente; totales corregidos |
| Reporte de mes vacío / solo ingresos | Sin división por cero ni categoría ganadora falsa |
| CSV con comas, comillas, tildes y saltos | CSV válido y UTF-8; una celda por nota |
| Nota `=1+1` al exportar | Texto neutralizado, no fórmula ejecutable |
| VoiceOver | Monto/categorías/guardar anunciados; edición y borrado accesibles |
| Dynamic Type accesible, iPhone pequeño, horizontal | Texto sin controles superpuestos; scroll y teclado utilizables |
| Modo claro/oscuro y mayor contraste | Colores legibles, selección distinguible sin depender solo del color |
| Cambio de mes/zona horaria | Inicio se recalcula al activarse; reporte conserva su mes seleccionado |
| Disco sin espacio/datos inaccesibles | Error visible, sin mensaje falso de éxito ni fallback a memoria |

Capturas reales, después de instalar/abrir la app en Simulator:

```bash
mkdir -p build/screenshots
xcrun simctl ui "$SIMULATOR_ID" appearance light
xcrun simctl io "$SIMULATOR_ID" screenshot build/screenshots/light.png
xcrun simctl ui "$SIMULATOR_ID" appearance dark
xcrun simctl io "$SIMULATOR_ID" screenshot build/screenshots/dark.png
xcrun simctl ui "$SIMULATOR_ID" content_size accessibility-extra-extra-extra-large
xcrun simctl io "$SIMULATOR_ID" screenshot build/screenshots/accessibility.png
xcrun simctl ui "$SIMULATOR_ID" content_size large
```

Las capturas necesitan navegación manual a las pantallas y teclado que se evalúan;
no sirven capturas de una página web que imite iOS.

## App Intents: prueba indispensable en iPhone físico

Con la app firmada e instalada y Siri en español:

1. Usar el App Shortcut de MiDinero: monto `12.50`, categoría Comida. Anotar si iOS
   pregunta ambos, si muestra confirmación y si mantiene la app fuera del foreground.
2. Abrir MiDinero y comprobar **un solo movimiento**, total, reporte y categoría.
3. Terminar MiDinero desde el selector y repetir. Reabrir y comprobar persistencia.
4. Repetir desde Siri y desde el icono de pantalla de inicio del atajo.
5. Ejecutar dos gastos seguidos antes de abrir MiDinero: deben aparecer ambos.
6. Probar monto inválido, cancelación antes de guardar, nota vacía y nota de 501 caracteres.
7. Ejecutar bloqueado: se espera desbloqueo; cancelar la autenticación no debe guardar.
8. Ejecutar con modo avión para comprobar que el guardado no depende de red. El
   reconocimiento de Siri puede tener requisitos propios: usar Atajos para aislarlo.
9. Probar el paso de descripción de [APP_INTENTS.md](APP_INTENTS.md) y documentar
   la UX real de esa versión de iOS. Comprobar también locale es_PE y uno con coma decimal.

Las pruebas `ExpenseIntentWriter` comprueban escritura y reapertura.
`AppIntentTests` también llama a `perform()` y verifica el almacén usado por la app.
Xcode procesa la metadata al compilar. Estas comprobaciones no ejecutan resolución,
autenticación ni `perform()` a través del runtime de Shortcuts/Siri.
