// ============================================================
//  EcoBuild database (SQLite) - tables follow your ERD
//  Uses Node's built-in sqlite, so nothing to compile/install.
// ============================================================
const fs = require('fs');
const path = require('path');
const { DatabaseSync } = require('node:sqlite');
const cfg = require('./config');

fs.mkdirSync(path.dirname(cfg.DB_FILE), { recursive: true });
const db = new DatabaseSync(cfg.DB_FILE);
db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');

db.exec(`
CREATE TABLE IF NOT EXISTS Building (
  building_ID   INTEGER PRIMARY KEY AUTOINCREMENT,
  building_name TEXT NOT NULL,
  location      TEXT
);

CREATE TABLE IF NOT EXISTS Room (
  room_ID         INTEGER PRIMARY KEY AUTOINCREMENT,
  building_ID     INTEGER NOT NULL REFERENCES Building(building_ID) ON DELETE CASCADE,
  room_name       TEXT NOT NULL,
  floor_plan_data TEXT,
  plan_width      REAL,
  plan_height     REAL
);

CREATE TABLE IF NOT EXISTS Controllers (
  controllers_ID   INTEGER PRIMARY KEY AUTOINCREMENT,
  room_ID          INTEGER NOT NULL REFERENCES Room(room_ID) ON DELETE CASCADE,
  controllers_name TEXT NOT NULL,
  mac_address      TEXT UNIQUE,
  ip_address       TEXT,
  status           TEXT DEFAULT 'offline',
  wifi             INTEGER,
  last_seen        TEXT
);

CREATE TABLE IF NOT EXISTS Sensors (
  sensor_ID     INTEGER PRIMARY KEY AUTOINCREMENT,
  controller_ID INTEGER NOT NULL REFERENCES Controllers(controllers_ID) ON DELETE CASCADE,
  sensor_type   TEXT NOT NULL,
  gpio_pin      INTEGER,
  pos_x         REAL,
  pos_y         REAL
);

CREATE TABLE IF NOT EXISTS Sensor_Readings (
  readings_ID INTEGER PRIMARY KEY AUTOINCREMENT,
  sensor_ID   INTEGER NOT NULL REFERENCES Sensors(sensor_ID) ON DELETE CASCADE,
  temperature REAL,
  humidity    REAL,
  occupied    INTEGER,
  recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_readings_sensor_time ON Sensor_Readings(sensor_ID, recorded_at);

CREATE TABLE IF NOT EXISTS Detection (
  detection_ID     INTEGER PRIMARY KEY AUTOINCREMENT,
  reading_ID       INTEGER REFERENCES Sensor_Readings(readings_ID) ON DELETE SET NULL,
  room_ID          INTEGER NOT NULL REFERENCES Room(room_ID) ON DELETE CASCADE,
  detection_type   TEXT,
  detection_result TEXT,
  detected_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS Appliances (
  appliances_ID   INTEGER PRIMARY KEY AUTOINCREMENT,
  room_ID         INTEGER NOT NULL REFERENCES Room(room_ID) ON DELETE CASCADE,
  controllers_ID  INTEGER REFERENCES Controllers(controllers_ID) ON DELETE SET NULL,
  appliances_name TEXT NOT NULL,
  appliances_type TEXT,
  gpio_pin        INTEGER,
  pos_x           REAL,
  pos_y           REAL
);

CREATE TABLE IF NOT EXISTS Appliance_States (
  states_ID      INTEGER PRIMARY KEY AUTOINCREMENT,
  appliances_ID  INTEGER NOT NULL UNIQUE REFERENCES Appliances(appliances_ID) ON DELETE CASCADE,
  reported_state TEXT DEFAULT 'off',
  desired_state  TEXT DEFAULT 'off',
  in_sync        INTEGER DEFAULT 1,
  updated_at     TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS IR_Command_Codes (
  code_ID       INTEGER PRIMARY KEY AUTOINCREMENT,
  appliances_ID INTEGER NOT NULL REFERENCES Appliances(appliances_ID) ON DELETE CASCADE,
  action        TEXT NOT NULL,
  protocol      TEXT,
  raw_code      TEXT
);

CREATE TABLE IF NOT EXISTS Automation_Rules (
  rules_ID         INTEGER PRIMARY KEY AUTOINCREMENT,
  room_ID          INTEGER NOT NULL REFERENCES Room(room_ID) ON DELETE CASCADE,
  appliances_ID    INTEGER NOT NULL REFERENCES Appliances(appliances_ID) ON DELETE CASCADE,
  rule_name        TEXT,
  trigger_type     TEXT NOT NULL,      -- temperature | humidity | vacancy
  threshold        REAL,
  duration_minutes INTEGER,
  action           TEXT NOT NULL,      -- on | off
  target_value     REAL,
  is_active        INTEGER NOT NULL DEFAULT 1,
  created_at       TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS Users (
  users_ID            INTEGER PRIMARY KEY AUTOINCREMENT,
  users_name          TEXT NOT NULL,
  users_email         TEXT NOT NULL UNIQUE,
  users_password_hash TEXT NOT NULL,
  role                TEXT NOT NULL DEFAULT 'user',   -- admin | user
  created_at          TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS User_Room_Access (
  users_ID INTEGER NOT NULL REFERENCES Users(users_ID) ON DELETE CASCADE,
  room_ID  INTEGER NOT NULL REFERENCES Room(room_ID) ON DELETE CASCADE,
  PRIMARY KEY (users_ID, room_ID)
);

CREATE TABLE IF NOT EXISTS Login_History (
  login_history_ID INTEGER PRIMARY KEY AUTOINCREMENT,
  user_ID          INTEGER REFERENCES Users(users_ID) ON DELETE CASCADE,
  login_time       TEXT DEFAULT (datetime('now')),
  login_status     TEXT,
  raw_code         TEXT
);

CREATE TABLE IF NOT EXISTS Commands (
  command_ID    INTEGER PRIMARY KEY AUTOINCREMENT,
  appliances_ID INTEGER NOT NULL REFERENCES Appliances(appliances_ID) ON DELETE CASCADE,
  user_ID       INTEGER REFERENCES Users(users_ID) ON DELETE SET NULL,
  rule_ID       INTEGER REFERENCES Automation_Rules(rules_ID) ON DELETE SET NULL,
  source        TEXT,                -- user | rule
  action        TEXT NOT NULL,       -- on | off
  status        TEXT NOT NULL DEFAULT 'pending',  -- pending | sent | confirmed | failed
  sent_at       TEXT,
  confirmed_at  TEXT,
  response_ms   INTEGER,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS Notifications (
  notification_ID      INTEGER PRIMARY KEY AUTOINCREMENT,
  user_ID              INTEGER REFERENCES Users(users_ID) ON DELETE CASCADE,  -- NULL = everyone
  room_ID              INTEGER REFERENCES Room(room_ID) ON DELETE CASCADE,
  detection_ID         INTEGER REFERENCES Detection(detection_ID) ON DELETE SET NULL,
  command_ID           INTEGER REFERENCES Commands(command_ID) ON DELETE SET NULL,
  notification_message TEXT NOT NULL,
  notification_is_read INTEGER NOT NULL DEFAULT 0,
  notification_sent_at TEXT NOT NULL DEFAULT (datetime('now')),
  delivered_at         TEXT,
  severity             TEXT NOT NULL DEFAULT 'info'   -- info | warning | danger
);
`);

const all = (sql, ...p) => db.prepare(sql).all(...p);
const get = (sql, ...p) => db.prepare(sql).get(...p);
const run = (sql, ...p) => db.prepare(sql).run(...p);

// ---------------- demo data (only when the database is empty) ----------------
function seed() {
  if (!cfg.SEED_DEMO_DATA) return;
  if (get('SELECT COUNT(*) AS n FROM Building').n > 0) return;

  const mkBuilding = (name, loc) => Number(run('INSERT INTO Building(building_name, location) VALUES (?,?)', name, loc).lastInsertRowid);
  const mkRoom = (b, name) => Number(run('INSERT INTO Room(building_ID, room_name, plan_width, plan_height) VALUES (?,?,?,?)', b, name, 800, 600).lastInsertRowid);
  const mkCtrl = (room, name, mac) => Number(run("INSERT INTO Controllers(room_ID, controllers_name, mac_address) VALUES (?,?,?)", room, name, mac).lastInsertRowid);
  const mkSensor = (c, type, pin) => Number(run('INSERT INTO Sensors(controller_ID, sensor_type, gpio_pin, pos_x, pos_y) VALUES (?,?,?,?,?)', c, type, pin, 100, 100).lastInsertRowid);
  const mkApp = (room, c, name, type, pin) => {
    const id = Number(run('INSERT INTO Appliances(room_ID, controllers_ID, appliances_name, appliances_type, gpio_pin, pos_x, pos_y) VALUES (?,?,?,?,?,?,?)', room, c, name, type, pin, 200, 200).lastInsertRowid);
    run('INSERT INTO Appliance_States(appliances_ID) VALUES (?)', id);
    return id;
  };

  const main = mkBuilding('Main Building', 'Don Bosco Technical College - Cebu');
  const mech = mkBuilding('Mech Lab', 'Don Bosco Technical College - Cebu');
  const comp = mkBuilding('Comp Lab', 'Don Bosco Technical College - Cebu');

  const rooms = [
    [main, 'Room 101'], [main, 'Room 102'], [main, 'Room 103'],
    [mech, 'Mech Room 1'], [mech, 'Mech Room 2'],
    [comp, 'Comp Room 1'], [comp, 'Comp Room 2']
  ];
  let i = 0;
  const dhtIds = [];
  const roomIds = [];
  for (const [b, name] of rooms) {
    i++;
    const r = mkRoom(b, name);
    roomIds.push(r);
    const c = mkCtrl(r, 'ESP32-' + name, 'AA:BB:CC:DD:EE:' + String(i).padStart(2, '0'));
    dhtIds.push(mkSensor(c, 'DHT22', 4));
    mkSensor(c, 'PIR', 5);
    const light = mkApp(r, c, 'Smart Light', 'light', 16);
    const ac = mkApp(r, c, 'Air Conditioner', 'aircon', 17);
    if (name === 'Comp Room 1') mkApp(r, c, 'Fan', 'fan', 18);
    if (name === 'Room 101') mkApp(r, c, 'Kiosk', 'kiosk', 19);
    run("INSERT INTO Automation_Rules(room_ID, appliances_ID, rule_name, trigger_type, duration_minutes, action) VALUES (?,?,?,?,?,?)",
      r, light, 'Turn off lights', 'vacancy', 10, 'off');
    run("INSERT INTO Automation_Rules(room_ID, appliances_ID, rule_name, trigger_type, threshold, action, target_value) VALUES (?,?,?,?,?,?,?)",
      r, ac, 'Air Conditioner', 'temperature', 28, 'on', 24);
  }

  // 12 hours of fake history so the charts are not empty
  for (const sid of dhtIds) {
    for (let h = 12; h >= 1; h--) {
      const t = (26 + Math.sin(h / 2) * 2 + Math.random()).toFixed(1);
      const hum = (58 + Math.random() * 6).toFixed(1);
      run("INSERT INTO Sensor_Readings(sensor_ID, temperature, humidity, recorded_at) VALUES (?,?,?, datetime('now', ?))",
        sid, Number(t), Number(hum), `-${h} hours`);
    }
  }
  console.log('[EcoBuild] demo data inserted');
}
seed();

module.exports = { db, all, get, run };
