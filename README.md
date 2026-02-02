# BLAZE

**Lean GPU abstraction over Vulkan for Zig**

BLAZE is a Zig-native GPU abstraction layer targeting Vulkan 1.3+ on Windows and Linux. It prioritizes ergonomics and modern GPU features over broad hardware compatibility.

## Key Features

- **Comptime Shader Reflection** - Parse WGSL at comptime to generate type-safe bind group layouts. Catch binding mismatches at compile time with zero runtime cost.
- **Comptime Pipeline Configuration** - Vertex layouts derived from struct fields at comptime. No verbose Vulkan boilerplate.
- **Tagged Unions for Commands** - Type-safe command recording without inheritance or trait objects.
- **Explicit Error Sets** - Callers know exactly what can fail.
- **Timeline Semaphores** - Modern synchronization as the primary sync primitive.

## Design Principles

1. Comptime over runtime
2. Explicit over implicit
3. Data-oriented design
4. Zero-cost abstractions
5. Incremental complexity

## Status

🚧 **Work in Progress** - Not ready for production use.

## License

MIT © hotschmoe

---

*Part of the [zig-graphics](https://github.com/hotschmoe/zig-graphics) stack: BLAZE → FORGE → FLUX*
