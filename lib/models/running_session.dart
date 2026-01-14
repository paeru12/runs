class RunningSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int totalSteps;
  final double totalDistance;
  final double averageSpeed;
  final int durationSeconds;
  final List<LocationPoint> routePoints;
  final List<SessionDataPoint> dataPoints;

  RunningSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.totalSteps,
    required this.totalDistance,
    required this.averageSpeed,
    required this.durationSeconds,
    required this.routePoints,
    required this.dataPoints,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'totalSteps': totalSteps,
      'totalDistance': totalDistance,
      'averageSpeed': averageSpeed,
      'durationSeconds': durationSeconds,
    };
  }

  factory RunningSession.fromMap(Map<String, dynamic> map) {
    return RunningSession(
      id: map['id'],
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      totalSteps: map['totalSteps'],
      totalDistance: map['totalDistance'],
      averageSpeed: map['averageSpeed'],
      durationSeconds: map['durationSeconds'],
      routePoints: [],
      dataPoints: [],
    );
  }

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get formattedPace {
    if (totalDistance == 0) return '0:00';
    final paceMinutes = durationSeconds / 60 / totalDistance;
    final minutes = paceMinutes.floor();
    final seconds = ((paceMinutes - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} min/km';
  }
}

class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String sessionId;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.sessionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
    };
  }

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      latitude: map['latitude'],
      longitude: map['longitude'],
      timestamp: DateTime.parse(map['timestamp']),
      sessionId: map['sessionId'],
    );
  }
}

class SessionDataPoint {
  final DateTime timestamp;
  final int steps;
  final double speed;
  final double distance;
  final String sessionId;

  SessionDataPoint({
    required this.timestamp,
    required this.steps,
    required this.speed,
    required this.distance,
    required this.sessionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'steps': steps,
      'speed': speed,
      'distance': distance,
      'sessionId': sessionId,
    };
  }

  factory SessionDataPoint.fromMap(Map<String, dynamic> map) {
    return SessionDataPoint(
      timestamp: DateTime.parse(map['timestamp']),
      steps: map['steps'],
      speed: map['speed'],
      distance: map['distance'],
      sessionId: map['sessionId'],
    );
  }
}
