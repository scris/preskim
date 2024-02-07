//
//  SKSecondaryToolbarController.h
//  Skim
//
//  Created by Tianze Ds Qiu on 24/2/06.
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

#import "SKSecondaryToolbarController.h"
#import "SKStringConstants.h"
#import "SKTopBarView.h"
#import "SKPDFView.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSSegmentedControl_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "NSView_SKExtensions.h"


@implementation SKSecondaryToolbarController

@synthesize delegate, noteButton, ownerController, findString;

- (NSString *)nibName {
    return @"HighlightBar";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [noteButton setHelp:NSLocalizedString(@"Add New Highlight", @"Tool tip message") forSegment:SKFreeTextNote];
    [noteButton setHelp:NSLocalizedString(@"Add New Anchored Note", @"Tool tip message") forSegment:SKAnchoredNote];
    [noteButton setHelp:NSLocalizedString(@"Add New Circle", @"Tool tip message") forSegment:SKCircleNote];
    [noteButton setHelp:NSLocalizedString(@"Add New Box", @"Tool tip message") forSegment:SKSquareNote];
    [noteButton setHelp:NSLocalizedString(@"Add New Text Note", @"Tool tip message") forSegment:SKHighlightNote];
    [noteButton setHelp:NSLocalizedString(@"Add New Underline", @"Tool tip message") forSegment:SKUnderlineNote];
    [noteButton setHelp:NSLocalizedString(@"Add New Strike Out", @"Tool tip message") forSegment:SKStrikeOutNote];
    [noteButton setHelp:NSLocalizedString(@"Add New Line", @"Tool tip message") forSegment:SKLineNote];
    [noteButton setHelp:NSLocalizedString(@"Add New Freehand", @"Tool tip message") forSegment:SKInkNote];
    [noteButton setSegmentStyle:NSSegmentStyleSeparated];
    
    // Crack Items From: New Note Item Identifier
}

- (void)windowDidBecomeKey:(NSNotification *)notification {}

- (void)windowDidResignKey:(NSNotification *)notification {}

- (void)didAddBar {
    NSWindow *window = [[self view] window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification object:window];
    [self windowDidBecomeKey:nil];
}

- (void)setDelegate:(id <SKSecondaryToolbarControllerDelegate>)newDelegate {
    if (delegate && newDelegate == nil)
        [ownerController setContent:nil];
    delegate = newDelegate;
}

- (IBAction)remove:(id)sender {
    NSWindow *window = [[self view] window];
    if (window == nil)
        return;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidBecomeKeyNotification object:window];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResignKeyNotification object:window];
    [self windowDidResignKey:nil];
    
    [delegate removeSecondaryToolbarController];
}

- (IBAction)toggleCaseInsensitiveFind:(id)sender {
    BOOL caseInsensitive = [[NSUserDefaults standardUserDefaults] boolForKey:SKCaseInsensitiveFindKey];
    [[NSUserDefaults standardUserDefaults] setBool:NO == caseInsensitive forKey:SKCaseInsensitiveFindKey];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(toggleCaseInsensitiveFind:)) {
        [menuItem setState:[[NSUserDefaults standardUserDefaults] boolForKey:SKCaseInsensitiveFindKey] ? NSControlStateValueOn : NSOffState];
        return YES;
    }
    return YES;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    if (command == @selector(cancelOperation:)) {
        return YES;
    }
    return NO;
}

@end
