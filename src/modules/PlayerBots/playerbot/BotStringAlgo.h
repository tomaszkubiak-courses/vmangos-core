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

#ifndef MANGOS_BOT_STRING_ALGO_H
#define MANGOS_BOT_STRING_ALGO_H

// The five boost::algorithm/string functions the vendored bot code used, and nothing
// more. VMaNGOS ships no Boost and deliberately wrote its own replacements for the
// parts of it that carry a real dependency (see src/shared/IO/README.md), so pulling
// the whole library in for case-insensitive compares was not worth it.
//
// Semantics match Boost: iequals and istarts_with ignore case, contains does not, and
// the trims modify in place. ASCII case folding only, which is all the callers do -
// they compare against literals like "healer", "tank", "LFG".

#include <algorithm>
#include <cctype>
#include <string>

namespace botstr
{
    inline char to_lower_ascii(char c)
    {
        return static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }

    inline bool iequals(std::string const& left, std::string const& right)
    {
        if (left.size() != right.size())
            return false;

        return std::equal(left.begin(), left.end(), right.begin(),
            [](char a, char b) { return to_lower_ascii(a) == to_lower_ascii(b); });
    }

    inline bool istarts_with(std::string const& text, std::string const& prefix)
    {
        if (prefix.size() > text.size())
            return false;

        return std::equal(prefix.begin(), prefix.end(), text.begin(),
            [](char a, char b) { return to_lower_ascii(a) == to_lower_ascii(b); });
    }

    inline bool contains(std::string const& haystack, std::string const& needle)
    {
        return haystack.find(needle) != std::string::npos;
    }

    inline void trim_left(std::string& text)
    {
        auto const first = std::find_if(text.begin(), text.end(),
            [](char c) { return !std::isspace(static_cast<unsigned char>(c)); });
        text.erase(text.begin(), first);
    }

    inline void trim_right(std::string& text)
    {
        auto const last = std::find_if(text.rbegin(), text.rend(),
            [](char c) { return !std::isspace(static_cast<unsigned char>(c)); });
        text.erase(last.base(), text.end());
    }

    inline void trim(std::string& text)
    {
        trim_right(text);
        trim_left(text);
    }
}

#endif
