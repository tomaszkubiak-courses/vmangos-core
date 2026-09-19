#!/bin/sh
# Resolve spawn coordinates to game areas using the core's own terrain lookup.
#
# Runs a scratch mangosd whose databases point at the corpus instance, so the
# live server and live character data are never involved. The scratch core
# exits on its own once the resolver has written its output.
#
# Usage: run_resolver.sh <input.csv> <output.csv>
#
# NOTE: this needs the ContentAudit.ResolveAreasFile hook, which is removed from
# the core once a corpus has been built - the resolver was temporary tooling, not
# a server feature, and carrying it in the core would mean carrying a config key
# that makes mangosd exit on startup. Re-apply commit 4a1fdd85c ("Add a temporary
# area resolver for the content audit") and rebuild before running this again;
# the areas table it fills only needs rebuilding when a source's spawn data
# changes.
set -eu

HERE=$(dirname "$0")
. "$HERE/config.env"

IN=$1
OUT=$2
CONF="$HERE/logs/resolver_mangosd.conf"
mkdir -p "$HERE/logs"

# Start from the installed config so DataDir and the client build match the
# live server, then override the databases and switch the resolver on.
#
# A real (non-root) user/password is used here rather than root with its
# blank corpus password: SqlConnection::Initialize (src/shared/Database/Database.cpp)
# splits the Info string on ";" and drops empty tokens, so an empty password
# field shifts every field after it instead of parsing as "no password" -
# the database name would silently be read as the password. The mysql CLI
# has no such problem, which is why root with no password still works for
# every other script in this pipeline.
sed -e "s|^ContentAudit.ResolveAreasFile.*|ContentAudit.ResolveAreasFile = \"$IN\"|" \
    -e "s|^ContentAudit.ResolveAreasOutFile.*|ContentAudit.ResolveAreasOutFile = \"$OUT\"|" \
    -e "s|^WorldDatabase.Info.*|WorldDatabase.Info = \"$CORPUS_HOST;$CORPUS_PORT;$CORPUS_RESOLVER_USER;$CORPUS_RESOLVER_PASS;v\"|" \
    -e "s|^CharacterDatabase.Info.*|CharacterDatabase.Info = \"$CORPUS_HOST;$CORPUS_PORT;$CORPUS_RESOLVER_USER;$CORPUS_RESOLVER_PASS;characters\"|" \
    -e "s|^LoginDatabase.Info.*|LoginDatabase.Info = \"$CORPUS_HOST;$CORPUS_PORT;$CORPUS_RESOLVER_USER;$CORPUS_RESOLVER_PASS;realmd\"|" \
    -e "s|^LogsDatabase.Info.*|LogsDatabase.Info = \"$CORPUS_HOST;$CORPUS_PORT;$CORPUS_RESOLVER_USER;$CORPUS_RESOLVER_PASS;logs\"|" \
    "$SERVER_DIR/mangosd.conf" > "$CONF"

# The installed mangosd.conf predates this feature and has no
# ContentAudit.* lines for the sed patterns above to match, so the resolver
# keys are appended instead. Config::ProcessLine keeps the first occurrence
# of a duplicate key and ignores the rest, so this is safe even once the
# operator's conf is regenerated with the (empty-valued, and therefore
# unparsed - see ProcessLine's value.empty() check) keys already present.
{
    echo "ContentAudit.ResolveAreasFile = \"$IN\""
    echo "ContentAudit.ResolveAreasOutFile = \"$OUT\""
} >> "$CONF"

rm -f "$OUT"
( cd "$SERVER_DIR" && ./mangosd -c "$CONF" ) > "$HERE/logs/resolver.log" 2>&1 || true

if [ ! -s "$OUT" ]; then
    echo "resolver produced no output; see $HERE/logs/resolver.log" >&2
    exit 1
fi

grep "\[ContentAudit\]" "$HERE/logs/resolver.log" || true
