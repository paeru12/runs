import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/running_session.dart';
import '../services/step_counter_service.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import 'package:geolocator/geolocator.dart';

class RunningSessionProvider extends ChangeNotifier {
  final StepCounterService _stepService = StepCounterService();
  final LocationService _locationService = LocationService();
  final DatabaseService _dbService = DatabaseService();

  RunningSession? _currentSession;
  bool _isRunning = false;
  DateTime? _startTime;
  Timer? _durationTimer;
  int _elapsedSeconds = 0;

  int _steps = 0;
  double _distance = 0;
  double _speed = 0;

  final List<LocationPoint> _routePoints = [];
  final List<SessionDataPoint> _dataPoints = [];

  StreamSubscription? _stepSubscription;
  StreamSubscription? _locationSubscription;

  bool get isRunning => _isRunning;
  int get steps => _steps;
  double get distance => _distance;
  double get speed => _speed;
  int get elapsedSeconds => _elapsedSeconds;
  RunningSession? get currentSession => _currentSession;
  List<LocationPoint> get routePoints => List.unmodifiable(_routePoints);

  String get formattedDuration {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get formattedDistance {
    return _distance.toStringAsFixed(2);
  }

  String get formattedSpeed {
    return _speed.toStringAsFixed(1);
  }

  String get formattedPace {
    if (_distance == 0) return '0:00';
    final paceMinutes = _elapsedSeconds / 60 / _distance;
    final minutes = paceMinutes.floor();
    final seconds = ((paceMinutes - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> startSession() async {
    if (_isRunning) return;

    try {
      final hasPermission = await _locationService.checkPermissions();
      if (!hasPermission) {
        throw Exception('Location permissions required');
      }

      _isRunning = true;
      _startTime = DateTime.now();
      _elapsedSeconds = 0;
      _steps = 0;
      _distance = 0;
      _speed = 0;
      _routePoints.clear();
      _dataPoints.clear();

      final sessionId = const Uuid().v4();
      _currentSession = RunningSession(
        id: sessionId,
        startTime: _startTime!,
        totalSteps: 0,
        totalDistance: 0,
        averageSpeed: 0,
        durationSeconds: 0,
        routePoints: [],
        dataPoints: [],
      );

      await _dbService.insertSession(_currentSession!);

      await _stepService.startTracking();
      await _locationService.startTracking();

      _stepSubscription = _stepService.stepStream.listen((stepCount) {
        _steps = stepCount;
        notifyListeners();
      });

      _locationSubscription = _locationService.positionStream.listen((position) {
        _distance = _locationService.totalDistance;
        _speed = position.speed * 3.6;

        final locationPoint = LocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
          sessionId: sessionId,
        );
        _routePoints.add(locationPoint);
        _dbService.insertLocationPoint(locationPoint);

        notifyListeners();
      });

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _elapsedSeconds++;

        final dataPoint = SessionDataPoint(
          timestamp: DateTime.now(),
          steps: _steps,
          speed: _speed,
          distance: _distance,
          sessionId: sessionId,
        );
        _dataPoints.add(dataPoint);
        _dbService.insertDataPoint(dataPoint);

        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      _isRunning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopSession() async {
    if (!_isRunning) return;

    _isRunning = false;
    _durationTimer?.cancel();
    _stepSubscription?.cancel();
    _locationSubscription?.cancel();

    _stepService.stopTracking();
    _locationService.stopTracking();

    if (_currentSession != null) {
      final averageSpeed = _distance > 0 ? (_distance / (_elapsedSeconds / 3600)) : 0;

      final updatedSession = RunningSession(
        id: _currentSession!.id,
        startTime: _currentSession!.startTime,
        endTime: DateTime.now(),
        totalSteps: _steps,
        totalDistance: _distance,
        averageSpeed: averageSpeed,
        durationSeconds: _elapsedSeconds,
        routePoints: _routePoints,
        dataPoints: _dataPoints,
      );

      await _dbService.updateSession(updatedSession);
      _currentSession = updatedSession;
    }

    notifyListeners();
  }

  void resetSession() {
    _currentSession = null;
    _steps = 0;
    _distance = 0;
    _speed = 0;
    _elapsedSeconds = 0;
    _routePoints.clear();
    _dataPoints.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _stepSubscription?.cancel();
    _locationSubscription?.cancel();
    _stepService.dispose();
    _locationService.dispose();
    super.dispose();
  }
}
