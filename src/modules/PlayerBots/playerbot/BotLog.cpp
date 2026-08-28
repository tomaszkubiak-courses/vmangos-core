#include "BotLog.h"

#include <chrono>
#include <cstdarg>
#include <cstring>
#include <ctime>
#include <string>

BotLog& BotLog::Instance()
{
    static BotLog s_instance;
    return s_instance;
}

LogLevel BotLog::ParseLevel(const char* value, LogLevel fallback)
{
    if (!value || value[0] == '\0')
        return fallback;

    struct LevelName { const char* name; LogLevel level; };
    static LevelName const names[] =
    {
        { "error",   LOG_LVL_ERROR   },
        { "minimal", LOG_LVL_MINIMAL },
        { "basic",   LOG_LVL_BASIC   },
        { "detail",  LOG_LVL_DETAIL  },
        { "debug",   LOG_LVL_DEBUG   },
    };

    for (auto const& entry : names)
    {
        if (!strcmp(value, entry.name))
            return entry.level;
    }

    // Also accept the raw numeric form, matching the core log's LogLevel config.
    if (value[0] >= '0' && value[0] <= '4' && value[1] == '\0')
        return LogLevel(value[0] - '0');

    return fallback;
}

void BotLog::Initialize(const char* logFile, const char* logsDir, bool debugEnabled, LogLevel level)
{
    if (!logFile || logFile[0] == '\0')
        return;  // empty → fall through to MaNGOS::Singleton<Log>::Instance() on every call

    std::string path;
    if (logsDir && logsDir[0] != '\0')
    {
        path = logsDir;
        if (path.back() != '/' && path.back() != '\\')
            path += '/';
    }
    path += logFile;

    std::lock_guard<std::mutex> g(m_mutex);
    if (m_file)
    {
        fclose(m_file);
        m_file = nullptr;
    }
    m_file = fopen(path.c_str(), "a");
    if (!m_file)
    {
        MaNGOS::Singleton<Log>::Instance().Out(LOG_BASIC, LOG_LVL_ERROR, "[BotLog] Failed to open bot log file: %s", path.c_str());
        return;
    }

    std::time_t now = std::time(nullptr);
    std::tm lt{};
#ifdef _WIN32
    localtime_s(&lt, &now);
#else
    localtime_r(&now, &lt);
#endif
    char tsBuf[32];
    std::strftime(tsBuf, sizeof(tsBuf), "%Y-%m-%d %H:%M:%S", &lt);
    // BotLogDebug predates BotLogLevel and is kept as a shorthand for the most
    // verbose setting. Debug is by definition noisier than detail, so asking for
    // it raises the level rather than sitting beside it as a second gate.
    m_level = (debugEnabled && level < LOG_LVL_DEBUG) ? LOG_LVL_DEBUG : level;
    m_debugEnabled = m_level >= LOG_LVL_DEBUG;
    fprintf(m_file, "\n# ---- BotLog session started %s (level %d) ----\n", tsBuf, int(level));
    fflush(m_file);
}

// Format the message into a fixed buffer, then route to file or sLog.
// Using a macro to keep the call-sites DRY while still being able to do
// va_start / va_end in the caller function (va_list can't cross helpers cleanly).
//
// log_level is what the line costs to print, and the file branch checks it
// against the configured level before writing. Callers that arrive through the
// LOG macros in Log.h were already filtered by HasLogLevelOrHigher; the many
// that call out*() directly are only filtered here.
#define BOTLOG_IMPL(prefix, log_type, log_level)                    \
    if (m_file && (log_level) > m_level) return;        \
    char _msg[4096];                                    \
    va_list _ap;                                        \
    va_start(_ap, fmt);                                 \
    vsnprintf(_msg, sizeof(_msg), fmt, _ap);            \
    va_end(_ap);                                        \
    std::lock_guard<std::mutex> _g(m_mutex);            \
    if (m_file) {                                       \
        std::time_t _now = std::time(nullptr);          \
        std::tm _lt{};                                  \
        localtime_r(&_now, &_lt);                       \
        char _ts[16];                                   \
        std::strftime(_ts, sizeof(_ts), "%H:%M:%S", &_lt); \
        fprintf(m_file, "[%s] %s%s\n", _ts, prefix, _msg); \
        fflush(m_file);                                 \
    } else {                                            \
        MaNGOS::Singleton<Log>::Instance().Out(log_type, log_level, "%s", _msg);            \
    }

#ifdef _WIN32
// localtime_r is POSIX; use localtime_s on Windows
#undef BOTLOG_IMPL
#define BOTLOG_IMPL(prefix, log_type, log_level)                    \
    if (m_file && (log_level) > m_level) return;        \
    char _msg[4096];                                    \
    va_list _ap;                                        \
    va_start(_ap, fmt);                                 \
    vsnprintf(_msg, sizeof(_msg), fmt, _ap);            \
    va_end(_ap);                                        \
    std::lock_guard<std::mutex> _g(m_mutex);            \
    if (m_file) {                                       \
        std::time_t _now = std::time(nullptr);          \
        std::tm _lt{};                                  \
        localtime_s(&_lt, &_now);                       \
        char _ts[16];                                   \
        std::strftime(_ts, sizeof(_ts), "%H:%M:%S", &_lt); \
        fprintf(m_file, "[%s] %s%s\n", _ts, prefix, _msg); \
        fflush(m_file);                                 \
    } else {                                            \
        MaNGOS::Singleton<Log>::Instance().Out(log_type, log_level, "%s", _msg);            \
    }
#endif

void BotLog::outString()
{
    std::lock_guard<std::mutex> g(m_mutex);
    if (m_file)
    {
        fprintf(m_file, "\n");
        fflush(m_file);
    }
    else
        MaNGOS::Singleton<Log>::Instance().Out(LOG_BASIC, LOG_LVL_MINIMAL, " ");
}

void BotLog::outString(const char* fmt, ...)
{
    BOTLOG_IMPL("", LOG_BASIC, LOG_LVL_MINIMAL)
}

void BotLog::outInfo(const char* fmt, ...)
{
    BOTLOG_IMPL("[INFO] ", LOG_BASIC, LOG_LVL_BASIC)
}

void BotLog::outDetail(const char* fmt, ...)
{
    BOTLOG_IMPL("[DETAIL] ", LOG_BASIC, LOG_LVL_DETAIL)
}

void BotLog::outError(const char* fmt, ...)
{
    BOTLOG_IMPL("[ERROR] ", LOG_BASIC, LOG_LVL_ERROR)
}

void BotLog::outDebug(const char* fmt, ...)
{
    if (!m_debugEnabled)
    {
        // Debug suppressed by default; fall through to sLog when no file is open.
        std::lock_guard<std::mutex> g(m_mutex);
        if (!m_file)
        {
            char _msg[4096];
            va_list _ap;
            va_start(_ap, fmt);
            vsnprintf(_msg, sizeof(_msg), fmt, _ap);
            va_end(_ap);
            MaNGOS::Singleton<Log>::Instance().Out(LOG_BASIC, LOG_LVL_DEBUG, "%s", _msg);
        }
        return;
    }
    BOTLOG_IMPL("[DEBUG] ", LOG_BASIC, LOG_LVL_DEBUG)
}

void BotLog::outBasic(const char* fmt, ...)
{
    BOTLOG_IMPL("[BASIC] ", LOG_BASIC, LOG_LVL_BASIC)
}

void BotLog::outErrorDb(const char* fmt, ...)
{
    BOTLOG_IMPL("[ERROR_DB] ", LOG_DBERROR, LOG_LVL_ERROR)
}

void BotLog::Out(LogType logType, LogLevel logLevel, const char* fmt, ...)
{
    char msg[4096];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(msg, sizeof(msg), fmt, ap);
    va_end(ap);

    MaNGOS::Singleton<Log>::Instance().Out(logType, logLevel, "%s", msg);
}
