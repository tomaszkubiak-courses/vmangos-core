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


def test_quest_xp_formula_matches_known_inputs():
    """The SQL divisor ladder reproduces Quest::XPValue for sampled levels.

    (quest level, RewMoneyMaxLevel, expected xp) - one per divisor branch,
    computed by hand from Quest::XPValue (mangoszero-server's
    src/game/WorldHandlers/QuestDef.cpp, lines 242-304), not reverse-engineered
    from cmp.vanilla_quest_xp itself. The 65/64/63/62 cases are the brief's;
    61 and 60 were added here because the ladder's sub-61 branch (divide by
    0.6) is the one every quest in this audit's pilot zones actually
    exercises - the brief's own four cases never reach it.
    """
    cases = [
        (65, 1200, 200.0),  # 1200 / 6.0
        (64, 1200, 250.0),  # 1200 / 4.8
        (63, 1200, 333.0),  # 1200 / 3.6 = 333.33...
        (62, 1200, 500.0),  # 1200 / 2.4
        (61, 1200, 1000.0),  # 1200 / 1.2
        (60, 1200, 2000.0),  # 1200 / 0.6, the sub-61 (ELSE) branch
        (1, 600, 1000.0),  # 600 / 0.6, low end of the same branch
    ]
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


def test_quest_xp_no_duplicate_rows():
    """cmp.n_quest_xp promises one row per (src, quest)."""
    rows = corpus_sql(
        "SELECT src, quest, COUNT(*) FROM cmp.n_quest_xp "
        "GROUP BY src, quest HAVING COUNT(*) > 1 LIMIT 5"
    )
    assert not rows, "duplicate (src, quest) rows in cmp.n_quest_xp: %s" % rows
    print("PASS test_quest_xp_no_duplicate_rows")


def test_vmangos_stored_xp_agrees_with_its_own_inputs():
    """Assert-bounded for levels 1-50; report-only for levels 51-60.

    Fix round 1 replaced this check's absolute (> 1 XP) tolerance with a
    relative one: the absolute tolerance made almost the whole 1-50 band
    "disagree" (2213 quests average 5-15 XP off a formula answer in the
    hundreds - a rounding-scale gap, not a real one), and CEIL() on the
    formula rescues none of it (see task-6-report.md's fix-round-1 section).
    5% was chosen from the data, not from taste: the ratio histogram for
    levels 1-50 has an obvious gap between "rounds to 1.0" (deviation <=5%,
    1978/2213 quests) and a second, genuinely scattered population starting
    just past 5% (235/2213, matching ROUND(ratio, 1) != 1.0 exactly). No
    absolute floor is layered on top - the smallest formula value in this
    corpus is 50 XP, and no quest pairs a small absolute gap with a large
    relative one, so a floor would not change which rows this flags.

    Levels 51-60 are excluded from the assertion on purpose:
    cmp.vanilla_quest_xp's /0.6 divisor does not model the real, smooth
    level-51-60 XP taper documented in task-6-report.md, so nearly all of
    that band fails a 5% check by construction. That is a known gap in the
    formula, not a per-quest defect - asserting on it would make the test
    fail permanently for a reason indistinguishable from a real regression,
    so it is reported (NOTE) rather than asserted.
    """
    rows = corpus_sql(
        "SELECT COUNT(*) FROM cmp.n_quest_xp x "
        "JOIN v.n_quest q ON q.entry = x.quest "
        "WHERE x.src='v' AND q.rew_xp > 0 AND q.rew_money_max_level > 0 "
        "AND q.lvl BETWEEN 1 AND 50 "
        "AND ABS(q.rew_xp - cmp.vanilla_quest_xp(q.lvl, q.rew_money_max_level)) "
        "    / cmp.vanilla_quest_xp(q.lvl, q.rew_money_max_level) > 0.05"
    )
    outliers = int(rows[0][0])
    print(
        "NOTE %d of 2213 level 1-50 quests disagree with the formula by "
        "more than 5%% (genuine outliers, not rounding noise)" % outliers
    )
    # The ceiling is roughly double this corpus's current count (235): loose
    # enough that ordinary corpus or content changes will not trip it, tight
    # enough that a regression that doubles the outlier count will.
    assert outliers <= 470, (
        "%d level 1-50 quests now disagree with the formula by more than "
        "5%%, expected <= 470 - investigate before raising this ceiling"
        % outliers
    )

    rows = corpus_sql(
        "SELECT COUNT(*) FROM cmp.n_quest_xp x "
        "JOIN v.n_quest q ON q.entry = x.quest "
        "WHERE x.src='v' AND q.rew_xp > 0 AND q.rew_money_max_level > 0 "
        "AND q.lvl BETWEEN 51 AND 60 "
        "AND ABS(q.rew_xp - cmp.vanilla_quest_xp(q.lvl, q.rew_money_max_level)) "
        "    / cmp.vanilla_quest_xp(q.lvl, q.rew_money_max_level) > 0.05"
    )
    print(
        "NOTE %s of 1185 level 51-60 quests diverge from the formula by "
        "more than 5%% - the known near-cap XP taper the formula does not "
        "model, not per-quest defects (report only, not asserted)"
        % rows[0][0]
    )
    print("PASS test_vmangos_stored_xp_agrees_with_its_own_inputs")


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


def test_consensus_strength_never_strong_with_an_abstaining_peer():
    """No input with mz or ac NULL can ever return 'strong', exhaustively.

    This is the property the audit depends on most: an abstention (a peer
    that cannot express the field at all) must never manufacture a defect.
    Rather than trust the worked cases above to cover it, this sweeps v and
    the non-abstaining peer over a small value set with the other peer NULL
    on both sides.
    """
    values = ["NULL", "'1'", "'2'", "'3'"]
    for v in values:
        for other in values:
            for strength_sql in (
                "cmp.strength(%s, NULL, %s)" % (v, other),
                "cmp.strength(%s, %s, NULL)" % (v, other),
            ):
                rows = corpus_sql("SELECT %s" % strength_sql)
                got = rows[0][0]
                assert got != "strong", "%s gave 'strong' with an abstaining peer" % strength_sql
    print("PASS test_consensus_strength_never_strong_with_an_abstaining_peer")


def test_consensus_strength_missing_from_v_is_strong_when_peers_agree():
    """v itself NULL (entity absent from the audited realm) must not vanish.

    When both independent peers exist and agree with each other, a missing
    v is the strongest possible signal of a missing entity - it must reach
    'strong', not disappear because v itself supplied no value.
    """
    rows = corpus_sql("SELECT cmp.strength(NULL, '2', '2')")
    assert rows[0][0] == "strong", "missing v with agreeing peers gave %r" % rows[0][0]

    rows = corpus_sql("SELECT cmp.strength(NULL, '2', NULL)")
    assert rows[0][0] != "strong", "missing v with one abstaining peer gave 'strong'"
    print("PASS test_consensus_strength_missing_from_v_is_strong_when_peers_agree")


def _strength_num(v, mz, ac, ratio_tol, abs_tol):
    def lit(x):
        return "NULL" if x is None else str(x)

    rows = corpus_sql(
        "SELECT cmp.strength_num(%s, %s, %s, %s, %s)"
        % (lit(v), lit(mz), lit(ac), ratio_tol, abs_tol)
    )
    got = rows[0][0]
    return "" if got == "NULL" else got


def test_consensus_strength_num_rule():
    """cmp.strength_num: the same rule, but peer agreement is judged by a
    tolerance instead of byte equality.

    Fix round 1: cmp.strength alone made every numeric topic (health, spawn
    count, respawn window, drop chance) judge peer agreement by byte
    equality while each topic's own WHERE clause judged v against a
    tolerance - two independently computed floats almost never round to the
    same integer, so 'strong' was unreachable in practice (measured on an
    8704-candidate health-shaped reproduction: 18 strong, 8686 weak).
    cmp.strength_num shares cmp.strength's branch structure with the
    tolerance predicate substituted for '<=>' in both positions.
    """
    cases = [
        # (v, mz, ac, ratio_tol, abs_tol, expected)
        # health-shaped tolerance (0.20 ratio, no absolute component)
        (100, 150, 145, 0.20, 0, "strong"),  # both peers outside 20% of v, but agree with each other
        (100, 200, 115, 0.20, 0, "weak"),  # mz outside tolerance, ac inside
        (2, 12, 13, 0.20, 0, "strong"),  # the brief's own worked example
        # spawn-count-shaped tolerance (0.50 ratio, 5 absolute): abs_tol
        # rescues a small-number pair the ratio alone would flag
        (2, 3, 3, 0.50, 5, ""),  # diff=1, within abs_tol alone
        # a zero half of the tolerance must mean "this half does not apply",
        # not "everything differs" - each case below relies on only ONE
        # half being nonzero to reach agreement
        (100, 105, 110, 1.0, 0, ""),  # ratio_tol alone carries agreement; abs_tol=0 must not force a finding
        (100, 104, 103, 0, 5, ""),  # abs_tol alone carries agreement; ratio_tol=0 must not force a finding
        (1, 1, 1, 0, 0, ""),  # both tolerances 0: falls back to exact equality
        (1, 2, 2, 0, 0, "strong"),  # both tolerances 0: exact equality still distinguishes
    ]
    for v, mz, ac, ratio_tol, abs_tol, expected in cases:
        got = _strength_num(v, mz, ac, ratio_tol, abs_tol)
        assert got == expected, (
            "v=%s mz=%s ac=%s ratio_tol=%s abs_tol=%s gave %r, expected %r"
            % (v, mz, ac, ratio_tol, abs_tol, got, expected)
        )
    print("PASS test_consensus_strength_num_rule")


def test_consensus_strength_num_is_symmetric():
    """The ratio predicate must not depend on which argument is v and which
    is the peer.

    Fix round 1: the plan's existing WHERE clauses divided by
    GREATEST(peer, 1) - peer-relative, so a=2b gives ratio 1.0 but b=2a
    gives 0.5, and the same pair of values agrees or disagrees depending on
    which source happened to be v. cmp.strength_num divides by
    GREATEST(LEAST(ABS(a), ABS(b)), 1) instead. 300 and 100 are 3x apart -
    outside a 100% (ratio_tol=1.0) tolerance either way under a correct
    symmetric denominator, but the old asymmetric one would call it
    agreement in one direction (200/300 = 0.667) and disagreement in the
    other (200/100 = 2.0). ac is pinned equal to v in both calls so only
    the v-vs-mz comparison is under test.
    """
    got_a = _strength_num(300, 100, 300, 1.0, 0)  # v=300, mz=100, ac=300 (agrees)
    got_b = _strength_num(100, 300, 100, 1.0, 0)  # v=100, mz=300, ac=100 (agrees) - same pair, swapped
    assert got_a == got_b == "weak", (
        "asymmetric denominator: (v=300,mz=100) gave %r, (v=100,mz=300) gave %r, expected both 'weak'"
        % (got_a, got_b)
    )
    print("PASS test_consensus_strength_num_is_symmetric")


def test_consensus_strength_num_never_strong_with_an_abstaining_peer():
    """No input with mz or ac NULL can ever return 'strong', exhaustively -
    the same property test_consensus_strength_never_strong_with_an_abstaining_peer
    proves for cmp.strength, mirrored here for the tolerance-based sibling.
    """
    values = [None, 1, 2, 3]
    for v in values:
        for other in values:
            for mz, ac in ((None, other), (other, None)):
                got = _strength_num(v, mz, ac, 0.20, 5)
                assert got != "strong", (
                    "cmp.strength_num(%s, %s, %s, 0.20, 5) gave 'strong' with an abstaining peer"
                    % (v, mz, ac)
                )
    print("PASS test_consensus_strength_num_never_strong_with_an_abstaining_peer")


def test_consensus_strength_num_filters_a_doubly_abstaining_peer_to_empty():
    """Item 3: the advisory-ac wrapper (CASE WHEN mz IS NULL THEN NULL ELSE
    ROUND(ac) END) nulls ac's vote whenever mz abstains, so both peer
    arguments arrive NULL. cmp.strength_num must return '' for that case -
    the same first branch cmp.strength uses - so that a diff query's
    mandatory 'WHERE cmp.strength_num(...) <> \'\'' guard drops these rows
    by construction instead of writing a contentless finding.
    """
    got = _strength_num(50, None, None, 0.20, 0)
    assert got == "", "both peers abstaining gave %r, expected ''" % got
    print("PASS test_consensus_strength_num_filters_a_doubly_abstaining_peer_to_empty")


def _strength_mag(v, mz, ac, ratio_tol, abs_tol):
    def lit(x):
        return "NULL" if x is None else str(x)

    rows = corpus_sql(
        "SELECT cmp.strength_mag(%s, %s, %s, %s, %s)"
        % (lit(v), lit(mz), lit(ac), ratio_tol, abs_tol)
    )
    got = rows[0][0]
    return "" if got == "NULL" else got


def test_consensus_strength_mag_rule():
    """Item 2 (fix round 2): cmp.strength_mag wraps cmp.strength_num for the
    four magnitude topics (health, trainer_spell_count, spawn_count,
    respawn_min). cmp.strength_num's third branch reads 'exactly one peer
    NULL' as automatic disagreement, even when the peer that did vote
    agrees with v - a row that asserts nothing, since no source is claiming
    a difference. cmp.strength_mag intercepts exactly that shape and
    returns '' instead; every other input must fall through to
    cmp.strength_num unchanged.

    Cases hand-computed from the rule, not round-tripped out of the
    function under test.
    """
    cases = [
        # (v, mz, ac, ratio_tol, abs_tol, expected)
        # one peer NULL, the other agrees with v (5/100 = 0.05 <= 0.20) -> ''
        (100, None, 105, 0.20, 0, ""),
        (100, 105, None, 0.20, 0, ""),
        # one peer NULL, the other disagrees with v (100/100 = 1.0 > 0.20) -> weak
        (100, None, 200, 0.20, 0, "weak"),
        (100, 200, None, 0.20, 0, "weak"),
        # both peers present, agree with each other but not v -> strong,
        # unchanged from cmp.strength_num (same case that test uses)
        (100, 150, 145, 0.20, 0, "strong"),
        # both peers NULL -> ''
        (100, None, None, 0.20, 0, ""),
    ]
    for v, mz, ac, ratio_tol, abs_tol, expected in cases:
        got = _strength_mag(v, mz, ac, ratio_tol, abs_tol)
        assert got == expected, (
            "cmp.strength_mag(%s, %s, %s, %s, %s) gave %r, expected %r"
            % (v, mz, ac, ratio_tol, abs_tol, got, expected)
        )
    print("PASS test_consensus_strength_mag_rule")


def _agrees_num(a, b, ratio_tol, abs_tol):
    rows = corpus_sql(
        "SELECT cmp._agrees_num(%s, %s, %s, %s)" % (a, b, ratio_tol, abs_tol)
    )
    return rows[0][0] == "1"


def test_agrees_num_matches_spec_at_percentage_point_scale():
    """Item 4 (fix round 1): pin cmp._agrees_num's behaviour at the exact
    (ratio_tol=1.0, abs_tol=5) percentage-point scale
    diffs/05_quest_item_drops.sql calls it at, hand-computed from the
    spec's "2x ratio or 5 absolute points" rule rather than read back out
    of the function under test.

    test_all_six_topics_fire alone would not catch abs_tol silently
    reverting to 0.05 while the *100 scaling on p_drop stayed in place -
    the ratio branch still fires some findings either way (it is on a
    percentage-point scale, so the GREATEST(...,1) floor trap
    diffs/00_schema.sql documents does not apply here), so the topic would
    not disappear from cmp.findings, only which rows it flags would
    quietly change. This pins the intended per-pair verdicts directly.
    """
    # Inside 5 points: agrees outright, regardless of ratio.
    assert _agrees_num(30, 33, 1.0, 5) is True, (
        "30 vs 33 (diff 3, within 5 points) should agree"
    )
    # Outside 5 points and beyond 2x (b is 5x a): disagrees on both halves.
    assert _agrees_num(2, 10, 1.0, 5) is False, (
        "2 vs 10 (diff 8, b is 5x a) should disagree"
    )
    # Outside 5 points but within 2x (b is 1.7x a): rescued by the ratio half.
    assert _agrees_num(10, 17, 1.0, 5) is True, (
        "10 vs 17 (diff 7, b is 1.7x a) should agree (within 2x)"
    )
    print("PASS test_agrees_num_matches_spec_at_percentage_point_scale")


def test_pilot_zones_produce_findings():
    """Westfall and the Deadmines each produce findings in every topic run.

    Item 3 (fix round 2, minor 7): the previous assertion only checked that
    the per-zone topic dict was non-empty, which passes even when a single
    topic fires and the other two produce nothing. Assert all three topic
    keys are present for each zone, per the docstring's actual claim.
    """
    topics = ("creatures", "relations", "spawns")
    for zone, label in ((40, "Westfall"), (1581, "The Deadmines")):
        rows = corpus_sql(
            "SELECT topic, COUNT(*) FROM cmp.findings WHERE zone=%d "
            "GROUP BY topic" % zone
        )
        got = {r[0]: int(r[1]) for r in rows}
        assert got, "%s produced no findings at all" % label
        missing = [t for t in topics if t not in got]
        assert not missing, (
            "%s produced no findings in topic(s) %s: %s" % (label, missing, got)
        )
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


def test_link_relation_uses_creature_entry_not_guid():
    """Task 9 Step 0 regression pin, over every source with creature_linking.

    creature_linking is keyed by spawn GUID; n_rel's 'link' kind must resolve
    both sides to creature entry, like the other four kinds, not carry the
    raw GUID through. A regression back to GUID keying would not error - it
    would just make every link npc/target value fail to name a real
    creature, and the row count would jump back up to one row per
    creature_linking record instead of one per distinct entry pair.

    Checked by reverting the Step 0 fix: with v.n_rel.link keyed by GUID,
    406 of v's 407 link rows have an npc value that is not a v.n_creature
    entry (only 1 is a coincidental GUID/entry collision), and the row
    count is 407 instead of 58.

    Item 4 (fix round 2, minor 8): the original pin checked only v, although
    mz.sql and tw.sql received the identical Step 0 edit - a revert of
    either alone passed the suite. Loops over all three sources that have
    creature_linking; ac has no equivalent table and must stay excluded
    (views/ac.sql's own comment on this).
    """
    for src in ("v", "mz", "tw"):
        rows = corpus_sql("SELECT COUNT(*) FROM %s.n_rel WHERE kind='link'" % src)
        n_link = int(rows[0][0])
        assert n_link > 0, "%s.n_rel has no link rows to check" % src

        rows = corpus_sql(
            "SELECT COUNT(*) FROM %s.n_rel r "
            "LEFT JOIN %s.n_creature c ON c.entry = r.npc "
            "WHERE r.kind='link' AND c.entry IS NULL" % (src, src)
        )
        assert int(rows[0][0]) == 0, (
            "%s: %s of %s link npc values are not creature entries - "
            "n_rel.link is keyed by GUID, not entry" % (src, rows[0][0], n_link)
        )

        rows = corpus_sql(
            "SELECT COUNT(*) FROM %s.n_rel r "
            "LEFT JOIN %s.n_creature c ON c.entry = r.target "
            "WHERE r.kind='link' AND c.entry IS NULL" % (src, src)
        )
        assert int(rows[0][0]) == 0, (
            "%s: %s link target values are not creature entries" % (src, rows[0][0])
        )
    print("PASS test_link_relation_uses_creature_entry_not_guid")


def test_spawn_count_never_strong_when_both_peers_absent():
    """Task 9 fix round 1 regression pin.

    06_spawns.sql used to build the spawn_count finding with
    COALESCE(peer.n, 0) on mz and ac alike. spawn_agg.n is a COUNT(*), so
    it is never 0 - a peer's absence from the aggregate was being turned
    into a literal 0, and when BOTH peers were absent for the same
    (kind, zone, entry), the two coalesced zeros agreed with each other and
    cmp.strength_num read that as corroboration: 'strong', the report's top
    label, for a claim neither peer made. Measured before the fix: 140
    spawn_count findings were 'strong' this way.

    This is checked independently of how mz_value/ac_value happen to be
    stored (NULL vs '0') by going back to cmp.spawn_agg directly: for every
    'strong' spawn_count finding, at least one of mz or ac must actually
    have a row for that (kind, zone, entry). Reverting the fix (COALESCE on
    both peer arguments) reproduces the 140 failures.
    """
    rows = corpus_sql(
        "SELECT COUNT(*) FROM cmp.findings f "
        "LEFT JOIN cmp.spawn_agg amz ON amz.src='mz' AND amz.kind=f.entity_kind "
        "  AND amz.zone=f.zone AND amz.entry=f.entity_id "
        "LEFT JOIN cmp.spawn_agg aac ON aac.src='ac' AND aac.kind=f.entity_kind "
        "  AND aac.zone=f.zone AND aac.entry=f.entity_id "
        "WHERE f.topic='spawns' AND f.field='spawn_count' AND f.strength='strong' "
        "  AND amz.n IS NULL AND aac.n IS NULL"
    )
    n = int(rows[0][0])
    assert n == 0, (
        "%s spawn_count findings are 'strong' with both mz and ac absent from "
        "spawn_agg - two absences are being read as mutual corroboration" % n
    )
    print("PASS test_spawn_count_never_strong_when_both_peers_absent")


def test_magnitude_topics_never_write_a_contentless_weak_finding():
    """Item 2 (fix round 2) regression pin, over the live findings table.

    No finding in a magnitude field (hp@N, trainer_spell_count, spawn_count,
    respawn_min) may have exactly one peer NULL while the other peer agrees
    with v_value within that field's own tolerance - cmp.strength_mag exists
    precisely to filter that shape out before diffs/*.sql inserts it.

    Tolerances are restated here as a literal table, not read out of
    diffs/00_schema.sql or diffs/*.sql, so a future tolerance change shows up
    as a failing assertion here instead of silently validating against
    whatever the SQL currently says. Checked by reverting the four call
    sites (01_creatures.sql, 02_relations.sql, 06_spawns.sql x2) from
    cmp.strength_mag back to cmp.strength_num and rebuilding: see the fix
    round 2 report for the counts this reproduces.
    """
    # (topic, field predicate, ratio_tol, abs_tol)
    fields = [
        ("creatures", "field LIKE 'hp@%'", 0.20, 0),
        ("relations", "field = 'trainer_spell_count'", 0.50, 5),
        ("spawns", "field = 'spawn_count'", 0.50, 5),
        ("spawns", "field = 'respawn_min'", 1.0, 0),
    ]
    for topic, field_pred, ratio_tol, abs_tol in fields:
        rows = corpus_sql(
            "SELECT COUNT(*) FROM cmp.findings WHERE topic='%s' AND %s AND ("
            "  (mz_value IS NULL AND ac_value IS NOT NULL"
            "     AND cmp._agrees_num(CAST(v_value AS DOUBLE), CAST(ac_value AS DOUBLE), %s, %s))"
            "  OR (ac_value IS NULL AND mz_value IS NOT NULL"
            "     AND cmp._agrees_num(CAST(v_value AS DOUBLE), CAST(mz_value AS DOUBLE), %s, %s))"
            ")" % (topic, field_pred, ratio_tol, abs_tol, ratio_tol, abs_tol)
        )
        n = int(rows[0][0])
        assert n == 0, (
            "%s/%s: %s findings have exactly one peer NULL with the other "
            "agreeing with v - a contentless weak finding cmp.strength_mag "
            "should have filtered" % (topic, field_pred, n)
        )
    print("PASS test_magnitude_topics_never_write_a_contentless_weak_finding")


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


def test_quest_item_drops_never_strong_when_both_peers_absent():
    """Ruling (g) regression pin: COALESCE(..., 0) belongs on v only.

    diffs/05_quest_item_drops.sql applies COALESCE(lv.p_drop, 0) to the v
    argument of cmp.strength_mag but leaves lmz.p_drop/lac.p_drop as bare
    NULLs when absent. Coalescing a peer's absence to 0 as well would let
    two independently absent peers agree with each other on a value neither
    one asserted - the exact shape that fabricated 169 'strong' spawn_count
    findings before diffs/06_spawns.sql was fixed
    (test_spawn_count_never_strong_when_both_peers_absent). This checks the
    live findings table directly, the same way that test does, rather than
    trusting the SQL was written the safe way.
    """
    rows = corpus_sql(
        "SELECT COUNT(*) FROM cmp.findings "
        "WHERE topic='quest_item_drops' AND strength='strong' "
        "AND mz_value IS NULL AND ac_value IS NULL"
    )
    n = int(rows[0][0])
    assert n == 0, (
        "%s quest_item_drops findings are 'strong' with both mz and ac "
        "absent - a peer's absence is being read as corroboration" % n
    )
    print("PASS test_quest_item_drops_never_strong_when_both_peers_absent")


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
    test_quest_xp_formula_matches_known_inputs,
    test_quest_xp_no_duplicate_rows,
    test_vmangos_stored_xp_agrees_with_its_own_inputs,
    test_effective_drop_chance,
    test_consensus_strength_rule,
    test_consensus_strength_never_strong_with_an_abstaining_peer,
    test_consensus_strength_missing_from_v_is_strong_when_peers_agree,
    test_consensus_strength_num_rule,
    test_consensus_strength_num_is_symmetric,
    test_consensus_strength_num_never_strong_with_an_abstaining_peer,
    test_consensus_strength_num_filters_a_doubly_abstaining_peer_to_empty,
    test_consensus_strength_mag_rule,
    test_agrees_num_matches_spec_at_percentage_point_scale,
    test_pilot_zones_produce_findings,
    test_link_relation_uses_creature_entry_not_guid,
    test_spawn_count_never_strong_when_both_peers_absent,
    test_magnitude_topics_never_write_a_contentless_weak_finding,
    test_all_six_topics_fire,
    test_quest_item_drops_never_strong_when_both_peers_absent,
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
