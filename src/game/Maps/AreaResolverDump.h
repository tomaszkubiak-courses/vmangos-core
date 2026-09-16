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
