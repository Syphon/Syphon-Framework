/*
    SyphonMachMessageSender.m
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

#import "SyphonMachMessageSender.h"
#import "SyphonMessaging.h"
//#include <servers/bootstrap.h> // using NSMachBootstrapServer instead
#include <mach/mach.h>

typedef struct {
    mach_msg_header_t header;
	// Think we ought to have a message type here
    int               data;
} SyphonMachMessage;

@implementation SyphonMachMessageSender
- (id)initForName:(NSString *)name protocol:(NSString *)protocolName invalidationHandler:(void (^)(void))handler
{
    self = [super initForName:name protocol:protocolName invalidationHandler:handler];
	if (self)
	{
		_port = [[[NSMachBootstrapServer sharedInstance] portForName:name] retain];
	}
	return self;
}

- (void)finishPort
{
	if (_port)
	{
		[_port invalidate];
		[_port release];
		_port = nil;
	}
}

- (void)finalize
{
	[self finishPort];
	[super finalize];
}

- (void)dealloc
{
	[self finishPort];
	[super dealloc];
}

- (void)send:(id <NSCoding>)data ofType:(uint32_t)type
{
	// TODO: handle sending data in messages, this just sends an integer, which isn't particularly handy...
	SyphonMachMessage message;
	mach_msg_header_t *header = &(message.header);
//	header->msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND);
	// not at all sure about this:
	header->msgh_bits = MACH_MSGH_BITS_REMOTE(MACH_MSG_TYPE_COPY_SEND); // mark this as complex to use OOL memory
	header->msgh_remote_port = [_port machPort];
	header->msgh_local_port = MACH_PORT_NULL;
	header->msgh_size = sizeof(SyphonMachMessage);
	header->msgh_id = type;
	mach_msg(header, MACH_SEND_MSG, header->msgh_size, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
}
@end
