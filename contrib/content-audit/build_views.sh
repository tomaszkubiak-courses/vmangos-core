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

echo "views: loot_eff"
"$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot \
    -e "CREATE DATABASE IF NOT EXISTS cmp DEFAULT CHARACTER SET utf8mb4;"
for src in v mz tw ac; do
    {
        echo "CREATE OR REPLACE VIEW cmp.n_loot_eff_$src AS"
        sed "s/__SRC__/$src/g" "$HERE/views/loot_eff_body.sql"
    } | "$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot
done
"$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot -e "
CREATE OR REPLACE VIEW cmp.n_loot_eff AS
SELECT * FROM cmp.n_loot_eff_v
UNION ALL SELECT * FROM cmp.n_loot_eff_mz
UNION ALL SELECT * FROM cmp.n_loot_eff_tw
UNION ALL SELECT * FROM cmp.n_loot_eff_ac;"

echo "views: derived"
"$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot \
    < "$HERE/views/derived.sql"
