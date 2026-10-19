
import 'dotenv/config';
import pg from 'pg';

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_SSL === 'true'
    ? { rejectUnauthorized: false }
    : undefined,
});

try {
  const info = await pool.query(`
    SELECT current_database() AS database,
           current_schema() AS schema,
           current_user AS db_user
  `);
  console.table(info.rows);

  const tables = await pool.query(`
    SELECT table_schema, table_name
    FROM information_schema.tables
    WHERE table_name = 'users'
    ORDER BY table_schema
  `);
  console.table(tables.rows);

  const users = await pool.query(`
    SELECT COUNT(*)::int AS user_count FROM users
  `);
  console.table(users.rows);
} catch (error) {
  console.error('Database inspection failed:', error.message);
} finally {
  await pool.end();
}
