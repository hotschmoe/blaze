  Blade's Architecture

  Language & Bindings:
  - Written in Rust, uses ash crate for Vulkan bindings (raw unsafe FFI)
  - gpu-alloc + gpu-alloc-ash for GPU memory allocation
  - naga for WGSL shader parsing and SPIR-V compilation

  Multi-backend Design:
  blade-graphics/src/
    vulkan/     # Vulkan backend
    metal/      # Metal backend (macOS/iOS)
    gles/       # OpenGL ES backend
    lib.rs      # Unified API
    traits.rs   # Backend-agnostic traits

  Key Abstractions:
  ┌─────────────────┬────────────────────────────────┬───────────────────────────────────────────────────┐
  │   Blade Type    │             Wraps              │                       Notes                       │
  ├─────────────────┼────────────────────────────────┼───────────────────────────────────────────────────┤
  │ Device          │ ash::Device + extensions       │ Holds swapchain, debug utils, timeline semaphores │
  ├─────────────────┼────────────────────────────────┼───────────────────────────────────────────────────┤
  │ Buffer          │ vk::Buffer + memory handle     │ Includes mapped_data pointer                      │
  ├─────────────────┼────────────────────────────────┼───────────────────────────────────────────────────┤
  │ Queue           │ vk::Queue + timeline semaphore │ Progress tracking for sync                        │
  ├─────────────────┼────────────────────────────────┼───────────────────────────────────────────────────┤
  │ ComputePipeline │ vk::Pipeline + layout          │ Descriptor set layouts bundled                    │
  └─────────────────┴────────────────────────────────┴───────────────────────────────────────────────────┘
  Shader Workflow:
  1. WGSL source -> naga parser
  2. Validation with capability checks
  3. Binding resolution (match shader vars to descriptor groups)
  4. SPIR-V generation at pipeline creation time

  vs. BLAZE Approach:
  ┌───────────────┬────────────────────────┬────────────────────────────────────┐
  │    Aspect     │      Blade (Rust)      │            BLAZE (Zig)             │
  ├───────────────┼────────────────────────┼────────────────────────────────────┤
  │ Bindings      │ ash crate              │ vulkan-zig (generated from vk.xml) │
  ├───────────────┼────────────────────────┼────────────────────────────────────┤
  │ Memory        │ gpu-alloc library      │ Manual (findMemoryType)            │
  ├───────────────┼────────────────────────┼────────────────────────────────────┤
  │ Shaders       │ Runtime naga parsing   │ Pre-compiled SPIR-V (for now)      │
  ├───────────────┼────────────────────────┼────────────────────────────────────┤
  │ Loading       │ Static linking via ash │ Dynamic loading (loader.zig)       │
  ├───────────────┼────────────────────────┼────────────────────────────────────┤
  │ Multi-backend │ Yes (Metal, GLES)      │ No (Vulkan-only)                   │
  └───────────────┴────────────────────────┴────────────────────────────────────┘
  Key Takeaways for BLAZE:
  1. Blade uses timeline semaphores as primary sync (we planned this)
  2. gpu-alloc is a sophisticated allocator - we could build similar or keep simple
  3. naga integration is powerful - comptime WGSL parsing would be even better in Zig
  4. Their trait system (ResourceDevice, ShaderDevice, etc.) is a good abstraction pattern
