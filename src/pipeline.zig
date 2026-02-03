const vk = @import("vulkan");
const Context = @import("context.zig").Context;

pub const PipelineError = error{
    ShaderModuleCreationFailed,
    PipelineLayoutCreationFailed,
    PipelineCreationFailed,
    DescriptorSetLayoutCreationFailed,
    DescriptorPoolCreationFailed,
    DescriptorSetAllocationFailed,
    OutOfHostMemory,
    OutOfDeviceMemory,
};

pub const ComputePipeline = struct {
    shader_module: vk.ShaderModule,
    descriptor_set_layout: vk.DescriptorSetLayout,
    pipeline_layout: vk.PipelineLayout,
    pipeline: vk.Pipeline,
    descriptor_pool: vk.DescriptorPool,

    pub fn init(ctx: *Context, spirv_code: []const u8, binding_count: u32) PipelineError!ComputePipeline {
        const shader_module = createShaderModule(ctx, spirv_code) catch {
            return error.ShaderModuleCreationFailed;
        };
        errdefer ctx.device.dispatch.destroyShaderModule(ctx.device.handle, shader_module, null);

        const descriptor_set_layout = createDescriptorSetLayout(ctx, binding_count) catch {
            return error.DescriptorSetLayoutCreationFailed;
        };
        errdefer ctx.device.dispatch.destroyDescriptorSetLayout(ctx.device.handle, descriptor_set_layout, null);

        const pipeline_layout = createPipelineLayout(ctx, descriptor_set_layout) catch {
            return error.PipelineLayoutCreationFailed;
        };
        errdefer ctx.device.dispatch.destroyPipelineLayout(ctx.device.handle, pipeline_layout, null);

        const pipeline = createComputePipeline(ctx, shader_module, pipeline_layout) catch {
            return error.PipelineCreationFailed;
        };
        errdefer ctx.device.dispatch.destroyPipeline(ctx.device.handle, pipeline, null);

        const descriptor_pool = createDescriptorPool(ctx, binding_count) catch {
            return error.DescriptorPoolCreationFailed;
        };

        return .{
            .shader_module = shader_module,
            .descriptor_set_layout = descriptor_set_layout,
            .pipeline_layout = pipeline_layout,
            .pipeline = pipeline,
            .descriptor_pool = descriptor_pool,
        };
    }

    pub fn deinit(self: *ComputePipeline, ctx: *Context) void {
        ctx.device.dispatch.destroyDescriptorPool(ctx.device.handle, self.descriptor_pool, null);
        ctx.device.dispatch.destroyPipeline(ctx.device.handle, self.pipeline, null);
        ctx.device.dispatch.destroyPipelineLayout(ctx.device.handle, self.pipeline_layout, null);
        ctx.device.dispatch.destroyDescriptorSetLayout(ctx.device.handle, self.descriptor_set_layout, null);
        ctx.device.dispatch.destroyShaderModule(ctx.device.handle, self.shader_module, null);
        self.* = undefined;
    }

    pub fn allocateDescriptorSet(self: *const ComputePipeline, ctx: *Context) PipelineError!vk.DescriptorSet {
        const layouts = [_]vk.DescriptorSetLayout{self.descriptor_set_layout};
        const alloc_info = vk.DescriptorSetAllocateInfo{
            .descriptor_pool = self.descriptor_pool,
            .descriptor_set_count = 1,
            .p_set_layouts = &layouts,
        };

        var descriptor_set: [1]vk.DescriptorSet = undefined;
        ctx.device.dispatch.allocateDescriptorSets(ctx.device.handle, &alloc_info, &descriptor_set) catch {
            return error.DescriptorSetAllocationFailed;
        };

        return descriptor_set[0];
    }

    fn createShaderModule(ctx: *Context, spirv_code: []const u8) !vk.ShaderModule {
        const create_info = vk.ShaderModuleCreateInfo{
            .code_size = spirv_code.len,
            .p_code = @ptrCast(@alignCast(spirv_code.ptr)),
        };

        return ctx.device.dispatch.createShaderModule(ctx.device.handle, &create_info, null);
    }

    fn createDescriptorSetLayout(ctx: *Context, binding_count: u32) !vk.DescriptorSetLayout {
        var bindings: [16]vk.DescriptorSetLayoutBinding = undefined;
        for (0..@min(binding_count, 16)) |i| {
            bindings[i] = .{
                .binding = @intCast(i),
                .descriptor_type = .storage_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .compute_bit = true },
                .p_immutable_samplers = null,
            };
        }

        const layout_info = vk.DescriptorSetLayoutCreateInfo{
            .binding_count = binding_count,
            .p_bindings = &bindings,
        };

        return ctx.device.dispatch.createDescriptorSetLayout(ctx.device.handle, &layout_info, null);
    }

    fn createPipelineLayout(ctx: *Context, descriptor_set_layout: vk.DescriptorSetLayout) !vk.PipelineLayout {
        const layouts = [_]vk.DescriptorSetLayout{descriptor_set_layout};
        const layout_info = vk.PipelineLayoutCreateInfo{
            .set_layout_count = 1,
            .p_set_layouts = &layouts,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
        };

        return ctx.device.dispatch.createPipelineLayout(ctx.device.handle, &layout_info, null);
    }

    fn createComputePipeline(ctx: *Context, shader_module: vk.ShaderModule, pipeline_layout: vk.PipelineLayout) !vk.Pipeline {
        const stage_info = vk.PipelineShaderStageCreateInfo{
            .stage = .{ .compute_bit = true },
            .module = shader_module,
            .p_name = "main",
            .p_specialization_info = null,
        };

        const pipeline_info = vk.ComputePipelineCreateInfo{
            .stage = stage_info,
            .layout = pipeline_layout,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        };

        var pipeline: [1]vk.Pipeline = undefined;
        _ = try ctx.device.dispatch.createComputePipelines(
            ctx.device.handle,
            .null_handle,
            1,
            @ptrCast(&pipeline_info),
            null,
            &pipeline,
        );

        return pipeline[0];
    }

    fn createDescriptorPool(ctx: *Context, binding_count: u32) !vk.DescriptorPool {
        const pool_size = vk.DescriptorPoolSize{
            .type = .storage_buffer,
            .descriptor_count = binding_count,
        };

        const pool_info = vk.DescriptorPoolCreateInfo{
            .max_sets = 1,
            .pool_size_count = 1,
            .p_pool_sizes = @ptrCast(&pool_size),
        };

        return ctx.device.dispatch.createDescriptorPool(ctx.device.handle, &pool_info, null);
    }
};

pub fn updateDescriptorSet(
    ctx: *Context,
    descriptor_set: vk.DescriptorSet,
    buffers: []const vk.Buffer,
    sizes: []const u64,
) void {
    var buffer_infos: [16]vk.DescriptorBufferInfo = undefined;
    var writes: [16]vk.WriteDescriptorSet = undefined;

    const count = @min(buffers.len, 16);

    for (0..count) |i| {
        buffer_infos[i] = .{
            .buffer = buffers[i],
            .offset = 0,
            .range = sizes[i],
        };

        writes[i] = .{
            .dst_set = descriptor_set,
            .dst_binding = @intCast(i),
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = .storage_buffer,
            .p_image_info = undefined,
            .p_buffer_info = @ptrCast(&buffer_infos[i]),
            .p_texel_buffer_view = undefined,
        };
    }

    ctx.device.dispatch.updateDescriptorSets(ctx.device.handle, @intCast(count), &writes, 0, undefined);
}
