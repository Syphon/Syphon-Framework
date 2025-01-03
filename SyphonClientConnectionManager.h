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


#import <Foundation/Foundation.h>

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
@protocol SyphonInfoReceiving
- (void)invalidateFrame;
@end

@interface SyphonClientConnectionManager : NSObject
- (id)initWithServerDescription:(NSDictionary<NSString *, id> *)description;
@property (readonly) BOOL isValid;
- (void)addInfoClient:(id <SyphonInfoReceiving>)client isFrameClient:(BOOL)frameClient;     // Must be
- (void)removeInfoClient:(id <SyphonInfoReceiving>)client isFrameClient:(BOOL)frameClient;  // paired
- (IOSurfaceRef)newSurface;
@property (readonly) NSUInteger frameID;
@end
