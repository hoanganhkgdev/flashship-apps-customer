# Flashship Customer App

Customer-facing mobile application for **Flashship**, a multi-service local delivery and on-demand services platform.

Built with Flutter, the app connects customers to the Flashship backend and realtime infrastructure for creating and managing delivery and service orders.

## Product Overview

Flashship is designed as a multi-role ecosystem with dedicated applications for customers, drivers, shops, and an operations/admin platform.

The Customer App is the main consumer-facing client and supports Flashship services such as local delivery, item pickup, assisted purchasing, and ride-related services.

## Tech Stack

- Flutter / Dart
- Riverpod — state management
- GoRouter — navigation
- Dio — REST API networking
- Google Maps Flutter
- Geolocator
- Firebase Core
- Firebase Cloud Messaging
- Firebase Realtime Database
- Shared Preferences
- Cached Network Image
- Permission Handler
- WebView Flutter

## Application Architecture

```text
Customer App (Flutter)
        │
        ├── REST API ─────────► Laravel Backend
        │                         ├── Authentication
        │                         ├── Customer
        │                         ├── Orders
        │                         ├── Pricing
        │                         └── Core Services
        │
        ├── Firebase Realtime ─► Live application data
        │
        ├── FCM ───────────────► Push notifications
        │
        └── Google Maps/GPS ───► Location-based workflows
```

## Key Engineering Areas

This project demonstrates mobile development across:

- REST API integration using Dio
- Riverpod-based state management
- Declarative navigation with GoRouter
- Authentication and persisted local state
- Google Maps integration
- GPS and runtime location permissions
- Firebase Cloud Messaging
- Firebase Realtime Database integration
- Image selection and network image handling
- Deep/external URL workflows
- Android and iOS application development

## Flashship Ecosystem

The Customer App works as part of a larger system:

- **Customer App** — creates and manages service orders
- **Driver App** — receives and processes delivery jobs
- **Shop App** — supports partner-shop delivery operations
- **Laravel Backend** — APIs, authentication, business rules, pricing, orders, payments, and integrations
- **Admin Platform** — internal operations and management

## Getting Started

### Requirements

- Flutter SDK compatible with Dart `^3.6.0`
- Android Studio and/or Xcode
- Configured Firebase project
- Google Maps credentials
- Access to the Flashship backend API

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Analyze

```bash
flutter analyze
```

### Test

```bash
flutter test
```

## Configuration & Security

Production credentials, Firebase configuration, API secrets, signing credentials, and other sensitive environment-specific values should not be committed to source control.

## Project Context

Flashship Customer is an actively developed real-world application rather than a Flutter tutorial project. It is designed to work with the broader Flashship delivery ecosystem and its Laravel/Firebase infrastructure.

---

**Flashship** — Local delivery and on-demand services platform.
