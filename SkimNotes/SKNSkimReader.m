//
//  SKNPreskimReader.m
//  SkimNotes
//
//  Created by Adam Maxwell on 04/09/07.
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

#import "SKNSkimReader.h"
#import "SKNAgentListenerProtocol.h"

#define AGENT_TIMEOUT 1.0f

@implementation SKNPreskimReader

@synthesize agentIdentifier;

+ (SKNPreskimReader *)sharedReader {
    static id sharedReader = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedReader = [[self alloc] init];
    });
    return sharedReader;
}

- (void)destroyConnection {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSConnectionDidDieNotification object:_connection];
#pragma clang diagnostic pop
    _agent = nil;
    
    [[_connection receivePort] invalidate];
    [[_connection sendPort] invalidate];
    [_connection invalidate];
    _connection = nil;
}

- (void)dealloc {
    [self destroyConnection];
}

- (void)setAgentIdentifier:(NSString *)identifier {
    NSAssert(_connection == nil, @"agentIdentifier must be set before connecting");
    if (_connection == nil && _agentIdentifier != identifier) {
        _agentIdentifier = identifier;
    }
}

// this could be simplified
- (NSString *)skimnotesToolPath {
    // we assume the skimnotes tool is contained in the Resources of the main bundle
    NSString *path = [[NSBundle mainBundle] pathForResource:@"skimnotes" ofType:nil];
    if (path == nil) {
        // in case this is included in a framework
        path = [[NSBundle bundleForClass:[self class]] pathForResource:@"skimnotes" ofType:nil];
    }
    if (path == nil) {
        // look for it in the Preskim bundle
        NSString *PreskimPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Preskim"];
        path = PreskimPath ? [[[NSBundle bundleWithPath:PreskimPath] sharedSupportPath] stringByAppendingPathComponent:@"skimnotes"] : nil;
    }
    return path;
}

- (void)handleConnectionDied:(NSNotification *)note {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSConnectionDidDieNotification object:[note object]];
#pragma clang diagnostic pop
    // ensure the proxy ivar and ports are cleaned up; is it still okay to message it?
    [self destroyConnection];
}

- (BOOL)launchedTask {
    BOOL taskLaunched = NO;
    NSString *launchPath = [self skimnotesToolPath];
    
    if (launchPath) {
        // can also use a fixed identifier, or let the tool decide about an identifier and read it from stdout
        if (nil == [self agentIdentifier])
            [self setAgentIdentifier:[[NSProcessInfo processInfo] globallyUniqueString]];
        
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:launchPath];
        [task setArguments:@[@"agent", [self agentIdentifier]]];
        
        // task will print the identifier to standard output; we don't care about it, since we specified it
        [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
        [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
        @try {
            [task launch];
            taskLaunched = [task isRunning];
        }
        @catch(id exception){
            NSLog(@"failed to launch skimnotes agent: %@", exception);
            taskLaunched = NO;
        }
        task = nil;
    } else {
        NSLog(@"failed to find skimnotes tool");
    }
    return taskLaunched;
}    

- (void)establishConnection {
    static int numberOfConnectionAttempts = 0;
    if (numberOfConnectionAttempts++ > 100) {
        static BOOL didWarn = NO;
        if (NO == didWarn) {
            NSLog(@"*** Insane number of Preskim agent connection failures; disabling further attempts ***");
            didWarn = YES;
        }
        return;
    }
    
    // okay to launch multiple instances, since the new one will just die, but we generally shouldn't do that
    
    // no point in trying to connect if the task didn't launch
    if ([self launchedTask]) {
        int maxTries = 5;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _connection = [NSConnection connectionWithRegisteredName:[self agentIdentifier] host:nil];
#pragma clang diagnostic pop
        
        // if we try to read data before the server is fully set up, connection will still be nil
        while (nil == _connection && maxTries--) {
            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            _connection = [NSConnection connectionWithRegisteredName:[self agentIdentifier] host:nil];
#pragma clang diagnostic pop
        }
        
        if (_connection) {
            
            // keep an eye on the connection from our end, so we can retain the proxy object
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleConnectionDied:) name:NSConnectionDidDieNotification object:_connection];
#pragma clang diagnostic pop
            
            // if we don't set these explicitly, timeout never seems to take place
            [_connection setRequestTimeout:AGENT_TIMEOUT];
            [_connection setReplyTimeout:AGENT_TIMEOUT];
            
            @try {
                id server = [_connection rootProxy];
                [server setProtocolForProxy:@protocol(SKNAgentListenerProtocol)];
                _agent = server;
            }
            @catch(id exception) {
                NSLog(@"Error: exception \"%@\" caught when contacting SkimNotesAgent", exception);
                [self destroyConnection];
            }
        }
    }
}    

- (BOOL)connectAndCheckTypeOfFile:(NSURL *)fileURL {
    // these checks are client side to avoid connecting to the server unless it's really necessary
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSString *fileType = [ws typeOfFile:[fileURL path] error:NULL];
    
    if (fileType != nil &&
        ([ws type:fileType conformsToType:(__bridge NSString *)kUTTypePDF] ||
         [ws type:fileType conformsToType:@"scris.ds.preskim.pdfd"] ||
         [ws type:fileType conformsToType:@"scris.ds.preskim.notes"])) {
        if (nil == _connection)
            [self establishConnection];
        return YES;
    }
    return NO;
}

- (NSData *)SkimNotesAtURL:(NSURL *)fileURL {
    NSData *data = nil;
    if ([self connectAndCheckTypeOfFile:fileURL]) {
        @try{
            data = [_agent SkimNotesAtPath:[fileURL path]];
        }
        @catch(id exception){
            data = nil;
            NSLog(@"-[SKNPreskimReader SkimNotesAtURL:] caught %@ while contacting skim agent", exception);
            [self destroyConnection];
        }
    }
    return data;
}

- (NSData *)RTFNotesAtURL:(NSURL *)fileURL {   
    NSData *data = nil;
    if ([self connectAndCheckTypeOfFile:fileURL]) {
        @try{
            data = [_agent RTFNotesAtPath:[fileURL path]];
        }
        @catch(id exception){
            data = nil;
            NSLog(@"-[SKNPreskimReader RTFNotesAtURL:] caught %@ while contacting skim agent", exception);
            [self destroyConnection];
        }
    }
    return data;
}

- (NSString *)textNotesAtURL:(NSURL *)fileURL {   
    NSData *textData = nil;
    if ([self connectAndCheckTypeOfFile:fileURL]) {
        @try{
            textData = [_agent textNotesAtPath:[fileURL path] encoding:NSUnicodeStringEncoding];
        }
        @catch(id exception){
            textData = nil;
            NSLog(@"-[SKNPreskimReader textNotesAtURL:] caught %@ while contacting skim agent", exception);
            [self destroyConnection];
        }
    }
    return textData ? [[NSString alloc] initWithData:textData encoding:NSUnicodeStringEncoding] : nil;
}


@end
