import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('trackbound.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    // Initial CREATE TABLE statements
    final createStatements = <String>[
      '''PRAGMA foreign_keys = ON;''',
      '''CREATE TABLE train_services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        operator TEXT,
        mode TEXT,
        description TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      );''',
      '''CREATE TABLE stations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT,
        latitude REAL,
        longitude REAL,
        created_at TEXT DEFAULT (datetime('now'))
      );''',
      '''CREATE INDEX idx_stations_code ON stations(code);''',
      '''CREATE TABLE routes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_id INTEGER NOT NULL REFERENCES train_services(id) ON DELETE CASCADE,
        name TEXT,
        geometry_wkt TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      );''',
      '''CREATE TABLE journeys (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        start_station_id INTEGER REFERENCES stations(id),
        end_station_id INTEGER REFERENCES stations(id),
        service_id INTEGER REFERENCES train_services(id),
        train_number TEXT,
        class TEXT,
        notes TEXT,
        distance_m REAL,
        created_at TEXT DEFAULT (datetime('now'))
      );''',
      '''CREATE INDEX idx_journeys_date ON journeys(date);''',
      '''CREATE TABLE journey_segments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        journey_id INTEGER NOT NULL REFERENCES journeys(id) ON DELETE CASCADE,
        route_id INTEGER REFERENCES routes(id),
        start_point_index INTEGER,
        end_point_index INTEGER,
        geometry_wkt TEXT,
        distance_m REAL,
        created_at TEXT DEFAULT (datetime('now'))
      );''',
      '''CREATE TABLE photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        journey_id INTEGER REFERENCES journeys(id) ON DELETE CASCADE,
        file_path TEXT NOT NULL,
        caption TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      );''',
      '''CREATE TABLE rail_edges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        edge_key TEXT NOT NULL UNIQUE,
        start_lat REAL NOT NULL,
        start_lng REAL NOT NULL,
        end_lat REAL NOT NULL,
        end_lng REAL NOT NULL,
        source_route_id INTEGER REFERENCES routes(id) ON DELETE SET NULL,
        travelled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now'))
      );''',
      '''CREATE INDEX idx_rail_edges_travelled ON rail_edges(travelled);''',
    ];

    final batch = db.batch();
    for (final s in createStatements) {
      batch.execute(s);
    }
    await batch.commit();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''CREATE TABLE IF NOT EXISTS rail_edges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        edge_key TEXT NOT NULL UNIQUE,
        start_lat REAL NOT NULL,
        start_lng REAL NOT NULL,
        end_lat REAL NOT NULL,
        end_lng REAL NOT NULL,
        source_route_id INTEGER REFERENCES routes(id) ON DELETE SET NULL,
        travelled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now'))
      );''');
      await db.execute('''CREATE INDEX IF NOT EXISTS idx_rail_edges_travelled ON rail_edges(travelled);''');
    }
  }

  Future close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
