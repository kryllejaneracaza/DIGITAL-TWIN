// Password hashing + login tokens
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cfg = require('./config');

module.exports = {
  hash: (plain) => bcrypt.hashSync(plain, 10),
  verify: (plain, hash) => bcrypt.compareSync(plain, hash),
  sign: (u) => jwt.sign({ sub: u.users_ID, role: u.role }, cfg.JWT_SECRET, { expiresIn: cfg.JWT_EXPIRES }),
  verifyToken: (t) => jwt.verify(t, cfg.JWT_SECRET)
};
