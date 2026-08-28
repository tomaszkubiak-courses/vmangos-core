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

#ifndef MANGOS_CRASHDUMP_H
#define MANGOS_CRASHDUMP_H

#include <string>

// Writes a Windows minidump for the thread that just crashed.
//
// A stack trace alone names the function but not the pointer it died on, which
// is the part that matters when the suspect is a use-after-free: the dump has
// the memory the stack referenced, so the freed object can be read back in a
// debugger and identified.
//
// Everything here runs with a possibly corrupted heap, so it allocates nothing
// and touches no globals other than its own fixed buffers.
namespace MaNGOS
{
    namespace CrashDump
    {
        // Remembers where dumps are written. Call once at startup, while the
        // process is still healthy - the crash path must not read the config.
        void Initialize(std::string const& directory);

        // Writes a dump for the current thread from a structured-exception
        // filter. Windows only; does nothing elsewhere. Returns the path
        // written, or nullptr if no dump could be produced. The returned buffer
        // is static and stays valid until the next call.
        char const* Write(void* exceptionPointers);
    }
}

#endif
