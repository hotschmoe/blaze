//! BLAZE Conformance Test Suite - Pipeline Tests
//!
//! Tests for graphics and compute pipeline creation.
//! Reference: CONFORMANCE.md Category 5: Pipeline Creation

const std = @import("std");
const framework = @import("../framework.zig");

pub const suite = framework.TestSuite{
    .name = "blaze.pipeline",
    .tests = &.{
        // P0 - Critical
        .{ .name = "PIP-001_create_graphics_minimal", .run = createGraphicsMinimal, .priority = .p0 },
        .{ .name = "PIP-003_create_compute", .run = createCompute, .priority = .p0 },
        .{ .name = "PIP-004_vertex_layout_basic", .run = vertexLayoutBasic, .priority = .p0 },
        .{ .name = "PIP-005_vertex_layout_interleaved", .run = vertexLayoutInterleaved, .priority = .p0 },
        .{ .name = "PIP-007_blend_opaque", .run = blendOpaque, .priority = .p0 },
        .{ .name = "PIP-008_blend_alpha", .run = blendAlpha, .priority = .p0 },
        .{ .name = "PIP-011_depth_test_less", .run = depthTestLess, .priority = .p0 },
        .{ .name = "PIP-015_cull_back", .run = cullBack, .priority = .p0 },
        .{ .name = "PIP-018_topology_triangles", .run = topologyTriangles, .priority = .p0 },
        .{ .name = "PIP-021_shader_compile_error", .run = shaderCompileError, .priority = .p0 },

        // P1 - Important
        .{ .name = "PIP-002_create_graphics_full", .run = createGraphicsFull, .priority = .p1 },
        .{ .name = "PIP-006_vertex_layout_instanced", .run = vertexLayoutInstanced, .priority = .p1 },
        .{ .name = "PIP-009_blend_additive", .run = blendAdditive, .priority = .p1 },
        .{ .name = "PIP-010_blend_premultiplied", .run = blendPremultiplied, .priority = .p1 },
        .{ .name = "PIP-012_depth_test_modes", .run = depthTestModes, .priority = .p1 },
        .{ .name = "PIP-013_depth_write_disabled", .run = depthWriteDisabled, .priority = .p1 },
        .{ .name = "PIP-016_cull_front", .run = cullFront, .priority = .p1 },
        .{ .name = "PIP-017_cull_none", .run = cullNone, .priority = .p1 },
        .{ .name = "PIP-019_topology_lines", .run = topologyLines, .priority = .p1 },

        // P2 - Nice to have
        .{ .name = "PIP-014_stencil_basic", .run = stencilBasic, .priority = .p2 },
        .{ .name = "PIP-020_topology_points", .run = topologyPoints, .priority = .p2 },
        .{ .name = "PIP-022_pipeline_cache", .run = pipelineCache, .priority = .p2 },
    },
};

/// PIP-001: Create minimal graphics pipeline (vertex + fragment only).
fn createGraphicsMinimal() framework.TestError!void {
    // TODO: Implement
    // 1. Create minimal vertex shader
    // 2. Create minimal fragment shader
    // 3. Create pipeline with minimal state
    // 4. Verify pipeline is valid
    // 5. Clean up
    return error.NotImplemented;
}

/// PIP-002: Create fully configured graphics pipeline.
fn createGraphicsFull() framework.TestError!void {
    // TODO: Implement
    // 1. Configure all pipeline stages
    // 2. Set all blend/depth/stencil state
    // 3. Create pipeline
    // 4. Verify all state is applied
    // 5. Clean up
    return error.NotImplemented;
}

/// PIP-003: Create compute pipeline.
fn createCompute() framework.TestError!void {
    // TODO: Implement
    // 1. Create compute shader
    // 2. Create compute pipeline
    // 3. Verify pipeline is valid
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-004: Position-only vertex layout.
fn vertexLayoutBasic() framework.TestError!void {
    // TODO: Implement
    // 1. Define position-only vertex format
    // 2. Create pipeline with this layout
    // 3. Render triangle
    // 4. Verify correct output
    // 5. Clean up
    return error.NotImplemented;
}

/// PIP-005: Multiple interleaved vertex attributes.
fn vertexLayoutInterleaved() framework.TestError!void {
    // TODO: Implement
    // 1. Define vertex with position + normal + uv + color
    // 2. Create pipeline with interleaved layout
    // 3. Render and verify all attributes work
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-006: Per-instance vertex attributes.
fn vertexLayoutInstanced() framework.TestError!void {
    // TODO: Implement
    // 1. Define per-vertex and per-instance attributes
    // 2. Create pipeline with instanced layout
    // 3. Render instanced geometry
    // 4. Verify instance data is used
    // 5. Clean up
    return error.NotImplemented;
}

/// PIP-007: No blending (opaque).
fn blendOpaque() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with blending disabled
    // 2. Render overlapping geometry
    // 3. Verify no blending occurs
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-008: Standard alpha blending.
fn blendAlpha() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with alpha blend: src*srcA + dst*(1-srcA)
    // 2. Render semi-transparent geometry
    // 3. Verify correct blending
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-009: Additive blending.
fn blendAdditive() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with additive blend: src + dst
    // 2. Render overlapping geometry
    // 3. Verify colors add together
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-010: Premultiplied alpha blending.
fn blendPremultiplied() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with premultiplied blend
    // 2. Render with premultiplied alpha textures
    // 3. Verify correct blending
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-011: Standard depth test (less).
fn depthTestLess() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with depth test = less
    // 2. Render front and back geometry
    // 3. Verify front occludes back
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-012: Test all depth comparison modes.
fn depthTestModes() framework.TestError!void {
    // TODO: Implement
    // 1. Test less, less_equal, greater, greater_equal, equal, not_equal, always, never
    // 2. Verify each mode works correctly
    // 3. Clean up
    return error.NotImplemented;
}

/// PIP-013: Depth test enabled, write disabled.
fn depthWriteDisabled() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with depth test on, write off
    // 2. Render geometry that should be tested but not written
    // 3. Verify depth buffer unchanged
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-014: Basic stencil test.
fn stencilBasic() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with stencil test enabled
    // 2. Write stencil values
    // 3. Test against stencil buffer
    // 4. Verify correct masking
    // 5. Clean up
    return error.NotImplemented;
}

/// PIP-015: Backface culling.
fn cullBack() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with backface culling
    // 2. Render cube
    // 3. Verify back faces not drawn
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-016: Frontface culling.
fn cullFront() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with frontface culling
    // 2. Render cube
    // 3. Verify front faces not drawn (see inside)
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-017: No culling.
fn cullNone() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with no culling
    // 2. Render both sides of geometry
    // 3. Verify both sides visible
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-018: Triangle list topology.
fn topologyTriangles() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with triangle list topology
    // 2. Render triangles
    // 3. Verify correct rendering
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-019: Line list topology.
fn topologyLines() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with line list topology
    // 2. Render lines
    // 3. Verify correct line rendering
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-020: Point list topology.
fn topologyPoints() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline with point list topology
    // 2. Render points
    // 3. Verify points rendered at correct positions
    // 4. Clean up
    return error.NotImplemented;
}

/// PIP-021: Invalid shader should produce error.
fn shaderCompileError() framework.TestError!void {
    // TODO: Implement
    // 1. Attempt to compile invalid shader
    // 2. Verify appropriate error returned
    // 3. Verify no crash
    return error.NotImplemented;
}

/// PIP-022: Pipeline caching.
fn pipelineCache() framework.TestError!void {
    // TODO: Implement
    // 1. Create pipeline
    // 2. Serialize pipeline cache
    // 3. Create same pipeline with cache
    // 4. Verify faster creation
    // 5. Clean up
    return error.NotImplemented;
}
