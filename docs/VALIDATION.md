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

## Primera ejecución en Mac

```bash
xcode-select -p
xcodebuild -version
xcrun swift --version
open MiDinero.xcodeproj
xcrun simctl list devices available
SIMULATOR_ID=<UUID_DE_UN_IPHONE> bash scripts/validate_mac.sh
```

Instala un runtime iOS compatible en Xcode si la lista está vacía. El script ejecuta:

1. Verificación estructural y las 17 pruebas del núcleo con `swift test`.
2. Listado real de targets/schemes con `xcodebuild -list`.
3. Compilación Debug para el Simulator elegido.
4. XCTest (23 unitarias/integración) y XCUITest (1), con resultado `.xcresult`.
5. Compilación Release para Simulator.

Revisar warnings de concurrencia con `SWIFT_STRICT_CONCURRENCY=complete`, expansión
de SwiftData y extracción de metadata App Intents. Corregir cualquier fallo y repetir
el comando. No eliminar una base personal para hacer pasar una prueba.

## Matriz funcional y visual pendiente

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

Las pruebas `ExpenseIntentWriter` comprueban el servicio de escritura y reapertura,
**no** el sistema de resolución, permisos, extracción de metadata ni la ejecución
de `perform()` a través del runtime de Shortcuts. No se ha simulado ese resultado.
