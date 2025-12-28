#!/bin/bash
set -e

# Build lz4 static libraries for Linux (x86_64)

# lz4
gcc -c c/lz4.c -I c/include -o lz4.o -O2 -m64
ar rcs lz4/lz4_linux_x64.a lz4.o
rm lz4.o

# lz4hc
gcc -c c/lz4hc.c -I c/include -o lz4hc.o -O2 -m64
ar rcs lz4hc/lz4hc_linux_x64.a lz4hc.o
rm lz4hc.o
