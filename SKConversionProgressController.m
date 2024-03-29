//
//  SKConversionProgressController.m
//  Skim
//
//  Created by Adam Maxwell on 12/6/06.
/*
 This software is Copyright (c) 2006
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

#import "SKConversionProgressController.h"
#import "NSString_SKExtensions.h"
#import "NSURL_SKExtensions.h"
#import "NSFileManager_SKExtensions.h"
#import "NSInvocation_SKExtensions.h"
#import "SKDocumentController.h"
#import "NSDocument_SKExtensions.h"
#import "NSError_SKExtensions.h"

#define PROVIDER_KEY    @"provider"
#define CONSUMER_KEY    @"consumer"
#define INPUTURL_KEY    @"inputURL"
#define PDFDATA_KEY     @"pdfData"
#define TOOLPATH_KEY    @"toolPath"

#define SKDviConversionCommandKey @"SKDviConversionCommand"
#define SKXdvConversionCommandKey @"SKXdvConversionCommand"
#define SKPSConversionCommandKey @"SKPSConversionCommand"

#define SKTouchBarItemIdentifierCancel @"scris.ds.preskim.touchbar-item.cancel"

#define PS_SEARCH_PATHS @[@"/usr/local/bin", @"/opt/sw/bin", @"/opt/local/bin", @"/opt/homebrew/bin"]
#define DVI_SEARCH_PATHS @[@"/Library/TeX/texbin", @"/opt/sw/bin", @"/opt/local/bin", @"/usr/local/bin"]

#define MIN_BUTTON_WIDTH 90.0

enum {
    SKConversionSucceeded = 0,
    SKConversionFailed = 1
};

@interface SKConversionProgressController (Private)
- (NSData *)newPDFDataFromURL:(NSURL *)aURL orData:(NSData *)aData ofType:(NSString *)aFileType error:(NSError **)outError;
- (void)conversionCompleted;
- (void)conversionStarted;
- (void)converterWasStopped;
- (void)setButtonTitle:(NSString *)title action:(SEL)action;
@end

#pragma mark Callbacks

static void PSConverterBeginDocumentCallback(void *info)
{
    id delegate = (__bridge id)info;
    if ([delegate respondsToSelector:@selector(conversionStarted)])
        [delegate performSelectorOnMainThread:@selector(conversionStarted) withObject:nil waitUntilDone:NO];
}

static void PSConverterEndDocumentCallback(void *info, bool success)
{
    id delegate = (__bridge id)info;
    if ([delegate respondsToSelector:@selector(conversionCompleted)])
        [delegate performSelectorOnMainThread:@selector(conversionCompleted) withObject:nil waitUntilDone:NO];
}

CGPSConverterCallbacks SKPSConverterCallbacks = { 
    0, 
    PSConverterBeginDocumentCallback, 
    PSConverterEndDocumentCallback, 
    NULL, // haven't seen this called in my testing
    NULL, 
    NULL, 
    NULL, // messages are usually not useful
    NULL 
};

#pragma mark -

@implementation SKConversionProgressController

@synthesize cancelButton, progressBar, textField;

+ (NSData *)newPDFDataFromURL:(NSURL *)aURL ofType:(NSString *)aFileType error:(NSError **)outError {
    return [[[self alloc] init] newPDFDataFromURL:aURL orData:nil ofType:aFileType error:outError];
}

+ (NSData *)newPDFDataWithPostScriptData:(NSData *)psData error:(NSError **)outError {
    return [[[self alloc] init] newPDFDataFromURL:nil orData:psData ofType:SKPostScriptDocumentType error:outError];
}

- (void)dealloc {
    if (converter) CFRelease(converter);
    converter = NULL;
}

- (void)windowDidLoad {
    [progressBar setUsesThreadedAnimation:YES];
    [self setButtonTitle:NSLocalizedString(@"Cancel", @"Button title") action:@selector(cancel:)];
    [[self window] setTitle:[NSString stringWithFormat:NSLocalizedString(@"Converting %@", @"PS conversion progress message"), [[NSDocumentController sharedDocumentController] displayNameForType:fileType]]];
}

- (NSString *)windowNibName { return @"ConversionProgressWindow"; }

- (IBAction)close:(id)sender { [NSApp stopModalWithCode:SKConversionFailed]; }

- (IBAction)cancel:(id)sender {
    if (cancelled == YES) {
        [self converterWasStopped];
    } else {
        cancelled = YES;
        if (converter)
            CGPSConverterAbort(converter);
        else if ([task isRunning])
            [task terminate];
    }
}

- (void)converterWasStopped {
    NSBeep();
    [textField setStringValue:NSLocalizedString(@"Converter already stopped.", @"PS conversion progress message")];
    [self setButtonTitle:NSLocalizedString(@"Close", @"Button title") action:@selector(close:)];
}

- (void)conversionCompleted {
    [textField setStringValue:NSLocalizedString(@"File successfully converted!", @"PS conversion progress message")];
    [progressBar stopAnimation:nil];
    [self setButtonTitle:NSLocalizedString(@"Close", @"Button title") action:@selector(close:)];
}

- (void)conversionStarted {
    [progressBar startAnimation:nil];
    [textField setStringValue:[[[self window] title] stringByAppendingEllipsis]];
}

- (void)setButtonTitle:(NSString *)title action:(SEL)action {
    [cancelButton setTitle:title];
    [cancelButton setAction:action];
    [cancelButton setNeedsLayout:YES];
}

- (void)stopModalWithResult:(NSNumber *)result {
    [NSApp stopModalWithCode:[result boolValue] ? SKConversionSucceeded : SKConversionFailed];
}

- (void)convertPostScriptWithProvider:(CGDataProviderRef)provider {
    // pass self as info
    converter = CGPSConverterCreate((void *)self, &SKPSConverterCallbacks, NULL);
    NSAssert(converter != NULL, @"unable to create PS converter");
    NSAssert(provider != NULL, @"no PS data provider");
    CGDataProviderRetain(provider);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CFMutableDataRef pdfData = CFDataCreateMutable(kCFAllocatorDefault, 0);
        CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(pdfData);
        
        Boolean success = CGPSConverterConvert(converter, provider, consumer, NULL);
        
        if (success)
            outputData = [(__bridge NSData *)pdfData copy];
        
        CGDataProviderRelease(provider);
        CGDataConsumerRelease(consumer);
        CFRelease(pdfData);
        
        // we don't use GCD for the callback, because on Mountain Lion the messages is never received, even though that works on Snow Leopard
        [self performSelectorOnMainThread:@selector(stopModalWithResult:) withObject:[NSNumber numberWithBool:success] waitUntilDone:NO];
    });
    
}

static NSString *toolPathForCommand(NSString *defaultKey, NSArray *supportedTools) {
    NSString *commandPath = [[NSUserDefaults standardUserDefaults] stringForKey:defaultKey];
    NSString *commandName = [commandPath lastPathComponent];
    NSArray *paths = [[supportedTools firstObject] isEqualToString:@"ps2pdf"] ? PS_SEARCH_PATHS : DVI_SEARCH_PATHS;
    NSInteger i = 0, iMax = [paths count];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSEnumerator *toolEnum = [supportedTools objectEnumerator];
    
    if (commandName == nil || [supportedTools containsObject:commandName] == NO)
        commandName = [toolEnum nextObject];
    do {
        i = 0;
        while ([fm isExecutableFileAtPath:commandPath] == NO) {
            if (i >= iMax) {
                commandPath = nil;
                break;
            }
            commandPath = [[paths objectAtIndex:i++] stringByAppendingPathComponent:commandName];
        }
    } while (commandPath == nil && (commandName = [toolEnum nextObject]));
    
    return commandPath;
}

+ (NSString *)toolPathForType:(NSString *)fileType {
    static NSMutableDictionary *toolPaths = nil;
    NSString *toolPath = [toolPaths objectForKey:fileType];
    if (toolPath == nil) {
        NSWorkspace *ws = [NSWorkspace sharedWorkspace];
        if ([ws type:fileType conformsToType:SKDVIDocumentType]) {
            if (@available(macOS 14.0, *))
                toolPath = toolPathForCommand(SKDviConversionCommandKey, @[@"dvipdfmx", @"dvipdfm", @"dvipdf"]);
            else
                toolPath = toolPathForCommand(SKDviConversionCommandKey, @[@"dvipdfmx", @"dvipdfm", @"dvipdf", @"dvips"]);
        } else if ([ws type:fileType conformsToType:SKXDVDocumentType]) {
            toolPath = toolPathForCommand(SKXdvConversionCommandKey, @[@"xdvipdfmx", @"dvipdfmx", @"xdv2pdf"]);
        } else if ([ws type:fileType conformsToType:SKPostScriptDocumentType]) {
            toolPath = toolPathForCommand(SKPSConversionCommandKey, @[@"ps2pdf", @"ps2pdf12", @"ps2pdf13", @"ps2pdf14", @"pstopdf"]);
        }
        if (toolPath) {
            if (toolPaths == nil)
                toolPaths = [[NSMutableDictionary alloc] init];
            [toolPaths setObject:toolPath forKey:fileType];
        }
    }
    return toolPath;
}

- (void)taskFinished:(NSNotification *)notification {
    BOOL success = [[notification object] terminationStatus] == 0 &&
                   [outputFileURL checkResourceIsReachableAndReturnError:NULL] &&
                   cancelled == NO;
    
    task = nil;
    
    if (success && [[outputFileURL pathExtension] isCaseInsensitiveEqual:@"ps"]) {
        CGDataProviderRef provider = CGDataProviderCreateWithURL((CFURLRef)outputFileURL);
        [self convertPostScriptWithProvider:provider];
        CGDataProviderRelease(provider);
    } else {
        if (success)
            outputData = [[NSData alloc] initWithContentsOfURL:outputFileURL];
        [self conversionCompleted];
        [NSApp stopModalWithCode:success ? SKConversionSucceeded : SKConversionFailed];
    }
}

- (NSData *)newPDFDataFromURL:(NSURL *)aURL orData:(NSData *)aData ofType:(NSString *)aFileType error:(NSError **)outError {
    NSAssert(NULL == converter && nil == task, @"attempted to reenter SKConversionProgressController, but this is not supported");
    
    fileType = aFileType;
    cancelled = NO;
    
    CGDataProviderRef provider = NULL;
    BOOL useTask = YES;
    if (@available(macOS 14.0, *)) {} else if ([[NSWorkspace sharedWorkspace] type:fileType conformsToType:SKPostScriptDocumentType])
        useTask = NO;
    
    if (useTask) {
        
        NSString *toolPath = [[self class] toolPathForType:fileType];
        if (toolPath) {
            NSString *commandName = [toolPath lastPathComponent];
            NSURL *tmpDirURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:aURL create:YES error:NULL];
            BOOL outputPS = [commandName isEqualToString:@"dvips"];
            NSURL *outFileURL = [tmpDirURL URLByAppendingPathComponent:[aURL lastPathComponentReplacingPathExtension:outputPS ? @"ps" : @"pdf"] isDirectory:NO];
            BOOL isStandardPS = [commandName hasPrefix:@"ps2pdf"] && ([PS_SEARCH_PATHS containsObject:[toolPath stringByDeletingLastPathComponent]]);
            NSArray *arguments = isStandardPS ? @[@"-dALLOWPSTRANSPARENCY", [aURL path], [outFileURL path]] : [commandName isEqualToString:@"dvipdf"] || [commandName hasPrefix:@"ps2pdf"] ? @[[aURL path], [outFileURL path]] : @[@"-o", [outFileURL path], [aURL path]];
            
            task = [[NSTask alloc] init];
            [task setLaunchPath:toolPath];
            [task setArguments:arguments];
            [task setCurrentDirectoryPath:[[aURL URLByDeletingLastPathComponent] path]];
            [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
            [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskFinished:) name:NSTaskDidTerminateNotification object:task];
            
            outputFileURL = outFileURL;
        }
        
    } else if (aURL) {
        
        provider = CGDataProviderCreateWithURL((CFURLRef)aURL);
        
    } else if (aData) {
        
        provider = CGDataProviderCreateWithCFData((CFDataRef)aData);
        
    }
    
    NSModalSession session = [NSApp beginModalSessionForWindow:[self window]];
    NSInteger rv = NSModalResponseContinue;
    
    if (provider) {
        [self convertPostScriptWithProvider:provider];
        CGDataProviderRelease(provider);
    } else if (task) {
        @try {
            [task launch];
            [self conversionStarted];
        }
        @catch(id exception) {
            task = nil;
            [NSApp stopModalWithCode:SKConversionFailed];
        }
    } else {
        [NSApp stopModalWithCode:SKConversionFailed];
    }
    
    while (rv == NSModalResponseContinue)
        rv = [NSApp runModalSession:session];
    [NSApp endModalSession:session];
    
    if (outputFileURL)
        [[NSFileManager defaultManager] removeItemAtURL:[outputFileURL URLByDeletingLastPathComponent] error:NULL];
    
    if (rv != SKConversionSucceeded && outError) {
        if (cancelled)
            *outError = [NSError userCancelledErrorWithUnderlyingError:nil];
        else
            *outError = [NSError readFileErrorWithLocalizedDescription:NSLocalizedString(@"Unable to load file", @"Error description")];
    }
    
    [self close];
    
    return outputData;
}

#pragma mark Touch Bar

- (NSTouchBar *)makeTouchBar {
    NSTouchBar *touchBar = [[NSTouchBar alloc] init];
    [touchBar setDelegate:self];
    [touchBar setDefaultItemIdentifiers:@[NSTouchBarItemIdentifierFlexibleSpace, SKTouchBarItemIdentifierCancel, NSTouchBarItemIdentifierFixedSpaceLarge]];
    return touchBar;
}

- (NSTouchBarItem *)touchBar:(NSTouchBar *)aTouchBar makeItemForIdentifier:(NSString *)identifier {
    NSCustomTouchBarItem *item = nil;
    if ([identifier isEqualToString:SKTouchBarItemIdentifierCancel]) {
        NSButton *button = [NSButton buttonWithTitle:[cancelButton title] target:[cancelButton target] action:[cancelButton action]];
        item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        [(NSCustomTouchBarItem *)item setView:button];
    }
    return item;
}

@end
