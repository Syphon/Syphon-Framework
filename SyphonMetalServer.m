/*
 SyphonMetalServer.m
 Syphon
 
 Copyright 2020-2023 Maxime Touroute & Philippe Chaurand (www.millumin.com),
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

#import "SyphonMetalServer.h"
#import "SyphonServerRendererMetal.h"
#import "SyphonPrivate.h"
#import "SyphonSubclassing.h"

@implementation SyphonMetalServer
{
    id<MTLTexture> _surfaceTexture;
    id<MTLDevice> _device;
    SyphonServerRendererMetal *_renderer;
    MTLPixelFormat _surfacePixelFormat;
    NSDictionary<NSString *, id<NSCoding>> *_surfaceDescription;
}

// These are redeclared from SyphonServerBase.h
@dynamic name;
@dynamic serverDescription;
@dynamic hasClients;

#pragma mark - Lifecycle

- (id)initWithName:(NSString *)name device:(id<MTLDevice>)theDevice options:(NSDictionary<NSString *, id> *)options
{
    self = [super initWithName:name options:options];
    if( self )
    {
        NSString *formatName = options[SyphonMetalServerOptionPixelFormat];
        _surfacePixelFormat = SyphonMTLPixelFormatFromName(formatName);
        if (_surfacePixelFormat == MTLPixelFormatInvalid)
        {
            SYPHONLOG(@"Unsupported Syphon Metal server pixel format: %@", formatName);
            return nil;
        }
        if (!SyphonColorHintOptionsAreValid(options))
        {
            SYPHONLOG(@"Invalid Syphon Metal server color hint options");
            return nil;
        }

        _device = theDevice;
        _surfaceTexture = nil;
        NSMutableDictionary<NSString *, id<NSCoding>> *surfaceDescription = [NSMutableDictionary dictionaryWithObject:SyphonSurfaceTypeIOSurface
                                                                                                                forKey:SyphonSurfaceType];
        NSString *surfacePixelFormatName = SyphonNameFromMTLPixelFormat(_surfacePixelFormat);
        if (surfacePixelFormatName != nil)
        {
            surfaceDescription[SyphonSurfaceDescriptionPixelFormatKey] = surfacePixelFormatName;
        }
        NSString *colorPrimaries = options[SyphonMetalServerOptionColorPrimaries];
        NSString *transferFunction = options[SyphonMetalServerOptionTransferFunction];
        NSString *colorRange = options[SyphonMetalServerOptionColorRange];
        if (colorPrimaries != nil)
        {
            surfaceDescription[SyphonSurfaceDescriptionColorPrimariesKey] = colorPrimaries;
            surfaceDescription[SyphonSurfaceDescriptionTransferFunctionKey] = transferFunction;
            surfaceDescription[SyphonSurfaceDescriptionColorRangeKey] = colorRange;
        }
        _surfaceDescription = [surfaceDescription copy];

        _renderer = [[SyphonServerRendererMetal alloc] initWithDevice:theDevice colorPixelFormat:_surfacePixelFormat];
        if (!_renderer)
        {
            return nil;
        }
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        self = nil;
    }
    return self;
}

- (void)dealloc
{
    [self destroyResources];
}

- (id<MTLDevice>)device
{
    return _device;
}

- (id<MTLTexture>)prepareToDrawFrameOfSize:(NSSize)size
{
    @synchronized (self) {
        BOOL hasSizeChanged = !NSEqualSizes(CGSizeMake(_surfaceTexture.width, _surfaceTexture.height), size);
        if (hasSizeChanged)
        {
            _surfaceTexture = nil;
        }
        if(_surfaceTexture == nil)
        {
            MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:_surfacePixelFormat
                                                                                                  width:size.width
                                                                                                 height:size.height
                                                                                              mipmapped:NO];
            descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
            IOSurfaceRef surface = [self newSurfaceForWidth:size.width height:size.height options:nil];
            if (surface)
            {
                _surfaceTexture = [_device newTextureWithDescriptor:descriptor iosurface:surface plane:0];
                _surfaceTexture.label = @"Syphon Surface Texture";
                CFRelease(surface);
            }
        }
        return _surfaceTexture;
    }
}

- (NSDictionary<NSString *, id<NSCoding>> *)surfaceDescription
{
    return _surfaceDescription;
}

- (unsigned int)serverDescriptionDictionaryVersion
{
    // to aid with compatibilty with existing "legacy" clients
    // any server that supports BGRA8 vends a legacy identifier
    // otherwise we opt into the current version
    return _surfacePixelFormat == MTLPixelFormatBGRA8Unorm ? kSyphonDictionaryVersionLegacy : kSyphonDictionaryVersion;
}

- (NSDictionary<NSString *, id> *)surfaceAttributesForWidth:(size_t)width height:(size_t)height options:(NSDictionary<NSString *,id> *)options
{
    OSType cvPixelFormat = SyphonCVPixelFormatFromMTLPixelFormat(_surfacePixelFormat);
    NSUInteger bytesPerElement = SyphonBytesPerElementFromMTLPixelFormat(_surfacePixelFormat);
    return @{(NSString *)kIOSurfaceIsGlobal: @(YES),
             (NSString *)kIOSurfaceWidth: @(width),
             (NSString *)kIOSurfaceHeight: @(height),
             (NSString *)kIOSurfacePixelFormat: @(cvPixelFormat),
             (NSString *)kIOSurfaceBytesPerElement: @(bytesPerElement)};
}

- (void)destroyResources
{
    @synchronized (self) {
        _surfaceTexture = nil;
    }
    _device = nil;
    _renderer = nil;
}

- (void)stop
{
    [self destroyResources];
    [super stop];
}


#pragma mark - Public API

- (id<MTLTexture>)newFrameImage
{
    @synchronized (self) {
        return _surfaceTexture;
    }
}

- (void)publishFrameTexture:(id<MTLTexture>)textureToPublish onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer imageRegion:(NSRect)region flipped:(BOOL)isFlipped
{
    if(textureToPublish == nil) {
        SYPHONLOG(@"TextureToPublish is nil. Syphon will not publish");
        return;
    }

    if (textureToPublish.pixelFormat != _surfacePixelFormat)
    {
        SYPHONLOG(@"TextureToPublish pixel format (%lu) does not match server format (%lu). Syphon will not publish",
                  (unsigned long)textureToPublish.pixelFormat,
                  (unsigned long)_surfacePixelFormat);
        return;
    }
    
    region = NSIntersectionRect(region, NSMakeRect(0, 0, textureToPublish.width, textureToPublish.height));
    
    id<MTLTexture> destination = [self prepareToDrawFrameOfSize:region.size];
    
    // When possible, use faster blit
    if( !isFlipped && textureToPublish.pixelFormat == destination.pixelFormat
       && textureToPublish.sampleCount == destination.sampleCount
       && !textureToPublish.framebufferOnly)
    {
        id<MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
        blitCommandEncoder.label = @"Syphon Server Optimised Blit commandEncoder";
        [blitCommandEncoder copyFromTexture:textureToPublish
                                sourceSlice:0
                                sourceLevel:0
                               sourceOrigin:MTLOriginMake(region.origin.x, region.origin.y, 0)
                                 sourceSize:MTLSizeMake(region.size.width, region.size.height, 1)
                                  toTexture:destination
                           destinationSlice:0
                           destinationLevel:0
                          destinationOrigin:MTLOriginMake(0, 0, 0)];

        [blitCommandEncoder endEncoding];
    }
    // otherwise, re-draw the frame
    else
    {
        [_renderer renderFromTexture:textureToPublish inTexture:destination region:region onCommandBuffer:commandBuffer flip:isFlipped];
    }
    
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull commandBuffer) {
        [self publish];
    }];
}

@end
