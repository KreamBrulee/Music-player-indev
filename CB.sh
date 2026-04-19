#!/bin/bash

cd build
rm -rf *
cmake ..
cmake --build . -j$(nproc)