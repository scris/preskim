//
//  SKNXPCSkimReader.m
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

#import "SKNXPCSkimReader.h"
#import "SKNXPCAgentListenerProtocol.h"
#import <ServiceManagement/ServiceManagement.h>

@implementation SKNXPCSkimReader

@synthesize agentIdentifier=_agentIdentifier;

+ (SKNXPCSkimReader *)sharedReader {
    static id sharedReader = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedReader = [[self alloc] init];
    });
    return sharedReader;
}

- (void)destroyConnection {
    _agent = nil;
    
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
        // look for it in the Skim bundle
        NSString *SkimPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Skim"];
        path = SkimPath ? [[[NSBundle bundleWithPath:SkimPath] sharedSupportPath] stringByAppendingPathComponent:@"skimnotes"] : nil;
    }
    return path;
}

- (BOOL)launchedTask {
    BOOL taskLaunched = NO;
    NSString *launchPath = [self skimnotesToolPath];
    
    if (launchPath) {
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        
        // can also use a fixed identifier, or let the tool decide about an identifier and read it from stdout
        if (nil == [self agentIdentifier]) {
            NSString *identifier = [NSString stringWithFormat:@"%@.skimnotes-%@", bundleIdentifier, [[NSProcessInfo processInfo] globallyUniqueString]];
            if ([identifier length] > 127)
                identifier = [identifier substringFromIndex:[identifier length] - 127];
            [self setAgentIdentifier:identifier];
        }
        
        NSArray *arguments = @[launchPath, @"agent", @"-xpc", [self agentIdentifier]];

        AuthorizationRef auth = NULL;
        OSStatus createStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &auth);
        if (createStatus != errAuthorizationSuccess) {
            auth = NULL;
            NSLog(@"failed to create authorization reference: %d", createStatus);
        }
        
        if (auth != NULL) {
            NSString *label = [NSString stringWithFormat:@"%@.skimnotes-agent", bundleIdentifier];
            
            // Try to remove the job from launchd if it is already running
            // We could invoke SMJobCopyDictionary() first to see if the job exists, but I'd rather avoid
            // using it because the headers indicate it may be removed one day without any replacement
            CFErrorRef removeError = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if (false == SMJobRemove(kSMDomainUserLaunchd, (__bridge CFStringRef)(label), auth, true, &removeError)) {
#pragma clang diagnostic pop
                if (removeError != NULL) {
                    // It's normal for a job to not be found, so this is not an interesting error
                    if (CFErrorGetCode(removeError) != kSMErrorJobNotFound)
                        NSLog(@"remove job error: %@", removeError);
                    CFRelease(removeError);
                }
            }
            
            NSDictionary *jobDictionary = @{@"Label" : label, @"ProgramArguments" : arguments, @"EnableTransactions" : @NO, @"Nice" : @0, @"ProcessType": @"Interactive", @"MachServices" : @{[self agentIdentifier] : @YES}};
            
            CFErrorRef submitError = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            // SMJobSubmit is deprecated but is the only way to submit a non-permanent
            // helper and allows us to submit to user domain without requiring authorization
            if (SMJobSubmit(kSMDomainUserLaunchd, (__bridge CFDictionaryRef)jobDictionary, auth, &submitError)) {
#pragma clang diagnostic pop
                taskLaunched = YES;
            } else {
                if (submitError != NULL) {
                    NSLog(@"submit job error: %@", submitError);
                    CFRelease(submitError);
                }
            }
            AuthorizationFree(auth, kAuthorizationFlagDefaults);
        }
    } else {
        NSLog(@"failed to find skimnotes tool");
    }
    return taskLaunched;
}

- (void)establishSynchronousConnection:(BOOL)sync {
    if ([self launchedTask]) {
        _connection = [[NSXPCConnection alloc] initWithMachServiceName:[self agentIdentifier] options:0];
        [_connection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(SKNXPCAgentListenerProtocol)]];
        __weak SKNXPCSkimReader *weakSelf = self;
        [_connection setInvalidationHandler:^{
            [weakSelf destroyConnection];
        }];
        if (sync)
            _agent = [_connection synchronousRemoteObjectProxyWithErrorHandler:^(NSError *error){}];
        else
            _agent = [_connection remoteObjectProxy];
        _synchronous = sync;
        [_connection resume];
    }
}

- (BOOL)connectAndCheckTypeOfFile:(NSURL *)fileURL synchronous:(BOOL)sync {
    if (_connection && _synchronous != sync) {
        NSLog(@"attempt to mix synchronous and asynchronous skim notes retrieval");
        return NO;
    }
    
    // these checks are client side to avoid connecting to the server unless it's really necessary
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSString *fileType = [ws typeOfFile:[fileURL path] error:NULL];
    
    if (fileType != nil &&
        ([ws type:fileType conformsToType:(__bridge NSString *)kUTTypePDF] ||
         [ws type:fileType conformsToType:@"net.sourceforge.skim-app.pdfd"] ||
         [ws type:fileType conformsToType:@"net.sourceforge.skim-app.skimnotes"])) {
        if (nil == _connection)
            [self establishSynchronousConnection:sync];
        return YES;
    }
    return NO;
}

- (NSData *)SkimNotesAtURL:(NSURL *)fileURL {
    __block NSData *data = nil;
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:YES])
        [_agent readSkimNotesAtURL:fileURL reply:^(NSData *outData){ data = outData; }];
    return data;
}

- (NSData *)RTFNotesAtURL:(NSURL *)fileURL {
    __block NSData *data = nil;
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:YES])
        [_agent readRTFNotesAtURL:fileURL reply:^(NSData *outData){ data = outData; }];
    return data;
}

- (NSString *)textNotesAtURL:(NSURL *)fileURL {
    __block NSString *string = nil;
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:YES])
        [_agent readTextNotesAtURL:fileURL reply:^(NSString *outString){ string = outString; }];
    return string;
}

- (void)readSkimNotesAtURL:(NSURL *)fileURL reply:(void (^)(NSData *))reply {
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:NO])
        [_agent readSkimNotesAtURL:fileURL reply:reply];
    else
        reply(nil);
}

- (void)readRTFNotesAtURL:(NSURL *)fileURL reply:(void (^)(NSData *))reply {
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:NO])
        [_agent readRTFNotesAtURL:fileURL reply:reply];
    else
        reply(nil);
}

- (void)readTextNotesAtURL:(NSURL *)fileURL reply:(void (^)(NSString *))reply {
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:NO])
        [_agent readTextNotesAtURL:fileURL reply:reply];
    else
        reply(nil);
}

@end
