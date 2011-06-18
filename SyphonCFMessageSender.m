/*
    SyphonCFMessageSender.m
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

#import "SyphonCFMessageSender.h"
#import "SyphonMessaging.h"
#import "SyphonPrivate.h"

@interface SyphonCFMessageSender (Private)
- (void)sendOnThread;
- (void)finishPort;
@end

@implementation SyphonCFMessageSender
- (id)initForName:(NSString *)name protocol:(NSString *)protocolName invalidationHandler:(void (^)(void))handler;
{
    self = [super initForName:name protocol:protocolName invalidationHandler:handler];
	if (self)
	{
		_port = CFMessagePortCreateRemote(kCFAllocatorDefault, (CFStringRef)name);
		if (_port == NULL)
		{
			[self release];
			return nil;
		}

		_queue = [[SyphonMessageQueue alloc] init];
		_queue.userInfo = self;
		// local vars for block references, see note below
		CFMessagePortRef port = _port;
		SyphonMessageQueue *queue = _queue;
		_dispatch = SyphonDispatchSourceCreate(^(){
			
			//// IMPORTANT																					//
			//// Do not refer to any ivars in this block, or self will be retained, causing a retain-loop	//
			
			CFDataRef returned;
			SInt32 result;
			uint32_t mType;
			NSData *mContent;
			while ([queue copyAndDequeue:&mContent type:&mType])
			{
				// TODO: think about dealing with time-outs
				result = CFMessagePortSendRequest(port, mType, (CFDataRef)mContent, 60, 0, NULL, &returned);
				[mContent release];
				if (result != kCFMessagePortSuccess)
				{
					if (result == kCFMessagePortIsInvalid)
					{
						[(SyphonCFMessageSender *)queue.userInfo finishPort];
						[(SyphonCFMessageSender *)queue.userInfo invalidate];
						break;
					}
				}
			}
		});
		
		SyphonDispatchSourceSetCompletionBlock(_dispatch, ^(){
			//// IMPORTANT																					//
			//// Do not refer to any ivars in this block, or self will be retained, causing a retain-loop	//
			if (port)
			{
				CFRelease(port);
			}
		});
	}
	return self;
}

- (void)finishPort
{
	_queue.userInfo = nil;
	// our CFMessagePort will be released in the dispatch source's completion block
	// we must stop referencing it now
	bool result;
	do {
		void *old = _port;
		result = OSAtomicCompareAndSwapPtrBarrier(old, NULL, (void **)&_port);
	} while (!result);
	do {
		void *old = _dispatch;
		result = OSAtomicCompareAndSwapPtrBarrier(old, NULL, (void **)&_dispatch);
		if (result) SyphonDispatchSourceRelease(old);
	} while (!result);
}

- (void)dealloc
{
	[self finishPort];
	[_queue release];
	[super dealloc];
}

- (void)finalize
{
	[self finishPort];
	[super finalize];
}

- (BOOL)isValid
{
	return (_port != NULL ? CFMessagePortIsValid(_port) : NO);
}

- (void)send:(id <NSCoding>)payload ofType:(uint32_t)type
{
	NSData *encoded;
	if (payload)
	{
		encoded = [NSKeyedArchiver archivedDataWithRootObject:payload];
	}
	else
	{
		encoded = nil;
	}
	[_queue queue:encoded ofType:type];
	SyphonDispatchSourceFire(_dispatch);
}

@end
