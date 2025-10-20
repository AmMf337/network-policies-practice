const express = require('express');
const { Pool } = require('pg');
const app = express();

const pool = new Pool({
  host: 'database-service.database-ns.svc.cluster.local',
  user: 'postgres',
  password: 'example',
  database: 'postgres',
  port: 5432
});

app.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()');
    res.send(`Hello from Backend! 🟣 DB Time: ${result.rows[0].now}`);
  } catch (err) {
    console.error('Database error:', err);
    res.status(500).send('Database not reachable: ' + err.message);
  }
});

app.listen(3000, () => {
  console.log('Backend running on port 3000');
});
