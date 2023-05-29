package main

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:os"
import "core:time"
import "core:sys/windows"
import "../lz4"
import lz4hc "../lz4hc"

main :: proc() {
    windows.timeBeginPeriod(1)

    if len(os.args) < 2 {
        fmt.println("Missing argument: please provide a path for test file.")
        return
    }

    src := os.read_entire_file(os.args[1]) or_else nil
    if src == nil do return

    fmt.printf("Original size: %i (%i MB)\n", len(src), len(src) / mem.Megabyte)

    decomp_buf := mem.alloc_bytes(size = len(src), allocator = context.temp_allocator) or_else nil
    if decomp_buf == nil do return

    // Example of using the odin wrapper
    {
        ACCELERATIONS :: [?]i32{lz4.ACCELERATION_DEFAULT, 100, 1000, 10000, lz4.ACCELERATION_MAX}

        for accel, i in ACCELERATIONS {
            defer fmt.println()
            start := time.now()
            if comp, comp_ok := lz4.compress_slice(src, accel, context.temp_allocator); comp_ok {
                fmt.printf(
                    "[%i] accel: % 7i, comp_size: % 8i bytes (%i MB) (% 5.2f%%), ratio: % 3.2f, comp_time: % .2f ms",
                    i,
                    accel,
                    len(comp),
                    len(comp) / mem.Megabyte,
                    100.0 * f32(len(comp)) / f32(len(src)),
                    f32(len(src)) / f32(len(comp)),
                    time.duration_milliseconds(time.since(start)),
                )

                start = time.now()
                if decomp, decomp_ok := lz4.decompress_slice(comp, decomp_buf); decomp_ok {
                    fmt.printf(
                        " decomp_valid: %t, decomp_time: % .2f ms",
                        slice.equal(src, decomp),
                        time.duration_milliseconds(time.since(start)),
                    )
                } else {
                    fmt.print(" Failed to decompress.")
                }
            } else {
                fmt.print("Failed to compress.")
            }
        }
    }

    // Example of using bindings directly
    {
        //
        // Compression
        //

        max_dst_size := lz4.compressBound(i32(len(src)))
        compressed_data := mem.alloc_bytes(int(max_dst_size)) or_else nil
        assert(compressed_data != nil, "Failed to allocate memory for *compressed_data.")
        defer delete(compressed_data)

        compressed_data_size := lz4.compress_default(
            &src[0],
            &compressed_data[0],
            i32(len(src)),
            max_dst_size,
        )
        assert(
            compressed_data_size > 0,
            "A 0 or negative result from lz4.compress_default() indicates a failure trying to compress the data.",
        )
        if compressed_data_size > 0 {
            fmt.println("We successfully compressed some data!")
            fmt.println("Compression ratio:", f32(len(src)) / f32(compressed_data_size))
        }
        // Not only does a positive return_value mean success, the value returned == the number of bytes required.
        // You can use this to realloc() *compress_data to free up memory, if desired.  We'll do so just to demonstrate the concept.
        compressed_data = mem.resize_bytes(compressed_data, int(compressed_data_size)) or_else nil
        assert(compressed_data != nil, "Failed to re-alloc memory for compressed_data.")

        //
        // Decompression
        //

        // First, let's create a *new_src location of size src_size since we know that value.
        regen_buffer := mem.alloc_bytes(len(src)) or_else nil
        assert(regen_buffer != nil, "Failed to allocate regen_buffer.")
        defer delete(regen_buffer)

        decompressed_size := lz4.decompress_safe(
            &compressed_data[0],
            &regen_buffer[0],
            compressed_data_size,
            i32(len(src)),
        )

        assert(
            decompressed_size >= 0,
            "A negative result from lz4.decompress_safe indicates a failure trying to decompress the data.  See exit code (echo $?) for value returned.",
        )

        fmt.println("We successfully decompressed some data!")

        assert(len(src) == int(decompressed_size), "Decompressed size is different than the source size.")
        assert(slice.equal(src, regen_buffer[:decompressed_size]), "Decompressed contains different data")
    }

    // HC wrapper example
    for clevel, i in lz4hc.CLEVEL_MIN ..< lz4hc.CLEVEL_MAX {
        defer fmt.println()
        start := time.now()
        if comp, comp_ok := lz4hc.compress_slice(src, i32(clevel), context.temp_allocator); comp_ok {
            fmt.printf(
                "[%i] comp_level: % 3i, comp_size: % 8i bytes (%i MB) (% 5.2f%%), ratio: % 3.2f, comp_time: % .2f ms",
                i,
                clevel,
                len(comp),
                len(comp) / mem.Megabyte,
                100.0 * f32(len(comp)) / f32(len(src)),
                f32(len(src)) / f32(len(comp)),
                time.duration_milliseconds(time.since(start)),
            )

            start = time.now()
            if decomp, decomp_ok := lz4.decompress_slice(comp, decomp_buf); decomp_ok {
                fmt.printf(
                    " decomp_valid: %t, decomp_time: % .2f ms",
                    slice.equal(src, decomp),
                    time.duration_milliseconds(time.since(start)),
                )
            }
        } else {
            fmt.print(" Failed to compress.")
        }
    }
}
