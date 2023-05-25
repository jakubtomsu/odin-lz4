package lz4

import "core:mem"

compress_slice :: proc(
    src: []byte,
    acceleration: i32 = ACCELERATION_DEFAULT,
    allocator := context.allocator,
) -> (
    []byte,
    bool,
) {
    if dst, dst_err := mem.alloc_bytes_non_zeroed(
        int(compressBound(i32(len(src)))),
        mem.DEFAULT_ALIGNMENT,
        allocator,
    ); dst_err == .None {
        compressed_size := compress_fast(
            src = &src[0],
            dst = &dst[0],
            srcSize = i32(len(src)),
            dstCapacity = i32(len(dst)),
            acceleration = acceleration,
        )

        if compressed_size > 0 {
            // Note: we're returing a slice of the original allocation, could that cause issues when deleting..?
            return dst[:compressed_size], true
        }

        delete(dst)
        return nil, false
    }

    return nil, false
}

decompress_slice :: proc(src: []byte, dst: []byte) -> ([]byte, bool) {
    decompressed_size := decompress_safe(
        src = &src[0],
        dst = &dst[0],
        compressedSize = i32(len(src)),
        dstCapacity = i32(len(dst)),
    )

    if decompressed_size >= 0 {
        return dst[:decompressed_size], true
    }

    return nil, false
}
