//
//  SKNAgentListener.m
//  SkimNotes
//
//  Created by Adam Maxwell on 04/10/07.
/*
 This software is Copyright (c) 2007
 Adam Maxwell. All rights reserved.
 
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

#import "SKNAgentListener.h"
#import "SKNAgentListenerProtocol.h"
#import "SKNXPCAgentListenerProtocol.h"
#import "NSFileManager_SKNToolExtensions.h"


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@interface SKNAgentListener (SKNConnection) <NSConnectionDelegate>
#pragma clang diagnostic pop
- (BOOL)startConnectionWithServerName:(NSString *)serverName;
- (void)destroyConnection;
@end

#pragma mark -

#if defined(MAC_OS_X_VERSION_10_8) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_8
@interface SKNAgentListener (SKNXPCConnection) <NSXPCListenerDelegate>
- (BOOL)startXPCListenerWithServerName:(NSString *)serverName;
- (void)destroyXPCConnection;
@end
#endif

#pragma mark -

@implementation SKNAgentListener

- (id)initWithServerName:(NSString *)serverName xpc:(BOOL)isXPC {
    self = [super init];
    if (self) {
        // user can pass nil, in which case we generate a server name to be read from standard output
        if (nil == serverName) {
            if (isXPC)
                serverName = [NSString stringWithFormat:@"scris.ds.preskim.notes-%@", [[NSProcessInfo processInfo] globallyUniqueString]];
            else
                serverName = [[NSProcessInfo processInfo] globallyUniqueString];
        }
        
        BOOL success = NO;
        if (isXPC) {
#if defined(MAC_OS_X_VERSION_10_8) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_8
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_8
            if ([NSXPCConnection class])
#endif
            success = [self startXPCListenerWithServerName:serverName];
#endif
        } else {
            success = [self startConnectionWithServerName:serverName];
        }
        
        if (success) {
            NSFileHandle *fh = [NSFileHandle fileHandleWithStandardOutput];
            [fh writeData:[serverName dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        } else {
            self = nil;
        }
    }
    return self;
}

- (void)dealloc {
    [self destroyConnection];
#if defined(MAC_OS_X_VERSION_10_8) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_8
    [self destroyXPCConnection];
#endif
}

@end

#pragma mark -

@implementation SKNAgentListener (SKNConnection)

- (BOOL)startConnectionWithServerName:(NSString *)serverName {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _connection = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:nil];
#pragma clang diagnostic pop
    NSProtocolChecker *checker = [NSProtocolChecker protocolCheckerWithTarget:self protocol:@protocol(SKNAgentListenerProtocol)];
    [_connection setRootObject:checker];
    [_connection setDelegate:self];
    
    if ([_connection registerName:serverName] == NO) {
        fprintf(stderr, "skimnotes agent pid %d: unable to register connection name %s; another process must be running\n", getpid(), [serverName UTF8String]);
        [self destroyConnection];
        return NO;
    }
    
    return YES;
}

- (void)destroyConnection {
    [_connection registerName:nil];
    [[_connection receivePort] invalidate];
    [[_connection sendPort] invalidate];
    [_connection invalidate];
    _connection = nil;
}

- (void)portDied:(NSNotification *)notification {
    [self destroyConnection];
    fprintf(stderr, "skimnotes agent pid %d dying because port %s is invalid\n", getpid(), [[[notification object] description] UTF8String]);
    exit(0);
}

// first app to connect will be the owner of this instance of the program; when the connection dies, so do we
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (BOOL)makeNewConnection:(NSConnection *)newConnection sender:(NSConnection *)parentConnection {
#pragma clang diagnostic pop
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(portDied:) name:NSPortDidBecomeInvalidNotification object:[newConnection sendPort]];
    fprintf(stderr, "skimnotes agent pid %d connection registered\n", getpid());
    return YES;
}

#pragma mark SKNAgentListenerProtocol

- (bycopy NSData *)SkimNotesAtPath:(in bycopy NSString *)aFile {
    NSError *error = nil;
    NSData *data = [[NSFileManager defaultManager] SkimNotesAtPath:aFile error:&error];
    if (nil == data)
        fprintf(stderr, "skimnotes agent pid %d: error getting Preskim notes (%s)\n", getpid(), [[error description] UTF8String]);
    return data;
}

- (bycopy NSData *)RTFNotesAtPath:(in bycopy NSString *)aFile {
    NSError *error = nil;
    NSData *data = [[NSFileManager defaultManager] PreskimRTFNotesAtPath:aFile error:&error];
    if (nil == data)
        fprintf(stderr, "skimnotes agent pid %d: error getting RTF notes (%s)\n", getpid(), [[error description] UTF8String]);
    return data;
}

- (bycopy NSData *)textNotesAtPath:(in bycopy NSString *)aFile encoding:(NSStringEncoding)encoding {
    NSError *error = nil;
    NSString *string = [[NSFileManager defaultManager] PreskimTextNotesAtPath:aFile error:&error];
    if (nil == string)
        fprintf(stderr, "skimnotes agent pid %d: error getting text notes (%s)\n", getpid(), [[error description] UTF8String]);
    // Returning the string directly can fail under some conditions.  For some strings with corrupt copy-paste characters (typical for notes), -[NSString canBeConvertedToEncoding:NSUTF8StringEncoding] returns YES but the actual conversion fails.  A result seems to be that encoding the string also fails, which causes the DO client to get a timeout.  Returning NSUnicodeStringEncoding data seems to work in those cases (and is safe since we're not going over the wire between big/little-endian systems).
    return [string dataUsingEncoding:encoding];
}

@end

#pragma mark -

#if defined(MAC_OS_X_VERSION_10_8) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_8
@implementation SKNAgentListener (SKNXPCConnection)

- (BOOL)startXPCListenerWithServerName:(NSString *)serverName {
    _xpcListener = [[NSXPCListener alloc] initWithMachServiceName:serverName];
    [_xpcListener setDelegate:self];
    [_xpcListener resume];
    
    return YES;
}

- (void)destroyXPCConnection {
    [_xpcConnection invalidate];
    _xpcConnection = nil;
    
    [_xpcListener invalidate];
    _xpcListener = nil;
}

// first app to connect will be the owner of this instance of the program; when the connection dies, so do we
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    if (_xpcConnection) {
        [newConnection invalidate];
        return NO;
    }
    
    [newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(SKNXPCAgentListenerProtocol)]];
    [newConnection setExportedObject:self];
    __weak SKNAgentListener *weakSelf = self;
    NSString *description = [newConnection description];
    [newConnection setInvalidationHandler:^{
        [weakSelf destroyXPCConnection];
        fprintf(stderr, "skimnotes agent pid %d dying because port %s is invalid\n", getpid(), [description UTF8String]);
        exit(0);
    }];
    _xpcConnection = newConnection;
    [_xpcConnection resume];
    
    return YES;
}

#pragma mark SKNXPCAgentListenerProtocol

- (void)readSkimNotesAtURL:(NSURL *)aURL reply:(void (^)(NSData *))reply {
    NSError *error = nil;
    NSData *data = [[NSFileManager defaultManager] SkimNotesAtPath:[aURL path] error:&error];
    if (nil == data)
        fprintf(stderr, "skimnotes agent pid %d: error getting Preskim notes (%s)\n", getpid(), [[error description] UTF8String]);
    reply(data);
}

- (void)readRTFNotesAtURL:(NSURL *)aURL reply:(void (^)(NSData *))reply {
    NSError *error = nil;
    NSData *data = [[NSFileManager defaultManager] PreskimRTFNotesAtPath:[aURL path] error:&error];
    if (nil == data)
        fprintf(stderr, "skimnotes agent pid %d: error getting RTF notes (%s)\n", getpid(), [[error description] UTF8String]);
    reply(data);
}

- (void)readTextNotesAtURL:(NSURL *)aURL reply:(void (^)(NSString *))reply {
    NSError *error = nil;
    NSString *string = [[NSFileManager defaultManager] PreskimTextNotesAtPath:[aURL path] error:&error];
    if (nil == string)
        fprintf(stderr, "skimnotes agent pid %d: error getting text notes (%s)\n", getpid(), [[error description] UTF8String]);
    reply(string);
}

@end
#endif
