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
    uint32 totalLines = 0;
    uint32 resolved = 0;
    uint32 skipped = 0;
    uint32 malformed = 0;

    while (fgets(line, sizeof(line), in))
    {
        ++totalLines;

        char src[64];
        char kind[32];
        uint32 id;
        uint32 mapId;
        float x, y, z;

        if (sscanf(line, "%63[^,],%31[^,],%u,%u,%f,%f,%f", src, kind, &id, &mapId, &x, &y, &z) != 7)
        {
            ++malformed;
            continue;
        }

        // GetZoneAndAreaId loads the map's TerrainInfo on demand (it is
        // never null - TerrainManager::LoadTerrain constructs one for any
        // map id rather than failing) and looks the resulting area flag up
        // against the world DB's area_template/map_template tables. Both
        // "map has no extracted terrain" and "coordinate has no matching
        // area_template row" come back as zone 0 and area 0, so that is
        // what "skipped" counts below - it cannot tell the two apart.
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

    sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "[ContentAudit] %u input lines, resolved %u, skipped %u, malformed %u",
             totalLines, resolved, skipped, malformed);
}
