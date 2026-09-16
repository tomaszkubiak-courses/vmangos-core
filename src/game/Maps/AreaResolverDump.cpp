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
