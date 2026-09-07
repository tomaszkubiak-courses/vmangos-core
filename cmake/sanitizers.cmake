
# AddressSanitizer support, enabled with -DENABLE_ASAN=ON.
#
# ASan rewrites every load and store to check the memory it touches, and replaces
# the allocator with one that puts guard zones around each block and keeps freed
# blocks poisoned in a quarantine instead of handing them straight back. A
# use-after-free, a heap overflow or a double free then stops the process with the
# faulting stack, the allocating stack and the freeing stack, instead of corrupting
# something that crashes minutes later somewhere unrelated.
#
# It costs roughly 2x run time and 2-3x memory, so it is a diagnostic build, not a
# production one. Leak detection is part of ASan on Linux only; the MSVC runtime
# does not ship it.

if(NOT ENABLE_ASAN)
  return()
endif()

if(MSVC)
  # The flag goes into the global compiler flags rather than MANGOS_CXX_FLAGS
  # because the whole binary has to agree on it. The MSVC standard library
  # annotates std::vector and std::string buffers when ASan is on, and an object
  # compiled without the flag that touches an annotated buffer reports a
  # container-overflow that is not real. Instrumenting the in-tree dependencies
  # under dep/ as well is what keeps those false positives away.
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /fsanitize=address")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /fsanitize=address")

  # ASan is incompatible with incremental linking, and CMake puts /INCREMENTAL in
  # the Debug and RelWithDebInfo linker flags by default.
  foreach(_asan_cfg "" "_DEBUG" "_RELEASE" "_RELWITHDEBINFO" "_MINSIZEREL")
    foreach(_asan_kind EXE SHARED MODULE)
      string(REPLACE "/INCREMENTAL" "" CMAKE_${_asan_kind}_LINKER_FLAGS${_asan_cfg}
             "${CMAKE_${_asan_kind}_LINKER_FLAGS${_asan_cfg}}")
    endforeach()
  endforeach()
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /INCREMENTAL:NO")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /INCREMENTAL:NO")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} /INCREMENTAL:NO")

  # The instrumented binary loads the sanitizer runtime at start-up, so it has to
  # sit next to the executables. It ships with the compiler, in the same directory
  # as cl.exe.
  get_filename_component(ASAN_COMPILER_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)
  find_file(ASAN_RUNTIME_DLL
    NAMES clang_rt.asan_dynamic-x86_64.dll
    HINTS "${ASAN_COMPILER_DIR}"
    NO_DEFAULT_PATH
    DOC "AddressSanitizer runtime shipped with the MSVC toolset"
  )
  if(ASAN_RUNTIME_DLL)
    install(FILES ${ASAN_RUNTIME_DLL} DESTINATION ${LIBS_DIR})
  else()
    message(WARNING
      "ENABLE_ASAN is on, but the AddressSanitizer runtime was not found next to the compiler.\n"
      "The build will succeed and the executables will fail to start. Copy\n"
      "clang_rt.asan_dynamic-x86_64.dll from the MSVC toolset next to them by hand."
    )
  endif()
else()
  # -fno-omit-frame-pointer and -fno-optimize-sibling-calls are what make the
  # reported stacks readable in an optimised build.
  set(ASAN_FLAGS "-fsanitize=address -fno-omit-frame-pointer -fno-optimize-sibling-calls")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${ASAN_FLAGS}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${ASAN_FLAGS}")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=address")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fsanitize=address")
endif()
