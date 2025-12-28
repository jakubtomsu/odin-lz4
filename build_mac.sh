#!/bin/bash
set -e

# Build lz4 static libraries for macOS (universal: arm64 + x86_64)

# lz4
clang -c c/lz4.c -I c/include -o lz4_arm64.o -O2 -arch arm64
clang -c c/lz4.c -I c/include -o lz4_x86_64.o -O2 -arch x86_64
lipo -create -output lz4/lz4_macos_universal.a lz4_arm64.o lz4_x86_64.o
rm lz4_arm64.o lz4_x86_64.o

# lz4hc
clang -c c/lz4hc.c -I c/include -o lz4hc_arm64.o -O2 -arch arm64
clang -c c/lz4hc.c -I c/include -o lz4hc_x86_64.o -O2 -arch x86_64
lipo -create -output lz4hc/lz4hc_macos_universal.a lz4hc_arm64.o lz4hc_x86_64.o
rm lz4hc_arm64.o lz4hc_x86_64.o
