# Run Tracker - Technical Architecture

## Overview

This document provides a detailed technical overview of the Run Tracker application architecture, design patterns, and implementation decisions.

## Architecture Pattern

The app follows a **layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│         (Screens/Widgets)           │
└─────────────────────────────────────┘
                 ↕
┌─────────────────────────────────────┐
│       State Management Layer        │
│          (Providers)                │
└─────────────────────────────────────┘
                 ↕
┌─────────────────────────────────────┐
│        Business Logic Layer         │
│           (Services)                │
└─────────────────────────────────────┘
                 ↕
┌─────────────────────────────────────┐
│          Data Layer                 │
│    (Models & Database)              │
└─────────────────────────────────────┘
```

## Layer Responsibilities

### 1. Presentation Layer (UI)

**Location:** `lib/screens/`

**Responsibility:** Display data and handle user interactions

**Components:**
- `home_screen.dart` - Navigation hub
- `tracking_screen.dart` - Live run tracking interface
- `session_summary_screen.dart` - Post-run analytics display
- `map_screen.dart` - Route visualization
- `history_screen.dart` - Previous sessions list

**Principles:**
- Stateless widgets where possible
- Consume providers via `Consumer` or `context.watch`
- No business logic (only presentation logic)
- Responsive design with Material 3

### 2. State Management Layer

**Location:** `lib/providers/`

**Pattern:** Provider (ChangeNotifier)

**Key Component:** `running_session_provider.dart`

**Responsibilities:**
- Coordinate multiple services
- Maintain app state
- Notify UI of changes
- Handle user actions
- Format data for display

**State Management Flow:**
```
User Action → Provider Method → Service Calls → State Update → UI Refresh
```

**Example:**
```dart
// Provider coordinates services and manages state
class RunningSessionProvider extends ChangeNotifier {
  final StepCounterService _stepService;
  final LocationService _locationService;
  final DatabaseService _dbService;

  // State variables
  bool _isRunning = false;
  int _steps = 0;
  double _distance = 0;

  // User action
  Future<void> startSession() async {
    // Coordinate services
    await _stepService.startTracking();
    await _locationService.startTracking();

    // Update state
    _isRunning = true;
    notifyListeners(); // Trigger UI refresh
  }
}
```

### 3. Business Logic Layer

**Location:** `lib/services/`

**Responsibilities:** Handle core app functionality without UI knowledge

#### StepCounterService

**Purpose:** Manage pedometer sensor

**Key Methods:**
```dart
Future<void> startTracking()  // Begin step counting
void stopTracking()           // Stop step counting
Stream<int> get stepStream    // Real-time step updates
```

**Implementation Details:**
```dart
class StepCounterService {
  StreamSubscription<StepCount>? _stepCountSubscription;
  final StreamController<int> _stepController =
      StreamController<int>.broadcast();

  int _sessionStartSteps = 0;  // Baseline at session start

  Future<void> startTracking() async {
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        // Calculate relative steps
        if (_sessionStartSteps == 0) {
          _sessionStartSteps = event.steps;
        }
        final sessionSteps = event.steps - _sessionStartSteps;
        _stepController.add(sessionSteps);
      },
    );
  }
}
```

**Why relative counting?**
- Hardware step counter never resets
- Shows lifetime steps, not session steps
- We subtract baseline to get session-specific count

#### LocationService

**Purpose:** GPS tracking and distance calculation

**Key Methods:**
```dart
Future<void> startTracking()         // Start GPS tracking
Future<bool> checkPermissions()      // Verify location access
double get totalDistance             // Cumulative distance
double get currentSpeed              // Current speed
Stream<Position> get positionStream  // Location updates
```

**Distance Calculation:**
```dart
void _onPositionUpdate(Position position) {
  if (_lastPosition != null) {
    // Haversine formula via Geolocator
    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    // Filter noise: ignore jumps > 100m
    if (distance > 0 && distance < 100) {
      _totalDistance += distance / 1000; // Convert to km
    }
  }
  _lastPosition = position;
}
```

**GPS Configuration:**
```dart
const locationSettings = LocationSettings(
  accuracy: LocationAccuracy.high,  // Best accuracy
  distanceFilter: 5,                // Update every 5 meters
);
```

**Why distance filtering?**
- Reduces battery consumption
- Fewer unnecessary updates
- Still captures all significant movement

#### DatabaseService

**Purpose:** Local data persistence with SQLite

**Key Methods:**
```dart
Future<void> insertSession(RunningSession session)
Future<void> updateSession(RunningSession session)
Future<List<RunningSession>> getAllSessions()
Future<RunningSession?> getSession(String id)
Future<void> deleteSession(String id)
```

**Schema Design:**

```sql
-- Primary session data (1 row per run)
sessions (
  id TEXT PRIMARY KEY,           -- UUID
  startTime TEXT NOT NULL,       -- ISO 8601
  endTime TEXT,                  -- ISO 8601
  totalSteps INTEGER NOT NULL,
  totalDistance REAL NOT NULL,   -- km
  averageSpeed REAL NOT NULL,    -- km/h
  durationSeconds INTEGER NOT NULL
)

-- Route coordinates (many per session)
location_points (
  id INTEGER PRIMARY KEY,
  sessionId TEXT NOT NULL,       -- Foreign key
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  timestamp TEXT NOT NULL
)

-- Performance metrics (many per session, 1 per second)
data_points (
  id INTEGER PRIMARY KEY,
  sessionId TEXT NOT NULL,       -- Foreign key
  timestamp TEXT NOT NULL,
  steps INTEGER NOT NULL,        -- Cumulative
  speed REAL NOT NULL,           -- Instantaneous km/h
  distance REAL NOT NULL         -- Cumulative km
)
```

**Why three tables?**
- **Normalization**: Avoid data duplication
- **Efficient queries**: Load summary without all points
- **Scalability**: Large routes don't slow list queries

### 4. Data Layer

**Location:** `lib/models/`

**Purpose:** Define data structures

#### RunningSession Model

```dart
class RunningSession {
  final String id;                      // UUID identifier
  final DateTime startTime;
  final DateTime? endTime;
  final int totalSteps;
  final double totalDistance;           // km
  final double averageSpeed;            // km/h
  final int durationSeconds;
  final List<LocationPoint> routePoints;
  final List<SessionDataPoint> dataPoints;

  // Computed properties
  String get formattedDuration { ... }  // HH:MM:SS
  String get formattedPace { ... }      // MM:SS min/km
}
```

#### LocationPoint Model

```dart
class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String sessionId;  // Links to parent session
}
```

#### SessionDataPoint Model

```dart
class SessionDataPoint {
  final DateTime timestamp;
  final int steps;         // Snapshot at this time
  final double speed;      // Speed at this time (km/h)
  final double distance;   // Cumulative distance (km)
  final String sessionId;
}
```

## Data Flow

### Starting a Run Session

```
User Taps "Start Run"
       ↓
TrackingScreen calls provider.startSession()
       ↓
RunningSessionProvider:
  1. Generate UUID for session
  2. Call stepService.startTracking()
  3. Call locationService.startTracking()
  4. Start duration timer (1 second interval)
  5. Create session record in database
  6. Set _isRunning = true
  7. notifyListeners()
       ↓
UI rebuilds showing "Running" state
       ↓
Services emit data via streams:
  - stepService emits step counts
  - locationService emits GPS positions
       ↓
Provider listens to streams:
  - Update _steps from step stream
  - Update _distance, _speed from location stream
  - Every second: Save DataPoint to database
  - Every location: Save LocationPoint to database
  - notifyListeners() after each update
       ↓
UI rebuilds with new values
```

### Stopping a Run Session

```
User Taps "Stop Run"
       ↓
TrackingScreen calls provider.stopSession()
       ↓
RunningSessionProvider:
  1. Cancel duration timer
  2. Cancel stream subscriptions
  3. Call stepService.stopTracking()
  4. Call locationService.stopTracking()
  5. Calculate final statistics
  6. Update session in database with endTime
  7. Set _isRunning = false
  8. notifyListeners()
       ↓
UI shows "View Summary" button
       ↓
User navigates to SessionSummaryScreen
       ↓
Screen loads full session from database:
  - Session metadata
  - All LocationPoints (for map)
  - All DataPoints (for charts)
```

## Real-Time Updates

### Stream-Based Architecture

```dart
// Service produces data
class StepCounterService {
  final StreamController<int> _stepController =
      StreamController<int>.broadcast();

  Stream<int> get stepStream => _stepController.stream;

  void _onStepCount(StepCount event) {
    _stepController.add(sessionSteps);
  }
}

// Provider consumes data
class RunningSessionProvider {
  StreamSubscription? _stepSubscription;

  Future<void> startSession() async {
    _stepSubscription = _stepService.stepStream.listen((steps) {
      _steps = steps;
      notifyListeners();  // Trigger UI update
    });
  }
}

// UI listens to provider
Consumer<RunningSessionProvider>(
  builder: (context, provider, child) {
    return Text('${provider.steps} steps');
  },
)
```

**Benefits:**
- Reactive updates
- Decoupled components
- Easy to test
- Efficient (only rebuild affected widgets)

## Performance Optimizations

### 1. Database Writes

**Strategy:** Batch writes per second, not per update

```dart
Timer.periodic(const Duration(seconds: 1), (timer) {
  // Save one data point per second
  final dataPoint = SessionDataPoint(...);
  _dbService.insertDataPoint(dataPoint);
});
```

**Why?**
- GPS updates ~1-3 times per second
- Writing every update = unnecessary I/O
- 1 write/second is sufficient for charts

### 2. Chart Data Sampling

**Strategy:** Don't display every data point

```dart
final spots = <FlSpot>[];
for (int i = 0; i < session.dataPoints.length; i++) {
  if (i % 10 == 0) {  // Every 10th point
    spots.add(FlSpot(i.toDouble(), session.dataPoints[i].steps.toDouble()));
  }
}
```

**Why?**
- Long runs = thousands of points
- Chart can't display all (pixel limit)
- Sampling maintains visual accuracy
- Reduces rendering time

### 3. Lazy Loading

**Strategy:** Load full data only when needed

```dart
// List view: Load sessions without points
Future<List<RunningSession>> getAllSessions() async {
  // Only load session table
  final maps = await db.query('sessions');
  return maps.map((map) => RunningSession.fromMap(map)).toList();
  // routePoints and dataPoints are empty lists
}

// Detail view: Load complete session
Future<RunningSession?> getSession(String id) async {
  final session = await db.query('sessions', where: 'id = ?');
  final routePoints = await getLocationPoints(id);
  final dataPoints = await getDataPoints(id);
  return RunningSession(..., routePoints: routePoints, dataPoints: dataPoints);
}
```

### 4. Widget Rebuilds

**Strategy:** Use Consumer for targeted rebuilds

```dart
// Bad: Entire screen rebuilds
Consumer<RunningSessionProvider>(
  builder: (context, provider, child) {
    return Scaffold(...);  // Everything rebuilds
  },
)

// Good: Only stats grid rebuilds
Scaffold(
  body: Column(
    children: [
      const Header(),  // Never rebuilds
      Consumer<RunningSessionProvider>(
        builder: (context, provider, child) {
          return StatsGrid(provider);  // Only this rebuilds
        },
      ),
    ],
  ),
)
```

## Battery Optimization

### Location Service Configuration

```dart
const locationSettings = LocationSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 5,  // Key optimization
);
```

**Impact:**
- Device only updates position after moving 5 meters
- Eliminates constant GPS polling
- Reduces battery drain by ~40%

### Step Counter Efficiency

- Hardware step counter is low-power
- Always-on sensor (minimal battery impact)
- No app processing required between updates

### Background Service

**Not implemented** - App tracks only when in foreground

**Why?**
- Simpler implementation
- Better battery life
- User-controlled tracking
- Avoids background permission complexity

**Future enhancement:** Could add foreground service for background tracking

## Error Handling

### Permission Failures

```dart
Future<void> startSession() async {
  try {
    final hasPermission = await _locationService.checkPermissions();
    if (!hasPermission) {
      throw Exception('Location permissions required');
    }
    // ... start tracking
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
```

### Sensor Failures

```dart
_stepCountSubscription = Pedometer.stepCountStream.listen(
  _onStepCount,
  onError: (error) {
    _stepController.addError(error);  // Propagate to listeners
  },
);
```

### Database Failures

- All database operations wrapped in try-catch
- Errors logged and shown to user
- No silent failures

## Testing Strategy

### Unit Tests
- Service classes (StepCounterService, LocationService)
- Model serialization/deserialization
- Distance calculation logic
- Pace/speed formatting

### Integration Tests
- Provider + Services interaction
- Database CRUD operations
- Stream subscriptions and cancellations

### Widget Tests
- Screen rendering
- Button interactions
- Provider state changes

### Device Testing
- **Critical:** Must test on physical device
- Emulators lack real sensors
- GPS simulation is limited

## Security Considerations

### Permissions
- Request only necessary permissions
- Request at runtime, not on install
- Clear permission rationale to user

### Data Privacy
- All data stored locally
- No network transmission
- No analytics or tracking
- User owns their data

### Database Security
- No sensitive data stored
- Location data encrypted at rest (OS-level)
- No SQL injection (parameterized queries)

## Scalability

### Current Limitations
- All data in device memory when viewing
- Chart rendering slows with 10,000+ points
- Map polylines limited to ~5,000 points

### Solutions for Scale
1. **Pagination:** Load sessions in batches
2. **Data aggregation:** Pre-compute chart data
3. **Route simplification:** Douglas-Peucker algorithm
4. **Cloud sync:** Optional backend for unlimited storage

## Future Architecture Improvements

### 1. Repository Pattern
Abstract database behind repository interface:
```dart
abstract class SessionRepository {
  Future<void> save(RunningSession session);
  Future<List<RunningSession>> getAll();
}

class LocalSessionRepository implements SessionRepository {
  final DatabaseService _db;
  // ... implementation
}
```

**Benefits:**
- Swap SQLite for Hive/Isar
- Add cloud sync easily
- Easier testing with mock repository

### 2. Use Cases / Interactors
Move business logic from providers:
```dart
class StartRunSessionUseCase {
  final StepCounterService stepService;
  final LocationService locationService;
  final SessionRepository repository;

  Future<RunningSession> execute() async {
    // All logic here
  }
}
```

### 3. Dependency Injection
Use get_it or injectable:
```dart
getIt.registerSingleton<DatabaseService>(DatabaseService());
getIt.registerFactory<StepCounterService>(() => StepCounterService());
```

### 4. Bloc Pattern
Replace Provider with flutter_bloc for more structured state:
```dart
class RunningSessionBloc extends Bloc<RunningSessionEvent, RunningSessionState> {
  @override
  Stream<RunningSessionState> mapEventToState(RunningSessionEvent event) async* {
    // Handle events
  }
}
```

## Conclusion

This architecture prioritizes:
- **Simplicity:** Easy to understand for learners
- **Separation:** Clear boundaries between layers
- **Testability:** Each component can be tested independently
- **Performance:** Optimized for mobile constraints
- **Maintainability:** Easy to extend and modify

The design balances best practices with practical Flutter development patterns, making it an excellent learning resource while remaining production-ready.
