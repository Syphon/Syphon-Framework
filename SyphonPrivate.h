/*
    SyphonPrivate.h
    Syphon

     Copyright 2010-2011 bangnoise (Tom Butterworth) & vade (Anton Marini).
     All rights reserved.
     
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

// Syphon Framework versions prior to 1.0
// Wupports OpenGl and Metal BGRa8 Only
#define kSyphonDictionaryVersionLegacy 0U

#define kSyphonDictionaryVersion 1U


#ifdef __OBJC__

#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <stdatomic.h> // For SyphonSafeBool

#define kSyphonIdentifier @"info.v002.Syphon"

// NSNotification names for Syphon's distributed notifications
#define SyphonServerAnnounceRequest @"info.v002.Syphon.ServerAnnounceRequest"
#define SyphonServerAnnounce @"info.v002.Syphon.ServerAnnounce"
#define SyphonServerRetire @"info.v002.Syphon.ServerRetire"
#define SyphonServerUpdate @"info.v002.Syphon.ServerUpdate"


// Server-description keys // and content
extern NSString * const SyphonServerDescriptionUUIDKey; // NSString
extern NSString * const SyphonServerDescriptionNameKey; // NSString
extern NSString * const SyphonServerDescriptionAppNameKey; // NSString
// extern NSString * const SyphonServerDescriptionIconKey; // TODO: remove this from here if we continue to reconstruct the icon on the far side rather than pack it
extern NSString * const SyphonServerDescriptionDictionaryVersionKey; // NSNumber as unsigned int
extern NSString * const SyphonServerDescriptionSurfacesKey; // An NSArray of NSDictionaries describing each supported surface type

// Surface-description (dictionary for SyphonServerDescriptionSurfacesKey) keys // and content
extern NSString * const SyphonSurfaceType;
extern NSString * const SyphonSurfaceTypeIOSurface;
extern NSString * const SyphonSurfaceDescriptionPixelFormatKey;
extern NSString * const SyphonSurfaceDescriptionColorPrimariesKey;
extern NSString * const SyphonSurfaceDescriptionTransferFunctionKey;
extern NSString * const SyphonSurfaceDescriptionColorRangeKey;

// SyphonServer options
extern NSString * const SyphonServerOptionIsPrivate;
extern NSString * const SyphonServerOptionAntialiasSampleCount;
extern NSString * const SyphonServerOptionDepthBufferResolution;
extern NSString * const SyphonServerOptionStencilBufferResolution;
extern NSString * const SyphonMetalServerOptionPixelFormat;
extern NSString * const SyphonMetalServerOptionColorPrimaries;
extern NSString * const SyphonMetalServerOptionTransferFunction;
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

NSString *SyphonCreateUUIDString(void) NS_RETURNS_RETAINED;

NSDictionary<NSString *, id> *SyphonIOSurfaceDescriptionFromServerDescription(NSDictionary<NSString *, id> *description);
MTLPixelFormat SyphonMTLPixelFormatFromName(NSString *formatName);
NSString *SyphonNameFromMTLPixelFormat(MTLPixelFormat pixelFormat);
OSType SyphonCVPixelFormatFromMTLPixelFormat(MTLPixelFormat pixelFormat);
NSUInteger SyphonBytesPerElementFromMTLPixelFormat(MTLPixelFormat pixelFormat);
BOOL SyphonColorHintOptionsAreValid(NSDictionary<NSString *, id> *options);

typedef atomic_int_fast32_t SyphonSafeBool;

BOOL SyphonSafeBoolGet(SyphonSafeBool *b);
void SyphonSafeBoolSet(SyphonSafeBool *b, BOOL value);

#endif

#pragma mark Communication Constants
/*
 
 Various constants used as message types in communications.
 
 Groupings are for one sender/receiver pair
 
 */
enum {
    SyphonMessageTypeAddClientForInfo = 0, /* Accompanying data is a NSString with the client's UUID.
											Server will send server description changes, IOSurfaceID changes and server retirement notices. */
	SyphonMessageTypeAddClientForFrames = 1, /* Accompanying data is a NSString with the client's UUID.
											  Server will send new frame notices. */
    SyphonMessageTypeRemoveClientForInfo = 2, /* Accompanying data is a NSString with the client's UUID.
											   Server will stop sending server description changes, IOSurfaceID changes and server retirement notices. */
	SyphonMessageTypeRemoveClientForFrames = 3 /* Accompanying data is a NSString with the client's UUID.
												Server will stop sending new frame notices. */
};

enum {
	SyphonMessageTypeUpdateServerName = 0, /* Accompanying data is the server name as NSString. */
	SyphonMessageTypeNewFrame = 1, /* No accompanying data. */
	SyphonMessageTypeUpdateSurfaceID = 2, /* Accompanying data is an unsigned integer value in a NSNumber representing a new IOSurfaceID */
	SyphonMessageTypeRetireServer = 3 /* No accompanying data. */
};
