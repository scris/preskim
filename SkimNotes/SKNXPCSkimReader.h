//
//  SKNXPCSkimReader.h
//  SkimNotesTest
//
//  Created by Christiaan Hofman on 24/11/2023.
/*
 This software is Copyright (c) 2023-2024
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
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SKNXPCPreskimReader : NSObject {
    NSString *_agentIdentifier;
    NSXPCConnection *_connection;
    id _agent;
    BOOL _synchronous;
}

@property (class, nonatomic, readonly) SKNXPCPreskimReader *sharedReader;

// this should only be set before any of the following calls is made
@property (nonatomic, strong, nullable) NSString *agentIdentifier;

// should use either the synchronous or the asynchronous methods, not both

// synchronous retrieval
- (nullable NSData *)SkimNotesAtURL:(NSURL *)fileURL;
- (nullable NSData *)RTFNotesAtURL:(NSURL *)fileURL;
- (nullable NSString *)textNotesAtURL:(NSURL *)fileURL;

// asynchronous retrieval
- (void)readSkimNotesAtURL:(NSURL *)fileURL reply:(void (^)(NSData * _Nullable))reply;
- (void)readRTFNotesAtURL:(NSURL *)fileURL reply:(void (^)(NSData * _Nullable))reply;
- (void)readTextNotesAtURL:(NSURL *)fileURL reply:(void (^)(NSString * _Nullable))reply;

@end

NS_ASSUME_NONNULL_END
