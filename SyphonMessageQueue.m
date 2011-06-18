/*
	SyphonMessageQueue.m
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

#import "SyphonMessageQueue.h"

/*
 
  Designed for a low number of message types. May want to use a collection class for internal storage if we need to support a great number of different types.
 
 */


typedef struct SyphonQMember
{
	NSData *content;
	uint32_t type;
	struct SyphonQMember *next;
} SyphonQMember;

static SyphonQMember *SyphonQMemberCreateFromPool(OSQueueHead *pool, NSData *mcontent, uint32_t mtype)
{
	SyphonQMember *n = OSAtomicDequeue(pool, offsetof(SyphonQMember, next));
	if (!n)
	{
		n = malloc(sizeof(SyphonQMember));
	}
	if (n)
	{
		n->next = NULL;
		n->content = [mcontent retain];
		n->type = mtype;
	}
	return n;
}

#define SyphonQMemberReturnToPool(pool, member) OSAtomicEnqueue((pool), (member), offsetof(SyphonQMember, next))

#define SyphonQMemberDestroy(m)	free((m))

@implementation SyphonMessageQueue
- (id)init
{
    self = [super init];
	if (self)
	{
		// These are the values of OS_ATOMIC_QUEUE_INIT
		_pool.opaque1 = NULL;
		_pool.opaque2 = 0;
		_lock = OS_SPINLOCK_INIT;
	}
	return self;
}

- (void)drainQueueAndPool
{
	SyphonQMember *m = _head;
	SyphonQMember *n;
	while (m)
	{
		n = m;
		m = m->next;
		[n->content release];
		SyphonQMemberDestroy(n);
	}
	do {
		m = OSAtomicDequeue(&_pool, offsetof(SyphonQMember, next));
		SyphonQMemberDestroy(m);
	} while (m);
}

- (void)finalize
{
	[self drainQueueAndPool];
	[super finalize];
}

- (void)dealloc
{
	[self drainQueueAndPool];
	[super dealloc];
}

- (void)queue:(NSData *)content ofType:(uint32_t)type
{
	SyphonQMember *incoming = SyphonQMemberCreateFromPool(&_pool, content, type);
	OSSpinLockLock(&_lock);
	// We do duplicate message removal and then new message insertion in two passes.
	// Feel free to improve on that...
	SyphonQMember *current = (SyphonQMember *)_head;
	SyphonQMember **prev = (SyphonQMember **)&_head;
	SyphonQMember *delete = NULL;
	while (current)
	{
		if (current->type == type)
		{
			[current->content release];
			*prev = current->next;
			delete = current;
		}
		else
		{
			prev = &current->next;
		}
		current = current->next;
		if (delete)
		{
			SyphonQMemberReturnToPool(&_pool, delete);
			delete = NULL;
		}
	}
	if (_head == NULL)
	{
		_head = incoming;
	}
	else
	{
		current = _head;
		while (current->next != NULL)
		{
			current = current->next;
		}
		current->next = incoming;
	}
	OSSpinLockUnlock(&_lock);
}

- (BOOL)copyAndDequeue:(NSData **)content type:(uint32_t *)type
{
	BOOL result;
	SyphonQMember *toDelete;
	OSSpinLockLock(&_lock);
	if (_head)
	{
		result = YES;
		SyphonQMember *head = (SyphonQMember *)_head;
		*content = head->content;
		*type = head->type;
		_head = head->next;
		toDelete = head;
	}
	else
	{
		result = NO;
		*content = nil;
		*type = 0;
		toDelete = NULL;
	}
	OSSpinLockUnlock(&_lock);
	if (toDelete) SyphonQMemberReturnToPool(&_pool, toDelete);
	return result;
}

- (void *)userInfo
{
	return _info;
}

- (void)setUserInfo:(void *)info
{
	bool result;
	do {
		void *old = _info;
		result = OSAtomicCompareAndSwapPtrBarrier(old, info, &_info);
	} while (!result);
}
@end
