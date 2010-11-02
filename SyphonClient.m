/*
    SyphonClient.m
    Syphon

     Copyright 2010 bangnoise (Tom Butterworth) & vade (Anton Marini).
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


#import "SyphonClient.h"
#import "SyphonPrivate.h"
#import "SyphonClientConnectionManager.h"

#import <libkern/OSAtomic.h>

#import <OpenGL/CGLMacro.h>

@implementation SyphonClient
#if SYPHON_DEBUG_NO_DRAWING
+ (void)load
{
	NSLog(@"SYPHON FRAMEWORK: DRAWING IS DISABLED");
	[super load];
}
#endif

- (id)init
{
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (id)initWithServerDescription:(NSDictionary *)description options:(NSDictionary *)options newFrameHandler:(void (^)(SyphonClient *client))handler
{
	if((self = [super init]))
	{
		NSNumber *dictionaryVersion = [description objectForKey:SyphonServerDescriptionDictionaryVersionKey];
		_connectionManager = [[SyphonClientConnectionManager alloc] initWithServerDescription:description];
		
		if (dictionaryVersion == nil
			|| [dictionaryVersion unsignedIntValue] > kSyphonDictionaryVersion
			|| _connectionManager == nil)
		{
			[self release];
			return nil;
		}
		
		[(SyphonClientConnectionManager *)_connectionManager addInfoClient:self];
		
		if (handler != nil)
		{
			_handler = [handler copy]; // copy don't retain
			[(SyphonClientConnectionManager *)_connectionManager addFrameClient:(id <SyphonFrameReceiving>)self];
		}
		_lock = OS_SPINLOCK_INIT;
		_status = 1;
	}
	return self;
}

- (void)finalize
{	
	if (((SyphonClientConnectionManager *)_connectionManager).isValid)
	{
		[NSException raise:@"SyphonClientException" format:@"finalize called on client that hasn't been stopped."];
	}
	[super finalize];
}

- (void) dealloc
{
	[self stop];
	[super dealloc];
}

- (void)stop
{
	if (OSAtomicDecrement32(&_status) == 0) // so this will only happen once even if stop is called multiple times
	{
		if (_handler != nil)
		{
			[(SyphonClientConnectionManager *)_connectionManager removeFrameClient:(id <SyphonFrameReceiving>) self];
			[_handler release];
		}		
		[(SyphonClientConnectionManager *)_connectionManager removeInfoClient:self];
		[(SyphonClientConnectionManager *)_connectionManager release];
		_connectionManager = nil;
	}
}

- (BOOL)isValid
{
	return ((SyphonClientConnectionManager *)_connectionManager).isValid;
}

- (void)receiveNewFrame
{
	if (_handler)
	{
		_handler(self);
	}
}

#pragma mark Rendering frames
- (BOOL)hasNewFrame
{
	BOOL result;
	OSSpinLockLock(&_lock);
	result = _lastFrameID != ((SyphonClientConnectionManager *)_connectionManager).frameID;
	OSSpinLockUnlock(&_lock);
	return result;
}

- (SyphonImage *)newFrameImageForContext:(CGLContextObj)cgl_ctx
{
	OSSpinLockLock(&_lock);
	_lastFrameID = [(SyphonClientConnectionManager *)_connectionManager frameID];
	OSSpinLockUnlock(&_lock);
	return [(SyphonClientConnectionManager *)_connectionManager newFrameForContext:cgl_ctx];
}

- (NSDictionary *)serverDescription
{
	return ((SyphonClientConnectionManager *)_connectionManager).serverDescription;
}

@end
