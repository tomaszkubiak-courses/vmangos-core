# Content Audit Pipeline (SP1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pipeline that compares this realm's world database against three other server databases and emits one Markdown discrepancy report per game zone, proven end to end on Westfall and The Deadmines.

**Architecture:** A throwaway MySQL instance holds all four databases side by side as separate schemas. A temporary hook in the core resolves every spawn coordinate to a game area using the server's own terrain lookup. Per-source SQL views normalise four dissimilar schemas into ten shared shapes; diff queries read only those views and write rows into one findings table; a standard-library Python script turns the findings into Markdown.

**Tech Stack:** MySQL 8+ (recursive CTEs required), C++14 (the core), Python 3.14 standard library only, Bash scripts (Git Bash on Windows, POSIX elsewhere).

**Spec:** `docs/superpowers/specs/2026-09-16-content-audit-pipeline-design.md`

## Global Constraints

- **No local machine details in any committed file.** No absolute paths, machine or account names, live credentials, or host/port values that are configuration. Every such value is read from a gitignored `config.env`. This is a standing rule in both `CLAUDE.md` files and applies to source, comments, scripts, SQL, docs and commit messages.
- **No Claude session links, ids, or transcript identifiers** in commits, branches, code or docs. `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` is the only permitted Claude trailer.
- **Branch workflow:** cut a branch from `development`, merge it into local `development` when done, push `development`. Do not open a pull request against the fork.
- **The live world database is read-only to this pipeline.** Every write goes to the corpus instance. The live server keeps running throughout; dumps use `--single-transaction`.
- **Adding a `.cpp` to `src/game` requires adding it to `src/game/CMakeLists.txt`** — there is no globbing, and a missing entry fails silently by simply not compiling the file.
- **Formatting** follows `.clang-format`: Allman braces, 4-space indent, no tabs, left-aligned pointers. Do not reformat unrelated lines.
- **Reports are generated artifacts** and belong in `doc/local/content-audit/`, which `.gitignore` already excludes at line 124.
- **Tolerances** (from the spec, used verbatim in Task 9 and Task 10): effective drop chance 2x ratio or 5 absolute points; respawn time 2x ratio; spawn count 50% or 5 spawns; effective health 20%; quest experience any difference.
- **Strength rule** (from the spec): *strong* when `v` differs from both `mz` and `ac` and those two agree; *weak* when `v` differs from exactly one of them or they disagree; `tw` votes only when it disagrees with `v`.

---

## File Structure

| Path | Responsibility |
|---|---|
| `contrib/content-audit/README.md` | How to run the pipeline; the only doc a newcomer needs |
| `contrib/content-audit/config.env.example` | Key names with generic placeholder values; copied to `config.env` (gitignored) |
| `contrib/content-audit/build_corpus.sh` | Start the corpus instance and import all seven schemas |
| `contrib/content-audit/export_coords.sh` | Dump the union of all four sources' spawn coordinates to CSV |
| `contrib/content-audit/run_resolver.sh` | Run the scratch core over the coordinate CSV |
| `contrib/content-audit/load_areas.sh` | Load the resolved CSV into `cmp.areas` |
| `contrib/content-audit/views/v.sql` | Normalising views for the live database |
| `contrib/content-audit/views/mz.sql` | Normalising views for mangoszero |
| `contrib/content-audit/views/tw.sql` | Normalising views for tortoise-wow |
| `contrib/content-audit/views/ac.sql` | Normalising views for azerothcore |
| `contrib/content-audit/views/derived.sql` | The three computed shapes, written once against `n_*` |
| `contrib/content-audit/diffs/*.sql` | One file per topic, each appending to `cmp.findings` |
| `contrib/content-audit/report.py` | Findings to Markdown |
| `contrib/content-audit/test_pipeline.py` | The five assertions; stdlib only |
| `src/game/Maps/AreaResolverDump.h/.cpp` | Temporary: resolve a coordinate CSV through `TerrainManager` |
| `src/game/World.cpp` | Temporary: one call, guarded by a config key that defaults off |

Everything under `contrib/content-audit/` is permanent tooling. The two `src/game` changes are temporary and Task 12 deletes them.

---

### Task 1: Corpus instance and source import

**Files:**
- Create: `contrib/content-audit/config.env.example`
- Create: `contrib/content-audit/build_corpus.sh`
- Create: `contrib/content-audit/README.md`
- Modify: `.gitignore`
- Test: `contrib/content-audit/test_pipeline.py`

**Interfaces:**
- Consumes: nothing.
- Produces: a corpus MySQL instance reachable as `"$CORPUS_MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -u root`, holding schemas `v`, `mz`, `tw`, `ac`, `characters`, `realmd`, `logs`. Every later task connects this way and never touches the live instance.

- [ ] **Step 1: Write the config template**

Create `contrib/content-audit/config.env.example`. Values here are illustrative placeholders, never this machine's real ones.

```sh
# Copy to config.env and fill in for your machine. config.env is gitignored.

# MySQL client and server binaries from your portable MySQL install.
MYSQL_BIN_DIR=/path/to/mysql/bin

# The live realm databases, read-only to this pipeline.
LIVE_HOST=127.0.0.1
LIVE_PORT=3306
LIVE_USER=youruser
LIVE_PASS=yourpass
LIVE_WORLD_DB=yourworlddb
LIVE_CHARACTERS_DB=yourcharactersdb
LIVE_REALMD_DB=yourrealmddb
LIVE_LOGS_DB=yourlogsdb

# The throwaway corpus instance. Its datadir must be outside every repository.
CORPUS_HOST=127.0.0.1
CORPUS_PORT=3307
CORPUS_DATADIR=/path/to/a/scratch/datadir

# Checkouts of the comparison sources.
SRC_MZ=/path/to/mangoszero-database
SRC_TW=/path/to/tortoise-wow
SRC_AC=/path/to/azerothcore-wotlk

# Where reports are written. Keep this inside doc/local/ so it stays gitignored.
REPORT_DIR=doc/local/content-audit
```

- [ ] **Step 2: Ignore the real config and the corpus logs**

Append to `.gitignore`:

```
/contrib/content-audit/config.env
/contrib/content-audit/logs/
```

- [ ] **Step 3: Write the failing test**

Create `contrib/content-audit/test_pipeline.py`:

```python
#!/usr/bin/env python3
"""Checks for the content audit pipeline. Standard library only.

Run:  python contrib/content-audit/test_pipeline.py
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def load_config():
    path = os.path.join(HERE, "config.env")
    if not os.path.exists(path):
        sys.exit("config.env not found. Copy config.env.example and fill it in.")
    cfg = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            cfg[key.strip()] = value.strip()
    return cfg


CFG = load_config()


def corpus_sql(statement, schema=""):
    """Run one statement on the corpus instance, return rows as lists of strings."""
    cmd = [
        os.path.join(CFG["MYSQL_BIN_DIR"], "mysql"),
        "--host=" + CFG["CORPUS_HOST"],
        "--port=" + CFG["CORPUS_PORT"],
        "-uroot",
        "--batch",
        "--skip-column-names",
        "--execute=" + statement,
    ]
    if schema:
        cmd.append(schema)
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    return [line.split("\t") for line in out.splitlines()]


def test_corpus_schemas_present():
    """Every source schema exists and its creature_template is populated."""
    expected = {"v": 10000, "mz": 10000, "tw": 10000, "ac": 20000}
    for schema, floor in expected.items():
        rows = corpus_sql(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema='%s'" % schema
        )
        assert int(rows[0][0]) > 50, "%s has only %s tables" % (schema, rows[0][0])
        rows = corpus_sql("SELECT COUNT(*) FROM %s.creature_template" % schema)
        count = int(rows[0][0])
        assert count > floor, "%s.creature_template has %d rows, expected > %d" % (
            schema,
            count,
            floor,
        )
    print("PASS test_corpus_schemas_present")


TESTS = [test_corpus_schemas_present]

if __name__ == "__main__":
    failures = 0
    for test in TESTS:
        try:
            test()
        except Exception as exc:  # noqa: BLE001 - a check runner wants every failure
            failures += 1
            print("FAIL %s: %s" % (test.__name__, exc))
    sys.exit(1 if failures else 0)
```

- [ ] **Step 4: Run it to make sure it fails**

```sh
cp contrib/content-audit/config.env.example contrib/content-audit/config.env
# fill in config.env for this machine
python contrib/content-audit/test_pipeline.py
```

Expected: FAIL — the corpus instance is not running, so `mysql` exits non-zero and `subprocess.run(check=True)` raises.

- [ ] **Step 5: Write the corpus build script**

Create `contrib/content-audit/build_corpus.sh`:

```sh
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
    "$MYSQLDUMP" --host="$LIVE_HOST" --port="$LIVE_PORT" \
        -u"$LIVE_USER" -p"$LIVE_PASS" \
        --single-transaction --skip-lock-tables --routines \
        "$src_db" | corpus "$dst_db"
}

snapshot "$LIVE_WORLD_DB"      v
snapshot "$LIVE_CHARACTERS_DB" characters
snapshot "$LIVE_REALMD_DB"     realmd
snapshot "$LIVE_LOGS_DB"       logs

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
for f in "$SRC_TW/sql/database_updates"/*.sql; do
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
```

- [ ] **Step 6: Run the build**

```sh
chmod +x contrib/content-audit/build_corpus.sh
sh contrib/content-audit/build_corpus.sh
```

Expected: runs 30-60 minutes, dominated by the AzerothCore import, then prints the failure-log line counts.

- [ ] **Step 7: Read the failure logs**

```sh
sort contrib/content-audit/logs/ac_updates.err | uniq -c | sort -rn | head -30
```

Expected: errors naming schemas other than `db_world` (`acore_auth`, `acore_characters`) are fine. An error mentioning a table this pipeline reads — `creature_template`, `quest_template`, `creature_loot_template`, `creature`, `gameobject`, `npc_vendor`, `npc_trainer`, `creature_questrelation`, `creature_involvedrelation`, `reference_loot_template`, `creature_classlevelstats` — is not fine. Fix the import before continuing; a half-applied schema is indistinguishable from missing content in every report this pipeline produces.

- [ ] **Step 8: Run the test to verify it passes**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: `PASS test_corpus_schemas_present`, exit 0.

- [ ] **Step 9: Write the README**

Create `contrib/content-audit/README.md`:

```markdown
# Content audit pipeline

Compares this realm's world database against three other server databases and
writes one Markdown discrepancy report per game zone.

Design: `docs/superpowers/specs/2026-09-16-content-audit-pipeline-design.md`

## Setup

    cp config.env.example config.env    # then fill it in; config.env is gitignored
    sh build_corpus.sh                  # 30-60 minutes, ~3 GB

`build_corpus.sh` starts a throwaway MySQL instance and imports seven schemas
into it: `v` (a snapshot of the live world database), `mz`, `tw`, `ac`, and the
three live realm databases so a scratch core can boot against the corpus rather
than against the live server.

The live databases are only ever read, and only with `--single-transaction`, so
the running server is unaffected.

## Reading the import logs

`logs/*.err` hold the failures from the `--force` update passes. Errors naming a
schema other than the one being built are expected. An error naming a table the
pipeline reads is not - a half-applied schema is indistinguishable from missing
content in the reports.

## Running

    sh export_coords.sh      # spawn coordinates out of the corpus
    sh run_resolver.sh       # resolve them to game areas through the core
    sh load_areas.sh         # resolved areas back into the corpus
    sh build_views.sh        # normalising views for all four sources
    sh run_diffs.sh          # populate cmp.findings
    python report.py 40 1581 # one report per zone id

## Checks

    python test_pipeline.py
```

- [ ] **Step 10: Commit**

```sh
git checkout -b feature/content-audit-pipeline
git add .gitignore contrib/content-audit/
git commit -m "Add the comparison corpus build for the content audit

The audit compares four world databases, which have to be queryable side
by side before anything can be diffed. Importing them into the live
instance would put three hundred megabytes of foreign content into the
database a running server depends on, so the corpus gets a throwaway
mysqld of its own on a separate port and datadir.

The live databases are read with --single-transaction and never written.

The AzerothCore update pass needs --force because some of its updates
reference schemas outside db_world. That makes the failure log part of
the build output rather than noise: a half-applied schema produces
reports indistinguishable from genuinely missing content.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Area resolver in the core

**Files:**
- Create: `src/game/Maps/AreaResolverDump.h`
- Create: `src/game/Maps/AreaResolverDump.cpp`
- Modify: `src/game/CMakeLists.txt`
- Modify: `src/game/World.cpp` (immediately after `LoadDBCStores(dbcPath);`, around line 1405)
- Modify: `src/mangosd/mangosd.conf.dist.in`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `void ResolveAreasFromFile(std::string const& inPath, std::string const& outPath);` declared in `AreaResolverDump.h`. Reads a headerless CSV of `src,kind,id,map,x,y,z` and writes `src,kind,id,map,x,y,z,zone,area`. Rows whose map has no terrain data are skipped and counted.

Why a config key rather than a console command: `CliRunnable` queues console input onto the world thread and calls `World::StopNow` the moment stdin reaches EOF, so a piped command races its own shutdown. A config key checked at a known point in startup has no such race. Hooking straight after `LoadDBCStores` also means the world database never loads, so the resolver runs in seconds instead of minutes.

- [ ] **Step 1: Write the failing test**

Add to `contrib/content-audit/test_pipeline.py`, above the `TESTS` list:

```python
# Known-good fixtures: (map, x, y, z, expected_zone_id, label)
RESOLVER_FIXTURES = [
    (0, -10496.0, 1036.0, 32.0, 12, "Hogger spawn, Elwynn Forest"),
    (36, -15.4, -383.0, 61.0, 1581, "Edwin VanCleef, The Deadmines"),
    (0, -10643.0, 1035.0, 33.0, 40, "Sentinel Hill area, Westfall"),
]


def test_resolver_assigns_known_zones():
    """The core's terrain lookup puts known spawns in known zones."""
    in_path = os.path.join(HERE, "logs", "resolver_fixture_in.csv")
    out_path = os.path.join(HERE, "logs", "resolver_fixture_out.csv")
    os.makedirs(os.path.join(HERE, "logs"), exist_ok=True)
    with open(in_path, "w", encoding="utf-8") as handle:
        for i, (m, x, y, z, _zone, _label) in enumerate(RESOLVER_FIXTURES):
            handle.write("fx,creature,%d,%d,%s,%s,%s\n" % (i, m, x, y, z))

    subprocess.run(
        ["sh", os.path.join(HERE, "run_resolver.sh"), in_path, out_path],
        check=True,
    )

    got = {}
    with open(out_path, encoding="utf-8") as handle:
        for line in handle:
            parts = line.strip().split(",")
            got[int(parts[2])] = int(parts[7])

    for i, (_m, _x, _y, _z, zone, label) in enumerate(RESOLVER_FIXTURES):
        assert got.get(i) == zone, "%s: got zone %s, expected %d" % (
            label,
            got.get(i),
            zone,
        )
    print("PASS test_resolver_assigns_known_zones")
```

Add `test_resolver_assigns_known_zones` to the `TESTS` list.

- [ ] **Step 2: Run it to verify it fails**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: FAIL — `run_resolver.sh` does not exist, so `subprocess.run` raises `FileNotFoundError`.

- [ ] **Step 3: Write the resolver header**

Create `src/game/Maps/AreaResolverDump.h`:

```cpp
/*
 * TEMPORARY - content audit tooling, not a server feature.
 * Remove this file, its CMakeLists entry, its call in World.cpp and the
 * ContentAudit.ResolveAreasFile config key once the audit corpus is built.
 * See docs/superpowers/specs/2026-09-16-content-audit-pipeline-design.md
 */

#ifndef MANGOS_AREA_RESOLVER_DUMP_H
#define MANGOS_AREA_RESOLVER_DUMP_H

#include <string>

// Reads a headerless CSV of "src,kind,id,map,x,y,z" and writes the same rows
// with ",zone,area" appended. Rows on a map with no terrain data are skipped.
void ResolveAreasFromFile(std::string const& inPath, std::string const& outPath);

#endif
```

- [ ] **Step 4: Write the resolver implementation**

Create `src/game/Maps/AreaResolverDump.cpp`:

```cpp
/*
 * TEMPORARY - content audit tooling, not a server feature. See the header.
 */

#include "AreaResolverDump.h"
#include "GridMap.h"
#include "Log.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

void ResolveAreasFromFile(std::string const& inPath, std::string const& outPath)
{
    FILE* in = fopen(inPath.c_str(), "r");
    if (!in)
    {
        sLog.Out(LOG_BASIC, LOG_LVL_ERROR, "[ContentAudit] cannot open input %s", inPath.c_str());
        return;
    }

    FILE* out = fopen(outPath.c_str(), "w");
    if (!out)
    {
        sLog.Out(LOG_BASIC, LOG_LVL_ERROR, "[ContentAudit] cannot open output %s", outPath.c_str());
        fclose(in);
        return;
    }

    char line[512];
    uint32 resolved = 0;
    uint32 skipped = 0;

    while (fgets(line, sizeof(line), in))
    {
        char src[64];
        char kind[32];
        uint32 id;
        uint32 mapId;
        float x, y, z;

        if (sscanf(line, "%63[^,],%31[^,],%u,%u,%f,%f,%f", src, kind, &id, &mapId, &x, &y, &z) != 7)
            continue;

        // A map with no extracted terrain has nothing to say about this
        // coordinate. That is the expected outcome for post-vanilla maps in
        // the AzerothCore data, so it is counted rather than warned about.
        TerrainInfo const* terrain = sTerrainMgr.LoadTerrain(mapId);
        if (!terrain)
        {
            ++skipped;
            continue;
        }

        uint32 zoneId = 0;
        uint32 areaId = 0;
        sTerrainMgr.GetZoneAndAreaId(zoneId, areaId, mapId, x, y, z);

        if (!zoneId && !areaId)
        {
            ++skipped;
            continue;
        }

        fprintf(out, "%s,%s,%u,%u,%.4f,%.4f,%.4f,%u,%u\n", src, kind, id, mapId, x, y, z, zoneId, areaId);
        ++resolved;
    }

    fclose(in);
    fclose(out);

    sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "[ContentAudit] resolved %u rows, skipped %u", resolved, skipped);
}
```

- [ ] **Step 5: Register the source file**

In `src/game/CMakeLists.txt`, find the block listing `Maps/GridMap.cpp` and add alongside it, keeping the list's existing alphabetical order:

```cmake
    Maps/AreaResolverDump.cpp
    Maps/AreaResolverDump.h
```

- [ ] **Step 6: Call it from startup**

In `src/game/World.cpp`, add the include near the other `Maps/` includes:

```cpp
#include "AreaResolverDump.h"
```

Then immediately after `LoadDBCStores(dbcPath);` (around line 1405) insert:

```cpp
    // TEMPORARY - content audit tooling. Everything the resolver needs is ready
    // at this point: DataDir is set and AreaTable.dbc is loaded. Running here
    // rather than after the world loads skips several minutes of database work.
    // Remove with AreaResolverDump.{h,cpp}.
    {
        std::string const resolveIn = sConfig.GetStringDefault("ContentAudit.ResolveAreasFile", "");
        if (!resolveIn.empty())
        {
            std::string const resolveOut = sConfig.GetStringDefault("ContentAudit.ResolveAreasOutFile", "");
            ResolveAreasFromFile(resolveIn, resolveOut);
            sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "[ContentAudit] resolver finished, exiting");
            Log::WaitBeforeContinueIfNeed();
            exit(0);
        }
    }
```

- [ ] **Step 7: Document the config keys**

In `src/mangosd/mangosd.conf.dist.in`, append to the end of the file:

```
#
#    ContentAudit.ResolveAreasFile
#        TEMPORARY - content audit tooling, not a server feature.
#        When set, the server resolves each coordinate in this CSV to a game
#        area immediately after loading the DBC stores, writes the result to
#        ContentAudit.ResolveAreasOutFile, and exits without loading the world.
#        Leave empty for normal operation.
#        Default: "" (disabled)
#
#    ContentAudit.ResolveAreasOutFile
#        Output path for the above.
#        Default: "" 

ContentAudit.ResolveAreasFile = ""
ContentAudit.ResolveAreasOutFile = ""
```

- [ ] **Step 8: Write the resolver runner**

Create `contrib/content-audit/run_resolver.sh`:

```sh
#!/bin/sh
# Resolve spawn coordinates to game areas using the core's own terrain lookup.
#
# Runs a scratch mangosd whose databases point at the corpus instance, so the
# live server and live character data are never involved. The scratch core
# exits on its own once the resolver has written its output.
#
# Usage: run_resolver.sh <input.csv> <output.csv>
set -eu

HERE=$(dirname "$0")
. "$HERE/config.env"

IN=$1
OUT=$2
CONF="$HERE/logs/resolver_mangosd.conf"
mkdir -p "$HERE/logs"

# Start from the installed config so DataDir and the client build match the
# live server, then override the databases and switch the resolver on.
sed -e "s|^ContentAudit.ResolveAreasFile.*|ContentAudit.ResolveAreasFile = \"$IN\"|" \
    -e "s|^ContentAudit.ResolveAreasOutFile.*|ContentAudit.ResolveAreasOutFile = \"$OUT\"|" \
    -e "s|^WorldDatabase.Info.*|WorldDatabase.Info = \"$CORPUS_HOST;$CORPUS_PORT;root;;v\"|" \
    -e "s|^CharacterDatabase.Info.*|CharacterDatabase.Info = \"$CORPUS_HOST;$CORPUS_PORT;root;;characters\"|" \
    -e "s|^LoginDatabase.Info.*|LoginDatabase.Info = \"$CORPUS_HOST;$CORPUS_PORT;root;;realmd\"|" \
    -e "s|^LogsDatabase.Info.*|LogsDatabase.Info = \"$CORPUS_HOST;$CORPUS_PORT;root;;logs\"|" \
    "$SERVER_DIR/mangosd.conf" > "$CONF"

rm -f "$OUT"
( cd "$SERVER_DIR" && ./mangosd -c "$CONF" ) > "$HERE/logs/resolver.log" 2>&1 || true

if [ ! -s "$OUT" ]; then
    echo "resolver produced no output; see $HERE/logs/resolver.log" >&2
    exit 1
fi

grep "\[ContentAudit\]" "$HERE/logs/resolver.log" || true
```

Add `SERVER_DIR=/path/to/your/server/install` to `config.env.example` with the other placeholder values.

- [ ] **Step 9: Build the core**

```sh
# From the configured build directory, using every core available.
MSBuild.exe cmake-build-playerbots/ALL_BUILD.vcxproj "/m:16" "/p:CL_MPCount=16" "/p:Configuration=RelWithDebInfo"
```

Expected: builds clean. If `AreaResolverDump.cpp` produces no object file, its `CMakeLists.txt` entry is missing — the list is explicit and a missing entry fails silently.

- [ ] **Step 10: Install the scratch binary**

```sh
MSBuild.exe cmake-build-playerbots/INSTALL.vcxproj "/p:Configuration=RelWithDebInfo"
```

Note: this replaces the live server binary. Do it while the server is stopped, or the resolver will run against a binary the live server is also using.

- [ ] **Step 11: Run the test to verify it passes**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: `PASS test_resolver_assigns_known_zones`. If a fixture lands in the wrong zone, the coordinate is wrong rather than the code — verify it against the live database with
`SELECT map, position_x, position_y, position_z FROM creature WHERE id = 448;` and correct the fixture.

- [ ] **Step 12: Commit**

```sh
git add src/game/Maps/AreaResolverDump.h src/game/Maps/AreaResolverDump.cpp \
        src/game/CMakeLists.txt src/game/World.cpp \
        src/mangosd/mangosd.conf.dist.in \
        contrib/content-audit/run_resolver.sh contrib/content-audit/config.env.example \
        contrib/content-audit/test_pipeline.py
git commit -m "Add a temporary area resolver for the content audit

Creature and gameobject spawns carry a map and coordinates but no zone,
so nothing in the audit can be partitioned by area until coordinates are
resolved. TerrainManager already answers exactly this question, and its
answer is authoritative by construction: it is what the running server
believes the area to be.

The resolver is driven by a config key rather than a console command.
CliRunnable queues console input onto the world thread and stops the
server as soon as stdin reaches EOF, so a piped command races its own
shutdown. Reading a config key at a fixed point in startup does not.

That point is immediately after the DBC stores load, which is everything
the lookup needs. The world database never loads, so the pass takes
seconds rather than minutes.

Both the source file and the config key are temporary and are removed
once the corpus is built.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Spawn coordinate export and the areas table

**Files:**
- Create: `contrib/content-audit/export_coords.sh`
- Create: `contrib/content-audit/load_areas.sh`
- Test: `contrib/content-audit/test_pipeline.py`

**Interfaces:**
- Consumes: the corpus instance from Task 1, `run_resolver.sh` from Task 2.
- Produces: schema `cmp` containing `areas(src VARCHAR(4), kind VARCHAR(16), id INT UNSIGNED, map INT UNSIGNED, x FLOAT, y FLOAT, z FLOAT, zone INT UNSIGNED, area INT UNSIGNED)` with an index on `(src, kind, id)`. Every later task joins spawn rows to this table to learn their zone.

- [ ] **Step 1: Write the export script**

Create `contrib/content-audit/export_coords.sh`:

```sh
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
```

- [ ] **Step 2: Run the export and the resolver**

```sh
sh contrib/content-audit/export_coords.sh
sh contrib/content-audit/run_resolver.sh \
    contrib/content-audit/logs/spawn_coords.csv \
    contrib/content-audit/logs/spawn_areas.csv
```

Expected: roughly 900k rows exported; the resolver prints its resolved and skipped counts.

- [ ] **Step 3: Check the skip count before trusting anything**

```sh
awk -F, '{print $1}' contrib/content-audit/logs/spawn_coords.csv | sort | uniq -c
awk -F, '{print $1}' contrib/content-audit/logs/spawn_areas.csv  | sort | uniq -c
```

Expected: `v`, `tw` and `mz` lose almost nothing. `ac` loses a large share — those are its Outland, Northrend, Blood Elf and Draenei spawns, which have no 1.12 terrain and are correctly absent from a vanilla audit. A large loss in `v` means the scratch core could not find the extracted map data, not that content is missing; fix `DataDir` before continuing.

- [ ] **Step 4: Write the loader**

Create `contrib/content-audit/load_areas.sh`:

```sh
#!/bin/sh
# Load resolved spawn areas into the corpus as cmp.areas.
set -eu

HERE=$(dirname "$0")
. "$HERE/config.env"

MYSQL="$MYSQL_BIN_DIR/mysql"
CSV=${1:-"$HERE/logs/spawn_areas.csv"}

corpus() { "$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot --local-infile=1 "$@"; }

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
```

- [ ] **Step 5: Write the failing test**

Add to `test_pipeline.py`, above `TESTS`:

```python
def test_areas_table_populated_and_named():
    """cmp.areas has rows for every source and joins to the DBC area names."""
    rows = corpus_sql("SELECT src, COUNT(*) FROM cmp.areas GROUP BY src")
    counts = {r[0]: int(r[1]) for r in rows}
    for src in ("v", "mz", "tw", "ac"):
        assert counts.get(src, 0) > 1000, "%s has %d resolved spawns" % (
            src,
            counts.get(src, 0),
        )

    rows = corpus_sql(
        "SELECT COUNT(*) FROM cmp.areas a "
        "JOIN dbc.area_table t ON t.id = a.zone WHERE a.src = 'v'"
    )
    assert int(rows[0][0]) > 1000, "cmp.areas zones do not join to dbc.area_table"
    print("PASS test_areas_table_populated_and_named")
```

Add it to the `TESTS` list.

- [ ] **Step 6: Run it to verify it fails**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: FAIL — `cmp.areas` does not exist yet.

- [ ] **Step 7: Load and re-run**

```sh
sh contrib/content-audit/load_areas.sh
python contrib/content-audit/test_pipeline.py
```

Expected: `PASS test_areas_table_populated_and_named`.

Note: the `dbc` schema lives on the live instance, not the corpus. If the join fails because `dbc` is absent from the corpus, add a fourth `snapshot dbc dbc` line to `build_corpus.sh` and re-run that one snapshot.

- [ ] **Step 8: Commit**

```sh
git add contrib/content-audit/export_coords.sh contrib/content-audit/load_areas.sh \
        contrib/content-audit/test_pipeline.py
git commit -m "Resolve every source's spawn coordinates to a game area

Exports the union of all four sources' creature and gameobject spawns,
runs them through the core's terrain lookup, and loads the result back
into the corpus as cmp.areas, which every later diff joins against.

The spawn key travels through only so the resolved area can be joined
back on. GUIDs are not comparable between sources, so spawn comparison
is always an aggregate over an entry within an area, never a row-level
diff.

AzerothCore loses a large share of its spawns here. Those are its
Outland, Northrend and post-vanilla starting zones, which have no 1.12
terrain and do not belong in a vanilla audit. The count is printed rather
than swallowed, because the same symptom in one of the vanilla sources
would instead mean the extracted map data was not found.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Base normalising views

**Files:**
- Create: `contrib/content-audit/views/v.sql`
- Create: `contrib/content-audit/views/mz.sql`
- Create: `contrib/content-audit/views/tw.sql`
- Create: `contrib/content-audit/views/ac.sql`
- Create: `contrib/content-audit/build_views.sh`
- Test: `contrib/content-audit/test_pipeline.py`

**Interfaces:**
- Consumes: `cmp.areas` from Task 3.
- Produces: in each of `v`, `mz`, `tw`, `ac`, these seven views with identical column names and types:

```
n_creature  (entry, name, lvl_min, lvl_max, faction, rank, type, npc_flags, unit_class, hp_mult)
n_spawn     (kind, entry, zone, area, map, resp_min, resp_max, wander)
n_quest     (entry, title, lvl, min_lvl, zone_or_sort, prev, next, excl_group, req_race, req_class,
             rew_money_max_level, rew_xp)
n_quest_obj (quest, kind, target, cnt)
n_quest_rew (quest, kind, id, cnt)
n_loot      (tbl, entry, item, chance, grp, ref, quest_only, cmin, cmax)
n_rel       (kind, npc, target)
```

`n_creature.unit_class` and `hp_mult` and `n_quest.rew_money_max_level` and `rew_xp` are carried here because Tasks 5 and 6 compute from them; no later task reads a source's raw tables.

- [ ] **Step 1: Write the views for the live schema**

Create `contrib/content-audit/views/v.sql`. `tw` is the same lineage, so Task step 3 copies this file with the schema name changed.

```sql
-- Normalising views for a VMaNGOS-lineage schema.
-- Every diff query reads these and never the underlying tables.

CREATE OR REPLACE VIEW n_creature AS
SELECT entry, name, level_min AS lvl_min, level_max AS lvl_max, faction,
       rank, type, npc_flags, unit_class, health_multiplier AS hp_mult
FROM creature_template;

CREATE OR REPLACE VIEW n_spawn AS
SELECT a.kind, c.id AS entry, a.zone, a.area, c.map,
       c.spawntimesecsmin AS resp_min, c.spawntimesecsmax AS resp_max,
       c.wander_distance AS wander
FROM creature c
JOIN cmp.areas a ON a.src = 'v' AND a.kind = 'creature' AND a.id = c.guid
UNION ALL
SELECT a.kind, g.id AS entry, a.zone, a.area, g.map,
       g.spawntimesecsmin, g.spawntimesecsmax, 0
FROM gameobject g
JOIN cmp.areas a ON a.src = 'v' AND a.kind = 'gobject' AND a.id = g.guid;

CREATE OR REPLACE VIEW n_quest AS
SELECT entry, Title AS title, QuestLevel AS lvl, MinLevel AS min_lvl,
       ZoneOrSort AS zone_or_sort, PrevQuestId AS prev, NextQuestId AS next,
       ExclusiveGroup AS excl_group, RequiredRaces AS req_race,
       RequiredClasses AS req_class,
       RewMoneyMaxLevel AS rew_money_max_level, RewXP AS rew_xp
FROM quest_template;

CREATE OR REPLACE VIEW n_quest_obj AS
SELECT entry AS quest, 'npc'  AS kind, ReqCreatureOrGOId1 AS target, ReqCreatureOrGOCount1 AS cnt FROM quest_template WHERE ReqCreatureOrGOId1 > 0
UNION ALL SELECT entry, 'npc',  ReqCreatureOrGOId2, ReqCreatureOrGOCount2 FROM quest_template WHERE ReqCreatureOrGOId2 > 0
UNION ALL SELECT entry, 'npc',  ReqCreatureOrGOId3, ReqCreatureOrGOCount3 FROM quest_template WHERE ReqCreatureOrGOId3 > 0
UNION ALL SELECT entry, 'npc',  ReqCreatureOrGOId4, ReqCreatureOrGOCount4 FROM quest_template WHERE ReqCreatureOrGOId4 > 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId1, ReqCreatureOrGOCount1 FROM quest_template WHERE ReqCreatureOrGOId1 < 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId2, ReqCreatureOrGOCount2 FROM quest_template WHERE ReqCreatureOrGOId2 < 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId3, ReqCreatureOrGOCount3 FROM quest_template WHERE ReqCreatureOrGOId3 < 0
UNION ALL SELECT entry, 'go',  -ReqCreatureOrGOId4, ReqCreatureOrGOCount4 FROM quest_template WHERE ReqCreatureOrGOId4 < 0
UNION ALL SELECT entry, 'item', ReqItemId1, ReqItemCount1 FROM quest_template WHERE ReqItemId1 > 0
UNION ALL SELECT entry, 'item', ReqItemId2, ReqItemCount2 FROM quest_template WHERE ReqItemId2 > 0
UNION ALL SELECT entry, 'item', ReqItemId3, ReqItemCount3 FROM quest_template WHERE ReqItemId3 > 0
UNION ALL SELECT entry, 'item', ReqItemId4, ReqItemCount4 FROM quest_template WHERE ReqItemId4 > 0;

CREATE OR REPLACE VIEW n_quest_rew AS
SELECT entry AS quest, 'item'   AS kind, RewItemId1 AS id, RewItemCount1 AS cnt FROM quest_template WHERE RewItemId1 > 0
UNION ALL SELECT entry, 'item',   RewItemId2, RewItemCount2 FROM quest_template WHERE RewItemId2 > 0
UNION ALL SELECT entry, 'item',   RewItemId3, RewItemCount3 FROM quest_template WHERE RewItemId3 > 0
UNION ALL SELECT entry, 'item',   RewItemId4, RewItemCount4 FROM quest_template WHERE RewItemId4 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId1, RewChoiceItemCount1 FROM quest_template WHERE RewChoiceItemId1 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId2, RewChoiceItemCount2 FROM quest_template WHERE RewChoiceItemId2 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId3, RewChoiceItemCount3 FROM quest_template WHERE RewChoiceItemId3 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId4, RewChoiceItemCount4 FROM quest_template WHERE RewChoiceItemId4 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId5, RewChoiceItemCount5 FROM quest_template WHERE RewChoiceItemId5 > 0
UNION ALL SELECT entry, 'choice', RewChoiceItemId6, RewChoiceItemCount6 FROM quest_template WHERE RewChoiceItemId6 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction1, RewRepValue1 FROM quest_template WHERE RewRepFaction1 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction2, RewRepValue2 FROM quest_template WHERE RewRepFaction2 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction3, RewRepValue3 FROM quest_template WHERE RewRepFaction3 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction4, RewRepValue4 FROM quest_template WHERE RewRepFaction4 > 0
UNION ALL SELECT entry, 'rep',    RewRepFaction5, RewRepValue5 FROM quest_template WHERE RewRepFaction5 > 0
UNION ALL SELECT entry, 'spell',  RewSpell, 1 FROM quest_template WHERE RewSpell > 0
UNION ALL SELECT entry, 'money',  0, RewOrReqMoney FROM quest_template WHERE RewOrReqMoney > 0;

-- Signs carry meaning in this lineage: a negative chance means the row only
-- drops for a player on the quest, a negative mincount means the row is a
-- reference into reference_loot_template rather than an item.
CREATE OR REPLACE VIEW n_loot AS
SELECT 'creature' AS tbl, entry, item, ABS(ChanceOrQuestChance) AS chance, groupid AS grp,
       CASE WHEN mincountOrRef < 0 THEN -mincountOrRef ELSE 0 END AS ref,
       CASE WHEN ChanceOrQuestChance < 0 THEN 1 ELSE 0 END AS quest_only,
       CASE WHEN mincountOrRef > 0 THEN mincountOrRef ELSE 1 END AS cmin, maxcount AS cmax
FROM creature_loot_template
UNION ALL
SELECT 'gobject', entry, item, ABS(ChanceOrQuestChance), groupid,
       CASE WHEN mincountOrRef < 0 THEN -mincountOrRef ELSE 0 END,
       CASE WHEN ChanceOrQuestChance < 0 THEN 1 ELSE 0 END,
       CASE WHEN mincountOrRef > 0 THEN mincountOrRef ELSE 1 END, maxcount
FROM gameobject_loot_template
UNION ALL
SELECT 'reference', entry, item, ABS(ChanceOrQuestChance), groupid,
       CASE WHEN mincountOrRef < 0 THEN -mincountOrRef ELSE 0 END,
       CASE WHEN ChanceOrQuestChance < 0 THEN 1 ELSE 0 END,
       CASE WHEN mincountOrRef > 0 THEN mincountOrRef ELSE 1 END, maxcount
FROM reference_loot_template;

CREATE OR REPLACE VIEW n_rel AS
SELECT 'questgiver' AS kind, id AS npc, quest AS target FROM creature_questrelation
UNION ALL SELECT 'questender', id, quest FROM creature_involvedrelation
UNION ALL SELECT 'vendor',     entry, item FROM npc_vendor
UNION ALL SELECT 'trainer',    entry, spell FROM npc_trainer
UNION ALL SELECT 'link',       guid, master_guid FROM creature_linking;
```

- [ ] **Step 2: Write the views for mangoszero**

Create `contrib/content-audit/views/mz.sql`. It differs from `v.sql` in four ways and is otherwise identical, so write it out in full rather than describing a diff:

```sql
-- Normalising views for a MaNGOS Zero schema.
-- Differences from the VMaNGOS lineage: mixed-case column names, faction split
-- into an Alliance and a Horde column, absolute health on the template, and no
-- RewXP column at all.

CREATE OR REPLACE VIEW n_creature AS
SELECT Entry AS entry, Name AS name, MinLevel AS lvl_min, MaxLevel AS lvl_max,
       FactionAlliance AS faction, Rank AS rank, CreatureType AS type,
       NpcFlags AS npc_flags, UnitClass AS unit_class,
       HealthMultiplier AS hp_mult
FROM creature_template;

CREATE OR REPLACE VIEW n_spawn AS
SELECT a.kind, c.id AS entry, a.zone, a.area, c.map,
       c.spawntimesecsmin AS resp_min, c.spawntimesecsmax AS resp_max,
       c.spawndist AS wander
FROM creature c
JOIN cmp.areas a ON a.src = 'mz' AND a.kind = 'creature' AND a.id = c.guid
UNION ALL
SELECT a.kind, g.id, a.zone, a.area, g.map, g.spawntimesecs, g.spawntimesecs, 0
FROM gameobject g
JOIN cmp.areas a ON a.src = 'mz' AND a.kind = 'gobject' AND a.id = g.guid;

CREATE OR REPLACE VIEW n_quest AS
SELECT entry, Title AS title, QuestLevel AS lvl, MinLevel AS min_lvl,
       ZoneOrSort AS zone_or_sort, PrevQuestId AS prev, NextQuestId AS next,
       ExclusiveGroup AS excl_group, RequiredRaces AS req_race,
       RequiredClasses AS req_class,
       RewMoneyMaxLevel AS rew_money_max_level, NULL AS rew_xp
FROM quest_template;
```

The `n_quest_obj`, `n_quest_rew`, `n_loot` and `n_rel` definitions are character-identical to `v.sql` — MaNGOS Zero uses the same column names for those tables. Copy them across unchanged, with one exception: MaNGOS Zero has no `creature_linking` table under that name, so the final `UNION ALL` of `n_rel` becomes:

```sql
UNION ALL SELECT 'link', guid, master_guid FROM creature_linking;
```

Verify the table exists first:

```sh
"$MYSQL_BIN_DIR/mysql" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot \
    -e "SHOW TABLES FROM mz LIKE 'creature_linking%'"
```

If it does not exist, drop that `UNION ALL` from `mz.sql` and note the omission in the README under "Known source gaps" — a source that cannot express a relationship must abstain from voting on it rather than appear to vote "absent".

- [ ] **Step 3: Write the views for tortoise-wow**

```sh
sed 's/src = .v./src = '"'"'tw'"'"'/' contrib/content-audit/views/v.sql \
    > contrib/content-audit/views/tw.sql
```

Then open `tw.sql` and confirm the two `src = 'tw'` substitutions landed in `n_spawn` and nowhere else.

- [ ] **Step 4: Write the views for azerothcore**

Create `contrib/content-audit/views/ac.sql`:

```sql
-- Normalising views for a TrinityCore/AzerothCore schema.
-- This lineage splits into columns what the vanilla ones overload into signs:
-- Reference, QuestRequired and Chance are separate, so n_loot is a rename.

CREATE OR REPLACE VIEW n_creature AS
SELECT entry, name, minlevel AS lvl_min, maxlevel AS lvl_max, faction,
       rank, type, npcflag AS npc_flags, unit_class,
       HealthModifier AS hp_mult
FROM creature_template;

CREATE OR REPLACE VIEW n_spawn AS
SELECT a.kind, c.id1 AS entry, a.zone, a.area, c.map,
       c.spawntimesecs AS resp_min, c.spawntimesecs AS resp_max,
       c.wander_distance AS wander
FROM creature c
JOIN cmp.areas a ON a.src = 'ac' AND a.kind = 'creature' AND a.id = c.guid
UNION ALL
SELECT a.kind, g.id, a.zone, a.area, g.map, g.spawntimesecs, g.spawntimesecs, 0
FROM gameobject g
JOIN cmp.areas a ON a.src = 'ac' AND a.kind = 'gobject' AND a.id = g.guid;

CREATE OR REPLACE VIEW n_quest AS
SELECT q.ID AS entry, q.LogTitle AS title, q.QuestLevel AS lvl,
       q.MinLevel AS min_lvl, q.QuestSortID AS zone_or_sort,
       0 AS prev, q.RewardNextQuest AS next, 0 AS excl_group,
       q.AllowableRaces AS req_race, 0 AS req_class,
       q.RewardMoney AS rew_money_max_level, NULL AS rew_xp
FROM quest_template q;

CREATE OR REPLACE VIEW n_quest_obj AS
SELECT ID AS quest, 'npc' AS kind, RequiredNpcOrGo1 AS target, RequiredNpcOrGoCount1 AS cnt FROM quest_template WHERE RequiredNpcOrGo1 > 0
UNION ALL SELECT ID, 'npc',  RequiredNpcOrGo2, RequiredNpcOrGoCount2 FROM quest_template WHERE RequiredNpcOrGo2 > 0
UNION ALL SELECT ID, 'npc',  RequiredNpcOrGo3, RequiredNpcOrGoCount3 FROM quest_template WHERE RequiredNpcOrGo3 > 0
UNION ALL SELECT ID, 'npc',  RequiredNpcOrGo4, RequiredNpcOrGoCount4 FROM quest_template WHERE RequiredNpcOrGo4 > 0
UNION ALL SELECT ID, 'go',  -RequiredNpcOrGo1, RequiredNpcOrGoCount1 FROM quest_template WHERE RequiredNpcOrGo1 < 0
UNION ALL SELECT ID, 'go',  -RequiredNpcOrGo2, RequiredNpcOrGoCount2 FROM quest_template WHERE RequiredNpcOrGo2 < 0
UNION ALL SELECT ID, 'go',  -RequiredNpcOrGo3, RequiredNpcOrGoCount3 FROM quest_template WHERE RequiredNpcOrGo3 < 0
UNION ALL SELECT ID, 'go',  -RequiredNpcOrGo4, RequiredNpcOrGoCount4 FROM quest_template WHERE RequiredNpcOrGo4 < 0
UNION ALL SELECT ID, 'item', RequiredItemId1, RequiredItemCount1 FROM quest_template WHERE RequiredItemId1 > 0
UNION ALL SELECT ID, 'item', RequiredItemId2, RequiredItemCount2 FROM quest_template WHERE RequiredItemId2 > 0
UNION ALL SELECT ID, 'item', RequiredItemId3, RequiredItemCount3 FROM quest_template WHERE RequiredItemId3 > 0
UNION ALL SELECT ID, 'item', RequiredItemId4, RequiredItemCount4 FROM quest_template WHERE RequiredItemId4 > 0;

CREATE OR REPLACE VIEW n_quest_rew AS
SELECT ID AS quest, 'item' AS kind, RewardItem1 AS id, RewardAmount1 AS cnt FROM quest_template WHERE RewardItem1 > 0
UNION ALL SELECT ID, 'item',   RewardItem2, RewardAmount2 FROM quest_template WHERE RewardItem2 > 0
UNION ALL SELECT ID, 'item',   RewardItem3, RewardAmount3 FROM quest_template WHERE RewardItem3 > 0
UNION ALL SELECT ID, 'item',   RewardItem4, RewardAmount4 FROM quest_template WHERE RewardItem4 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID1, RewardChoiceItemQuantity1 FROM quest_template WHERE RewardChoiceItemID1 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID2, RewardChoiceItemQuantity2 FROM quest_template WHERE RewardChoiceItemID2 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID3, RewardChoiceItemQuantity3 FROM quest_template WHERE RewardChoiceItemID3 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID4, RewardChoiceItemQuantity4 FROM quest_template WHERE RewardChoiceItemID4 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID5, RewardChoiceItemQuantity5 FROM quest_template WHERE RewardChoiceItemID5 > 0
UNION ALL SELECT ID, 'choice', RewardChoiceItemID6, RewardChoiceItemQuantity6 FROM quest_template WHERE RewardChoiceItemID6 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID1, RewardFactionValue1 FROM quest_template WHERE RewardFactionID1 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID2, RewardFactionValue2 FROM quest_template WHERE RewardFactionID2 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID3, RewardFactionValue3 FROM quest_template WHERE RewardFactionID3 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID4, RewardFactionValue4 FROM quest_template WHERE RewardFactionID4 > 0
UNION ALL SELECT ID, 'rep',    RewardFactionID5, RewardFactionValue5 FROM quest_template WHERE RewardFactionID5 > 0
UNION ALL SELECT ID, 'spell',  RewardSpell, 1 FROM quest_template WHERE RewardSpell > 0
UNION ALL SELECT ID, 'money',  0, RewardMoney FROM quest_template WHERE RewardMoney > 0;

CREATE OR REPLACE VIEW n_loot AS
SELECT 'creature' AS tbl, Entry AS entry, Item AS item, Chance AS chance,
       GroupId AS grp, Reference AS ref, QuestRequired AS quest_only,
       MinCount AS cmin, MaxCount AS cmax
FROM creature_loot_template
UNION ALL
SELECT 'gobject', Entry, Item, Chance, GroupId, Reference, QuestRequired, MinCount, MaxCount
FROM gameobject_loot_template
UNION ALL
SELECT 'reference', Entry, Item, Chance, GroupId, Reference, QuestRequired, MinCount, MaxCount
FROM reference_loot_template;

CREATE OR REPLACE VIEW n_rel AS
SELECT 'questgiver' AS kind, id AS npc, quest AS target FROM creature_queststarter
UNION ALL SELECT 'questender', id, quest FROM creature_questender
UNION ALL SELECT 'vendor',     entry, item FROM npc_vendor
UNION ALL SELECT 'trainer',    ID, SpellID FROM npc_trainer;
```

AzerothCore has no direct equivalent of `creature_linking`, so `n_rel` omits the `link` kind. That is an abstention, and Task 9 must treat a source with no rows of a given `kind` as abstaining rather than as reporting absence.

- [ ] **Step 5: Write the view builder**

Create `contrib/content-audit/build_views.sh`:

```sh
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
```

`views/derived.sql` is created in Task 5; create it empty now so the script runs:

```sh
: > contrib/content-audit/views/derived.sql
```

- [ ] **Step 6: Write the failing test**

Add to `test_pipeline.py`, above `TESTS`:

```python
NORMALISED_VIEWS = [
    "n_creature",
    "n_spawn",
    "n_quest",
    "n_quest_obj",
    "n_quest_rew",
    "n_loot",
    "n_rel",
]


def test_normalised_views_exist_and_agree_on_shape():
    """Every source exposes every view, with the same columns, non-empty."""
    shapes = {}
    for view in NORMALISED_VIEWS:
        for src in ("v", "mz", "tw", "ac"):
            cols = corpus_sql(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_schema='%s' AND table_name='%s' "
                "ORDER BY ordinal_position" % (src, view)
            )
            names = tuple(c[0] for c in cols)
            assert names, "%s.%s does not exist" % (src, view)
            shapes.setdefault(view, {})[src] = names

            rows = corpus_sql("SELECT COUNT(*) FROM %s.%s" % (src, view))
            assert int(rows[0][0]) > 0, "%s.%s is empty" % (src, view)

        distinct = set(shapes[view].values())
        assert len(distinct) == 1, "%s has differing shapes: %s" % (view, shapes[view])
    print("PASS test_normalised_views_exist_and_agree_on_shape")


def test_known_westfall_quest_matches_across_vanilla_sources():
    """Quest 5-1 'Red Linen Goods' has the same objective shape in v and mz."""
    quest = 9  # Westfall: Red Linen Goods
    shape = {}
    for src in ("v", "mz"):
        rows = corpus_sql(
            "SELECT kind, target, cnt FROM %s.n_quest_obj "
            "WHERE quest=%d ORDER BY kind, target" % (src, quest)
        )
        shape[src] = [tuple(r) for r in rows]
    assert shape["v"], "quest %d has no objectives in v" % quest
    assert shape["v"] == shape["mz"], "quest %d differs: %s" % (quest, shape)
    print("PASS test_known_westfall_quest_matches_across_vanilla_sources")
```

Add both to the `TESTS` list.

- [ ] **Step 7: Run it to verify it fails**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: FAIL — the views do not exist.

- [ ] **Step 8: Build the views and iterate**

```sh
sh contrib/content-audit/build_views.sh
python contrib/content-audit/test_pipeline.py
```

Expected: several failures on the first pass, each naming a column that does not exist in one source. Fix that source's view file and re-run. This loop is the column archaeology the spec warns about and is the bulk of the work in this task.

If `test_known_westfall_quest_matches_across_vanilla_sources` fails on quest 9, that is a *finding*, not a test failure — pick another Westfall quest that does agree, use it as the fixture, and record quest 9 as the pipeline's first real result.

- [ ] **Step 9: Commit**

```sh
git add contrib/content-audit/views/ contrib/content-audit/build_views.sh \
        contrib/content-audit/test_pipeline.py
git commit -m "Normalise four world database schemas behind shared views

The four sources share almost no column vocabulary. creature_template
alone spells the minimum level three different ways, mangoszero splits
faction across two columns, and the vanilla lineages overload signs in
the loot tables where AzerothCore uses separate columns.

Each source now exposes the same seven views, and every diff query reads
those and nothing else. Adding a fifth source later is one more view file
and no change to any query.

Where a source cannot express a relationship at all - AzerothCore has no
creature_linking - the view omits that kind entirely. Consumers must read
an absent kind as an abstention, not as a claim that the relationship is
missing.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Effective health

**Files:**
- Modify: `contrib/content-audit/views/derived.sql`
- Test: `contrib/content-audit/test_pipeline.py`

**Interfaces:**
- Consumes: `n_creature` from Task 4.
- Produces: `cmp.n_creature_hp (src, entry, lvl, hp)` — one row per source, creature and level endpoint.

The rank multiplier is deliberately excluded. In VMaNGOS it comes from `CONFIG_FLOAT_RATE_CREATURE_*_HP`, which is server tuning rather than content, and a rank disagreement between sources is already a `rank` finding in topic 1. Including it here would report the same defect twice.

- [ ] **Step 1: Write the failing test**

Add to `test_pipeline.py`:

```python
def test_effective_health_resolves_for_every_source():
    """Each source produces a positive health figure for a known creature."""
    hogger = 448
    rows = corpus_sql(
        "SELECT src, lvl, hp FROM cmp.n_creature_hp WHERE entry=%d ORDER BY src, lvl"
        % hogger
    )
    got = {}
    for src, lvl, hp in rows:
        got.setdefault(src, []).append((int(lvl), float(hp)))
    for src in ("v", "mz", "tw", "ac"):
        assert src in got, "no health rows for %s" % src
        for lvl, hp in got[src]:
            assert hp > 0, "%s level %d gives hp %s" % (src, lvl, hp)
    # Hogger is level 11 in vanilla; a source disagreeing by 10x means the
    # stat table join is wrong, not that the creature differs.
    v_hp = max(hp for _lvl, hp in got["v"])
    mz_hp = max(hp for _lvl, hp in got["mz"])
    assert 0.1 < v_hp / mz_hp < 10, "v %.0f vs mz %.0f - check the stat join" % (
        v_hp,
        mz_hp,
    )
    print("PASS test_effective_health_resolves_for_every_source")
```

Add it to `TESTS`.

- [ ] **Step 2: Run it to verify it fails**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: FAIL — `cmp.n_creature_hp` does not exist.

- [ ] **Step 3: Confirm the mangoszero formula before writing it**

MaNGOS Zero carries both an absolute health on the template and a stat table. Check which its core actually uses:

```sh
grep -rn -A25 "void Creature::SelectLevel" \
    "$SRC_MZ/../mangoszero-server/src/game/Object/Creature.cpp" | grep -iE "health"
```

If it reads `MinLevelHealth`/`MaxLevelHealth`, use those directly. If those are zero for most rows, fall back to `creature_template_classlevelstats.BaseHealthExp0 * HealthMultiplier`. The view below implements the absolute value with that fallback, which is correct either way:

```sql
COALESCE(NULLIF(ct.MinLevelHealth, 0), cls.BaseHealthExp0 * ct.HealthMultiplier)
```

- [ ] **Step 4: Write the view**

Append to `contrib/content-audit/views/derived.sql`:

```sql
-- Effective creature health, resolved through each source's own pipeline.
--
-- VMaNGOS:     creature_classlevelstats.health * creature_template.health_multiplier
-- AzerothCore: creature_classlevelstats.basehp0 * creature_template.HealthModifier
-- MaNGOS Zero: absolute on the template, with the stat table as a fallback
--
-- The rank rate (CONFIG_FLOAT_RATE_CREATURE_*_HP) is excluded on purpose: it is
-- server tuning, not content, and a rank disagreement is already reported by
-- topic 1.

CREATE DATABASE IF NOT EXISTS cmp DEFAULT CHARACTER SET utf8mb4;

CREATE OR REPLACE VIEW cmp.n_creature_hp AS
SELECT 'v' AS src, ct.entry, cls.level AS lvl, cls.health * ct.health_multiplier AS hp
FROM v.creature_template ct
JOIN v.creature_classlevelstats cls
  ON cls.class = ct.unit_class AND cls.level IN (ct.level_min, ct.level_max)
UNION ALL
SELECT 'tw', ct.entry, cls.level, cls.health * ct.health_multiplier
FROM tw.creature_template ct
JOIN tw.creature_classlevelstats cls
  ON cls.class = ct.unit_class AND cls.level IN (ct.level_min, ct.level_max)
UNION ALL
SELECT 'ac', ct.entry, cls.level, cls.basehp0 * ct.HealthModifier
FROM ac.creature_template ct
JOIN ac.creature_classlevelstats cls
  ON cls.class = ct.unit_class AND cls.level IN (ct.minlevel, ct.maxlevel)
UNION ALL
SELECT 'mz', ct.Entry, lv.level,
       COALESCE(
           NULLIF(CASE WHEN lv.level = ct.MinLevel THEN ct.MinLevelHealth ELSE ct.MaxLevelHealth END, 0),
           cls.BaseHealthExp0 * ct.HealthMultiplier)
FROM mz.creature_template ct
JOIN (SELECT DISTINCT Level AS level FROM mz.creature_template_classlevelstats) lv
  ON lv.level IN (ct.MinLevel, ct.MaxLevel)
LEFT JOIN mz.creature_template_classlevelstats cls
  ON cls.Class = ct.UnitClass AND cls.Level = lv.level;
```

- [ ] **Step 5: Rebuild and run the test**

```sh
sh contrib/content-audit/build_views.sh
python contrib/content-audit/test_pipeline.py
```

Expected: `PASS test_effective_health_resolves_for_every_source`.

- [ ] **Step 6: Commit**

```sh
git add contrib/content-audit/views/derived.sql contrib/content-audit/test_pipeline.py
git commit -m "Resolve creature health through each source's own pipeline

Health is not a column that can be renamed into a shared shape. VMaNGOS
and AzerothCore store a multiplier against a class and level stat table;
mangoszero stores the figure outright. Comparing the raw columns would
compare a multiplier against a hit point total.

The rank rate is excluded. It comes from server configuration rather than
from content, and a rank disagreement between sources is already a
finding in the creature topic, so including it would report one defect
twice.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Quest experience and its self-consistency check

**Files:**
- Modify: `contrib/content-audit/views/derived.sql`
- Test: `contrib/content-audit/test_pipeline.py`

**Interfaces:**
- Consumes: `n_quest` from Task 4.
- Produces: `cmp.n_quest_xp (src, quest, xp, awards_xp)`. `xp` is NULL for `ac`, which cannot supply a vanilla figure; `awards_xp` is the boolean every source can vote on.

The vanilla formula, from `Quest::XPValue` in the MaNGOS Zero core: experience at full value is `RewMoneyMaxLevel` divided by a factor selected by quest level. The full piecewise ladder below was read from that function; levels at or above 65 use 6.0, and the ladder steps down through 61.

- [ ] **Step 1: Read the full divisor ladder from the source**

```sh
grep -n -A60 "uint32 Quest::XPValue" \
    "$SRC_MZ/../mangoszero-server/src/game/WorldHandlers/QuestDef.cpp"
```

Transcribe every branch. The head of the ladder is:

| Quest level | Divisor |
|---|---|
| >= 65 | 6.0 |
| 64 | 4.8 |
| 63 | 3.6 |
| 62 | 2.4 |
| 61 | 1.2 |

and below 61 the function uses a different branch — read it and write the `CASE` to match exactly. Do not approximate; an off-by-one divisor silently shifts every quest in a level band.

- [ ] **Step 2: Write the failing test**

Add to `test_pipeline.py`:

```python
def test_quest_xp_formula_matches_known_inputs():
    """The SQL divisor ladder reproduces Quest::XPValue for sampled levels."""
    # (quest level, RewMoneyMaxLevel, expected xp) - one per divisor branch,
    # computed by hand from the ladder read in step 1.
    cases = [(65, 1200, 200.0), (64, 1200, 250.0), (63, 1200, 333.0), (62, 1200, 500.0)]
    for lvl, money, expected in cases:
        rows = corpus_sql(
            "SELECT ROUND(cmp.vanilla_quest_xp(%d, %d))" % (lvl, money)
        )
        got = float(rows[0][0])
        assert abs(got - expected) <= 1, "level %d: got %s, expected %s" % (
            lvl,
            got,
            expected,
        )
    print("PASS test_quest_xp_formula_matches_known_inputs")


def test_vmangos_stored_xp_agrees_with_its_own_inputs():
    """Report, do not assert: quests whose RewXP contradicts the formula."""
    rows = corpus_sql(
        "SELECT COUNT(*) FROM cmp.n_quest_xp x "
        "JOIN v.n_quest q ON q.entry = x.quest "
        "WHERE x.src='v' AND q.rew_xp > 0 AND q.rew_money_max_level > 0 "
        "AND ABS(q.rew_xp - cmp.vanilla_quest_xp(q.lvl, q.rew_money_max_level)) > 1"
    )
    print("NOTE %s quests have a stored RewXP the vanilla formula disagrees with"
          % rows[0][0])
    print("PASS test_vmangos_stored_xp_agrees_with_its_own_inputs")
```

Add both to `TESTS`.

- [ ] **Step 3: Run it to verify it fails**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: FAIL — the function `cmp.vanilla_quest_xp` does not exist.

- [ ] **Step 4: Write the formula and the view**

Append to `contrib/content-audit/views/derived.sql`, filling the `CASE` from the ladder transcribed in step 1:

```sql
-- The vanilla quest experience formula, transcribed from Quest::XPValue.
-- MaNGOS Zero computes this at runtime; VMaNGOS stores the result as RewXP.
-- Both carry the inputs, so the comparison is exact.

DROP FUNCTION IF EXISTS cmp.vanilla_quest_xp;
CREATE FUNCTION cmp.vanilla_quest_xp(quest_level INT, money_max_level INT)
RETURNS DOUBLE DETERMINISTIC
RETURN CASE
    WHEN money_max_level <= 0 THEN 0
    WHEN quest_level >= 65 THEN money_max_level / 6.0
    WHEN quest_level  = 64 THEN money_max_level / 4.8
    WHEN quest_level  = 63 THEN money_max_level / 3.6
    WHEN quest_level  = 62 THEN money_max_level / 2.4
    WHEN quest_level  = 61 THEN money_max_level / 1.2
    ELSE money_max_level  -- replace with the sub-61 branch read in step 1
END;

CREATE OR REPLACE VIEW cmp.n_quest_xp AS
SELECT 'v' AS src, entry AS quest, rew_xp AS xp,
       CASE WHEN rew_xp > 0 THEN 1 ELSE 0 END AS awards_xp
FROM v.n_quest
UNION ALL
SELECT 'tw', entry, rew_xp, CASE WHEN rew_xp > 0 THEN 1 ELSE 0 END
FROM tw.n_quest
UNION ALL
SELECT 'mz', entry, cmp.vanilla_quest_xp(lvl, rew_money_max_level),
       CASE WHEN rew_money_max_level > 0 THEN 1 ELSE 0 END
FROM mz.n_quest
UNION ALL
-- AzerothCore cannot supply a vanilla figure: RewardXPDifficulty indexes
-- QuestXP.dbc, which is not available here, and WotLK rebalanced quest
-- experience regardless. It votes on the boolean only.
SELECT 'ac', ID, NULL,
       CASE WHEN RewardXPDifficulty > 0 THEN 1 ELSE 0 END
FROM ac.quest_template;
```

- [ ] **Step 5: Rebuild and run**

```sh
sh contrib/content-audit/build_views.sh
python contrib/content-audit/test_pipeline.py
```

Expected: `PASS test_quest_xp_formula_matches_known_inputs`, and a `NOTE` line giving the count of self-inconsistent quests. That count is the first real audit result the pipeline produces; record it in the commit message.

- [ ] **Step 6: Commit**

```sh
git add contrib/content-audit/views/derived.sql contrib/content-audit/test_pipeline.py
git commit -m "Compare quest experience, and check it against its own inputs

VMaNGOS stores quest experience as a column. MaNGOS Zero has no such
column and derives the figure at runtime from RewMoneyMaxLevel and the
quest level. Both carry the inputs, so transcribing the divisor ladder
into SQL makes the comparison exact rather than approximate.

The same formula applied to VMaNGOS's own inputs yields a second check
that needs no other source: any quest whose stored reward contradicts the
formula is a defect on its own evidence, and the consensus rule would
never have surfaced it.

AzerothCore votes only on whether a quest awards experience at all. Its
figure indexes a DBC that is not available here and carries WotLK
rebalancing even when it is.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Effective drop chance

**Files:**
- Modify: `contrib/content-audit/views/derived.sql`
- Test: `contrib/content-audit/test_pipeline.py`

**Interfaces:**
- Consumes: `n_loot` from Task 4.
- Produces: `cmp.n_loot_eff (src, tbl, entry, item, quest_only, p_drop)` where `p_drop` is a probability in `[0, 1]`.

Write the test before the view. Group and reference resolution produces a plausible-looking number whatever the bug, and topic 5 rests entirely on this view.

- [ ] **Step 1: Write the failing test**

Add to `test_pipeline.py`:

```python
LOOT_FIXTURE = """
DROP DATABASE IF EXISTS cmp_test;
CREATE DATABASE cmp_test DEFAULT CHARACTER SET utf8mb4;
CREATE TABLE cmp_test.n_loot (
    tbl VARCHAR(16), entry INT, item INT, chance DOUBLE,
    grp INT, ref INT, quest_only INT, cmin INT, cmax INT
);
INSERT INTO cmp_test.n_loot VALUES
    -- 1: an ungrouped row at 25%
    ('creature', 1, 101, 25, 0, 0, 0, 1, 1),
    -- 2: a group of one explicit 30% row and two equal-chance rows
    ('creature', 2, 201, 30, 1, 0, 0, 1, 1),
    ('creature', 2, 202,  0, 1, 0, 0, 1, 1),
    ('creature', 2, 203,  0, 1, 0, 0, 1, 1),
    -- 3: a row referencing a sub-table at 50%, the sub-table dropping at 40%
    ('creature',  3, 0,   50, 0, 9, 0, 1, 1),
    ('reference', 9, 301, 40, 0, 0, 0, 1, 1),
    -- 4: a table that references itself, which must terminate
    ('creature',  4, 0,  100, 0, 8, 0, 1, 1),
    ('reference', 8, 401, 10, 0, 8, 0, 1, 1);
"""


def test_effective_drop_chance():
    """Group competition, reference expansion and cycle termination."""
    subprocess.run(
        [
            os.path.join(CFG["MYSQL_BIN_DIR"], "mysql"),
            "--host=" + CFG["CORPUS_HOST"],
            "--port=" + CFG["CORPUS_PORT"],
            "-uroot",
            "--execute=" + LOOT_FIXTURE,
        ],
        check=True,
    )
    sql_path = os.path.join(HERE, "views", "loot_eff_body.sql")
    with open(sql_path, encoding="utf-8") as handle:
        body = handle.read().replace("__SRC__", "cmp_test")
    rows = corpus_sql(body)
    got = {(r[1], int(r[2])): round(float(r[4]), 4) for r in rows}

    assert got[("1", 101)] == 0.25, "ungrouped 25%% gave %s" % got[("1", 101)]
    assert got[("2", 201)] == 0.30, "explicit group member gave %s" % got[("2", 201)]
    assert got[("2", 202)] == 0.35, "equal group member gave %s" % got[("2", 202)]
    assert got[("2", 203)] == 0.35, "equal group member gave %s" % got[("2", 203)]
    assert got[("3", 301)] == 0.20, "0.50 x 0.40 gave %s" % got[("3", 301)]
    assert ("4", 401) in got, "self-referencing table produced nothing"
    print("PASS test_effective_drop_chance")
```

Add it to `TESTS`.

- [ ] **Step 2: Run it to verify it fails**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: FAIL — `views/loot_eff_body.sql` does not exist.

- [ ] **Step 3: Write the resolution query**

Create `contrib/content-audit/views/loot_eff_body.sql`. `__SRC__` is substituted with a schema name, which lets the test run it against a fixture and `derived.sql` run it against each source.

```sql
WITH RECURSIVE
-- Per group: how much chance is spoken for, and how many rows share the rest.
grp AS (
    SELECT tbl, entry, grp AS g,
           SUM(CASE WHEN chance > 0 THEN chance ELSE 0 END) AS sum_explicit,
           SUM(CASE WHEN chance = 0 THEN 1 ELSE 0 END)      AS n_equal
    FROM __SRC__.n_loot
    GROUP BY tbl, entry, grp
),
-- The probability of each row firing, before any reference is followed.
-- Ungrouped rows roll independently. Grouped rows compete for one roll:
-- an explicit chance is absolute within it, and rows at zero divide the rest.
base AS (
    SELECT l.tbl, l.entry, l.item, l.ref, l.quest_only,
           CASE
               WHEN l.grp = 0     THEN l.chance / 100.0
               WHEN l.chance > 0  THEN l.chance / 100.0
               WHEN g.n_equal > 0 THEN GREATEST(100.0 - g.sum_explicit, 0) / g.n_equal / 100.0
               ELSE 0
           END AS p_local
    FROM __SRC__.n_loot l
    JOIN grp g ON g.tbl = l.tbl AND g.entry = l.entry AND g.g = l.grp
),
-- Follow references, multiplying probabilities. The depth cap is what makes a
-- self-referencing table terminate; five is far beyond any real loot tree.
walk AS (
    SELECT tbl, entry AS root_entry, item, ref, quest_only, p_local AS p, 0 AS depth
    FROM base
    WHERE tbl <> 'reference'
    UNION ALL
    SELECT w.tbl, w.root_entry, b.item, b.ref,
           GREATEST(w.quest_only, b.quest_only), w.p * b.p_local, w.depth + 1
    FROM walk w
    JOIN base b ON b.tbl = 'reference' AND b.entry = w.ref
    WHERE w.ref > 0 AND w.depth < 5
)
-- An item reachable by several paths drops if any path fires. Clamp before the
-- logarithm: a row at 100% would otherwise take LOG(0).
SELECT '__SRC__' AS src, tbl, root_entry AS entry, item, quest_only,
       1 - EXP(SUM(LOG(1 - LEAST(p, 0.999999)))) AS p_drop
FROM walk
WHERE ref = 0 AND item > 0
GROUP BY tbl, root_entry, item, quest_only;
```

- [ ] **Step 4: Run the test to verify it passes**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: `PASS test_effective_drop_chance`. If the equal-chance members give 0.35 but the explicit one gives something other than 0.30, the `base` CASE ordering is wrong — the `chance > 0` branch must be checked before the equal-share branch.

- [ ] **Step 5: Wire it into the derived views**

Append to `contrib/content-audit/views/derived.sql`:

```sql
-- Effective drop probability per source. The body lives in loot_eff_body.sql
-- so that the checks can run it against a fixture schema.
```

Then extend `build_views.sh` to generate the view from the body, immediately before it sources `derived.sql`:

```sh
echo "views: loot_eff"
{
    echo "CREATE OR REPLACE VIEW cmp.n_loot_eff AS"
    for src in v mz tw ac; do
        [ "$src" = v ] || echo "UNION ALL"
        sed "s/__SRC__/$src/g" "$HERE/views/loot_eff_body.sql"
    done
} | "$MYSQL" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot
```

Note: a `WITH RECURSIVE` clause cannot be repeated inside a `UNION ALL`. Generate one view per source instead — `cmp.n_loot_eff_v`, `_mz`, `_tw`, `_ac` — and define `cmp.n_loot_eff` as a plain `UNION ALL` over those four:

```sh
echo "views: loot_eff"
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
```

- [ ] **Step 6: Rebuild and sanity-check against the game**

```sh
sh contrib/content-audit/build_views.sh
"$MYSQL_BIN_DIR/mysql" --host="$CORPUS_HOST" --port="$CORPUS_PORT" -uroot -e "
SELECT src, ROUND(p_drop*100,1) FROM cmp.n_loot_eff
WHERE tbl='creature' AND entry=448 ORDER BY src, p_drop DESC LIMIT 12;"
```

Expected: every probability between 0 and 1, none above 1, and the vanilla sources broadly agreeing. A probability above 1 means the independent-combination step is wrong.

- [ ] **Step 7: Commit**

```sh
git add contrib/content-audit/views/loot_eff_body.sql \
        contrib/content-audit/views/derived.sql \
        contrib/content-audit/build_views.sh \
        contrib/content-audit/test_pipeline.py
git commit -m "Resolve loot tables into an effective drop probability

A chance column is not a drop probability. Rows sharing a group id
compete for a single roll, an explicit chance is absolute within that
roll, rows left at zero divide whatever remains, and a row can be a
reference into another table rather than an item at all. Comparing the
raw columns across sources compares numbers that do not mean the same
thing.

The resolution expands references with a recursive walk and combines
paths as independent events. The depth cap is what makes a
self-referencing table terminate rather than run forever.

The checks were written before the query, because this is the one piece
of the pipeline that can be confidently wrong: whatever the bug, it still
produces a plausible-looking percentage, and the quest item drop topic
rests entirely on it.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: The findings table and the consensus rule

**Files:**
- Create: `contrib/content-audit/diffs/00_schema.sql`
- Create: `contrib/content-audit/run_diffs.sh`
- Test: `contrib/content-audit/test_pipeline.py`

**Interfaces:**
- Consumes: nothing beyond the corpus.
- Produces: `cmp.findings(zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)` and the function `cmp.strength(v, mz, ac)` returning `'strong'`, `'weak'` or `''`. Every diff query in Tasks 9 and 10 inserts through this function and never computes a strength itself.

- [ ] **Step 1: Write the failing test**

Add to `test_pipeline.py`:

```python
def test_consensus_strength_rule():
    """The strength rule, against the spec's own worked cases."""
    cases = [
        # (v, mz, ac, expected)
        ("1", "2", "2", "strong"),   # both peers agree against v
        ("1", "2", "1", "weak"),     # only mz disagrees
        ("1", "1", "2", "weak"),     # only ac disagrees
        ("1", "2", "3", "weak"),     # peers disagree with each other
        ("1", "1", "1", ""),         # nobody disagrees
        ("1", None, "2", "weak"),    # an abstaining peer cannot make it strong
        ("1", None, None, ""),       # no peers, no finding
    ]
    for v, mz, ac, expected in cases:
        def lit(x):
            return "NULL" if x is None else "'%s'" % x

        rows = corpus_sql(
            "SELECT cmp.strength(%s, %s, %s)" % (lit(v), lit(mz), lit(ac))
        )
        got = rows[0][0]
        got = "" if got == "NULL" else got
        assert got == expected, "v=%s mz=%s ac=%s gave %r, expected %r" % (
            v,
            mz,
            ac,
            got,
            expected,
        )
    print("PASS test_consensus_strength_rule")
```

Add it to `TESTS`.

- [ ] **Step 2: Run it to verify it fails**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: FAIL — `cmp.strength` does not exist.

- [ ] **Step 3: Write the schema and the rule**

Create `contrib/content-audit/diffs/00_schema.sql`:

```sql
CREATE DATABASE IF NOT EXISTS cmp DEFAULT CHARACTER SET utf8mb4;

DROP TABLE IF EXISTS cmp.findings;
CREATE TABLE cmp.findings (
    zone        INT UNSIGNED NOT NULL,
    topic       VARCHAR(32)  NOT NULL,
    entity_kind VARCHAR(16)  NOT NULL,
    entity_id   INT UNSIGNED NOT NULL,
    field       VARCHAR(48)  NOT NULL,
    v_value     VARCHAR(128),
    mz_value    VARCHAR(128),
    tw_value    VARCHAR(128),
    ac_value    VARCHAR(128),
    strength    VARCHAR(8)   NOT NULL,
    note        VARCHAR(255) NOT NULL DEFAULT '',
    KEY ix_zone_topic (zone, topic),
    KEY ix_strength (strength)
) ENGINE=InnoDB;

-- The consensus rule, in one place.
--
-- tortoise-wow is a fork of the live database, so its agreement carries no
-- information and it is not an argument here. It enters a report only where it
-- disagrees, as context on a finding the peers already raised.
--
-- A NULL peer is abstaining - it cannot express this field at all - and an
-- abstention never strengthens a finding.
DROP FUNCTION IF EXISTS cmp.strength;
CREATE FUNCTION cmp.strength(v VARCHAR(128), mz VARCHAR(128), ac VARCHAR(128))
RETURNS VARCHAR(8) DETERMINISTIC
RETURN CASE
    WHEN mz IS NULL AND ac IS NULL                      THEN ''
    WHEN mz IS NOT NULL AND ac IS NOT NULL
         AND NOT (v <=> mz) AND NOT (v <=> ac)
         AND (mz <=> ac)                                THEN 'strong'
    WHEN NOT (v <=> mz) OR NOT (v <=> ac)               THEN 'weak'
    ELSE ''
END;
```

Note on `<=>`: MySQL's null-safe equality. Ordinary `=` returns NULL when either side is NULL, which would make every comparison against an abstaining source silently vanish instead of being handled by the rule above.

- [ ] **Step 4: Write the diff runner**

Create `contrib/content-audit/run_diffs.sh`:

```sh
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
```

- [ ] **Step 5: Run the test to verify it passes**

```sh
sh contrib/content-audit/run_diffs.sh
python contrib/content-audit/test_pipeline.py
```

Expected: `PASS test_consensus_strength_rule`.

- [ ] **Step 6: Commit**

```sh
git add contrib/content-audit/diffs/00_schema.sql contrib/content-audit/run_diffs.sh \
        contrib/content-audit/test_pipeline.py
git commit -m "Add the findings table and put the consensus rule in one place

Every diff query inserts through cmp.strength rather than deciding for
itself, so the rule can be argued about and changed in one place.

tortoise-wow is not an argument in it. The database is a fork of the one
under audit, so its agreement carries no information; it appears in a
report only where it disagrees, as context on a finding the independent
peers already raised.

Comparisons use null-safe equality throughout. A source that cannot
express a field is abstaining, and ordinary equality would have made
those rows evaluate to NULL and disappear rather than be handled.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Diff queries for creatures, relationships and spawns

**Files:**
- Create: `contrib/content-audit/diffs/01_creatures.sql`
- Create: `contrib/content-audit/diffs/02_relations.sql`
- Create: `contrib/content-audit/diffs/06_spawns.sql`
- Test: `contrib/content-audit/test_pipeline.py`

**Interfaces:**
- Consumes: `n_creature`, `n_spawn`, `n_rel`, `cmp.n_creature_hp`, `cmp.strength`, `cmp.areas`.
- Produces: rows in `cmp.findings` with `topic` in `creatures`, `relations`, `spawns`.

A creature belongs to a zone if it is spawned there in any source. That is what makes a missing template reportable: a creature spawned in Westfall by mangoszero but absent from the live database has no live spawn to find it by.

- [ ] **Step 1: Write the creature diff**

Create `contrib/content-audit/diffs/01_creatures.sql`:

```sql
-- Topic 1: creature templates, per zone.

-- Every (zone, creature) pair any source places in the world.
CREATE OR REPLACE VIEW cmp.zone_creature AS
SELECT DISTINCT zone, entry FROM v.n_spawn  WHERE kind = 'creature'
UNION SELECT DISTINCT zone, entry FROM mz.n_spawn WHERE kind = 'creature'
UNION SELECT DISTINCT zone, entry FROM tw.n_spawn WHERE kind = 'creature'
UNION SELECT DISTINCT zone, entry FROM ac.n_spawn WHERE kind = 'creature';

INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zc.zone, 'creatures', 'creature', zc.entry, f.field,
       f.v, f.mz, f.tw, f.ac,
       cmp.strength(f.v, f.mz, f.ac),
       CASE WHEN f.v IS NULL THEN 'absent from the live database' ELSE '' END
FROM cmp.zone_creature zc
JOIN (
    SELECT zc2.entry,
           'exists' AS field,
           CASE WHEN cv.entry  IS NULL THEN NULL ELSE '1' END AS v,
           CASE WHEN cmz.entry IS NULL THEN NULL ELSE '1' END AS mz,
           CASE WHEN ctw.entry IS NULL THEN NULL ELSE '1' END AS tw,
           CASE WHEN cac.entry IS NULL THEN NULL ELSE '1' END AS ac
    FROM (SELECT DISTINCT entry FROM cmp.zone_creature) zc2
    LEFT JOIN v.n_creature  cv  ON cv.entry  = zc2.entry
    LEFT JOIN mz.n_creature cmz ON cmz.entry = zc2.entry
    LEFT JOIN tw.n_creature ctw ON ctw.entry = zc2.entry
    LEFT JOIN ac.n_creature cac ON cac.entry = zc2.entry

    UNION ALL

    SELECT zc2.entry, fld.field,
           CAST(CASE fld.field WHEN 'lvl_min' THEN cv.lvl_min WHEN 'lvl_max' THEN cv.lvl_max
                               WHEN 'faction' THEN cv.faction WHEN 'rank' THEN cv.rank
                               WHEN 'type' THEN cv.type END AS CHAR),
           CAST(CASE fld.field WHEN 'lvl_min' THEN cmz.lvl_min WHEN 'lvl_max' THEN cmz.lvl_max
                               WHEN 'faction' THEN cmz.faction WHEN 'rank' THEN cmz.rank
                               WHEN 'type' THEN cmz.type END AS CHAR),
           CAST(CASE fld.field WHEN 'lvl_min' THEN ctw.lvl_min WHEN 'lvl_max' THEN ctw.lvl_max
                               WHEN 'faction' THEN ctw.faction WHEN 'rank' THEN ctw.rank
                               WHEN 'type' THEN ctw.type END AS CHAR),
           CAST(CASE fld.field WHEN 'lvl_min' THEN cac.lvl_min WHEN 'lvl_max' THEN cac.lvl_max
                               WHEN 'faction' THEN cac.faction WHEN 'rank' THEN cac.rank
                               WHEN 'type' THEN cac.type END AS CHAR)
    FROM (SELECT DISTINCT entry FROM cmp.zone_creature) zc2
    CROSS JOIN (SELECT 'lvl_min' AS field UNION ALL SELECT 'lvl_max'
                UNION ALL SELECT 'faction' UNION ALL SELECT 'rank'
                UNION ALL SELECT 'type') fld
    JOIN v.n_creature  cv  ON cv.entry  = zc2.entry
    LEFT JOIN mz.n_creature cmz ON cmz.entry = zc2.entry
    LEFT JOIN tw.n_creature ctw ON ctw.entry = zc2.entry
    LEFT JOIN ac.n_creature cac ON cac.entry = zc2.entry
) f ON f.entry = zc.entry
WHERE cmp.strength(f.v, f.mz, f.ac) <> '';

-- Effective health, at the 20% tolerance from the spec. AzerothCore's vote is
-- advisory: WotLK inflated creature health as policy, so it counts only where
-- mangoszero agrees. Passing NULL for ac where mz is absent expresses exactly
-- that - an unsupported AzerothCore figure cannot make a finding strong.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zc.zone, 'creatures', 'creature', zc.entry,
       CONCAT('hp@', hv.lvl),
       ROUND(hv.hp), ROUND(hmz.hp), ROUND(htw.hp), ROUND(hac.hp),
       cmp.strength(
           ROUND(hv.hp),
           ROUND(hmz.hp),
           CASE WHEN hmz.hp IS NULL THEN NULL ELSE ROUND(hac.hp) END),
       'AzerothCore health is advisory; WotLK inflated creature health'
FROM cmp.zone_creature zc
JOIN      cmp.n_creature_hp hv  ON hv.src  = 'v'  AND hv.entry  = zc.entry
LEFT JOIN cmp.n_creature_hp hmz ON hmz.src = 'mz' AND hmz.entry = zc.entry AND hmz.lvl = hv.lvl
LEFT JOIN cmp.n_creature_hp htw ON htw.src = 'tw' AND htw.entry = zc.entry AND htw.lvl = hv.lvl
LEFT JOIN cmp.n_creature_hp hac ON hac.src = 'ac' AND hac.entry = zc.entry AND hac.lvl = hv.lvl
WHERE (hmz.hp IS NOT NULL AND ABS(hv.hp - hmz.hp) / GREATEST(hmz.hp, 1) >= 0.20)
   OR (hac.hp IS NOT NULL AND ABS(hv.hp - hac.hp) / GREATEST(hac.hp, 1) >= 0.20);
```

- [ ] **Step 2: Write the relationship diff**

Create `contrib/content-audit/diffs/02_relations.sql`:

```sql
-- Topic 2: connected creatures. Four relationship families, one query shape.
--
-- A source with no rows at all of a given kind is abstaining, not reporting
-- absence: AzerothCore has no creature_linking equivalent, so it must not vote
-- on links. The HAVING clause below is what enforces that.

CREATE OR REPLACE VIEW cmp.rel_kinds_present AS
SELECT 'v'  AS src, kind FROM v.n_rel  GROUP BY kind
UNION ALL SELECT 'mz', kind FROM mz.n_rel GROUP BY kind
UNION ALL SELECT 'tw', kind FROM tw.n_rel GROUP BY kind
UNION ALL SELECT 'ac', kind FROM ac.n_rel GROUP BY kind;

INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT z.zone, 'relations', 'creature', r.npc,
       CONCAT(r.kind, ':', r.target),
       CASE WHEN rv.npc  IS NULL THEN NULL ELSE '1' END,
       CASE WHEN rmz.npc IS NULL AND kmz.kind IS NOT NULL THEN '0'
            WHEN rmz.npc IS NULL THEN NULL ELSE '1' END,
       CASE WHEN rtw.npc IS NULL AND ktw.kind IS NOT NULL THEN '0'
            WHEN rtw.npc IS NULL THEN NULL ELSE '1' END,
       CASE WHEN rac.npc IS NULL AND kac.kind IS NOT NULL THEN '0'
            WHEN rac.npc IS NULL THEN NULL ELSE '1' END,
       cmp.strength(
           CASE WHEN rv.npc IS NULL THEN '0' ELSE '1' END,
           CASE WHEN kmz.kind IS NULL THEN NULL WHEN rmz.npc IS NULL THEN '0' ELSE '1' END,
           CASE WHEN kac.kind IS NULL THEN NULL WHEN rac.npc IS NULL THEN '0' ELSE '1' END),
       ''
FROM (
    SELECT kind, npc, target FROM v.n_rel
    UNION SELECT kind, npc, target FROM mz.n_rel
    UNION SELECT kind, npc, target FROM tw.n_rel
    UNION SELECT kind, npc, target FROM ac.n_rel
) r
JOIN (SELECT DISTINCT zone, entry FROM v.n_spawn WHERE kind='creature'
      UNION SELECT DISTINCT zone, entry FROM mz.n_spawn WHERE kind='creature') z
  ON z.entry = r.npc
LEFT JOIN v.n_rel  rv  ON rv.kind  = r.kind AND rv.npc  = r.npc AND rv.target  = r.target
LEFT JOIN mz.n_rel rmz ON rmz.kind = r.kind AND rmz.npc = r.npc AND rmz.target = r.target
LEFT JOIN tw.n_rel rtw ON rtw.kind = r.kind AND rtw.npc = r.npc AND rtw.target = r.target
LEFT JOIN ac.n_rel rac ON rac.kind = r.kind AND rac.npc = r.npc AND rac.target = r.target
LEFT JOIN cmp.rel_kinds_present kmz ON kmz.src = 'mz' AND kmz.kind = r.kind
LEFT JOIN cmp.rel_kinds_present ktw ON ktw.src = 'tw' AND ktw.kind = r.kind
LEFT JOIN cmp.rel_kinds_present kac ON kac.src = 'ac' AND kac.kind = r.kind
WHERE cmp.strength(
        CASE WHEN rv.npc IS NULL THEN '0' ELSE '1' END,
        CASE WHEN kmz.kind IS NULL THEN NULL WHEN rmz.npc IS NULL THEN '0' ELSE '1' END,
        CASE WHEN kac.kind IS NULL THEN NULL WHEN rac.npc IS NULL THEN '0' ELSE '1' END) <> '';
```

- [ ] **Step 3: Write the spawn diff**

Create `contrib/content-audit/diffs/06_spawns.sql`:

```sql
-- Topic 6: spawn counts and respawn windows, per zone and creature.
--
-- GUIDs are not comparable between sources, so this is always an aggregate.
-- Tolerances from the spec: count differs by 50% or by 5 spawns; respawn by 2x.

CREATE OR REPLACE VIEW cmp.spawn_agg AS
SELECT 'v' AS src, kind, zone, entry, COUNT(*) AS n,
       MIN(resp_min) AS resp_min, MAX(resp_max) AS resp_max
FROM v.n_spawn GROUP BY kind, zone, entry
UNION ALL
SELECT 'mz', kind, zone, entry, COUNT(*), MIN(resp_min), MAX(resp_max)
FROM mz.n_spawn GROUP BY kind, zone, entry
UNION ALL
SELECT 'tw', kind, zone, entry, COUNT(*), MIN(resp_min), MAX(resp_max)
FROM tw.n_spawn GROUP BY kind, zone, entry
UNION ALL
SELECT 'ac', kind, zone, entry, COUNT(*), MIN(resp_min), MAX(resp_max)
FROM ac.n_spawn GROUP BY kind, zone, entry;

INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT k.zone, 'spawns', k.kind, k.entry, 'spawn_count',
       av.n, amz.n, atw.n, aac.n,
       cmp.strength(av.n, amz.n, aac.n), ''
FROM (SELECT DISTINCT kind, zone, entry FROM cmp.spawn_agg) k
LEFT JOIN cmp.spawn_agg av  ON av.src  = 'v'  AND av.kind  = k.kind AND av.zone  = k.zone AND av.entry  = k.entry
LEFT JOIN cmp.spawn_agg amz ON amz.src = 'mz' AND amz.kind = k.kind AND amz.zone = k.zone AND amz.entry = k.entry
LEFT JOIN cmp.spawn_agg atw ON atw.src = 'tw' AND atw.kind = k.kind AND atw.zone = k.zone AND atw.entry = k.entry
LEFT JOIN cmp.spawn_agg aac ON aac.src = 'ac' AND aac.kind = k.kind AND aac.zone = k.zone AND aac.entry = k.entry
WHERE (amz.n IS NOT NULL AND (ABS(COALESCE(av.n,0) - amz.n) >= 5
                          OR ABS(COALESCE(av.n,0) - amz.n) / GREATEST(amz.n,1) >= 0.50))
   OR (aac.n IS NOT NULL AND (ABS(COALESCE(av.n,0) - aac.n) >= 5
                          OR ABS(COALESCE(av.n,0) - aac.n) / GREATEST(aac.n,1) >= 0.50));

INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT k.zone, 'spawns', k.kind, k.entry, 'respawn_min',
       av.resp_min, amz.resp_min, atw.resp_min, aac.resp_min,
       cmp.strength(av.resp_min, amz.resp_min, aac.resp_min), ''
FROM (SELECT DISTINCT kind, zone, entry FROM cmp.spawn_agg) k
JOIN      cmp.spawn_agg av  ON av.src  = 'v'  AND av.kind  = k.kind AND av.zone  = k.zone AND av.entry  = k.entry
LEFT JOIN cmp.spawn_agg amz ON amz.src = 'mz' AND amz.kind = k.kind AND amz.zone = k.zone AND amz.entry = k.entry
LEFT JOIN cmp.spawn_agg atw ON atw.src = 'tw' AND atw.kind = k.kind AND atw.zone = k.zone AND atw.entry = k.entry
LEFT JOIN cmp.spawn_agg aac ON aac.src = 'ac' AND aac.kind = k.kind AND aac.zone = k.zone AND aac.entry = k.entry
WHERE (amz.resp_min > 0 AND av.resp_min > 0
       AND (av.resp_min / amz.resp_min >= 2 OR amz.resp_min / av.resp_min >= 2))
   OR (aac.resp_min > 0 AND av.resp_min > 0
       AND (av.resp_min / aac.resp_min >= 2 OR aac.resp_min / av.resp_min >= 2));
```

- [ ] **Step 4: Write the failing test**

Add to `test_pipeline.py`:

```python
def test_pilot_zones_produce_findings():
    """Westfall and the Deadmines each produce findings in every topic run."""
    for zone, label in ((40, "Westfall"), (1581, "The Deadmines")):
        rows = corpus_sql(
            "SELECT topic, COUNT(*) FROM cmp.findings WHERE zone=%d "
            "GROUP BY topic" % zone
        )
        got = {r[0]: int(r[1]) for r in rows}
        assert got, "%s produced no findings at all" % label
        print("NOTE %s: %s" % (label, got))
    # A zone where every topic fires on nearly every entity means a broken
    # join, not a broken game.
    rows = corpus_sql(
        "SELECT COUNT(*) FROM cmp.findings WHERE zone=40 AND topic='creatures'"
    )
    assert int(rows[0][0]) < 2000, (
        "Westfall has %s creature findings - suspect a join, not the content"
        % rows[0][0]
    )
    print("PASS test_pilot_zones_produce_findings")
```

Add it to `TESTS`.

- [ ] **Step 5: Run the diffs and the test**

```sh
sh contrib/content-audit/run_diffs.sh
python contrib/content-audit/test_pipeline.py
```

Expected: the runner prints per-topic counts; the test prints the Westfall and Deadmines breakdowns and passes. If Westfall trips the 2000 guard, stop and find the join — a report nobody can read is worse than no report.

- [ ] **Step 6: Commit**

```sh
git add contrib/content-audit/diffs/01_creatures.sql \
        contrib/content-audit/diffs/02_relations.sql \
        contrib/content-audit/diffs/06_spawns.sql \
        contrib/content-audit/test_pipeline.py
git commit -m "Diff creatures, relationships and spawns per zone

A creature belongs to a zone if any source spawns it there, which is what
makes a missing template findable: a creature the live database lacks has
no live spawn to notice its absence by.

Relationship diffs distinguish a source that says no from a source that
cannot say anything. AzerothCore has no creature_linking equivalent, so
it abstains on links rather than appearing to report every link missing.

Spawn comparison is always an aggregate over a zone and an entry. GUIDs
do not survive the trip between databases, so counts and respawn windows
are the only spawn facts that mean the same thing in all four.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Diff queries for quests, rewards and drop rates

**Files:**
- Create: `contrib/content-audit/diffs/03_quests.sql`
- Create: `contrib/content-audit/diffs/04_quest_rewards.sql`
- Create: `contrib/content-audit/diffs/05_quest_item_drops.sql`
- Test: `contrib/content-audit/test_pipeline.py`

**Interfaces:**
- Consumes: `n_quest`, `n_quest_obj`, `n_quest_rew`, `n_rel`, `cmp.n_quest_xp`, `cmp.n_loot_eff`, `cmp.strength`.
- Produces: rows in `cmp.findings` with `topic` in `quests`, `quest_rewards`, `quest_item_drops`.

A quest belongs to a zone by the zone of the creature that starts it, taken from `n_rel` and `cmp.areas`. `ZoneOrSort` is not used: it is a client sort key, negative for class and profession quests, and it disagrees with where the quest is actually obtained often enough to misfile findings.

- [ ] **Step 1: Write the quest diff**

Create `contrib/content-audit/diffs/03_quests.sql`:

```sql
-- Topic 3: quest existence, gating and objectives, per zone.
--
-- A quest is placed by where its giver stands, not by ZoneOrSort. That column
-- is a client sort key - negative for class and profession quests - and it
-- disagrees with the quest's actual location often enough to misfile findings.

CREATE OR REPLACE VIEW cmp.zone_quest AS
SELECT DISTINCT s.zone, r.target AS quest
FROM v.n_rel r
JOIN v.n_spawn s ON s.kind = 'creature' AND s.entry = r.npc
WHERE r.kind = 'questgiver'
UNION
SELECT DISTINCT s.zone, r.target
FROM mz.n_rel r
JOIN mz.n_spawn s ON s.kind = 'creature' AND s.entry = r.npc
WHERE r.kind = 'questgiver';

-- Existence and the fields that gate a quest.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quests', 'quest', zq.quest, fld.field,
       CAST(CASE fld.field WHEN 'exists'    THEN IF(qv.entry IS NULL, NULL, '1')
                           WHEN 'lvl'       THEN qv.lvl
                           WHEN 'min_lvl'   THEN qv.min_lvl
                           WHEN 'req_race'  THEN qv.req_race
                           WHEN 'next'      THEN qv.next END AS CHAR),
       CAST(CASE fld.field WHEN 'exists'    THEN IF(qmz.entry IS NULL, NULL, '1')
                           WHEN 'lvl'       THEN qmz.lvl
                           WHEN 'min_lvl'   THEN qmz.min_lvl
                           WHEN 'req_race'  THEN qmz.req_race
                           WHEN 'next'      THEN qmz.next END AS CHAR),
       CAST(CASE fld.field WHEN 'exists'    THEN IF(qtw.entry IS NULL, NULL, '1')
                           WHEN 'lvl'       THEN qtw.lvl
                           WHEN 'min_lvl'   THEN qtw.min_lvl
                           WHEN 'req_race'  THEN qtw.req_race
                           WHEN 'next'      THEN qtw.next END AS CHAR),
       CAST(CASE fld.field WHEN 'exists'    THEN IF(qac.entry IS NULL, NULL, '1')
                           WHEN 'lvl'       THEN qac.lvl
                           WHEN 'min_lvl'   THEN qac.min_lvl
                           WHEN 'req_race'  THEN qac.req_race
                           WHEN 'next'      THEN qac.next END AS CHAR),
       '', ''
FROM cmp.zone_quest zq
CROSS JOIN (SELECT 'exists' AS field UNION ALL SELECT 'lvl' UNION ALL SELECT 'min_lvl'
            UNION ALL SELECT 'req_race' UNION ALL SELECT 'next') fld
LEFT JOIN v.n_quest  qv  ON qv.entry  = zq.quest
LEFT JOIN mz.n_quest qmz ON qmz.entry = zq.quest
LEFT JOIN tw.n_quest qtw ON qtw.entry = zq.quest
LEFT JOIN ac.n_quest qac ON qac.entry = zq.quest;

-- Set the strength in a second pass: the CASE expressions above are already at
-- the limit of what stays readable inline.
UPDATE cmp.findings
SET strength = cmp.strength(v_value, mz_value, ac_value)
WHERE topic = 'quests' AND strength = '';
DELETE FROM cmp.findings WHERE topic = 'quests' AND strength = '';

-- Objectives: present in one source, absent in another.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quests', 'quest', o.quest,
       CONCAT('obj:', o.kind, ':', o.target),
       ov.cnt, omz.cnt, otw.cnt, oac.cnt,
       cmp.strength(ov.cnt, omz.cnt, oac.cnt),
       'objective count'
FROM cmp.zone_quest zq
JOIN (
    SELECT quest, kind, target FROM v.n_quest_obj
    UNION SELECT quest, kind, target FROM mz.n_quest_obj
    UNION SELECT quest, kind, target FROM ac.n_quest_obj
) o ON o.quest = zq.quest
LEFT JOIN v.n_quest_obj  ov  ON ov.quest  = o.quest AND ov.kind  = o.kind AND ov.target  = o.target
LEFT JOIN mz.n_quest_obj omz ON omz.quest = o.quest AND omz.kind = o.kind AND omz.target = o.target
LEFT JOIN tw.n_quest_obj otw ON otw.quest = o.quest AND otw.kind = o.kind AND otw.target = o.target
LEFT JOIN ac.n_quest_obj oac ON oac.quest = o.quest AND oac.kind = o.kind AND oac.target = o.target
WHERE cmp.strength(ov.cnt, omz.cnt, oac.cnt) <> '';
```

- [ ] **Step 2: Write the reward diff**

Create `contrib/content-audit/diffs/04_quest_rewards.sql`:

```sql
-- Topic 4: quest rewards, including experience.

INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quest_rewards', 'quest', r.quest,
       CONCAT(r.kind, ':', r.id),
       rv.cnt, rmz.cnt, rtw.cnt, rac.cnt,
       cmp.strength(rv.cnt, rmz.cnt, rac.cnt), ''
FROM cmp.zone_quest zq
JOIN (
    SELECT quest, kind, id FROM v.n_quest_rew
    UNION SELECT quest, kind, id FROM mz.n_quest_rew
    UNION SELECT quest, kind, id FROM ac.n_quest_rew
) r ON r.quest = zq.quest
LEFT JOIN v.n_quest_rew  rv  ON rv.quest  = r.quest AND rv.kind  = r.kind AND rv.id  = r.id
LEFT JOIN mz.n_quest_rew rmz ON rmz.quest = r.quest AND rmz.kind = r.kind AND rmz.id = r.id
LEFT JOIN tw.n_quest_rew rtw ON rtw.quest = r.quest AND rtw.kind = r.kind AND rtw.id = r.id
LEFT JOIN ac.n_quest_rew rac ON rac.quest = r.quest AND rac.kind = r.kind AND rac.id = r.id
WHERE cmp.strength(rv.cnt, rmz.cnt, rac.cnt) <> '';

-- Experience. AzerothCore votes on the boolean only, so its figure is passed
-- as NULL: it abstains on the number and cannot strengthen a finding about it.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quest_rewards', 'quest', zq.quest, 'xp',
       ROUND(xv.xp), ROUND(xmz.xp), ROUND(xtw.xp), NULL,
       cmp.strength(ROUND(xv.xp), ROUND(xmz.xp), NULL),
       'AzerothCore abstains on the figure; it votes only on awards_xp'
FROM cmp.zone_quest zq
JOIN      cmp.n_quest_xp xv  ON xv.src  = 'v'  AND xv.quest  = zq.quest
LEFT JOIN cmp.n_quest_xp xmz ON xmz.src = 'mz' AND xmz.quest = zq.quest
LEFT JOIN cmp.n_quest_xp xtw ON xtw.src = 'tw' AND xtw.quest = zq.quest
WHERE xmz.xp IS NOT NULL AND ABS(COALESCE(xv.xp, 0) - xmz.xp) > 1;

-- Whether a quest awards experience at all. Every source can answer this.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quest_rewards', 'quest', zq.quest, 'awards_xp',
       xv.awards_xp, xmz.awards_xp, xtw.awards_xp, xac.awards_xp,
       cmp.strength(xv.awards_xp, xmz.awards_xp, xac.awards_xp), ''
FROM cmp.zone_quest zq
JOIN      cmp.n_quest_xp xv  ON xv.src  = 'v'  AND xv.quest  = zq.quest
LEFT JOIN cmp.n_quest_xp xmz ON xmz.src = 'mz' AND xmz.quest = zq.quest
LEFT JOIN cmp.n_quest_xp xtw ON xtw.src = 'tw' AND xtw.quest = zq.quest
LEFT JOIN cmp.n_quest_xp xac ON xac.src = 'ac' AND xac.quest = zq.quest
WHERE cmp.strength(xv.awards_xp, xmz.awards_xp, xac.awards_xp) <> '';

-- Single-source finding: the stored reward contradicts the vanilla formula
-- applied to the quest's own inputs. No peer is relevant, so the peer columns
-- carry the formula's answer rather than another database's opinion.
INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT zq.zone, 'quest_rewards', 'quest', q.entry, 'xp_self_consistency',
       q.rew_xp, ROUND(cmp.vanilla_quest_xp(q.lvl, q.rew_money_max_level)),
       NULL, NULL, 'strong',
       'stored RewXP disagrees with the vanilla formula on this quest own inputs'
FROM cmp.zone_quest zq
JOIN v.n_quest q ON q.entry = zq.quest
WHERE q.rew_xp > 0 AND q.rew_money_max_level > 0
  AND ABS(q.rew_xp - cmp.vanilla_quest_xp(q.lvl, q.rew_money_max_level)) > 1;
```

- [ ] **Step 3: Write the drop rate diff**

Create `contrib/content-audit/diffs/05_quest_item_drops.sql`:

```sql
-- Topic 5: the effective drop chance of items a quest objective requires.
--
-- Scoped to quest items on purpose. Every other loot difference is noise at
-- this stage; an item a quest demands that drops at a tenth the rate the peers
-- agree on is the defect that stalls a player.

CREATE OR REPLACE VIEW cmp.quest_items AS
SELECT DISTINCT zq.zone, o.quest, o.target AS item
FROM cmp.zone_quest zq
JOIN v.n_quest_obj o ON o.quest = zq.quest AND o.kind = 'item'
UNION
SELECT DISTINCT zq.zone, o.quest, o.target
FROM cmp.zone_quest zq
JOIN mz.n_quest_obj o ON o.quest = zq.quest AND o.kind = 'item';

INSERT INTO cmp.findings
    (zone, topic, entity_kind, entity_id, field, v_value, mz_value, tw_value, ac_value, strength, note)
SELECT qi.zone, 'quest_item_drops', 'item', qi.item,
       CONCAT(src.tbl, ':', src.entry),
       ROUND(lv.p_drop * 100, 2), ROUND(lmz.p_drop * 100, 2),
       ROUND(ltw.p_drop * 100, 2), ROUND(lac.p_drop * 100, 2),
       cmp.strength(ROUND(lv.p_drop * 100, 2), ROUND(lmz.p_drop * 100, 2),
                    ROUND(lac.p_drop * 100, 2)),
       CONCAT('quest ', qi.quest)
FROM cmp.quest_items qi
JOIN (
    SELECT DISTINCT tbl, entry, item FROM cmp.n_loot_eff
) src ON src.item = qi.item
LEFT JOIN cmp.n_loot_eff lv  ON lv.src  = 'v'  AND lv.tbl  = src.tbl AND lv.entry  = src.entry AND lv.item  = qi.item
LEFT JOIN cmp.n_loot_eff lmz ON lmz.src = 'mz' AND lmz.tbl = src.tbl AND lmz.entry = src.entry AND lmz.item = qi.item
LEFT JOIN cmp.n_loot_eff ltw ON ltw.src = 'tw' AND ltw.tbl = src.tbl AND ltw.entry = src.entry AND ltw.item = qi.item
LEFT JOIN cmp.n_loot_eff lac ON lac.src = 'ac' AND lac.tbl = src.tbl AND lac.entry = src.entry AND lac.item = qi.item
-- Tolerance from the spec: a 2x ratio or a 5 point absolute gap.
WHERE (lmz.p_drop IS NOT NULL AND (
          ABS(COALESCE(lv.p_drop,0) - lmz.p_drop) * 100 >= 5
       OR GREATEST(COALESCE(lv.p_drop,0), lmz.p_drop)
          / GREATEST(LEAST(COALESCE(lv.p_drop,0), lmz.p_drop), 0.0001) >= 2))
   OR (lac.p_drop IS NOT NULL AND (
          ABS(COALESCE(lv.p_drop,0) - lac.p_drop) * 100 >= 5
       OR GREATEST(COALESCE(lv.p_drop,0), lac.p_drop)
          / GREATEST(LEAST(COALESCE(lv.p_drop,0), lac.p_drop), 0.0001) >= 2));
```

- [ ] **Step 4: Extend the test**

Add to `test_pipeline.py`:

```python
def test_all_six_topics_fire():
    """Every topic in the spec produces at least one finding somewhere."""
    rows = corpus_sql("SELECT DISTINCT topic FROM cmp.findings")
    got = {r[0] for r in rows}
    expected = {
        "creatures",
        "relations",
        "quests",
        "quest_rewards",
        "quest_item_drops",
        "spawns",
    }
    missing = expected - got
    assert not missing, "no findings at all for: %s" % sorted(missing)
    print("PASS test_all_six_topics_fire")
```

Add it to `TESTS`.

- [ ] **Step 5: Run and verify**

```sh
sh contrib/content-audit/run_diffs.sh
python contrib/content-audit/test_pipeline.py
```

Expected: all tests pass, and the runner prints a per-topic, per-strength breakdown.

A topic producing zero findings is a bug in its query, not a clean bill of health — four databases never agree on everything.

- [ ] **Step 6: Commit**

```sh
git add contrib/content-audit/diffs/03_quests.sql \
        contrib/content-audit/diffs/04_quest_rewards.sql \
        contrib/content-audit/diffs/05_quest_item_drops.sql \
        contrib/content-audit/test_pipeline.py
git commit -m "Diff quests, rewards and quest item drop rates per zone

Quests are placed by where their giver stands rather than by ZoneOrSort.
That column is a client sort key, negative for class and profession
quests, and it disagrees with where a quest is actually picked up often
enough to file findings under the wrong zone.

Drop rates are scoped to items a quest objective demands. Every other
loot difference is noise at this stage, while an item a quest requires
dropping at a tenth the rate the peers agree on is the defect that stalls
a player for an hour.

Experience carries three separate findings: the figure, which AzerothCore
abstains from, the boolean, which every source can answer, and the
disagreement between a stored reward and the vanilla formula applied to
the quest's own inputs, which needs no peer at all.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: Report generator

**Files:**
- Create: `contrib/content-audit/report.py`
- Test: `contrib/content-audit/test_pipeline.py`

**Interfaces:**
- Consumes: `cmp.findings`, `cmp.areas`, `dbc.area_table`.
- Produces: `<REPORT_DIR>/<zone id>-<zone name>.md`, one per zone id given on the command line.

- [ ] **Step 1: Write the failing test**

Add to `test_pipeline.py`:

```python
def test_report_renders_for_pilot_zones():
    """report.py writes a readable file per zone with every section present."""
    subprocess.run(
        [sys.executable, os.path.join(HERE, "report.py"), "40", "1581"], check=True
    )
    repo_root = os.path.abspath(os.path.join(HERE, "..", ".."))
    report_dir = os.path.join(repo_root, CFG["REPORT_DIR"])
    written = [f for f in os.listdir(report_dir) if f.endswith(".md")]
    assert any(f.startswith("40-") for f in written), "no Westfall report"
    assert any(f.startswith("1581-") for f in written), "no Deadmines report"

    path = os.path.join(report_dir, [f for f in written if f.startswith("40-")][0])
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    for heading in (
        "## 1. Creatures",
        "## 2. Connected creatures",
        "## 3. Quests",
        "## 4. Quest rewards",
        "## 5. Quest item drop rates",
        "## 6. Spawn rates and counts",
        "## Appendix A",
        "## Appendix B",
        "## Appendix C",
        "## Comparability notes",
    ):
        assert heading in text, "report is missing %r" % heading
    print("PASS test_report_renders_for_pilot_zones")
```

Add it to `TESTS`.

- [ ] **Step 2: Run it to verify it fails**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: FAIL — `report.py` does not exist.

- [ ] **Step 3: Write the generator**

Create `contrib/content-audit/report.py`:

```python
#!/usr/bin/env python3
"""Render cmp.findings into one Markdown report per zone.

Usage:  python report.py <zone id> [<zone id> ...]

Reads config.env for connection details and the output directory. Standard
library only - the MySQL client does the talking.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

TOPICS = [
    ("creatures", "1. Creatures"),
    ("relations", "2. Connected creatures"),
    ("quests", "3. Quests"),
    ("quest_rewards", "4. Quest rewards"),
    ("quest_item_drops", "5. Quest item drop rates"),
    ("spawns", "6. Spawn rates and counts"),
]

COMPARABILITY = """\
- AzerothCore does not vote on quest experience figures, only on whether a
  quest awards experience at all. Its own figure indexes a DBC that is not
  available here and carries WotLK rebalancing regardless.
- AzerothCore's health vote is advisory and counts only where mangoszero
  agrees with it, because WotLK inflated creature health as a matter of
  policy rather than per creature.
- tortoise-wow is a fork of the database under audit. It never strengthens a
  finding; it appears only where it disagrees, as context.
- A blank cell means the source cannot express the field at all. That is an
  abstention, not a claim that the value is missing.
"""


def load_config():
    path = os.path.join(HERE, "config.env")
    cfg = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                cfg[key.strip()] = value.strip()
    return cfg


CFG = load_config()


def query(statement):
    cmd = [
        os.path.join(CFG["MYSQL_BIN_DIR"], "mysql"),
        "--host=" + CFG["CORPUS_HOST"],
        "--port=" + CFG["CORPUS_PORT"],
        "-uroot",
        "--batch",
        "--skip-column-names",
        "--execute=" + statement,
    ]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    return [line.split("\t") for line in out.splitlines()]


def cell(value):
    """NULL from the client means the source abstained; show it as blank."""
    return "" if value in ("NULL", None) else value


def zone_name(zone):
    rows = query(
        "SELECT name FROM dbc.area_table WHERE id = %d" % zone
    )
    return rows[0][0] if rows else "zone-%d" % zone


def findings_table(zone, topic):
    rows = query(
        "SELECT entity_kind, entity_id, field, v_value, mz_value, tw_value, "
        "ac_value, strength, note FROM cmp.findings "
        "WHERE zone=%d AND topic='%s' "
        "ORDER BY FIELD(strength,'strong','weak'), entity_id, field" % (zone, topic)
    )
    if not rows:
        return "No findings.\n"
    out = [
        "| Entity | Id | Field | live | mangoszero | tortoise | azerothcore | Strength | Note |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        out.append("| " + " | ".join(cell(c) for c in r) + " |")
    return "\n".join(out) + "\n"


def appendix(zone, title, statement):
    rows = query(statement)
    body = "None.\n"
    if rows:
        body = "\n".join("- " + " ".join(cell(c) for c in r) for r in rows) + "\n"
    return "## %s\n\n%s\n" % (title, body)


def render(zone):
    name = zone_name(zone)
    counts = query(
        "SELECT strength, COUNT(*) FROM cmp.findings WHERE zone=%d "
        "GROUP BY strength" % zone
    )
    summary = ", ".join("%s %s" % (c[1], c[0]) for c in counts) or "no findings"

    parts = ["# %s (%d)\n" % (name, zone), "%s\n" % summary]
    for topic, heading in TOPICS:
        parts.append("## %s\n\n%s" % (heading, findings_table(zone, topic)))

    parts.append(
        appendix(
            zone,
            "Appendix A - AzerothCore-only entities (probable post-vanilla)",
            "SELECT DISTINCT a.entry, c.name FROM ac.n_spawn a "
            "JOIN ac.n_creature c ON c.entry = a.entry "
            "LEFT JOIN v.n_creature cv ON cv.entry = a.entry "
            "LEFT JOIN mz.n_creature cm ON cm.entry = a.entry "
            "WHERE a.zone = %d AND cv.entry IS NULL AND cm.entry IS NULL "
            "LIMIT 200" % zone,
        )
    )
    parts.append(
        appendix(
            zone,
            "Appendix B - tortoise-only entities (probable classic-plus custom)",
            "SELECT DISTINCT t.entry, c.name FROM tw.n_spawn t "
            "JOIN tw.n_creature c ON c.entry = t.entry "
            "LEFT JOIN v.n_creature cv ON cv.entry = t.entry "
            "LEFT JOIN mz.n_creature cm ON cm.entry = t.entry "
            "WHERE t.zone = %d AND cv.entry IS NULL AND cm.entry IS NULL "
            "LIMIT 200" % zone,
        )
    )
    parts.append(
        appendix(
            zone,
            "Appendix C - unresolved spawns",
            "SELECT src, kind, COUNT(*) FROM cmp.areas WHERE zone = 0 "
            "GROUP BY src, kind",
        )
    )
    parts.append("## Comparability notes\n\n" + COMPARABILITY)
    return "\n".join(parts)


def main(argv):
    if not argv:
        sys.exit("usage: report.py <zone id> [<zone id> ...]")
    out_dir = os.path.join(REPO, CFG["REPORT_DIR"])
    os.makedirs(out_dir, exist_ok=True)
    for arg in argv:
        zone = int(arg)
        name = zone_name(zone).replace(" ", "-").replace("'", "")
        path = os.path.join(out_dir, "%d-%s.md" % (zone, name))
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(render(zone))
        print("wrote %s" % path)


if __name__ == "__main__":
    main(sys.argv[1:])
```

- [ ] **Step 4: Run the test to verify it passes**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: `PASS test_report_renders_for_pilot_zones`.

- [ ] **Step 5: Read a report end to end**

```sh
less doc/local/content-audit/40-Westfall.md
```

This is the deliverable. If it cannot be read start to finish in a sitting, the tolerances are too loose — note which topic floods it and fix that in Task 12, not here.

- [ ] **Step 6: Commit**

```sh
git add contrib/content-audit/report.py contrib/content-audit/test_pipeline.py
git commit -m "Render per-zone discrepancy reports

One Markdown file per zone: the six topics in the order the audit asks
them, then the two appendices for entities only one source has, then the
unresolved spawns, then the comparability notes.

A blank cell means the source cannot express that field. Distinguishing
it from a zero matters in every row: a source that has no table for a
relationship is abstaining, and reading that as 'missing' would turn a
schema difference into a content defect.

Reports go to the gitignored local documentation directory. They are
generated artifacts and regenerating a zone is cheap, so committing forty
of them would add churn and no information.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 12: Pilot review, tolerance tuning, and removing the temporary core changes

**Files:**
- Modify: `contrib/content-audit/diffs/*.sql` (tolerances only)
- Modify: `contrib/content-audit/README.md`
- Delete: `src/game/Maps/AreaResolverDump.h`, `src/game/Maps/AreaResolverDump.cpp`
- Modify: `src/game/CMakeLists.txt`, `src/game/World.cpp`, `src/mangosd/mangosd.conf.dist.in`

**Interfaces:**
- Consumes: everything.
- Produces: two reviewed reports, tuned tolerances, and a tree with no temporary core changes left in it.

- [ ] **Step 1: Read both reports fully**

```sh
wc -l doc/local/content-audit/*.md
```

For each topic, judge twenty findings by hand against the live database and record how many are real. A topic where fewer than half are real has a tolerance problem or a join problem; decide which before touching a number.

- [ ] **Step 2: Record the false positive rate in the README**

Append to `contrib/content-audit/README.md`:

```markdown
## Pilot results (Westfall and The Deadmines)

Measured by hand-checking twenty findings per topic against the live database.

| Topic | Findings | Sampled | Real | Notes |
|---|---|---|---|---|
| Creatures | | | | |
| Connected creatures | | | | |
| Quests | | | | |
| Quest rewards | | | | |
| Quest item drop rates | | | | |
| Spawn rates | | | | |

The quest topic was expected to be the noisiest: AzerothCore's `exp` column
filters post-vanilla creatures cleanly, but quests have no equivalent marker
and many were revamped between 1.12 and 3.3.5.
```

Fill the table in from step 1. This table is what SP2 is planned against, so an empty row here is a plan written on a guess.

- [ ] **Step 3: Adjust tolerances and re-run**

Change only the numbers in the `WHERE` clauses of the diff files, then:

```sh
sh contrib/content-audit/run_diffs.sh
python contrib/content-audit/report.py 40 1581
```

Re-sample. Stop when a topic is majority-real or when it is clear that no tolerance fixes it, in which case note that in the README rather than tuning until the topic is empty. An empty topic reports nothing and hides everything.

- [ ] **Step 4: Remove the temporary core changes**

The corpus is built and `cmp.areas` is populated, so the resolver has done its job.

```sh
git rm src/game/Maps/AreaResolverDump.h src/game/Maps/AreaResolverDump.cpp
```

Remove the two `Maps/AreaResolverDump.*` lines from `src/game/CMakeLists.txt`; remove the `#include "AreaResolverDump.h"` line and the whole guarded block after `LoadDBCStores(dbcPath);` from `src/game/World.cpp`; remove the two `ContentAudit.*` entries and their comment block from `src/mangosd/mangosd.conf.dist.in`.

Leave `run_resolver.sh` in place and add a note at its head:

```sh
# NOTE: this needs the ContentAudit.ResolveAreasFile hook, which is removed from
# the core once a corpus has been built. Re-apply the commit that added
# src/game/Maps/AreaResolverDump.cpp before rebuilding the areas table.
```

- [ ] **Step 5: Verify the core still builds without it**

```sh
MSBuild.exe cmake-build-playerbots/ALL_BUILD.vcxproj "/m:16" "/p:CL_MPCount=16" "/p:Configuration=RelWithDebInfo"
```

Expected: builds clean. A linker error naming `ResolveAreasFromFile` means the `World.cpp` call survived the deletion.

- [ ] **Step 6: Run the full check suite one last time**

```sh
python contrib/content-audit/test_pipeline.py
```

Expected: every test passes except `test_resolver_assigns_known_zones`, which now fails because the hook is gone. Mark it skipped rather than deleting it — it is the check to re-enable when the areas table is next rebuilt:

```python
def test_resolver_assigns_known_zones():
    print("SKIP test_resolver_assigns_known_zones - core hook removed after corpus build")
    return
```

- [ ] **Step 7: Commit and merge**

```sh
git add -A contrib/content-audit/ src/game/CMakeLists.txt src/game/World.cpp \
           src/mangosd/mangosd.conf.dist.in
git commit -m "Tune audit tolerances from the pilot and remove the core hook

The pilot's purpose was to find out how many findings are real before
committing to a sweep of every zone. The measured rates are recorded in
the tooling README and are what the next sub-project should be planned
against.

Tolerances were adjusted where a topic was majority noise. Where no
tolerance separated signal from noise, that is recorded rather than tuned
around: a topic tuned until it is empty reports nothing and hides
everything.

The area resolver and its config key are removed now that the corpus
exists. The script that drove them stays, with a note naming the commit
to re-apply when the areas table next needs rebuilding.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"

git checkout development
git merge --no-ff feature/content-audit-pipeline
git push origin development
git branch -d feature/content-audit-pipeline
```

---

## Self-Review

**Spec coverage.** Every section of the spec maps to a task: sources and corpus to Task 1; the area resolver and both its accepted limits to Tasks 2 and 3; the seven base shapes to Task 4 and the three derived ones to Tasks 5, 6 and 7; the consensus rule and the findings table to Task 8; the six topics to Tasks 9 and 10; the report layout, both appendices and the comparability notes to Task 11; tolerance tuning and the temporary-change removal to Task 12. The five spec assertions appear as tests in Tasks 2, 4, 6, 7 and 8, with the loot check written before its query as the spec requires.

**Known soft spots, called out rather than hidden.**

- Task 4 step 8 is an iteration loop rather than a fixed edit. Four schemas cannot be normalised from column lists alone; the test tells the implementer exactly which column is wrong on each pass, which is the best a plan can do here.
- Task 6 step 1 requires reading the sub-61 branch of `Quest::XPValue` out of the mangoszero core. The ladder above 61 is transcribed; the branch below it is not, because guessing a divisor would silently shift every low-level quest, and every quest in the pilot zones is below 61.
- Task 5 step 3 checks which health source mangoszero actually uses before writing the view. The `COALESCE` given is correct under either answer, so the check confirms rather than unblocks.

**Type consistency.** `cmp.strength(v, mz, ac)` takes and returns `VARCHAR` everywhere; every diff passes `CAST(... AS CHAR)` or `ROUND(...)` values. `cmp.n_loot_eff` columns `(src, tbl, entry, item, quest_only, p_drop)` match the `SELECT` in `loot_eff_body.sql` and the joins in Task 10. `cmp.areas` columns match `load_areas.sh`, every `n_spawn` view and the Appendix C query. `n_creature` carries `unit_class` and `hp_mult` because Task 5 joins on them; `n_quest` carries `rew_money_max_level` and `rew_xp` because Task 6 does.
