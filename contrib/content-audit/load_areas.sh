#!/bin/sh
# Load resolved spawn areas into the corpus as cmp.areas.
set -eu

HERE=$(dirname "$0")
. "$HERE/config.env"

MYSQL="$MYSQL_BIN_DIR/mysql"
CSV=${1:-"$HERE/logs/spawn_areas.csv"}

corpus() { "$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot --local-infile=1 "$@"; }

# The corpus instance starts with local_infile off (the mysqld default);
# --local-infile=1 above only asks the client to allow it, the server side
# also has to agree or LOAD DATA LOCAL INFILE is rejected outright.
corpus -e "SET GLOBAL local_infile = 1;"

corpus -e "CREATE DATABASE IF NOT EXISTS cmp DEFAULT CHARACTER SET utf8mb4;"
corpus cmp -e "
DROP TABLE IF EXISTS areas;
CREATE TABLE areas (
    src   VARCHAR(4)   NOT NULL,
    kind  VARCHAR(16)  NOT NULL,
    id    INT UNSIGNED NOT NULL,
    map   INT UNSIGNED NOT NULL,
    x     FLOAT        NOT NULL,
    y     FLOAT        NOT NULL,
    z     FLOAT        NOT NULL,
    zone  INT UNSIGNED NOT NULL,
    area  INT UNSIGNED NOT NULL,
    KEY ix_src_kind_id (src, kind, id),
    KEY ix_zone (zone)
) ENGINE=InnoDB;
LOAD DATA LOCAL INFILE '$CSV' INTO TABLE areas
    FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
    (src, kind, id, map, x, y, z, zone, area);
"

corpus cmp -e "SELECT src, kind, COUNT(*) FROM areas GROUP BY src, kind;"
