//
//  SKNoteWindowController.m
//  Skim
//
//  Created by Christiaan Hofman on 12/15/06.
/*
 This software is Copyright (c) 2006
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

#import "SKNoteWindowController.h"
#import <Quartz/Quartz.h>
#import "SKDragImageView.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKNPDFAnnotationNote_SKExtensions.h"
#import "SKStatusBar.h"
#import "SKMainDocument.h"
#import "SKPDFView.h"
#import "NSWindowController_SKExtensions.h"
#import "NSUserDefaultsController_SKExtensions.h"
#import "SKStringConstants.h"
#import "PDFPage_SKExtensions.h"
#import "NSValueTransformer_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "SKNoteTextView.h"
#import "NSInvocation_SKExtensions.h"
#import "NSURL_SKExtensions.h"
#import "SKMainWindowController.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "NSPasteboard_SKExtensions.h"
#import "NSAttributedString_SKExtensions.h"
#import "SKChainedUndoManager.h"
#import "SKApplicationController.h"

#define SKNoteWindowFrameAutosaveName @"SKNoteWindow"
#define SKAnyNoteWindowFrameAutosaveName @"SKAnyNoteWindow"

#define SKKeepNoteWindowsOnTopKey @"SKKeepNoteWindowsOnTop"

#define DEFAULT_TEXT_HEIGHT 29.0

static char SKNoteWindowDefaultsObservationContext;
static char SKNoteWindowNoteObservationContext;

@interface SKAddTextColorTransformer : NSValueTransformer
@end

#pragma mark -

@interface SKNoteWindowController (SKPrivate)
- (void)handleApplicationWillTerminate:(NSNotification *)notification;
- (void)handlePageLabelsChangedNotification:(NSNotification *)notification;
@end

@implementation SKNoteWindowController

@synthesize textView, topView, edgeView, imageView, statusBar, iconTypePopUpButton, iconLabelField, checkButton, noteController, note, keepOnTop, forceOnTop;
@dynamic isNoteType;

static NSImage *noteIcons[7] = {nil, nil, nil, nil, nil, nil, nil};

+ (void)makeNoteIcons {
    if (noteIcons[0]) return;
    
    NSRect bounds = {NSZeroPoint, SKNPDFAnnotationNoteSize};
    PDFAnnotation *annotation = [[PDFAnnotation alloc] initWithBounds:bounds forType:PDFAnnotationSubtypeText withProperties:@{PDFAnnotationKeyColor:[NSColor clearColor]}];
    PDFPage *page = [[PDFPage alloc] init];
    [page setBounds:bounds forBox:kPDFDisplayBoxMediaBox];
    [page addAnnotation:annotation];
    
    NSUInteger i;
    for (i = 0; i < 7; i++) {
        [annotation setIconType:i];
        noteIcons[i] = [[NSImage alloc] initWithSize:SKNPDFAnnotationNoteSize];
        [noteIcons[i] lockFocus];
        [page drawWithBox:kPDFDisplayBoxMediaBox toContext:[[NSGraphicsContext currentContext] CGContext]];
        [noteIcons[i] unlockFocus];
        [noteIcons[i] setTemplate:YES];
    }
}

+ (NSArray *)fontKeysToObserve {
    return @[SKAnchoredNoteFontNameKey, SKAnchoredNoteFontSizeKey];
}

+ (void)initialize {
    SKINITIALIZE;
    [self makeNoteIcons];
}

static NSURL *temporaryDirectoryURL = nil;

+ (NSURL *)temporaryDirectoryURL {
    if (temporaryDirectoryURL == nil) {
        char *template = strdup([[NSTemporaryDirectory() stringByAppendingPathComponent:@"Preskim.XXXXXX"] fileSystemRepresentation]);
        const char *tempPath = mkdtemp(template);
        NSString *tmpPath = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempPath length:strlen(tempPath)];
        temporaryDirectoryURL = [[NSURL alloc] initFileURLWithPath:tmpPath];
        free(template);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillTerminate:) name:NSApplicationWillTerminateNotification object:NSApp];
    }
    if ([temporaryDirectoryURL checkResourceIsReachableAndReturnError:NULL] == NO)
        [[NSFileManager defaultManager] createDirectoryAtPath:[temporaryDirectoryURL path] withIntermediateDirectories:YES attributes:nil error:NULL];
    return temporaryDirectoryURL;
}

- (instancetype)init {
    return [self initWithNote:nil];
}

- (instancetype)initWithNote:(PDFAnnotation *)aNote {
    self = [super initWithWindowNibName:@"NoteWindow"];
    if (self) {
        note = aNote;
        
        keepOnTop = [[NSUserDefaults standardUserDefaults] boolForKey:SKKeepNoteWindowsOnTopKey];
        forceOnTop = NO;
        
        [note addObserver:self forKeyPath:SKNPDFAnnotationPageKey options:0 context:&SKNoteWindowNoteObservationContext];
        [note addObserver:self forKeyPath:SKNPDFAnnotationBoundsKey options:0 context:&SKNoteWindowNoteObservationContext];
        [note addObserver:self forKeyPath:SKNPDFAnnotationStringKey options:0 context:&SKNoteWindowNoteObservationContext];
        if ([self isNoteType])
            [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeys:[[self class] fontKeysToObserve] context:&SKNoteWindowDefaultsObservationContext];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePageLabelsChangedNotification:) name:SKPageLabelsChangedNotification object:nil];
    }
    return self;
}

- (void)updateStatusMessage {
    NSRect bounds = [note bounds];
    [[statusBar leftField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Page %@ at (%ld, %ld)", @"Status message"), [[note page] displayLabel], (long)NSMidX(bounds), (long)NSMidY(bounds)]];
}

- (void)windowDidLoad {
    [[self window] setLevel:keepOnTop || forceOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel];
    [[self window] setHidesOnDeactivate:keepOnTop || forceOnTop];
    
    if (@available(macOS 10.14, *))
        [textView setDrawsBackground:NO];
    
    if ([self isNoteType]) {
        if (@available(macOS 10.14, *))
            [edgeView setFillColor:[NSColor separatorColor]];
        
        NSFont *font = [[NSUserDefaults standardUserDefaults] fontForNameKey:SKAnchoredNoteFontNameKey sizeKey:SKAnchoredNoteFontSizeKey];
        if (font)
            [textView setFont:font];
        
        NSDictionary *options = nil;
        if (@available(macOS 10.14, *))
            options = @{NSValueTransformerBindingOption:[[SKAddTextColorTransformer alloc] init]};
        [textView bind:@"attributedString" toObject:noteController withKeyPath:@"selection.text" options:options];
        
        for (NSMenuItem *item in [iconTypePopUpButton itemArray])
            [item setImage:noteIcons[[item tag]]];
        
    } else {
        [topView removeFromSuperview];
        
        NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:[textView enclosingScrollView] attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:[[self window] contentView] attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
        [constraint setActive:YES];
        
        [textView setRichText:NO];
        [textView setImportsGraphics:NO];
        [textView setAllowsImageEditing:NO];
        [textView setUsesDefaultFontSize:YES];
        [textView bind:@"value" toObject:noteController withKeyPath:@"selection.string" options:nil];
        
        NSSize minimumSize = [[self window] minSize];
        NSRect frame = [[[self window] contentView] frame];
        frame.size.height = NSHeight([statusBar frame]) + DEFAULT_TEXT_HEIGHT;
        frame = [[self window] frameRectForContentRect:frame];
        minimumSize.height = NSHeight(frame);
        [[self window] setMinSize:minimumSize];
        [[self window] setFrame:frame display:NO];
    }
    
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:SKTypeImageTransformerName];
    
    [[statusBar leftField] setAction:@selector(statusBarClicked:)];
    [[statusBar leftField] setTarget:self];
    [statusBar setIcon:[transformer transformedValue:[note type]]];
    
    [self updateStatusMessage];
    
    [self setWindowFrameAutosaveNameOrCascade:[self isNoteType] ? SKNoteWindowFrameAutosaveName : SKAnyNoteWindowFrameAutosaveName];
}

- (BOOL)windowShouldClose:(id)window {
    return [self commitEditing];
}

- (void)windowWillClose:(NSNotification *)aNotification {
    if ([self commitEditing] == NO)
        [self discardEditing];
    if ([[self window] isKeyWindow])
        [[[[self document] mainWindowController] window] makeKeyWindow];
    else if ([[self window] isMainWindow])
        [[[[self document] mainWindowController] window] makeMainWindow];
    if (previewURL)
        [self endPreviewPanelControl:nil];
    @try { [textView unbind:[self isNoteType] ? @"attributedString" : @"value"]; }
    @catch (id e) {}
    [note removeObserver:self forKeyPath:SKNPDFAnnotationPageKey context:&SKNoteWindowNoteObservationContext];
    [note removeObserver:self forKeyPath:SKNPDFAnnotationBoundsKey context:&SKNoteWindowNoteObservationContext];
    [note removeObserver:self forKeyPath:SKNPDFAnnotationStringKey context:&SKNoteWindowNoteObservationContext];
    if ([self isNoteType])
        [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeys:[[self class] fontKeysToObserve] context:&SKNoteWindowDefaultsObservationContext];
    else
        [textView setUsesDefaultFontSize:NO];
    [[self window] setDelegate:nil];
    [imageView setDelegate:nil];
    [textView setDelegate:nil];
}

- (void)handleApplicationWillTerminate:(NSNotification *)notification {
    if ([temporaryDirectoryURL checkResourceIsReachableAndReturnError:NULL])
        [[NSFileManager defaultManager] removeItemAtURL:temporaryDirectoryURL error:NULL];
    temporaryDirectoryURL = nil;
}

- (void)handlePageLabelsChangedNotification:(NSNotification *)notification {
    [self updateStatusMessage];
}

- (void)setDocument:(NSDocument *)document {
    // in case the document is reset before windowWillClose: is called, I think this can happen on Tiger
    if ([self document] && document == nil) {
        if ([self commitEditing] == NO)
            [self discardEditing];
        if (isEditing) {
            [[self document] objectDidEndEditing:self];
            isEditing = NO;
        }
    }
    [super setDocument:document];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
    return [[[[self note] type] typeName] stringByAppendingEmDashAndString:[[self note] string] ?: @""];
}

- (BOOL)isNoteWindowController { return YES; }

- (BOOL)isNoteType {
    return [note isNote];
}

- (void)setKeepOnTop:(BOOL)flag {
    keepOnTop = flag;
    [[self window] setLevel:keepOnTop || forceOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel];
    [[self window] setHidesOnDeactivate:keepOnTop || forceOnTop];
}

- (void)setForceOnTop:(BOOL)flag {
    forceOnTop = flag;
    [[self window] setLevel:keepOnTop || forceOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel];
    [[self window] setHidesOnDeactivate:keepOnTop || forceOnTop];
}

- (void)statusBarClicked:(id)sender {
    SKPDFView *pdfView = [(SKMainDocument *)[self document] pdfView];
    [pdfView scrollAnnotationToVisible:note];
    [pdfView setCurrentAnnotation:note];
}

- (NSURL *)writeImageToDestination:(NSURL *)destination {
    NSImage *image = [note image];
    if (image) {
        NSString *name = [note string];
        if ([name length] == 0)
            name = @"NoteImage";
        NSURL *fileURL = [[destination URLByAppendingPathComponent:name isDirectory:NO] URLByAppendingPathExtension:@"tiff"];
        fileURL = [fileURL uniqueFileURL];
        if ([[image TIFFRepresentation] writeToURL:fileURL atomically:YES])
            return fileURL;
    }
    return nil;
}

#pragma mark NSTextViewDelegate and NSTextDelegate protocol

- (NSUndoManager *)undoManagerForTextView:(NSTextView *)aTextView {
    if (textViewUndoManager == nil)
        textViewUndoManager = [[SKChainedUndoManager alloc] initWithNextUndoManager:[[self document] undoManager]];
    return textViewUndoManager;
}

- (void)textDidChange:(NSNotification *)notification {
    if (@available(macOS 10.14, *))
        [[textView textStorage] addTextColorAttribute];
}

- (void)textDidEndEditing:(NSNotification *)notification {
    [textViewUndoManager removeAllActions];
}

#pragma mark NSEditorRegistration and NSEditor protocol

- (void)objectDidBeginEditing:(id)editor {
    if (isEditing == NO) {
        [[self document] objectDidBeginEditing:self];
        isEditing = YES;
    }
}

- (void)objectDidEndEditing:(id)editor {
    if (isEditing) {
        [[self document] objectDidEndEditing:self];
        isEditing = NO;
    }
}

- (void)discardEditing {
    [noteController discardEditing];
}

- (BOOL)commitEditing {
    return [noteController commitEditing];
}

- (BOOL)commitEditingAndReturnError:(NSError **)error {
    return [noteController commitEditingAndReturnError:error];
}

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void *)contextInfo {
    return [noteController commitEditingWithDelegate:delegate didCommitSelector:didCommitSelector contextInfo:contextInfo];
}

#pragma mark SKDragImageView delegate protocol

- (id<NSPasteboardWriting>)draggedObjectForDragImageView {
    NSImage *image = [note image];
    if (image)
        return [[NSFilePromiseProvider alloc] initWithFileType:(__bridge NSString *)kUTTypeTIFF delegate:self];
    else
        return nil;
}

- (void)showImageForDragImageView {
    NSURL *fileURL = [self writeImageToDestination:[[self class] temporaryDirectoryURL]];
    if (fileURL)
        [[NSWorkspace sharedWorkspace] openURL:fileURL];
}

#pragma mark NSFilePromiseProviderDelegate protocol

- (NSString *)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider fileNameForType:(NSString *)fileType {
    return [[note string] ?: @"NoteImage" stringByAppendingPathExtension:@"tiff"];
}

- (void)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider writePromiseToURL:(NSURL *)fileURL completionHandler:(void (^)(NSError *))completionHandler {
    NSError *error = nil;
    NSImage *image = [note image];
    [[image TIFFRepresentation] writeToURL:fileURL options:NSDataWritingAtomic error:&error];
    completionHandler(error);
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKNoteWindowDefaultsObservationContext) {
        NSString *key = [keyPath substringFromIndex:7];
        if (([key isEqualToString:SKAnchoredNoteFontNameKey] || [key isEqualToString:SKAnchoredNoteFontSizeKey]) && [self isNoteType] && [[textView string] length] == 0) {
            NSFont *font = [[NSUserDefaults standardUserDefaults] fontForNameKey:SKAnchoredNoteFontNameKey sizeKey:SKAnchoredNoteFontSizeKey];
            if (font)
                [textView setFont:font];
        }
    } else if (context == &SKNoteWindowNoteObservationContext) {
        if ([keyPath isEqualToString:SKNPDFAnnotationStringKey])
            [self synchronizeWindowTitleWithDocumentName];
        else
            [self updateStatusMessage];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Quick Look Panel Support

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel {
    return [self isNoteType];
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel {
    [self endPreviewPanelControl:nil];
    previewURL = [self writeImageToDestination:[[self class] temporaryDirectoryURL]];
    [panel setDelegate:self];
    [panel setDataSource:self];
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {
    if (previewURL) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *tmpDirURL = [previewURL URLByDeletingLastPathComponent];
        [fm removeItemAtURL:previewURL error:NULL];
        if ([[fm contentsOfDirectoryAtURL:tmpDirURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL] count] == 0)
            [fm removeItemAtURL:tmpDirURL error:NULL];
        previewURL = nil;
    }
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
    return [note image] == nil ? 0 : 1;
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)anIndex {
    return self;
}

- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item {
    return [imageView convertRectToScreen:NSInsetRect([imageView bounds], 8.0, 8.0)];
}

- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event {
    if ([event type] == NSEventTypeKeyDown) {
        [imageView keyDown:event];
        return YES;
    }
    return NO;
}

- (NSURL *)previewItemURL {
    return previewURL;
}

- (NSString *)previewItemTitle {
    NSString *title = [note string];
    if ([title length] == 0)
        title = @"Preskim Note";
    return title;
}

@end

#pragma mark -

@implementation SKAddTextColorTransformer

- (id)transformedValue:(id)value {
    return [value attributedStringByAddingTextColorAttribute];
}

- (id)reverseTransformedValue:(id)value {
    return [value attributedStringByRemovingTextColorAttribute];
}

@end
