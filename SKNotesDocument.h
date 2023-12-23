//
//  SKNotesDocument.h
//  Skim
//
//  Created by Christiaan Hofman on 4/10/07.
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

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "SKNoteOutlineView.h"
#import "SKNoteTypeSheetController.h"
#import "NSDocument_SKExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@class SKNoteOutlineView, SKStatusBar;

@interface SKNotesDocument : NSDocument <NSWindowDelegate, NSToolbarDelegate, SKNoteOutlineViewDelegate, NSOutlineViewDataSource, SKNoteTypeSheetControllerDelegate> {
    SKNoteOutlineView *outlineView;
    NSArrayController *arrayController;
    NSSearchField *searchField;
    SKStatusBar *statusBar;
    NSDictionary *toolbarItems;
    NSArray<PDFAnnotation *> *notes;
    NSArray<NSDictionary<NSString *, id> *> *unsupportedNotes;
    PDFDocument *pdfDocument;
    NSURL *sourceFileURL;
    NSMapTable *rowHeights;
    SKNoteTypeSheetController *noteTypeSheetController;
    NSRect windowRect;
    struct _ndFlags {
        unsigned int exportUsingPanel:1;
        unsigned int caseInsensitiveSearch:1;
        unsigned int autoResizeRows:1;
        unsigned int settingUpWindow:1;
    } ndFlags;
}

@property (nonatomic, nullable, strong) IBOutlet SKNoteOutlineView *outlineView;
@property (nonatomic, nullable, strong) IBOutlet SKStatusBar *statusBar;
@property (nonatomic, nullable, strong) IBOutlet NSArrayController *arrayController;
@property (nonatomic, nullable, strong) IBOutlet NSSearchField *searchField;
@property (nonatomic, readonly,) NSArray<PDFAnnotation *> *notes;
@property (nonatomic, nullable, readonly) PDFDocument *pdfDocument;
@property (nonatomic, nullable, readonly) NSWindow *window;
@property (nonatomic, nullable, strong) NSURL *sourceFileURL;
@property (nonatomic, readonly) SKInteractionMode interactionMode;

- (IBAction)openPDF:(nullable id)sender;
- (IBAction)searchNotes:(nullable id)sender;
- (IBAction)toggleStatusBar:(nullable id)sender;
- (IBAction)toggleCaseInsensitiveSearch:(nullable id)sender;
- (IBAction)toggleFullscreen:(nullable id)sender;

- (void)setupToolbarForWindow:(NSWindow *)aWindow;

@end

NS_ASSUME_NONNULL_END
