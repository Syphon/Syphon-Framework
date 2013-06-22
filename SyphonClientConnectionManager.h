/*
    SyphonClientConnectionManager.h
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
#import <IOSurface/IOSurface.h>
#import <libkern/OSAtomic.h>
#import "SyphonMessaging.h"
#import "SyphonIOSurfaceImage.h"

/* This object handles messaging to and from the server.

 SyphonClients should
 
 addInfoClient:self
 addFrameClient:self (if wanted)
 ...
 removeFrameClient:self (if added)
 removeInfoClient:self
 
 in that order.
 
 Thread-safe. One instance is shared between all clients for a server.
 
 */

@protocol SyphonFrameReceiving
- (void)receiveNewFrame;
@end

#define SYPHON_CLIENT_CONNECTION_MANAGER_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonClientConnectionManager)

@interface SYPHON_CLIENT_CONNECTION_MANAGER_UNIQUE_CLASS_NAME : NSObject
{
@private
	NSString *_myUUID;
	IOSurfaceID _surfaceID;
	IOSurfaceRef _surface;
	uint32_t _lastSeed;
	NSMapTable *_frames;
	NSUInteger _frameID;
	NSMutableDictionary *_serverDescription;
	BOOL _active;
	SyphonMessageReceiver *_connection;
	int32_t _infoClientCount;
	int32_t _handlerCount;
	NSHashTable *_frameClients;
	dispatch_queue_t _frameQueue;
	OSSpinLock _lock;
}
- (id)initWithServerDescription:(NSDictionary *)description;
@property (readonly) BOOL isValid;
- (void)addInfoClient:(id)client;		// Must be
- (void)removeInfoClient:(id)client;	// paired
- (void)addFrameClient:(id <SyphonFrameReceiving>)client;		// Must be
- (void)removeFrameClient:(id <SyphonFrameReceiving>)client;	// paired
@property (readonly) NSDictionary *serverDescription;
- (SyphonImage *)newFrameForContext:(CGLContextObj)context;
@property (readonly) NSUInteger frameID;
@end

#if defined(SYPHON_USE_CLASS_ALIAS)
@compatibility_alias SyphonClientConnectionManager SYPHON_CLIENT_CONNECTION_MANAGER_UNIQUE_CLASS_NAME;
#endif
