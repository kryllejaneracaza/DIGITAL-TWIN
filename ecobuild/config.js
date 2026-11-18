// ============================================================
//  EcoBuild backend settings  -  edit the values you need
// ============================================================
const path = require('path');

module.exports = {
  // Where the SQLite database file is stored (created automatically)
  DB_FILE: process.env.ECOBUILD_DB || path.join(__dirname, 'data', 'ecobuild.sqlite'),

  // !!! CHANGE THIS to your own long random text (32+ characters) !!!
  JWT_SECRET: process.env.ECOBUILD_JWT_SECRET || '123456',
  JWT_EXPIRES: '7d',

  // Password that the ESP32 controllers send in the "x-device-key" header
  DEVICE_KEY: process.env.ECOBUILD_DEVICE_KEY || '123456',

  // Send a "High Temperature" alert above this temperature (Celsius)
  ALERT_TEMP: 30,

  // A controller counts as offline if it has not reported for this many seconds
  OFFLINE_AFTER_SECONDS: 120,

  // true  = every logged-in user can see/control every room
  // false = normal users only see rooms the admin granted (User_Room_Access)
  // (admins always see everything)
  OPEN_ROOM_ACCESS: true,

  // true  = app commands are marked "confirmed" immediately (good for demos without hardware)
  // false = commands wait until the ESP32 confirms them (use this with real hardware)
  AUTO_CONFIRM_COMMANDS: true,

  // true = on first start, fill the database with sample buildings, rooms, sensors, appliances
  SEED_DEMO_DATA: true
};
