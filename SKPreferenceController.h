//
//  SKPreferenceController.h
//  Skim
//
//  Created by Christiaan Hofman on 2/10/07.
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SKPreferencePane;

@interface SKPreferenceController : NSWindowController <NSWindowDelegate, NSTabViewDelegate, NSToolbarDelegate, NSTouchBarDelegate> {
    NSButton *resetButton;
    NSButton *resetAllButton;
    NSSegmentedControl *panesButton;
    NSTextView *fieldEditor;
    NSArray<NSViewController<SKPreferencePane> *> *preferencePanes;
    NSViewController<SKPreferencePane> *currentPane;
    NSMutableArray *history;
    NSUInteger historyIndex;
}

@property (nonatomic, nullable, strong) IBOutlet NSButton *resetButton, *resetAllButton;

@property (class, nonatomic, readonly) SKPreferenceController *sharedPrefenceController;

- (IBAction)resetAll:(nullable id)sender;
- (IBAction)resetCurrent:(nullable id)sender;

- (IBAction)doGoToNextPage:(nullable id)sender;
- (IBAction)doGoToPreviousPage:(nullable id)sender;
- (IBAction)doGoToFirstPage:(nullable id)sender;
- (IBAction)doGoToLastPage:(nullable id)sender;
- (IBAction)doGoBack:(nullable id)sender;
- (IBAction)doGoForward:(nullable id)sender;

- (IBAction)changeFont:(nullable id)sender;
- (IBAction)changeAttributes:(nullable id)sender;

@end


@protocol SKPreferencePane
@property NSString* systemSymbol;
@optional
- (void)defaultsDidRevert;
@end

NS_ASSUME_NONNULL_END
