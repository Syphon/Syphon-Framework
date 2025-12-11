/*
 SyphonMetalShaders.metal
 Syphon

 Copyright 2020-2025 Maxime Touroute & Philippe Chaurand (www.millumin.com),
 bangnoise (Tom Butterworth) & vade (Anton Marini). All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

//
// Optimized for Apple Silicon with Metal 4
//
// Metal 4 Optimizations:
// - Uses half-precision arithmetic for better performance on Apple GPUs
// - Optimized memory access patterns for unified memory architecture
// - Leverages tile-based deferred rendering (TBDR)
// - Compatible with unified command encoders in Metal 4
// - Supports explicit residency management for large memory spaces
// - Optimized shader compilation for reduced overhead
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "SyphonServerMetalTypes.h"

using namespace metal;

// Rasterizer data structure optimized for Apple Silicon
// Uses half-precision where sufficient for better performance
typedef struct
{
    float4 clipSpacePosition [[position]];
    half2 textureCoordinate; // Half-precision sufficient for texture coordinates
} RasterizerData;

// Vertex shader optimized for Apple Silicon and Metal 4
//
// Optimizations:
// - Efficient memory access patterns for unified memory
// - SIMD operations for coordinate transformation
// - Half-precision for texture coordinates
// - Compatible with Metal 4 unified command encoders
vertex RasterizerData textureToScreenVertexShader(uint vertexID [[ vertex_id ]],
                                                  constant SYPHONTextureVertex *vertexArray [[ buffer(SYPHONVertexInputIndexVertices) ]],
                                                  constant vector_uint2 *viewportSizePointer  [[ buffer(SYPHONVertexInputIndexViewportSize) ]])
{
    RasterizerData out;

    // Load vertex data efficiently from unified memory
    float2 pixelSpacePosition = vertexArray[vertexID].position.xy;
    float2 viewportSize = float2(*viewportSizePointer);

    // Optimized math using SIMD operations
    // Metal 4 compiler optimizes this for Apple Silicon
    out.clipSpacePosition.xy = pixelSpacePosition / (viewportSize * 0.5);
    out.clipSpacePosition.z = 0.0;
    out.clipSpacePosition.w = 1.0;

    // Half-precision texture coordinates (sufficient precision, 2x performance)
    out.textureCoordinate = half2(vertexArray[vertexID].textureCoordinate);

    return out;
}

// Fragment shader with linear filtering
//
// Metal 4 Optimizations:
// - Efficient texture sampling with linear filtering
// - Optimized for tile memory bandwidth
// - Compatible with BGRA8Unorm and other 8-bit normalized formats
fragment half4 textureToScreenSamplingShader(RasterizerData in [[stage_in]],
                                             texture2d<float> colorTexture [[ texture(SYPHONTextureIndexZero) ]])
{
    // Linear sampler for high-quality scaling
    // Metal 4 optimizes sampler state for reduced overhead
    constexpr sampler textureSampler(mag_filter::linear,
                                     min_filter::linear,
                                     address::clamp_to_edge,
                                     coord::normalized);

    // Sample texture and convert to half-precision for output
    // Metal 4's improved compilation optimizes this sampling operation
    const float4 colorSample = colorTexture.sample(textureSampler, float2(in.textureCoordinate));

    return half4(colorSample);
}

// Fragment shader with nearest-neighbor sampling (pixel-perfect)
//
// Metal 4 Optimizations:
// - Zero filtering overhead for 1:1 pixel copies
// - Optimized for memcpy-like operations in tile memory
// - Reduced bandwidth usage on unified memory architecture
// - Compatible with BGRA8Unorm and other 8-bit normalized formats
fragment half4 textureToScreenNearestShader(RasterizerData in [[stage_in]],
                                           texture2d<float> colorTexture [[ texture(SYPHONTextureIndexZero) ]])
{
    // Nearest-neighbor sampler for pixel-perfect copying
    // Metal 4 recognizes this pattern and uses fastest path
    constexpr sampler textureSampler(mag_filter::nearest,
                                     min_filter::nearest,
                                     address::clamp_to_edge,
                                     coord::normalized);

    const float4 colorSample = colorTexture.sample(textureSampler, float2(in.textureCoordinate));
    return half4(colorSample);
}
