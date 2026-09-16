#!/bin/sh
# Rebuild cmp.findings from every diff query, in order.
set -eu

HERE=$(dirname "$0")
. "$HERE/config.env"

MYSQL="$MYSQL_BIN_DIR/mysql"

for f in "$HERE/diffs"/*.sql; do
    echo "diff: $(basename "$f")"
    "$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot < "$f"
done

"$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot -e "
SELECT topic, strength, COUNT(*) FROM cmp.findings
GROUP BY topic, strength ORDER BY topic, strength;"
