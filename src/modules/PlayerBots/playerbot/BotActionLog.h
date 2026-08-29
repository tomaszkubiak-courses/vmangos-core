#pragma once
//
// BotActionLog — opt-in per-bot detailed action log. Each bot summoned while
// AiPlayerbot.EnableActionLog=1 gets its own file under <LogsDir>/bots/, with a
// timestamped event stream covering lifecycle, casts, auras, state and target
// changes. One event per line, `[timestamp] [TAG] key=val key=val`. Files are
// fflush()'d on every write so a crash doesn't lose the trail. Gated behind
// the runtime config flag; ~zero cost when disabled.
//

#include "Common.h"
#include <cstdio>
#include <string>
#include <unordered_map>

class Player;
class PlayerbotAI;

namespace ai { namespace botdiag {

class BotActionLog
{
public:
    // Open a log file for this bot. Idempotent (returns existing handle
    // if already open). Creates the `bots/` directory if missing. Returns null on
    // I/O error (caller must tolerate null and skip logging).
    static std::FILE* Open(PlayerbotAI* ai);

    // Close + flush + remove from the registry. Safe to call on a bot
    // that was never opened.
    static void Close(PlayerbotAI* ai);

    // Same, keyed by the bot's low GUID. Needed because the Player and the
    // PlayerbotAI are already gone on some teardown paths, and the
    // PlayerbotAI* overload cannot then reach the handle at all - which is
    // how 488 of 2375 files were left open in one run.
    static void Close(uint32 guid);

    // Close every open handle. Called when the bot manager shuts down, so a
    // clean stop does not depend on every bot taking the logout path.
    static void CloseAll();

    // Get the open handle for this bot, or null if not open. Cheap.
    static std::FILE* GetHandle(PlayerbotAI* ai);

    // Lower-level write: timestamped, tag-prefixed, fflush'd. Format
    // follows printf semantics. Safe to call when log isn't open
    // (no-op).
    static void Write(PlayerbotAI* ai, const char* tag, const char* fmt, ...);

    // Convenience: snapshot the bot's current state to the log. Called
    // periodically (every ~2s from TickHeartbeat) and on combat-state
    // change. Includes HP%, MP%, combat flag, target name+guid, active
    // strategy list, current spell-cast (if any), aura count.
    static void LogState(PlayerbotAI* ai, const char* reason);

    // Convenience: log a spell-cast attempt with its target.
    static void LogCastStart(PlayerbotAI* ai, uint32 spellId, ObjectGuid targetGuid, uint32 castTimeMs);

    // Convenience: log a spell-cast result. `result` is a SpellCastResult
    // enum value (0 = success, otherwise failure code from SpellMgr).
    // `phase` is "PREPARE" / "CAST" / "EFFECT" — where in the cast
    // pipeline the result fired.
    static void LogCastResult(PlayerbotAI* ai, uint32 spellId, uint8 result, const char* phase);

    // Convenience: log an aura apply/remove. We skip very-short auras
    // (< 3s) and movement-class auras to keep the log readable; pass
    // `force=true` to always log.
    static void LogAuraApply(PlayerbotAI* ai, uint32 spellId, int32 durationMs, ObjectGuid casterGuid, bool force = false);
    static void LogAuraRemove(PlayerbotAI* ai, uint32 spellId, ObjectGuid casterGuid, bool force = false);

    // Number of per-bot files kept open at once. The Windows CRT caps a
    // process at 512 open FILE streams by default, and the whole server
    // shares that budget with the world logs, the DBC/map/vmap/mmap loaders
    // and the MySQL client. One handle per bot exceeded it 39 minutes into a
    // 200-bot run, after which every unrelated fopen in the process failed -
    // visible as 152 bogus "VMapManager2: could not load" errors for files
    // that were on disk and intact. Handles past the cap are closed
    // least-recently-used first and reopened on next write.
    static constexpr size_t kMaxOpenFiles = 128;

private:
    // One open file per bot, keyed by character GUID (low). Player* would be
    // unsafe across logout; the GUID stays valid in the map until we close it.
    struct OpenFile
    {
        std::FILE* fp = nullptr;
        uint64 lastUse = 0;     // sUseCounter stamp, for LRU eviction
    };
    static std::unordered_map<uint32, OpenFile> sFiles;

    // Path per bot, kept for the whole run even while the handle is evicted,
    // so reopening appends to the file the bot already has. Rebuilding it
    // would embed a fresh timestamp and scatter one bot across many files.
    static std::unordered_map<uint32, std::string> sPaths;

    // Monotonic stamp source for the LRU order above.
    static uint64 sUseCounter;

    // Close the least-recently-used handle. Caller holds sFilesMutex.
    static void EvictOldestLocked();

    // Helper: build the per-bot log path. `<botname>_<sessionId>_<date>.log`.
    static std::string BuildPath(Player* bot);

    // Helper: the directory the per-bot files go in — the server's LogsDir
    // plus `bots/`, with a trailing separator.
    static std::string LogDir();

    // Helper: ensure that directory exists. Cheap (CreateDirectory ignores
    // ERROR_ALREADY_EXISTS).
    static void EnsureLogDir();
};

}}  // namespace ai::botdiag
