# Mova – Student Carpooling Application

## About Mova

Mova is a student-focused carpooling application designed to help students find and share rides to campus. The application connects students who need transport with students who are willing to offer rides, making commuting more convenient and encouraging ride-sharing.

Drivers can create rides by specifying their pickup location, scheduled departure time, and available seats. Passengers can browse available rides, request seats, and communicate with other users through the application's messaging functionality.

The application is being developed using Flutter for the frontend and ASP.NET Core Web API for the backend.

## Features

- **User Authentication:** Register and log in using student account credentials.
- **Driver and Passenger Roles:** The application provides different functionality depending on whether a student offers rides or needs transport.
- **Create Rides:** Drivers can specify pickup locations, departure dates and times, and available seats.
- **Find Rides:** Passengers can browse available rides and view pickup and destination locations on a map.
- **Ride Requests:** Passengers can request seats, while drivers can manage incoming requests.
- **Ride Management:** Users can view and manage their rides, including completing rides.
- **Interactive Maps:** MapLibre displays maps using OpenStreetMap-compatible map services.
- **Route Calculation:** OSRM provides road-route information.
- **In-App Messaging:** Users can communicate with other participants regarding their rides.
- **Profile Management:** Users can manage their profile information and profile images.
- **Dark Mode:** Supported screens offer a dark-mode option.

The current destination flow is configured for the Eduvos Tyger Valley campus.

## Technology Stack

### Frontend
- Flutter
- Dart
- Material Design
- MapLibre GL
- HTTP REST API integration
- Flutter Secure Storage

### Backend
- C#
- ASP.NET Core Web API
- SQLite
- MongoDB Atlas
- JWT authentication
- Supabase Storage for profile images
- Swagger / OpenAPI

### Mapping and Routing
- OpenStreetMap map data
- MapLibre for map rendering
- OSRM for road-route calculations

## Project Structure

The frontend and backend are maintained as separate projects.

```text
mova/
├── android/             # Android application configuration
├── assets/              # Images, icons, and other assets
├── lib/
│   ├── models/           # Application data models
│   ├── screens/          # User interface screens
│   ├── services/         # API communication and services
│   └── main.dart         # Application entry point
├── test/                 # Flutter tests
├── pubspec.yaml          # Dependencies and asset configuration
└── README.md             # Project documentation
```

The exact structure may change as development continues.

## Requirements

Before running the application, install:

- Flutter SDK
- Dart SDK (included with Flutter)
- Android Studio and Android SDK, if targeting Android
- Git
- A running Mova backend or access to a deployed API

Verify your Flutter installation:

```bash
flutter doctor
```

## Installation and Setup

### 1. Clone the repository

```bash
git clone https://github.com/DaChoco/mova.git
cd mova
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure the backend URL

The frontend uses `AppConfig.backendBaseUrl` to determine which backend API to contact.

Configure this value to point to your backend environment.

Examples include:
- A locally hosted backend.
- A backend running on your development computer and accessed from a physical Android device.
- A deployed backend accessible over the internet.

For Android emulators, use the appropriate host address to reach your development computer. For physical devices, ensure the phone and computer can communicate over the network.

### 4. Run the application

List available devices:

```bash
flutter devices
```

Start the application:

```bash
flutter run
```

To run in Chrome, where supported:

```bash
flutter run -d chrome
```

## Backend Setup

The backend is a separate ASP.NET Core Web API project.

From the directory containing `Mova.Api.csproj`, run:

```bash
dotnet restore
dotnet build
dotnet run
```

Use the address printed in the terminal to access the API. If Swagger is enabled, open its configured Swagger UI URL to inspect and test the available endpoints.

The backend requires the appropriate configuration for its database, authentication, storage, chat, and routing services.

## API Functionality

The frontend communicates with the backend through REST API requests.

The main API areas include:

- **Authentication:** User registration and login.
- **Users:** Retrieve and update profile information.
- **Rides:** Create, find, view, and manage rides.
- **Ride Requests:** Request seats and accept, reject, or cancel requests.
- **Ride Status:** Start and complete rides, with ratings where supported.
- **Chat:** Retrieve and send ride-related messages.
- **Routes:** Request route information from the routing service.

Refer to the backend's `docs/api-contract.md` and Swagger documentation for the exact endpoints, parameters, and request formats.

## Maps and Routing

Mova uses MapLibre to display maps and OpenStreetMap-compatible services to provide map data. OSRM is used to calculate road routes between pickup and destination coordinates.

Mapping, geocoding, and routing are separate services. Their availability and usage restrictions depend on the configured providers.

For routing problems, verify that the backend can reach its configured OSRM endpoint and that the routing service permits the requests being made.

## Security Considerations

- Never commit database credentials, API keys, JWT signing secrets, or other sensitive configuration to Git.
- Keep local environment files out of version control.
- Use HTTPS in deployed environments.
- Configure CORS appropriately for the frontend origins that need access.
- Store authentication tokens securely on the device.
- Keep privileged database and storage credentials on the backend rather than embedding them in the Flutter application.
- Follow the usage policies of external mapping and routing services.

## Troubleshooting

### The application cannot connect to the backend

- Confirm that the backend is running.
- Verify `AppConfig.backendBaseUrl`.
- Check network connectivity and firewall settings.
- For web builds, verify the backend's CORS configuration.

### Login or ride requests fail

- Test the relevant endpoint through Swagger.
- Check the backend logs for errors.
- Verify that request fields match the backend API contract.

### Chat or profile images do not work

- Check the MongoDB and Supabase configuration.
- Confirm that the services are reachable and the required credentials are configured.
- Inspect API responses and backend logs.

### Routes do not appear

- Verify the OSRM endpoint configured in the backend.
- Confirm that valid pickup and destination coordinates are provided.
- Check the backend logs for routing errors.

## Testing and Code Analysis

Run Flutter's static analysis:

```bash
flutter analyze
```

Run the available Flutter tests:

```bash
flutter test
```

## Project Status

Mova is a student software engineering project under active development. Features, integrations, configuration, and deployment arrangements may change as the application evolves.

## Contributors

[Yaeshveer Naidoo](https://github.com/FriedFly)
[Keano Hsu](https://github.com/keanohsu22-ops)
[Maile Chokoe](https://github.com/DaChoco)
[Jayden Carolissen](https://github.com/UncleDonut)
[Josh-Lee Biggs](https://github.com/heavenoffline)
[Kreesan Naicker](https://github.com/kreesan1)

Developed collaboratively as a student project.

## License

MIT
