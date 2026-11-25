// ============================================================
//  EcoBuild backend  -  NO LOGIN  +  Neon (PostgreSQL)
//  Every Node-RED function node calls:  global.get('eco').handle('<route name>', msg)
//  Everybody who opens the web app is treated as the admin user.
//  (ESP32 device routes still check the x-device-key header.)
// ============================================================
const cfg = require('./config');
const db = require('./db');
const { all, get, run, ins, NOW } = db;

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
const bad = (m) => new HttpError(400, m);
const must = (row, m = 'Not found') => { if (!row) throw new HttpError(404, m); return row; };
const ok = (data, status = 200) => ({ status, body: { success: true, data } });
const raw = (status, body) => ({ status, body });
const isEmail = (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e);
const num = (v, d = null) => (v === undefined || v === null || v === '' ? d : Number(v));
const str = (v) => (typeof v === 'string' ? v.trim() : '');
const onOff = (v) => {
  const a = String(v || '').toLowerCase();
  if (a !== 'on' && a !== 'off') throw bad("action must be 'on' or 'off'");
  return a;
};

// "NOW minus <interval>" (only ever used with fixed values written in this file)
const ago = (interval) => `(${NOW} - interval '${interval}')`;
const OFFLINE = `(c.last_seen IS NOT NULL AND c.last_seen >= ${ago(Number(cfg.OFFLINE_AFTER_SECONDS) + ' seconds')})`;

// ---------------- start-up (create tables on first run) ----------------
let readyPromise = null;
function ensureReady() {
  if (!readyPromise) {
    readyPromise = db.init().then(() => console.log('[EcoBuild] Neon database ready'))
      .catch((e) => { readyPromise = null; throw e; });
  }
  return readyPromise;
}
ensureReady().catch((e) => console.error('[EcoBuild] database not ready yet:', e.message));

// ---------------- the one default user (login removed) ----------------
let cachedUser = null;
async function defaultUser() {
  if (cachedUser) return cachedUser;
  let u = await get(`SELECT * FROM Users ORDER BY CASE WHEN role='admin' THEN 0 ELSE 1 END, users_ID LIMIT 1`);
  if (!u) {
    const id = await ins(
      'INSERT INTO Users(users_name, users_email, users_password_hash, role) VALUES (?,?,?,?) RETURNING users_ID',
      'Admin', 'admin@ecobuild.local', 'login-disabled', 'admin');
    u = await get('SELECT * FROM Users WHERE users_ID=?', id);
  }
  cachedUser = { ...u, role: 'admin' };
  return cachedUser;
}
const publicUser = (u) => ({
  id: u.users_ID,
  users_ID: u.users_ID,
  name: u.users_name,
  email: u.users_email,
  role: u.role,
  created_at: u.created_at
});

// ---------------- room access ----------------
async function allowedRooms(user) {
  if (user.role === 'admin' || cfg.OPEN_ROOM_ACCESS) return null; // null = all rooms
  return (await all('SELECT room_ID FROM User_Room_Access WHERE users_ID=?', user.users_ID)).map((r) => r.room_ID);
}
async function canSeeRoom(user, roomId) {
  const a = await allowedRooms(user);
  return a === null || a.includes(Number(roomId));
}
async function filterByRoom(user, rows, key = 'room_ID') {
  const a = await allowedRooms(user);
  return a === null ? rows : rows.filter((r) => a.includes(r[key]));
}

// ---------------- reusable queries ----------------
async function latest(roomId, col) {
  const r = await get(
    `SELECT r.${col} AS v FROM Sensor_Readings r
       JOIN Sensors s ON s.sensor_ID = r.sensor_ID
       JOIN Controllers c ON c.controllers_ID = s.controller_ID
      WHERE c.room_ID = ? AND r.${col} IS NOT NULL
      ORDER BY r.readings_ID DESC LIMIT 1`, roomId);
  return r ? r.v : null;
}
async function roomLive(roomId) {
  const [temperature, humidity, occ] = await Promise.all([
    latest(roomId, 'temperature'), latest(roomId, 'humidity'), latest(roomId, 'occupied')
  ]);
  return {
    temperature,
    humidity,
    occupied: occ === null ? null : !!occ,
    status: occ ? 'Occupied' : 'Available'
  };
}
const withLive = (rows) => Promise.all(rows.map(async (r) => ({ ...r, ...(await roomLive(r.room_ID)) })));

const SENSOR_SQL = `
  SELECT s.*, c.room_ID, c.controllers_name, rm.room_name,
    CASE WHEN ${OFFLINE} THEN 1 ELSE 0 END AS online,
    (SELECT r.temperature FROM Sensor_Readings r WHERE r.sensor_ID=s.sensor_ID AND r.temperature IS NOT NULL ORDER BY r.readings_ID DESC LIMIT 1) AS temperature,
    (SELECT r.humidity    FROM Sensor_Readings r WHERE r.sensor_ID=s.sensor_ID AND r.humidity    IS NOT NULL ORDER BY r.readings_ID DESC LIMIT 1) AS humidity,
    (SELECT r.occupied    FROM Sensor_Readings r WHERE r.sensor_ID=s.sensor_ID AND r.occupied    IS NOT NULL ORDER BY r.readings_ID DESC LIMIT 1) AS occupied,
    (SELECT r.recorded_at FROM Sensor_Readings r WHERE r.sensor_ID=s.sensor_ID ORDER BY r.readings_ID DESC LIMIT 1) AS last_reading_at
  FROM Sensors s
  JOIN Controllers c ON c.controllers_ID = s.controller_ID
  JOIN Room rm ON rm.room_ID = c.room_ID`;
const fixSensor = (s) => ({ ...s, online: !!s.online, occupied: s.occupied === null ? null : !!s.occupied });

const APPLIANCE_SQL = `
  SELECT a.*, rm.room_name,
    COALESCE(st.desired_state,'off')  AS state,
    COALESCE(st.reported_state,'off') AS reported_state,
    COALESCE(st.in_sync,1)            AS in_sync,
    st.updated_at                     AS state_updated_at
  FROM Appliances a
  JOIN Room rm ON rm.room_ID = a.room_ID
  LEFT JOIN Appliance_States st ON st.appliances_ID = a.appliances_ID`;
const fixAppliance = (a) => ({ ...a, is_on: a.state === 'on', in_sync: !!a.in_sync });

const RULE_SQL = `
  SELECT ru.*, a.appliances_name, rm.room_name
  FROM Automation_Rules ru
  JOIN Appliances a ON a.appliances_ID = ru.appliances_ID
  JOIN Room rm ON rm.room_ID = ru.room_ID`;
const fixRule = (r) => ({ ...r, is_active: !!r.is_active });

// ---------------- notifications ----------------
function notify({ roomId = null, message, severity = 'info', detectionId = null, commandId = null, userId = null }) {
  return ins(
    `INSERT INTO Notifications(user_ID, room_ID, detection_ID, command_ID, notification_message, severity, delivered_at)
     VALUES (?,?,?,?,?,?, ${NOW}) RETURNING notification_ID`,
    userId, roomId, detectionId, commandId, message, severity);
}
async function notifyOnce(roomId, message, severity, minutes = 10) {
  const dup = await get(
    `SELECT 1 AS x FROM Notifications
      WHERE room_ID IS NOT DISTINCT FROM ? AND severity=? AND notification_message LIKE ?
        AND notification_sent_at >= ${NOW} + ?::interval`,
    roomId, severity, message.split(':')[0] + '%', `-${minutes} minutes`);
  if (!dup) await notify({ roomId, message, severity });
}

// ---------------- commands (appliance control) ----------------
async function queueCommand(applianceId, action, { userId = null, ruleId = null, source = 'user' } = {}) {
  await run('INSERT INTO Appliance_States(appliances_ID) VALUES (?) ON CONFLICT DO NOTHING', applianceId);
  const id = await ins(
    `INSERT INTO Commands(appliances_ID, user_ID, rule_ID, source, action, status) VALUES (?,?,?,?,?, 'pending') RETURNING command_ID`,
    applianceId, userId, ruleId, source, action);
  await run(`UPDATE Appliance_States SET desired_state=?, in_sync=0, updated_at=${NOW} WHERE appliances_ID=?`, action, applianceId);
  if (cfg.AUTO_CONFIRM_COMMANDS) await confirmCommand(id, true);
  return id;
}
async function confirmCommand(commandId, success) {
  const c = must(await get('SELECT * FROM Commands WHERE command_ID=?', commandId), 'Command not found');
  const ms = Math.max(0, Date.now() - Date.parse(String(c.created_at).replace(' ', 'T') + 'Z'));
  if (success) {
    await run(`UPDATE Commands SET status='confirmed', confirmed_at=${NOW}, response_ms=? WHERE command_ID=?`, ms, commandId);
    await run(`UPDATE Appliance_States
                  SET reported_state=?, in_sync = CASE WHEN desired_state=? THEN 1 ELSE 0 END, updated_at=${NOW}
                WHERE appliances_ID=?`, c.action, c.action, c.appliances_ID);
  } else {
    await run(`UPDATE Commands SET status='failed', confirmed_at=${NOW}, response_ms=? WHERE command_ID=?`, ms, commandId);
    const ap = await get('SELECT room_ID, appliances_name FROM Appliances WHERE appliances_ID=?', c.appliances_ID);
    if (ap) await notify({ roomId: ap.room_ID, severity: 'warning', commandId, message: `Command failed: ${ap.appliances_name}` });
  }
}

// ---------------- automation engine ----------------
async function evaluateRules(roomId) {
  const rules = await all('SELECT * FROM Automation_Rules WHERE room_ID=? AND is_active=1', roomId);
  for (const rule of rules) {
    let fire = false;
    if (rule.trigger_type === 'temperature') {
      const t = await latest(roomId, 'temperature');
      fire = t !== null && rule.threshold !== null && t > rule.threshold;
    } else if (rule.trigger_type === 'humidity') {
      const h = await latest(roomId, 'humidity');
      fire = h !== null && rule.threshold !== null && h > rule.threshold;
    } else if (rule.trigger_type === 'vacancy') {
      const mins = rule.duration_minutes || 10;
      if ((await latest(roomId, 'occupied')) === 0) {
        const base = `FROM Sensor_Readings r JOIN Sensors s ON s.sensor_ID=r.sensor_ID
                      JOIN Controllers c ON c.controllers_ID=s.controller_ID
                      WHERE c.room_ID=? AND r.occupied IS NOT NULL`;
        const recent = (await get(`SELECT COUNT(*) AS n ${base} AND r.occupied=1 AND r.recorded_at >= ${NOW} + ?::interval`, roomId, `-${mins} minutes`)).n;
        const history = (await get(`SELECT COUNT(*) AS n ${base} AND r.recorded_at <= ${NOW} + ?::interval`, roomId, `-${mins} minutes`)).n;
        fire = recent === 0 && history > 0;
      }
    }
    if (!fire) continue;

    const st = await get('SELECT desired_state FROM Appliance_States WHERE appliances_ID=?', rule.appliances_ID);
    if (st && st.desired_state === rule.action) continue; // already in that state
    const cool = await get(`SELECT 1 AS x FROM Commands WHERE rule_ID=? AND created_at >= ${ago('10 minutes')}`, rule.rules_ID);
    if (cool) continue; // do not fight the user: wait 10 min between executions

    const cmd = await queueCommand(rule.appliances_ID, rule.action, { ruleId: rule.rules_ID, source: 'rule' });
    await notify({ roomId, commandId: cmd, severity: 'info', message: `Automation Rule Executed: ${rule.rule_name || 'Rule ' + rule.rules_ID}` });
  }
}

// ---------------- reading intake (ESP32 and simulator) ----------------
async function ingestReading(sensorId, d) {
  const sensor = must(await get(
    `SELECT s.*, c.room_ID, rm.room_name FROM Sensors s
       JOIN Controllers c ON c.controllers_ID=s.controller_ID
       JOIN Room rm ON rm.room_ID=c.room_ID WHERE s.sensor_ID=?`, sensorId), `Sensor ${sensorId} not found`);
  const temperature = num(d.temperature);
  const humidity = num(d.humidity);
  const occupied = d.occupied === undefined || d.occupied === null ? null : (d.occupied === true || d.occupied === 1 || d.occupied === '1' || d.occupied === 'true' ? 1 : 0);
  if (temperature === null && humidity === null && occupied === null) throw bad('Send temperature, humidity or occupied');

  const prev = await get('SELECT occupied FROM Sensor_Readings WHERE sensor_ID=? AND occupied IS NOT NULL ORDER BY readings_ID DESC LIMIT 1', sensorId);
  const rid = await ins('INSERT INTO Sensor_Readings(sensor_ID, temperature, humidity, occupied) VALUES (?,?,?,?) RETURNING readings_ID',
    sensorId, temperature, humidity, occupied);
  await run(`UPDATE Controllers SET last_seen=${NOW}, status='online' WHERE controllers_ID=?`, sensor.controller_ID);

  if (occupied !== null && (!prev || prev.occupied !== occupied)) {
    const did = await ins('INSERT INTO Detection(reading_ID, room_ID, detection_type, detection_result) VALUES (?,?,?,?) RETURNING detection_ID',
      rid, sensor.room_ID, 'occupancy', occupied ? 'occupied' : 'vacant');
    await notify({ roomId: sensor.room_ID, detectionId: did, severity: 'info', message: `${sensor.room_name} is now ${occupied ? 'occupied' : 'vacant'}` });
  }
  if (temperature !== null && temperature > cfg.ALERT_TEMP) {
    await notifyOnce(sensor.room_ID, `High Temperature: ${sensor.room_name} is ${temperature}°C`, 'warning', 10);
  }
  await evaluateRules(sensor.room_ID);
  return rid;
}

// Fake data generator for demos without hardware (rooms run in parallel, sensors of one room in order)
async function simulate() {
  const sensors = await all('SELECT s.*, c.room_ID FROM Sensors s JOIN Controllers c ON c.controllers_ID=s.controller_ID ORDER BY s.sensor_ID');
  const byRoom = new Map();
  for (const s of sensors) {
    if (!byRoom.has(s.room_ID)) byRoom.set(s.room_ID, []);
    byRoom.get(s.room_ID).push(s);
  }
  let n = 0;
  await Promise.all([...byRoom.values()].map(async (list) => {
    for (const s of list) {
      const t = String(s.sensor_type).toUpperCase();
      if (t.startsWith('DHT') || t === 'TEMPERATURE') {
        await ingestReading(s.sensor_ID, { temperature: +(25 + Math.random() * 7).toFixed(1), humidity: +(55 + Math.random() * 15).toFixed(1) });
      } else {
        await ingestReading(s.sensor_ID, { occupied: Math.random() < 0.4 });
      }
      n++;
    }
  }));
  return n;
}

// ============================================================
//  ROUTES   (auth: none | user | admin | device)
//  user/admin routes need no login any more - the default admin is used.
// ============================================================
const routes = {
  // ---------- health ----------
  'health': { auth: 'none', run: () => ok({ status: 'ok', time: new Date().toISOString() }) },

  // ---------- account (login removed: these always succeed) ----------
  'auth.signup': {
    auth: 'none',
    run: async () => raw(200, { success: true, message: 'Login is disabled', token: 'no-login', user: publicUser(await defaultUser()) })
  },
  'auth.login': {
    auth: 'none',
    run: async () => raw(200, { success: true, token: 'no-login', user: publicUser(await defaultUser()) })
  },
  'auth.me': { auth: 'user', run: ({ user }) => raw(200, { success: true, user: publicUser(user) }) },
  'auth.updateMe': {
    auth: 'user',
    run: async ({ user, body }) => {
      const name = str(body.name) || user.users_name;
      const email = (str(body.email) || user.users_email).toLowerCase();
      if (!isEmail(email)) throw bad('Invalid email');
      await run('UPDATE Users SET users_name=?, users_email=? WHERE users_ID=?', name, email, user.users_ID);
      cachedUser = null;
      return raw(200, { success: true, user: publicUser(await defaultUser()) });
    }
  },
  'auth.logout': { auth: 'none', run: () => raw(200, { success: true, message: 'Logged out' }) },

  // ---------- dashboard ----------
  'dashboard': {
    auth: 'user',
    run: async ({ user }) => {
      const sensors = await get(`SELECT COUNT(*) AS total, COALESCE(SUM(CASE WHEN ${OFFLINE} THEN 1 ELSE 0 END),0) AS online
                                   FROM Sensors s JOIN Controllers c ON c.controllers_ID=s.controller_ID`);
      const warn = (await get(`SELECT COUNT(*) AS n FROM Notifications WHERE severity IN ('warning','danger') AND notification_is_read=0
                                 AND notification_sent_at >= ${ago('1 hours')}`)).n;
      const recent = (await filterByRoom(user, await all(
        `SELECT n.*, r.room_name FROM Notifications n LEFT JOIN Room r ON r.room_ID=n.room_ID
          WHERE n.user_ID IS NULL OR n.user_ID=? ORDER BY n.notification_ID DESC LIMIT 20`, user.users_ID))).slice(0, 5);
      const [buildings, rooms] = await Promise.all([
        get('SELECT COUNT(*) AS n FROM Building'), get('SELECT COUNT(*) AS n FROM Room')
      ]);
      return ok({
        buildings: buildings.n,
        rooms: rooms.n,
        sensors: sensors.total,
        online_percent: sensors.total ? Math.round((sensors.online / sensors.total) * 100) : 0,
        status: warn === 0 ? 'normal' : 'attention',
        status_text: warn === 0 ? 'All systems Normal' : `${warn} warning(s) need attention`,
        recent_activity: recent.map((n) => ({ message: n.notification_message, severity: n.severity, time: n.notification_sent_at, room_name: n.room_name }))
      });
    }
  },

  // ---------- buildings ----------
  'buildings.list': {
    auth: 'user',
    run: async () => ok(await all(`
      SELECT b.*,
        (SELECT COUNT(*) FROM Room r WHERE r.building_ID=b.building_ID) AS room_count,
        (SELECT COUNT(*) FROM Sensors s JOIN Controllers c ON c.controllers_ID=s.controller_ID
           JOIN Room r ON r.room_ID=c.room_ID WHERE r.building_ID=b.building_ID) AS sensor_count
      FROM Building b ORDER BY b.building_name`))
  },
  'buildings.get': {
    auth: 'user',
    run: async ({ params, user }) => {
      const b = must(await get('SELECT * FROM Building WHERE building_ID=?', params.id), 'Building not found');
      const rows = await filterByRoom(user, await all('SELECT * FROM Room WHERE building_ID=? ORDER BY room_name', b.building_ID));
      return ok({ ...b, rooms: await withLive(rows) });
    }
  },
  'buildings.create': {
    auth: 'admin',
    run: async ({ body }) => {
      const name = str(body.building_name);
      if (!name) throw bad('building_name is required');
      const id = await ins('INSERT INTO Building(building_name, location) VALUES (?,?) RETURNING building_ID', name, str(body.location) || null);
      return ok(await get('SELECT * FROM Building WHERE building_ID=?', id), 201);
    }
  },
  'buildings.update': {
    auth: 'admin',
    run: async ({ params, body }) => {
      const b = must(await get('SELECT * FROM Building WHERE building_ID=?', params.id), 'Building not found');
      await run('UPDATE Building SET building_name=?, location=? WHERE building_ID=?',
        str(body.building_name) || b.building_name, body.location === undefined ? b.location : str(body.location), b.building_ID);
      return ok(await get('SELECT * FROM Building WHERE building_ID=?', b.building_ID));
    }
  },
  'buildings.delete': {
    auth: 'admin',
    run: async ({ params }) => {
      must(await get('SELECT 1 AS x FROM Building WHERE building_ID=?', params.id), 'Building not found');
      await run('DELETE FROM Building WHERE building_ID=?', params.id);
      return ok({ deleted: true });
    }
  },

  // ---------- rooms ----------
  'rooms.list': {
    auth: 'user',
    run: async ({ user, query }) => {
      const rows = query.building_id
        ? await all('SELECT r.*, b.building_name FROM Room r JOIN Building b ON b.building_ID=r.building_ID WHERE r.building_ID=? ORDER BY r.room_name', query.building_id)
        : await all('SELECT r.*, b.building_name FROM Room r JOIN Building b ON b.building_ID=r.building_ID ORDER BY b.building_name, r.room_name');
      let list = await withLive(await filterByRoom(user, rows));
      const q = str(query.search).toLowerCase();
      if (q) list = list.filter((r) => r.room_name.toLowerCase().includes(q));
      return ok(list);
    }
  },
  'rooms.get': {
    auth: 'user',
    run: async ({ user, params }) => {
      const r = must(await get('SELECT r.*, b.building_name FROM Room r JOIN Building b ON b.building_ID=r.building_ID WHERE r.room_ID=?', params.id), 'Room not found');
      if (!(await canSeeRoom(user, r.room_ID))) throw new HttpError(403, 'No access to this room');
      const [live, sensors, appliances] = await Promise.all([
        roomLive(r.room_ID),
        all(SENSOR_SQL + ' WHERE c.room_ID=?', r.room_ID),
        all(APPLIANCE_SQL + ' WHERE a.room_ID=?', r.room_ID)
      ]);
      return ok({ ...r, ...live, sensors: sensors.map(fixSensor), appliances: appliances.map(fixAppliance) });
    }
  },
  'rooms.create': {
    auth: 'admin',
    run: async ({ body }) => {
      const name = str(body.room_name);
      if (!name || !body.building_ID) throw bad('building_ID and room_name are required');
      const id = await ins('INSERT INTO Room(building_ID, room_name, floor_plan_data, plan_width, plan_height) VALUES (?,?,?,?,?) RETURNING room_ID',
        body.building_ID, name, body.floor_plan_data || null, num(body.plan_width), num(body.plan_height));
      return ok(await get('SELECT * FROM Room WHERE room_ID=?', id), 201);
    }
  },
  'rooms.update': {
    auth: 'admin',
    run: async ({ params, body }) => {
      const r = must(await get('SELECT * FROM Room WHERE room_ID=?', params.id), 'Room not found');
      await run('UPDATE Room SET room_name=?, floor_plan_data=?, plan_width=?, plan_height=? WHERE room_ID=?',
        str(body.room_name) || r.room_name,
        body.floor_plan_data === undefined ? r.floor_plan_data : body.floor_plan_data,
        num(body.plan_width, r.plan_width), num(body.plan_height, r.plan_height), r.room_ID);
      return ok(await get('SELECT * FROM Room WHERE room_ID=?', r.room_ID));
    }
  },
  'rooms.delete': {
    auth: 'admin',
    run: async ({ params }) => {
      must(await get('SELECT 1 AS x FROM Room WHERE room_ID=?', params.id), 'Room not found');
      await run('DELETE FROM Room WHERE room_ID=?', params.id);
      return ok({ deleted: true });
    }
  },

  // ---------- controllers (ESP32 boards) ----------
  'controllers.list': {
    auth: 'admin',
    run: async () => ok((await all(`SELECT c.*, rm.room_name, CASE WHEN ${OFFLINE} THEN 1 ELSE 0 END AS online
                                      FROM Controllers c JOIN Room rm ON rm.room_ID=c.room_ID ORDER BY c.controllers_ID`)).map((c) => ({ ...c, online: !!c.online })))
  },
  'controllers.create': {
    auth: 'admin',
    run: async ({ body }) => {
      if (!body.room_ID || !str(body.controllers_name)) throw bad('room_ID and controllers_name are required');
      const id = await ins('INSERT INTO Controllers(room_ID, controllers_name, mac_address, ip_address) VALUES (?,?,?,?) RETURNING controllers_ID',
        body.room_ID, str(body.controllers_name), str(body.mac_address) || null, str(body.ip_address) || null);
      return ok(await get('SELECT * FROM Controllers WHERE controllers_ID=?', id), 201);
    }
  },
  'controllers.delete': {
    auth: 'admin',
    run: async ({ params }) => {
      must(await get('SELECT 1 AS x FROM Controllers WHERE controllers_ID=?', params.id), 'Controller not found');
      await run('DELETE FROM Controllers WHERE controllers_ID=?', params.id);
      return ok({ deleted: true });
    }
  },

  // ---------- sensors ----------
  'sensors.list': {
    auth: 'user',
    run: async ({ user, query }) => {
      const rows = query.room_id ? await all(SENSOR_SQL + ' WHERE c.room_ID=? ORDER BY s.sensor_ID', query.room_id) : await all(SENSOR_SQL + ' ORDER BY s.sensor_ID');
      const list = (await filterByRoom(user, rows)).map(fixSensor);
      const offline = list.filter((s) => !s.online).length;
      return ok({ sensors: list, summary: { total: list.length, offline, status: offline === 0 ? 'All Sensors Normal' : `${offline} sensor(s) offline` } });
    }
  },
  'sensors.create': {
    auth: 'admin',
    run: async ({ body }) => {
      if (!body.controller_ID || !str(body.sensor_type)) throw bad('controller_ID and sensor_type are required');
      const id = await ins('INSERT INTO Sensors(controller_ID, sensor_type, gpio_pin, pos_x, pos_y) VALUES (?,?,?,?,?) RETURNING sensor_ID',
        body.controller_ID, str(body.sensor_type), num(body.gpio_pin), num(body.pos_x), num(body.pos_y));
      return ok(await get('SELECT * FROM Sensors WHERE sensor_ID=?', id), 201);
    }
  },
  'sensors.delete': {
    auth: 'admin',
    run: async ({ params }) => {
      must(await get('SELECT 1 AS x FROM Sensors WHERE sensor_ID=?', params.id), 'Sensor not found');
      await run('DELETE FROM Sensors WHERE sensor_ID=?', params.id);
      return ok({ deleted: true });
    }
  },
  'sensors.readings': {
    auth: 'user',
    run: async ({ params, query }) => {
      const hours = Math.min(Math.max(num(query.hours, 12), 1), 168);
      return ok(await all(`SELECT readings_ID, temperature, humidity, occupied, recorded_at FROM Sensor_Readings
                            WHERE sensor_ID=? AND recorded_at >= ${NOW} + ?::interval ORDER BY readings_ID DESC LIMIT 500`,
        params.id, `-${hours} hours`));
    }
  },
  'sensors.chart': {
    auth: 'user',
    run: async ({ query }) => {
      const col = { temperature: 'temperature', humidity: 'humidity', occupancy: 'occupied' }[String(query.type || 'temperature').toLowerCase()];
      if (!col) throw bad('type must be temperature, humidity or occupancy');
      const hours = Math.min(Math.max(num(query.hours, 12), 1), 168);
      const bucketSecs = (hours <= 1 ? 5 : hours <= 6 ? 30 : 60) * 60;
      const params = [bucketSecs, bucketSecs, `-${hours} hours`];
      let roomSql = '';
      if (query.room_id) { roomSql = ' AND c.room_ID=?'; params.push(Number(query.room_id)); }
      const points = await all(
        `SELECT to_char(to_timestamp((floor(extract(epoch FROM r.recorded_at) / ?::int) * ?::int)::double precision) AT TIME ZONE 'utc', 'YYYY-MM-DD HH24:MI:SS') AS "time",
                ROUND(AVG(r.${col})::numeric, 2) AS "value"
           FROM Sensor_Readings r
           JOIN Sensors s ON s.sensor_ID = r.sensor_ID
           JOIN Controllers c ON c.controllers_ID = s.controller_ID
          WHERE r.${col} IS NOT NULL AND r.recorded_at >= ${NOW} + ?::interval${roomSql}
          GROUP BY 1 ORDER BY 1`, ...params);
      return ok({ type: String(query.type || 'temperature'), hours, points });
    }
  },

  // ---------- appliances ----------
  'appliances.list': {
    auth: 'user',
    run: async ({ user, query }) => {
      const rows = query.room_id ? await all(APPLIANCE_SQL + ' WHERE a.room_ID=? ORDER BY a.appliances_ID', query.room_id) : await all(APPLIANCE_SQL + ' ORDER BY a.appliances_ID');
      return ok((await filterByRoom(user, rows)).map(fixAppliance));
    }
  },
  'appliances.create': {
    auth: 'admin',
    run: async ({ body }) => {
      if (!body.room_ID || !str(body.appliances_name)) throw bad('room_ID and appliances_name are required');
      const id = await ins('INSERT INTO Appliances(room_ID, controllers_ID, appliances_name, appliances_type, gpio_pin, pos_x, pos_y) VALUES (?,?,?,?,?,?,?) RETURNING appliances_ID',
        body.room_ID, num(body.controllers_ID), str(body.appliances_name), str(body.appliances_type) || null,
        num(body.gpio_pin), num(body.pos_x), num(body.pos_y));
      await run('INSERT INTO Appliance_States(appliances_ID) VALUES (?) ON CONFLICT DO NOTHING', id);
      return ok(fixAppliance(await get(APPLIANCE_SQL + ' WHERE a.appliances_ID=?', id)), 201);
    }
  },
  'appliances.update': {
    auth: 'admin',
    run: async ({ params, body }) => {
      const a = must(await get('SELECT * FROM Appliances WHERE appliances_ID=?', params.id), 'Appliance not found');
      await run('UPDATE Appliances SET appliances_name=?, appliances_type=?, controllers_ID=?, gpio_pin=?, pos_x=?, pos_y=? WHERE appliances_ID=?',
        str(body.appliances_name) || a.appliances_name, str(body.appliances_type) || a.appliances_type,
        num(body.controllers_ID, a.controllers_ID), num(body.gpio_pin, a.gpio_pin), num(body.pos_x, a.pos_x), num(body.pos_y, a.pos_y), a.appliances_ID);
      return ok(fixAppliance(await get(APPLIANCE_SQL + ' WHERE a.appliances_ID=?', a.appliances_ID)));
    }
  },
  'appliances.delete': {
    auth: 'admin',
    run: async ({ params }) => {
      must(await get('SELECT 1 AS x FROM Appliances WHERE appliances_ID=?', params.id), 'Appliance not found');
      await run('DELETE FROM Appliances WHERE appliances_ID=?', params.id);
      return ok({ deleted: true });
    }
  },
  'appliances.control': {
    auth: 'user',
    run: async ({ user, params, body }) => {
      const a = must(await get('SELECT * FROM Appliances WHERE appliances_ID=?', params.id), 'Appliance not found');
      if (!(await canSeeRoom(user, a.room_ID))) throw new HttpError(403, 'No access to this room');
      const cmd = await queueCommand(a.appliances_ID, onOff(body.action), { userId: user.users_ID, source: 'user' });
      return ok({ command_ID: cmd, appliance: fixAppliance(await get(APPLIANCE_SQL + ' WHERE a.appliances_ID=?', a.appliances_ID)) });
    }
  },
  'appliances.ir.list': {
    auth: 'admin',
    run: async ({ params }) => ok(await all('SELECT * FROM IR_Command_Codes WHERE appliances_ID=?', params.id))
  },
  'appliances.ir.create': {
    auth: 'admin',
    run: async ({ params, body }) => {
      must(await get('SELECT 1 AS x FROM Appliances WHERE appliances_ID=?', params.id), 'Appliance not found');
      const action = onOff(body.action);
      const id = await ins('INSERT INTO IR_Command_Codes(appliances_ID, action, protocol, raw_code) VALUES (?,?,?,?) RETURNING code_ID',
        params.id, action, str(body.protocol) || null, str(body.raw_code) || null);
      return ok(await get('SELECT * FROM IR_Command_Codes WHERE code_ID=?', id), 201);
    }
  },

  // ---------- automation rules ----------
  'rules.list': {
    auth: 'user',
    run: async ({ user, query }) => {
      const rows = query.room_id ? await all(RULE_SQL + ' WHERE ru.room_ID=? ORDER BY ru.rules_ID', query.room_id) : await all(RULE_SQL + ' ORDER BY ru.rules_ID');
      return ok((await filterByRoom(user, rows)).map(fixRule));
    }
  },
  'rules.create': {
    auth: 'admin',
    run: async ({ body }) => {
      const trig = String(body.trigger_type || '').toLowerCase();
      if (!['temperature', 'humidity', 'vacancy'].includes(trig)) throw bad('trigger_type must be temperature, humidity or vacancy');
      if (!body.room_ID || !body.appliances_ID) throw bad('room_ID and appliances_ID are required');
      if (trig !== 'vacancy' && num(body.threshold) === null) throw bad('threshold is required');
      const id = await ins(`INSERT INTO Automation_Rules(room_ID, appliances_ID, rule_name, trigger_type, threshold, duration_minutes, action, target_value, is_active)
                            VALUES (?,?,?,?,?,?,?,?,?) RETURNING rules_ID`,
        body.room_ID, body.appliances_ID, str(body.rule_name) || null, trig, num(body.threshold), num(body.duration_minutes, trig === 'vacancy' ? 10 : null),
        onOff(body.action), num(body.target_value), body.is_active === false ? 0 : 1);
      return ok(fixRule(await get(RULE_SQL + ' WHERE ru.rules_ID=?', id)), 201);
    }
  },
  'rules.update': {
    auth: 'admin',
    run: async ({ params, body }) => {
      const r = must(await get('SELECT * FROM Automation_Rules WHERE rules_ID=?', params.id), 'Rule not found');
      await run(`UPDATE Automation_Rules SET rule_name=?, trigger_type=?, threshold=?, duration_minutes=?, action=?, target_value=?, is_active=? WHERE rules_ID=?`,
        body.rule_name === undefined ? r.rule_name : str(body.rule_name),
        body.trigger_type ? String(body.trigger_type).toLowerCase() : r.trigger_type,
        num(body.threshold, r.threshold), num(body.duration_minutes, r.duration_minutes),
        body.action ? onOff(body.action) : r.action, num(body.target_value, r.target_value),
        body.is_active === undefined ? r.is_active : (body.is_active ? 1 : 0), r.rules_ID);
      return ok(fixRule(await get(RULE_SQL + ' WHERE ru.rules_ID=?', r.rules_ID)));
    }
  },
  'rules.toggle': {
    auth: 'user',
    run: async ({ user, params, body }) => {
      const r = must(await get('SELECT * FROM Automation_Rules WHERE rules_ID=?', params.id), 'Rule not found');
      if (!(await canSeeRoom(user, r.room_ID))) throw new HttpError(403, 'No access to this room');
      const next = body.is_active === undefined ? (r.is_active ? 0 : 1) : (body.is_active ? 1 : 0);
      await run('UPDATE Automation_Rules SET is_active=? WHERE rules_ID=?', next, r.rules_ID);
      return ok(fixRule(await get(RULE_SQL + ' WHERE ru.rules_ID=?', r.rules_ID)));
    }
  },
  'rules.delete': {
    auth: 'admin',
    run: async ({ params }) => {
      must(await get('SELECT 1 AS x FROM Automation_Rules WHERE rules_ID=?', params.id), 'Rule not found');
      await run('DELETE FROM Automation_Rules WHERE rules_ID=?', params.id);
      return ok({ deleted: true });
    }
  },

  // ---------- notifications (Alerts screen) ----------
  'notifications.list': {
    auth: 'user',
    run: async ({ user, query }) => {
      const f = String(query.filter || 'all').toLowerCase();
      const limit = Math.min(Math.max(num(query.limit, 50), 1), 200);
      let sev = '';
      if (f === 'warnings' || f === 'warning') sev = " AND n.severity IN ('warning','danger')";
      else if (f === 'info') sev = " AND n.severity = 'info'";
      const rows = (await filterByRoom(user, await all(
        `SELECT n.*, r.room_name FROM Notifications n LEFT JOIN Room r ON r.room_ID=n.room_ID
          WHERE (n.user_ID IS NULL OR n.user_ID=?)${sev} ORDER BY n.notification_ID DESC LIMIT ?`, user.users_ID, limit)))
        .map((n) => ({ ...n, notification_is_read: !!n.notification_is_read }));
      return ok({ unread_count: rows.filter((n) => !n.notification_is_read).length, notifications: rows });
    }
  },
  'notifications.read': {
    auth: 'user',
    run: async ({ params }) => {
      await run('UPDATE Notifications SET notification_is_read=1 WHERE notification_ID=?', params.id);
      return ok({ read: true });
    }
  },
  'notifications.readAll': {
    auth: 'user',
    run: async ({ user }) => {
      await run('UPDATE Notifications SET notification_is_read=1 WHERE user_ID IS NULL OR user_ID=?', user.users_ID);
      return ok({ read: true });
    }
  },

  // ---------- users (admin) ----------
  'users.list': {
    auth: 'admin',
    run: async () => {
      const users = await all('SELECT users_ID, users_name, users_email, role, created_at FROM Users ORDER BY users_ID');
      return ok(await Promise.all(users.map(async (u) => ({
        ...u,
        rooms: (await all('SELECT room_ID FROM User_Room_Access WHERE users_ID=?', u.users_ID)).map((r) => r.room_ID)
      }))));
    }
  },
  'users.update': {
    auth: 'admin',
    run: async ({ params, body }) => {
      const u = must(await get('SELECT * FROM Users WHERE users_ID=?', params.id), 'User not found');
      const role = body.role === undefined ? u.role : String(body.role).toLowerCase();
      if (!['admin', 'user'].includes(role)) throw bad("role must be 'admin' or 'user'");
      await run('UPDATE Users SET role=? WHERE users_ID=?', role, u.users_ID);
      cachedUser = null;
      return ok(publicUser(await get('SELECT * FROM Users WHERE users_ID=?', u.users_ID)));
    }
  },
  'users.delete': {
    auth: 'admin',
    run: async ({ user, params }) => {
      if (Number(params.id) === user.users_ID) throw bad('You cannot delete the default admin account');
      must(await get('SELECT 1 AS x FROM Users WHERE users_ID=?', params.id), 'User not found');
      await run('DELETE FROM Users WHERE users_ID=?', params.id);
      return ok({ deleted: true });
    }
  },
  'users.access.add': {
    auth: 'admin',
    run: async ({ params, body }) => {
      must(await get('SELECT 1 AS x FROM Users WHERE users_ID=?', params.id), 'User not found');
      must(await get('SELECT 1 AS x FROM Room WHERE room_ID=?', body.room_ID), 'Room not found');
      await run('INSERT INTO User_Room_Access(users_ID, room_ID) VALUES (?,?) ON CONFLICT DO NOTHING', params.id, body.room_ID);
      return ok({ granted: true }, 201);
    }
  },
  'users.access.remove': {
    auth: 'admin',
    run: async ({ params }) => {
      await run('DELETE FROM User_Room_Access WHERE users_ID=? AND room_ID=?', params.id, params.roomId);
      return ok({ removed: true });
    }
  },

  // ---------- device (ESP32) endpoints: send header  x-device-key ----------
  'device.heartbeat': {
    auth: 'device',
    run: async ({ body }) => {
      const c = body.controllers_ID
        ? await get('SELECT * FROM Controllers WHERE controllers_ID=?', body.controllers_ID)
        : await get('SELECT * FROM Controllers WHERE mac_address=?', str(body.mac_address));
      must(c, 'Controller not registered (send controllers_ID or a known mac_address)');
      await run(`UPDATE Controllers SET last_seen=${NOW}, status='online', ip_address=COALESCE(?,ip_address), wifi=COALESCE(?,wifi) WHERE controllers_ID=?`,
        str(body.ip_address) || null, num(body.wifi), c.controllers_ID);
      return ok({ controllers_ID: c.controllers_ID, room_ID: c.room_ID, server_time: new Date().toISOString() });
    }
  },
  'device.readings': {
    auth: 'device',
    run: async ({ body, rawBody }) => {
      const list = Array.isArray(rawBody) ? rawBody : Array.isArray(body.readings) ? body.readings : [body];
      const ids = [];
      for (const d of list) {
        if (!d.sensor_ID) throw bad('sensor_ID is required');
        ids.push(await ingestReading(Number(d.sensor_ID), d));
      }
      return ok({ saved: ids.length, readings_IDs: ids }, 201);
    }
  },
  'device.commands': {
    auth: 'device',
    run: async ({ query }) => {
      let cid = query.controller_id;
      if (!cid) {
        const row = await get('SELECT controllers_ID FROM Controllers WHERE mac_address=?', str(query.mac));
        cid = row && row.controllers_ID;
      }
      if (!cid) throw bad('Send controller_id or mac');
      const cmds = await all(
        `SELECT cm.command_ID, cm.appliances_ID, cm.action, a.appliances_type, a.gpio_pin
           FROM Commands cm JOIN Appliances a ON a.appliances_ID=cm.appliances_ID
          WHERE a.controllers_ID=? AND cm.status IN ('pending','sent') ORDER BY cm.command_ID`, cid);
      for (const c of cmds) {
        c.ir = (await get('SELECT protocol, raw_code FROM IR_Command_Codes WHERE appliances_ID=? AND action=?', c.appliances_ID, c.action)) || null;
        await run(`UPDATE Commands SET status='sent', sent_at=${NOW} WHERE command_ID=? AND status='pending'`, c.command_ID);
      }
      return ok(cmds);
    }
  },
  'device.confirm': {
    auth: 'device',
    run: async ({ params, body }) => {
      await confirmCommand(Number(params.id), body.success !== false);
      return ok({ confirmed: true });
    }
  },
  'device.simulate': {
    auth: 'device',
    run: async () => ok({ sensors_updated: await simulate() })
  }
};

// ============================================================
//  Entry point used by every Node-RED function node (returns a Promise)
// ============================================================
function errorResponse(name, e) {
  if (e instanceof HttpError) return raw(e.status, { success: false, error: e.message });
  if (e && e.code === '23505') return raw(409, { success: false, error: 'Already exists (duplicate value)' });
  if (e && e.code === '23503') return raw(400, { success: false, error: 'Invalid reference (id does not exist, or still in use)' });
  if (e && e.code === '23502') return raw(400, { success: false, error: 'A required field is missing' });
  console.error('[EcoBuild]', name, e);
  return raw(500, { success: false, error: 'Server error: ' + String((e && e.message) || e) });
}

async function handle(name, msg) {
  let out;
  try {
    const route = routes[name];
    if (!route) throw new HttpError(404, 'Unknown handler: ' + name);
    await ensureReady();

    const req = msg.req || {};
    const headers = req.headers || {};
    const method = String(req.method || 'GET').toUpperCase();
    const hasBody = method === 'POST' || method === 'PUT' || method === 'PATCH';
    const ctx = {
      body: hasBody && msg.payload && typeof msg.payload === 'object' && !Array.isArray(msg.payload) ? msg.payload : {},
      rawBody: hasBody ? msg.payload : undefined,
      query: req.query || {},
      params: req.params || {},
      ip: req.ip || (req.socket && req.socket.remoteAddress) || '',
      user: null
    };

    if (route.auth === 'device') {
      if (headers['x-device-key'] !== cfg.DEVICE_KEY) throw new HttpError(401, 'Bad or missing x-device-key');
    } else if (route.auth !== 'none') {
      ctx.user = await defaultUser(); // no login: everybody is the default admin
    }

    out = await route.run(ctx);
  } catch (e) {
    out = errorResponse(name, e);
  }
  msg.statusCode = out.status;
  msg.payload = JSON.parse(JSON.stringify(out.body)); // plain objects for Node-RED
  return msg;
}

module.exports = { handle, routes, simulate };