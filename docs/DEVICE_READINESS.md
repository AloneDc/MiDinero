# De repositorio a iPhone y TestFlight

Auditoría de Fase 3, 21 de septiembre de 2026. Resultados de ejecuciones y estados
comprobados en [ASTRA_EVALUATION.md](ASTRA_EVALUATION.md#fase-3--device-readiness).
La instalación y los recorridos físicos se registrarán en
[IPHONE_TEST_PLAN.md](IPHONE_TEST_PLAN.md); todavía no se han ejecutado.

## Configuración auditada

| Elemento | Configuración / conclusión |
| --- | --- |
| Identidad | `com.eduardo.MiDinero`; debe estar disponible para el Team elegido |
| Versión / build | `0.1.0` / `1`; aumentar build antes de una nueva subida a ASC |
| Deployment target | iOS `17.0`, compatible con SwiftData y las APIs usadas |
| Familia / arquitectura | iPhone (`TARGETED_DEVICE_FAMILY=1`), dispositivo arm64; sin Catalyst ni Mac Designed for iPhone |
| Nombre / idioma | MiDinero; región de desarrollo y localización `es`, textos del intent en español |
| Orientación | Vertical y ambos horizontales; sin vertical invertido |
| Info.plist | Archivo explícito, versiones e ID resueltos desde build settings, launch screen nativo y una escena |
| Icono | AppIcon RGB 1024×1024 sin alpha; asset catalog compilado en el archive |
| Firma | Automatic en el proyecto, sin Team, identidad ni perfiles privados guardados |
| Archive | `SKIP_INSTALL=NO` app; `YES` ambos targets de tests; solo app marcada para Archive en scheme |
| Entitlements | Ningún `.entitlements` ni `CODE_SIGN_ENTITLEMENTS` personalizado |
| Capabilities | Sin SiriKit, iCloud, App Groups, Background Modes ni Push; ninguna necesaria para este intent integrado |
| App Intents | Provider y acción pertenecen al target principal; metadata generada por Xcode y empaquetada |
| SwiftData / Charts | Frameworks nativos enlazados en el ejecutable de dispositivo; sin paquetes externos |
| Tests | Unit tests alojados en app y target XCUITest, solo para tests; no se distribuyen como extensiones |
| URL schemes | Ninguno; App Shortcuts no requiere un URL scheme |
| Privacy manifest | Incluido en Resources: sin tracking, dominios de tracking ni datos recolectados |
| Required Reason APIs | No hay llamadas directas a UserDefaults/AppStorage, timestamps de archivos, capacidad de disco, uptime ni teclado activo en el código del producto; sin SDKs de terceros. Se mantiene la lista vacía, sin razones inventadas |
| Export compliance | `ITSAppUsesNonExemptEncryption=false`: no incorpora cifrado propio ni bibliotecas criptográficas; usa la protección del sistema. Revisar si cambia ese diseño |

El manifiesto refleja el código actual; **no equivale a una aceptación de App Store
Connect**. El procesamiento del primer envío debe confirmar los análisis de Apple.
Referencias: [required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api),
[declaración de cifrado](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/).

## App e intent: mismo almacenamiento físico

`PersistenceController.storeURL()` usa
`FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
appropriateFor: nil, create: true)` y añade `MiDinero/MiDinero.store`.
En un iPhone, el path tiene esta forma (el UUID lo asigna iOS, no se codifica):

```text
<sandbox de datos de MiDinero>/Library/Application Support/MiDinero/MiDinero.store
# Habitualmente bajo /var/mobile/Containers/Data/Application/<UUID>/...
```

Configuración: `Schema([FinancialTransaction.self, Category.self])`, nombre
`MiDinero`, URL explícita, `cloudKitDatabase: .none`, almacenamiento persistente.
SwiftData administra SQLite y sus archivos auxiliares `-wal`/`-shm`; no moverlos
individualmente ni copiar una base abierta. La carpeta queda excluida de backups.
Una desinstalación o pérdida del dispositivo puede perder los datos; exportar CSV
antes de cambiar de instalación. No existe restauración/importación en este slice.

`LedgerStore.reload()`, `RegisterExpenseIntent.perform()` y la consulta de categorías
usan `PersistenceController.shared.container()`. App, modelos, consultas y escritura
están dentro de **un solo target/bundle**, no hay extensión App Intents. En el mismo
proceso comparten instancia; tras terminar el proceso, la misma función resuelve
la misma URL del sandbox. `TransactionRepository` crea contextos nuevos y hace
`save()` explícito antes de confirmar. Todo acceso a modelos se limita a MainActor;
no se transfieren ModelContext/modelos entre actores.

RootView recarga al volver a `.active` y tras guardar. No depende de que una
notificación cruce procesos. El esquema de tests utiliza un UUID aislado, solamente
en Debug; el scheme de ejecución normal no define esa variable y Release no contiene
la rama de aislamiento.

**App Groups no es necesario** para este diseño. Una futura extensión necesitaría
analizar contenedor compartido, entitlements y migración, como explica
[APP_INTENTS.md](APP_INTENTS.md). No se añadieron capabilities preventivamente.

## Auditoría de Registrar gasto

- `MiDineroShortcuts: AppShortcutsProvider` publica una acción y dos frases con
  `.applicationName`: «Registrar gasto en MiDinero» y «Anotar un gasto en MiDinero».
  `RootView` actualiza parámetros al cargar; no se ha eliminado esa llamada.
- Título localizado **Registrar gasto**. Monto `String` obligatorio (dígitos, punto
  o coma decimal, sin separadores de miles); conserva precisión. La validación
  devuelve `needsValueError` antes de escribir cuando el monto es inválido.
- Categoría obligatoria `ExpenseCategoryEntity`; consulta diez categorías reales
  con ID estable, búsquedas localizadas y creación inicial idempotente. No hay
  lista de opciones ficticias fuera del repositorio.
- Descripción `String?` opcional; la falta de valor no exige pregunta automática.
  Configurar «Preguntar cada vez» o usar la receta documentada para pedirla.
- `perform()` y escritura MainActor; resultado `IntentResult & ProvidesDialog`
  con confirmación solo después de guardar en disco. Sin red, URL de retorno ni
  navegación necesaria. Cada ejecución completada crea un movimiento.
- Autenticación local requerida. El modo predeterminado es background compatible
  con iOS 17; no hay solicitud de foreground. La metadata de dispositivo extraída
  confirma `isDiscoverable=true`, `openAppWhenRun=false`, obligatoriedad de monto
  y categoría, nota opcional y las dos frases del provider.

Esto demuestra el contrato compilado, **no que Siri/Atajos lo haya indexado y
ejecutado en un teléfono**. Esperamos ejecución sin navegación con el iPhone
desbloqueado, confirmación y recarga al abrir la app. iOS controla permisos,
autenticación, indexación, UI de preguntas, voz y cuándo inicia el proceso.
El texto «doce soles» puede no convertirse a `12`; la entrada numérica por texto
es la prueba inicial más predecible. No se promete acceso antes del primer
desbloqueo tras reiniciar.

Simulator permite probar `perform()` y el repositorio, pero no prueba el recorrido
del sistema ni firma/protección de archivos/autenticación reales. En fase 2 hubo
un diagnóstico Launch Services `-10814` al actualizar los shortcuts en el host de
tests; no prueba un fallo en iPhone ni permite darlo por resuelto. Las pruebas de
descubrimiento, Siri, app terminada y reinicio quedan explícitas en el plan físico.
El host de tests de Simulator 26.2 también registró
`LinkDaemon.ApplicationServiceInstance.Errors Code=2` al refrescar parámetros;
se conserva como límite de validación, aunque `perform()` y persistencia sí pasaron.
Referencias: [AppIntent](https://developer.apple.com/documentation/appintents/appintent),
[parámetros](https://developer.apple.com/documentation/appintents/adding-parameters-to-an-app-intent),
[autenticación](https://developer.apple.com/documentation/appintents/intentauthenticationpolicy/requireslocaldeviceauthentication).

## A. Instalar personalmente con Xcode (primer paso recomendado)

1. Disponer de un Mac y Xcode que soporte la versión del iPhone. Para reproducir
   esta fase se usa Xcode 26.2; un iPhone con iOS más nuevo puede exigir Xcode más nuevo.
2. Clonar el repositorio y abrir `MiDinero.xcodeproj`. En Xcode → Settings → Accounts,
   añadir tu Apple Account personalmente; no compartir su contraseña en el repositorio.
3. En target **MiDinero → Signing & Capabilities**, activar Automatically manage
   signing y seleccionar tu Team. `com.eduardo.MiDinero` no está reservado por este
   repositorio: si no está disponible, elegir un ID propio. Mantenerlo estable.
4. Conectar iPhone desbloqueado, confiar en el Mac y emparejarlo en Devices and
   Simulators. Habilitar Ajustes → Privacidad y seguridad → Developer Mode cuando
   iOS lo solicite y completar su reinicio/confirmación. Aceptar confianza del
   desarrollador si el sistema la solicita.
5. Seleccionar scheme **MiDinero**, destino **tu iPhone**, acción Run (⌘R).
   Xcode debe obtener certificado Apple Development y perfil de desarrollo que
   incluya App ID y dispositivo. No usar `CODE_SIGNING_ALLOWED=NO` para instalar.
6. Los test targets no se necesitan para Run. Para tests en dispositivo, seleccionar
   el mismo Team en ambos targets y permitir sus identificadores derivados.
7. Detener debugger y ejecutar [IPHONE_TEST_PLAN.md](IPHONE_TEST_PLAN.md).

Una **Personal Team gratuita** permite la prueba personal con las limitaciones
y caducidad de perfiles de Apple (normalmente siete días); hay que volver a firmar.
No habilita TestFlight. La membresía de pago permite recursos de distribución.
[Comparación oficial de cuentas](https://developer.apple.com/help/account/basics/about-your-developer-account),
[ejecución en dispositivos](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices).

Cambiar bundle ID crea otra identidad/sandbox; no migra los movimientos. Los ajustes
compartidos definitivos deben modificarse también en `scripts/generate_project.py`
y regenerarse; para pruebas personales mantener signing local, sin subir archivos
privados. El archive sin firma de CI es evidencia compilable, **no un instalador**.

## B. Distribuir por TestFlight (actualizado)

La estrategia vigente es automatic/cloud-managed signing con una Team API key.
No configurar p12 ni provisioning profiles manuales. Consultar
[TESTFLIGHT_MISSION_4.md](TESTFLIGHT_MISSION_4.md) para los valores y pasos actuales.

Los workflows usan `macos-26` y el Xcode seleccionado por el runner, exigiendo
versi?n 26 o posterior en ejecuci?n. El archive Release se genera sin firma local;
`xcodebuild -exportArchive`, con `signingStyle=automatic`, `teamID`, la API key y
`-allowProvisioningUpdates`, solicita firma y perfil de distribuci?n a Apple.
Se verifica la IPA firmada antes de validarla y subirla con altool.
La ruta requiere permisos reales y todav?a no ha sido probada contra este equipo
Apple: no confundir tests verdes con autorizaci?n cloud ni disponibilidad TestFlight.

## Protección del repositorio

`.gitignore` excluye p12/pfx, claves p8/pem/key, certificados, perfiles, keychains,
archivos `.env`, carpetas de secretos, datos personales Xcode, IPA y xcarchive.
`scripts/check_repository_security.py` inspecciona todos los blobs del índice de
Git para bloquear nombres privados y patrones conocidos de claves/tokens, sin
imprimir valores. Ejecutarlo **después de `git add` y antes de `git commit`**:

```sh
python3 scripts/check_repository_security.py
git diff --cached --check
```

También se ejecuta en CI. `.gitignore` no protege archivos ya rastreados ni `git add -f`,
y ningún escáner simple garantiza detectar secretos arbitrarios. CI detecta después
del push; por eso la comprobación local previa importa. No se introdujeron secretos
ni certificados reales/falsos en esta fase. Activar secret scanning/push protection
de GitHub según disponibilidad de la cuenta complementa estas medidas.
