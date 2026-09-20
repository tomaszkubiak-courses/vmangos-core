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

# The field column embeds a second id in these topics: 'creature:NNN' /
# 'gobject:NNN' in quest_item_drops, 'vendor:NNN' / 'questgiver:NNN' /
# 'questender:NNN' / 'link:NNN' in relations, 'item:NNN' / 'choice:NNN' in
# quest_rewards, and 'obj:npc:NNN' / 'obj:item:NNN' in quests. Read off
# views/v.sql's n_rel definition, not guessed - 'link' resolves to a
# creature entry because Task 9 rekeyed it from the spawn GUID
# creature_linking used natively.
FIELD_PREFIX_KIND = {
    "creature": "creature",
    "gobject": "gobject",
    "link": "creature",
    "vendor": "item",
    "questgiver": "quest",
    "questender": "quest",
    "item": "item",
    "choice": "item",
    "obj:npc": "creature",
    "obj:item": "item",
}

# (schema, table, id column, name column, patch-keyed) per kind, first
# source that has the id wins. AzerothCore is deliberately not a name
# source for quests (its quest_template renamed the title column to
# LogTitle, and an ac-only quest is post-vanilla content this report does
# not need to name).
#
# v.quest_template/item_template/gameobject_template are keyed on
# (entry, patch) - one row per content patch a row was introduced or
# changed in, exactly like v.creature_template/quest_template documented in
# views/v.sql. n_creature already resolves that for creatures; there is no
# equivalent n_gameobject/n_item view, so a naive "WHERE entry = X" against
# these three raw v tables can return more than one row and hand back a
# name from the wrong patch. 'patch-keyed' below reruns the same
# MAX(patch) WHERE patch <= 10 pick views/v.sql uses. mz and ac carry no
# patch column on any of these tables (verified on the corpus) and are
# queried directly.
NAME_SOURCES = {
    "creature": [
        ("v", "n_creature", "entry", "name", False),
        ("mz", "n_creature", "entry", "name", False),
        ("ac", "n_creature", "entry", "name", False),
    ],
    "gobject": [
        ("v", "gameobject_template", "entry", "name", True),
        ("mz", "gameobject_template", "entry", "name", False),
        ("ac", "gameobject_template", "entry", "name", False),
    ],
    "quest": [
        ("v", "quest_template", "entry", "Title", True),
        ("mz", "quest_template", "entry", "Title", False),
    ],
    "item": [
        ("v", "item_template", "entry", "name", True),
        ("mz", "item_template", "entry", "name", False),
    ],
}

# Follow-up 3, task-16 part B: the exact strings diffs/02_relations.sql and
# diffs/03_quests.sql write into cmp.findings.note for a 'strong' per-target
# relation or quest-objective finding. Matched by substring below rather than
# by exact equality, since the quests topic's obj: rows prefix this with
# "objective count; ".
REALM_HAS_NOTE = "this realm has it; neither peer does"
REALM_LACKS_NOTE = "this realm lacks it; both peers have it"

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
- `lineage` (Task 13) means mangoszero and AzerothCore agree with each other,
  disagree with this realm, AND their rows are the same shared-ancestor row -
  not two independent sources reaching the same conclusion. It is still the
  most actionable signal the audit produces (this realm diverged from what
  both peers inherited), but it is one witness, not two, so it is kept out of
  the `strong` count. See README.md's corpus-overlap section for why.
- A `relations`/`quests` note reading "this realm has it; neither peer does"
  or "this realm lacks it; both peers have it" (Task 16) names which side of
  a `strong` finding is short. The first is usually the peers being a leaner
  or different content set, not a defect here; the second is the shape this
  audit exists to find. Neither is suppressed - both are real disagreements.
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
    rows = query("SELECT name FROM dbc.area_table WHERE id = %d" % zone)
    return rows[0][0] if rows else "zone-%d" % zone


def load_zone_findings(zone):
    rows = query(
        "SELECT topic, entity_kind, entity_id, field, v_value, mz_value, "
        "tw_value, ac_value, strength, note FROM cmp.findings "
        "WHERE zone=%d" % zone
    )
    findings = []
    for topic, kind, eid, field, v, mz, tw, ac, strength, note in rows:
        findings.append(
            {
                "topic": topic,
                "kind": kind,
                "id": int(eid),
                "field": field,
                "v": v,
                "mz": mz,
                "tw": tw,
                "ac": ac,
                "strength": strength,
                "note": note,
            }
        )
    return findings


def field_ref(field):
    """('vendor', 'item', 401) for 'vendor:401'; ('obj:npc', 'creature', 6)
    for 'obj:npc:6'; None when field carries no id. The numeric id is
    always the last colon-separated segment, so splitting on the last colon
    handles the two-segment 'obj:npc'/'obj:item' forms the same way as the
    one-segment ones, without special-casing either."""
    if ":" not in field:
        return None
    prefix, _, rest = field.rpartition(":")
    kind = FIELD_PREFIX_KIND.get(prefix)
    if kind and rest.isdigit():
        return prefix, kind, int(rest)
    return None


def collect_ids(findings):
    needed = {"creature": set(), "gobject": set(), "quest": set(), "item": set()}
    for f in findings:
        if f["kind"] in needed:
            needed[f["kind"]].add(f["id"])
        ref = field_ref(f["field"])
        if ref:
            _, kind, fid = ref
            needed[kind].add(fid)
    return needed


def fetch_names(schema, table, id_col, name_col, ids, patched):
    id_list = ",".join(str(i) for i in sorted(ids))
    if patched:
        stmt = (
            "SELECT t.{id_col}, t.{name_col} FROM {schema}.{table} t "
            "JOIN (SELECT {id_col}, MAX(patch) AS patch FROM {schema}.{table} "
            "WHERE patch <= 10 AND {id_col} IN ({ids}) GROUP BY {id_col}) latest "
            "ON latest.{id_col} = t.{id_col} AND latest.patch = t.patch"
        ).format(id_col=id_col, name_col=name_col, schema=schema, table=table, ids=id_list)
    else:
        stmt = "SELECT {id_col}, {name_col} FROM {schema}.{table} WHERE {id_col} IN ({ids})".format(
            id_col=id_col, name_col=name_col, schema=schema, table=table, ids=id_list
        )
    rows = query(stmt)
    return {int(r[0]): r[1] for r in rows if r[1] not in (None, "NULL")}


def resolve_names(needed):
    """(kind, id) -> name, first source in NAME_SOURCES[kind] that has it."""
    names = {}
    for kind, ids in needed.items():
        remaining = set(ids)
        for schema, table, id_col, name_col, patched in NAME_SOURCES[kind]:
            if not remaining:
                break
            found = fetch_names(schema, table, id_col, name_col, remaining, patched)
            for fid, nm in found.items():
                names[(kind, fid)] = nm
            remaining -= set(found)
    return names


def render_id(names, kind, entity_id):
    nm = names.get((kind, entity_id))
    return "%d %s" % (entity_id, nm) if nm else str(entity_id)


def render_field(names, field):
    ref = field_ref(field)
    if not ref:
        return field
    prefix, kind, fid = ref
    return "%s:%s" % (prefix, render_id(names, kind, fid))


def parse_float(value):
    if value in (None, "NULL"):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def row_divergence(v, peers):
    """Largest abs(v-peer)/max(min(|v|,|peer|),1) over peers that parse as float."""
    vf = parse_float(v)
    if vf is None:
        return 0.0
    best = 0.0
    for peer in peers:
        pf = parse_float(peer)
        if pf is None:
            continue
        best = max(best, abs(vf - pf) / max(min(abs(vf), abs(pf)), 1))
    return best


STRENGTH_RANK = {"strong": 0, "lineage": 1, "weak": 2}


def sort_key(row):
    # Item 4: tortoise-wow is a fork of the live database (00_schema.sql's
    # consensus comment), so its agreement or disagreement carries no
    # evidence and neither cmp.strength nor cmp.strength_num takes it.
    # Ordering by how far a fork strays is ordering by non-evidence -
    # measured on this corpus, tortoise is the strict maximum divergence in
    # 1033 of 40259 numeric-v rows (2.6%), so leaving it in did move real
    # output. It stays a peer column in the table, which is its documented
    # role.
    #
    # Task 13: strong > lineage > weak (diffs/00_schema.sql's doctrine
    # comment on cmp.apply_lineage) - a shared-ancestry finding is still more
    # actionable than an ordinary disagreement, but less than two
    # independent sources agreeing.
    rank = STRENGTH_RANK.get(row["strength"], 3)
    div = row_divergence(row["v"], (row["mz"], row["ac"]))
    return (rank, -div, row["id"], row["field"])


def findings_table(rows, names):
    if not rows:
        return "No findings.\n"
    out = [
        "| Entity | Id | Field | live | mangoszero | tortoise | azerothcore | Strength | Note |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for r in sorted(rows, key=sort_key):
        out.append(
            "| %s | %s | %s | %s | %s | %s | %s | %s | %s |"
            % (
                r["kind"],
                render_id(names, r["kind"], r["id"]),
                render_field(names, r["field"]),
                cell(r["v"]),
                cell(r["mz"]),
                cell(r["tw"]),
                cell(r["ac"]),
                r["strength"],
                r["note"],
            )
        )
    return "\n".join(out) + "\n"


def suppression_note(group, names, destination):
    """Item 1: the exists row a suppressed row points back to can live in
    either of two places - see the call sites below."""
    distinct = sorted({r["id"] for r in group})
    one = len(group) == 1
    note = (
        "%d further finding%s here %s to %d creature%s absent from the live "
        "database entirely; %s of the exists findings %s."
        % (
            len(group),
            "" if one else "s",
            "belongs" if one else "belong",
            len(distinct),
            "" if len(distinct) == 1 else "s",
            "it is a consequence" if one else "they are consequences",
            destination,
        )
    )
    if len(distinct) <= 12:
        note += " (" + ", ".join(render_id(names, "creature", i) for i in distinct) + ")"
    return note


def render_topic(topic, heading, rows, names, absent_ids, appendix_a_ids):
    lines = ["## %s" % heading, ""]

    if topic == "creatures":
        moved = [r for r in rows if r["field"] == "exists" and r["id"] in appendix_a_ids]
        shown = [r for r in rows if r not in moved]
        to_appendix_a = to_section1 = []
    else:
        # Ruling 11(c): suppress rows that only restate a creature's absence.
        # Scoped to entity_kind == 'creature' so a numeric id shared with
        # another kind (e.g. an item or quest id) can never be caught by
        # this filter - mirrors the kind-filter defect ruling 11(a) found in
        # the plan's n_spawn/n_creature join.
        #
        # Item 1: the suppressed creature's own exists row does not always
        # live in the same place. Ruling 11(d) moved every exists row with
        # both v and mz absent to Appendix A; a creature absent from v alone
        # (mz still has it) keeps its exists row in section 1. Pick the
        # destination per creature rather than pointing every suppression at
        # a fixed string - appendix_a_ids is always a subset of absent_ids,
        # so this partition is exhaustive. The two sets are equal on this
        # corpus (verified: 0 findings with v absent and mz present) but
        # nothing in the schema forces that, so both branches stay live and
        # a block spanning both says both.
        suppressed = [r for r in rows if r["kind"] == "creature" and r["id"] in absent_ids]
        shown = [r for r in rows if r not in suppressed]
        to_appendix_a = [r for r in suppressed if r["id"] in appendix_a_ids]
        to_section1 = [r for r in suppressed if r["id"] not in appendix_a_ids]

    # 2026-09-20: one realm-wide convention, not N defects. This realm sets
    # quest_template.RequiredRaces on 628 of its 4433 quests; mangoszero sets
    # it on 2431 of 4248 and AzerothCore on 4919 of 9464. Once the race masks
    # are compared on the vanilla bits alone (see views/v.sql), every quest
    # where this realm leaves the field 0 and both peers restrict it becomes a
    # 'strong' finding - 1986 of them corpus-wide, which buries every other
    # quest finding in the report exactly the way the per-spell trainer rows
    # did before diffs/02_relations.sql collapsed them.
    #
    # Collapsed in rendering only: the rows stay in cmp.findings, the count is
    # printed, and a quest where this realm restricts and the peers differ is
    # NOT collapsed - that direction is a real per-quest claim.
    race_convention = []
    if topic == "quests":
        race_convention = [
            r for r in shown
            if r["field"] == "req_race" and r["v"] == "0"
            and r["mz"] not in (None, "NULL", "0")
            and r["ac"] not in (None, "NULL", "0")
        ]
        shown = [r for r in shown if r not in race_convention]

    strong = sum(1 for r in shown if r["strength"] == "strong")
    lineage = sum(1 for r in shown if r["strength"] == "lineage")
    weak = len(shown) - strong - lineage
    lines.append(
        "%d findings (%d strong, %d lineage, %d weak)" % (len(shown), strong, lineage, weak)
    )

    # Follow-up 3, task-16 part B: the relations (vendor/questgiver/
    # questender/link) and quests (obj:) topics carry a note recording which
    # way a 'strong' finding points - diffs/02_relations.sql and
    # diffs/03_quests.sql write REALM_HAS_NOTE/REALM_LACKS_NOTE literally,
    # never reconstructed here, so this can never drift from what a reader
    # sees in the Note column. Only these two topics ever produce the note
    # text, so the substring check is safe without a topic filter, but the
    # topic check still gates the line to avoid a stray "(0 ..., 0 ...)" on
    # every other topic's summary.
    if topic in ("relations", "quests"):
        realm_has = sum(1 for r in shown if REALM_HAS_NOTE in r["note"])
        realm_lacks = sum(1 for r in shown if REALM_LACKS_NOTE in r["note"])
        if realm_has or realm_lacks:
            lines.append(
                "Of these, %d point at content only this realm has (neither peer does) "
                "and %d point at a gap both peers have that this realm lacks."
                % (realm_has, realm_lacks)
            )

    if race_convention:
        lines.append("")
        lines.append(
            "%d req_race finding%s collapsed: this realm leaves RequiredRaces at 0 "
            "where both peers restrict the quest by race. It populates that column on "
            "roughly one quest in seven against more than half in either peer, so this "
            "is one realm-wide convention rather than %d separate defects. The rows are "
            "still in cmp.findings."
            % (len(race_convention), "" if len(race_convention) == 1 else "s",
               len(race_convention))
        )

    if topic == "creatures" and moved:
        lines.append("")
        lines.append(
            "%d finding%s moved to Appendix A: entit%s absent from both "
            "vanilla peers (probable post-vanilla or custom content)."
            % (
                len(moved),
                "" if len(moved) == 1 else "s",
                "y" if len(moved) == 1 else "ies",
            )
        )
    elif topic != "creatures" and (to_section1 or to_appendix_a):
        lines.append("")
        if to_section1:
            lines.append(suppression_note(to_section1, names, "in section 1"))
        if to_appendix_a:
            lines.append(suppression_note(to_appendix_a, names, "moved to Appendix A"))

    lines.append("")
    lines.append(findings_table(shown, names))
    return "\n".join(lines)


def appendix_a(appendix_a_rows, names):
    # Item 2: the predicate (v and mz both absent) is right - it deliberately
    # covers both the ac-only shape and the tortoise+ac shape - but the old
    # heading claimed every row was AzerothCore-only, which made 22
    # (zone, entry) pairs corpus-wide contradict Appendix B's "tortoise-only"
    # heading for the same creature. Fix the label, not the predicate: name
    # what the set really is, and read who actually claims each row off its
    # own tw_value/ac_value rather than assuming AzerothCore.
    body = "None.\n"
    if appendix_a_rows:
        lines = []
        for i in sorted(appendix_a_rows):
            f = appendix_a_rows[i]
            sources = [
                label
                for key, label in (("tw", "tortoise-wow"), ("ac", "AzerothCore"))
                if f[key] not in (None, "NULL")
            ]
            lines.append("- %s (%s)" % (render_id(names, "creature", i), ", ".join(sources) or "no source"))
        body = "\n".join(lines) + "\n"
    return (
        "## Appendix A - absent from both vanilla peers (probable "
        "post-vanilla or custom content)\n\n%s\n" % body
    )


def appendix_b(zone):
    # Ruling 11(a): the missing kind = 'creature' filter let a gameobject
    # spawn borrow a creature's name (2066 ids in this corpus collide
    # between the two kinds in n_spawn) - added here.
    where = (
        "t.zone = %d AND t.kind = 'creature' "
        "AND cv.entry IS NULL AND cm.entry IS NULL" % zone
    )
    from_clause = (
        "FROM tw.n_spawn t "
        "JOIN tw.n_creature c ON c.entry = t.entry "
        "LEFT JOIN v.n_creature cv ON cv.entry = t.entry "
        "LEFT JOIN mz.n_creature cm ON cm.entry = t.entry "
    )
    rows = query(
        "SELECT DISTINCT t.entry, c.name %s WHERE %s ORDER BY t.entry LIMIT 200"
        % (from_clause, where)
    )
    body = "None.\n"
    if rows:
        body = "\n".join("- %s %s" % (r[0], r[1]) for r in rows) + "\n"
        if len(rows) == 200:
            # Ruling 11(d) expected this appendix empty or near-empty in
            # most zones. On this corpus it is not (240 distinct entries
            # for Westfall alone, tortoise-wow's own Westfall-set custom
            # NPCs) - note the truncation rather than silently dropping the
            # rest, without changing which rows are listed.
            total = query(
                "SELECT COUNT(DISTINCT t.entry) %s WHERE %s" % (from_clause, where)
            )
            n = int(total[0][0])
            if n > 200:
                body += "\n(showing 200 of %d - list truncated)\n" % n
    return "## Appendix B - tortoise-only entities (probable classic-plus custom)\n\n%s\n" % body


def appendix_c():
    # Ruling 11(a): not zone-scoped and cannot be - a spawn whose zone could
    # not be resolved has no zone to file it under. Identical in every
    # report.
    rows = query("SELECT src, kind, COUNT(*) FROM cmp.areas WHERE zone = 0 GROUP BY src, kind")
    body = "None.\n"
    if rows:
        body = "\n".join("- " + " ".join(cell(c) for c in r) for r in rows) + "\n"
    return "## Appendix C - unresolved spawns (global, not zone-specific)\n\n%s\n" % body


def render(zone):
    name = zone_name(zone)
    findings = load_zone_findings(zone)

    absent_ids = {
        f["id"]
        for f in findings
        if f["topic"] == "creatures" and f["field"] == "exists" and f["v"] in (None, "NULL")
    }
    appendix_a_rows = {
        f["id"]: f
        for f in findings
        if f["topic"] == "creatures"
        and f["field"] == "exists"
        and f["v"] in (None, "NULL")
        and f["mz"] in (None, "NULL")
    }
    appendix_a_ids = set(appendix_a_rows)

    needed = collect_ids(findings)
    needed["creature"] |= appendix_a_ids
    names = resolve_names(needed)

    total = len(findings)
    strong_total = sum(1 for f in findings if f["strength"] == "strong")
    lineage_total = sum(1 for f in findings if f["strength"] == "lineage")
    weak_total = total - strong_total - lineage_total
    summary = (
        "%d findings (%d strong, %d lineage, %d weak)"
        % (total, strong_total, lineage_total, weak_total)
        if total
        else "no findings"
    )

    parts = ["# %s (%d)" % (name, zone), "", summary, ""]
    for topic, heading in TOPICS:
        rows = [f for f in findings if f["topic"] == topic]
        parts.append(render_topic(topic, heading, rows, names, absent_ids, appendix_a_ids))
        parts.append("")

    parts.append(appendix_a(appendix_a_rows, names))
    parts.append(appendix_b(zone))
    parts.append(appendix_c())
    parts.append("## Comparability notes\n\n" + COMPARABILITY)
    return "\n".join(parts)


def main(argv):
    if not argv:
        sys.exit("usage: report.py <zone id> [<zone id> ...]")
    out_dir = os.path.join(REPO, CFG["REPORT_DIR"])
    os.makedirs(out_dir, exist_ok=True)
    for arg in argv:
        zone = int(arg)
        text = render(zone)
        zname = zone_name(zone).replace(" ", "-").replace("'", "")
        path = os.path.join(out_dir, "%d-%s.md" % (zone, zname))
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
        print("wrote %s" % path)


if __name__ == "__main__":
    main(sys.argv[1:])
