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

# Link filesystem library if necessary
target_link_libraries(music_player PRIVATE stdc++fs)