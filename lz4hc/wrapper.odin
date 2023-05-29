package lz4hc

import "core:mem"
import "../lz4"

compress_slice :: proc(
    src: []byte,
    compression_level: i32 = CLEVEL_DEFAULT,
    allocator := context.allocator,
) -> (
    []byte,
    bool,
) {
    if dst, dst_err := mem.alloc_bytes_non_zeroed(int(lz4.compressBound(i32(len(src)))), 8, allocator);
       dst_err == .None {

        if state, state_err := mem.alloc_bytes_non_zeroed(int(sizeofStateHC()), 8, context.temp_allocator);
           state_err == .None {
            compressed_size := compress_HC_extStateHC(
                stateHC = &state[0],
                src = &src[0],
                dst = &dst[0],
                srcSize = i32(len(src)),
                maxDstSize = i32(len(dst)),
                compressionLevel = compression_level,
            )

            if compressed_size > 0 {
                // Note: we're returing a slice of the original allocation, could that cause issues when deleting..?
                return dst[:compressed_size], true
            }
        }

        delete(dst)
        return nil, false
    }

    return nil, false
}

// Note: no HC specific decompression. Use lz4.
