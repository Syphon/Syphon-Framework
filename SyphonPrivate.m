/*
    SyphonConstants.c
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

#import "SyphonPrivate.h"

NSString * const SyphonServerDescriptionDictionaryVersionKey = @"SyphonServerDescriptionDictionaryVersionKey";
NSString * const SyphonServerDescriptionUUIDKey = @"SyphonServerDescriptionUUIDKey";
NSString * const SyphonServerDescriptionNameKey = @"SyphonServerDescriptionNameKey";
NSString * const SyphonServerDescriptionAppNameKey = @"SyphonServerDescriptionAppNameKey";
NSString * const SyphonServerDescriptionIconKey = @"SyphonServerDescriptionIconKey";
NSString * const SyphonServerDescriptionSurfacesKey = @"SyphonServerDescriptionSurfacesKey";

NSString * const SyphonSurfaceType = @"SyphonSurfaceType";
NSString * const SyphonSurfaceTypeIOSurface = @"SyphonSurfaceTypeIOSurface";
NSString * const SyphonSurfaceDescriptionPixelFormatKey = @"SyphonSurfaceDescriptionPixelFormatKey";
NSString * const SyphonSurfaceDescriptionColorPrimariesKey = @"SyphonSurfaceDescriptionColorPrimariesKey";
NSString * const SyphonSurfaceDescriptionTransferFunctionKey = @"SyphonSurfaceDescriptionTransferFunctionKey";
NSString * const SyphonSurfaceDescriptionColorRangeKey = @"SyphonSurfaceDescriptionColorRangeKey";

NSString * const SyphonServerOptionIsPrivate = @"SyphonServerOptionIsPrivate";
NSString * const SyphonServerOptionAntialiasSampleCount = @"SyphonServerOptionAntialiasSampleCount";
NSString * const SyphonServerOptionDepthBufferResolution = @"SyphonServerOptionDepthBufferResolution";
NSString * const SyphonServerOptionStencilBufferResolution = @"SyphonServerOptionStencilBufferResolution";
NSString * const SyphonMetalServerOptionPixelFormat = @"SyphonMetalServerOptionPixelFormat";
NSString * const SyphonMetalServerOptionColorPrimaries = @"SyphonMetalServerOptionColorPrimaries";
NSString * const SyphonMetalServerOptionTransferFunction = @"SyphonMetalServerOptionTransferFunction";
NSString * const SyphonMetalServerOptionColorRange = @"SyphonMetalServerOptionColorRange";

NSString * const SyphonPixelFormatBGRA8 = @"SyphonPixelFormatBGRA8";
NSString * const SyphonPixelFormatRGBA16Float = @"SyphonPixelFormatRGBA16Float";
NSString * const SyphonPixelFormatRGBA32Float = @"SyphonPixelFormatRGBA32Float";

NSString * const SyphonColorPrimariesBT601NTSC = @"BT601_NTSC";
NSString * const SyphonColorPrimariesBT601PAL = @"BT601_PAL";
NSString * const SyphonColorPrimariesBT709 = @"BT709";
NSString * const SyphonColorPrimariesBT2020 = @"BT2020";
NSString * const SyphonColorPrimariesP3D65 = @"P3D65";
NSString * const SyphonColorPrimariesPassthrough = @"Passthrough";

NSString * const SyphonTransferFunctionLinear = @"Linear";
NSString * const SyphonTransferFunctionSRGB = @"SRGB";
NSString * const SyphonTransferFunctionGamma22 = @"Gamma22";
NSString * const SyphonTransferFunctionBT1886 = @"BT1886";
NSString * const SyphonTransferFunctionPQ = @"PQ";
NSString * const SyphonTransferFunctionHLG = @"HLG";
NSString * const SyphonTransferFunctionPassthrough = @"Passthrough";

NSString * const SyphonColorRangeFull = @"Full";
NSString * const SyphonColorRangeVideo = @"Video";
NSString * const SyphonColorRangeWide = @"Wide";
NSString * const SyphonColorRangePassthrough = @"Passthrough";

static NSSet<NSString *> *SyphonValidColorPrimaries(void)
{
    static NSSet<NSString *> *values;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        values = [NSSet setWithObjects:
                  SyphonColorPrimariesBT601NTSC,
                  SyphonColorPrimariesBT601PAL,
                  SyphonColorPrimariesBT709,
                  SyphonColorPrimariesBT2020,
                  SyphonColorPrimariesP3D65,
                  SyphonColorPrimariesPassthrough,
                  nil];
    });
    return values;
}

static NSSet<NSString *> *SyphonValidTransferFunctions(void)
{
    static NSSet<NSString *> *values;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        values = [NSSet setWithObjects:
                  SyphonTransferFunctionLinear,
                  SyphonTransferFunctionSRGB,
                  SyphonTransferFunctionGamma22,
                  SyphonTransferFunctionBT1886,
                  SyphonTransferFunctionPQ,
                  SyphonTransferFunctionHLG,
                  SyphonTransferFunctionPassthrough,
                  nil];
    });
    return values;
}

static NSSet<NSString *> *SyphonValidColorRanges(void)
{
    static NSSet<NSString *> *values;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        values = [NSSet setWithObjects:
                  SyphonColorRangeFull,
                  SyphonColorRangeVideo,
                  SyphonColorRangeWide,
                  SyphonColorRangePassthrough,
                  nil];
    });
    return values;
}

NSString *SyphonCreateUUIDString(void)
{
	// generate UUID
	CFUUIDRef	uuidObj = CFUUIDCreate(nil);
	CFStringRef uuid = CFUUIDCreateString(nil, uuidObj);
	CFRelease(uuidObj);
	NSString *result = [[NSString alloc] initWithFormat:@"%@.%@", kSyphonIdentifier, uuid];
	CFRelease(uuid);
	return result;
}

NSDictionary<NSString *, id> *SyphonIOSurfaceDescriptionFromServerDescription(NSDictionary<NSString *, id> *description)
{
    NSArray<NSDictionary<NSString *, id> *> *surfaces = description[SyphonServerDescriptionSurfacesKey];
    for (NSDictionary<NSString *, id> *surfaceDescription in surfaces)
    {
        if ([surfaceDescription[SyphonSurfaceType] isEqualToString:SyphonSurfaceTypeIOSurface])
        {
            return surfaceDescription;
        }
    }
    return nil;
}

MTLPixelFormat SyphonMTLPixelFormatFromName(NSString *formatName)
{
    if (formatName == nil)
    {
        return MTLPixelFormatBGRA8Unorm;
    }
    if (![formatName isKindOfClass:[NSString class]])
    {
        return MTLPixelFormatInvalid;
    }
    if ([formatName isEqualToString:SyphonPixelFormatBGRA8])
    {
        return MTLPixelFormatBGRA8Unorm;
    }
    if ([formatName isEqualToString:SyphonPixelFormatRGBA16Float])
    {
        return MTLPixelFormatRGBA16Float;
    }
    if ([formatName isEqualToString:SyphonPixelFormatRGBA32Float])
    {
        return MTLPixelFormatRGBA32Float;
    }
    return MTLPixelFormatInvalid;
}

NSString *SyphonNameFromMTLPixelFormat(MTLPixelFormat pixelFormat)
{
    switch (pixelFormat)
    {
        case MTLPixelFormatBGRA8Unorm:
            return SyphonPixelFormatBGRA8;
        case MTLPixelFormatRGBA16Float:
            return SyphonPixelFormatRGBA16Float;
        case MTLPixelFormatRGBA32Float:
            return SyphonPixelFormatRGBA32Float;
        default:
            return nil;
    }
}

OSType SyphonCVPixelFormatFromMTLPixelFormat(MTLPixelFormat pixelFormat)
{
    switch (pixelFormat)
    {
        case MTLPixelFormatBGRA8Unorm:
            return kCVPixelFormatType_32BGRA;
        case MTLPixelFormatRGBA16Float:
            return kCVPixelFormatType_64RGBAHalf;
        case MTLPixelFormatRGBA32Float:
            return kCVPixelFormatType_128RGBAFloat;
        default:
            return 0;
    }
}

NSUInteger SyphonBytesPerElementFromMTLPixelFormat(MTLPixelFormat pixelFormat)
{
    switch (pixelFormat)
    {
        case MTLPixelFormatBGRA8Unorm:
            return 4U;
        case MTLPixelFormatRGBA16Float:
            return 8U;
        case MTLPixelFormatRGBA32Float:
            return 16U;
        default:
            return 0U;
    }
}

BOOL SyphonColorHintOptionsAreValid(NSDictionary<NSString *, id> *options)
{
    NSString *primaries = options[SyphonMetalServerOptionColorPrimaries];
    NSString *transfer = options[SyphonMetalServerOptionTransferFunction];
    NSString *range = options[SyphonMetalServerOptionColorRange];

    BOOL anySpecified = (primaries != nil || transfer != nil || range != nil);
    if (!anySpecified)
    {
        return YES;
    }
    if (primaries == nil || transfer == nil || range == nil)
    {
        return NO;
    }
    if (![primaries isKindOfClass:[NSString class]]
        || ![transfer isKindOfClass:[NSString class]]
        || ![range isKindOfClass:[NSString class]])
    {
        return NO;
    }
    return [SyphonValidColorPrimaries() containsObject:primaries]
        && [SyphonValidTransferFunctions() containsObject:transfer]
        && [SyphonValidColorRanges() containsObject:range];
}

BOOL SyphonSafeBoolGet(SyphonSafeBool *b)
{
	return (*b == 0 ? NO : YES);
}

void SyphonSafeBoolSet(SyphonSafeBool *b, BOOL value)
{
	bool result;
	int32_t new = value ? 1 : 0;
	do {
		int32_t old = *b;
        result = atomic_compare_exchange_strong(b, &old, new);
	} while (!result);
}
