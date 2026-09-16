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
    """Every source exposes every view, with the same columns, same types, non-empty.

    Column *names* alone are not the whole contract: fix round 1 found three
    columns (tw.n_creature.hp_mult, mz/ac.n_quest.rew_xp) that were bare
    `NULL` literals reporting as `varbinary` - a type that would silently
    break a numeric CAST or aggregate in Tasks 5/6 - and a dozen more where
    names lined up but widths did not (ac's id-ish columns are `int` where
    the others are `mediumint`, mz's n_spawn.map is `int` where the others
    are narrower, ac's n_loot numerics were narrower still). Comparing only
    column_name, as this test originally did, missed all of it. Comparing
    data_type here would have caught every one of them.
    """
    shapes = {}
    types = {}
    for view in NORMALISED_VIEWS:
        for src in ("v", "mz", "tw", "ac"):
            cols = corpus_sql(
                "SELECT column_name, data_type FROM information_schema.columns "
                "WHERE table_schema='%s' AND table_name='%s' "
                "ORDER BY ordinal_position" % (src, view)
            )
            names = tuple(c[0] for c in cols)
            data_types = tuple(c[1] for c in cols)
            assert names, "%s.%s does not exist" % (src, view)
            shapes.setdefault(view, {})[src] = names
            types.setdefault(view, {})[src] = data_types

            rows = corpus_sql("SELECT COUNT(*) FROM %s.%s" % (src, view))
            assert int(rows[0][0]) > 0, "%s.%s is empty" % (src, view)

        distinct = set(shapes[view].values())
        assert len(distinct) == 1, "%s has differing shapes: %s" % (view, shapes[view])

        distinct_types = set(types[view].values())
        assert len(distinct_types) == 1, "%s has differing column types: %s" % (
            view,
            types[view],
        )
    print("PASS test_normalised_views_exist_and_agree_on_shape")


def test_known_westfall_quest_matches_across_vanilla_sources():
    """Quest 5-1 'Red Linen Goods' has the same objective shape in v and mz.

    The brief warned this fixture might disagree once patch/id-pool were
    fixed and said to swap in another Westfall quest if so - it does not:
    once n_quest_obj reads the patch-picked quest row (see v.sql), quest 9
    agrees between v and mz (npc 114 x20 in both). Kept as the fixture.
    """
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


def test_effective_health_respects_mz_armor_multiplier_gate():
    """mz must use the absolute health columns when ArmorMultiplier <= 0.

    Fix round 1: an earlier version of the mz branch fell back to the
    absolute MinLevelHealth/MaxLevelHealth columns only when no
    classlevelstats row matched - it never checked ArmorMultiplier at all.
    On this corpus a classlevelstats row matches for every one of the 13
    ArmorMultiplier <= 0 rows, so the view was silently taking the
    classlevelstats path for all of them (up to 119x off). Every other test
    in this file passed while that was true, because none of them targeted
    an ArmorMultiplier <= 0 creature. This one does: entry 15729 has
    ArmorMultiplier -1 and stored MinLevelHealth = MaxLevelHealth = 5000,
    and a classlevelstats row that, if wrongly preferred, would have
    returned something else entirely.
    """
    entry = 15729
    rows = corpus_sql(
        "SELECT lvl, hp FROM cmp.n_creature_hp WHERE src='mz' AND entry=%d" % entry
    )
    assert rows, "no mz health row for entry %d" % entry
    for _lvl, hp in rows:
        assert float(hp) == 5000.0, (
            "entry %d (ArmorMultiplier <= 0) should read the absolute "
            "MinLevelHealth/MaxLevelHealth column (5000), got %s - "
            "the ArmorMultiplier gate is not being checked" % (entry, hp)
        )
    print("PASS test_effective_health_respects_mz_armor_multiplier_gate")


def test_effective_health_ac_uses_expansion_tier():
    """ac must select basehp0/1/2 by creature_template.exp, not always basehp0.

    Fix round 1: the ac branch hardcoded basehp0 (the classic tier), so the
    13883/29947 ac creatures with exp=1 or exp=2 (TBC/WotLK) silently got
    classic-tier base health. Entry 89 is exp=2 at level 70; its basehp0/
    basehp1/basehp2 are 4050/6986/8982 - if the view read the wrong tier,
    this assertion would catch it directly instead of only noticing a
    disagreement against another source.
    """
    rows = corpus_sql(
        "SELECT exp FROM ac.creature_template WHERE entry=89"
    )
    assert rows and rows[0][0] == "2", "fixture creature 89 is no longer exp=2"
    hp_rows = corpus_sql(
        "SELECT lvl, hp FROM cmp.n_creature_hp WHERE src='ac' AND entry=89 AND lvl=70"
    )
    assert hp_rows, "no ac level-70 health row for entry 89"
    hp = float(hp_rows[0][1])
    # basehp0 (classic) * HealthModifier would give a much smaller figure;
    # basehp2 (WotLK) * HealthModifier is what SelectLevel actually reads.
    assert hp > 10000, "entry 89 at level 70 gives hp %.1f - looks like the classic-tier basehp0 was used instead of exp=2's basehp2" % hp
    print("PASS test_effective_health_ac_uses_expansion_tier")


def test_effective_health_has_no_duplicate_rows():
    """cmp.n_creature_hp promises one row per (src, entry, lvl).

    tw and mz store two absolute health values per creature (min/max level)
    rather than one row per level; 288 tw rows and 68 mz rows have
    level_min == level_max with the two values genuinely different, which
    would emit two conflicting rows for the same key if the view unioned one
    branch per endpoint. The view instead starts from the distinct set of
    levels per entry, so the collapse happens before the health lookup - this
    checks that held across the whole corpus, not just the sampled rows
    above.
    """
    rows = corpus_sql(
        "SELECT src, entry, lvl, COUNT(*) FROM cmp.n_creature_hp "
        "GROUP BY src, entry, lvl HAVING COUNT(*) > 1 LIMIT 5"
    )
    assert not rows, "duplicate (src, entry, lvl) rows in cmp.n_creature_hp: %s" % rows
    print("PASS test_effective_health_has_no_duplicate_rows")


TESTS = [
    test_corpus_schemas_present,
    test_dbc_schema_present,
    test_realm_schemas_present,
    test_resolver_assigns_known_zones,
    test_areas_table_populated_and_named,
    test_normalised_views_exist_and_agree_on_shape,
    test_known_westfall_quest_matches_across_vanilla_sources,
    test_effective_health_resolves_for_every_source,
    test_effective_health_respects_mz_armor_multiplier_gate,
    test_effective_health_ac_uses_expansion_tier,
    test_effective_health_has_no_duplicate_rows,
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
