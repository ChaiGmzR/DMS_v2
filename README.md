# DMS v2 - Flutter

Version Flutter del DMS actual. Usa el backend DMS API Server y esta pensada para:

- Celulares Android/iOS con captura por camara cuando la plataforma lo soporte.
- Laptops y desktop Windows con layout amplio y entrada por teclado o lector USB.

## Modulos incluidos

- Login con JWT y URL de API configurable.
- Captura y lista de defectos.
- Reparacion: pendientes, iniciar y finalizar.
- Validacion QA: aprobar o rechazar reparaciones.
- Usuarios: listar, crear, editar, activar/desactivar y cambiar PIN.

## API

La app espera una URL que termine en `/api`.

- Produccion/server: `http://192.168.1.10:5000/api`
- Android emulator local: `http://10.0.2.2:5000/api`
- Telefono fisico local: usar la IP de la PC/servidor, por ejemplo `http://192.168.0.140:5000/api`

La URL se puede cambiar desde la pantalla de login en `Configurar servidor API`.

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows
flutter build apk --debug
flutter build apk --release
```

## Artefactos verificados

- Windows: `build/windows/x64/runner/Release/defect_ms_v2.exe`
- Android debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Android release: `build/app/outputs/flutter-apk/app-release.apk`
