# NextTurn – Flutter front

Flutter client for NextTurn. It talks to the Symfony API in [`back-NextTurn`](../../back-NextTurn) over HTTP/JSON.

## Run

### Requirements

- Flutter with Dart 3.14 or newer (`flutter --version`). The `sdk-setup.sh` script at the repo root installs it to `~/flutter`. If an older Flutter comes first in your `PATH`, use `~/flutter/bin/flutter`.
- The back (`back-NextTurn`) running, by default on `http://localhost:8000`.

### Steps

From this `app/` folder:

```bash
flutter pub get
```

```bash
flutter run
```

The API URL defaults to `http://localhost:8000`. To change it, pass `API_URL`:

| Target | Command |
| --- | --- |
| Linux desktop / Chrome | `flutter run --dart-define=API_URL=http://localhost:8000` |
| Android emulator | `flutter run --dart-define=API_URL=http://10.0.2.2:8000` |
| Physical phone (same Wi-Fi) | `flutter run --dart-define=API_URL=http://<your-PC-IP>:8000` |

`flutter devices` lists the available targets, and `flutter run -d <device-id>` picks one.

### Tests

```bash
flutter test
```

```bash
flutter analyze
```

Run both before pushing.

## Architecture

All app code lives in `lib/src/`. Flutter only compiles code under `lib/`.

```
lib/
├── main.dart                      # Entry point: runApp(NextTurnApp())
└── src/
    ├── app.dart                   # Root widget, wires adapters → services → components
    ├── config/
    │   └── env.dart               # Build-time config (API_URL)
    ├── models/
    │   └── category.dart          # Domain models: plain Dart, no JSON, no HTTP
    ├── adapters/
    │   ├── http/
    │   │   └── api_client.dart    # Only place that does HTTP (base URL, headers, JSON, errors)
    │   └── category_adapter.dart  # Interface + HTTP implementation for /api/categories
    ├── services/
    │   └── category_service.dart  # Business rules (validation, sorting…)
    └── components/
        └── category/              # Widgets, grouped by feature
            ├── categories_screen.dart
            ├── category_list.dart
            └── category_tile.dart
```

### Layers

| Layer | Role | Can depend on |
| --- | --- | --- |
| **components** | UI: screens and widgets. Show data, handle user input. | services, models |
| **services** | Business logic: validation, sorting, combining data. | adapter **interfaces**, models |
| **adapters** | Talk to the outside world (API, storage…) and convert raw data into models. | `ApiClient`, models |
| **models** | Domain objects used everywhere. | nothing |

The flow is: `component → service → adapter (interface) → HttpXxxAdapter → ApiClient → back`.

### Rules

- **Components never call HTTP or adapters directly.** They only use services.
- **Services depend on the adapter interface** (`CategoryAdapter`), not on `HttpCategoryAdapter`. This means you can swap the data source (generated OpenAPI client, mock, cache) without touching services or UI.
- **JSON stays in adapters.** Models don't have `fromJson`/`toJson`; the adapter maps API fields to the model.
- **Wiring happens in one place:** `app.dart` creates `ApiClient`, the adapters and the services, then passes services to the screens.
- **Validation is duplicated on purpose:** services check the same rules as the back (e.g. name max 255 chars) to give quick feedback, but the back stays the source of truth.

## Adding a feature

Example: adding `Game`.

1. **Model:** `lib/src/models/game.dart` with the fields the UI needs.
2. **Adapter:** `lib/src/adapters/game_adapter.dart` with an `abstract interface class GameAdapter` and an `HttpGameAdapter` that calls `/api/games` through `ApiClient` and maps the JSON.
3. **Service:** `lib/src/services/game_service.dart`, taking a `GameAdapter` in its constructor.
4. **Components:** `lib/src/components/game/` with the screen and its widgets. The screen takes a `GameService`.
5. **Wiring:** create the adapter and service in `app.dart` and pass the service to the screen.
6. **Tests:** a fake `GameAdapter` in `test/` to test the service and the screen without the back.

## Testing

Tests use fake adapters (see `FakeCategoryAdapter` in [`test/widget_test.dart`](test/widget_test.dart)), so they don't need the back or a network.

- **Service tests:** check business rules with plain `test()`.
- **Widget tests:** pass a fake adapter to `NextTurnApp(categoryAdapter: ...)` and check what's on screen.

## Connecting to the back with Swagger

The back can publish an OpenAPI (Swagger) spec, and a typed Dart client can be generated from it. See [`docs/swagger-flutter.md`](../docs/swagger-flutter.md).

Once the client is generated, only the adapters change: `HttpCategoryAdapter` calls the generated `CategoryApi` instead of `ApiClient`. Services and components stay the same.

## Dependencies

| Package | Use |
| --- | --- |
| `material_ui` | Material widgets |
| `http` | HTTP calls in `ApiClient` |
| `flutter_lints` (dev) | Lint rules (`analysis_options.yaml`) |

## Troubleshooting

- **`version solving failed` / `requires SDK version ^3.14.0`:** your Flutter is too old. Use `~/flutter/bin/flutter`, or run `sdk-setup.sh`.
- **Connection refused on Android emulator:** use `API_URL=http://10.0.2.2:8000`. `localhost` is the emulator itself.
- **CORS error on Chrome:** the back needs `nelmio/cors-bundle` configured to allow the front's origin.
- **Physical phone can't reach the back:** the back must listen on `0.0.0.0` (not `127.0.0.1`), and the phone must be on the same network.
