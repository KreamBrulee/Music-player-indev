cd build
rm -rf *
cmake ..
cmake --build . -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"