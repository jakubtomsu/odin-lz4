// LZ4 is lossless compression algorithm, providing compression speed >500 MB/s per core,
// scalable with multi-cores CPU. It features an extremely fast decoder, with speed in
// multiple GB/s per core, typically reaching RAM speed limits on multi-core systems.
// 
// The LZ4 compression library provides in-memory compression and decompression functions.
// It gives full buffer control to user.
// Compression can be done in:
// - a single step (described as Simple Functions)
// - a single step, reusing a context (described in Advanced Functions)
// - unbounded multiple steps (described as Streaming compression)
// 
// lz4.h generates and decodes LZ4-compressed blocks (doc/Block_format.md).
// Decompressing such a compressed block requires additional metadata.
// Exact metadata depends on exact decompression function.
// For the typical case of decompress_safe(),
// metadata includes block's compressed size, and maximum bound of decompressed size.
// Each application is free to encode and pass such metadata in whichever way it wants.
// 
// lz4.h only handle blocks, it can not generate Frames.
// 
// Blocks are different from Frames (doc/Frame_format.md).
// Frames bundle both blocks and metadata in a specified manner.
// Embedding metadata is required for compressed data to be self-contained and portable.
// Frame format is delivered through a companion API, declared in lz4frame.h.
// The `lz4` CLI can only manage frames.
package lz4

import "core:c"


// Note: to tweak the constants you also need to recompile the C files!

// Version

VERSION_MAJOR :: 1 // for breaking interface changes
VERSION_MINOR :: 9 // for new (non-breaking) interface capabilities
VERSION_RELEASE :: 4 // for tweaks, bug-fixes, or development
VERSION :: VERSION_MAJOR * 100 * 100 + VERSION_MINOR * 100 + VERSION_RELEASE

MAX_INPUT_SIZE :: 0x7E000000 // 2 113 929 216 bytes

// Select "acceleration" for compress_fast() when parameter value <= 0
ACCELERATION_DEFAULT :: 1
// Any "acceleration" value higher than this threshold get treated as ACCELERATION_MAX instead (fix #876)
ACCELERATION_MAX :: 65537

when ODIN_OS == .Windows {
    when ODIN_DEBUG {
        foreign import lib "lz4_windows_x64_debug.lib"
    } else {
        foreign import lib "lz4_windows_x64_release.lib"
    }
}

@(default_calling_convention = "c", link_prefix = "LZ4_")
foreign lib {
    // library version number useful to check dll version requires v1.3.0+
    versionNumber :: proc() -> c.int ---

    // library version string useful to check dll version requires v1.7.5+
    versionString :: proc() -> cstring ---

    ////////////////////////////////////////////////////////////////////////////////////////////
    // Simple Functions
    //

    // Compresses 'srcSize' bytes from buffer 'src'
    // into already allocated 'dst' buffer of size 'dstCapacity'.
    // Compression is guaranteed to succeed if 'dstCapacity' >= compressBound(srcSize).
    // It also runs faster, so it's a recommended setting.
    // If the function cannot compress 'src' into a more limited 'dst' budget,
    // compression stops *immediately*, and the function result is zero.
    // In which case, 'dst' content is undefined (invalid).
    //     srcSize : max supported value is MAX_INPUT_SIZE.
    //     dstCapacity : size of buffer 'dst' (which must be already allocated)
    // @return  : the number of bytes written into buffer 'dst' (necessarily <= dstCapacity)
    //               or 0 if compression fails
    // Note : This function is protected against buffer overflow scenarios
    //  (never writes outside 'dst' buffer, nor read outside 'source' buffer).
    compress_default :: proc(src: [^]byte, dst: [^]byte, srcSize: c.int, dstCapacity: c.int) -> c.int ---

    // compressedSize: is the exact complete size of the compressed block.
    // @dstCapacity : is the size of destination buffer (which must be already allocated),
    //                is an upper bound of decompressed size.
    // @return : the number of bytes decompressed into destination buffer (necessarily <= dstCapacity)
    //           If destination buffer is not large enough, decoding will stop and output an error code (negative value).
    //           If the source stream is detected malformed, the function will stop decoding and return a negative result.
    // Note 1 : This function is protected against malicious data packets :
    //          it will never writes outside 'dst' buffer, nor read outside 'source' buffer,
    //          even if the compressed block is maliciously modified to order the decoder to do these actions.
    //          In such case, the decoder stops immediately, and considers the compressed block malformed.
    // Note 2 : compressedSize and dstCapacity must be provided to the function, the compressed block does not contain them.
    //          The implementation is free to send / store / derive this information in whichever way is most beneficial.
    //          If there is a need for a different format which bundles together both compressed data and its metadata, consider looking at lz4frame.h instead.
    decompress_safe :: proc(src: [^]byte, dst: [^]byte, compressedSize: c.int, dstCapacity: c.int) -> c.int ---


    ////////////////////////////////////////////////////////////////////////////////////////////
    // Advanced Functions
    //

    // Provides the maximum size that LZ4 compression may output in a "worst case" scenario (input data not compressible)
    // This function is primarily useful for memory allocation purposes (destination buffer size).
    // Macro COMPRESSBOUND() is also provided for compilation-time evaluation (stack memory allocation for example).
    // Note that compress_default() compresses faster when dstCapacity is >= compressBound(srcSize)
    // @param inputSize : max supported value is MAX_INPUT_SIZE
    // @return : maximum output size in a "worst case" scenario or 0, if input size is incorrect (too large or negative)
    compressBound :: proc(inputSize: c.int) -> c.int ---

    // Same as compress_default(), but allows selection of "acceleration" factor.
    // The larger the acceleration value, the faster the algorithm, but also the lesser the compression.
    // It's a trade-off. It can be fine tuned, with each successive value providing roughly +~3% to speed.
    // An acceleration value of "1" is the same as regular compress_default()
    // Values <= 0 will be replaced by ACCELERATION_DEFAULT (currently == 1, see lz4.c).
    // Values > ACCELERATION_MAX will be replaced by ACCELERATION_MAX (currently == 65537, see lz4.c).
    compress_fast :: proc(src: [^]byte, dst: [^]byte, srcSize: c.int, dstCapacity: c.int, acceleration: c.int) -> c.int ---


    // Same as compress_fast(), using an externally allocated memory space for its state.
    // Use sizeofState() to know how much memory must be allocated,
    // and allocate it on 8-bytes boundaries (using `malloc()` typically).
    // Then, provide this buffer as `void* state` to compression function.
    compress_fast_extState :: proc(state: rawptr, src: [^]byte, dst: [^]byte, srcSize: c.int, dstCapacity: c.int, acceleration: c.int) -> c.int ---
    sizeofState :: proc() -> c.int ---

    // Reverse the logic : compresses as much data as possible from 'src' buffer
    // into already allocated buffer 'dst', of size >= 'targetDestSize'.
    // This function either compresses the entire 'src' content into 'dst' if it's large enough,
    // or fill 'dst' buffer completely with as much data as possible from 'src'.
    // note: acceleration parameter is fixed to "default".
    //
    // *srcSizePtr : will be modified to indicate how many bytes where read from 'src' to fill 'dst'.
    //               New value is necessarily <= input value.
    // @return : Nb bytes written into 'dst' (necessarily <= targetDestSize)
    //           or 0 if compression fails.
    //
    // Note : from v1.8.2 to v1.9.1, this function had a bug (fixed un v1.9.2+):
    //        the produced compressed content could, in specific circumstances,
    //        require to be decompressed into a destination buffer larger
    //        by at least 1 byte than the content to decompress.
    //        If an application uses `compress_destSize()`,
    //        it's highly recommended to update liblz4 to v1.9.2 or better.
    //        If this can't be done or ensured,
    //        the receiving decompression function should provide
    //        a dstCapacity which is > decompressedSize, by at least 1 byte.
    //        See https://github.com/lz4/lz4/issues/859 for details
    compress_destSize :: proc(src: [^]byte, dst: [^]byte, srcSizePtr: ^c.int, targetDstSize: c.int) -> c.int ---

    // Decompress an LZ4 compressed block, of size 'srcSize' at position 'src',
    // into destination buffer 'dst' of size 'dstCapacity'.
    // Up to 'targetOutputSize' bytes will be decoded.
    // The function stops decoding on reaching this objective.
    // This can be useful to boost performance
    // whenever only the beginning of a block is required.
    //
    // @return : the number of bytes decoded in `dst` (necessarily <= targetOutputSize)
    //           If source stream is detected malformed, function returns a negative result.
    //
    // Note 1 : @return can be < targetOutputSize, if compressed block contains less data.
    //
    // Note 2 : targetOutputSize must be <= dstCapacity
    //
    // Note 3 : this function effectively stops decoding on reaching targetOutputSize,
    //           so dstCapacity is kind of redundant.
    //           This is because in older versions of this function,
    //           decoding operation would still write complete sequences.
    //           Therefore, there was no guarantee that it would stop writing at exactly targetOutputSize,
    //           it could write more bytes, though only up to dstCapacity.
    //           Some "margin" used to be required for this operation to work properly.
    //           Thankfully, this is no longer necessary.
    //           The function nonetheless keeps the same signature, in an effort to preserve API compatibility.
    //
    // Note 4 : If srcSize is the exact size of the block,
    //           then targetOutputSize can be any value,
    //           including larger than the block's decompressed size.
    //           The function will, at most, generate block's decompressed size.
    //
    // Note 5 : If srcSize is _larger_ than block's compressed size,
    //           then targetOutputSize **MUST** be <= block's decompressed size.
    //           Otherwise, *silent corruption will occur*.
    decompress_safe_partial :: proc(src: [^]byte, dst: [^]byte, srcSize: c.int, targetOutputSize: c.int, dstCapacity: c.int) -> c.int ---


    ////////////////////////////////////////////////////////////////////////////////////////////
    // Streaming Functions
    //

    // Allocates a stream with the LZ4 allocation functions.
    createStream :: proc() -> ^stream_t ---

    // Free stream from createStream
    freeStream :: proc(streamPtr: ^stream_t) -> c.int ---

    // Use this to prepare an stream_t for a new chain of dependent blocks
    // (e.g., compress_fast_continue()).
    // 
    // An stream_t must be initialized once before usage.
    // This is automatically done when created by createStream().
    // However, should the stream_t be simply declared on stack (for example),
    // it's necessary to initialize it first, using initStream().
    // 
    // After init, start any new stream with resetStream_fast().
    // A same stream_t can be re-used multiple times consecutively
    // and compress multiple streams,
    // provided that it starts each new stream with resetStream_fast().
    // 
    // resetStream_fast() is much faster than initStream(),
    // but is not compatible with memory regions containing garbage data.
    // 
    // Note: it's only useful to call resetStream_fast()
    // in the context of streaming compression.
    // The *extState* functions perform their own resets.
    // Invoking resetStream_fast() before is redundant, and even counterproductive.
    resetStream_fast :: proc(streamPtr: ^stream_t) ---

    // Use this function to reference a static dictionary into stream_t.
    // The dictionary must remain available during compression.
    // loadDict() triggers a reset, so any previous data will be forgotten.
    // The same dictionary will have to be loaded on decompression side for successful decoding.
    // Dictionary are useful for better compression of small data (KB range).
    // While LZ4 accept any input as dictionary,
    // results are generally better when using Zstandard's Dictionary Builder.
    // Loading a size of 0 is allowed, and is the same as reset.
    //
    // @return : loaded dictionary size, in bytes (necessarily <= 64 KB)
    loadDict :: proc(streamPtr: ^stream_t, dictionary: [^]byte, dictSize: c.int) -> c.int ---

    // Compress 'src' content using data from previously compressed blocks, for better compression ratio.
    // 'dst' buffer must be already allocated.
    // If dstCapacity >= compressBound(srcSize), compression is guaranteed to succeed, and runs faster.
    // 
    // @return : size of compressed block or 0 if there is an error (typically, cannot fit into 'dst').
    // 
    // Note 1 : Each invocation to compress_fast_continue() generates a new block.
    // Each block has precise boundaries.
    // Each block must be decompressed separately, calling decompress_*() with relevant metadata.
    // It's not possible to append blocks together and expect a single invocation of decompress_*() to decompress them together.
    // 
    // Note 2 : The previous 64KB of source data is __assumed__ to remain present, unmodified, at same address in memory !
    // 
    // Note 3 : When input is structured as a double-buffer, each buffer can have any size, including < 64 KB.
    // Make sure that buffers are separated, by at least one byte.
    // This construction ensures that each block only depends on previous block.
    // 
    // Note 4 : If input buffer is a ring-buffer, it can have any size, including < 64 KB.
    // 
    // Note 5 : After an error, the stream status is undefined (invalid), it can only be reset or freed.
    compress_fast_continue :: proc(streamPtr: ^stream_t, src: [^]byte, dst: [^]byte, srcSize: c.int, dstCapacity: c.int, acceleration: c.int) -> c.int ---

    // If last 64KB data cannot be guaranteed to remain available at its current memory location,
    // save it into a safer place (char* safeBuffer).
    // This is schematically equivalent to a memcpy() followed by loadDict(),
    // but is much faster, because saveDict() doesn't need to rebuild tables.
    // 
    // @return : saved dictionary size in bytes (necessarily <= maxDictSize), or 0 if error.
    saveDict :: proc(streamPtr: ^stream_t, safeBuffer: [^]byte, maxDictSize: c.int) -> c.int ---
} // foregin lib

// Note: this doesn't work in odin (for fixed-size arrays).
// COMPRESSBOUND :: #force_inline proc($S: uint) -> uint {
//     return S > MAX_INPUT_SIZE ? 0 : S + (S / 255) + 16
// }


MEMORY_USAGE_MIN :: 10
MEMORY_USAGE_DEFAULT :: 14
MEMORY_USAGE_MAX :: 20

// Memory usage formula : N->2^N Bytes (examples : 10 -> 1KB; 12 -> 4KB ; 16 -> 64KB; 20 -> 1MB; )
// Increasing memory usage improves compression ratio, at the cost of speed.
// Reduced memory usage may improve speed at the cost of ratio, thanks to better cache locality.
// Default value is 14, for 16KB, which nicely fits into Intel x86 L1 cache.
MEMORY_USAGE :: MEMORY_USAGE_DEFAULT

HASHLOG :: MEMORY_USAGE - 2
HASHTABLESIZE :: 1 << MEMORY_USAGE
HASH_SIZE_U32 :: 1 << HASHLOG /* required as macro for static allocation */

@(private)
stream_t_internal :: struct {
    hashTable:     [HASH_SIZE_U32]u32,
    dictionary:    [^]byte,
    dictCtx:       ^stream_t_internal,
    currentOffset: u32,
    tableType:     u32,
    dictSize:      u32,
    // Implicit padding to ensure structure is aligned
}

// static size, for inter-version compatibility
STREAM_MINSIZE :: ((1 << MEMORY_USAGE) + 32)

// Never use this directly, this is here only for static allocation.
stream_t :: struct #raw_union {
    minStateSize:      [STREAM_MINSIZE]byte,
    internal_donotuse: stream_t_internal,
}
