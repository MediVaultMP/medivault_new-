
import 'dotenv/config';
import pg from 'pg';

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true'
    ? { rejectUnauthorized: false }
    : undefined,
});

try {
  const result = await pool.query(`
    SELECT id, name, email
    FROM users
    WHERE role = 'patient'
    ORDER BY created_at DESC
  `);

  console.table(result.rows);
} catch (error) {
  console.error('Patient lookup failed:', error.message);
} finally {
  await pool.end();
}
