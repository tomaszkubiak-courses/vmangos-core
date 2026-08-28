#pragma once
//
// BotLog — routes all sLog calls from the bot subsystem to a dedicated log
// file (logs/bots.log by default) so the main server.log stays clean.
//
// Activated by AiPlayerbot.BotLogFile in aiplayerbot.conf. When the setting
// is empty the class falls back to Log::Instance() for every call, keeping
// existing behaviour with zero overhead.
//
// AiPlayerbot.BotLogLevel caps how verbose the file gets, exactly the way
// LogLevel caps the core log. Without it every out*() call was written
// unconditionally once the file was open, so a populated server produced
// hundreds of megabytes of detail lines an hour.
//
// playerbot.h redefines `sLog` to `BotLog::Instance()` after including this
// header, so every bot .cpp that includes playerbot.h automatically routes
// through here without any call-site changes.
//

#include "Log.h"
#include "Platform/Define.h"
#include <cstdio>
#include <mutex>

class BotLog
{
public:
    static BotLog& Instance();

    // Called once from PlayerbotAIConfig::Initialize(). logFile is the bare
    // filename (e.g. "bots.log"); logsDir is the server's LogsDir value.
    // Empty logFile disables file routing (all calls fall through to sLog).
    // level caps what reaches the file, mirroring the core log's LogLevel.
    void Initialize(const char* logFile, const char* logsDir, bool debugEnabled = false, LogLevel level = LOG_LVL_BASIC);

    // Drop-in replacements for the Log methods bot code calls directly.
    void outString();
    void outString(const char* fmt, ...)  ATTR_PRINTF(2, 3);
    void outInfo(const char* fmt, ...)    ATTR_PRINTF(2, 3);
    void outDetail(const char* fmt, ...)  ATTR_PRINTF(2, 3);
    void outError(const char* fmt, ...)   ATTR_PRINTF(2, 3);
    void outDebug(const char* fmt, ...)   ATTR_PRINTF(2, 3);
    void outBasic(const char* fmt, ...)   ATTR_PRINTF(2, 3);
    void outErrorDb(const char* fmt, ...) ATTR_PRINTF(2, 3);

    // Core headers that the module includes log through sLog.Out() directly - the
    // database templates do - and sLog is this class inside the module, so it needs
    // the same entry point. It always goes to the core log: the type and level are
    // the core's, and the line has nothing to do with a bot.
    void Out(LogType logType, LogLevel logLevel, const char* fmt, ...) ATTR_PRINTF(4, 5);

    // The LOG macros in Log.h (DETAIL_LOG, BASIC_LOG, etc.) call this on
    // sLog before calling out*. While the file is open it answers for the
    // file's own level, so a suppressed line is never even formatted; with
    // no file it stays permissive and the core log applies its own level.
    bool HasLogLevelOrHigher(LogLevel loglvl) const { return !m_file || m_level >= loglvl; }
    bool HasLogFilter(uint32 /*filter*/) const { return false; }

    // Parses "error", "minimal", "basic", "detail" or "debug" (or a raw 0-4)
    // into a LogLevel. Anything unrecognised yields fallback.
    static LogLevel ParseLevel(const char* value, LogLevel fallback);

private:
    FILE*      m_file = nullptr;
    bool       m_debugEnabled = false;
    LogLevel   m_level = LOG_LVL_BASIC;
    std::mutex m_mutex;
};
