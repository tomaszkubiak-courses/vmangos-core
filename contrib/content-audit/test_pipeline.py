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


TESTS = [test_corpus_schemas_present, test_dbc_schema_present, test_realm_schemas_present]

if __name__ == "__main__":
    failures = 0
    for test in TESTS:
        try:
            test()
        except Exception as exc:  # noqa: BLE001 - a check runner wants every failure
            failures += 1
            print("FAIL %s: %s" % (test.__name__, exc))
    sys.exit(1 if failures else 0)
