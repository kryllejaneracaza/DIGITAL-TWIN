// ============================================================
//  One-time copy:  old SQLite file  ->  Neon (PostgreSQL)
//  Run from the ecobuild folder (stop Node-RED first):
//      node migrate-sqlite-to-neon.js            (refuses if Neon already has data)
//      node migrate-sqlite-to-neon.js --force    (wipes Neon tables first, then copies)
//  Needs DATABASE_URL (ecobuild/.env). Reads data/ecobuild.sqlite
//  with Node's built-in "node:sqlite" (or "better-sqlite3" if installed).
// ============================================================
const path = require('path');
const fs = require('fs');
const db = require('./db');

const SQLITE_FILE = process.env.ECOBUILD_DB || path.join(__dirname, 'data', 'ecobuild.sqlite');

// [table, id column]   (parents first so foreign keys are satisfied)
const TABLES = [
  ['Users', 'users_ID'], ['Building', 'building_ID'], ['Room', 'room_ID'],
  ['Controllers', 'controllers_ID'], ['Sensors', 'sensor_ID'], ['Appliances', 'appliances_ID'],
  ['Appliance_States', 'states_ID'], ['Automation_Rules', 'rules_ID'],
  ['Sensor_Readings', 'readings_ID'], ['Commands', 'command_ID'], ['Detection', 'detection_ID'],
  ['Notifications', 'notification_ID'], ['IR_Command_Codes', 'code_ID'], ['User_Room_Access', null]
];

function openSqlite(file) {
  try {
    const { DatabaseSync } = require('node:sqlite');
    return new DatabaseSync(file, { readOnly: true });
  } catch (e1) {
    try {
      const Database = require('better-sqlite3');
      return new Database(file, { readonly: true });
    } catch (e2) {
      throw new Error('Cannot open the SQLite file. node:sqlite said: ' + e1.message + ' | better-sqlite3 said: ' + e2.message);
    }
  }
}

async function copyTable(sqlite, table, idCol) {
  let rows;
  try { rows = sqlite.prepare(`SELECT * FROM ${table}`).all(); }
  catch (e) { console.log(`  ${table}: not in SQLite file (skipped)`); return 0; }
  if (!rows.length) { console.log(`  ${table}: 0 rows`); return 0; }
  const cols = Object.keys(rows[0]);
  const perInsert = Math.max(1, Math.floor(40000 / cols.length)); // stay below the 65535 parameter limit
  for (let i = 0; i < rows.length; i += perInsert) {
    const chunk = rows.slice(i, i + perInsert);
    const marks = chunk.map(() => '(' + cols.map(() => '?').join(',') + ')').join(',');
    const params = [];
    for (const r of chunk) for (const c of cols) params.push(r[c] === undefined ? null : r[c]);
    await db.run(`INSERT INTO ${table} (${cols.join(',')}) ${idCol ? 'OVERRIDING SYSTEM VALUE ' : ''}VALUES ${marks}`, ...params);
  }
  console.log(`  ${table}: ${rows.length} rows copied`);
  return rows.length;
}

async function main() {
  const force = process.argv.includes('--force');
  if (!fs.existsSync(SQLITE_FILE)) throw new Error('SQLite file not found: ' + SQLITE_FILE);

  console.log('Connecting to Neon and creating tables ...');
  await db.init();

  const existing = await db.get('SELECT (SELECT COUNT(*) FROM Building) + (SELECT COUNT(*) FROM Sensor_Readings) + (SELECT COUNT(*) FROM Users) AS n');
  if (existing.n > 0) {
    if (!force) {
      throw new Error('Neon already contains data (' + existing.n + ' rows in Building/Users/Readings). ' +
        'Run again with --force to wipe it and copy from SQLite.');
    }
    console.log('--force: emptying the Neon tables ...');
    const names = TABLES.map(([t]) => t).join(', ');
    await db.run(`TRUNCATE ${names} RESTART IDENTITY CASCADE`);
  }

  console.log('Reading ' + SQLITE_FILE);
  const sqlite = openSqlite(SQLITE_FILE);
  for (const [table, idCol] of TABLES) await copyTable(sqlite, table, idCol);
  if (sqlite.close) sqlite.close();

  console.log('Fixing id counters ...');
  for (const [table, idCol] of TABLES) {
    if (!idCol) continue;
    await db.get(
      `SELECT setval(pg_get_serial_sequence('${table.toLowerCase()}', '${idCol.toLowerCase()}'),
                     COALESCE((SELECT MAX(${idCol}) FROM ${table}), 1),
                     (SELECT MAX(${idCol}) FROM ${table}) IS NOT NULL) AS v`);
  }
  console.log('DONE. You can start Node-RED now.');
}

module.exports = { main };

if (require.main === module) {
  main().then(() => process.exit(0)).catch((e) => { console.error('\nFAILED: ' + e.message); process.exit(1); });
}