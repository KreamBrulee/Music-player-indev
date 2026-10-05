cmake_minimum_required(VERSION 3.15)
project(music_player)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add include directory
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

# Add executable
add_executable(music_player src/main.cpp)

# Find and link required libraries
find_package(Threads REQUIRED)
target_link_libraries(music_player PRIVATE Threads::Threads)

# GCC before 9 ships <filesystem> in a separate library that must be linked
# explicitly. Clang/AppleClang and GCC >= 9 have it built into libstdc++/libc++,
# and libstdc++fs doesn't even exist on macOS, so only link it when needed.
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 9.0)
    target_link_libraries(music_player PRIVATE stdc++fs)
endif()

# ---- Tests (run with: ctest --test-dir build --output-on-failure) ----
option(BUILD_TESTING "Build unit tests" ON)
if(BUILD_TESTING)
    enable_testing()
    add_executable(unit_tests tests/test_utils.cpp)
    add_test(NAME unit_tests COMMAND unit_tests)
endif()
