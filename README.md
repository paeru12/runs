# Run Tracker - Flutter Running Activity Monitor

A comprehensive Flutter application that monitors running activity using your phone's built-in sensors. Track your runs with real-time step counting, GPS tracking, interactive maps, and detailed performance analytics.

## Features

### Core Functionality
- **Real-time Step Counting**: Uses the phone's pedometer sensor to accurately count steps
- **GPS Location Tracking**: Tracks your running route with high-accuracy GPS
- **Live Statistics**: Display real-time data including:
  - Step count
  - Distance traveled (km)
  - Current speed (km/h)
  - Average pace (min/km)
  - Elapsed time
- **Session Management**: Start and stop running sessions with simple controls
- **Local Data Storage**: All data saved locally using SQLite database

### Analytics & Visualization
- **Session Summary**: Detailed breakdown of each run with key metrics
- **Performance Charts**: Interactive graphs showing:
  - Steps progression over time
  - Speed variations throughout the run
- **Route Visualization**: View your running route on Google Maps with start/end markers
- **Run History**: Browse all previous running sessions with ability to delete

### User Experience
- **Clean Material Design UI**: Modern, responsive interface
- **Battery Optimized**: Efficient sensor and location updates
- **Permission Handling**: Proper runtime permission requests
- **Offline Support**: Works completely offline (except map display)

## App Architecture

### Clean Architecture Pattern

```
lib/
├── main.dart                          # App entry point
├── models/                            # Data models
│   └── running_session.dart           # Session, LocationPoint, DataPoint models
├── services/                          # Business logic & external interactions
│   ├── database_service.dart          # SQLite database operations
│   ├── step_counter_service.dart      # Pedometer sensor handling
│   └── location_service.dart          # GPS location tracking
├── providers/                         # State management
│   └── running_session_provider.dart  # Running session state & coordination
└── screens/                           # UI screens
    ├── home_screen.dart               # Main navigation
    ├── tracking_screen.dart           # Active run tracking UI
    ├── session_summary_screen.dart    # Post-run analytics
    ├── map_screen.dart                # Route visualization
    └── history_screen.dart            # Previous runs list
```

### Key Components

#### 1. Step Counter Service (`step_counter_service.dart`)
Handles pedometer sensor integration:
```dart
// Start tracking steps
await StepCounterService().startTracking();

// Listen to step updates
StepCounterService().stepStream.listen((steps) {
  print('Steps: $steps');
});
```

**How it works:**
- Uses the `pedometer` package to access hardware step counter
- Tracks the starting step count when session begins
- Calculates session steps by subtracting start count from current count
- Broadcasts updates via Stream for real-time UI updates

#### 2. Location Service (`location_service.dart`)
Manages GPS tracking and distance calculation:
```dart
// Start GPS tracking
await LocationService().startTracking();

// Listen to position updates
LocationService().positionStream.listen((position) {
  print('Distance: ${LocationService().totalDistance} km');
  print('Speed: ${position.speed * 3.6} km/h');
});
```

**How it works:**
- Uses `geolocator` package for high-accuracy GPS
- Filters position updates by 5-meter distance to reduce noise
- Calculates distance using Haversine formula between consecutive points
- Converts speed from m/s to km/h for display
- Manages location permissions

#### 3. Database Service (`database_service.dart`)
SQLite database for persistent storage:

**Schema:**
```sql
-- Main session data
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  startTime TEXT NOT NULL,
  endTime TEXT,
  totalSteps INTEGER NOT NULL,
  totalDistance REAL NOT NULL,
  averageSpeed REAL NOT NULL,
  durationSeconds INTEGER NOT NULL
);

-- GPS route points
CREATE TABLE location_points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sessionId TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  timestamp TEXT NOT NULL,
  FOREIGN KEY (sessionId) REFERENCES sessions (id)
);

-- Performance data points for charts
CREATE TABLE data_points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sessionId TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  steps INTEGER NOT NULL,
  speed REAL NOT NULL,
  distance REAL NOT NULL,
  FOREIGN KEY (sessionId) REFERENCES sessions (id)
);
```

#### 4. Running Session Provider (`running_session_provider.dart`)
Central state management using Provider pattern:
- Coordinates step counter and location services
- Maintains running session state
- Handles timer for duration tracking
- Saves data points every second for chart generation
- Provides formatted strings for UI display

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Android Studio / Xcode
- Google Maps API key (for map features)

### Installation Steps

1. **Install Flutter dependencies:**
```bash
flutter pub get
```

2. **Configure Google Maps API:**

**For Android:**
- Get a Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
- Open `android/app/src/main/AndroidManifest.xml`
- Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE"/>
```

**For iOS:**
- Open `ios/Runner/AppDelegate.swift` and add:
```swift
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_ACTUAL_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

3. **Run the app:**
```bash
# For Android
flutter run

# For iOS
flutter run

# For release build
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

### Testing on Physical Device
**Important:** This app requires a physical device for proper testing because:
- Emulators don't have real pedometer sensors
- GPS simulation in emulators is limited
- Real-world movement is needed for accurate testing

## Permissions

The app requests the following permissions:

**Android:**
- `ACCESS_FINE_LOCATION` - High-accuracy GPS tracking
- `ACCESS_COARSE_LOCATION` - Network-based location
- `ACTIVITY_RECOGNITION` - Step counter sensor access
- `ACCESS_BACKGROUND_LOCATION` - Location tracking during run (Android 10+)

**iOS:**
- `NSLocationWhenInUseUsageDescription` - Location access during app use
- `NSMotionUsageDescription` - Motion sensor (pedometer) access

Permissions are requested at runtime when starting a run session.

## Battery Optimization

The app is optimized for battery efficiency:
- **Location updates**: Filtered by 5-meter distance changes (not time-based)
- **Sensor sampling**: Uses hardware step counter (low power consumption)
- **Data saving**: Batched database writes every second
- **UI updates**: Throttled to necessary frequency only

## How This App Differs from Default Health Apps

### Advantages Over Built-in Running Apps:

1. **Simplified, Running-Focused UI**
   - Clean interface designed specifically for runners
   - Large, easy-to-read statistics during runs
   - No clutter from other fitness features

2. **Full Data Control**
   - All data stored locally on your device
   - No cloud sync or account requirements
   - Export and own your data completely
   - No privacy concerns about data sharing

3. **Customization Potential**
   - Open source allows feature additions
   - Can add custom metrics or goals
   - Modify UI to personal preferences
   - Add gamification features

4. **Interactive Route Maps**
   - View detailed route maps with polylines
   - See start/end markers
   - Zoom and pan to explore your route
   - Compare routes from different sessions

5. **Detailed Performance Analytics**
   - Custom charts for steps and speed
   - Granular second-by-second data points
   - Export data for external analysis
   - Historical trend analysis

6. **Educational Value**
   - Learn Flutter sensor integration
   - Understand GPS tracking implementation
   - Database design patterns
   - State management in practice

7. **No Bloat**
   - Only running features (no social, challenges, etc.)
   - Fast app startup
   - Minimal storage footprint
   - No ads or premium upsells

8. **Cross-Platform**
   - Same experience on Android and iOS
   - Consistent UI across devices
   - Easy to port to web/desktop if needed

## Technical Highlights

### Sensor Integration
- **Pedometer**: Direct hardware step counter access for accuracy
- **GPS**: High-accuracy mode with distance filtering
- **Real-time Streams**: Reactive programming with StreamController

### Data Management
- **Relational Database**: Proper SQLite schema with foreign keys
- **Efficient Queries**: Indexed lookups for fast history browsing
- **Data Integrity**: Transaction-safe operations

### State Management
- **Provider Pattern**: Clean separation of UI and business logic
- **ChangeNotifier**: Efficient UI updates on state changes
- **Stream Integration**: Real-time sensor data binding

### Performance
- **Lazy Loading**: Charts generated only when viewing summary
- **Memory Efficient**: Streams closed when not needed
- **Battery Conscious**: Smart sensor sampling rates

## Future Enhancement Ideas

- Goal setting and achievement system
- Audio feedback during runs
- Weekly/monthly statistics summaries
- Export runs to GPX/TCX formats
- Interval training support
- Heart rate monitor integration
- Weather data integration
- Social sharing features
- Custom workout plans

## Troubleshooting

**Steps not counting:**
- Ensure ACTIVITY_RECOGNITION permission granted
- Test on physical device (not emulator)
- Check if device has step counter sensor

**GPS not working:**
- Verify location permissions granted
- Enable device location services
- Test outdoors for better GPS signal
- Check if Google Play Services installed (Android)

**Map not displaying:**
- Verify Google Maps API key configured
- Check API key has Maps SDK enabled
- Ensure internet connection available

**App crashes on startup:**
- Run `flutter clean` and rebuild
- Check all dependencies installed
- Verify minimum SDK versions met

## Dependencies

Key packages used:
- `pedometer` - Step counter sensor access
- `geolocator` - GPS location tracking
- `sqflite` - SQLite database
- `google_maps_flutter` - Map visualization
- `fl_chart` - Performance charts
- `provider` - State management
- `permission_handler` - Runtime permissions

## License

This project is open source and available for educational purposes.

## Contributing

Contributions welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests
- Improve documentation

---

**Happy Running! 🏃‍♂️**
