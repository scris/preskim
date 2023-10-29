//
//  SKApplication.m
//  Skim
//
//  Created by Christiaan Hofman on 2/15/07.
/*
 This software is Copyright (c) 2007-2023
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

#import "SKApplication.h"
#import "NSMenu_SKExtensions.h"
#import "NSResponder_SKExtensions.h"
#import "NSDocument_SKExtensions.h"
#import "NSEvent_SKExtensions.h"

NSString *SKApplicationStartsTerminatingNotification = @"SKApplicationStartsTerminatingNotification";

@implementation SKApplication

@synthesize userAttentionDisabled;

- (NSInteger)requestUserAttention:(NSRequestUserAttentionType)requestType {
    return userAttentionDisabled ? 0 : [super requestUserAttention:requestType];
}

- (void)sendEvent:(NSEvent *)anEvent {
    if ([anEvent type] == NSEventTypeApplicationDefined && [anEvent subtype] == SKRemoteButtonEvent) {
        id target = [self targetForAction:@selector(remoteButtonPressed:)];
        if (target == nil) {
            target = [[NSDocumentController sharedDocumentController] currentDocument];
            if ([target respondsToSelector:@selector(remoteButtonPressed:)] == NO)
                target = nil;
        }
        if (target) {
            [target remoteButtonPressed:anEvent];
            return;
        }
    } else if ([anEvent type] == NSEventTypeTabletProximity) {
        [NSEvent setCurrentPointingDeviceType:[anEvent isEnteringProximity] ? [anEvent pointingDeviceType] : NSPointingDeviceTypeUnknown];
    }
    [super sendEvent:anEvent];
}

- (IBAction)terminate:(id)sender {
    NSNotification *notification = [NSNotification notificationWithName:SKApplicationStartsTerminatingNotification object:self];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
    if ([[self delegate] respondsToSelector:@selector(applicationStartsTerminating:)])
        [[self delegate] applicationStartsTerminating:notification];
    [super terminate:sender];
}

- (void)updatePresentationOptionsForWindow:(NSWindow *)aWindow {
    const NSApplicationPresentationOptions options[4] = {NSApplicationPresentationDefault,
            NSApplicationPresentationAutoHideDock | NSApplicationPresentationAutoHideMenuBar | NSApplicationPresentationFullScreen,
            NSApplicationPresentationHideDock | NSApplicationPresentationHideMenuBar
        };
    SKInteractionMode mode = [[[aWindow windowController] document] systemInteractionMode];
    if ([self presentationOptions] != options[mode])
        [self setPresentationOptions:options[mode]];
}

- (BOOL)willDragMouse {
    return NSEventTypeLeftMouseDragged == [[self nextEventMatchingMask:(NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged) untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:NO] type];
}

- (id <SKApplicationDelegate>)delegate { return (id <SKApplicationDelegate>)[super delegate]; }
- (void)setDelegate:(id <SKApplicationDelegate>)newDelegate { [super setDelegate:newDelegate]; }

#pragma mark Windows menu

- (void)reorganizeWindowsItem:(NSWindow *)aWindow {
    NSMenu *windowsMenu = [self windowsMenu];
    NSInteger nItems = [windowsMenu numberOfItems];
    NSInteger i = nItems;
    NSMutableArray *mainItems = [NSMutableArray array];
    NSMutableArray *auxItems = [NSMutableArray array];
    NSMutableArray *toSort = nil;
    NSMapTable *subItems = [NSMapTable strongToStrongObjectsMapTable];
    NSMenuItem *item;
    
    while (i-- > 0) {
        item = [windowsMenu itemAtIndex:i];
        if ([item isSeparatorItem] || [item action] != @selector(makeKeyAndOrderFront:)) break;
        
        NSWindow *window = [item target];
        NSWindowController *wc = [window windowController];
        NSDocument *doc = [wc document];
        NSMutableArray *items = nil;
        
        if (doc == nil) {
            items = auxItems;
        } else if ([wc isEqual:[[doc windowControllers] firstObject]]) {
            items = mainItems;
        } else {
            items = [subItems objectForKey:doc];
            if (items == nil) {
                items = [NSMutableArray array];
                [subItems setObject:items forKey:doc];
            }
            [item setIndentationLevel:1];
        }
        if (window == aWindow)
            toSort = items;
        [items insertObject:item atIndex:0];
        [windowsMenu removeItemAtIndex:i];
    }
    
    if ([toSort count] > 1)
        [toSort sortUsingDescriptors:@[[[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease]]];
    
    for (item in mainItems) {
        [windowsMenu addItem:item];
        NSDocument *doc = [[[item target] windowController] document];
        NSArray *subArray = [subItems objectForKey:doc];
        if ([subArray count]) {
            NSMenuItem *subItem;
            for (subItem in subArray)
                [windowsMenu addItem:subItem];
        }
        [subItems removeObjectForKey:doc];
    }
    
    if ([subItems count]) {
        for (NSDocument *doc in subItems) {
            for (item in [subItems objectForKey:doc])
                [windowsMenu addItem:item];
        }
    }
    
    for (item in auxItems)
        [windowsMenu addItem:item];
}

- (void)addWindowsItem:(NSWindow *)aWindow title:(NSString *)aString filename:(BOOL)isFilename {
    [super addWindowsItem:aWindow title:aString filename:isFilename];
    
    [self reorganizeWindowsItem:aWindow];
}

- (void)changeWindowsItem:(NSWindow *)aWindow title:(NSString *)aString filename:(BOOL)isFilename {
    [super changeWindowsItem:aWindow title:aString filename:isFilename];
    
    [self reorganizeWindowsItem:aWindow];
}

#pragma mark Scripting

- (id)newScriptingObjectOfClass:(Class)objectClass forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties {
    if ([key isEqualToString:@"orderedDocuments"]) {
        [[NSScriptCommand currentCommand] setScriptErrorNumber:NSOperationNotSupportedForKeyScriptError];
        [[NSScriptCommand currentCommand] setScriptErrorString:@"Cannot create new empty documents"];
        return nil;
    }
    return [super newScriptingObjectOfClass:objectClass forValueForKey:key withContentsValue:contentsValue properties:properties];
}

#pragma mark Template support

- (NSDate *)date { return [NSDate date]; }

- (NSString *)userName { return NSUserName(); }

- (NSString *)fullUserName { return NSFullUserName(); }

@end
