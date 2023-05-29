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
data := [?]f32{1, 2, 3, 4, 5}
compressed := lz4.compress_slice(data) or_return
hc_compressed := lz4hc.compress_slice(data) or_return
```
