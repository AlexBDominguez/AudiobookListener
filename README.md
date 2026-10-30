# AudiobookListener

Reproductor personal de audiolibros `.m4b` para Android (y Windows), 100 % offline.

- Lee una carpeta local elegida con el Storage Access Framework, sin permisos de almacenamiento.
- Parser de MP4/m4b propio en Dart puro (metadatos, portada y capítulos).
- Reproducción en segundo plano con controles en notificación, pantalla de bloqueo y auriculares.

Requisitos y fases: [docs/REQUISITOS.md](docs/REQUISITOS.md).

## Desarrollo

```sh
flutter pub get
flutter test
flutter run -d <id>            # flutter devices para ver el id
flutter build apk --release
```

Los fixtures de `test/fixtures/` se regeneran con `test/fixtures/generate_fixtures.ps1` (necesita ffmpeg).

La fuente Inter se distribuye bajo la SIL Open Font License (`assets/fonts/inter/OFL.txt`).
