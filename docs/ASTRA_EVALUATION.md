# Evidencia de ejecución del agente

Fecha de la sesión: 21 de septiembre de 2026. Las secciones iniciales conservan
el registro histórico de la **fase 1 realizada en Windows**. Los resultados
posteriores de macOS/Xcode están en **Fase 2 — Validación Xcode**, al final del
documento; sustituyen los pendientes de compilación de la fase 1.

## Entorno detectado

- Directorio: `C:\Users\Eduardo\Desktop\EduDev\MiDinero`.
- Estado inicial: directorio vacío, sin repositorio Git. Se ejecutó `git init`.
- Windows 11 Pro, versión `10.0.26200`, 64 bits; PowerShell.
- Python 3.12.6, Node 24.18.0, Git 2.47.1.windows.2, ripgrep 15.2.0.
- Git Bash disponible en `C:/Program Files/Git/bin/bash.exe`.
- Pillow 10.4.0 ya instalado; se usó solo para producir el PNG del icono.
- `Get-Command swift,xcodebuild,xcrun` no encontró esas herramientas.
- `wsl --list --quiet` informó que WSL no está instalado (salida 1).
- Sin acceso a macOS, Xcode, SDK iOS, Simulator ni a una sesión de iPhone utilizable.
  No se encontró un compilador Swift accesible.
- Acceso a documentación oficial de Apple por web y su JSON de documentación.
- Se instalaron herramientas de análisis opcionales únicamente en `.validation-tools/`
  (ignorada por Git): tree-sitter 0.25.2, tree-sitter-swift 0.7.3,
  openstep-parser 2.0.3. No son dependencias del producto ni del build iOS.

## Trabajo realizado

- Proyecto `MiDinero.xcodeproj` con scheme compartido y tres targets: MiDinero,
  MiDineroTests, MiDineroUITests. Configuraciones Debug y Release, iPhone/iOS 17.
- 20 archivos Swift de aplicación: dominio, persistencia, estado, vistas, intents y CSV.
- Dinero en unidades menores, moneda/precisión por movimiento; cálculos `Decimal`.
- Diez categorías persistidas con IDs estables y símbolos. Sin fixtures en producción.
- Registro de gasto/ingreso, nota opcional y fecha; validación, feedback, edición,
  confirmación de borrado y protección frente a descartar edición accidentalmente.
- Inicio con datos reales; historial ordenable; reporte por mes, promedios,
  porcentajes, categoría principal y barras Charts con equivalente textual accesible.
- Configuración SwiftData única, guardado explícito, propagación de errores y recarga
  al volver a primer plano o al guardar. No se usa memoria como sustituto ante fallos.
- App Intent con monto/categoría obligatorios, descripción opcional y confirmación
  después de guardar; AppEntity consultable, frases de App Shortcut y ayuda en la app.
- CSV con UTF-8 BOM, comillas escapadas, CRLF, fechas ISO 8601 UTC y protección contra
  interpretación de texto como fórmula en hojas de cálculo. Exportación por Archivos.
- 24 pruebas escritas: 17 del núcleo Foundation, 6 de persistencia/servicio de intent,
  1 de interfaz con registro/reapertura/edición/reporte/eliminación.
- Generador determinista del proyecto con biblioteca estándar de Python; proyecto
  generado incluido. Icono RGB 1024×1024, plist y manifiesto de privacidad incluidos.
- README, límites de App Intents, guía de validación y script reproducible para Mac.

**Las pruebas están implementadas, pero ninguna XCTest/XCUITest se ejecutó aquí.**

## Decisiones autónomas

1. iOS 17: mínimo que permite SwiftData, Observation y el feedback de SwiftUI usado.
   Lenguaje Swift 5 con compilador 5.9 o superior y comprobación completa de concurrencia.
2. `Int64` para almacenamiento monetario y `Decimal` para agregados; no `Double` en
   lógica financiera. El único paso a `Double` es para dibujar la longitud de barras.
3. Texto decimal en App Intents: conserva precisión y evita depender de conversiones
   binarias. Acepta coma/punto decimal sin miles; máximo 999 999 999.99 PEN por entrada.
4. Un repositorio concreto y snapshots de valores, sin una colección de protocolos
   de infraestructura. SwiftData y modelos permanecen en `MainActor`.
5. App e intent en el mismo target/sandbox; ningún App Group ni extensión ficticia.
   Preparación de widgets mediante documentación de signing y migración futura.
6. Calendario gregoriano, zona horaria del dispositivo e intervalo mensual semiabierto.
   Promedio definido como gasto / número de días con al menos un gasto.
7. No mezclar monedas en reportes. PEN es la única moneda disponible en la UI inicial.
8. Nota opcional sin pregunta automática; documentación de una variante con acciones
   nativas de Atajos. No se generó un `.shortcut` no firmado ni se inventó una API.
9. Desbloqueo local para ejecutar el intent; CloudKit desactivado y directorio excluido
   de backups. La exportación es la única copia externa del MVP y requiere acción explícita.
10. Listas, NavigationStack, TabView y sheets de SwiftUI; SF Symbols, colores semánticos,
    Dynamic Type y signos/etiquetas que distinguen ingresos/gastos sin depender del color.
11. Se siguió el brief visual explícito y la autonomía solicitada; no se abrieron rondas
    de aprobación de diseño ni se sustituyó el producto por mockups.

## Validación realizada

Comandos ejecutados y resultados observados:

| Comando / comprobación | Resultado real |
| --- | --- |
| `Get-Location`, `Get-ChildItem -Force`, `git status --short` inicial | Directorio vacío; Git informó que no era repositorio |
| `Get-CimInstance Win32_OperatingSystem`, comandos `--version` | Herramientas y versiones descritas arriba |
| `git init` | Repositorio local creado, sin commit ni remoto |
| `python scripts/generate_icon.py` | Icono y catálogos generados; PNG inspeccionado visualmente |
| `python scripts/generate_project.py` | `.pbxproj`, workspace y scheme compartido generados |
| `python scripts/verify_static.py` | 73 comprobaciones estructurales aprobadas; 20 fuentes Swift de app incluidas |
| `python scripts/verify_static.py --parse-swift --parse-project` con PYTHONPATH local | 27 archivos Swift sin nodos gramaticales ERROR/missing; OpenStep leyó 94 objetos, tres targets y referencias existentes |
| `python -m compileall -q scripts` | Salida 0, sin errores de sintaxis Python |
| Git Bash `-n scripts/validate_mac.sh` | Salida 0, sintaxis Bash válida |
| `git diff --check` después de normalizar los archivos | Sin errores de whitespace |
| Revisión del diff completo por grupos de archivos | Modelos, dinero, repositorio, intents, UI, tests, recursos, scripts, proyecto y documentos revisados |

El parser OpenStep es independiente del generador: comprueba que el proyecto se
puede analizar, pero **no equivale a abrirlo con Xcode**. Tree-sitter solo comprueba
gramática, no tipos, disponibilidad binaria ni expansión de macros.

Incidencias y correcciones durante la validación:

- La primera instalación del parser pedía tree-sitter-swift 0.7.1, versión no disponible;
  se instaló la versión publicada 0.7.3 y se documentó la versión exacta.
- Tree-sitter señaló una expresión `as? String ??` en la prueba UI; se añadieron
  paréntesis explícitos. No se presenta como error descubierto por un compilador Swift.
- `git diff --check` detectó líneas vacías finales; se normalizó UTF-8/LF y fin de archivo.
- Revisión de código: contextos con variable local explícita, redondeo de presentación
  definido, año visible en fechas, cálculo de resumen una vez por evaluación de la vista,
  identificadores accesibles para tests y cifras sin verde de bajo contraste.
- El cambio de monto después de elegir categoría ahora muestra el error de validación;
  no depende solo de deshabilitar Guardar.

Referencias oficiales consultadas y availability revisada:

- [ModelConfiguration](https://developer.apple.com/documentation/swiftdata/modelconfiguration):
  configuración con URL propia y `cloudKitDatabase: .none`; inicializador desde iOS 17.
- [Parámetros de App Intents](https://developer.apple.com/documentation/appintents/adding-parameters-to-an-app-intent):
  diferencia entre parámetros requeridos y opcionales.
- [needsValueError](https://developer.apple.com/documentation/appintents/intentparameter/needsvalueerror(_:)):
  relanzar resolución antes de guardar; disponible desde iOS 16.
- [Autenticación local](https://developer.apple.com/documentation/appintents/intentauthenticationpolicy/requireslocaldeviceauthentication):
  requiere desbloqueo del dispositivo; disponible desde iOS 16.
- [ShortcutsLink](https://developer.apple.com/documentation/appintents/shortcutslink):
  inicializador con acción por defecto, disponible desde iOS 16.
- [openAppWhenRun](https://developer.apple.com/documentation/appintents/appintent/openappwhenrun):
  obsoleto desde iOS 26; se conserva el comportamiento por defecto de AppIntent.
- [Interactividad y procesos de widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities):
  relevante para el futuro segundo target, no implementado en este slice.

## Limitaciones

- No se ejecutó `xcodebuild`, `swift test`, XCTest, XCUITest, Simulator ni previews.
  No hay resultados `.xcresult`, screenshots de la app, mediciones de rendimiento ni
  evidencia de persistencia real en iPhone en esta sesión.
- No se pudo verificar expansión `@Model`/`#Predicate`, type checking SwiftUI,
  warnings del SDK, metadata de App Intents, firma, Siri, preguntas del sistema o ejecución
  en segundo plano. Son riesgos pendientes, no comprobaciones aprobadas.
- No se pudo medir contraste, layout con teclado/Dynamic Type, VoiceOver ni hápticos
  en una pantalla renderizada. La revisión visual se limitó al recurso del icono.
- Los tests del servicio de intent no invocan el runtime real de Shortcuts/Siri.
- Historial completo en memoria, sin paginación. No se probó con gran volumen.
- Sin sincronización, importación/restauración, categorías personalizadas en UI ni
  migración versionada. No hay soporte multiusuario o multicurrency en la interfaz.
- La base excluida de backups se pierde al desinstalar; CSV no tiene importador todavía.
- La receta avanzada de Atajos está documentada, pero no se pudo ejecutar su editor.

## Pendientes

1. Abrir el proyecto en un Mac y ejecutar `scripts/validate_mac.sh` con UUID de Simulator.
   Corregir cualquier error real de compilador/macros/tests antes de considerar validado el slice.
2. Ejecutar la matriz visual, accesibilidad y errores de almacenamiento de `VALIDATION.md`.
3. Instalar con signing propio en iPhone y verificar el camino crítico:
   Atajo → guardar → abrir app → movimiento único → totales → reporte, con app terminada.
4. Registrar la UX real de la descripción opcional y reconocimiento numérico de Siri.
5. Tras validar el núcleo: migraciones versionadas y recuperación/importación local
   antes de extender esquema; medir volumen antes de introducir paginación.

## Archivos principales

| Archivo | Papel |
| --- | --- |
| `MiDinero.xcodeproj` | Proyecto listo para abrir, sin generador externo obligatorio |
| `MiDinero/Domain/Money.swift` | Parseo monetario y formato |
| `MiDinero/Domain/MonthlySummary.swift` | Agregación mensual común para inicio y reporte |
| `MiDinero/Persistence/Models.swift` | FinancialTransaction y Category persistidos |
| `MiDinero/Persistence/PersistenceController.swift` | URL, configuración local y contenedor |
| `MiDinero/Persistence/TransactionRepository.swift` | Lectura, validación, guardado, edición y borrado |
| `MiDinero/App/LedgerStore.swift` | Estado observable y refresco de snapshots |
| `MiDinero/Features/Transactions/TransactionEditorView.swift` | Registro rápido y edición |
| `MiDinero/Intents/RegisterExpenseIntent.swift` | Acción de Atajos y servicio de escritura |
| `MiDinero/Intents/ExpenseCategoryEntity.swift` | Resolución de categorías persistidas |
| `MiDinero/Services/TransactionExporter.swift` | Interfaz de formatos y CSV |
| `MiDineroTests`, `MiDineroUITests` | Pruebas escritas, no ejecutadas aquí |
| `scripts/verify_static.py`, `scripts/validate_mac.sh` | Comprobaciones separadas según plataforma |

## Fase 2 — Validación Xcode

### Entorno macOS

GitHub Actions, repositorio [AloneDc/MiDinero](https://github.com/AloneDc/MiDinero),
runner `macos-15`. Edición y seguimiento desde Windows mediante Git y la API de
GitHub, con autenticación existente y sin almacenar tokens en archivos.

Entorno observado: macOS 15.7.9 (24G830), arquitectura arm64, Xcode 16.4 (16F6),
Apple Swift 6.1.2 (`swiftlang-6.1.2.1.2 clang-1700.0.13.5`), SDK Simulator 18.5.
Se registran versiones reales, SDKs, revisión, targets y scheme en cada intento.
El runtime se elige de `simctl` y `xcodebuild -showdestinations`, priorizando el
SDK instalado; el UUID y la arquitectura se pasan explícitamente a Xcode.

### Build

El [quinto y último intento](https://github.com/AloneDc/MiDinero/actions/runs/35658862995),
revisión `eeeb4b02cfd38d8a96cf22b14db4aa670396ed05`, terminó correctamente:

| Operación real de Xcode | Resultado | Salida |
| --- | --- | --- |
| `-list -project MiDinero.xcodeproj` | Tres targets y scheme MiDinero reconocidos | 0 |
| Debug `build` | `BUILD SUCCEEDED` | 0 |
| `build-for-testing` | `TEST BUILD SUCCEEDED` | 0 |
| `test-without-building` | `TEST EXECUTE SUCCEEDED` | 0 |
| Release `build`, arm64 y x86_64 | `BUILD SUCCEEDED` | 0 |

El pipeline se ejecutó con `python3 scripts/ci/validate_xcode.py`. Comandos de build
(variables que representan los valores reales de esta ejecución):

```bash
DD=/Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData
EVID=/Users/runner/work/MiDinero/MiDinero/build/ci-evidence
DEST='platform=iOS Simulator,id=22A3039C-6A45-47F4-82D4-80C58CA94379,arch=arm64'
BASE=(xcodebuild -project MiDinero.xcodeproj -scheme MiDinero
  -configuration Debug -destination "$DEST" -destination-timeout 120
  -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete)
"${BASE[@]}" -resultBundlePath "$EVID/Build.xcresult" build
"${BASE[@]}" -resultBundlePath "$EVID/BuildForTesting.xcresult" build-for-testing
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete \
  -resultBundlePath "$EVID/Release.xcresult" build
```

Los [comandos exactos expandidos](evidence/phase2/commands.md),
[argumentos y códigos de salida](evidence/phase2/result.json) y
[procedencia/versiones/hash del artefacto](evidence/phase2/provenance.json)
quedan conservados en Git. El UUID anterior es evidencia histórica: al reproducir,
el script detecta un dispositivo disponible en el Mac actual.

### Tests

Resultado real del último intento, contrastando enumeración Xcode, salida XCTest
y `xcresulttool get test-results summary`: **26 descubiertas, 26 ejecutadas,
26 aprobadas, 0 fallidas, 0 omitidas y 0 fallos esperados**.

Comandos ejecutados con `BASE` y `EVID` definidos arriba:

```bash
"${BASE[@]}" test-without-building -enumerate-tests -test-enumeration-style flat \
  -test-enumeration-format text -test-enumeration-output-path "$EVID/discovered-tests.txt"
"${BASE[@]}" -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -resultBundlePath "$EVID/Tests.xcresult" test-without-building
xcrun xcresulttool get test-results summary --path "$EVID/Tests.xcresult"
```

Se conservan [inventario descubierto](evidence/phase2/discovered-tests.txt),
[resumen nativo](evidence/phase2/test-summary.json) y
[resultado individual de cada test](evidence/phase2/test-details.json).

| Grupo | Ejecutadas / aprobadas |
| --- | --- |
| MoneyTests | 7 / 7 |
| MonthlySummaryTests | 7 / 7 |
| CSVExporterTests | 3 / 3 |
| PersistenceTests | 7 / 7 |
| AppIntentTests | 1 / 1 |
| MiDineroUITests | 1 / 1 |

Incluye guardar gasto e ingreso, totales/balance mensual, categorías/porcentajes,
precisión, edición, eliminación, cambio/límites de mes, año bisiesto y DST.
La prueba nueva del intent ejecutó `perform()`, comprobó identidad del contenedor,
lectura desde `LedgerStore`, actualización del resumen y reapertura del archivo.
XCUITest registró, cerró/reabrió, editó, comprobó el reporte, canceló y confirmó el
borrado, y volvió a abrir. Se inspeccionaron tres capturas reales en iPhone SE
(3.ª generación), iOS 18.5: [Inicio S/ 12.50](evidence/phase2/home-after-save.png),
[reporte S/ 20.00](evidence/phase2/report-after-edit.png) y
[estado vacío final](evidence/phase2/empty-after-delete.png).
No se ejecutó por separado `swift test`; las 17 pruebas del núcleo sí se ejecutaron
dentro del target iOS. Ninguna prueba del scheme quedó sin ejecutar.

### Errores encontrados y correcciones

| Intento | Evidencia y corrección |
| --- | --- |
| [1 / 381b45c](https://github.com/AloneDc/MiDinero/actions/runs/35656213139) | `-showdestinations` solo anunció destinos genéricos antes de inicializar CoreSimulator. Se cambió el orden, se indicó SDK Simulator y se contrastaron destinos y dispositivos instalados. |
| [2 / a46f0af](https://github.com/AloneDc/MiDinero/actions/runs/35656506137) | Falló `testEmptyExportStillHasHeader`: Foundation de Apple consume el BOM al decodificar UTF-8. La prueba ahora compara bytes completos, incluyendo BOM y CRLF. El exportador no cambió. |
| 2 / a46f0af | Warnings de key paths no `Sendable` en `SortDescriptor` y `#Predicate`. Se habilitó `InferSendableFromCaptures`, manteniendo comprobación completa de concurrencia, MainActor y predicados. Sin `@unchecked Sendable`, `@preconcurrency` ni supresión de diagnósticos. |
| 2 / a46f0af | Warnings al quitar símbolos de bibliotecas XCTest firmadas del SDK. Debug ahora usa `COPY_PHASE_STRIP=NO`, conservando los símbolos de depuración. |
| [3 / 06a7ac6](https://github.com/AloneDc/MiDinero/actions/runs/35657567092) | `TransactionEditorView.swift:43`: el compilador no pudo resolver la expresión en tiempo razonable tras habilitar la inferencia. Se dividió la vista en secciones y el botón usa una closure explícita. Mismo diseño y comportamiento. |
| 3 / 06a7ac6 | Xcode anunció varios destinos para el mismo UUID (arm64/x86_64). Se añadió la arquitectura detectada a `-destination`. |
| [4 / 57c6aa0](https://github.com/AloneDc/MiDinero/actions/runs/35658255232) | Debug, Release y 26 tests aprobados. Se corrigieron después dos avisos menores: `var intent` pasó a `let` (setter de `@Parameter` no mutante) y `-showBuildSettings` usa también el destino/arquitectura concretos. |
| [5 / eeeb4b0](https://github.com/AloneDc/MiDinero/actions/runs/35658862995) | Se repitió el pipeline completo: Debug, tests y Release aprobados; los dos avisos menores desaparecieron. |

La inferencia de key paths está descrita en
[SE-0418](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0418-inferring-sendable-for-methods.md).
También se acotaron los comandos y se hizo flush inmediato de logs para conservar
diagnósticos ante interrupciones. La cancelación del intento 2 no se cuenta como éxito.

### Warnings

La ejecución final no produjo warnings de Swift/concurrencia ni errores de compilador.
Permanece **un aviso** de la herramienta de Apple en **MiDineroUITests**:
`Metadata extraction skipped. No AppIntents.framework dependency found`.
Ese target no contiene intents. La app sí generó metadata y entrenó ambas frases
en Debug y Release; no se desactivó su procesamiento para silenciar el aviso.

El log de ejecución también registra Launch Services `NSOSStatusErrorDomain -10814`
al actualizar parámetros de App Shortcuts en Simulator. No se presenta el descubrimiento
de Atajos como validado: requiere prueba física. Los errores CoreData de ruta inválida
proceden del test deliberado `testStorageErrorPropagatesInsteadOfFallingBackToMemory`,
que aprobó; no son fallos de persistencia durante el flujo normal.

### App Intents

El build real procesó AppIntent, parámetros, AppEntity/EntityStringQuery,
AppShortcutsProvider, parameter summary, `needsValueError`, política de autenticación
y metadata. El log registra entrenamiento de ambas frases en español y copia a
`MiDinero.app/Metadata.appintents/`.

La prueba aprobada invoca `perform()` directamente. No equivale al runtime de
Siri/Atajos: quedan pendientes en iPhone firmado el descubrimiento del shortcut,
resolución de monto/categoría/nota, cancelación, desbloqueo y ejecución con la app
terminada, seguida de un movimiento único, totales y reporte actualizados.

### Persistencia

App e intent pertenecen al target `MiDinero`, sin extensión. Ambos obtienen
`PersistenceController.shared.container()`, que cachea una única instancia en
MainActor y configura `Application Support/MiDinero/MiDinero.store` explícitamente.
Cada operación crea un contexto de ese contenedor y guarda antes de confirmar.
La app recarga al guardar y al activarse. No se añadió App Group: no existe otro
target de producto que requiera compartir sandbox. Un widget futuro necesitará
capability y migración, no un almacén independiente.

Las pruebas usan memoria o archivos temporales. TestAction inyecta un UUID de pruebas;
la prueba de `perform()` exige esa variable antes de usar el singleton. UI usa otro
UUID por ejecución y lo conserva al relanzar. No se lee ni borra la base personal.

### Proyecto y comprobaciones complementarias

- Scheme compartido MiDinero, targets app/unit/UI, dependencias y test host.
- 20 fuentes de app, 6 archivos unit/integration, 1 de UI, incluidos en Sources;
  deployment target iOS 17, Swift 5 con compilador Swift 6 e inferencia SE-0418.
- Xcode procesó Assets/AppIcon, Info.plist, PrivacyInfo.xcprivacy, macros SwiftData,
  SwiftUI y Charts, y enlazó frameworks mediante Swift autolinking.
- Bundle IDs `com.eduardo.MiDinero`, `.MiDineroTests`, `.MiDineroUITests`.
  Simulator con `CODE_SIGNING_ALLOWED=NO`; sin entitlements/App Groups/iCloud/SiriKit.
- 75 assertions estructurales, 96 objetos PBX y 28 archivos Swift analizados.
  Cinco tests Python del parser aprobados; actionlint 1.7.12 sin errores.
  Son comprobaciones auxiliares, separadas de XCTest/XCUITest.
- Workflow con logs, comandos, códigos de salida, inventario descubierto, JSON,
  `.xcresult` y capturas UI; retención de artefactos de 14 días. Cambios solo de
  documentación no repiten CI; cambios de código, proyecto o pipeline sí lo ejecutan.
- Ninguna característica ni prueba fue eliminada o deshabilitada.
- Se revisó el diff de código, proyecto, tests, CI y documentación, y los logs
  originales de las ejecuciones. La entrega final añade solo documentación y
  evidencia al commit de código validado; no modifica binarios ni pruebas.

### Límites y siguiente comprobación

No hubo iPhone físico, signing de dispositivo, ejecución real de Siri/Atajos,
previews ni pruebas de VoiceOver, hápticos o modo oscuro. No se ejecutó un runtime
iOS 17; se compiló con deployment target 17 y se probó en Simulator 18.5.
El siguiente paso es instalar en un iPhone firmado y completar la matriz de
Atajos de [VALIDATION.md](VALIDATION.md), investigando especialmente el diagnóstico
Launch Services observado en Simulator. No se declara aprobado ese recorrido del sistema.

### Estado final

COMPILED_AND_TESTED

Dos ejecuciones completas aprobadas; la última corresponde a `eeeb4b0`.

## Fase 3 — Device Readiness

### Alcance y entorno

Preparación para dispositivo y distribución, sin funcionalidades, pantallas ni
cambios de dominio/UI. Entorno local: Windows, sin Xcode ni iPhone. Se reutilizó
el acceso autorizado a `AloneDc/MiDinero` para push y GitHub Actions en macOS 15.
No se crearon certificados, cuentas Apple ni secretos; no se instaló en un teléfono.

### Cambios y decisiones autónomas

- Auditoría completa en [DEVICE_READINESS.md](DEVICE_READINESS.md): bundle/versiones,
  mínimo iOS, signing, capabilities, metadata, almacenamiento, icono, orientación,
  familia, frameworks, tests, privacidad y distribución.
- `SKIP_INSTALL=NO` explícito en la app y `YES` en los tests, mantenidos en el
  generador y el proyecto. El scheme ya archivaba únicamente la app.
- `ITSAppUsesNonExemptEncryption=false`: el producto no implementa cifrado propio
  ni usa SDKs criptográficos; no se desactiva la protección del dispositivo.
- iOS 17 sigue siendo el mínimo. Xcode 26.2/SDK 26.2 para device archive y futura
  distribución, porque los requisitos actuales de ASC superan el Xcode 16.4 de
  fase 2. La matriz conserva también la validación de Xcode 16.4.
- Se añadieron comprobaciones de archive reales y un workflow TestFlight separado,
  manual y bloqueado sin configuración. Estrategia p12 + perfil App Store + clave
  de equipo ASC, keychain efímero y limpieza; no depende de Fastlane.
- `.gitignore` ampliado, comprobación de blobs del índice para nombres privados y
  claves/tokens conocidos. Es una protección adicional, no garantía universal.
- [IPHONE_TEST_PLAN.md](IPHONE_TEST_PLAN.md) documenta altas S/ 10 Comida y S/ 15
  Transporte, deltas/porcentajes, cierre, Siri, background, app terminada y reinicio.
  Todas las pruebas físicas siguen sin marcar.

### Signing y entitlements actuales

Proyecto: `CODE_SIGN_STYLE=Automatic`, sin `DEVELOPMENT_TEAM`, perfil ni identidad
configurados. Bundle `com.eduardo.MiDinero`, versión `0.1.0`, build `1`.
Ningún entitlement personalizado ni extensión. No se añadieron App Groups,
iCloud, SiriKit ni modos de background. El archive sin firma registra identidad
y Team vacíos; no contiene perfil ni `_CodeSignature`.

Development requiere Mac/Xcode compatible, Apple Account/Team, bundle ID disponible,
certificado Apple Development y perfil con el dispositivo (Xcode puede gestionarlos),
iPhone emparejado y Developer Mode. Personal Team sirve para prueba personal con
caducidad; no permite TestFlight. No se requieren certificados de distribución para
la primera instalación desde Xcode.

TestFlight requiere membresía Developer Program, App ID y app ASC con ID coincidente,
certificado Apple Distribution **con clave privada**, perfil App Store válido,
clave API de equipo para el workflow, build nuevo, procesamiento Apple y asignación
de tester. Lista exacta de variables/secrets, instrucciones y fuentes oficiales en
[DEVICE_READINESS.md](DEVICE_READINESS.md#b-distribuir-por-testflight).

### App Intents y persistencia física

La metadata generada por Xcode 26.2 dentro del archive confirma
`RegisterExpenseIntent`, `isDiscoverable=true`, `openAppWhenRun=false`, monto y
categoría obligatorios, descripción opcional, provider y dos frases con nombre
de app. Esto prueba extracción/empaquetado, no indexación en el iPhone.

App e intent llaman a `PersistenceController.shared.container()` en el mismo target.
URL resuelta por FileManager: `<sandbox>/Library/Application Support/MiDinero/MiDinero.store`;
configuración `MiDinero`, schema FinancialTransaction/Category, URL explícita,
CloudKit deshabilitado. Contextos nuevos, MainActor, save explícito y recarga al
activar escena. No hace falta App Group. Los tests usan otra carpeta solo en Debug.
La carpeta financiera está excluida de backup; cambiar ID/desinstalar no migra datos.

El comportamiento físico esperado y los límites de Siri, resolución de monto,
nota opcional, autenticación y ejecución en segundo plano están documentados.
El diagnóstico Launch Services de Simulator no se ha ocultado ni se considera
resuelto por la compilación del archive.

### Validación de esta fase

Primera ejecución: [35660821233](https://github.com/AloneDc/MiDinero/actions/runs/35660821233),
revisión `3e7a1d8fd8b25c5ceb8f4a3771b85554ed3eabf4`.
El job de dispositivo completó Release build y archive con códigos 0 en macOS
15.7.9, Xcode 26.2 (17C52), SDK iPhoneOS 26.2. Archivo arm64, mínimo 17.0,
Info.plist/icono/privacy manifest/metadata presentes, frameworks SwiftData,
AppIntents, Charts y SwiftUI enlazados, UUID del dSYM coincidente. Sin warnings.
`codesign -dvv` devolvió 1: resultado esperado que confirma falta de firma.
No se intentó exportar ni subir ese archive sin firma.

Comandos locales realizados:

```text
python scripts/generate_project.py
python scripts/verify_static.py --parse-swift --parse-project
python -m unittest discover -s scripts/ci -p 'test_*.py' -v
python -m py_compile scripts/ci/validate_device.py scripts/ci/distribute_testflight.py
.validation-tools/actionlint.exe .github/workflows/ios-ci.yml .github/workflows/ios-testflight.yml
python scripts/check_repository_security.py
git diff --check
```

75 comprobaciones estructurales, 96 objetos PBX resueltos, 28 archivos Swift con
gramática válida, seis tests Python aprobados. Actionlint y py_compile sin errores.
La prueba de seguridad usa entorno vacío: no crea credenciales ficticias ni ejecuta
comandos Apple. Diez rutas de prueba de `.gitignore` quedaron excluidas; no se
crearon esos archivos. Revisión adicional de 95 blobs históricos: sin patrones de
claves/tokens configurados. No sustituye un análisis exhaustivo de todos los secretos
posibles. Diff revisado antes de publicar; sin código Swift de producto modificado.

### Límites y pendientes

No se ha demostrado firma, exportación IPA, upload, aceptación/procesamiento de ASC,
instalación física ni ejecución del intent desde Atajos/Siri del sistema. El workflow
de distribución solo tiene validación estática y del bloqueo sin credenciales.
No se han configurado `TESTFLIGHT_ENABLED`, environment de distribución, secretos
Apple ni protección de ese environment. No hay prueba en runtime iOS 17 físico.

El siguiente paso operativo es seleccionar Team en Xcode e instalar en el iPhone,
siguiendo el plan. Si no se dispone de Mac, preparar los recursos de Developer
Program/ASC y los secrets del workflow permite la vía TestFlight. No se puede
garantizar que la prueba física no descubra un problema todavía no observable.

### Archivos principales de la fase

| Archivo | Evidencia o responsabilidad |
| --- | --- |
| `scripts/ci/validate_device.py` | Build/archive de dispositivo y validación estructural real |
| `.github/workflows/ios-ci.yml` | Matriz de Simulator y job de archive |
| `.github/workflows/ios-testflight.yml` | Distribución manual futura, protegida por configuración |
| `scripts/ci/distribute_testflight.py` | Preflight, keychain temporal, archive firmado, export y upload |
| `scripts/ci/test_distribution_safety.py` | Bloqueo sin credenciales, sin tocar Apple ni crear archivos |
| `scripts/check_repository_security.py` | Revisión del índice sin imprimir secretos |
| `docs/DEVICE_READINESS.md` | Auditoría y requisitos concretos de ambas vías de instalación |
| `docs/IPHONE_TEST_PLAN.md` | Checklist físico pendiente, con resultados esperados |
