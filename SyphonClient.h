/*
   SyphonClient.h
   Syphon

    Copyright 2010-2020 bangnoise (Tom Butterworth) & vade (Anton Marini).
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

#ifndef SYPHONCLIENT_H_C1F80C6A_CEEB_4FB7_B014_2A0A7A7AD9D2
#define SYPHONCLIENT_H_C1F80C6A_CEEB_4FB7_B014_2A0A7A7AD9D2
#import "SyphonOpenGLClient.h"

NS_ASSUME_NONNULL_BEGIN

#define SYPHON_CLIENT_UNIQUE_CLASS_NAME SYPHON_UNIQUE_CLASS_NAME(SyphonClient)

DEPRECATED_MSG_ATTRIBUTE("Use SyphonOpenGLClient")
@interface SYPHON_CLIENT_UNIQUE_CLASS_NAME : SyphonOpenGLClient
- (id)initWithServerDescription:(NSDictionary *)description context:(CGLContextObj)context options:(nullable NSDictionary *)options newFrameHandler:(nullable void (^)(SYPHON_CLIENT_UNIQUE_CLASS_NAME *client))handler;
@end

#if defined(SYPHON_USE_CLASS_ALIAS)
@compatibility_alias SyphonClient SYPHON_CLIENT_UNIQUE_CLASS_NAME;
#endif

NS_ASSUME_NONNULL_END
#endif
