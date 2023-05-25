package lz4

/*
   LZ4 HC - High Compression Mode of LZ4
   Header File
   Copyright (C) 2011-2020, Yann Collet.
   BSD 2-Clause License (http://www.opensource.org/licenses/bsd-license.php)

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are
   met:

       * Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
       * Redistributions in binary form must reproduce the above
   copyright notice, this list of conditions and the following disclaimer
   in the documentation and/or other materials provided with the
   distribution.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES LOSS OF USE,
   DATA, OR PROFITS OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

   You can contact the author at :
   - LZ4 source repository : https://github.com/lz4/lz4
   - LZ4 public forum : https://groups.google.com/forum/#!forum/lz4c
*/

import "core:c"

// Useful constants
HC_CLEVEL_MIN :: 3
HC_CLEVEL_DEFAULT :: 9
HC_CLEVEL_OPT_MIN :: 10
HC_CLEVEL_MAX :: 12


@(default_calling_convention = "c", link_prefix = "LZ4_")
foreign lib {

} // foreign lib


// PRIVATE DEFINITIONS :
// Do not use these definitions directly.
// They are merely exposed to allow static allocation of `streamHC_t`.
// Declare an `streamHC_t` directly, rather than any type below.
// Even then, only do so in the context of static linking, as definitions may change between versions.

HC_DICTIONARY_LOGSIZE :: 16
HC_MAXD :: (1 << HC_DICTIONARY_LOGSIZE)
HC_MAXD_MASK :: (HC_MAXD - 1)

HC_HASH_LOG :: 15
HC_HASHTABLESIZE :: (1 << HC_HASH_LOG)
HC_HASH_MASK :: (HC_HASHTABLESIZE - 1)

// Never ever use these definitions directly !
// Declare or allocate an streamHC_t instead.
HC_CCtx_internal :: struct {
    hashTable:        [HC_HASHTABLESIZE]u32,
    chainTable:       [HC_MAXD]u16,
    end:              [^]byte, /* next block here to continue on current prefix */
    prefixStart:      [^]byte, /* Indexes relative to this position */
    dictStart:        [^]byte, /* alternate reference for extDict */
    dictLimit:        u32, /* below that point, need extDict */
    lowLimit:         u32, /* below that point, no more dict */
    nextToUpdate:     u32, /* index from which to continue dictionary update */
    compressionLevel: i16,
    favorDecSpeed:    i8, /* favor decompression speed if this flag set, otherwise, favor compression ratio */
    dirty:            i8, /* stream has to be fully reset if this flag is set */
    dictCtx:          ^HC_CCtx_internal,
}

// static size, for inter-version compatibility
STREAMHC_MINSIZE :: 262200

// streamHC_t :
// This structure allows static allocation of LZ4 HC streaming state.
// This can be used to allocate statically on stack, or as part of a larger structure.
// 
// Such state **must** be initialized using initStreamHC() before first use.
// 
// Note that invoking initStreamHC() is not required when
// the state was created using createStreamHC() (which is recommended).
// Using the normal builder, a newly created state is automatically initialized.
// 
// Static allocation shall only be used in combination with static linking.
streamHC_t :: struct #raw_union {
    minStateSize:      [STREAMHC_MINSIZE]byte,
    internal_donotuse: HC_CCtx_internal,
}
