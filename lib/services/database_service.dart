import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/running_session.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'run_tracker.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        startTime TEXT NOT NULL,
        endTime TEXT,
        totalSteps INTEGER NOT NULL,
        totalDistance REAL NOT NULL,
        averageSpeed REAL NOT NULL,
        durationSeconds INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE location_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE data_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        steps INTEGER NOT NULL,
        speed REAL NOT NULL,
        distance REAL NOT NULL,
        FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> insertSession(RunningSession session) async {
    final db = await database;
    await db.insert('sessions', session.toMap());
  }

  Future<void> updateSession(RunningSession session) async {
    final db = await database;
    await db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> insertLocationPoint(LocationPoint point) async {
    final db = await database;
    await db.insert('location_points', point.toMap());
  }

  Future<void> insertDataPoint(SessionDataPoint point) async {
    final db = await database;
    await db.insert('data_points', point.toMap());
  }

  Future<List<RunningSession>> getAllSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      orderBy: 'startTime DESC',
    );

    return List.generate(maps.length, (i) {
      return RunningSession.fromMap(maps[i]);
    });
  }

  Future<RunningSession?> getSession(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final session = RunningSession.fromMap(maps[0]);
    final routePoints = await getLocationPoints(id);
    final dataPoints = await getDataPoints(id);

    return RunningSession(
      id: session.id,
      startTime: session.startTime,
      endTime: session.endTime,
      totalSteps: session.totalSteps,
      totalDistance: session.totalDistance,
      averageSpeed: session.averageSpeed,
      durationSeconds: session.durationSeconds,
      routePoints: routePoints,
      dataPoints: dataPoints,
    );
  }

  Future<List<LocationPoint>> getLocationPoints(String sessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'location_points',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return LocationPoint.fromMap(maps[i]);
    });
  }

  Future<List<SessionDataPoint>> getDataPoints(String sessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'data_points',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return SessionDataPoint.fromMap(maps[i]);
    });
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
