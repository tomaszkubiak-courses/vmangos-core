#!/bin/sh
# Build the comparison corpus: one throwaway MySQL instance holding every source
# database side by side. Re-runnable; each schema is dropped and rebuilt.
set -eu

HERE=$(dirname "$0")
. "$HERE/config.env"

MYSQL="$MYSQL_BIN_DIR/mysql"
MYSQLD="$MYSQL_BIN_DIR/mysqld"
MYSQLDUMP="$MYSQL_BIN_DIR/mysqldump"
LOGS="$HERE/logs"
mkdir -p "$LOGS"

corpus() { "$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot "$@"; }

# --- start the instance, initialising the datadir on first run ------------
if [ ! -d "$CORPUS_DATADIR/mysql" ]; then
    echo "initialising corpus datadir"
    "$MYSQLD" --no-defaults --initialize-insecure --datadir="$CORPUS_DATADIR"
fi

if ! corpus --execute="SELECT 1" >/dev/null 2>&1; then
    echo "starting corpus instance on port $CORPUS_PORT"
    "$MYSQLD" --no-defaults \
        --datadir="$CORPUS_DATADIR" \
        --port="$CORPUS_PORT" \
        --socket="$CORPUS_DATADIR/corpus.sock" \
        --secure-file-priv="" \
        --sql-mode="NO_ENGINE_SUBSTITUTION" \
        --log-bin=OFF \
        > "$LOGS/mysqld.log" 2>&1 &
    # Wait for it to accept connections rather than guessing at a delay.
    i=0
    while ! corpus --execute="SELECT 1" >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -gt 60 ] && { echo "corpus instance did not start; see $LOGS/mysqld.log"; exit 1; }
        sleep 1
    done
fi

fresh() { corpus --execute="DROP DATABASE IF EXISTS \`$1\`; CREATE DATABASE \`$1\` DEFAULT CHARACTER SET utf8mb4;"; }

# --- v: snapshot of the live databases ------------------------------------
# --single-transaction takes no locks. Every table in the live world DB is
# InnoDB, so the running server is unaffected.
snapshot() {
    src_db=$1
    dst_db=$2
    echo "snapshotting $dst_db"
    fresh "$dst_db"
    # --set-gtid-purged=OFF skips mysqldump's internal "FLUSH TABLES" step for
    # the GTID position, which otherwise requires the RELOAD privilege the
    # live user does not have and aborts the dump before any table is read.
    "$MYSQLDUMP" --host="$LIVE_HOST" --port="$LIVE_PORT" \
        -u"$LIVE_USER" -p"$LIVE_PASS" \
        --single-transaction --skip-lock-tables --routines \
        --set-gtid-purged=OFF \
        "$src_db" | corpus "$dst_db"
}

snapshot "$LIVE_WORLD_DB"      v
snapshot "$LIVE_CHARACTERS_DB" characters
snapshot "$LIVE_REALMD_DB"     realmd
snapshot "$LIVE_LOGS_DB"       logs
# dbc: DBC reference tables (area_table etc.). Later tasks join these for
# zone names, so this snapshot is required, not optional.
snapshot "$LIVE_DBC_DB"        dbc

# --- mz: schema, then data, then release updates --------------------------
echo "importing mz"
fresh mz
corpus mz < "$SRC_MZ/World/Setup/mangosdLoadDB.sql"
for f in "$SRC_MZ/World/Setup/FullDB"/*.sql; do
    corpus mz < "$f"
done
for d in "$SRC_MZ/World/Updates"/*/; do
    for f in "$d"*.sql; do
        [ -e "$f" ] || continue
        corpus --force mz < "$f" 2>> "$LOGS/mz_updates.err"
    done
done

# --- tw: each base file carries its own CREATE TABLE ----------------------
echo "importing tw"
fresh tw
for f in "$SRC_TW/sql/base"/tw_world_*.sql; do
    corpus tw < "$f"
done
for f in "$SRC_TW/sql/database_updates/world"/*.sql; do
    [ -e "$f" ] || continue
    corpus --force tw < "$f" 2>> "$LOGS/tw_updates.err"
done

# --- ac: squashed base, then updates in filename order --------------------
# --force is required: some updates reference schemas outside db_world. The
# error log is an output of this build, not noise - read it before trusting
# a diff, because a half-applied schema looks exactly like missing content.
echo "importing ac"
fresh ac
for f in "$SRC_AC/data/sql/base/db_world"/*.sql; do
    corpus ac < "$f"
done
: > "$LOGS/ac_updates.err"
for f in $(ls "$SRC_AC/data/sql/updates/db_world"/*.sql | sort); do
    corpus --force ac < "$f" 2>> "$LOGS/ac_updates.err"
done

echo
echo "import failure logs:"
wc -l "$LOGS"/*.err 2>/dev/null || true
echo "review these before trusting any diff."
