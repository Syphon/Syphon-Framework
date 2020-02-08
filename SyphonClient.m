//
//  SyphonClient.m
//  Syphon
//
//  Created by Tom Butterworth on 08/02/2020.
//

#import "SyphonClient.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation SyphonClient

- (id)initWithServerDescription:(NSDictionary *)description context:(CGLContextObj)context options:(NSDictionary *)options newFrameHandler:(void (^)(SyphonClient * _Nonnull))handler
{
    self = [super initWithServerDescription:description
                                    context:context
                                    options:options
                            newFrameHandler:(void (^)(SyphonOpenGLClient *client))handler];
    if (self)
    {

    }
    return self;
}

@end

#pragma clang diagnostic pop
