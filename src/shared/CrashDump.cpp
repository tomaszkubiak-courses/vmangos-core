/*
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

#include "CrashDump.h"

#include <cstdio>
#include <cstring>
#include <ctime>

#ifdef _WIN32
#include <windows.h>
#include <dbghelp.h>
#pragma comment(lib, "dbghelp.lib")
#endif

namespace
{
    // Fixed buffers: a crash handler cannot rely on the heap.
    char s_directory[512] = { 0 };
    char s_lastDumpPath[640] = { 0 };
}

void MaNGOS::CrashDump::Initialize(std::string const& directory)
{
    s_directory[0] = '\0';

    if (directory.empty())
        return;

    size_t const length = directory.size() < sizeof(s_directory) - 2
        ? directory.size()
        : sizeof(s_directory) - 2;

    memcpy(s_directory, directory.c_str(), length);
    s_directory[length] = '\0';

    char const last = s_directory[length - 1];
    if (last != '/' && last != '\\')
    {
        s_directory[length] = '/';
        s_directory[length + 1] = '\0';
    }
}

#ifndef _WIN32

char const* MaNGOS::CrashDump::Write(void* /*exceptionPointers*/)
{
    return nullptr;
}

#else

char const* MaNGOS::CrashDump::Write(void* exceptionPointers)
{
    if (!exceptionPointers)
        return nullptr;

    time_t const now = time(nullptr);
    tm local;
    if (localtime_s(&local, &now) != 0)
        memset(&local, 0, sizeof(local));

    snprintf(s_lastDumpPath, sizeof(s_lastDumpPath),
        "%smangosd_crash_%04d-%02d-%02d_%02d-%02d-%02d_%lu.dmp",
        s_directory,
        local.tm_year + 1900, local.tm_mon + 1, local.tm_mday,
        local.tm_hour, local.tm_min, local.tm_sec,
        static_cast<unsigned long>(GetCurrentProcessId()));

    HANDLE const file = CreateFileA(s_lastDumpPath, GENERIC_WRITE, 0, nullptr,
        CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);

    if (file == INVALID_HANDLE_VALUE)
        return nullptr;

    MINIDUMP_EXCEPTION_INFORMATION info;
    info.ThreadId = GetCurrentThreadId();
    info.ExceptionPointers = static_cast<EXCEPTION_POINTERS*>(exceptionPointers);
    info.ClientPointers = FALSE;

    // Not MiniDumpWithFullMemory: a world running bots holds several GB and the
    // dump would be unusable. IndirectlyReferencedMemory pulls in what the
    // stacks point at, which covers the object a dangling pointer refers to,
    // and DataSegs covers the singletons. That lands in the tens of MB.
    MINIDUMP_TYPE const type = static_cast<MINIDUMP_TYPE>(
        MiniDumpWithIndirectlyReferencedMemory |
        MiniDumpWithDataSegs |
        MiniDumpWithHandleData |
        MiniDumpWithProcessThreadData |
        MiniDumpWithThreadInfo |
        MiniDumpWithUnloadedModules);

    BOOL const written = MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(),
        file, type, &info, nullptr, nullptr);

    CloseHandle(file);

    if (!written)
    {
        DeleteFileA(s_lastDumpPath);
        return nullptr;
    }

    return s_lastDumpPath;
}

#endif
