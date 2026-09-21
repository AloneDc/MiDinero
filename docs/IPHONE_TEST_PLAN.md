# Primera prueba física de MiDinero

**Estado: pendiente. Ninguna casilla representa una prueba realizada por el agente.**
Ejecutar en un iPhone real, sin debugger conectado después de instalar. Conservar
capturas solo con datos de prueba; no publicar movimientos personales en GitHub.

## Registro de la sesión

| Dato | Completar al probar |
| --- | --- |
| Fecha/hora y zona horaria | |
| Modelo de iPhone / versión exacta de iOS | |
| Commit / versión / build / bundle ID instalado | |
| Instalación: Xcode Development o TestFlight | |
| Idioma/región del iPhone e idioma de Siri | |
| Tester / resultado global / incidencias | |

- [ ] Usar iOS 17 o posterior; para instalar con Xcode, comprobar soporte de ese iOS.
- [ ] Seguir [DEVICE_READINESS.md](DEVICE_READINESS.md) para firma e instalación.
- [ ] Mantener la misma fecha local y el mismo mes durante las dos primeras altas.
- [ ] Si ya existen datos, exportar CSV y anotar la base del mes: gastos G₀,
  ingresos I₀, balance B₀, movimientos N₀, gastos Comida C₀ y Transporte T₀.
- [ ] **No desinstalar ni borrar datos personales para obtener un estado vacío.**
  La base está excluida del backup; CSV conserva información pero aún no hay importación.

## Instalación y primer arranque

- [ ] Xcode: añadir Apple Account, seleccionar Team y bundle ID único, conectar y
  confiar en el iPhone, habilitar Developer Mode, seleccionar **MiDinero + iPhone**,
  pulsar ⌘R. Esperado: build firmado e instalación correctos. Anotar cualquier error.
- [ ] TestFlight (solo si ya hay build procesado e invitación): abrir TestFlight,
  aceptar invitación, instalar MiDinero. Esta vía no requiere Developer Mode.
- [ ] Detener la ejecución en Xcode, desconectar cable y abrir desde el icono.
- [ ] Ver icono y nombre **MiDinero**, arranque sin crash ni login.
- [ ] Primera instalación vacía: ver estado vacío y acceso para registrar gasto;
  no deben aparecer movimientos de ejemplo. Si había datos, deben seguir presentes.
- [ ] En modo claro, abrir Inicio, Movimientos y Reporte. Leer todos los textos.
- [ ] En Ajustes → Pantalla y brillo → Oscuro, repetir. Revisar texto, teclado,
  selector de categoría y barras; nada debe quedar ilegible.
- [ ] Rotar a horizontal y volver a vertical; comprobar contenido y teclado.
- [ ] Opcional: texto grande y VoiceOver; monto, categorías y guardar accesibles.

## Registro dentro de la app

- [ ] En **Inicio**, tocar **Registrar gasto**.
- [ ] Introducir `10` (S/ 10.00), elegir **Comida**, escribir **Prueba física** y guardar
  una sola vez. No cambiar tipo ni fecha. Esperado: confirmación y cierre del editor.
- [ ] En **Movimientos**, verificar exactamente una nueva fila: gasto, Comida,
  S/ 10.00, «Prueba física», fecha local actual. Anotar hora para identificarla.
- [ ] En **Inicio**, comprobar gastos G₀ + 10, ingresos I₀, balance B₀ − 10,
  movimientos N₀ + 1. Comida debe aumentar C₀ + 10.
- [ ] En **Reporte**, elegir el mes actual y comprobar los mismos totales y categoría.
  Si la base estaba vacía: gastos 10, ingresos 0, balance −10, un movimiento,
  Comida 100 %, promedio S/ 10 por día con gasto.
- [ ] Ir a inicio del iPhone, cerrar MiDinero desde el selector de apps y abrirla
  otra vez desde su icono. Deben conservarse fila, nota, importes y reporte.

## Atajos: descubrimiento y ejecución sin navegar por MiDinero

- [ ] Con el iPhone desbloqueado, abrir **Atajos / Shortcuts**. Buscar en
  **Atajos de apps → MiDinero**, o **+ → Añadir acción → Apps → MiDinero**.
  Debe aparecer **Registrar gasto**. Registrar ruta exacta según versión de iOS.
- [ ] Si no aparece, registrar ese fallo antes de intentar recuperar. Abrir MiDinero
  una vez, volver a Atajos y buscar de nuevo. No reinstalar ni borrar la base.
- [ ] Crear un atajo personal **Registrar gasto** con la acción de **MiDinero**.
  Configurar Monto y Categoría como **Preguntar cada vez**. Para esta prueba poner
  la Descripción fija **Taxi prueba**, o **Preguntar cada vez** si el editor lo permite.
  La nota opcional vacía NO debe obligar a una pregunta automática.
- [ ] Ejecutar el atajo con MiDinero fuera del foreground, **sin cerrarla a la fuerza**.
  Responder Monto `15` y Categoría **Transporte**. Ejecutar una sola vez.
- [ ] Esperado: confirmación «Guardé S/ 15.00 en Transporte» (el formato puede variar
  con locale). No debe requerir navegar manualmente por MiDinero. Registrar si iOS
  muestra autenticación, permiso, selector o abre la app; no confundir UI del sistema
  con navegación interna. No marcar éxito si solo se completó sin guardar.
- [ ] Abrir MiDinero. Debe existir una nueva fila S/ 15, Transporte, **Taxi prueba**.
- [ ] Verificar Inicio y Reporte: gastos G₀ + 25, ingresos I₀, balance B₀ − 25,
  N₀ + 2 movimientos; Comida C₀ + 10 y Transporte T₀ + 15.
- [ ] Si la base estaba vacía y ambas altas fueron el mismo día: gastos S/ 25,
  ingresos S/ 0, balance −S/ 25, promedio **S/ 25 por día con gasto**, Comida 40 %,
  Transporte 60 %, categoría principal Transporte, dos movimientos. Con datos previos,
  recalcular porcentajes sobre G₀ + 25; no exigir 40/60 ni Transporte como principal.
- [ ] Añadir el atajo a pantalla de inicio desde sus detalles. Comprobar que aparece
  el acceso; no ejecutarlo otra vez sin contabilizar un nuevo movimiento.
- [ ] Prueba de validación: ejecutar con `0` y después cancelar cuando solicite
  corrección. Debe pedir un monto válido y no aumentar el conteo. Registrar error exacto
  si la experiencia de iOS difiere.

## Siri

- [ ] Con Siri configurada en español y teléfono desbloqueado, decir
  **«Siri, registrar gasto en MiDinero»**. Esta es una frase declarada por el provider.
- [ ] Si resuelve la acción, indicar `1` y **Otros**. La nota puede quedar vacía.
  Esperado: una confirmación después del guardado y un solo gasto de S/ 1.
- [ ] Anotar literalmente transcripción reconocida, preguntas, respuesta, si abrió
  MiDinero, si solicitó autenticación y si el gasto existe. Si reconoce «un sol» como
  palabras y no acepta el monto, registrar el límite; no atribuirlo a un guardado exitoso.
- [ ] Probar también **«Siri, anotar un gasto en MiDinero»**, cancelando antes del
  guardado si solo se quiere comprobar descubrimiento. Si se guarda, anotar el nuevo gasto.
- [ ] Opcional: repetir bloqueado; se espera requerimiento de autenticación local.
  Desbloquear o cancelar. Comprobar que cancelar no guarda ni duplica.

## App terminada

- [ ] Anotar gastos y conteo actuales (incluyendo cualquier alta de Siri).
- [ ] Deslizar MiDinero fuera del selector de apps. Dejar el iPhone desbloqueado.
- [ ] Ejecutar el atajo personal desde Atajos o su icono con `2`, **Otros**,
  descripción **App terminada** (editar la nota del atajo antes de ejecutar).
- [ ] Esperado: el sistema inicia la ejecución del intent, guarda y confirma sin
  exigir recorrer pantallas de MiDinero. Si falla, registrar mensaje y estado exactos.
- [ ] Abrir MiDinero y comprobar un único gasto S/ 2 «App terminada», total anterior
  + 2, balance −2 y conteo +1. Reporte e historial deben coincidir.

## Reinicio

- [ ] Anotar todos los movimientos de prueba y totales finales o tomar captura.
- [ ] Reiniciar el iPhone, desbloquearlo al menos una vez y abrir MiDinero.
- [ ] Comprobar las filas «Prueba física», «Taxi prueba» y «App terminada», más las
  altas efectivamente realizadas mediante Siri. Totales/reporte idénticos a antes
  del reinicio, salvo cruce de mes/zona horaria que debe anotarse.
- [ ] No esperar lectura del almacén antes del primer desbloqueo tras reiniciar.

## Resultado y limpieza opcional

| Caso | PASS / FAIL / NO EJECUTADO | Evidencia o mensaje exacto |
| --- | --- | --- |
| Instalación y arranque | | |
| Claro / oscuro | | |
| App → persistencia → reporte | | |
| Descubrimiento en Atajos | | |
| Atajo → persistencia → reporte | | |
| Siri y resolución del monto | | |
| App terminada | | |
| Reinicio | | |

- [ ] Si se desea limpiar, eliminar **solo** las filas de esta sesión, identificadas
  por nota/hora/monto y con la confirmación de la app. No borrar movimientos preexistentes.
- [ ] No declarar completado el recorrido físico mientras falte instalación,
  descubrimiento, guardado real por Atajos o persistencia tras reinicio.
