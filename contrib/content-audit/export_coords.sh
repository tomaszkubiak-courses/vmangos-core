#!/bin/sh
# Export the union of all four sources' spawn coordinates for area resolution.
#
# Spawn GUIDs are not comparable across sources, so the id column carries the
# spawn's own key only to join the resolved area back on. Comparison happens on
# creature and gameobject entries, never on GUIDs.
set -eu

HERE=$(dirname "$0")
. "$HERE/config.env"

MYSQL="$MYSQL_BIN_DIR/mysql"
OUT="$HERE/logs/spawn_coords.csv"
mkdir -p "$HERE/logs"

corpus() { "$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot --batch --skip-column-names "$@"; }

{
    corpus -e "SELECT CONCAT_WS(',','v','creature',guid,map,position_x,position_y,position_z) FROM v.creature"
    corpus -e "SELECT CONCAT_WS(',','v','gobject',guid,map,position_x,position_y,position_z) FROM v.gameobject"
    corpus -e "SELECT CONCAT_WS(',','tw','creature',guid,map,position_x,position_y,position_z) FROM tw.creature"
    corpus -e "SELECT CONCAT_WS(',','tw','gobject',guid,map,position_x,position_y,position_z) FROM tw.gameobject"
    corpus -e "SELECT CONCAT_WS(',','mz','creature',guid,map,position_x,position_y,position_z) FROM mz.creature"
    corpus -e "SELECT CONCAT_WS(',','mz','gobject',guid,map,position_x,position_y,position_z) FROM mz.gameobject"
    corpus -e "SELECT CONCAT_WS(',','ac','creature',guid,map,position_x,position_y,position_z) FROM ac.creature"
    corpus -e "SELECT CONCAT_WS(',','ac','gobject',guid,map,position_x,position_y,position_z) FROM ac.gameobject"
} > "$OUT"

echo "exported $(wc -l < "$OUT") spawn coordinates to $OUT"
