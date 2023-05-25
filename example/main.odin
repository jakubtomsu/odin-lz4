package main

import "core:fmt"
import "core:mem"
import "core:slice"
import "../lz4"

main :: proc() {
    src := transmute([]u8)string(
        `Lorem ipsum dolor sit amet, consectetuer adipiscing elit.
Pellentesque pretium lectus id turpis.
Nullam at arcu a est sollicitudin euismod.
Proin pede metus, vulputate nec, fermentum fringilla,
vehicula vitae, justo. Aliquam erat volutpat. Proin pede metus,
vulputate nec, fermentum fringilla, vehicula vitae, justo. Nunc
auctor. Maecenas libero. Integer malesuada. Itaque earum rerum
hic tenetur a sapiente delectus, ut aut reiciendis voluptatibus
maiores alias consequatur aut perferendis doloribus asperiores 
epellat. Fusce nibh. Fusce wisi. Maecenas sollicitudin. Nullam
sapien sem, ornare ac, nonummy non, lobortis a enim. Quis autem
vel eum iure reprehenderit qui in ea voluptate velit esse quam
nihil molestiae consequatur, vel illum qui dolorem eum fugiat
quo voluptas nulla pariatur? In rutrum. Temporibus autem quibusdam
`,
    )

    fmt.println("Original size:", len(src), "bytes")

    // Example of using the odin wrapper
    {
        decomp_buf := mem.alloc_bytes(size = len(src), allocator = context.temp_allocator) or_else nil
        if decomp_buf == nil do return

        ACCELERATIONS :: [?]i32{lz4.ACCELERATION_DEFAULT, 100, 1000, 10000, lz4.ACCELERATION_MAX}

        for accel, i in ACCELERATIONS {
            if comp, comp_ok := lz4.compress_slice(src, accel, context.temp_allocator); comp_ok {
                fmt.print(
                    "[",
                    i,
                    "] accel:",
                    accel,
                    "compressed_size:",
                    len(comp),
                    "compression_ratio:",
                    f32(len(src)) / f32(len(comp)),
                )

                if decomp, decomp_ok := lz4.decompress_slice(comp, decomp_buf); decomp_ok {
                    fmt.println(" decompressed_correctly:", slice.equal(src, decomp))
                }
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
}
