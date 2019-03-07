#import "SyphonConstants.h"
#import "SyphonPrivate.h"

@implementation SYPHON_CONSTANTS_UNIQUE_CLASS_NAME

+(unsigned int)SyphonDictionaryVersion
{
    return kSyphonDictionaryVersion;
}

+(NSString*) SyphonIdentifier
{
    return kSyphonIdentifier;
}

+(NSString*) SyphonConstantServerAnnounceRequest
{
    return SyphonServerAnnounceRequest;
}

+(NSString*) SyphonConstantServerAnnounce
{
    return SyphonServerAnnounce;
}

+(NSString*) SyphonConstantServerRetire
{
    return SyphonServerRetire;
}

+(NSString*) SyphonConstantServerUpdate
{
    return SyphonServerUpdate;
}

// Server-description keys // and content
+(NSString*) SyphonServerDescriptionUUIDKey
{
    return SyphonServerDescriptionUUIDKey;
}

+(NSString*) SyphonServerDescriptionNameKey
{
    return SyphonServerDescriptionNameKey;
}

+(NSString*) SyphonServerDescriptionAppNameKey
{
    return SyphonServerDescriptionAppNameKey;
}

+(NSString*) SyphonServerDescriptionDictionaryVersionKey
{
    return SyphonServerDescriptionDictionaryVersionKey;
}

+(NSString*) SyphonServerDescriptionSurfacesKey
{
    return SyphonServerDescriptionSurfacesKey;
}

+(NSString*) SyphonSurfaceType
{
    return SyphonSurfaceType;
}

+(NSString*) SyphonSurfaceTypeIOSurface
{
    return SyphonSurfaceTypeIOSurface;
}

+(NSString*) SyphonServerOptionIsPrivate
{
    return SyphonServerOptionIsPrivate;
}

+(NSString*) SyphonServerOptionAntialiasSampleCount
{
    return SyphonServerOptionAntialiasSampleCount;
}

+(NSString*) SyphonServerOptionDepthBufferResolution
{
    return SyphonServerOptionDepthBufferResolution;
}

+(NSString*) SyphonServerOptionStencilBufferResolution
{
    return SyphonServerOptionStencilBufferResolution;
}

+(NSString*) SyphonCreateUUIDString
{
    return SyphonCreateUUIDString();
}

@end
