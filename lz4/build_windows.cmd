@echo off

cl /c c\lz4.c /I c\include /Folz4.obj /Oi /MT /Zi /D_DEBUG /DEBUG
lib /OUT:lz4_windows_x64_debug.lib lz4.obj

cl /c c\lz4.c /I c\include /Folz4.obj /Oi /O2
lib /OUT:lz4_windows_x64_release.lib lz4.obj


cl /c c\lz4hc.c /I c\include /Folz4.obj /Oi /MT /Zi /D_DEBUG /DEBUG
lib /OUT:lz4hc_windows_x64_debug.lib lz4.obj

cl /c c\lz4hc.c /I c\include /Folz4.obj /Oi /O2
lib /OUT:lz4hc_windows_x64_release.lib lz4.obj


del lz4.obj