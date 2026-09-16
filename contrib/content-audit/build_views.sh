#!/bin/sh
# (Re)create the normalising views in every source schema. Idempotent.
set -eu

HERE=$(dirname "$0")
. "$HERE/config.env"

MYSQL="$MYSQL_BIN_DIR/mysql"

for src in v mz tw ac; do
    echo "views: $src"
    "$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot "$src" \
        < "$HERE/views/$src.sql"
done

echo "views: derived"
"$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot \
    < "$HERE/views/derived.sql"
