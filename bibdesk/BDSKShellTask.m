//
//  BDSKShellTask.m
//  BibDesk
//
//  Created by Michael McCracken on Sat Dec 14 2002.
/*
 This software is Copyright (c) 2002,2003,2004,2005,2006,2007
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "BDSKShellTask.h"
#import "BibAppController.h"

volatile int caughtSignal = 0;

@interface BDSKShellTask (Private)
// Note: the returned data is not autoreleased
- (NSData *)privateRunShellCommand:(NSString *)cmd withInputString:(NSString *)input;
- (NSData *)privateExecuteBinary:(NSString *)executablePath inDirectory:(NSString *)currentDirPath withArguments:(NSArray *)args environment:(NSDictionary *)env inputString:(NSString *)input;
- (void)stdoutNowAvailable:(NSNotification *)notification;
@end


@implementation BDSKShellTask

+ (NSString *)runShellCommand:(NSString *)cmd withInputString:(NSString *)input{
    BDSKShellTask *shellTask = [[self alloc] init];
    NSString *output = nil;
    NSData *outputData = [shellTask privateRunShellCommand:cmd withInputString:input];
    if(outputData){
        output = [[NSString allocWithZone:[self zone]] initWithData:outputData encoding:NSUTF8StringEncoding];
        if(!output)
            output = [[NSString allocWithZone:[self zone]] initWithData:outputData encoding:NSASCIIStringEncoding];
        if(!output)
            output = [[NSString allocWithZone:[self zone]] initWithData:outputData encoding:[NSString defaultCStringEncoding]];
    }
    [shellTask release];
    return [output autorelease];
}

+ (NSData *)runRawShellCommand:(NSString *)cmd withInputString:(NSString *)input{
    BDSKShellTask *shellTask = [[self alloc] init];
    NSData *output = [[shellTask privateRunShellCommand:cmd withInputString:input] retain];
    [shellTask release];
    return [output autorelease];
}

+ (NSString *)executeBinary:(NSString *)executablePath inDirectory:(NSString *)currentDirPath withArguments:(NSArray *)args environment:(NSDictionary *)env inputString:(NSString *)input{
    BDSKShellTask *shellTask = [[self alloc] init];
    NSString *output = nil;
    NSData *outputData = [shellTask privateExecuteBinary:executablePath inDirectory:currentDirPath withArguments:args environment:env inputString:input];
    if(outputData){
        output = [[NSString allocWithZone:[self zone]] initWithData:outputData encoding:NSUTF8StringEncoding];
        if(!output)
            output = [[NSString allocWithZone:[self zone]] initWithData:outputData encoding:NSASCIIStringEncoding];
        if(!output)
            output = [[NSString allocWithZone:[self zone]] initWithData:outputData encoding:[NSString defaultCStringEncoding]];
    }
    [shellTask release];
    return [output autorelease];
}

- (id)init{
    self = [super init];
    if(self)
        stdoutData = [[NSMutableData alloc] init];
    return self;
}

- (void)dealloc{
    [stdoutData release];
    [super dealloc];
}

@end


@implementation BDSKShellTask (Private)

//
// The following three methods are borrowed from Mike Ferris' TextExtras.
// For the real versions of them, check out http://www.lorax.com/FreeStuff/TextExtras.html
// - mmcc

// was runWithInputString in TextExtras' TEPipeCommand class.
- (NSData *)privateRunShellCommand:(NSString *)cmd withInputString:(NSString *)input{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *shellPath = @"/bin/sh";
    NSString *shellScriptPath = [[NSApp delegate] temporaryFilePath:@"shellscript" createDirectory:NO];
    NSString *script;
    NSData *scriptData;
    NSMutableDictionary *currentAttributes;
    unsigned long currentMode;
    NSData *output = nil;

    // ---------- Check the shell and create the script ----------
    if (![fm isExecutableFileAtPath:shellPath]) {
        NSLog(@"Filter Pipes: Shell path for Pipe panel does not exist or is not executable. (%@)", shellPath);
        return nil;
    }
    if (!cmd){
        return nil;
    }
    script = [NSString stringWithFormat:@"#!%@\n\n%@\n", shellPath, cmd];
    // Use UTF8... and write out the shell script and make it exectuable
    scriptData = [script dataUsingEncoding:NSUTF8StringEncoding];
    if (![scriptData writeToFile:shellScriptPath atomically:YES]) {
        NSLog(@"Filter Pipes: Failed to write temporary script file. (%@)", shellScriptPath);
        return nil;
    }
    currentAttributes = [[[fm fileAttributesAtPath:shellScriptPath traverseLink:NO] mutableCopyWithZone:[self zone]] autorelease];
    if (!currentAttributes) {
        NSLog(@"Filter Pipes: Failed to get attributes of temporary script file. (%@)", shellScriptPath);
        return nil;
    }
    currentMode = [currentAttributes filePosixPermissions];
    currentMode |= S_IRWXU;
    [currentAttributes setObject:[NSNumber numberWithUnsignedLong:currentMode] forKey:NSFilePosixPermissions];
    if (![fm changeFileAttributes:currentAttributes atPath:shellScriptPath]) {
        NSLog(@"Filter Pipes: Failed to get attributes of temporary script file. (%@)", shellScriptPath);
        return nil;
    }

    // ---------- Execute the script ----------

    // MF:!!! The current working dir isn't too appropriate
    output = [self privateExecuteBinary:shellScriptPath inDirectory:[shellScriptPath stringByDeletingLastPathComponent] withArguments:nil environment:nil inputString:input];

    // ---------- Remove the script file ----------
    if (![fm removeFileAtPath:shellScriptPath handler:nil]) {
        NSLog(@"Filter Pipes: Failed to delete temporary script file. (%@)", shellScriptPath);
    }

    return output;
}

// This method and the little notification method following implement synchronously running a task with input piped in from a string and output piped back out and returned as a string.   They require only a stdoutData instance variable to function.
- (NSData *)privateExecuteBinary:(NSString *)executablePath inDirectory:(NSString *)currentDirPath withArguments:(NSArray *)args environment:(NSDictionary *)env inputString:(NSString *)input {
    NSTask *task;
    NSPipe *inputPipe;
    NSPipe *outputPipe;
    NSFileHandle *inputFileHandle;
    NSFileHandle *outputFileHandle;

    task = [[NSTask allocWithZone:[self zone]] init];    
    [task setLaunchPath:executablePath];
    if (currentDirPath) {
        [task setCurrentDirectoryPath:currentDirPath];
    }
    if (args) {
        [task setArguments:args];
    }
    if (env) {
        [task setEnvironment:env];
    }

    [task setStandardError:[NSFileHandle fileHandleWithStandardError]];
    inputPipe = [NSPipe pipe];
    inputFileHandle = [inputPipe fileHandleForWriting];
    [task setStandardInput:inputPipe];
    outputPipe = [NSPipe pipe];
    outputFileHandle = [outputPipe fileHandleForReading];
    [task setStandardOutput:outputPipe];
    
    // ignore SIGPIPE, as it causes a crash (seems to happen if the binaries don't exist and you try writing to the pipe)
    signal(SIGPIPE, SIG_IGN);

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    @try{
        
        [nc addObserver:self selector:@selector(stdoutNowAvailable:) name:NSFileHandleReadCompletionNotification object:outputFileHandle];
        [outputFileHandle readInBackgroundAndNotify];

        [task launch];

        if ([task isRunning]) {
            
            // run the runloop and pick up our notifications
            [task waitUntilExit];
            
            [nc removeObserver:self name:NSFileHandleReadCompletionNotification object:outputFileHandle];
            
        } else {
            NSLog(@"Failed to launch task or task exited without accepting input.  Termination status was %d", [task terminationStatus]);
        }
    }
    @catch(id exception){
        // if the pipe failed, we catch an exception here and ignore it
        NSLog(@"exception %@ encountered while trying to launch task %@", exception, executablePath);
        [nc removeObserver:self name:NSFileHandleReadCompletionNotification object:outputFileHandle];
    }
    
    // reset signal handling to default behavior
    signal(SIGPIPE, SIG_DFL);
    [task release];

    return [stdoutData length] ? stdoutData : nil;
}

- (void)stdoutNowAvailable:(NSNotification *)notification {
    NSData *outputData = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    if ([outputData length]) {
        [stdoutData appendData:outputData];
    }
    [[notification object] readInBackgroundAndNotify];
}


@end
