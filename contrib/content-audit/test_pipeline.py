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
    # Floors are sanity guards against an empty or half-applied import, not
    # spec values. mz is lower because mangoszero-database's creature_template
    # genuinely has ~9.1k rows (verified against the source SQL directly, not
    # just trusted from a clean import) - it is a leaner content set than the
    # other three sources, not a truncated one.
    expected = {"v": 10000, "mz": 8000, "tw": 10000, "ac": 20000}
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


def test_dbc_schema_present():
    """The dbc snapshot exists and area_table is populated (later tasks join it for zone names)."""
    rows = corpus_sql(
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='dbc'"
    )
    assert int(rows[0][0]) > 10, "dbc has only %s tables" % rows[0][0]
    rows = corpus_sql("SELECT COUNT(*) FROM dbc.area_table")
    count = int(rows[0][0])
    assert count > 1000, "dbc.area_table has %d rows, expected > 1000" % count
    print("PASS test_dbc_schema_present")


def test_realm_schemas_present():
    """characters/realmd/logs exist with real tables (so a scratch core can boot
    against the corpus). They went through the same snapshot() path as v/dbc and
    were the ones that actually imported empty the first time this broke, so this
    checks them directly rather than trusting a general "did snapshot() work" test."""
    # Floors are a sanity guard, not a spec value: actual counts observed on a
    # correct import were characters=69, realmd=13, logs=10.
    expected = {"characters": 5, "realmd": 5, "logs": 5}
    for schema, floor in expected.items():
        rows = corpus_sql(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema='%s'" % schema
        )
        count = int(rows[0][0])
        assert count > floor, "%s has only %d tables, expected > %d" % (
            schema,
            count,
            floor,
        )
    print("PASS test_realm_schemas_present")


# Known-good fixtures: (map, x, y, z, expected_zone_id, label)
# Hogger's coordinate was corrected 2026-09-16: the brief's original value
# (0, -10496.0, 1036.0, 32.0) is Gryan Stoutmantle's real spawn in Sentinel
# Hill (creature.id=234 in the corpus v schema), not Hogger's - it resolved
# to zone 40 (Westfall) instead of 12. Replaced with Hogger's own real spawn
# (creature.id=448), verified against `SELECT map, position_x, position_y,
# position_z FROM creature WHERE id=448` on the corpus. The other two
# fixtures were checked the same way and left as given: both resolve to
# their expected zones.
RESOLVER_FIXTURES = [
    (0, -9946.0, 604.266, 38.2862, 12, "Hogger spawn, Elwynn Forest"),
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


TESTS = [
    test_corpus_schemas_present,
    test_dbc_schema_present,
    test_realm_schemas_present,
    test_resolver_assigns_known_zones,
    test_areas_table_populated_and_named,
]

if __name__ == "__main__":
    failures = 0
    for test in TESTS:
        try:
            test()
        except Exception as exc:  # noqa: BLE001 - a check runner wants every failure
            failures += 1
            print("FAIL %s: %s" % (test.__name__, exc))
    sys.exit(1 if failures else 0)
