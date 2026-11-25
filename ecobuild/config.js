// ============================================================
//  EcoBuild backend settings  (Neon Postgres, no login)
// ============================================================
const fs = require('fs');
const path = require('path');

// Tiny .env loader: reads  ecobuild/.env  (one KEY=VALUE per line) so the
// database password never has to be written in this file or committed to git.
try {
  const file = path.join(__dirname, '.env');
  if (fs.existsSync(file)) {
    const text = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
    for (const line of text.split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
      if (m && process.env[m[1]] === undefined) {
        process.env[m[1]] = m[2].replace(/^(['"])(.*)\1$/, '$2');
      }
    }
  }
} catch (e) {
  console.warn('[EcoBuild] could not read .env:', e.message);
}

module.exports = {
  // Neon connection string (Node.js format). Put it in ecobuild/.env as:
  //   DATABASE_URL=postgresql://USER:PASSWORD@HOST/neondb?sslmode=require
  DATABASE_URL: process.env.DATABASE_URL || '',

  // Password that the ESP32 controllers send in the "x-device-key" header
  DEVICE_KEY: process.env.ECOBUILD_DEVICE_KEY || '123456',

  // Send a "High Temperature" alert above this temperature (Celsius)
  ALERT_TEMP: 30,

  // A controller counts as offline if it has not reported for this many seconds
  OFFLINE_AFTER_SECONDS: 120,

  // true = every visitor can see/control every room (always true without login)
  OPEN_ROOM_ACCESS: true,

  // true  = app commands are marked "confirmed" immediately (good for demos without hardware)
  // false = commands wait until the ESP32 confirms them (use this with real hardware)
  AUTO_CONFIRM_COMMANDS: true,

  // true = if the database is EMPTY on start, fill it with sample buildings, rooms, sensors...
  // Keep false if you will copy your old SQLite data with migrate-sqlite-to-neon.js
  SEED_DEMO_DATA: false
};