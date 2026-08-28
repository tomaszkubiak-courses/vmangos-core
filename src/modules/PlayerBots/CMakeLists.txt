#
# Copyright (C) 2005-2018 MaNGOS project <http://getmangos.com/>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

# IKE3's playerbots, by way of the tortoise-wow fork. See doc/PLAYERBOT_PORT_SCOPE.md
# for where this came from and what was changed on the way in.
#
# Differences from the donor's build file:
#   - No Boost. This tree ships none and has its own replacements for the parts of it
#     that carry a dependency, so the module's uses were rewritten. See BotStringAlgo.h.
#   - Only the vanilla expansion. The donor picked one from the CMake project name,
#     which never matched, so vanilla was the accidental default anyway.
#   - Include paths follow this tree's layout, which splits Server/ out of game/.

set(LIBRARY_NAME playerbots)

set(bots_PCH "${CMAKE_CURRENT_SOURCE_DIR}/botpch.h")

file(GLOB Playerbot_Source ${CMAKE_CURRENT_SOURCE_DIR}/playerbot/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/playerbot/*.h)
source_group("Player Bot" FILES ${Playerbot_Source})

file(GLOB AHbot_Source ${CMAKE_CURRENT_SOURCE_DIR}/ahbot/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/ahbot/*.h)
source_group("AH Bot" FILES ${AHbot_Source})

set(LIBRARY_SRCS
    ${Playerbot_Source}
    ${AHbot_Source}
    ${bots_PCH}
    ${CMAKE_CURRENT_SOURCE_DIR}/botpch.cpp
)

# playerbot/strategy/deathknight is absent, unlike in the donor's build file, because the
# directory is gone. The Death Knight class does not exist before 3.0 and this tree only
# ever builds vanilla, so the class AI and every reference to it were deleted rather than
# guarded. Recovering it means going back to the donor, not to an #ifdef here.
foreach(subdir strategy strategy/actions strategy/generic strategy/triggers strategy/values
               strategy/druid strategy/hunter strategy/mage strategy/paladin strategy/priest
               strategy/rogue strategy/shaman strategy/warlock strategy/warrior
               strategy/tests)
  file(GLOB subdir_SRCS ${CMAKE_CURRENT_SOURCE_DIR}/playerbot/${subdir}/*.cpp
                        ${CMAKE_CURRENT_SOURCE_DIR}/playerbot/${subdir}/*.h)
  string(REPLACE "/" "\\\\" group_name ${subdir})
  source_group("Player Bot\\${group_name}" FILES ${subdir_SRCS})
  list(APPEND LIBRARY_SRCS ${subdir_SRCS})
endforeach()

add_library(${LIBRARY_NAME} STATIC ${LIBRARY_SRCS})

# Feature gates the vendored source expects:
#   CMANGOS           - selects the cmangos codepath in the vendored headers, as opposed
#                       to the TrinityCore or MaNGOS-Zero alternates.
#   MANGOSBOT_ZERO    - vanilla. Sets level caps, talent trees, spell ranges. The donor
#                       notes MANGOSBOT_ONE for TBC and MANGOSBOT_TWO for WotLK.
#   ENABLE_PLAYERBOTS - the vendor tree's own ifdef walls.
#   BUILD_PLAYERBOTS  - the core's own gate. src/game/Server/WorldSession.h declares the raw
#                       packet entry points the module calls behind it, and the module does
#                       not link game (only mangosd does), so the PUBLIC definition on that
#                       target does not reach here - set it again.
target_compile_definitions(${LIBRARY_NAME} PRIVATE CMANGOS MANGOSBOT_ZERO ENABLE_PLAYERBOTS BUILD_PLAYERBOTS)

# The core builds at C++14; the vendored tree assumes C++17 - std::string_view in a dozen
# files, inline variables, structured bindings. Rewriting all of that would fork the
# vendored code far enough to make future re-vendoring painful, so this one target gets
# C++17 instead. Mixing standard levels within a toolset is supported by MSVC, GCC and
# Clang alike as long as the standard library and its ABI-affecting flags match, which
# they do here - everything is built in this tree by one compiler.
set_target_properties(${LIBRARY_NAME} PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)

# The vendored source includes core headers by bare name as often as by path
# ("ObjectMgr.h" but also "Maps/MapManager.h"), and which form it uses is not
# consistent, so every game subdirectory goes on the path rather than the dozen the
# donor happened to need. Globbed so a new core subdirectory does not silently break
# the module.
file(GLOB_RECURSE game_dir_markers LIST_DIRECTORIES true ${CMAKE_SOURCE_DIR}/src/game/*)
set(game_include_dirs ${CMAKE_SOURCE_DIR}/src/game)
foreach(entry ${game_dir_markers})
  if(IS_DIRECTORY ${entry})
    list(APPEND game_include_dirs ${entry})
  endif()
endforeach()

target_include_directories(${LIBRARY_NAME}
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/cmangos-compat-stubs
  PRIVATE
    ${game_include_dirs}
    ${CMAKE_SOURCE_DIR}/src/shared
    ${CMAKE_SOURCE_DIR}/src/framework
    ${CMAKE_SOURCE_DIR}/dep/recastnavigation
    ${CMAKE_SOURCE_DIR}/dep/recastnavigation/Detour/Include
    ${CMAKE_SOURCE_DIR}/dep/g3dlite/include
    ${CMAKE_BINARY_DIR}
    ${CMAKE_BINARY_DIR}/src/shared
    ${MYSQL_INCLUDE_DIR}
    ${OPENSSL_INCLUDE_DIR}
)

if(WIN32)
  target_include_directories(${LIBRARY_NAME} PRIVATE ${CMAKE_SOURCE_DIR}/dep/windows/include)
endif()

target_link_libraries(${LIBRARY_NAME}
  PRIVATE shared
  PRIVATE Detour
  PRIVATE g3dlite
)

if (ENABLE_CPPTRACE)
  # MemoryMonitor records a stack per tracked allocation. It used boost::stacktrace;
  # cpptrace is what this tree already vendors for the same job.
  target_link_libraries(${LIBRARY_NAME} PRIVATE cpptrace::cpptrace)
  target_compile_definitions(${LIBRARY_NAME} PRIVATE ENABLE_CPPTRACE)
endif()

if(MSVC)
  # /bigobj: the strategy and action contexts instantiate enough templates in one translation
  # unit to pass the 65,536-section limit of the normal object format (C1128).
  target_compile_options(${LIBRARY_NAME} PRIVATE /bigobj)

  # Constrain the MSVC inliner on this module only, carried over from the donor: the
  # vendored tree is heavily templated (the strategy and action queues, Singleton<>
  # instantiations) and /Ob2 can ICE the optimizer with C1001 while expanding them.
  # /Ob1 honours explicit inline only. Costs a few percent of bot tick throughput and
  # makes the module build deterministically. Every other target keeps /Ob2.
  target_compile_options(${LIBRARY_NAME} PRIVATE $<$<CONFIG:Release>:/Ob1>)
endif()

set_target_properties(${LIBRARY_NAME} PROPERTIES PROJECT_LABEL "PlayerBots" FOLDER "Game Libs")

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/playerbot/aiplayerbot.conf.dist.in ${CMAKE_CURRENT_BINARY_DIR}/aiplayerbot.conf.dist)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/ahbot/ahbot.conf.dist.in ${CMAKE_CURRENT_BINARY_DIR}/ahbot.conf.dist)

if (NOT CONF_INSTALL_DIR)
  set(CONF_INSTALL_DIR ${CONF_DIR})
endif()
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/aiplayerbot.conf.dist DESTINATION ${CONF_INSTALL_DIR})
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/ahbot.conf.dist DESTINATION ${CONF_INSTALL_DIR})

if(USE_PCH)
  target_precompile_headers(${LIBRARY_NAME} PRIVATE ${bots_PCH})
endif()
