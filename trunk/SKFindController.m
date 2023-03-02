//
//  SKFindController.m
//  Skim
//
//  Created by Christiaan Hofman on 16/2/07.
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

#import "SKFindController.h"
#import "SKStringConstants.h"
#import "SKTopBarView.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSSegmentedControl_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "NSView_SKExtensions.h"


@implementation SKFindController

@synthesize delegate, findField, messageField, doneButton, navigationButton, ownerController, findString;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SKDESTROY(findString);
    SKDESTROY(findField);
    SKDESTROY(messageField);
    SKDESTROY(ownerController);
    SKDESTROY(doneButton);
    SKDESTROY(navigationButton);
    [super dealloc];
}

- (NSString *)nibName {
    return @"FindBar";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[self view] setAccessibilityLabel:NSLocalizedString(@"search bar", @"Accessibility description")];
    
    NSMenu *menu = [NSMenu menu];
    [menu addItemWithTitle:NSLocalizedString(@"Ignore Case", @"Menu item title") action:@selector(toggleCaseInsensitiveFind:) target:self];
    [[findField cell] setSearchMenuTemplate:menu];
    [[findField cell] setPlaceholderString:NSLocalizedString(@"Find", @"placeholder")];

    [navigationButton setHelp:NSLocalizedString(@"Find previous", @"Tool tip message") forSegment:0];
    [navigationButton setHelp:NSLocalizedString(@"Find next", @"Tool tip message") forSegment:1];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    NSPasteboard *findPboard = [NSPasteboard pasteboardWithName:NSFindPboard];
    if (lastChangeCount < [findPboard changeCount]) {
        NSArray *strings = [findPboard readObjectsForClasses:@[[NSString class]] options:@{}];
        if ([strings count] > 0) {
            [self setFindString:[strings objectAtIndex:0]];
            lastChangeCount = [findPboard changeCount];
            didChange = NO;
        }
    }
}

- (void)windowDidResignKey:(NSNotification *)notification {
    [self updateFindPboard];
}

- (void)updateFindPboard {
    if (didChange) {
        NSPasteboard *findPboard = [NSPasteboard pasteboardWithName:NSFindPboard];
        [findPboard clearContents];
        [findPboard writeObjects:@[(findString ?: @"")]];
        lastChangeCount = [findPboard changeCount];
        didChange = NO;
    }
}

- (void)didAddFindBar {
    NSWindow *window = [[self view] window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification object:window];
    [self windowDidBecomeKey:nil];
    [messageField setHidden:YES];
}

- (void)setDelegate:(id <SKFindControllerDelegate>)newDelegate {
    if (delegate && newDelegate == nil)
        [ownerController setContent:nil];
    delegate = newDelegate;
}

- (void)setFindString:(NSString *)newFindString {
    if (findString != newFindString) {
        [findString release];
        findString = [newFindString retain];
        didChange = YES;
    }
}

- (void)findForward:(BOOL)forward {
    BOOL found = YES;
    if ([findString length]) {
        found = [delegate findString:findString forward:forward];
        [self updateFindPboard];
    }
    [messageField setHidden:found];
}

- (IBAction)find:(id)sender {
    BOOL forward = [sender isKindOfClass:[NSSegmentedControl class]] ? [sender selectedSegment] == 1 : ([NSEvent modifierFlags] & NSEventModifierFlagShift) == 0;
    [self findForward:forward];
}

- (IBAction)remove:(id)sender {
    NSWindow *window = [[self view] window];
    if (window == nil)
        return;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:window];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignKeyNotification object:window];
    [self windowDidResignKey:nil];
    
    [messageField setHidden:YES];
    
    [delegate removeFindController:self];
}

- (IBAction)toggleCaseInsensitiveFind:(id)sender {
    BOOL caseInsensitive = [[NSUserDefaults standardUserDefaults] boolForKey:SKCaseInsensitiveFindKey];
    [[NSUserDefaults standardUserDefaults] setBool:NO == caseInsensitive forKey:SKCaseInsensitiveFindKey];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(toggleCaseInsensitiveFind:)) {
        [menuItem setState:[[NSUserDefaults standardUserDefaults] boolForKey:SKCaseInsensitiveFindKey] ? NSOnState : NSOffState];
        return YES;
    }
    return YES;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    if (command == @selector(cancelOperation:)) {
        [doneButton performClick:nil];
        return YES;
    }
    return NO;
}

@end
