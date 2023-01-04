#import "SyphonServerRendererMetal.h"
#import <Metal/Metal.h>
#include <simd/simd.h>
#include "SyphonServerMetalTypes.h"

@implementation SyphonServerRendererMetal
{
    id<MTLRenderPipelineState> _pipelineState;
}

- (nonnull instancetype)initWithDevice:(id<MTLDevice>)device colorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    self = [super init];
    if( self )
    {
        NSError *error = NULL;
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        id<MTLLibrary> defaultLibrary = [device newDefaultLibraryWithBundle:bundle error:&error];
        if(error)
        {
            SYPHONLOG(@"Metal library could not be loaded:%@", error);
        }
        
        // Load the vertex/shader function from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"textureToScreenVertexShader"];
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"textureToScreenSamplingShader"];
        
        [defaultLibrary release];
        
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [MTLRenderPipelineDescriptor new];
        pipelineStateDescriptor.label = @"Syphon Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat;
        
        _pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        
        [vertexFunction release];
        [fragmentFunction release];
        
        if( !_pipelineState )
        {
            SYPHONLOG(@"Failed to createe pipeline state, error %@", error);
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    [_pipelineState release];
    [super dealloc];
}

- (void)renderFromTexture:(id<MTLTexture>)offScreenTexture inTexture:(id<MTLTexture>)texture region:(NSRect)region onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer flip:(BOOL)flip
{
    if( texture == nil )
    {
        return;
    }
    
    const MTLViewport viewport = (MTLViewport){region.origin.x, region.origin.y, region.size.width, region.size.height, -1.0, 1.0 };
    vector_uint2 viewportSize = simd_make_uint2(viewport.width, viewport.height);
    
    const float w = viewport.width/2;
    const float h = viewport.height/2;
    const float flipValue = flip ? 1 : -1;
    
    const SYPHONTextureVertex quadVertices[] =
    {
        // Pixel positions (NDC), Texture coordinates
        { {  w,   flipValue * h },  { 1.f, 1.f } },
        { { -w,   flipValue * h },  { 0.f, 1.f } },
        { { -w,  flipValue * -h },  { 0.f, 0.f } },
        
        { {  w,  flipValue * h },  { 1.f, 1.f } },
        { { -w,  flipValue * -h },  { 0.f, 0.f } },
        { {  w,  flipValue * -h },  { 1.f, 0.f } },
    };
    
    const NSUInteger numberOfVertices = sizeof(quadVertices) / sizeof(SYPHONTextureVertex);
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    renderPassDescriptor.colorAttachments[0].texture = texture;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    // Create a render command encoder so we can render into something
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    renderEncoder.label = @"Syphon Server Render Encoder";
    [renderEncoder setViewport:viewport];
    [renderEncoder setRenderPipelineState:_pipelineState];
    [renderEncoder setVertexBytes:quadVertices length:sizeof(quadVertices) atIndex:SYPHONVertexInputIndexVertices];
    [renderEncoder setVertexBytes:&viewportSize length:sizeof(viewportSize) atIndex:SYPHONVertexInputIndexViewportSize];
    [renderEncoder setFragmentTexture:offScreenTexture atIndex:SYPHONTextureIndexZero];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:numberOfVertices];
    [renderEncoder endEncoding];
}

@end
