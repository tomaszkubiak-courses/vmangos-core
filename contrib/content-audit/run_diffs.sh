#!/bin/sh
# Rebuild cmp.findings from every diff query, in order.
set -eu

HERE=$(dirname "$0")
. "$HERE/config.env"

MYSQL="$MYSQL_BIN_DIR/mysql"

for f in "$HERE/diffs"/*.sql; do
    echo "diff: $(basename "$f")"
    # STRICT_ALL_TABLES turns a NULL into a NOT NULL column, or an
    # over-length value, into an error instead of a silent coercion - each
    # .sql file runs on its own connection, so this has to be set here, not
    # inside the files. --show-warnings surfaces anything strict mode does
    # not itself turn into an error. --default-character-set=utf8mb4 avoids
    # creating routines and rows under the Windows console's cp852 codepage,
    # which is harmless only while every literal stays ASCII.
    "$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot \
        --init-command='SET SESSION sql_mode="STRICT_ALL_TABLES,NO_ENGINE_SUBSTITUTION"' \
        --show-warnings --default-character-set=utf8mb4 < "$f"
done

"$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot -e "
SELECT topic, strength, COUNT(*) FROM cmp.findings
GROUP BY topic, strength ORDER BY topic, strength;"
