# MiDinero

Finanzas personales para iPhone: registrar un gasto en segundos, desde la app o
Atajos, y verlo en el historial y el reporte mensual. SwiftUI, SwiftData, App Intents
y Charts; sin cuentas, backend, sincronización ni dependencias externas de ejecución.

**Estado:** vertical slice implementado, con validación Xcode automatizada en
[GitHub Actions](https://github.com/AloneDc/MiDinero/actions/workflows/ios-ci.yml).
Resultados reales y límites en [ASTRA_EVALUATION.md](docs/ASTRA_EVALUATION.md#fase-2--validación-xcode).

## Abrir y ejecutar

- Mac con Xcode 16 o posterior para el pipeline de evidencia; Simulator iOS 17 o posterior.
- iPhone con iOS 17 o posterior. Elige una versión de Xcode compatible con su iOS.
- Abre `MiDinero.xcodeproj`, selecciona el scheme **MiDinero** y un iPhone Simulator;
  ejecuta con **⌘R**. El proyecto está incluido; no necesitas generadores ni paquetes.
- Para un iPhone físico, selecciona tu Team en Signing & Capabilities, cambia el
  bundle ID `com.eduardo.MiDinero` si es necesario y activa Developer Mode.

Solo se requiere signing normal. No añadas iCloud, App Groups, Background Modes ni
la capability Siri de SiriKit: este slice usa App Intents dentro del target principal.

## Qué incluye

- Registro rápido: monto con teclado decimal → categoría → nota opcional → guardar.
- Ingresos y fecha en «Tipo y fecha»; edición tocando un movimiento.
- Inicio con gastos, ingresos, balance registrado, conteo y categorías principales.
- Historial ordenable; eliminación desde swipe/context menu con confirmación.
- Reportes por mes con barras nativas, porcentajes y promedio por día **con gasto**.
- Intent **Registrar gasto**, confirmación posterior a `save()` y App Shortcut.
- Exportar CSV desde **Movimientos → Opciones → Exportar CSV**, mediante Archivos.
  Tú eliges el destino; un proveedor externo en Archivos supone una exportación explícita.

No hay movimientos precargados. Solo se crean las diez categorías iniciales.

## Probar Registrar gasto

1. Instala y abre MiDinero una vez. Ve a **Inicio → Registra con Atajos o Siri**.
2. Toca el enlace de Atajos o abre **Atajos → Atajos de apps → MiDinero**.
3. Ejecuta **Registrar gasto**. Introduce `12.50` y selecciona **Comida**.
4. Abre MiDinero: debe aparecer un gasto de S/ 12.50 en las tres pantallas.
5. Prueba de nuevo con la app terminada y el iPhone desbloqueado.

Para tener un icono propio, crea un atajo, añade la acción **Registrar gasto** de
MiDinero, configura monto y categoría como **Preguntar cada vez** y usa
**Detalles → Añadir a pantalla de inicio**. También puedes usar la frase
«Siri, registrar gasto en MiDinero» con Siri en español.

La descripción es opcional: iOS no pregunta automáticamente por parámetros
opcionales. Puedes escribirla o elegir **Preguntar cada vez** en el editor del atajo.
Para un paso explícito «Sin descripción / Añadir descripción», sigue
[la receta y las limitaciones de App Intents](docs/APP_INTENTS.md).

## Arquitectura y decisiones

| Carpeta | Responsabilidad |
| --- | --- |
| `Domain` | Dinero exacto, categorías, snapshots y agregaciones mensuales puras |
| `Persistence` | Modelos SwiftData, único contenedor y repositorio con guardado explícito |
| `App` | Estado observable, navegación y recarga tras guardar o volver al foreground |
| `Features` | SwiftUI; ninguna fórmula financiera en las vistas |
| `Intents` | AppEntity de categorías, intent y App Shortcuts |
| `Services` | Contrato de exportación y CSV real |

Importes positivos en unidades menores `Int64`; tipo separado para gasto/ingreso.
Los totales, promedios y porcentajes usan `Decimal`. `Double` aparece únicamente
en la conversión final para dibujar Charts. Cada movimiento guarda código de moneda
y precisión; la UI inicial usa PEN y el reporte nunca suma monedas distintas.

El calendario es gregoriano con zona horaria actual del dispositivo; los meses usan
intervalos `[inicio, siguiente inicio)`. Cambiar de zona horaria puede cambiar el día
o mes local asignado a movimientos próximos a medianoche.

Modelos y contextos se usan en `MainActor`; las vistas reciben valores independientes
de SwiftData. Cada operación usa un contexto nuevo del contenedor compartido. Las
notificaciones de guardado y el regreso al foreground recargan el estado. No hay
fallback silencioso a memoria ni borrado de datos al fallar la apertura.

La base vive en `Application Support/MiDinero/MiDinero.store`, con CloudKit
deshabilitado y el directorio excluido de backups del dispositivo. **Desinstalar la
app o perder el iPhone puede perder los datos; exporta CSV para conservar una copia.**
No hay importación todavía. No se guardan importes/notas en logs. El App Intent
requiere desbloqueo local. La base no añade cifrado propio al que proporciona iOS.

No se usa App Group porque no hay extensiones: app e intent pertenecen al mismo
target. Un futuro widget con proceso propio requerirá un App Group registrado en
ambos targets y una migración probada del almacén; cambiar solo la URL perdería
acceso a los datos existentes. Ver [APP_INTENTS.md](docs/APP_INTENTS.md).

## Pruebas

En Xcode: **⌘U** ejecuta unitarias, persistencia y UI. Desde una terminal en Mac:

```bash
swift test                                 # 17 pruebas del núcleo Foundation
bash scripts/validate_mac.sh               # detecta Xcode, SDK y un iPhone disponible
# Opcional: SIMULATOR_ID=<UUID> bash scripts/validate_mac.sh
```

El script compila Debug y los tests, enumera las pruebas mediante Xcode, ejecuta
XCTest/XCUITest con `.xcresult` y compila Release. Conserva comandos, logs y
resultados en `build/ci-evidence/`; mueve ese directorio antes de repetir localmente.
Los scripts auxiliares usan Python 3.10 o posterior; abrir/compilar desde Xcode no lo requiere.
Las siete pruebas de persistencia usan almacenes temporales o en memoria.
Otra prueba invoca `perform()` directamente y comprueba el contenedor común, la
lectura desde `LedgerStore` y la reapertura del archivo. El scheme de tests usa un
directorio separado; la prueba falla si falta su variable de aislamiento. La prueba
UI usa un directorio con UUID independiente de los datos personales y comprueba
registro, reapertura, edición, reporte, cancelación de borrado y eliminación.

Invocar `perform()` en XCTest no sustituye la resolución y ejecución de Siri/Atajos reales.
La [matriz de validación en Mac/iPhone](docs/VALIDATION.md) cubre esa diferencia.

Comprobaciones disponibles también en Windows:

```powershell
python scripts/verify_static.py
# Opcional: parser gramatical, no compilador
python -m pip install --target .validation-tools tree-sitter==0.25.2 tree-sitter-swift==0.7.3 openstep-parser==2.0.3
$env:PYTHONPATH = (Join-Path (Get-Location) '.validation-tools')
python scripts/verify_static.py --parse-swift --parse-project
```

Si añades archivos Swift, ejecuta `python scripts/generate_project.py` para regenerar
el proyecto de forma determinista. Mantén ajustes de targets en ese script. Los
PNG están incluidos; Pillow solo es necesario para regenerar el icono opcionalmente.

## Límites del slice

Interfaz en español y moneda PEN; límite de S/ 999 999 999.99 por movimiento.
Monto en Atajos es texto para preservar precisión: Siri debe resolver texto numérico,
no palabras como «doce soles»; el tipo de teclado de Atajos lo controla iOS.
No hay categorías personalizadas en la UI, paginación, importación ni restauración.
El historial se carga completo: adecuado para uso personal inicial, pendiente medir
con volúmenes grandes. Antes de cambiar el schema se debe introducir y probar una
migración versionada. CSV está implementado; Excel, Markdown y Notion no lo están.
