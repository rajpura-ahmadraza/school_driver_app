# 🚌 School Driver App — Setup Guide

## Live API
```
https://laravel-api.emaad-infotech.com/zahab-laravel/public/api/v1
```

## Prerequisites
- Flutter >= 3.10.0 & Dart >= 3.0.0
- Android Studio / Xcode
- Physical device recommended for GPS testing

---

## ⚡ Quick Start

```bash
# 1. Install dependencies
flutter pub get

# 2. Run on device
flutter run

# 3. Build release APK
flutter build apk --release

# 4. Build release App Bundle (for Play Store)
flutter build appbundle --release
```

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry + EasyLocalization
├── core/
│   ├── api/
│   │   └── api_client.dart            # Dio + JWT interceptor + live URL
│   ├── providers/
│   │   └── auth_provider.dart         # Riverpod auth state
│   ├── router/
│   │   └── app_router.dart            # GoRouter + auth guard
│   ├── splash/
│   │   └── splash_screen.dart         # 1.5s animated splash
│   └── theme/
│       └── app_theme.dart             # Material 3 light/dark theme
└── features/
    ├── auth/
    │   └── login_screen.dart          # Driver login + language picker
    ├── home/
    │   └── home_screen.dart           # Driver dashboard
    ├── tracking/
    │   ├── gps_service.dart           # Haversine GPS (30s/30m trigger)
    │   └── tracking_screen.dart       # Animated start/stop tracking
    └── students/
        └── students_screen.dart       # Route students + mark absent

assets/
├── translations/
│   ├── en.json                        # English
│   ├── hi.json                        # Hindi (हिन्दी)
│   └── gu.json                        # Gujarati (ગુજરાતી)
└── fonts/
    ├── Poppins-Regular.ttf
    ├── Poppins-Medium.ttf
    ├── Poppins-SemiBold.ttf
    └── Poppins-Bold.ttf
```

---

## 🔑 Login

Default driver credentials:
- **Email**: `driver@school.com`
- **Password**: `password`

> Only users with `role = driver` can log in. The app shows an error
> if any other role tries to sign in.

---

## 🌍 Languages

Switch language from the Login screen or Home screen.
Supported: **English**, **हिन्दी (Hindi)**, **ગુજરાતી (Gujarati)**

---

## 🛰️ GPS Tracking Logic

The app uses a **dual-trigger** system to minimise battery usage:

| Trigger | Condition |
|---------|-----------|
| Time-based | Sends location every **30 seconds** via a background timer |
| Distance-based | Sends location when device moves **≥ 30 meters** (Haversine formula) |

This means:
- If the bus is **stationary** → location sent every 30s (minimal drain)
- If the bus is **moving** → location sent on every 30m movement
- Uses `distanceFilter: 5` on the device stream to avoid noisy micro-movements

### API endpoint called:
```
POST /api/v1/bus/location
{
  "latitude":  23.0225,
  "longitude": 72.5714,
  "speed":     35.5,
  "heading":   90.0,
  "accuracy":  8.5,
  "route_id":  1
}
```

---

## 📲 Screens

| Screen | Description |
|--------|-------------|
| **Splash** | 1.5s animated gradient splash with logo |
| **Login** | Email/password with show/hide + language picker |
| **Home** | Greeting, tracking status, quick action cards |
| **Tracking** | Big animated start/stop button, live speed display, GPS coordinates |
| **Students** | Student list for route, search, mark absent/present, save attendance |

---

## 🔒 Permissions Required

### Android
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION`
- `FOREGROUND_SERVICE`
- `INTERNET`

### iOS
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- Background mode: `location`

---

## 📦 Adding Poppins Fonts

Download from [fonts.google.com/specimen/Poppins](https://fonts.google.com/specimen/Poppins)

Place in `assets/fonts/`:
- `Poppins-Regular.ttf`
- `Poppins-Medium.ttf`
- `Poppins-SemiBold.ttf`
- `Poppins-Bold.ttf`

> If fonts are missing, Flutter will fall back to the system default font.
> The app is fully functional without the font files.

---

## ⚠️ Physical Device Testing

GPS does **not** work on emulator/simulator. Use a physical device.

Connect device via USB, enable Developer Options + USB Debugging, then:
```bash
flutter run
```

---

## 🏗️ Build for Release

```bash
# Android APK
flutter build apk --release --target-platform android-arm64

# Android App Bundle
flutter build appbundle --release

# iOS (requires Mac + Xcode)
flutter build ios --release
```
