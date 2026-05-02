#!/bin/bash
set -e

ENV_FILE="$(cd "$(dirname "$0")" && pwd)/.env"
source "$ENV_FILE"

CLICKHOUSE_USER="${CLICKHOUSE_USER:-ch_admin}"
CLICKHOUSE_DB="${CLICKHOUSE_DB:-clickhouse_warehouse}"

BASE_URL="http://localhost:8123"

# Query function: $1 = sql, $2 = database (optional)
query() {
  local sql="$1"
  local db=""
  if [ -n "$2" ]; then
    db="&database=$2"
  fi
  curl -s "${BASE_URL}?user=${CLICKHOUSE_USER}&password=${CLICKHOUSE_PASSWORD}${db}" -d "$sql"
}

echo "=== ClickHouse CRUD Tests ==="
echo "DB: ${CLICKHOUSE_DB} | User: ${CLICKHOUSE_USER}"
echo ""

# 0. Create database
echo ">>> CREATE DATABASE"
result=$(query "CREATE DATABASE IF NOT EXISTS ${CLICKHOUSE_DB}" "")
if echo "$result" | grep -q "Code:"; then
  echo "FAIL: $result"
  exit 1
fi
echo "OK"
echo ""

# Helper for queries within the database
q() {
  query "$1" "${CLICKHOUSE_DB}"
}

# 1. Create schema
echo ">>> CREATE TABLE"
q "DROP TABLE IF EXISTS test_crud"
q "CREATE TABLE test_crud (id UInt32, name String, value UInt32, created_at DateTime) ENGINE = MergeTree() ORDER BY id"
echo "OK"
echo ""

# 2. Insert
echo ">>> INSERT"
q "INSERT INTO test_crud VALUES (1, 'alpha', 100, now()), (2, 'beta', 200, now()), (3, 'gamma', 300, now())"
echo "OK"
echo ""

# 3. Select all
echo ">>> SELECT ALL"
q "SELECT * FROM test_crud ORDER BY id FORMAT Pretty"
echo ""

# 4. Update
echo ">>> UPDATE (set value=150 where id=1)"
q "ALTER TABLE test_crud UPDATE value = 150 WHERE id = 1"
echo "OK"
q "SELECT * FROM test_crud WHERE id = 1 FORMAT Pretty"
echo ""

# 5. Delete
echo ">>> DELETE (delete where id=3)"
q "DELETE FROM test_crud WHERE id = 3"
echo "OK"
q "SELECT * FROM test_crud ORDER BY id FORMAT Pretty"
echo ""

# 6. Verify final state
echo ">>> FINAL COUNT"
count=$(q "SELECT count() FROM test_crud FORMAT TSV")
if [ "$count" = "2" ]; then
  echo "OK (count=2)"
else
  echo "FAIL (expected 2, got: $count)"
  exit 1
fi
echo ""

# 7. Cleanup
echo ">>> DROP TABLE (cleanup)"
q "DROP TABLE IF EXISTS test_crud"
echo "OK"

echo ""
echo "=== All tests passed ==="
