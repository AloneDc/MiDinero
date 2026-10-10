# TestFlight — configuración vigente

Los workflows usan `macos-26` y el Xcode predeterminado del runner, exigiendo 26+.
Se conservan todos los tests y funcionalidades. La distribución usa archive Release
sin firma local y automatic/cloud-managed signing durante `-exportArchive`, con
`signingStyle=automatic`, `teamID`, `-allowProvisioningUpdates`,
`-authenticationKeyPath`, `-authenticationKeyID` y `-authenticationKeyIssuerID`.
MiDinero no tiene extensiones ni entitlements personalizados. La IPA exportada se
verifica con codesign, se inspecciona su perfil App Store y se valida/sube con altool.

[Apple: automatización y cloud signing](https://developer.apple.com/videos/play/wwdc2021/10204/).
Implementado, pero firma/exportación/upload no probados con credenciales reales.
No podemos confirmar permisos de tu equipo sin una clave real. No hay evidencia
de un bloqueo que obligue a firma manual. No existe fallback que simule éxito.

## GitHub: configuración mínima

En **Settings → Environments → testflight** (ya creado, restringido a main):

| Tipo | Nombre | Contenido |
| --- | --- | --- |
| Variable | `APP_BUNDLE_ID` | `com.eduardo.MiDinero`, ya configurada |
| Variable | `APPLE_TEAM_ID` | Team ID real de diez caracteres |
| Secret | `ASC_KEY_ID` | Key ID de la Team API key |
| Secret | `ASC_ISSUER_ID` | Issuer ID del equipo, UUID |
| Secret | `ASC_PRIVATE_KEY_BASE64` | Base64 en una línea del `.p8` descargado |

En **Settings → Secrets and variables → Actions → Variables** configurar
`TESTFLIGHT_ENABLED=true`. Build number nuevo y `confirm_upload=true` son inputs
de ejecución manual en main, no Secrets. Ya no se usan los anteriores Secrets
`APPLE_DISTRIBUTION_P12_BASE64`, `APPLE_DISTRIBUTION_P12_PASSWORD` ni
`APPSTORE_PROFILE_BASE64`.

Desde una carpeta privada fuera del repositorio, reemplazar el nombre por el real:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\AuthKey_ID.p8).Path)) | Set-Clipboard
```

Pegar en el Secret y vaciar con `Set-Clipboard -Value ''`. No compartir `.p8`,
base64, claves privadas, contraseñas Apple ni códigos 2FA en el chat o Git.

## Apple: acciones del titular

1. **Apple Developer → Account → Membership details**: verificar membresía activa
   Apple Developer Program, obtener Team ID y aceptar acuerdos pendientes.
2. **Certificates, Identifiers & Profiles → Identifiers**: registrar o verificar
   App ID explícito `com.eduardo.MiDinero`. Sin capabilities adicionales.
3. **App Store Connect → My Apps → + → New App**: iOS, MiDinero, Spanish,
   ese Bundle ID, SKU `midinero-ios`. Reutilizar el registro si ya existe.
4. **Users and Access → Integrations → App Store Connect API → Team Keys**:
   habilitar API si se solicita; crear una clave de equipo con rol **Admin**, que
   permite aprovisionamiento y firma cloud sin depender de permisos especiales del
   rol Developer. Descargar el `.p8` y guardar Key ID e Issuer ID en GitHub.
   No usar Individual API key. La clave Admin tiene acceso amplio al equipo;
   reservarla para este environment.
5. No crear certificados ni perfiles manualmente: Xcode los administra al exportar.
   Si Apple rechaza cloud signing, revisar el error real antes de cambiar estrategia.
6. Tras upload aceptado, esperar procesamiento y resolver export compliance.
   **MiDinero → TestFlight → Internal Testing**: crear grupo, añadir tu usuario y
   la build procesada. Solo entonces estará disponible para instalar. Pruebas
   A/B/C/D pendientes del usuario en [IPHONE_TEST_PLAN.md](IPHONE_TEST_PLAN.md).

## Evidencia

`docs/evidence/phase3` y `docs/evidence/mission4/device` corresponden a validaciones
anteriores. No prueban que el nuevo runner macos-26 ni cloud signing hayan pasado.
La nueva ejecución tendrá evidencia separada. Tests verdes no acreditan permisos
Apple, upload, procesamiento, disponibilidad TestFlight ni instalación física.
