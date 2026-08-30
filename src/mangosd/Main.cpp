/*
 * Copyright (C) 2005-2011 MaNGOS <http://getmangos.com/>
 * Copyright (C) 2009-2011 MaNGOSZero <https://github.com/mangos/zero>
 * Copyright (C) 2011-2016 Nostalrius <https://nostalrius.org>
 * Copyright (C) 2016-2017 Elysium Project <https://github.com/elysium-project>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

// \addtogroup mangosd Mangos Daemon
// @{
// \file

#include "Common.h"
#include "Database/DatabaseEnv.h"
#include "Config/Config.h"
#include "ProgressBar.h"
#include "Log.h"
#include "Master.h"
#include "SystemConfig.h"
#include "revision.h"
#include "ArgparserForServer.h"

#include "Crypto/InitializeCrypto.h"
#include "CrashDump.h"
#include "Errors.h"

#ifdef WIN32
#include <stdio.h>
#endif

#ifdef WIN32
#include "ServiceWin32.h"
char serviceName[] = "mangosd";
char serviceLongName[] = "MaNGOS world service";
char serviceDescription[] = "Massive Network Game Object Server";
/*
 * -1 - not in service mode
 *  0 - stopped
 *  1 - running
 *  2 - paused
 */
volatile int m_ServiceStatus = -1;
#else
#include "PosixDaemon.h"
#endif

DatabaseType WorldDatabase;                                 // Accessor to the world database
DatabaseType CharacterDatabase;                             // Accessor to the character database
DatabaseType LoginDatabase;                                 // Accessor to the realm/login database
DatabaseType LogsDatabase;                                  // Accessor to the logs database

uint32 realmID;                                             // Id of the realm
std::string realmName;                                      // Name of the realm

char const* g_mainLogFileName = "Server.log";

// Launch the mangos server
#ifdef WIN32

#ifdef BUILD_PLAYERBOTS
// Defined in the playerbots module. SC_PHASE stamps these per thread, so the
// crashing thread can say which bot subsystem it was in even when the stack has
// been inlined past recognition.
namespace ai { namespace botdiag {
    extern thread_local char const* gLastPhaseTag;
    extern thread_local char const* gLastPhaseBotName;
}}

// Kept apart from the filter because it needs __try, which MSVC will not accept
// in a function that has objects to unwind.
static void LogLastBotPhase()
{
    char const* tag = ai::botdiag::gLastPhaseTag;
    char const* botName = ai::botdiag::gLastPhaseBotName;

    if (!tag)
        return;

    // gLastPhaseBotName points into the Player object itself. If a freed Player
    // is what killed us, reading the name faults too - and that is worth saying
    // out loud, because it narrows the crash to a use-after-free on the spot.
    __try
    {
        sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Last bot phase on this thread: %s (bot %s)",
            tag, botName ? botName : "<unknown>");
    }
    __except (EXCEPTION_EXECUTE_HANDLER)
    {
        sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL,
            "Last bot phase on this thread: %s (bot name unreadable - the Player it pointed at is gone)", tag);
    }
}
#endif

// An access violation on Windows does not raise SIGSEGV, so Master::_OnSignal
// never sees it and the process disappears with nothing in the log - which is
// exactly what a crash under bots looked like. Log the stack on the way out.
static LONG WINAPI MangosUnhandledExceptionFilter(EXCEPTION_POINTERS* pException)
{
    if (pException && pException->ExceptionRecord)
    {
        EXCEPTION_RECORD const* record = pException->ExceptionRecord;

        sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Unhandled exception 0x%08X at address 0x%p",
            uint32(record->ExceptionCode), record->ExceptionAddress);

        // The address the code went for is the whole question on a use-after-free:
        // a small value is a null dereference, a plausible-looking heap address is
        // a pointer to something that has been freed, and 0xDDDDDDDDDDDDDDDD and
        // friends are the debug allocator's fill patterns.
        if (record->ExceptionCode == EXCEPTION_ACCESS_VIOLATION && record->NumberParameters >= 2)
        {
            char const* operation = "read";
            if (record->ExceptionInformation[0] == 1)
                operation = "write";
            else if (record->ExceptionInformation[0] == 8)
                operation = "execute";

            sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Access violation: %s of address 0x%p",
                operation, reinterpret_cast<void*>(record->ExceptionInformation[1]));
        }
    }
    else
        sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Unhandled exception");

#ifdef BUILD_PLAYERBOTS
    LogLastBotPhase();
#endif

    MaNGOS::Errors::PrintStacktrace(0, 64);

    if (char const* dumpPath = MaNGOS::CrashDump::Write(pException))
        sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Crash dump written to %s", dumpPath);
    else
        sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Could not write a crash dump");

    return EXCEPTION_CONTINUE_SEARCH; // let Windows report the crash as it would have
}
#endif

extern int main(int argc, char **argv)
{
#ifdef WIN32
    SetUnhandledExceptionFilter(&MangosUnhandledExceptionFilter);

    // The Windows CRT caps a process at 512 simultaneously open FILE streams
    // by default. mangosd shares that budget between the world log files, the
    // DBC/map/vmap/mmap loaders, the MySQL client and anything a module keeps
    // open, and it is reachable: a 200-bot run with per-bot action logs
    // enabled crossed it 39 minutes in, after which every unrelated fopen in
    // the process failed - reported as 152 "VMapManager2: could not load"
    // errors for model files that were on disk and intact. Raise the ceiling
    // so an unrelated subsystem cannot starve map loading.
    _setmaxstdio(2048);
#endif

    ServerStartupArguments args;
    {
        // parseResult is std::expected, where the error is the return code, that might be present when invalid args or "--help" is given
        auto parseResult = ParseServerStartupArguments(argc, argv);
        if (!parseResult)
            return parseResult.error();

        args = parseResult.value();
    }

    if (args.configFilePath.empty())
        args.configFilePath = _MANGOSD_CONFIG;

    if (!sConfig.LoadFromFile(args.configFilePath)) // must be done before (linux) service init
    {
        sLog.Out(LOG_BASIC, LOG_LVL_ERROR, "Could not find or parse configuration file %s", args.configFilePath.c_str());
        Log::WaitBeforeContinueIfNeed();
        return EXIT_FAILURE;
    }

    sLog.OpenWorldLogFiles();

    // Before anything can crash, and while reading the config is still safe.
    MaNGOS::CrashDump::Initialize(sConfig.GetStringDefault("LogsDir", ""));

    switch (args.inputServiceMode)
    {
        case ServiceDaemonAction::NotSet:
            break;
#ifdef WIN32
            // windows service command need execute before config read
        case ServiceDaemonAction::Install:
            sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Installing service...");
            return WinServiceInstall() ? EXIT_SUCCESS : EXIT_FAILURE;
        case ServiceDaemonAction::Uninstall:
            sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Uninstalling service...");
            return WinServiceUninstall() ? EXIT_SUCCESS : EXIT_FAILURE;
        case ServiceDaemonAction::Start:
            sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Starting service...");
            return WinServiceRun() ? EXIT_SUCCESS : EXIT_FAILURE;
#else
            // posix daemon commands need apply after config read
    case ServiceDaemonAction::Start:
        startDaemon();
        break;
    case ServiceDaemonAction::Stop:
        stopDaemon();
        break;
#endif
    }

    sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "\n\n"
        "MM     MM MM   MM         MM   MM  MMMMM   MMMMM   MMMMM\n"
        "MM     MM MM   MM         MM   MM MMM MMM MM   MM MMM MMM\n"
        " MM   MM  MMM MMM         MMM  MM MMM MMM MM   MM MMM\n"
        " MM   MM  MM M MM  MMMMM  MMMM MM MMM     MM   MM  MMM\n"
        "  MM MM   MM M MM M   MMM MM MMMM MMM     MM   MM   MMM\n"
        "  MM MM   MM M MM     MMM MM  MMM MMMMMMM MM   MM    MMM\n"
        "   MMM    MM   MM MMMMMMM MM   MM MM  MMM MM   MM     MMM\n"
        "   MMM    MM   MM MM  MMM MM   MM MMM MMM MM   MM MMM MMM\n"
        "    M     MM   MM MM  MMM MM   MM  MMMMMM  MMMMM   MMMMM\n"
        "                  MMMMMM\n"
        "                          https://github.com/vmangos\n\n");
    sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Core revision: %s [world-daemon]", _FULLVERSION);
    if (!Crypto::InitializeCryptoAndPrintVersion())
    {
        sLog.WaitBeforeContinueIfNeed();
        return EXIT_FAILURE;
    }

    sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "<Ctrl-C> to stop.");
    sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Using configuration file %s", sConfig.GetFilename().c_str());

    // Set progress bars show mode
    BarGoLink::SetOutputState(sConfig.GetBoolDefault("ShowProgressBars", true));

    // and run the 'Master'
    // TODO: Why do we need this 'Master'? Can't all of this be in the Main as for Realmd?
    return sMaster.Run();

    // at sMaster return function exist with codes
    // 0 - normal shutdown
    // 1 - shutdown at error
    // 2 - restart command used, this code can be used by restarter for restart mangosd
}

// @}
