/*
    SyphonClientConnectionManager.m
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


#import "SyphonClientConnectionManager.h"
#import "SyphonPrivate.h"

#pragma mark Shared Instances

static OSSpinLock _lookupTableLock = OS_SPINLOCK_INIT;
static NSMapTable *_lookupTable;

static id SyphonClientPrivateCopyInstance(NSString *uuid)
{
	id result = nil;
	OSSpinLockLock(&_lookupTableLock);
	if (uuid) result = [_lookupTable objectForKey:uuid];
	[result retain];
	OSSpinLockUnlock(&_lookupTableLock);
	return result;
}

static void SyphonClientPrivateInsertInstance(id instance, NSString *uuid)
{
	OSSpinLockLock(&_lookupTableLock);
	if (uuid)
	{
		if (!_lookupTable) _lookupTable = [[NSMapTable alloc] initWithKeyOptions:NSMapTableStrongMemory valueOptions:NSMapTableZeroingWeakMemory capacity:1];
		[_lookupTable setObject:instance forKey:uuid];
	}
	OSSpinLockUnlock(&_lookupTableLock);
}

static void SyphonClientPrivateRemoveInstance(id instance, NSString *uuid)
{
	OSSpinLockLock(&_lookupTableLock);
	if (uuid) [_lookupTable removeObjectForKey:uuid];
	if ([_lookupTable count] == 0)
	{
		[_lookupTable release];
		_lookupTable = nil;
	}
	OSSpinLockUnlock(&_lookupTableLock);
}

@interface SyphonClientConnectionManager (Private)
- (void)setServerName:(NSString *)name;
- (void)publishNewFrame;
- (void)setSurfaceID:(IOSurfaceID)surfaceID;
- (IOSurfaceRef)surfaceHavingLock;
- (void)endConnectionHavingLock:(BOOL)hasLock;
@end
@implementation SyphonClientConnectionManager

- (id)initWithServerDescription:(NSDictionary *)description
{
    self = [super init];
	if (self)
	{
		NSString *serverUUID = [description objectForKey:SyphonServerDescriptionUUIDKey];
		
		// Return an existing instance for this server if we have one
		id existing = SyphonClientPrivateCopyInstance(serverUUID);
		if (existing)
		{
			[self release];
			return existing;
		}
		
		NSArray *surfaces = [description objectForKey:SyphonServerDescriptionSurfacesKey];
		BOOL hasIOSurface = NO;
		for (NSDictionary *surface in surfaces)
		{
			if ([[surface objectForKey:SyphonSurfaceType] isEqualToString:SyphonSurfaceTypeIOSurface]) hasIOSurface = YES;
		}
		
		if (!hasIOSurface)
		{
			[self release];
			return nil;
		}
		
		_lock = OS_SPINLOCK_INIT;
		_serverDescription = [[NSMutableDictionary alloc] initWithDictionary:description];
		_myUUID = SyphonCreateUUIDString();
		
		SyphonClientPrivateInsertInstance(self, serverUUID);
		_frames = [[NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsOpaquePersonality | NSPointerFunctionsOpaqueMemory)
										 valueOptions:(NSPointerFunctionsObjectPersonality | NSPointerFunctionsStrongMemory)] retain];
	}
	return self;
}

- (void)finalize
{
	if (_frameQueue) dispatch_release(_frameQueue);
	[super finalize];
}

- (void) dealloc
{
	SyphonClientPrivateRemoveInstance(self, [_serverDescription objectForKey:SyphonServerDescriptionUUIDKey]);
	[_frames release];
	if (_frameQueue) dispatch_release(_frameQueue);
	[_frameClients release];
	[_serverDescription release];
	[_myUUID release];
	[super dealloc];
}

- (void)endConnectionHavingLock:(BOOL)hasLock
{
	SYPHONLOG(@"Ending connection");
	SyphonMessageReceiver *connection;
	IOSurfaceRef surface;
	// we copy and clear ivars inside the lock, release them outside it
	if (!hasLock) OSSpinLockLock(&_lock);
	connection = _connection;
	_connection = nil;
	_active = NO;
	surface = _surface;
	_surface = NULL;
	[_frames removeAllObjects];
	if (!hasLock) OSSpinLockUnlock(&_lock);
	[connection invalidate];
	[connection release];
	if (surface) CFRelease(surface);
}

- (BOOL)isValid
{
	BOOL result;
	OSSpinLockLock(&_lock);
	result = _active;
	OSSpinLockUnlock(&_lock);
	return result;
}

- (void)addInfoClient:(id)client
{
	OSSpinLockLock(&_lock);
	_infoClientCount++;
	BOOL shouldSendAdd = NO;
	NSString *serverUUID = nil;
	if (_infoClientCount == 1)
	{
		// set up a connection to receive and deal with messages from the server
		_connection = [[SyphonMessageReceiver alloc] initForName:_myUUID protocol:SyphonMessagingProtocolCFMessage handler:^(id data, uint32_t type) {
			switch (type) {
				case SyphonMessageTypeNewFrame:
					[self publishNewFrame];
					break;
				case SyphonMessageTypeUpdateServerName:
					[self setServerName:(NSString *)data];
					break;
				case SyphonMessageTypeUpdateSurfaceID:
					[self setSurfaceID:[(NSNumber *)data unsignedIntValue]];
					break;
				case SyphonMessageTypeRetireServer:
					[self endConnectionHavingLock:NO];
					break;
				default:
					SYPHONLOG(@"Unknown message type #%u received", type);
					break;
			}
		}];
		
		if (_connection != nil)
		{
			serverUUID = [_serverDescription objectForKey:SyphonServerDescriptionUUIDKey];
			_active = shouldSendAdd = YES;
		}
	}
	OSSpinLockUnlock(&_lock);
	// We can do this outside the lock because we're not using any protected resources
	if (shouldSendAdd)
	{
		SYPHONLOG(@"Registering for info updates");
		SyphonMessageSender *sender = [[SyphonMessageSender alloc] initForName:serverUUID
																	  protocol:SyphonMessagingProtocolCFMessage
														   invalidationHandler:nil];
		
		if (sender == nil)
		{
			SYPHONLOG(@"Failed to create connection to server with uuid:%@", serverUUID);
			[self endConnectionHavingLock:NO];
		}
		[sender send:_myUUID ofType:SyphonMessageTypeAddClientForInfo];
		[sender release];
	}
}

- (void)removeInfoClient:(id)client
{
	OSSpinLockLock(&_lock);
	_infoClientCount--;
	if (_infoClientCount == 0)
	{
		// Remove ourself from the server
		NSString *serverUUID = [_serverDescription objectForKey:SyphonServerDescriptionUUIDKey];
		if (_active)
		{
			SYPHONLOG(@"De-registering for info updates");
			SyphonMessageSender *sender = [[SyphonMessageSender alloc] initForName:serverUUID
																		  protocol:SyphonMessagingProtocolCFMessage
															   invalidationHandler:nil];
			[sender send:_myUUID ofType:SyphonMessageTypeRemoveClientForInfo];
			[sender release];
			[self endConnectionHavingLock:YES];
		}
	}
	OSSpinLockUnlock(&_lock);
}

- (void)addFrameClient:(id)client
{
	OSSpinLockLock(&_lock);
	if (_frameQueue == nil)
	{
		_frameQueue = dispatch_queue_create([_myUUID cStringUsingEncoding:NSUTF8StringEncoding], 0);
		_frameClients = [[NSHashTable hashTableWithWeakObjects] retain];
	}
	OSSpinLockUnlock(&_lock);
	// only access _frameClients within the queue
	dispatch_sync(_frameQueue, ^{
		[_frameClients addObject:client];
	});
	if (OSAtomicIncrement32(&_handlerCount) == 1)
	{
		SYPHONLOG(@"Registering for frame updates");
		SyphonMessageSender *sender = [[SyphonMessageSender alloc] initForName:[self.serverDescription objectForKey:SyphonServerDescriptionUUIDKey]
																	  protocol:SyphonMessagingProtocolCFMessage
														   invalidationHandler:nil];
		if (sender == nil)
		{
			SYPHONLOG(@"Failed to create connection to server with uuid:%@", [self.serverDescription objectForKey:SyphonServerDescriptionUUIDKey]);
			[self endConnectionHavingLock:NO];
		}
		[sender send:_myUUID ofType:SyphonMessageTypeAddClientForFrames];
		[sender release];
	}
}

- (void)removeFrameClient:(id)client
{
	dispatch_sync(_frameQueue, ^{
		[_frameClients removeObject:client];
	});
	if (OSAtomicDecrement32(&_handlerCount) == 0 && self.isValid)
	{
		SYPHONLOG(@"De-registering for frame updates");
		SyphonMessageSender *sender = [[SyphonMessageSender alloc] initForName:[self.serverDescription objectForKey:SyphonServerDescriptionUUIDKey]
																	  protocol:SyphonMessagingProtocolCFMessage
														   invalidationHandler:nil];
		if (sender == nil)
		{
			SYPHONLOG(@"Failed to create connection to server with uuid:%@", [self.serverDescription objectForKey:SyphonServerDescriptionUUIDKey]);
			[self endConnectionHavingLock:NO];
		}
		[sender send:_myUUID ofType:SyphonMessageTypeRemoveClientForFrames];
		[sender release];
	}
}

- (NSString*) description
{
	OSSpinLockLock(&_lock);
	NSDictionary *description = [_serverDescription retain];
	OSSpinLockUnlock(&_lock);
	NSString *result = [NSString stringWithFormat:@"Server UUID: %@, Server Name: %@, Host Application: %@",
						[description objectForKey:SyphonServerDescriptionUUIDKey],
						[description objectForKey:SyphonServerDescriptionNameKey],
						[description objectForKey:SyphonServerDescriptionAppNameKey], nil];
	[description release];
	return result;
}

- (NSDictionary *)serverDescription
{
	OSSpinLockLock(&_lock);
	NSDictionary *description = [_serverDescription retain];
	OSSpinLockUnlock(&_lock);
	NSDictionary *result = [NSDictionary dictionaryWithDictionary:description];
	[description release];
	return result;
}

- (void)setServerName:(NSString *)name
{
	if (name)
	{
		OSSpinLockLock(&_lock);
		[_serverDescription setObject:name forKey:SyphonServerDescriptionNameKey];
		OSSpinLockUnlock(&_lock);
	}
}

- (void)publishNewFrame
{
	// This could be dispatch_async WHEN we coalesce incoming messages
	// Just now it's sync so a server can't flood a client (at the cost of blocking servers)
	dispatch_sync(_frameQueue, ^{
		for (id <SyphonFrameReceiving> obj in _frameClients) {
			[obj receiveNewFrame];
		}
	});
}

- (IOSurfaceRef)surfaceHavingLock
{
	if (!_surface)
	{
		// WHOA - This causes a retain.
		_surface = IOSurfaceLookup(_surfaceID);
	}
	return _surface;
}

- (void)setSurfaceID:(IOSurfaceID)surfaceID
{
	OSSpinLockLock(&_lock);
	_surfaceID = surfaceID;
	_frameID++; // new surface means a new frame
	if (_surface) 
	{
		CFRelease(_surface);
		_surface = NULL;
		[_frames removeAllObjects];
	}
	OSSpinLockUnlock(&_lock);
}

- (SyphonImage *)newFrameForContext:(CGLContextObj)context
{
	SyphonImage *result;
	OSSpinLockLock(&_lock);
	result = NSMapGet(_frames, context);
	if (result)
	{
		[result retain];
	}
	else
	{
		result = [[SyphonIOSurfaceImage alloc] initWithSurface:[self surfaceHavingLock] forContext:context];
		NSMapInsertKnownAbsent(_frames, context, result);
	}
	OSSpinLockUnlock(&_lock);
	return result;
}

- (NSUInteger)frameID
{
	NSUInteger result;
	OSSpinLockLock(&_lock);
	IOSurfaceRef surface = [self surfaceHavingLock];
	if (surface)
	{
		uint32_t seed = IOSurfaceGetSeed(surface);
		if (_lastSeed != seed)
		{
			_frameID++;
			_lastSeed = seed;
		}
	}
	result = _frameID;
	OSSpinLockUnlock(&_lock);
	return result;
}

@end
