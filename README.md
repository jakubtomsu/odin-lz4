# odin-lz4
Odin bindings for the [LZ4 library](https://github.com/lz4/lz4).

> LZ4 is lossless compression algorithm, providing compression speed > 500 MB/s per core, scalable with multi-cores CPU. It features an extremely fast decoder, with speed in multiple GB/s per core, typically reaching RAM speed limits on multi-core systems.

## Usage
Import the packages:
```odin
import "project:lz4"
import "project:lz4hc"
```

Compress data:
```odin
data := [?]byte{1, 2, 3, 4, 5}
compressed := lz4.compress_slice(data) or_return
hc_compressed := lz4hc.compress_slice(data) or_return
```

Decompress data:
```odin
decompressed_buf := mem.alloc_bytes(orig_size) // You need to store the original size separately.
// Decompress data from LZ4 or LZ4HC
decompressed := lz4.decompress(compressed, decompressed_buf) or_return
```

## Features
- LZ4
  - simple functions
  - advanced functions
  - streaming functions (WIP: implemented but not fully tested!)
- LZ4HC
  - block compression
  - streaming compression (WIP: implemented but not fully tested!)

Frame and file support isn't implemented. I might implement them if ever need them.

## Contributing
All contributions are welcome! I will merge any pull requests with meaningful work, whether that is small bug fixes, odin helpers or missing API implementation.
