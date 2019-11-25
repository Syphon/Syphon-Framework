#import "SyphonServerRendererMetal.h"
#import <Metal/Metal.h>



#include <simd/simd.h>

typedef enum AAPLVertexInputIndex
{
    AAPLVertexInputIndexVertices     = 0,
    AAPLVertexInputIndexViewportSize =  1,
} AAPLVertexInputIndex;


typedef enum AAPLTextureIndex
{
    AAPLTextureIndexBaseColor = 0,
} AAPLTextureIndex;

typedef struct
{
    vector_float2 position;
    vector_float4 color;
} AAPLColorVertex;

typedef struct
{
    vector_float2 position;
    vector_float2 textureCoordinate;
} AAPLTextureVertex;

NSString *types = @""
"#include <simd/simd.h>\n"
"typedef enum AAPLVertexInputIndex\n"
"{"
"    AAPLVertexInputIndexVertices     = 0,\n"
"    AAPLVertexInputIndexViewportSize =  1,\n"
"} AAPLVertexInputIndex;\n"
"typedef enum AAPLTextureIndex\n"
"{"
"    AAPLTextureIndexBaseColor = 0,\n"
"} AAPLTextureIndex;\n"
"typedef struct\n"
"{"
"    vector_float2 position;\n"
"    vector_float4 color;\n"
"} AAPLColorVertex;\n"
"typedef struct\n"
"{"
"    vector_float2 position;\n"
"    vector_float2 textureCoordinate;\n"
"} AAPLTextureVertex;\n";

NSString *shaderCode = @""
"#include <metal_stdlib>\n"
"#include <simd/simd.h>\n"
"using namespace metal;\n"
"typedef struct\n"
"{"
"    float4 clipSpacePosition [[position]];\n"
"    float4 color;\n"
"    float2 textureCoordinate;\n"
"} RasterizerData;\n"
"vertex RasterizerData textureToScreenVertexShader(uint vertexID [[ vertex_id ]], constant AAPLTextureVertex *vertexArray [[ buffer(AAPLVertexInputIndexVertices) ]], constant vector_uint2 *viewportSizePointer  [[ buffer(AAPLVertexInputIndexViewportSize) ]]){"
"RasterizerData out;"
"float2 pixelSpacePosition = vertexArray[vertexID].position.xy;"
"float2 viewportSize = float2(*viewportSizePointer);"
"out.clipSpacePosition.xy = pixelSpacePosition / (viewportSize / 2.0);"
"out.clipSpacePosition.z = 0.0;"
"out.clipSpacePosition.w = 1.0;"
"out.textureCoordinate = vertexArray[vertexID].textureCoordinate;"
"return out;"
"}\n"

"fragment float4 textureToScreenSamplingShader(RasterizerData in [[stage_in]], texture2d<half> colorTexture [[ texture(AAPLTextureIndexBaseColor) ]]) {"
"    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);"
"    const half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);"
"    return float4(colorSample);"
"}";


@implementation SyphonServerRendererMetal
{
    id<MTLRenderPipelineState> renderToTexturePipelineState;
    MTLPixelFormat colorPixelFormat;
    id<MTLDevice> device;
}

- (nonnull instancetype)initWithDevice:(id<MTLDevice>)theDevice pixelFormat:(MTLPixelFormat)pixelFormat
{
    self = [super init];
    if( self )
    {
        colorPixelFormat = pixelFormat;
        device = theDevice;
        
        NSError *error = NULL;
        
        NSString *code = [types stringByAppendingString:shaderCode];
        MTLCompileOptions *compileOptions = [MTLCompileOptions new];
        compileOptions.languageVersion = MTLLanguageVersion1_2;
        id<MTLLibrary> defaultLibrary = [device newLibraryWithSource:code options:compileOptions error:&error];
        if( error )
        {
            SYPHONLOG(@"SHADER COMPILER ERROR:%@", error);
        }
        
        // Load the vertex/shader function from the library
        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"textureToScreenVertexShader"];
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"textureToScreenSamplingShader"];
        
        // Set up a descriptor for creating a pipeline state object
        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Syphon Flip Texture Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = pixelFormat;
        
        renderToTexturePipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        if( !renderToTexturePipelineState )
        {
            SYPHONLOG(@"Failed to created flip texture pipeline state, error %@", error);
            return nil;
        }
    }
    return self;
}

- (void)drawTexture:(id<MTLTexture>)texture inTexture:(id<MTLTexture>)renderTexture withCommandBuffer:(id<MTLCommandBuffer>)buffer flipped:(BOOL)isFlipped
{
    MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    
    if( renderPassDescriptor != nil )
    {
        // Render to texture
        renderPassDescriptor.colorAttachments[0].texture = renderTexture;
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        
        float w = texture.width/2;
        float h = texture.height/2;
        
        AAPLTextureVertex quadVertices[6];
        quadVertices[0].position = vector2(w, -h);
        quadVertices[1].position = vector2(-w, -h);
        quadVertices[2].position = vector2(-w, h);
        quadVertices[3].position = vector2(w, -h);
        quadVertices[4].position = vector2(-w, h);
        quadVertices[5].position = vector2(w, h);
        
        if( isFlipped )
        {
            quadVertices[0].textureCoordinate = vector2(0.f, 1.f);
            quadVertices[1].textureCoordinate = vector2(1.f, 1.f);
            quadVertices[2].textureCoordinate = vector2(1.f, 0.f);
            quadVertices[3].textureCoordinate = vector2(0.f, 1.f);
            quadVertices[4].textureCoordinate = vector2(1.f, 0.f);
            quadVertices[5].textureCoordinate = vector2(0.f, 0.f);
        }
        else
        {
            quadVertices[0].textureCoordinate = vector2(1.f, 0.f);
            quadVertices[1].textureCoordinate = vector2(0.f, 0.f);
            quadVertices[2].textureCoordinate = vector2(0.f, 1.f);
            quadVertices[3].textureCoordinate = vector2(1.f, 0.f);
            quadVertices[4].textureCoordinate = vector2(0.f, 1.f);
            quadVertices[5].textureCoordinate = vector2(1.f, 1.f);
        }
        
        NSUInteger numberOfVertices =  sizeof(quadVertices) / sizeof(AAPLTextureVertex);
        MTLViewport viewport = (MTLViewport){0.0, 0.0, texture.width, texture.height, -1.0, 1.0 };
        vector_uint2 _viewportSize = {(uint)texture.width, (uint)texture.height};
        id <MTLRenderCommandEncoder> renderEncoder = [buffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"Syphon FlipTexture encoder";
        [renderEncoder setViewport:viewport];
        [renderEncoder setRenderPipelineState:renderToTexturePipelineState];
        [renderEncoder setVertexBytes:quadVertices length:sizeof(quadVertices) atIndex:AAPLVertexInputIndexVertices];
        [renderEncoder setVertexBytes:&_viewportSize length:sizeof(_viewportSize)atIndex:AAPLVertexInputIndexViewportSize];
        [renderEncoder setFragmentTexture:texture atIndex:AAPLTextureIndexBaseColor];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:numberOfVertices];
        [renderEncoder endEncoding];
    }
}

@end
