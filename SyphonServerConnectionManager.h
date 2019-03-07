/*
    SyphonServerConnectionManager.h
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


#import <Cocoa/Cocoa.h>

/*
 This class is not KVO compliant for serverDescription, as changes to name won't raise a notification for serverDescription
 This isn't a problem currently, as SyphonServer is KVO compliant for name/serverDescription
 */

#define SYPHON_SERVER_CONNECTION_MANAGER_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonServerConnectionManager)

@interface SYPHON_SERVER_CONNECTION_MANAGER_UNIQUE_CLASS_NAME : NSObject
- (id)initWithUUID:(NSString *)uuid options:(NSDictionary *)options;
@property (readonly) NSDictionary *surfaceDescription;
/*
 - (BOOL)start
 
 Starts the server. Returns YES if the server was started, NO if it could not be started.
 */
- (BOOL)start;
- (void)stop;
@property (readonly) BOOL hasClients;
- (void)publishNewFrame;
- (void)setSurfaceID:(IOSurfaceID)newID;
- (void)setName:(NSString *)name;
@end

#if defined(SYPHON_USE_CLASS_ALIAS)
@compatibility_alias SyphonServerConnectionManager SYPHON_SERVER_CONNECTION_MANAGER_UNIQUE_CLASS_NAME;
#endif