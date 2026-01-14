import 'dart:async';
import 'package:pedometer/pedometer.dart';

class StepCounterService {
  static final StepCounterService _instance = StepCounterService._internal();
  factory StepCounterService() => _instance;
  StepCounterService._internal();

  StreamSubscription<StepCount>? _stepCountSubscription;
  final StreamController<int> _stepController = StreamController<int>.broadcast();

  int _sessionStartSteps = 0;
  int _currentSteps = 0;
  bool _isTracking = false;

  Stream<int> get stepStream => _stepController.stream;
  int get currentSteps => _currentSteps;

  Future<void> startTracking() async {
    if (_isTracking) return;

    _isTracking = true;
    _sessionStartSteps = 0;
    _currentSteps = 0;

    _stepCountSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: _onStepCountError,
    );
  }

  void _onStepCount(StepCount event) {
    if (_sessionStartSteps == 0) {
      _sessionStartSteps = event.steps;
    }

    _currentSteps = event.steps - _sessionStartSteps;
    _stepController.add(_currentSteps);
  }

  void _onStepCountError(error) {
    _stepController.addError(error);
  }

  void stopTracking() {
    _isTracking = false;
    _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
  }

  void reset() {
    _sessionStartSteps = 0;
    _currentSteps = 0;
  }

  void dispose() {
    stopTracking();
    _stepController.close();
  }
}
