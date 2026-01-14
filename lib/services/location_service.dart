import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/running_session.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();

  Position? _lastPosition;
  double _totalDistance = 0;
  double _currentSpeed = 0;
  bool _isTracking = false;

  Stream<Position> get positionStream => _positionController.stream;
  double get totalDistance => _totalDistance;
  double get currentSpeed => _currentSpeed;
  Position? get lastPosition => _lastPosition;

  Future<bool> checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      throw Exception('Location permissions not granted');
    }

    _isTracking = true;
    _totalDistance = 0;
    _lastPosition = null;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: _onPositionError,
    );
  }

  void _onPositionUpdate(Position position) {
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance > 0 && distance < 100) {
        _totalDistance += distance / 1000;
      }
    }

    _currentSpeed = position.speed * 3.6;
    _lastPosition = position;
    _positionController.add(position);
  }

  void _onPositionError(error) {
    _positionController.addError(error);
  }

  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void reset() {
    _totalDistance = 0;
    _currentSpeed = 0;
    _lastPosition = null;
  }

  List<LocationPoint> getRoutePoints(String sessionId) {
    return [];
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
