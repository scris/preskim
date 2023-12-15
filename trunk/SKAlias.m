//
//  SKAlias.m
//  Skim
//
//  Created by Christiaan Hofman on 1/21/13.
/*
 This software is Copyright (c) 2013-2023
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SKAlias.h"


@implementation SKAlias

@dynamic data, bookmark, fileURL, fileURLNoUI;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static inline AliasHandle createAliasHandleFromData(NSData *data) {
    NSUInteger len = [data length];
    Handle handle = NewHandle(len);
    if (handle != NULL && len > 0) {
        HLock(handle);
        memmove((void *)*handle, (const void *)[data bytes], len);
        HUnlock(handle);
    }
    return (AliasHandle)handle;
}

static inline NSData *dataFromAliasHandle(AliasHandle aliasHandle) {
    NSData *data = nil;
    Handle handle = (Handle)aliasHandle;
    NSUInteger len = GetHandleSize(handle);
    SInt8 handleState = HGetState(handle);
    HLock(handle);
    data = [NSData dataWithBytes:(const void *)*handle length:len];
    HSetState(handle, handleState);
    return data;
}

static inline NSURL *fileURLFromAliasHandle(AliasHandle aliasHandle, NSUInteger mountFlags) {
    FSRef fileRef;
    Boolean wasChanged;
    if (noErr == FSResolveAliasWithMountFlags(NULL, aliasHandle, &fileRef, &wasChanged, mountFlags))
        return (NSURL *)CFBridgingRelease(CFURLCreateFromFSRef(kCFAllocatorDefault, &fileRef));
    return nil;
}

static inline void disposeAliasHandle(AliasHandle aliasHandle) {
    if (aliasHandle) DisposeHandle((Handle)aliasHandle);
}
#pragma clang diagnostic pop

- (instancetype)initWithAliasData:(NSData *)aliasData {
    if (aliasData == nil) {
        self = nil;
    } else {
        self = [super init];
        if (self) {
            data = (NSData *)CFBridgingRelease(CFURLCreateBookmarkDataFromAliasRecord(NULL, (__bridge CFDataRef)aliasData));
            if (data == nil) {
                aliasHandle = createAliasHandleFromData(aliasData);
                if (aliasHandle == NULL) {
                    self = nil;
                }
            }
        }
    }
    return self;
}

- (instancetype)initWithBookmarkData:(NSData *)bookmarkData {
    if (bookmarkData == nil) {
        self = nil;
    } else {
        self = [super init];
        if (self) {
            data = bookmarkData;
        }
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)fileURL {
    return [self initWithBookmarkData:[fileURL bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:NULL]];
}

- (void)dealloc {
    disposeAliasHandle(aliasHandle);
    aliasHandle = NULL;
}

- (NSData *)data {
    if (aliasHandle)
        // try to convert alias to bookmark data
        [self fileURLNoUI];
    if (aliasHandle)
        // we could return data if present when fileURLNoUI is nil
        return dataFromAliasHandle(aliasHandle) ?: data;
    else
        return data;
}

- (BOOL)isBookmark {
    return aliasHandle == nil && data != nil;
}

- (NSURL *)fileURLAllowingUI:(BOOL)allowUI {
    // we could cache the fileURL, but it would break when moving the file while we run
    NSURL *fileURL = nil;
    BOOL shouldUpdate = NO;
    if (aliasHandle) {
        fileURL = fileURLFromAliasHandle(aliasHandle, allowUI ? 0 : kResolveAliasFileNoUI);
        shouldUpdate = YES;
    } else if (data) {
        NSURLBookmarkResolutionOptions options = allowUI ? 0 : NSURLBookmarkResolutionWithoutUI | NSURLBookmarkResolutionWithoutMounting;
        fileURL = [NSURL URLByResolvingBookmarkData:data options:options relativeToURL:nil bookmarkDataIsStale:&shouldUpdate error:NULL];
    }
    if (shouldUpdate && fileURL) {
        NSData *bmData = [fileURL bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:NULL];
        if (bmData) {
            if (aliasHandle)
                disposeAliasHandle(aliasHandle);
            data = bmData;
        }
    }
    return fileURL;
}

- (NSURL *)fileURL {
    return [self fileURLAllowingUI:YES];
}

- (NSURL *)fileURLNoUI {
    return [self fileURLAllowingUI:NO];
}

@end
