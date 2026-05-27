/*
 SyphonMetalServer.h
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

#import <Syphon/SyphonServerBase.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 @relates SyphonServerBase
 If this key is matched with a NSNumber with a BOOL value YES, then the server will be invisible to other Syphon users. You are then responsible for passing the NSDictionary returned by serverDescription to processes which require it to create a SyphonClient. Default is NO.
 */
extern NSString * const SyphonServerOptionIsPrivate;

/*!
 @relates SyphonMetalServer
 Optional `NSString` specifying the pixel format used for the Metal server's published IOSurface. If omitted, the server uses legacy BGRA8 behavior.
*/
extern NSString * const SyphonMetalServerOptionPixelFormat;

/*!
 @relates SyphonMetalServer
 Optional advisory `NSString` describing the color primaries of the published surface. This is a hint only; Syphon does not apply color management.
*/
extern NSString * const SyphonMetalServerOptionColorPrimaries;

/*!
 @relates SyphonMetalServer
 Optional advisory `NSString` describing the transfer function of the published surface. This is a hint only; Syphon does not apply color management.
*/
extern NSString * const SyphonMetalServerOptionTransferFunction;

/*!
 @relates SyphonMetalServer
 Optional advisory `NSString` describing the numeric/color range of the published surface. This is a hint only; Syphon does not apply color management.
*/
extern NSString * const SyphonMetalServerOptionColorRange;

extern NSString * const SyphonPixelFormatBGRA8;
extern NSString * const SyphonPixelFormatRGBA16Float;
extern NSString * const SyphonPixelFormatRGBA32Float;

extern NSString * const SyphonColorPrimariesBT601NTSC;
extern NSString * const SyphonColorPrimariesBT601PAL;
extern NSString * const SyphonColorPrimariesBT709;
extern NSString * const SyphonColorPrimariesBT2020;
extern NSString * const SyphonColorPrimariesP3D65;
extern NSString * const SyphonColorPrimariesPassthrough;

extern NSString * const SyphonTransferFunctionLinear;
extern NSString * const SyphonTransferFunctionSRGB;
extern NSString * const SyphonTransferFunctionGamma22;
extern NSString * const SyphonTransferFunctionBT1886;
extern NSString * const SyphonTransferFunctionPQ;
extern NSString * const SyphonTransferFunctionHLG;
extern NSString * const SyphonTransferFunctionPassthrough;

extern NSString * const SyphonColorRangeFull;
extern NSString * const SyphonColorRangeVideo;
extern NSString * const SyphonColorRangeWide;
extern NSString * const SyphonColorRangePassthrough;

/*!
 A server handles the publishing of frames from one video source to any number of clients.
 
 Frames are published by passing in an existing Metal texture.
 
 Each server represents one video output for your application. If your application produces several video outputs, then they should each have their own server. If your application might have multiple servers running, you should name each server to aid identification by users.
 
 It is safe to access instances of this class across threads.
 */
@interface SyphonMetalServer : SyphonServerBase

/*!
 Creates a new server with the specified human-readable name (which need not be unique) for a `MTLDevice` and given options. The server will be started immediately. Init may fail and return nil if the server could not be started.

 @param name Non-unique human readable server name. This is not required and may be `nil`, but is usually used by clients in their UI to aid identification.
 @param device The `MTLDevice` that textures will be valid and available on for publishing.
 @param options A dictionary containing key-value pairs to specify options for the server. Supported options are `SyphonServerOptionIsPrivate`, `SyphonMetalServerOptionPixelFormat`, and the optional advisory color hint keys. See their descriptions for details.
 @returns A newly intialized SyphonMetalServer. Nil on failure.
*/
- (id)initWithName:(nullable NSString*)name device:(id<MTLDevice>)device options:(nullable NSDictionary<NSString *, id> *)options;

/*!
 The MTLDevice the server uses for drawing.
*/
@property (readonly) id<MTLDevice> device;

/*!
A string representing the name of the server.
*/
@property (nullable, strong) NSString* name;

/*!
A dictionary describing the server. Normally you won't need to access this, however if you created the server as private (using ``SyphonServerOptionIsPrivate``) then you must pass this dictionary to any process in which you wish to create a SyphonClient. You should not rely on the presence of any particular keys in this dictionary.
*/
@property (readonly) NSDictionary<NSString *, id<NSCoding>>* serverDescription;

/*!
`YES` if clients are currently attached, `NO` otherwise. If you generate frames frequently (for instance on a display-link timer), you may choose to test this and only call ``publishFrameTexture:onCommandBuffer:imageRegion:flipped:`` when clients are attached.
*/
@property (readonly) BOOL hasClients;

/*!
 Publishes the part of the texture described in region of the texture to clients. The texture is copied and can be safely modified once this method has returned.
 
 @param textureToPublish The `MTLTexture` you wish to publish on the server.
 @param commandBuffer Your command buffer on which Syphon will write its internal metal commands. You are responsible for comitting this command buffer.
 @param region The sub-region of the texture to publish.
 @param isFlipped `YES` if the texture is vertically flipped in Metal coordinates
*/
- (void)publishFrameTexture:(id<MTLTexture>)textureToPublish onCommandBuffer:(id<MTLCommandBuffer>)commandBuffer imageRegion:(NSRect)region flipped:(BOOL)isFlipped;

/*!
 Returns a `MTLTexture` representing the current output from the server, valid on the server's `MTLDevice`. Call this method every time you wish to access the current server frame. This texture has a limited useful lifetime: you should release it as soon as you are finished drawing with it.
  
 @returns A `MTLTexture` representing the current output from the server. YOU ARE RESPONSIBLE FOR RELEASING THIS OBJECT when you are finished with it.
 */
- (nullable id<MTLTexture>)newFrameImage;

/*!
 Stops the server instance. Use of this method is optional and releasing all references to the server has the same effect.
*/
- (void)stop;

@end

NS_ASSUME_NONNULL_END
