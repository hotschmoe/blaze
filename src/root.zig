//! BLAZE - Lean GPU Abstraction over Vulkan
//!
//! Zig-native GPU abstraction layer targeting Vulkan 1.3+ on Windows and Linux.
//! Supports headless compute-only contexts for CI/batch processing.

// Internal modules
const context_mod = @import("context.zig");
const buffer_mod = @import("buffer.zig");
const pipeline_mod = @import("pipeline.zig");
const command_mod = @import("command.zig");
const memory_mod = @import("memory.zig");

// Public API

pub const Context = context_mod.Context;
pub const Config = context_mod.Config;
pub const Mode = context_mod.Mode;
pub const ContextError = context_mod.ContextError;

pub const Buffer = buffer_mod.Buffer;
pub const BufferDesc = buffer_mod.BufferDesc;
pub const BufferUsage = buffer_mod.BufferUsage;
pub const BufferError = buffer_mod.BufferError;

pub const ComputePipeline = pipeline_mod.ComputePipeline;
pub const PipelineError = pipeline_mod.PipelineError;
pub const updateDescriptorSet = pipeline_mod.updateDescriptorSet;

pub const CommandBuffer = command_mod.CommandBuffer;
pub const CommandError = command_mod.CommandError;

pub const MemoryLocation = memory_mod.MemoryLocation;

test "blaze module imports" {
    _ = context_mod;
    _ = buffer_mod;
    _ = pipeline_mod;
    _ = command_mod;
    _ = memory_mod;
}
