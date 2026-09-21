# Registrar gasto: contrato y límites

La [auditoría de dispositivo de Fase 3](DEVICE_READINESS.md#auditoría-de-registrar-gasto)
contrasta también la metadata generada en el archive de iPhone. El recorrido físico
se verifica con [IPHONE_TEST_PLAN.md](IPHONE_TEST_PLAN.md), todavía pendiente.

## Camino real implementado

`MiDineroShortcuts → RegisterExpenseIntent → ExpenseIntentWriter → TransactionRepository
→ ModelContext.save() → mismo ModelContainer/URL → LedgerStore.reload()
→ inicio, historial y MonthlySummary`.

La acción pertenece **solo al target MiDinero**, no a una extensión. No necesita un
servidor, una llamada de red ni abrir una pantalla. Se conserva el modo de ejecución
en segundo plano predeterminado de AppIntent (no se solicita foreground). Se evita
usar las APIs de modos más recientes, para admitir iOS 17. El proyecto requiere
Xcode 16 o posterior por la inferencia Sendable del compilador habilitada en fase 2.

Los parámetros obligatorios son texto numérico y una entidad de categoría persistida.
Los IDs estables permiten reutilizar un atajo aunque cambie el nombre visible de una
categoría. La consulta obtiene categorías reales del mismo repositorio y las crea
si el intent se usa antes de la primera apertura de la app.

Se valida **antes** de escribir. Un monto inválido lanza `needsValueError` y solicita
otro valor. Después de guardar no se solicita ningún dato adicional: no se reinicia
`perform()` tras un guardado por un error de resolución. Cada ejecución voluntaria
crea un movimiento nuevo; no se deduplican gastos iguales.

La UI se recarga al activarse la escena y al recibir una notificación local de
guardado. No se asume que una notificación local atraviese procesos: la recarga en
foreground es el punto de reconciliación. Las consultas usan contextos nuevos.

## Qué controla iOS

En la fase 2, Xcode compiló y extrajo la metadata; XCTest ejecutó `perform()` y
comprobó persistencia compartida. Simulator registró Launch Services `-10814` al
actualizar parámetros del App Shortcut. El descubrimiento y la ejecución a través
de Siri/Atajos siguen pendientes de iPhone físico; ver la
[evidencia y los límites](ASTRA_EVALUATION.md#fase-2--validación-xcode).

- Los parámetros no opcionales sin valor pueden provocar una pregunta del sistema.
  La nota `String?` no provoca una pregunta automática; esto está documentado por
  Apple en [Adding parameters to an app intent](https://developer.apple.com/documentation/appintents/adding-parameters-to-an-app-intent).
- No se puede imponer un teclado SwiftUI personalizado al diálogo de Shortcuts/Siri.
  El monto es `String` deliberadamente, para no introducir aproximaciones binarias.
  Se aceptan `12.50` o `12,50`, sin miles, signos ni símbolos monetarios. En el atajo
  se puede conectar una acción nativa **Solicitar entrada** de tipo Número, comprobando
  que su representación resultante no incluya agrupación. La opción más predecible
  para el primer slice es entrada de texto con dígitos.
- [requiresLocalDeviceAuthentication](https://developer.apple.com/documentation/appintents/intentauthenticationpolicy/requireslocaldeviceauthentication)
  exige desbloquear el iPhone. No se promete registrar desde un teléfono bloqueado.
- `openAppWhenRun` está obsoleto en SDKs recientes; se utiliza el comportamiento
  de fondo predeterminado compatible con iOS 17. Referencia:
  [AppIntent](https://developer.apple.com/documentation/appintents/appintent).
- La disponibilidad de Siri, el reconocimiento de frases en español, las preguntas
  exactas y las pantallas de permisos dependen del sistema. Solo se podrán confirmar
  al instalar y ejecutar en un iPhone. Las palabras de Siri no se procesan con IA propia.

## Atajo con decisión opcional de descripción

Para reproducir monto → categoría → nota opcional con control explícito:

1. Crea un atajo llamado **Registrar gasto**.
2. Añade **Solicitar entrada** (Texto): «¿Cuánto gastaste?»; guarda la respuesta en
   una variable **Monto**.
3. Añade **Elegir del menú**: Comida, Transporte, Compras, Entretenimiento, Hogar,
   Servicios, Educación, Salud, Tecnología, Otros. En cada rama asigna ese nombre
   a una variable **Categoría**. Esta lista es manual: debe mantenerse si se cambian categorías.
4. Añade **Elegir del menú** con **Sin descripción** y **Añadir descripción**.
5. En **Sin descripción**, ejecuta **Registrar gasto** de MiDinero con **Monto**,
   **Categoría** y descripción vacía. En **Añadir descripción**, usa **Solicitar entrada**
   (Texto), y ejecuta la misma acción pasando su resultado como descripción.
6. La categoría de texto se resuelve por `EntityStringQuery`; si iOS no conecta esa
   variable automáticamente, selecciona **Preguntar cada vez** para Categoría en las
   dos acciones y omite el paso 3. Esta variante pregunta categoría después de la nota.
7. En Detalles, selecciona **Añadir a pantalla de inicio**.

La alternativa mínima recomendada es una sola acción, monto/categoría configurados
como **Preguntar cada vez**, y descripción vacía. No se entrega un archivo `.shortcut`
fabricado: la importación/firma y la resolución de variables deben verificarse en iOS.

## Almacenamiento y futuras extensiones

Un App Intent integrado en el target principal utiliza su sandbox. No se añade un
App Group sin un segundo target que lo necesite. En una futura extensión WidgetKit:

1. Registrar `group.<bundle-id>` en el Apple Developer portal y activar App Groups
   para app y widget con el mismo identificador y Team.
2. Resolver el directorio mediante `containerURL(forSecurityApplicationGroupIdentifier:)`.
3. Migrar de forma coordinada el store existente y sus archivos SQLite auxiliares;
   no copiar una base abierta ni cambiar la URL y arrancar vacía. Añadir backup y
   pruebas de migración antes de distribuir la actualización.
4. Definir quién ejecuta cada intent y cómo se actualizan widgets y contextos entre
   procesos. Las notificaciones de Foundation actuales no bastan para eso.

Referencias de Apple: [ModelConfiguration](https://developer.apple.com/documentation/swiftdata/modelconfiguration),
[persistencia entre aperturas](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches),
[interactividad en widgets y proceso de ejecución](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities).
