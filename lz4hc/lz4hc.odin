package lz4hc

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
CLEVEL_MIN :: 3
CLEVEL_DEFAULT :: 9
CLEVEL_OPT_MIN :: 10
CLEVEL_MAX :: 12

when ODIN_OS == .Windows {
    when ODIN_DEBUG {
        foreign import lib "lz4hc_windows_x64_debug.lib"
    } else {
        foreign import lib "lz4hc_windows_x64_release.lib"
    }
}

@(default_calling_convention = "c", link_prefix = "LZ4_")
foreign lib {

    ////////////////////////////////////////////////////////////////////////////////////////////
    // Block Compression
    //

    // Compress data from `src` into `dst`, using the powerful but slower "HC" algorithm.
    // `dst` must be already allocated.
    // Compression is guaranteed to succeed if `dstCapacity >= compressBound(srcSize)` (see "lz4.h")
    // Max supported `srcSize` value is MAX_INPUT_SIZE (see "lz4.h")
    // `compressionLevel` : any value between 1 and HC_CLEVEL_MAX will work.
    // Values > HC_CLEVEL_MAX behave the same as HC_CLEVEL_MAX.
    // Note: Decompression functions are provided within "lz4.h" (BSD license)
    //
    // @return : the number of bytes written into 'dst' or 0 if compression fails.
    compress_HC :: proc(src: [^]byte, dst: [^]byte, srcSize: c.int, dstCapacity: c.int, compressionLevel: c.int) -> c.int ---


    // Same as compress_HC(), but using an externally allocated memory segment for `state`.
    // `state` size is provided by sizeofStateHC().
    // Memory segment must be aligned on 8-bytes boundaries (which a normal malloc() should do properly).
    compress_HC_extStateHC :: proc(stateHC: rawptr, src: [^]byte, dst: [^]byte, srcSize: c.int, maxDstSize: c.int, compressionLevel: c.int) -> c.int ---
    sizeofStateHC :: proc() -> c.int ---


    // Will compress as much data as possible from `src` to fit into `targetDstSize` budget.
    // Result is provided in 2 parts :
    // @return : the number of bytes written into 'dst' (necessarily <= targetDstSize)
    // or 0 if compression fails.
    // `srcSizePtr` : on success, *srcSizePtr is updated to indicate how much bytes were read from `src`
    compress_HC_destSize :: proc(stateHC: rawptr, src: [^]byte, dst: [^]byte, srcSizePtr: ^c.int, targetDstSize: c.int, compressionLevel: c.int) -> c.int ---


    ////////////////////////////////////////////////////////////////////////////////////////////
    // Streaming Compression
    // Bufferless synchronous API
    //

    // These functions create and release memory for LZ4 HC streaming state.
    // Newly created states are automatically initialized.
    // A same state can be used multiple times consecutively,
    // starting with resetStreamHC_fast() to start a new stream of blocks.
    createStreamHC :: proc() -> ^stream_t ---
    freeStreamHC :: proc(streamPtr: ^stream_t) -> c.int ---

    // These functions compress data in successive blocks of any size,
    // using previous blocks as dictionary, to improve compression ratio.
    // One key assumption is that previous blocks (up to 64 KB) remain read-accessible while compressing next blocks.
    // There is an exception for ring buffers, which can be smaller than 64 KB.
    // Ring-buffer scenario is automatically detected and handled within compress_HC_continue().
    // 
    // Before starting compression, state must be allocated and properly initialized.
    // createStreamHC() does both, though compression level is set to HC_CLEVEL_DEFAULT.
    // 
    // Selecting the compression level can be done with resetStreamHC_fast() (starts a new stream)
    // or setCompressionLevel() (anytime, between blocks in the same stream) (experimental).
    // resetStreamHC_fast() only works on states which have been properly initialized at least once,
    // which is automatically the case when state is created using createStreamHC().
    // 
    // After reset, a first "fictional block" can be designated as initial dictionary,
    // using loadDictHC() (Optional).
    // 
    // Invoke compress_HC_continue() to compress each successive block.
    // The number of blocks is unlimited.
    // Previous input blocks, including initial dictionary when present,
    // must remain accessible and unmodified during compression.
    // 
    // It's allowed to update compression level anytime between blocks,
    // using setCompressionLevel() (experimental).
    // 
    // 'dst' buffer should be sized to handle worst case scenarios
    // (see compressBound(), it ensures compression success).
    // In case of failure, the API does not guarantee recovery,
    // so the state _must_ be reset.
    // To ensure compression success
    // whenever `dst` buffer size cannot be made >= compressBound(),
    // consider using compress_HC_continue_destSize().
    // 
    // Whenever previous input blocks can't be preserved unmodified in-place during compression of next blocks,
    // it's possible to copy the last blocks into a more stable memory space, using saveDictHC().
    // Return value of saveDictHC() is the size of dictionary effectively saved into 'safeBuffer' (<= 64 KB)
    // 
    // After completing a streaming compression,
    // it's possible to start a new stream of blocks, using the same stream_t state,
    // just by resetting it, using resetStreamHC_fast().

    resetStreamHC_fast :: proc(streamPtr: ^stream_t, compressionLevel: c.int) ---
    loadDictHC :: proc(streamPtr: ^stream_t, dictionary: [^]byte, dictSize: c.int) -> c.int ---

    compress_HC_continue :: proc(streamPtr: ^stream_t, src: [^]byte, dst: [^]byte, srcSize: c.int, maxDstSize: c.int) -> c.int ---

    // Similar to compress_HC_continue(),
    // but will read as much data as possible from `src`
    // to fit into `targetDstSize` budget.
    // Result is provided into 2 parts :
    // @return : the number of bytes written into 'dst' (necessarily <= targetDstSize)
    // or 0 if compression fails.
    // `srcSizePtr` : on success, *srcSizePtr will be updated to indicate how much bytes were read from `src`.
    // Note that this function may not consume the entire input.
    compress_HC_continue_destSize :: proc(streamPtr: ^stream_t, src: [^]byte, dst: [^]byte, srcSizePtr: ^c.int, targetDstSize: c.int) -> c.int ---

    saveDictHC :: proc(streamPtr: ^stream_t, safeBuffer: [^]byte, maxDictSize: c.int) -> c.int ---

} // foreign lib


// PRIVATE DEFINITIONS :
// Do not use these definitions directly.
// They are merely exposed to allow static allocation of `stream_t`.
// Declare an `stream_t` directly, rather than any type below.
// Even then, only do so in the context of static linking, as definitions may change between versions.

DICTIONARY_LOGSIZE :: 16
MAXD :: (1 << DICTIONARY_LOGSIZE)
MAXD_MASK :: (MAXD - 1)

HASH_LOG :: 15
HASHTABLESIZE :: (1 << HASH_LOG)
HASH_MASK :: (HASHTABLESIZE - 1)

// Never ever use these definitions directly !
// Declare or allocate an stream_t instead.
CCtx_internal :: struct {
    hashTable:        [HASHTABLESIZE]u32,
    chainTable:       [MAXD]u16,
    end:              [^]byte, /* next block here to continue on current prefix */
    prefixStart:      [^]byte, /* Indexes relative to this position */
    dictStart:        [^]byte, /* alternate reference for extDict */
    dictLimit:        u32, /* below that point, need extDict */
    lowLimit:         u32, /* below that point, no more dict */
    nextToUpdate:     u32, /* index from which to continue dictionary update */
    compressionLevel: i16,
    favorDecSpeed:    i8, /* favor decompression speed if this flag set, otherwise, favor compression ratio */
    dirty:            i8, /* stream has to be fully reset if this flag is set */
    dictCtx:          ^CCtx_internal,
}

// static size, for inter-version compatibility
STREAM_MINSIZE :: 262200

// stream_t :
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
stream_t :: struct #raw_union {
    minStateSize:      [STREAM_MINSIZE]byte,
    internal_donotuse: CCtx_internal,
}
