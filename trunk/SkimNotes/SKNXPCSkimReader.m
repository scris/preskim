//
//  SKNXPCSkimReader.m
//  SkimNotesTest
//
//  Created by Christiaan Hofman on 24/11/2023.
/*
 This software is Copyright (c) 2023
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

@synthesize agentIdentifier;

+ (id)sharedReader {
    static id sharedReader = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedReader = [[self alloc] init];
    });
    return sharedReader;
}

- (void)destroyConnection {
    [agent release];
    agent = nil;
    
    [connection invalidate];
    [connection release];
    connection = nil;
}

- (void)dealloc {
    [self destroyConnection];
    [agentIdentifier release];
    [super dealloc];
}

- (void)setAgentIdentifier:(NSString *)identifier {
    NSAssert(connection == nil, @"agentIdentifier must be set before connecting");
    if (connection == nil && agentIdentifier != identifier) {
        [agentIdentifier release];
        agentIdentifier = [identifier retain];
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
            if (false == SMJobRemove(kSMDomainUserLaunchd, (CFStringRef)(label), auth, true, &removeError)) {
#pragma clang diagnostic pop
                if (removeError != NULL) {
                    // It's normal for a job to not be found, so this is not an interesting error
                    if (CFErrorGetCode(removeError) != kSMErrorJobNotFound)
                        NSLog(@"remove job error: %@", removeError);
                    CFRelease(removeError);
                }
            }
            
            NSDictionary *jobDictionary = @{@"Label" : label, @"ProgramArguments" : arguments, @"EnableTransactions" : @NO, @"KeepAlive" : @{@"SuccessfulExit" : @NO}, @"RunAtLoad" : @NO, @"Nice" : @0, @"ProcessType": @"Interactive", @"LaunchOnlyOnce": @YES, @"MachServices" : @{[self agentIdentifier] : @YES}};
            
            CFErrorRef submitError = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            // SMJobSubmit is deprecated but is the only way to submit a non-permanent
            // helper and allows us to submit to user domain without requiring authorization
            if (SMJobSubmit(kSMDomainUserLaunchd, (CFDictionaryRef)jobDictionary, auth, &submitError)) {
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
        connection = [[NSXPCConnection alloc] initWithMachServiceName:[self agentIdentifier] options:0];
        [connection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(SKNXPCAgentListenerProtocol)]];
        [connection setInvalidationHandler:^{
            [self destroyConnection];
        }];
        if (sync)
            agent = [[connection synchronousRemoteObjectProxyWithErrorHandler:^(NSError *error){}] retain];
        else
            agent = [[connection remoteObjectProxy] retain];
        synchronous = sync;
        [connection resume];
    }
}

- (BOOL)connectAndCheckTypeOfFile:(NSURL *)fileURL synchronous:(BOOL)sync {
    if (connection && synchronous != sync) {
        NSLog(@"attempt to mix synchronous and asynchronous skim notes retrieval");
        return NO;
    }
    
    // these checks are client side to avoid connecting to the server unless it's really necessary
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSString *fileType = [ws typeOfFile:[fileURL path] error:NULL];
    
    if (fileType != nil &&
        ([ws type:fileType conformsToType:(NSString *)kUTTypePDF] ||
         [ws type:fileType conformsToType:@"net.sourceforge.skim-app.pdfd"] ||
         [ws type:fileType conformsToType:@"net.sourceforge.skim-app.skimnotes"])) {
        if (nil == connection)
            [self establishSynchronousConnection:sync];
        return YES;
    }
    return NO;
}

- (NSData *)SkimNotesAtURL:(NSURL *)fileURL {
    __block NSData *data = nil;
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:YES])
        [agent readSkimNotesAtURL:fileURL reply:^(NSData *outData){ data = [outData retain]; }];
    return [data autorelease];
}

- (NSData *)RTFNotesAtURL:(NSURL *)fileURL {
    __block NSData *data = nil;
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:YES])
        [agent readRTFNotesAtURL:fileURL reply:^(NSData *outData){ data = [outData retain]; }];
    return [data autorelease];
}

- (NSString *)textNotesAtURL:(NSURL *)fileURL {
    __block NSString *string = nil;
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:YES])
        [agent readTextNotesAtURL:fileURL reply:^(NSString *outString){ string = [outString retain]; }];
    return [string autorelease];
}

- (void)readSkimNotesAtURL:(NSURL *)fileURL reply:(void (^)(NSData *))reply {
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:NO])
        [agent readSkimNotesAtURL:fileURL reply:reply];
    else
        reply(nil);
}

- (void)readRTFNotesAtURL:(NSURL *)fileURL reply:(void (^)(NSData *))reply {
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:NO])
        [agent readRTFNotesAtURL:fileURL reply:reply];
    else
        reply(nil);
}

- (void)readTextNotesAtURL:(NSURL *)fileURL reply:(void (^)(NSString *))reply {
    if ([self connectAndCheckTypeOfFile:fileURL synchronous:NO])
        [agent readTextNotesAtURL:fileURL reply:reply];
    else
        reply(nil);
}

@end
