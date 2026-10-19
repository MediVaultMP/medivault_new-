import "dotenv/config";
import pg from "pg";

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL
});

try {
  const result = await pool.query(
    "SELECT id, name, email, role, status FROM users WHERE role = $1",
    ["patient"]
  );
  console.table(result.rows);
} catch (error) {
  console.error("Database query failed:", error.message);
} finally {
  await pool.end();
}
