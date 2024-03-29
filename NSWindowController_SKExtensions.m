//
//  NSWindowController_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 3/21/07.
/*
 This software is Copyright (c) 2007
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

#import "NSWindowController_SKExtensions.h"
#import "NSInvocation_SKExtensions.h"
#import "NSPointerArray_SKExtensions.h"
#import "NSPointerFunctions_SKExtensions.h"


@implementation NSWindowController (SKExtensions)

- (void)setWindowFrameAutosaveNameOrCascade:(NSString *)name {
    static NSMapTable *nextWindowLocations = nil;
    if (nextWindowLocations == nil)
        nextWindowLocations = [[NSMapTable alloc] initWithKeyPointerFunctions:[NSPointerFunctions strongPointerFunctions] valuePointerFunctions:[NSPointerFunctions pointPointerFunctions] capacity:0];
    
    NSPointPointer pointPtr = (NSPointPointer)NSMapGet(nextWindowLocations, (__bridge void *)name);
    NSPoint point;
    
    // [[self window] setFrameUsingName:name];
    [self setShouldCascadeWindows:NO];
    if ([[self window] setFrameAutosaveName:name] || pointPtr == NULL) {
        NSRect windowFrame = [[self window] frame];
        point = NSMakePoint(NSMinX(windowFrame), NSMaxY(windowFrame));
    } else {
        point = *pointPtr;
    }
    point = [[self window] cascadeTopLeftFromPoint:point];
    NSMapInsert(nextWindowLocations, (__bridge void *)name, &point);
}

- (BOOL)isNoteWindowController { return NO; }

- (void)beginSheetModalForWindow:(NSWindow *)window completionHandler:(void (^)(NSModalResponse result))handler {
    NS_VALID_UNTIL_END_OF_SCOPE __block id strongSelf = self;
    [window beginSheet:[self window] completionHandler:^(NSModalResponse result){
        if (handler)
            handler(result);
        strongSelf = nil;
    }];
}

- (IBAction)dismissSheet:(id)sender {
    NSWindow *window = [[self window] sheetParent];
    [window endSheet:[self window] returnCode:[sender tag]];
}

@end
