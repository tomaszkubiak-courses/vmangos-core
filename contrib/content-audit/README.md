# Content audit pipeline

Compares this realm's world database against three other server databases and
writes one Markdown discrepancy report per game zone.

Design: `docs/superpowers/specs/2026-09-16-content-audit-pipeline-design.md`

## Setup

    cp config.env.example config.env    # then fill it in; config.env is gitignored
    sh build_corpus.sh                  # 30-60 minutes, ~3 GB

`build_corpus.sh` starts a throwaway MySQL instance and imports eight schemas
into it: `v` (a snapshot of the live world database), `mz`, `tw`, `ac`, the
three live realm databases so a scratch core can boot against the corpus
rather than against the live server, and `dbc` (a snapshot of the live DBC
reference tables, needed later to resolve zone names via `dbc.area_table`).

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
