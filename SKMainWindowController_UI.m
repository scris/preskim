//
//  SKMainWindowController_UI.m
//  Skim
//
//  Created by Christiaan Hofman on 5/2/08.
/*
 This software is Copyright (c) 2008
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

#import "SKMainWindowController_UI.h"
#import "SKMainWindowController_FullScreen.h"
#import "SKMainWindowController_Actions.h"
#import "SKLeftSideViewController.h"
#import "SKRightSideViewController.h"
#import "SKMainToolbarController.h"
#import "SKPDFView.h"
#import "SKStatusBar.h"
#import "SKSnapshotWindowController.h"
#import "SKNoteWindowController.h"
#import "SKNoteTextView.h"
#import "NSWindowController_SKExtensions.h"
#import "SKSideWindow.h"
#import "SKProgressController.h"
#import "SKAnnotationTypeImageView.h"
#import "SKStringConstants.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKNoteText.h"
#import "SKImageToolTipWindow.h"
#import "SKMainDocument.h"
#import "PDFPage_SKExtensions.h"
#import "SKGroupedSearchResult.h"
#import "PDFSelection_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "SKApplication.h"
#import "NSMenu_SKExtensions.h"
#import "SKLineInspector.h"
#import "SKFieldEditor.h"
#import "PDFOutline_SKExtensions.h"
#import "SKDocumentController.h"
#import "SKFindController.h"
#import "SKSecondaryToolbarController.h"
#import "NSColor_SKExtensions.h"
#import "SKSplitView.h"
#import "SKScrollView.h"
#import "NSEvent_SKExtensions.h"
#import "SKDocumentController.h"
#import "NSError_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "NSInvocation_SKExtensions.h"
#import "NSURL_SKExtensions.h"
#import "PDFDocument_SKExtensions.h"
#import "NSArray_SKExtensions.h"
#import "SKNoteTableRowView.h"
#import "SKHighlightingTableRowView.h"
#import "SKSecondaryPDFView.h"
#import "SKControlTableCellView.h"
#import "SKThumbnailItem.h"
#import "SKOverviewView.h"
#import "NSView_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSObject_SKExtensions.h"
#import "NSPasteboard_SKExtensions.h"
#import "SKApplicationController.h"
#import "SKSecondaryToolbarController.h"

#define NOTES_KEY       @"notes"
#define SNAPSHOTS_KEY   @"snapshots"

#define PAGE_COLUMNID       @"page"
#define LABEL_COLUMNID      @"label"
#define NOTE_COLUMNID       @"note"
#define TYPE_COLUMNID       @"type"
#define COLOR_COLUMNID      @"color"
#define AUTHOR_COLUMNID     @"author"
#define DATE_COLUMNID       @"date"
#define IMAGE_COLUMNID      @"image"
#define RELEVANCE_COLUMNID  @"relevance"

#define ROWVIEW_IDENTIFIER @"row"

#define SKLeftSidePaneWidthKey  @"SKLeftSidePaneWidth"
#define SKRightSidePaneWidthKey @"SKRightSidePaneWidth"

#define SKTocOutlineEmptyIndicator @"SKTocOutlineEmptyIndicator"

#define MIN_SIDE_PANE_WIDTH 100.0
#define DEFAULT_SPLIT_PANE_HEIGHT 200.0
#define MIN_SPLIT_PANE_HEIGHT 50.0
#define MIN_PDF_PANE_HEIGHT 50.0

#define SNAPSHOT_HEIGHT 200.0

#define EXTRA_ROW_HEIGHT 2.0
#define DEFAULT_TEXT_ROW_HEIGHT 85.0
#define DEFAULT_MARKUP_ROW_HEIGHT 50.0

@interface SKMainWindowController (SKPrivateMain)

- (void)cleanup;

- (void)goToSelectedOutlineItem:(id)sender;

- (void)updatePageLabels;
- (void)updatePageLabel;

- (void)updateNoteFilterPredicate;

- (void)rotatePageAtIndex:(NSUInteger)idx by:(NSInteger)rotation;

@end

@interface SKMainWindowController (UIPrivate)
- (void)changeColorProperty:(id)sender;
@end

#pragma mark -

@implementation SKMainWindowController (UI)

#pragma mark Utility panel updating

- (NSButton *)newColorAccessoryButtonWithTitle:(NSString *)title {
    NSButton *button = [[NSButton alloc] init];
    [button setButtonType:NSButtonTypeSwitch];
    [button setTitle:title];
    [[button cell] setControlSize:NSControlSizeSmall];
    [button setTarget:self];
    [button setAction:@selector(changeColorProperty:)];
    [button sizeToFit];
    return button;
}

- (void)updateColorPanel {
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    NSColor *color = nil;
    NSView *accessoryView = nil;
    
    if ([[self window] isMainWindow]) {
        if ([annotation isSkimNote]) {
            if ([annotation hasInteriorColor]) {
                if (colorAccessoryView == nil)
                    colorAccessoryView = [self newColorAccessoryButtonWithTitle:NSLocalizedString(@"Fill color", @"Check button title")];
                accessoryView = colorAccessoryView;
            } else if ([annotation isText]) {
                if (textColorAccessoryView == nil)
                    textColorAccessoryView = [self newColorAccessoryButtonWithTitle:NSLocalizedString(@"Text color", @"Check button title")];
                accessoryView = textColorAccessoryView;
            }
            if ([annotation hasInteriorColor] && [colorAccessoryView state] == NSControlStateValueOn) {
                color = [(id)annotation interiorColor] ?: [NSColor clearColor];
            } else if ([annotation isText] && [textColorAccessoryView state] == NSControlStateValueOn) {
                color = [(id)annotation fontColor] ?: [NSColor blackColor];
            } else {
                color = [annotation color];
            }
        }
        if ([[NSColorPanel sharedColorPanel] accessoryView] != accessoryView) {
            [[NSColorPanel sharedColorPanel] setAccessoryView:nil];
            [[NSColorPanel sharedColorPanel] setAccessoryView:accessoryView];
        }
    }
    
    if (color) {
        mwcFlags.updatingColor = 1;
        [[NSColorPanel sharedColorPanel] setColor:color];
        mwcFlags.updatingColor = 0;
    }
}

- (void)changeColorProperty:(id)sender{
   [self updateColorPanel];
}

- (void)updateLineInspector {
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    
    if ([[self window] isMainWindow] &&[annotation hasBorder]) {
        mwcFlags.updatingLine = 1;
        [[SKLineInspector sharedLineInspector] setAnnotationStyle:annotation];
        mwcFlags.updatingLine = 0;
    }
}

- (void)updateUtilityPanel {
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    
    if ([[self window] isMainWindow]) {
        if ([annotation isSkimNote]) {
            if ([annotation isText]) {
                mwcFlags.updatingFont = 1;
                [[NSFontManager sharedFontManager] setSelectedFont:[annotation font] isMultiple:NO];
                mwcFlags.updatingFont = 0;
                mwcFlags.updatingFontAttributes = 1;
                [[NSFontManager sharedFontManager] setSelectedAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[annotation fontColor], NSForegroundColorAttributeName, nil] isMultiple:NO];
                mwcFlags.updatingFontAttributes = 0;
            }
        }
    }
    
    [self updateColorPanel];
    [self updateLineInspector];
}

#pragma mark NSWindow delegate protocol

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
    if ([pdfView document]) {
        [[self window] setSubtitle:[NSString stringWithFormat:NSLocalizedString(@"page %ld of %ld", @"Window title format subtitle"), (long)([[[self pdfView] currentPage] pageIndex] + 1), (long)[[pdfView document] pageCount]]];
        return displayName;
    } else {
        return displayName;
    }
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
    if ([[self window] isEqual:[notification object]])
        [self updateUtilityPanel];
}

- (void)windowDidResignMain:(NSNotification *)notification {
    if ([[[NSColorPanel sharedColorPanel] accessoryView] isEqual:colorAccessoryView])
        [[NSColorPanel sharedColorPanel] setAccessoryView:nil];
}

- (void)windowWillClose:(NSNotification *)notification {
    if ([[notification object] isEqual:[self window]]) {
        // if we were not yet removed in removeWindowController: we should save our document info now
        // otherwise [self document] is nil so this is safe
        if ([self document]) {
            [self setRecentInfoNeedsUpdate:YES];
            [[self document] saveRecentDocumentInfo];
        }
        // timers retain their target, so invalidate them now or they may keep firing after the PDF is gone
        if (snapshotTimer) {
            [snapshotTimer invalidate];
            snapshotTimer = nil;
        }
        if ([[pdfView document] isFinding])
            [[pdfView document] cancelFindString];
        if ((mwcFlags.isEditingTable || [pdfView isEditing]) && [self commitEditing] == NO)
            [self discardEditing];
        [self cleanup]; // clean up everything
    }
}

- (void)windowDidChangeScreen:(NSNotification *)notification {
    if ([[notification object] isEqual:[self window]] && [[notification object] isEqual:mainWindow] == NO) {
        NSScreen *screen = [[self window] screen];
        [[self window] setFrame:[screen frame] display:NO];
        if ([self interactionMode] == SKPresentationMode && sideWindow) {
            NSRect screenFrame = [[[self window] screen] frame];
            NSRect frame = [sideWindow frame];
            frame.origin.x = NSMinX(screenFrame);
            frame.origin.y = NSMidY(screenFrame) - floor(0.5 * NSHeight(frame));
            [sideWindow setFrame:frame display:YES];
        }
        [pdfView layoutDocumentView];
        [pdfView requiresDisplay];
    }
}

- (void)windowDidMove:(NSNotification *)notification {
    if ([[notification object] isEqual:[self window]] && [[self window] styleMask] == NSWindowStyleMaskBorderless) {
        NSScreen *screen = [[self window] screen];
        NSRect screenFrame = [screen frame];
        if (NSEqualRects(screenFrame, [[self window] frame]) == NO) {
            [[self window] setFrame:screenFrame display:NO];
            [pdfView layoutDocumentView];
            [pdfView requiresDisplay];
        }
    } else if ([[notification object] isEqual:[self window]] && [self interactionMode] == SKPresentationMode) {
        if (sideWindow) {
            NSRect screenFrame = [[[self window] screen] frame];
            NSRect frame = [sideWindow frame];
            frame.origin.x = NSMinX(screenFrame);
            frame.origin.y = NSMidY(screenFrame) - floor(0.5 * NSHeight(frame));
            [sideWindow setFrame:frame display:YES];
        }
    }
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
    if (fieldEditor == nil) {
        fieldEditor = [[SKFieldEditor alloc] init];
        [fieldEditor setFieldEditor:YES];
    }
    return fieldEditor;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender {
    if ([self interactionMode] == SKPresentationMode)
        return [self presentationUndoManager];
    return [[self document] undoManager];
}

- (void)window:(NSWindow *)sender willSendEvent:(NSEvent *)event {
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
    
    if ([pdfView temporaryToolMode] != SKNoToolMode && [pdfView window] == sender) {
        if ([event type] == NSEventTypeLeftMouseDown) {
            NSView *view = [pdfView hitTest:[event locationInView:pdfView]];
            if ([view isDescendantOf:[pdfView documentView]] == NO || [view isKindOfClass:[NSTextView class]])
                [pdfView setTemporaryToolMode:SKNoToolMode];
        } else {
            [pdfView setTemporaryToolMode:SKNoToolMode];
        }
    }
}

#pragma mark Page history highlights

#define MAX_HIGHLIGHTS 5

- (NSInteger)thumbnailHighlightLevelForRow:(NSInteger)row {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableHistoryHighlightsKey] == NO) {
        NSInteger i, iMax = [lastViewedPages count];
        for (i = 0; i < iMax; i++) {
            if (row == (NSInteger)[lastViewedPages pointerAtIndex:i])
                return MAX(0, MAX_HIGHLIGHTS - i);
        }
    }
    return 0;
}

- (NSInteger)tocHighlightLevelForRow:(NSInteger)row {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableHistoryHighlightsKey] == NO) {
        NSOutlineView *ov = leftSideController.tocOutlineView;
        NSInteger numRows = [ov numberOfRows];
        NSInteger firstPage = [[[ov itemAtRow:row] page] pageIndex];
        NSInteger lastPage = row + 1 < numRows ? [[[ov itemAtRow:row + 1] page] pageIndex] : [[self pdfDocument] pageCount];
        NSRange range = NSMakeRange(firstPage, MAX(1L, lastPage - firstPage));
        NSInteger i, iMax = [lastViewedPages count];
        for (i = 0; i < iMax; i++) {
            if (NSLocationInRange((NSUInteger)[lastViewedPages pointerAtIndex:i], range))
                return MAX(0, MAX_HIGHLIGHTS - i);
        }
    }
    return 0;
}

- (void)updateThumbnailHighlights {
    [leftSideController.thumbnailTableView enumerateAvailableRowViewsUsingBlock:^(SKHighlightingTableRowView *rowView, NSInteger row){
        [rowView setHighlightLevel:[self thumbnailHighlightLevelForRow:row]];
    }];
    if (overviewView) {
        for (NSIndexPath *indexPath in [overviewView indexPathsForVisibleItems])
            [(SKThumbnailItem *)[overviewView itemAtIndexPath:indexPath] setHighlightLevel:[self thumbnailHighlightLevelForRow:[indexPath item]]];
    }
}

- (void)updateTocHighlights {
    [leftSideController.tocOutlineView enumerateAvailableRowViewsUsingBlock:^(SKHighlightingTableRowView *rowView, NSInteger row){
        [rowView setHighlightLevel:[self tocHighlightLevelForRow:row]];
    }];
}

#pragma mark NSTableView datasource protocol

// AppKit bug: need a dummy NSTableDataSource implementation, otherwise some NSTableView delegate methods are ignored
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    if ([tv isEqual:rightSideController.snapshotTableView]) {
        return [[rightSideController.snapshotArrayController arrangedObjects] count];
    }
    return 0;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([tv isEqual:rightSideController.snapshotTableView]) {
        return [[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row];
    }
    return nil;
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tv pasteboardWriterForRow:(NSInteger)row {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        if ([[pdfView document] isLocked] == NO) {
            PDFPage *page = [[pdfView document] pageAtIndex:row];
            return [page filePromiseForPageIndexes:nil];
        }
    } else if ([tv isEqual:rightSideController.snapshotTableView]) {
        SKSnapshotWindowController *snapshot = [[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row];
        return [[NSFilePromiseProvider alloc] initWithFileType:NSPasteboardTypeTIFF delegate:snapshot];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tv draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes {
    if (([tv isEqual:leftSideController.thumbnailTableView] || [tv isEqual:rightSideController.snapshotTableView]) &&
        [rowIndexes count] == 1) {
        NSTableCellView *view = [tv viewAtColumn:0 row:[rowIndexes firstIndex] makeIfNecessary:NO];
        if (view) {
            // The docs say it uses screen coordinates when we pass a nil view.
            // In reality the coodinates are offset by the mouse postion relative to the top-left of the screen, it seems. Huh?
            NSRect frame = [view convertRectToScreen:[view bounds]];
            frame.origin.x -= screenPoint.x - [session draggingLocation].x;
            frame.origin.y -= screenPoint.y - [session draggingLocation].y;
            NSArray *classes = @[[NSPasteboardItem class]];
            [session enumerateDraggingItemsWithOptions:0 forView:nil classes:classes searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop){
                [draggingItem setImageComponentsProvider:^{
                    return [view draggingImageComponents];
                }];
                [draggingItem setDraggingFrame:frame];
            }];
        }
    }
}

- (void)tableView:(NSTableView *)tv sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    if ([tv isEqual:leftSideController.groupedFindTableView]) {
        [leftSideController.groupedFindArrayController setSortDescriptors:[tv sortDescriptors]];
    }
}

#pragma mark NSTableView delegate protocol


// This makes the thumbnail tableview view based on 10.7+
// on 10.6 this is ignored, and the cell based tableview uses the datasource methods
- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        NSTableCellView *view = [tv makeViewWithIdentifier:[tableColumn identifier] owner:self];
        if ([[tableColumn identifier] isEqualToString:PAGE_COLUMNID])
            [[view imageView] setObjectValue:(NSUInteger)row == markedPageIndex ? [NSImage markImage] : nil];
        return view;
    } else if ([tv isEqual:rightSideController.snapshotTableView]) {
        return [tv makeViewWithIdentifier:[tableColumn identifier] owner:self];
    } else if ([tv isEqual:leftSideController.findTableView]) {
        return [tv makeViewWithIdentifier:[tableColumn identifier] owner:self];
    } else if ([tv isEqual:leftSideController.groupedFindTableView]) {
        NSTableCellView *view = [tv makeViewWithIdentifier:[tableColumn identifier] owner:self];
        if ([[tableColumn identifier] isEqualToString:RELEVANCE_COLUMNID]) {
            // IB does not allow setting te height and height sizable mask of a NSLeveleIndicator
            NSControl *levelIndicator = [(SKControlTableCellView *)view control];
            [levelIndicator setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            [levelIndicator setFrame:[view bounds]];
        }
        return view;
    }
    return nil;
}

- (NSView *)tableView:(NSTableView *)tv rowViewForRow:(NSInteger)row {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        SKHighlightingTableRowView *rowView = [tv makeViewWithIdentifier:ROWVIEW_IDENTIFIER owner:self];
        [rowView setHighlightLevel:[self thumbnailHighlightLevelForRow:row]];
        return rowView;
    }
    return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if ([[aNotification object] isEqual:leftSideController.thumbnailTableView]) {
        if (mwcFlags.updatingThumbnailSelection == 0) {
            NSInteger row = [leftSideController.thumbnailTableView selectedRow];
            if (row != -1)
                [pdfView goToCurrentPage:[[pdfView document] pageAtIndex:row]];
            
            if ([self interactionMode] == SKPresentationMode && [[NSUserDefaults standardUserDefaults] boolForKey:SKAutoHidePresentationContentsKey])
                [self hideSideWindow];
        }
    } else if ([[aNotification object] isEqual:rightSideController.snapshotTableView]) {
        NSInteger row = [[aNotification object] selectedRow];
        if (row != -1) {
            SKSnapshotWindowController *controller = [[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row];
            if ([[controller window] isVisible])
                [[controller window] orderFront:self];
        }
    } else if ([[aNotification object] isEqual:leftSideController.findTableView] ||
               [[aNotification object] isEqual:leftSideController.groupedFindTableView]) {
        if (mwcFlags.updatingFindResults == 0)
            [self selectFindResultHighlight:NSDirectSelection];
    }
}

- (BOOL)tableView:(NSTableView *)tv commandSelectRow:(NSInteger)row {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        NSRect rect = [[[pdfView document] pageAtIndex:row] boundsForBox:kPDFDisplayBoxCropBox];
        
        rect.origin.y = NSMidY(rect) - 0.5 * SNAPSHOT_HEIGHT;
        rect.size.height = SNAPSHOT_HEIGHT;
        [self showSnapshotAtPageNumber:row forRect:rect scaleFactor:[pdfView scaleFactor] autoFits:NO];
        return YES;
    }
    return NO;
}

- (void)tableViewColumnDidResize:(NSNotification *)aNotification {
    if ([[[[aNotification userInfo] objectForKey:@"NSTableColumn"] identifier] isEqualToString:IMAGE_COLUMNID]) {
        NSTableView *tv = [aNotification object];
        if ([tv isEqual:leftSideController.thumbnailTableView] || [tv isEqual:rightSideController.snapshotTableView]) {
            [(SKTableView *)tv noteHeightOfRowsChangedAnimating:NO];
        }
    }
}

- (CGFloat)tableView:(NSTableView *)tv heightOfRow:(NSInteger)row {
    NSSize thumbSize = NSZeroSize;
    CGFloat thumbHeight = 0.0, rowHeight = [tv rowHeight];
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        thumbSize = [[thumbnails objectAtIndex:row] size];
        thumbHeight = roundedThumbnailSize;
    } else if ([tv isEqual:rightSideController.snapshotTableView]) {
        thumbSize = [[(SKSnapshotWindowController *)[[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row] thumbnail] size];
        thumbHeight = roundedSnapshotThumbnailSize;
    } else {
        return rowHeight;
    }
    if (thumbSize.height <= rowHeight)
        return rowHeight;
    return fmax(rowHeight, fmin(thumbHeight, fmin(thumbSize.height, [[tv tableColumnWithIdentifier:IMAGE_COLUMNID] width] * thumbSize.height / thumbSize.width)));
}

- (void)tableView:(NSTableView *)tv copyRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        NSUInteger idx = [rowIndexes firstIndex];
        if (idx != NSNotFound && [[pdfView document] isLocked] == NO) {
            PDFPage *page = [[pdfView document] pageAtIndex:idx];
            [page writeToClipboardForPageIndexes:nil];
        }
    } else if ([tv isEqual:leftSideController.findTableView]) {
        NSMutableString *string = [NSMutableString string];
        NSArray *results = [leftSideController.findArrayController arrangedObjects];
        [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            PDFSelection *match = [results objectAtIndex:idx];
            [string appendString:@"* "];
            [string appendFormat:NSLocalizedString(@"Page %@", @""), [[match safeFirstPage] displayLabel]];
            [string appendFormat:@": %@\n", [[match contextString] string]];
        }];
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard clearContents];
        [pboard writeObjects:@[string]];
    } else if ([tv isEqual:leftSideController.groupedFindTableView]) {
        NSMutableString *string = [NSMutableString string];
        NSArray *results = [leftSideController.groupedFindArrayController arrangedObjects];
        [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            SKGroupedSearchResult *result = [results objectAtIndex:idx];
            NSArray *matches = [result matches];
            [string appendString:@"* "];
            [string appendFormat:NSLocalizedString(@"Page %@", @""), [[result page] displayLabel]];
            [string appendString:@": "];
            [string appendFormat:NSLocalizedString(@"%ld Results", @""), (long)[matches count]];
            [string appendFormat:@":\n\t%@\n", [[matches valueForKeyPath:@"contextString.string"] componentsJoinedByString:@"\n\t"]];
        }];
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard clearContents];
        [pboard writeObjects:@[string]];
    }
}

- (BOOL)tableView:(NSTableView *)tv canCopyRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if ([tv isEqual:leftSideController.thumbnailTableView] ||
        [tv isEqual:leftSideController.findTableView] ||
        [tv isEqual:leftSideController.groupedFindTableView]) {
        return [rowIndexes count] > 0;
    }
    return NO;
}

- (void)tableView:(NSTableView *)tv deleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if ([tv isEqual:rightSideController.snapshotTableView]) {
        NSArray *controllers = [[rightSideController.snapshotArrayController arrangedObjects] objectsAtIndexes:rowIndexes];
        [controllers makeObjectsPerformSelector:@selector(close)];
    }
}

- (BOOL)tableView:(NSTableView *)tv canDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    if ([tv isEqual:rightSideController.snapshotTableView]) {
        return [rowIndexes count] > 0;
    }
    return NO;
}

- (void)tableViewMoveLeft:(NSTableView *)tv {
    if (([tv isEqual:leftSideController.findTableView] || [tv isEqual:leftSideController.groupedFindTableView])) {
        [self selectFindResultHighlight:NSSelectingPrevious];
    }
}

- (void)tableViewMoveRight:(NSTableView *)tv {
    if (([tv isEqual:leftSideController.findTableView] || [tv isEqual:leftSideController.groupedFindTableView])) {
        [self selectFindResultHighlight:NSSelectingNext];
    }
}

- (id <SKImageToolTipContext>)tableView:(NSTableView *)tv imageContextForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row scale:(CGFloat *)scale {
    if (tableColumn) {
        return nil;
    } else if ([tv isEqual:leftSideController.findTableView]) {
        *scale = [[self pdfView] scaleFactor];
        return [[leftSideController.findArrayController arrangedObjects] objectAtIndex:row];
    } else if ([tv isEqual:leftSideController.groupedFindTableView]) {
        *scale = [[self pdfView] scaleFactor];
        return [[leftSideController.groupedFindArrayController arrangedObjects] objectAtIndex:row];
    }
    return nil;
}

- (NSArray *)tableViewTypeSelectHelperSelectionStrings:(NSTableView *)tv {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        return pageLabels;
    }
    return nil;
}

- (void)tableView:(NSTableView *)tv typeSelectHelperDidFailToFindMatchForSearchString:(NSString *)searchString {
    if ([tv isEqual:leftSideController.thumbnailTableView]) {
        [[statusBar leftField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"No match: \"%@\"", @"Status message"), searchString]];
    }
}

- (void)tableView:(NSTableView *)tv typeSelectHelperUpdateSearchString:(NSString *)searchString {}

#pragma mark NSOutlineView datasource protocol

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item{
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        if (item == nil && [[pdfView document] isLocked] == NO)
            item = [[pdfView document] outlineRoot];
        if ([(PDFOutline *)item numberOfChildren] == 0) {
            [[[[self toolbarController].leftPaneButton menuForSegment:0] itemArray][2] setEnabled:FALSE];
        } else {
            [[[[self toolbarController].leftPaneButton menuForSegment:0] itemArray][2] setEnabled:TRUE];
        }
        return [(PDFOutline *)item numberOfChildren];
    } else if ([ov isEqual:rightSideController.noteOutlineView]) {
        if (item == nil)
            return [[rightSideController.noteArrayController arrangedObjects] count];
        else
            return [item hasNoteText];
    }
    return 0;
}

- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)anIndex ofItem:(id)item{
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        if (item == nil && [[pdfView document] isLocked] == NO)
            item = [[pdfView document] outlineRoot];
        id obj = [(PDFOutline *)item childAtIndex:anIndex];
        return obj;
    } else if ([ov isEqual:rightSideController.noteOutlineView]) {
        if (item == nil)
            return [[rightSideController.noteArrayController arrangedObjects] objectAtIndex:anIndex];
        else
            return [item noteText];
    }
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item{
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        if (item == nil && [[pdfView document] isLocked] == NO)
            item = [[pdfView document] outlineRoot];
        return ([(PDFOutline *)item numberOfChildren] > 0);
    } else if ([ov isEqual:rightSideController.noteOutlineView]) {
        return [item hasNoteText];
    }
    return NO;
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item{
    if ([ov isEqual:leftSideController.tocOutlineView] || [ov isEqual:rightSideController.noteOutlineView]) {
        return item;
    }
    return nil;
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)anIndex {
    NSDragOperation dragOp = NSDragOperationNone;
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        NSPasteboard *pboard = [info draggingPasteboard];
        if ([pboard canReadObjectForClasses:@[[NSColor class]] options:@{}] &&
            anIndex == NSOutlineViewDropOnItemIndex && [(PDFAnnotation *)item type] != nil)
            dragOp = NSDragOperationEvery;
    }
    return dragOp;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)anIndex {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        NSPasteboard *pboard = [info draggingPasteboard];
        if ([pboard canReadObjectForClasses:@[[NSColor class]] options:@{}]) {
            BOOL isShift = ([NSEvent standardModifierFlags] & NSEventModifierFlagShift) != 0;
            BOOL isAlt = ([NSEvent standardModifierFlags] & NSEventModifierFlagOption) != 0;
            [item setColor:[NSColor colorFromPasteboard:pboard] alternate:isAlt updateDefaults:isShift];
            return YES;
        }
    }
    return NO;
}

#pragma mark NSOutlineView delegate protocol

- (NSView *)outlineView:(NSOutlineView *)ov viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        return [ov makeViewWithIdentifier:[tableColumn identifier] owner:self];
    } else if ([ov isEqual:rightSideController.noteOutlineView]) {
        if ([(PDFAnnotation *)item type] || tableColumn == [ov outlineTableColumn]) {
            NSTableCellView *view = [ov makeViewWithIdentifier:[tableColumn identifier] owner:self];
            if ([[tableColumn identifier] isEqualToString:TYPE_COLUMNID])
                [(SKAnnotationTypeImageView *)[view imageView] setHasOutline:[pdfView currentAnnotation] == item];
            [[view textField] setDelegate:self];
            return view;
        }
    }
    return nil;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)ov rowViewForItem:(id)item {
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        SKHighlightingTableRowView *rowView = [ov makeViewWithIdentifier:ROWVIEW_IDENTIFIER owner:self];
        [rowView setHighlightLevel:[self tocHighlightLevelForRow:[ov rowForItem:item]]];
        return rowView;
    } else if ([ov isEqual:rightSideController.noteOutlineView]) {
        return [ov makeViewWithIdentifier:ROWVIEW_IDENTIFIER owner:self];
    }
    return nil;
}

- (void)outlineView:(NSOutlineView *)ov didClickTableColumn:(NSTableColumn *)tableColumn {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        NSTableColumn *oldTableColumn = [ov highlightedTableColumn];
        NSTableColumn *newTableColumn = ([NSEvent modifierFlags] & NSEventModifierFlagCommand) ? nil : tableColumn;
        NSMutableArray *sortDescriptors = nil;
        BOOL ascending = YES;
        if ([oldTableColumn isEqual:newTableColumn]) {
            sortDescriptors = [[rightSideController.noteArrayController sortDescriptors] mutableCopy];
            [sortDescriptors replaceObjectAtIndex:0 withObject:[[sortDescriptors firstObject] reversedSortDescriptor]];
            ascending = [[sortDescriptors firstObject] ascending];
        } else {
            NSString *tcID = [newTableColumn identifier];
            NSSortDescriptor *pageIndexSortDescriptor = [[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationPageIndexKey ascending:ascending];
            NSSortDescriptor *boundsSortDescriptor = [[NSSortDescriptor alloc] initWithKey:SKPDFAnnotationBoundsOrderKey ascending:ascending selector:@selector(compare:)];
            sortDescriptors = [NSMutableArray arrayWithObjects:pageIndexSortDescriptor, boundsSortDescriptor, nil];
            if ([tcID isEqualToString:TYPE_COLUMNID]) {
                [sortDescriptors insertObject:[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationTypeKey ascending:YES selector:@selector(noteTypeCompare:)] atIndex:0];
            } else if ([tcID isEqualToString:COLOR_COLUMNID]) {
                [sortDescriptors insertObject:[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationColorKey ascending:YES selector:@selector(colorCompare:)] atIndex:0];
            } else if ([tcID isEqualToString:NOTE_COLUMNID]) {
                [sortDescriptors insertObject:[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationStringKey ascending:YES selector:@selector(localizedCaseInsensitiveNumericCompare:)] atIndex:0];
            } else if ([tcID isEqualToString:AUTHOR_COLUMNID]) {
                [sortDescriptors insertObject:[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationUserNameKey ascending:YES selector:@selector(localizedCaseInsensitiveNumericCompare:)] atIndex:0];
            } else if ([tcID isEqualToString:DATE_COLUMNID]) {
                [sortDescriptors insertObject:[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationModificationDateKey ascending:YES] atIndex:0];
            }
            if (oldTableColumn)
                [ov setIndicatorImage:nil inTableColumn:oldTableColumn];
            [ov setHighlightedTableColumn:newTableColumn]; 
        }
        [rightSideController.noteArrayController setSortDescriptors:sortDescriptors];
        if (newTableColumn)
            [ov setIndicatorImage:[NSImage imageNamed:ascending ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator"]
                    inTableColumn:newTableColumn];
        [ov reloadData];
    }
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification{
	// Get the destination associated with the search result list. Tell the PDFView to go there.
	if ([[notification object] isEqual:leftSideController.tocOutlineView] && (mwcFlags.updatingOutlineSelection == 0)){
        mwcFlags.updatingOutlineSelection = 1;
        [self goToSelectedOutlineItem:nil];
        mwcFlags.updatingOutlineSelection = 0;
        if ([self interactionMode] == SKPresentationMode && [[NSUserDefaults standardUserDefaults] boolForKey:SKAutoHidePresentationContentsKey])
            [self hideSideWindow];
    }
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification{
    if ([[notification object] isEqual:leftSideController.tocOutlineView]) {
        [self updateTocHighlights];
        [self updateOutlineSelection];
    }
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification{
    if ([[notification object] isEqual:leftSideController.tocOutlineView]) {
        [self updateTocHighlights];
        [self updateOutlineSelection];
    }
}

- (void)resetNoteRowHeights {
    [rowHeights removeAllObjects];
    [rightSideController.noteOutlineView noteHeightOfRowsChangedAnimating:YES];
}

- (void)outlineViewColumnDidResize:(NSNotification *)notification{
    if (mwcFlags.autoResizeNoteRows && [[notification object] isEqual:rightSideController.noteOutlineView] &&
        [(SKScrollView *)[rightSideController.noteOutlineView enclosingScrollView] isResizingSubviews] == NO)
        [self performSelectorOnce:@selector(resetNoteRowHeights) afterDelay:0.0];
}

- (void)outlineView:(NSOutlineView *)ov didChangeHiddenOfTableColumn:(NSTableColumn *)tableColumn {
    if (mwcFlags.autoResizeNoteRows && [ov isEqual:rightSideController.noteOutlineView])
        [self performSelectorOnce:@selector(resetNoteRowHeights) afterDelay:0.0];
}

- (void)outlineViewColumnDidMove:(NSNotification *)notification {
    if ([[notification object] isEqual:rightSideController.noteOutlineView] && mwcFlags.autoResizeNoteRows) {
        NSInteger oldColumn = [[[notification userInfo] objectForKey:@"NSOldColumn"] integerValue];
        NSInteger newColumn = [[[notification userInfo] objectForKey:@"NSNewColumn"] integerValue];
        if (oldColumn == 0 || newColumn == 0)
            [self performSelectorOnce:@selector(resetNoteRowHeights) afterDelay:0.0];
    }
}

- (CGFloat)outlineView:(NSOutlineView *)ov heightOfRowByItem:(id)item {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        CGFloat rowHeight = (NSInteger)NSMapGet(rowHeights, (__bridge void *)item);
        if (rowHeight <= 0.0) {
            if (mwcFlags.autoResizeNoteRows) {
                NSTableColumn *tableColumn = [ov outlineTableColumn];
                CGFloat width = 0.0;
                id cell = [tableColumn dataCell];
                [cell setObjectValue:[item objectValue]];
                // don't use cellFrameAtRow:column: as this needs the row height which we are calculating
                if ([(PDFAnnotation *)item type] == nil)
                    width = fmax(10.0, [(SKNoteOutlineView *)ov fullWidthCellWidth]);
                else if ([tableColumn isHidden] == NO)
                    width = [tableColumn width] - [(SKNoteOutlineView *)ov outlineIndentation];
                if (width > 0.0)
                    rowHeight = [cell cellSizeForBounds:NSMakeRect(0.0, 0.0, width, CGFLOAT_MAX)].height;
                rowHeight = round(fmax(rowHeight, [ov rowHeight]) + EXTRA_ROW_HEIGHT);
                NSMapInsert(rowHeights, (__bridge void *)item, (void *)(NSInteger)rowHeight);
            } else {
                rowHeight = [(PDFAnnotation *)item type] ? [ov rowHeight] + EXTRA_ROW_HEIGHT : ([[(SKNoteText *)item note] isNote] ? DEFAULT_TEXT_ROW_HEIGHT : DEFAULT_MARKUP_ROW_HEIGHT);
            }
        }
        return rowHeight;
    }
    return [ov rowHeight];
}

- (void)outlineView:(NSOutlineView *)ov setHeight:(CGFloat)newHeight ofRowByItem:(id)item {
    NSMapInsert(rowHeights, (__bridge void *)item, (void *)(NSInteger)round(newHeight));
}

- (NSArray *)noteItems:(NSArray *)items {
    NSMutableArray *noteItems = [NSMutableArray array];
    
    for (id item in items) {
        PDFAnnotation *note = [(PDFAnnotation *)item type] == nil ? [item note] : item;
        if ([noteItems containsObject:note] == NO)
            [noteItems addObject:note];
    }
    return noteItems;
}

- (void)outlineView:(NSOutlineView *)ov deleteItems:(NSArray *)items  {
    if ([ov isEqual:rightSideController.noteOutlineView] && [items count]) {
        for (PDFAnnotation *item in [self noteItems:items])
            [[self pdfDocument] removeAnnotation:item];
        [[[self document] undoManager] setActionName:NSLocalizedString(@"Remove Note", @"Undo action name")];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov canDeleteItems:(NSArray *)items  {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        return [[self pdfDocument] allowsNotes] && [items count] > 0;
    }
    return NO;
}

- (void)outlineView:(NSOutlineView *)ov copyItems:(NSArray *)items  {
    if ([ov isEqual:rightSideController.noteOutlineView] && [items count]) {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        NSMutableArray *copiedItems = [NSMutableArray array];
        NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] init];
        BOOL isAttributed = NO;
        id item;
        
        for (item in [self noteItems:items]) {
            if ([item isMovable])
                [copiedItems addObject:item];
        }
        for (item in items) {
            if ([attrString length])
                [attrString replaceCharactersInRange:NSMakeRange([attrString length], 0) withString:@"\n\n"];
            if ([(PDFAnnotation *)item type] == nil && [[(SKNoteText *)item note] isNote]) {
                [attrString appendAttributedString:[(SKNoteText *)item text]];
                isAttributed = YES;
            } else {
                [attrString replaceCharactersInRange:NSMakeRange([attrString length], 0) withString:[item string] ?: @""];
            }
        }
        
        [pboard clearContents];
        if (isAttributed)
            [pboard writeObjects:@[attrString]];
        else
            [pboard writeObjects:@[[attrString string]]];
        if ([copiedItems count] > 0)
            [pboard writeObjects:copiedItems];
    }
}

- (BOOL)outlineView:(NSOutlineView *)ov canCopyItems:(NSArray *)items  {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        return [items count] > 0;
    }
    return NO;
}

- (id <SKImageToolTipContext>)outlineView:(NSOutlineView *)ov imageContextForItem:(id)item scale:(CGFloat *)scale {
    if ([ov isEqual:leftSideController.tocOutlineView]) {
        *scale = [[self pdfView] scaleFactor];
        return [item destination];
    }
    return nil;
}

- (NSArray *)outlineViewTypeSelectHelperSelectionStrings:(NSOutlineView *)ov {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        NSInteger i, count = [rightSideController.noteOutlineView numberOfRows];
        NSMutableArray *texts = [NSMutableArray arrayWithCapacity:count];
        for (i = 0; i < count; i++) {
            id item = [rightSideController.noteOutlineView itemAtRow:i];
            NSString *string = [item string];
            [texts addObject:string ?: @""];
        }
        return texts;
    } else if ([ov isEqual:leftSideController.tocOutlineView]) {
        NSInteger i, count = [leftSideController.tocOutlineView numberOfRows];
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
        for (i = 0; i < count; i++) 
            [array addObject:[[(PDFOutline *)[leftSideController.tocOutlineView itemAtRow:i] label] lossyStringUsingEncoding:NSASCIIStringEncoding]];
        return array;
    }
    return nil;
}

- (void)outlineView:(NSOutlineView *)ov typeSelectHelperDidFailToFindMatchForSearchString:(NSString *)searchString {
    if ([ov isEqual:rightSideController.noteOutlineView]) {
        [[statusBar rightField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"No match: \"%@\"", @"Status message"), searchString]];
    } else if ([ov isEqual:leftSideController.tocOutlineView]) {
        [[statusBar leftField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"No match: \"%@\"", @"Status message"), searchString]];
    }
}

- (void)outlineView:(NSOutlineView *)ov typeSelectHelperUpdateSearchString:(NSString *)searchString {}

#pragma mark Contextual menus

- (void)copyPage:(id)sender {
    [self tableView:leftSideController.thumbnailTableView copyRowsWithIndexes:[sender representedObject]];
}

- (void)copyPageURL:(id)sender {
    NSUInteger idx = [[sender representedObject] firstIndex];
    if (idx != NSNotFound) {
        PDFPage *page = [[pdfView document] pageAtIndex:idx];
        NSURL *skimURL = [page skimURL];
        if (skimURL != nil) {
            NSPasteboard *pboard = [NSPasteboard generalPasteboard];
            [pboard clearContents];
            [pboard writeURLs:@[skimURL] names:@[[[self document] displayName]]];
        }
    }
}

- (void)selectSelections:(id)sender {
    [pdfView setCurrentSelection:[PDFSelection selectionByAddingSelections:[sender representedObject]]];
}

- (void)deleteSnapshot:(id)sender {
    [[sender representedObject] close];
}

- (void)showSnapshot:(id)sender {
    SKSnapshotWindowController *controller = [sender representedObject];
    if ([[controller window] isVisible])
        [[controller window] orderFront:self];
    else
        [controller deminiaturize];
}

- (void)hideSnapshot:(id)sender {
    SKSnapshotWindowController *controller = [sender representedObject];
    if ([[controller window] isVisible])
        [controller miniaturize];
}

- (void)goToSnapshot:(id)sender {
    SKSnapshotWindowController *controller = [sender representedObject];
    NSUInteger pageIndex = [controller pageIndex];
    PDFPage *page = [[pdfView document] pageAtIndex:pageIndex];
    NSRect rect = [controller bounds];
    [pdfView goToRect:rect onPage:page];
}

- (void)deleteNotes:(id)sender {
    [self outlineView:rightSideController.noteOutlineView deleteItems:[sender representedObject]];
}

- (void)copyNotes:(id)sender {
    [self outlineView:rightSideController.noteOutlineView copyItems:[sender representedObject]];
}

- (void)editNoteFromTable:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    SKNoteOutlineView *ov = rightSideController.noteOutlineView;
    NSInteger row = [ov rowForItem:annotation];
    NSInteger column = [ov columnWithIdentifier:NOTE_COLUMNID];
    if (row != -1 && column != -1) {
        [ov selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [ov editColumn:column row:row withEvent:nil select:YES];
    }
}

- (void)editNoteTextFromTable:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    [pdfView scrollAnnotationToVisible:annotation];
    if ([pdfView canSelectNote])
        [pdfView setCurrentAnnotation:annotation];
    [self showNote:annotation];
    SKNoteWindowController *noteController = (SKNoteWindowController *)[self windowControllerForNote:annotation];
    [[noteController window] makeFirstResponder:[noteController textView]];
    [[noteController textView] selectAll:nil];
}

- (void)deselectNote:(id)sender {
    [pdfView setCurrentAnnotation:nil];
}

- (void)selectNote:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    [pdfView scrollAnnotationToVisible:annotation];
    [pdfView setCurrentAnnotation:annotation];
}

- (void)revealNote:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    [pdfView scrollAnnotationToVisible:annotation];
}

- (void)bringNoteToFront:(id)sender {
    PDFAnnotation *note = [sender representedObject];
    PDFPage *page = [note page];
    PDFAnnotation *lastNote = [[page annotations] lastObject];
    
    if (lastNote == note)
        return;
    
    
    NSUInteger i = [[self notes] indexOfObject:note];
    NSUInteger j = [[self notes] indexOfObject:lastNote];
    if (i < j && j != NSNotFound) {
        [self removeObjectFromNotesAtIndex:i];
        [self insertObject:note inNotesAtIndex:j];
    }
    
    [page removeAnnotation:note];
    [page addAnnotation:note];
    
    
    [pdfView setNeedsDisplayForAnnotation:note];
}

- (void)autoSizeNoteRows:(id)sender {
    NSOutlineView *ov = rightSideController.noteOutlineView;
    CGFloat height = 0.0, rowHeight = [ov rowHeight];
    NSTableColumn *tableColumn = [ov outlineTableColumn];
    id cell = [tableColumn dataCell];
    NSUInteger column = [[ov tableColumns] indexOfObject:tableColumn];
    NSRect rect = NSMakeRect(0.0, 0.0, NSWidth([ov frameOfCellAtColumn:column row:0]), CGFLOAT_MAX);
    NSRect fullRect = NSMakeRect(0.0, 0.0,  NSWidth([ov frameOfCellAtColumn:-1 row:0]), CGFLOAT_MAX);
    NSMutableIndexSet *rowIndexes = nil;
    NSArray *items = [sender representedObject];
    NSInteger row;
    
    if (items == nil) {
        NSMutableArray *tmpItems = [NSMutableArray array];
        for (PDFAnnotation *note in [self notes]) {
            [tmpItems addObject:note];
            if ([note hasNoteText])
                [tmpItems addObject:[note noteText]];
        }
        items = tmpItems;
    } else {
        rowIndexes = [NSMutableIndexSet indexSet];
    }
    
    for (id item in items) {
        [cell setObjectValue:[item objectValue]];
        if ([(PDFAnnotation *)item type] == nil)
            height = [cell cellSizeForBounds:fullRect].height;
        else if ([tableColumn isHidden] == NO)
            height = [cell cellSizeForBounds:rect].height;
        else
            height = 0.0;
        NSMapInsert(rowHeights, (__bridge void *)item, (void *)(NSInteger)round(fmax(height, rowHeight) + EXTRA_ROW_HEIGHT));
        if (rowIndexes) {
            row = [ov rowForItem:item];
            if (row != -1)
                [rowIndexes addIndex:row];
        }
    }
    [ov noteHeightOfRowsWithIndexesChanged:rowIndexes ?: [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [ov numberOfRows])]];
}

- (void)resetHeightOfNoteRows:(id)sender {
    NSArray *items = [sender representedObject];
    if (items == nil) {
        [self resetNoteRowHeights];
    } else {
        SKNoteOutlineView *ov = rightSideController.noteOutlineView;
        NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
        for (id item in items) {
            NSMapRemove(rowHeights, (__bridge void *)item);
            NSInteger row = [ov rowForItem:item];
            if (row != -1)
                [indexes addIndex:row];
        }
        [ov noteHeightOfRowsWithIndexesChanged:indexes];
    }
}

- (void)toggleAutoResizeNoteRows:(id)sender {
    mwcFlags.autoResizeNoteRows = (0 == mwcFlags.autoResizeNoteRows);
    if (mwcFlags.autoResizeNoteRows)
        [self resetNoteRowHeights];
    else
        [self autoSizeNoteRows:nil];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    NSMenuItem *item = nil;
    [menu removeAllItems];
    if ([self interactionMode] == SKPresentationMode)
        return;
    if ([menu isEqual:[leftSideController.thumbnailTableView menu]]) {
        NSInteger row = [leftSideController.thumbnailTableView clickedRow];
        if (row != -1) {
            item = [menu addItemWithTitle:NSLocalizedString(@"Copy", @"Menu item title") action:@selector(copyPage:) target:self];
            [item setRepresentedObject:[NSIndexSet indexSetWithIndex:row]];
            item = [menu addItemWithTitle:NSLocalizedString(@"Copy URL", @"Menu item title") action:@selector(copyPageURL:) target:self];
            [item setRepresentedObject:[NSIndexSet indexSetWithIndex:row]];
        }
    } else if ([menu isEqual:[leftSideController.findTableView menu]]) {
        NSIndexSet *rowIndexes = [leftSideController.findTableView selectedRowIndexes];
        NSInteger row = [leftSideController.findTableView clickedRow];
        if (row != -1) {
            if ([rowIndexes containsIndex:row] == NO)
                rowIndexes = [NSIndexSet indexSetWithIndex:row];
            NSArray *selections = [[leftSideController.findArrayController arrangedObjects] objectsAtIndexes:rowIndexes];
            if ([pdfView toolMode] == SKTextToolMode) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Select", @"Menu item title") action:@selector(selectSelections:) target:self];
                [item setRepresentedObject:selections];
            }
            if ([pdfView hideNotes] == NO && [[pdfView document] allowsNotes]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"New Circle", @"Menu item title") action:@selector(addAnnotationForContext:) target:pdfView tag:SKCircleNote];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Box", @"Menu item title") action:@selector(addAnnotationForContext:) target:pdfView tag:SKSquareNote];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Highlight", @"Menu item title") action:@selector(addAnnotationForContext:) target:pdfView tag:SKHighlightNote];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Underline", @"Menu item title") action:@selector(addAnnotationForContext:) target:pdfView tag:SKUnderlineNote];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Strike Out", @"Menu item title") action:@selector(addAnnotationForContext:) target:pdfView tag:SKStrikeOutNote];
                [item setRepresentedObject:selections];
            }
        }
    } else if ([menu isEqual:[leftSideController.groupedFindTableView menu]]) {
        NSIndexSet *rowIndexes = [leftSideController.groupedFindTableView selectedRowIndexes];
        NSInteger row = [leftSideController.groupedFindTableView clickedRow];
        if (row != -1) {
            if ([rowIndexes containsIndex:row] == NO)
                rowIndexes = [NSIndexSet indexSetWithIndex:row];
            NSArray *selections = [[[leftSideController.groupedFindArrayController arrangedObjects] objectsAtIndexes:rowIndexes] valueForKeyPath:@"@unionOfArrays.matches"];
            if ([pdfView toolMode] == SKTextToolMode) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Select", @"Menu item title") action:@selector(selectSelections:) target:self];
                [item setRepresentedObject:selections];
            }
            if ([pdfView hideNotes] == NO && [[pdfView document] allowsNotes]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"New Circle", @"Menu item title") action:@selector(addAnnotationForContext:) target:pdfView tag:SKCircleNote];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Box", @"Menu item title") action:@selector(addAnnotationForContext:) target:pdfView tag:SKSquareNote];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Highlight", @"Menu item title") action:@selector(addAnnotationForContext:) target:pdfView tag:SKHighlightNote];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Underline", @"Menu item title") action:@selector(addAnnotationForContext:) target:pdfView tag:SKUnderlineNote];
                [item setRepresentedObject:selections];
                item = [menu addItemWithTitle:NSLocalizedString(@"New Strike Out", @"Menu item title") action:@selector(addAnnotationForContext:) target:pdfView tag:SKStrikeOutNote];
                [item setRepresentedObject:selections];
            }
        }
    } else if ([menu isEqual:[rightSideController.snapshotTableView menu]]) {
        NSInteger row = [rightSideController.snapshotTableView clickedRow];
        if (row != -1) {
            SKSnapshotWindowController *controller = [[rightSideController.snapshotArrayController arrangedObjects] objectAtIndex:row];
            item = [menu addItemWithTitle:NSLocalizedString(@"Delete", @"Menu item title") action:@selector(deleteSnapshot:) target:self];
            [item setRepresentedObject:controller];
            item = [menu addItemWithTitle:NSLocalizedString(@"Show", @"Menu item title") action:@selector(showSnapshot:) target:self];
            [item setRepresentedObject:controller];
            if ([[controller window] isVisible]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Hide", @"Menu item title") action:@selector(hideSnapshot:) target:self];
                [item setRepresentedObject:controller];
            }
            item = [menu addItemWithTitle:NSLocalizedString(@"Go", @"Menu item title") action:@selector(goToSnapshot:) target:self];
            [item setRepresentedObject:controller];
        }
    } else if ([menu isEqual:[rightSideController.noteOutlineView menu]]) {
        NSArray *items;
        NSIndexSet *rowIndexes = [rightSideController.noteOutlineView selectedRowIndexes];
        NSInteger row = [rightSideController.noteOutlineView clickedRow];
        if (row != -1) {
            if ([rowIndexes containsIndex:row] == NO)
                rowIndexes = [NSIndexSet indexSetWithIndex:row];
            items = [rightSideController.noteOutlineView itemsAtRowIndexes:rowIndexes];
            
            if ([self outlineView:rightSideController.noteOutlineView canDeleteItems:items]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Delete", @"Menu item title") action:@selector(deleteNotes:) target:self];
                [item setRepresentedObject:items];
            }
            if ([self outlineView:rightSideController.noteOutlineView canCopyItems:items]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Copy", @"Menu item title") action:@selector(copyNotes:) target:self];
                [item setRepresentedObject:items];
            }
            if ([pdfView hideNotes] == NO && [items count] == 1) {
                PDFAnnotation *annotation = [[self noteItems:items] lastObject];
                if ([annotation isEditable]) {
                    if ([(PDFAnnotation *)[items lastObject] type] == nil) {
                        if ([[(SKNoteText *)[items lastObject] note] isNote]) {
                            item = [menu addItemWithTitle:[NSLocalizedString(@"Edit", @"Menu item title") stringByAppendingEllipsis] action:@selector(editNoteTextFromTable:) target:self];
                            [item setRepresentedObject:annotation];
                        }
                    } else if ([[rightSideController.noteOutlineView tableColumnWithIdentifier:NOTE_COLUMNID] isHidden]) {
                        item = [menu addItemWithTitle:[NSLocalizedString(@"Edit", @"Menu item title") stringByAppendingEllipsis] action:@selector(editThisAnnotation:) target:pdfView];
                        [item setRepresentedObject:annotation];
                    } else {
                        item = [menu addItemWithTitle:NSLocalizedString(@"Edit", @"Menu item title") action:@selector(editNoteFromTable:) target:self];
                        [item setRepresentedObject:annotation];
                        item = [menu addItemWithTitle:[NSLocalizedString(@"Edit", @"Menu item title") stringByAppendingEllipsis] action:@selector(editThisAnnotation:) target:pdfView];
                        [item setRepresentedObject:annotation];
                        [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
                        [item setAlternate:YES];
                    }
                }
                if ([pdfView hideNotes] == NO && [[self pdfDocument] allowsNotes]) {
                    if ([pdfView currentAnnotation] == annotation) {
                        item = [menu addItemWithTitle:NSLocalizedString(@"Deselect", @"Menu item title") action:@selector(deselectNote:) target:self];
                        [item setRepresentedObject:annotation];
                    } else if ([pdfView canSelectNote]) {
                        item = [menu addItemWithTitle:NSLocalizedString(@"Select", @"Menu item title") action:@selector(selectNote:) target:self];
                        [item setRepresentedObject:annotation];
                    }
                    item = [menu addItemWithTitle:NSLocalizedString(@"Show", @"Menu item title") action:@selector(revealNote:) target:self];
                    [item setRepresentedObject:annotation];
                    if ([[[annotation page] annotations] lastObject] != annotation) {
                        item = [menu addItemWithTitle:NSLocalizedString(@"Bring to Front", @"Menu item title") action:@selector(bringNoteToFront:) target:self];
                        [item setRepresentedObject:annotation];
                    }
                }
            }
            if ([menu numberOfItems] > 0)
                [menu addItem:[NSMenuItem separatorItem]];
            item = [menu addItemWithTitle:[items count] == 1 ? NSLocalizedString(@"Auto Size Row", @"Menu item title") : NSLocalizedString(@"Auto Size Rows", @"Menu item title") action:@selector(autoSizeNoteRows:) target:self];
            [item setRepresentedObject:items];
            item = [menu addItemWithTitle:[items count] == 1 ? NSLocalizedString(@"Undo Auto Size Row", @"Menu item title") : NSLocalizedString(@"Undo Auto Size Rows", @"Menu item title") action:@selector(resetHeightOfNoteRows:) target:self];
            [item setRepresentedObject:items];
            [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
            [item setAlternate:YES];
            [menu addItemWithTitle:NSLocalizedString(@"Auto Size All", @"Menu item title") action:@selector(autoSizeNoteRows:) target:self];
            item = [menu addItemWithTitle:NSLocalizedString(@"Undo Auto Size All", @"Menu item title") action:@selector(resetHeightOfNoteRows:) target:self];
            [item setKeyEquivalentModifierMask:NSEventModifierFlagOption];
            [item setAlternate:YES];
            [menu addItemWithTitle:NSLocalizedString(@"Automatically Resize", @"Menu item title") action:@selector(toggleAutoResizeNoteRows:) target:self];
        }
    }
}

#pragma mark NSControl delegate protocol

- (void)controlTextDidBeginEditing:(NSNotification *)note {
    if ([[note object] isDescendantOf:rightSideController.noteOutlineView]) {
        if (mwcFlags.isEditingTable == NO && mwcFlags.isEditingPDF == NO)
            [[self document] objectDidBeginEditing:(id)self];
        mwcFlags.isEditingTable = YES;
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)note {
    if ([[note object] isDescendantOf:rightSideController.noteOutlineView]) {
        if (mwcFlags.isEditingTable && mwcFlags.isEditingPDF == NO)
            [[self document] objectDidEndEditing:(id)self];
        mwcFlags.isEditingTable = NO;
    }
}

- (void)setDocument:(NSDocument *)document {
    if ([self document] && document == nil && (mwcFlags.isEditingTable || [pdfView isEditing])) {
        if ([self commitEditing] == NO)
            [self discardEditing];
        if (mwcFlags.isEditingPDF || mwcFlags.isEditingTable)
            [[self document] objectDidEndEditing:(id)self];
        mwcFlags.isEditingPDF = mwcFlags.isEditingTable = NO;
    }
    [super setDocument:document];
}

#pragma mark NSEditor protocol

- (void)discardEditing {
    [rightSideController.noteOutlineView abortEditing];
    [pdfView discardEditing];
    // when using abortEditing the control does not call the controlTextDidEndEditing: delegate method
    if (mwcFlags.isEditingTable || mwcFlags.isEditingPDF)
        [[self document] objectDidEndEditing:(id)self];
    mwcFlags.isEditingTable = NO;
    mwcFlags.isEditingPDF = NO;
}

- (BOOL)commitEditing {
    return [self commitEditingAndReturnError:NULL];
}

- (BOOL)commitEditingAndReturnError:(NSError **)error {
    BOOL rv = [pdfView commitEditing];
    if ([rightSideController.noteOutlineView editedRow] != -1)
        rv = [[rightSideController.noteOutlineView window] makeFirstResponder:rightSideController.noteOutlineView] && rv;
    if (rv == NO && error)
        *error = [NSError failedToCommitErrorWithLocalizedDescription:NSLocalizedString(@"Failed to commit edits", @"Error description")];
    return rv;
}

- (void)commitEditingWithDelegate:(id)delegate didCommitSelector:(SEL)didCommitSelector contextInfo:(void *)contextInfo {
    BOOL didCommit = [self commitEditingAndReturnError:NULL];
    if (delegate && didCommitSelector) {
        // - (void)editor:(id)editor didCommit:(BOOL)didCommit contextInfo:(void *)contextInfo
        dispatch_async(dispatch_get_main_queue(), ^{
            void (*didCommitImp)(id, SEL, id, BOOL, void *) = (void (*)(id, SEL, id, BOOL, void *))[delegate methodForSelector:didCommitSelector];
            if (didCommitImp)
                didCommitImp(delegate, didCommitSelector, self, didCommit, contextInfo);
        });
    }
}

#pragma mark SKNoteTypeSheetController delegate protocol

- (void)noteTypeSheetControllerNoteTypesDidChange {
    [self updateNoteFilterPredicate];
}

- (NSWindow *)windowForNoteTypeSheetController {
    return [self window];
}

#pragma mark SKPDFView delegate protocol

- (NSURL *)redirectRelativeLinkURL:(NSURL *)url {
    if ([url scheme] == nil && [[self document] fileURL])
        url = [[NSURL URLWithString:[url absoluteString] relativeToURL:[[self document] fileURL]] absoluteURL] ?: url;
    if ([url isFileURL] && [[[self document] fileType] isEqualToString:SKPDFBundleDocumentType] && [url checkResourceIsReachableAndReturnError:NULL] == NO) {
        NSString *path = [url path];
        NSURL *docURL = [[self document] fileURL];
        NSString *docPath = [docURL path];
        NSURL *replaceURL = nil;
        if ([docPath hasSuffix:@"/"] == NO)
            docPath = [docPath stringByAppendingString:@"/"];
        if ([path hasPrefix:docPath]) {
            replaceURL = [[docURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:[path substringFromIndex:[docPath length]]];
            if ([replaceURL checkResourceIsReachableAndReturnError:NULL]) {
                url = replaceURL;
            } else if ([[url pathExtension] isCaseInsensitiveEqual:@"pdf"]) {
                replaceURL = [replaceURL URLReplacingPathExtension:@"pdfd"];
                if ([replaceURL checkResourceIsReachableAndReturnError:NULL])
                    url = replaceURL;
            }
        }
    }
    return url;
}

- (void)PDFViewOpenPDF:(PDFView *)sender forRemoteGoToAction:(PDFActionRemoteGoTo *)action {
    NSURL *fileURL = [self redirectRelativeLinkURL:[action URL]];
    SKDocumentController *sdc = [NSDocumentController sharedDocumentController];
    Class docClass = [sdc documentClassForContentsOfURL:fileURL];
    if (docClass) {
        [sdc openDocumentWithContentsOfURL:fileURL display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
            if ([document isPDFDocument]) {
                NSUInteger pageIndex = [action pageIndex];
                if (pageIndex < [[document pdfDocument] pageCount]) {
                    PDFPage *page = [[document pdfDocument] pageAtIndex:pageIndex];
                    PDFDestination *dest = [[PDFDestination alloc] initWithPage:page atPoint:[action point]];
                    [[(SKMainDocument *)document pdfView] goToDestination:dest];
                }
            } else if (document == nil && error && [error isUserCancelledError] == NO) {
                [self presentError:error];
            }
        }];
    } else if (fileURL) {
        // fall back to just opening the file and ignore the destination
        [[NSWorkspace sharedWorkspace] openURL:fileURL];
    }
}

- (void)PDFViewWillClickOnLink:(PDFView *)sender withURL:(NSURL *)url {
    SKDocumentController *sdc = [NSDocumentController sharedDocumentController];
    url = [self redirectRelativeLinkURL:url];
    if ([url isFileURL] && [sdc documentClassForContentsOfURL:url]) {
        [sdc openDocumentWithContentsOfURL:url display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error){
            if (document == nil && error && [error isUserCancelledError] == NO)
                [self presentError:error];
        }];
    } else if ([url isPreskimFileURL]) {
        [sdc openDocumentWithContentsOfURL:[url associatedFileURL] display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error){
            if (document == nil && error && [error isUserCancelledError] == NO)
                [self presentError:error];
        }];
    } else if ([[url scheme] isCaseInsensitiveEqual:@"tel"]) {
        NSBeep();
    } else {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)PDFViewPerformFind:(PDFView *)sender {
    BOOL wasVisible = [[findController view] window] != nil;
    [self showFindBar];
    if (wasVisible == NO)
        NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor([pdfView documentView]), NSAccessibilityLayoutChangedNotification, [NSDictionary dictionaryWithObjectsAndKeys:NSAccessibilityUnignoredChildrenForOnlyChild([findController view]), NSAccessibilityUIElementsKey, nil]);
}

- (void)PDFViewPerformHideFind:(PDFView *)sender {
    if ([[findController view] window]) {
        [findController remove:nil];
        NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor([pdfView documentView]), NSAccessibilityLayoutChangedNotification, nil);
    }
}

- (BOOL)PDFViewIsFindVisible:(PDFView *)sender {
    return [[findController view] window] != nil;
}

- (void)PDFViewPerformGoToPage:(PDFView *)sender {
    [self doGoToPage:sender];
}

- (void)PDFViewPerformPrint:(PDFView *)sender {
    [[self document] printDocument:sender];
}

- (void)PDFViewDidBeginEditing:(PDFView *)sender {
    if (mwcFlags.isEditingPDF == NO && mwcFlags.isEditingTable == NO)
        [[self document] objectDidBeginEditing:(id)self];
    mwcFlags.isEditingPDF = YES;
}

- (void)PDFViewDidEndEditing:(PDFView *)sender {
    if (mwcFlags.isEditingPDF && mwcFlags.isEditingTable == NO)
        [[self document] objectDidEndEditing:(id)self];
    mwcFlags.isEditingPDF = NO;
}

- (void)PDFView:(PDFView *)sender editAnnotation:(PDFAnnotation *)annotation {
    [self showNote:annotation];
}

- (void)PDFView:(PDFView *)sender showSnapshotAtPageNumber:(NSInteger)pageNum forRect:(NSRect)rect scaleFactor:(CGFloat)scaleFactor autoFits:(BOOL)autoFits {
    [self showSnapshotAtPageNumber:pageNum forRect:rect scaleFactor:scaleFactor autoFits:autoFits];
}

- (void)PDFViewExitPresentation:(PDFView *)sender {
    [self exitPresentation];
}

- (void)PDFViewTogglePages:(PDFView *)sender {
    [self toggleOverview:sender];
}

- (void)PDFViewToggleContents:(PDFView *)sender {
    [self toggleLeftSidebar:sender];
}

- (void)PDFView:(PDFView *)sender rotatePageAtIndex:(NSUInteger)idx by:(NSInteger)rotation {
    [self rotatePageAtIndex:idx by:rotation];
}

- (NSUndoManager *)undoManagerForPDFView:(PDFView *)sender {
    return [[self document] undoManager];
}

#pragma mark NSSplitView delegate protocol

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview {
    if ([sender isEqual:splitView]) {
        return [subview isEqual:centerContentView] == NO;
    } else if ([sender isEqual:pdfSplitView]) {
        return [subview isEqual:secondaryPdfView];
    }
    return NO;
}

- (BOOL)splitView:(NSSplitView *)sender shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex {
    if ([sender isEqual:splitView]) {
        if ([subview isEqual:leftSideContentView])
            [self toggleLeftSidebar:sender];
        else if ([subview isEqual:rightSideContentView])
            [self toggleRightSidePane:sender];
    } else if ([sender isEqual:pdfSplitView]) {
        if ([subview isEqual:secondaryPdfView]) {
            CGFloat position = [pdfSplitView maxPossiblePositionOfDividerAtIndex:dividerIndex];
            if ([pdfSplitView isSubviewCollapsed:secondaryPdfView]) {
                if (lastSplitPDFHeight <= 0.0)
                    lastSplitPDFHeight = DEFAULT_SPLIT_PANE_HEIGHT;
                if (lastSplitPDFHeight > NSHeight([pdfContentView frame]))
                    lastSplitPDFHeight = floor(0.5 * NSHeight([pdfView frame]));
                position -= lastSplitPDFHeight;
            } else {
                lastSplitPDFHeight = NSHeight([secondaryPdfView frame]);
            }
            [pdfSplitView setPosition:position ofDividerAtIndex:dividerIndex animate:YES];
        }
    }
    return NO;
}

- (BOOL)splitView:(NSSplitView *)sender shouldHideDividerAtIndex:(NSInteger)dividerIndex {
    return [sender isEqual:splitView];
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex {
    if ([sender respondsToSelector:@selector(isAnimating)] && [(SKSplitView *)sender isAnimating])
        return proposedMax;
    else if ([sender isEqual:splitView] && dividerIndex == 1)
        return proposedMax - MIN_SIDE_PANE_WIDTH;
    else if ([sender isEqual:pdfSplitView])
        return proposedMax - MIN_SPLIT_PANE_HEIGHT;
    return proposedMax;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex {
    if ([sender respondsToSelector:@selector(isAnimating)] && [(SKSplitView *)sender isAnimating])
        return proposedMin;
    else if ([sender isEqual:splitView] && dividerIndex == 0)
        return proposedMin + MIN_SIDE_PANE_WIDTH;
    else if ([sender isEqual:pdfSplitView])
        return proposedMin + titleBarHeight + MIN_PDF_PANE_HEIGHT;
    return proposedMin;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    if ([sender isEqual:splitView]) {
        NSView *leftView = [[sender subviews] objectAtIndex:0];
        NSView *mainView = [[sender subviews] objectAtIndex:1];
        NSView *rightView = [[sender subviews] objectAtIndex:2];
        BOOL leftCollapsed = [sender isSubviewCollapsed:leftView];
        BOOL rightCollapsed = [sender isSubviewCollapsed:rightView];
        NSSize leftSize = [leftView frame].size;
        NSSize mainSize = [mainView frame].size;
        NSSize rightSize = [rightView frame].size;
        CGFloat contentWidth = NSWidth([sender frame]);
        
        if (leftCollapsed)
            leftSize.width = 0.0;
        else
            contentWidth -= [sender dividerThickness];
        if (rightCollapsed)
            rightSize.width = 0.0;
        else
            contentWidth -= [sender dividerThickness];
        
        if (contentWidth < leftSize.width + rightSize.width) {
            CGFloat oldContentWidth = oldSize.width;
            if (leftCollapsed == NO)
                oldContentWidth -= [sender dividerThickness];
            if (rightCollapsed == NO)
                oldContentWidth -= [sender dividerThickness];
            CGFloat resizeFactor = contentWidth / oldContentWidth;
            leftSize.width = floor(resizeFactor * leftSize.width);
            rightSize.width = floor(resizeFactor * rightSize.width);
        }
        
        mainSize.width = contentWidth - leftSize.width - rightSize.width;
        leftSize.height = rightSize.height = mainSize.height = NSHeight([sender frame]);
        if (leftCollapsed == NO)
            [leftView setFrameSize:leftSize];
        if (rightCollapsed == NO)
            [rightView setFrameSize:rightSize];
        [mainView setFrameSize:mainSize];
    } else if ([sender isEqual:pdfSplitView] && [[sender subviews] count] > 1) {
        NSView *topView = [[sender subviews] objectAtIndex:0];
        NSView *bottomView = [[sender subviews] objectAtIndex:1];
        NSSize topSize = [topView frame].size;
        NSSize bottomSize = [bottomView frame].size;
        CGFloat contentHeight = NSHeight([sender frame]) - [sender dividerThickness];
        
        if (bottomSize.height <= 0.0 || contentHeight < titleBarHeight + MIN_PDF_PANE_HEIGHT + MIN_SPLIT_PANE_HEIGHT) {
            topSize.height = contentHeight;
            bottomSize.height = 0.0;
        } else {
            if (rand() % 2 == 0) {
                topSize.height = floor(contentHeight * topSize.height / (oldSize.height - [sender dividerThickness]));
                bottomSize.height = contentHeight - topSize.height;
            } else {
                bottomSize.height = floor(contentHeight * bottomSize.height / (oldSize.height - [sender dividerThickness]));
                topSize.height = contentHeight - bottomSize.height;
            }
            if (bottomSize.height < MIN_SPLIT_PANE_HEIGHT) {
                bottomSize.height = MIN_SPLIT_PANE_HEIGHT;
                topSize.height = contentHeight - MIN_SPLIT_PANE_HEIGHT;
            } else if (topSize.height < titleBarHeight + MIN_PDF_PANE_HEIGHT) {
                topSize.height = titleBarHeight - MIN_PDF_PANE_HEIGHT;
                bottomSize.height = contentHeight - titleBarHeight - MIN_PDF_PANE_HEIGHT;
            }
        }
        topSize.width = bottomSize.width = NSWidth([sender frame]);
        [topView setFrameSize:topSize];
        [bottomView setFrameSize:bottomSize];
    }
    [sender adjustSubviews];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    id sender = [notification object];
    if (([sender isEqual:splitView] || sender == nil) && [[self window] frameAutosaveName] && mwcFlags.settingUpWindow == 0) {
        CGFloat leftWidth = [splitView isSubviewCollapsed:leftSideContentView] ? 0.0 : NSWidth([leftSideContentView frame]);
        CGFloat rightWidth = [splitView isSubviewCollapsed:rightSideContentView] ? 0.0 : NSWidth([rightSideContentView frame]);
        [[NSUserDefaults standardUserDefaults] setFloat:leftWidth forKey:SKLeftSidePaneWidthKey];
        [[NSUserDefaults standardUserDefaults] setFloat:rightWidth forKey:SKRightSidePaneWidthKey];
    }
}

#pragma mark UI validation

static NSArray *allMainDocumentPDFViews() {
    NSMutableArray *array = [NSMutableArray array];
    for (id document in [[NSDocumentController sharedDocumentController] documents]) {
        if ([document respondsToSelector:@selector(pdfView)])
            [array addObject:[document pdfView]];
    }
    return array;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(createNewNote:)) {
        return [pdfView canSelectNote];
    } else if (action == @selector(editNote:)) {
        PDFAnnotation *annotation = [pdfView currentAnnotation];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [annotation isSkimNote] && [annotation isEditable];
    } else if (action == @selector(autoSizeNote:)) {
        PDFAnnotation *annotation = [pdfView currentAnnotation];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [annotation isSkimNote] && ([annotation isResizable] && [annotation isLine] == NO);
    } else if (action == @selector(alignLeft:) || action == @selector(alignRight:) || action == @selector(alignCenter:)) {
        PDFAnnotation *annotation = [pdfView currentAnnotation];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [annotation isSkimNote] && [annotation isEditable] && [annotation isText];
    } else if (action == @selector(toggleHideNotes:)) {
        if ([pdfView hideNotes])
            [menuItem setTitle:NSLocalizedString(@"Show Notes", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Hide Notes", @"Menu item title")];
        return YES;
    } else if (action == @selector(changeDisplaySinglePages:)) {
        [menuItem setState:([pdfView displayMode] & kPDFDisplayTwoUp) == (PDFDisplayMode)[menuItem tag] ? NSControlStateValueOn : NSOffState];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(changeDisplayContinuous:)) {
        [menuItem setState:([pdfView displayMode] & kPDFDisplaySinglePageContinuous) == (PDFDisplayMode)[menuItem tag] ? NSControlStateValueOn : NSOffState];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(changeDisplayMode:)) {
        [menuItem setState: [pdfView extendedDisplayMode] == [menuItem tag] ? NSControlStateValueOn : NSOffState];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(changeDisplayDirection:)) {
        [menuItem setState:[pdfView displaysHorizontally] == (BOOL)[menuItem tag] ? NSControlStateValueOn : NSOffState];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO && [pdfView displayMode] == kPDFDisplaySinglePageContinuous;
    } else if (action == @selector(toggleDisplaysRTL:)) {
        [menuItem setState:[pdfView displaysRTL] ? NSControlStateValueOn : NSOffState];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(toggleDisplaysAsBook:)) {
        [menuItem setState:[pdfView displaysAsBook] ? NSControlStateValueOn : NSOffState];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(toggleDisplayPageBreaks:)) {
        [menuItem setState:[pdfView displaysPageBreaks] ? NSControlStateValueOn : NSOffState];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(changeDisplayBox:)) {
        [menuItem setState:[pdfView displayBox] == (PDFDisplayBox)[menuItem tag] ? NSControlStateValueOn : NSOffState];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(delete:) || action == @selector(copy:) || action == @selector(cut:) || action == @selector(paste:) || action == @selector(alternatePaste:) || action == @selector(pasteAsPlainText:) || action == @selector(deselectAll:) || action == @selector(changeAnnotationMode:) || action == @selector(changeToolMode:)) {
        return [self hasOverview] == NO && [pdfView validateMenuItem:menuItem];
    } else if (action == @selector(doGoToNextPage:)) {
        return [pdfView canGoToNextPage];
    } else if (action == @selector(doGoToPreviousPage:) ) {
        return [pdfView canGoToPreviousPage];
    } else if (action == @selector(doGoToFirstPage:)) {
        return [pdfView canGoToFirstPage];
    } else if (action == @selector(doGoToLastPage:)) {
        return [pdfView canGoToLastPage];
    } else if (action == @selector(doGoToPage:)) {
        return [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(allGoToNextPage:)) {
        return [[allMainDocumentPDFViews() valueForKeyPath:@"@min.canGoToNextPage"] boolValue];
    } else if (action == @selector(allGoToPreviousPage:)) {
        return [[allMainDocumentPDFViews() valueForKeyPath:@"@min.canGoToPreviousPage"] boolValue];
    } else if (action == @selector(allGoToFirstPage:)) {
        return [[allMainDocumentPDFViews() valueForKeyPath:@"@min.canGoToFirstPage"] boolValue];
    } else if (action == @selector(allGoToLastPage:)) {
        return [[allMainDocumentPDFViews() valueForKeyPath:@"@min.canGoToLastPage"] boolValue];
    } else if (action == @selector(doGoBack:)) {
        return [pdfView canGoBack];
    } else if (action == @selector(doGoForward:)) {
        return [pdfView canGoForward];
    } else if (action == @selector(goToMarkedPage:)) {
        if (beforeMarkedPageIndex != NSNotFound) {
            [menuItem setTitle:NSLocalizedString(@"Jump Back From Marked Page", @"Menu item title")];
            return YES;
        } else {
            [menuItem setTitle:NSLocalizedString(@"Go To Marked Page", @"Menu item title")];
            return markedPageIndex != NSNotFound && markedPageIndex != [[pdfView currentPage] pageIndex];
        }
    } else if (action == @selector(markPage:)) {
        return [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(doZoomIn:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [pdfView canZoomIn];
    } else if (action == @selector(doZoomOut:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [pdfView canZoomOut];
    } else if (action == @selector(doZoomToActualSize:)) {
        return [[self pdfDocument] isLocked] == NO && ([pdfView autoScales] || fabs([pdfView scaleFactor] - 1.0) > 0.0);
    } else if (action == @selector(doZoomToPhysicalSize:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO && ([pdfView autoScales] || fabs([pdfView physicalScaleFactor] - 1.0 ) > 0.001);
    } else if (action == @selector(doZoomToSelection:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO && (NSIsEmptyRect([pdfView currentSelectionRect]) == NO || [pdfView toolMode] != SKSelectToolMode);
    } else if (action == @selector(doZoomToFit:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO && [pdfView autoScales] == NO;
    } else if (action == @selector(alternateZoomToFit:)) {
// @@ Horizontal layout
        PDFDisplayMode displayMode = [pdfView extendedDisplayMode];
        if ((displayMode & kPDFDisplaySinglePageContinuous) != 0) {
            [menuItem setTitle:NSLocalizedString(@"Zoom To Height", @"Menu item title")];
        } else {
            [menuItem setTitle:NSLocalizedString(@"Zoom To Width", @"Menu item title")];
        }
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(doAutoScale:)) {
        return [[self pdfDocument] isLocked] == NO && [pdfView autoScales] == NO && [self hasOverview] == NO;
    } else if (action == @selector(toggleAutoScale:)) {
        [menuItem setState:[pdfView autoScales] ? NSControlStateValueOn : NSOffState];
        return [[self pdfDocument] isLocked] == NO && [self hasOverview] == NO;
    } else if (action == @selector(rotateRight:) || action == @selector(rotateLeft:) || action == @selector(rotateAllRight:) || action == @selector(rotateAllLeft:)) {
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(cropAll:) || action == @selector(crop:) || action == @selector(autoCropAll:) || action == @selector(smartAutoCropAll:)) {
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(resetCrop:)) {
        return mwcFlags.hasCropped && [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(autoSelectContent:)) {
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO && [pdfView toolMode] == SKSelectToolMode;
    } else if (action == @selector(takeSnapshot:)) {
        return [[self pdfDocument] isLocked] == NO && [self hasOverview] == NO;
    } else if (action == @selector(toggleLeftSidebar:)) {
        if ([self leftSidebarIsOpen])
            [menuItem setTitle:NSLocalizedString(@"Hide Contents Pane", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Contents Pane", @"Menu item title")];
        return YES;
    } else if (action == @selector(toggleRightSidePane:)) {
        if ([self rightSidePaneIsOpen])
            [menuItem setTitle:NSLocalizedString(@"Hide Notes Pane", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Notes Pane", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode;
    } else if (action == @selector(changeLeftSidePaneState:)) {
        [menuItem setState:mwcFlags.leftSidePaneState == (SKLeftSidePaneState)[menuItem tag] ? (([leftSideController.findTableView window] || [leftSideController.groupedFindTableView window]) ? NSMixedState : NSControlStateValueOn) : NSOffState];
        return (SKLeftSidePaneState)[menuItem tag] == SKSidePaneStateThumbnail || [[pdfView document] outlineRoot];
    } else if (action == @selector(changeRightSidePaneState:)) {
        [menuItem setState:mwcFlags.rightSidePaneState == (SKRightSidePaneState)[menuItem tag] ? NSControlStateValueOn : NSOffState];
        return [self interactionMode] != SKPresentationMode;
    } else if (action == @selector(toggleOverview:)) {
        if ([self hasOverview])
            [menuItem setTitle:NSLocalizedString(@"Hide Overview", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Overview", @"Menu item title")];
        return YES;
    } else if (action == @selector(toggleSplitPDF:)) {
        if ([(NSView *)secondaryPdfView window])
            [menuItem setTitle:NSLocalizedString(@"Hide Split PDF", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Split PDF", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode;
    } else if (action == @selector(toggleStatusBar:)) {
        if ([statusBar isVisible])
            [menuItem setTitle:NSLocalizedString(@"Hide Status Bar", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Status Bar", @"Menu item title")];
        return [self interactionMode] == SKNormalMode || [self interactionMode] == SKFullScreenMode;
    } else if (action == @selector(searchPDF:)) {
        return [self interactionMode] != SKPresentationMode;
    } else if (action == @selector(toggleFullscreen:)) {
        if ([self interactionMode] == SKFullScreenMode)
            [menuItem setTitle:NSLocalizedString(@"Remove Full Screen", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Full Screen", @"Menu item title")];
        return [self canEnterFullscreen] || [self canExitFullscreen];
    } else if (action == @selector(togglePresentation:)) {
        if ([self interactionMode] == SKPresentationMode)
            [menuItem setTitle:NSLocalizedString(@"Remove Presentation", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Presentation", @"Menu item title")];
        return [self canEnterPresentation] || [self canExitPresentation];
    } else if (action == @selector(getInfo:)) {
        return [self interactionMode] != SKPresentationMode;
    } else if (action == @selector(performFit:)) {
        return [self interactionMode] == SKNormalMode && [[self pdfDocument] isLocked] == NO && [self hasOverview] == NO;
    } else if (action == @selector(password:)) {
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] permissionsStatus] != kPDFDocumentPermissionsOwner;
    } else if (action == @selector(toggleReadingBar:)) {
        if ([[self pdfView] hasReadingBar])
            [menuItem setTitle:NSLocalizedString(@"Hide Reading Bar", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Show Reading Bar", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(togglePacer:)) {
        if ([[self pdfView] hasPacer])
            [menuItem setTitle:NSLocalizedString(@"Stop Pacer", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Start Pacer", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(changePacerSpeed:)) {
        if ([menuItem tag] > 0) {
            CGFloat speed = [pdfView pacerSpeed];
            NSInteger s = 5 * MAX(0, (NSInteger)round(0.2 * speed) - 1) + [menuItem tag];
            [menuItem setTitle:[NSString stringWithFormat:@"%ld",(long)s]];
            [menuItem setState:(NSInteger)round(speed) == s ? NSControlStateValueOn : NSOffState];
        }
        return YES;
    } else if (action == @selector(savePDFSettingToDefaults:)) {
        if ([self interactionMode] == SKFullScreenMode)
            [menuItem setTitle:NSLocalizedString(@"Use Current View Settings as Default for Full Screen", @"Menu item title")];
        else
            [menuItem setTitle:NSLocalizedString(@"Use Current View Settings as Default", @"Menu item title")];
        return [self interactionMode] != SKPresentationMode && [self hasOverview] == NO && [[self pdfDocument] isLocked] == NO;
    } else if (action == @selector(chooseTransition:)) {
        return [[self pdfDocument] pageCount] > 1;
    } else if (action == @selector(toggleCaseInsensitiveSearch:)) {
        [menuItem setState:mwcFlags.caseInsensitiveSearch ? NSControlStateValueOn : NSOffState];
        return YES;
    } else if (action == @selector(toggleWholeWordSearch:)) {
        [menuItem setState:mwcFlags.wholeWordSearch ? NSControlStateValueOn : NSOffState];
        return YES;
    } else if (action == @selector(toggleCaseInsensitiveFilter:)) {
        [menuItem setState:mwcFlags.caseInsensitiveFilter ? NSControlStateValueOn : NSOffState];
        return YES;
    } else if (action == @selector(toggleAutoResizeNoteRows:)) {
        [menuItem setState:mwcFlags.autoResizeNoteRows ? NSControlStateValueOn : NSOffState];
        return YES;
    } else if (action == @selector(performFindPanelAction:)) {
        if ([self interactionMode] == SKPresentationMode)
            return NO;
        switch ([menuItem tag]) {
            case NSFindPanelActionShowFindPanel:
                return YES;
            case NSFindPanelActionNext:
            case NSFindPanelActionPrevious:
                return YES;
            case NSFindPanelActionSetFindString:
                return [[[self pdfView] currentSelection] hasCharacters];
            default:
                return NO;
        }
    } else if (action == @selector(centerSelectionInVisibleArea:)) {
        return [self interactionMode] != SKPresentationMode &&
               [[pdfView currentSelection] hasCharacters];
    }
    return YES;
}

#pragma mark Notification handlers

#define MAX_HIGHLIGHTS 5

- (void)handlePageChangedNotification:(NSNotification *)notification {
    // When the PDFView is changing scale, or when view settings change when switching fullscreen modes, 
    // a lot of wrong page change notifications may be send, which we better ignore. 
    // Full screen switching and zooming should not change the current page anyway.
    if ([pdfView isZooming] || mwcFlags.isSwitchingFullScreen || [pdfView needsRewind])
        return;
    
    PDFPage *page = [pdfView currentPage];
    NSUInteger pageIndex = [page pageIndex];
    
    if ([lastViewedPages count] == 0) {
        [lastViewedPages addPointer:(void *)pageIndex];
    } else if ((NSUInteger)[lastViewedPages pointerAtIndex:0] != pageIndex) {
        [lastViewedPages insertPointer:(void *)pageIndex atIndex:0];
        if ([lastViewedPages count] > MAX_HIGHLIGHTS)
            [lastViewedPages setCount:MAX_HIGHLIGHTS];
    }
    [self updateThumbnailHighlights];
    [self updateTocHighlights];

    [self updatePageLabel];
    
    [self updateOutlineSelection];
    [self updateNoteSelection];
    [self updateThumbnailSelection];
    
    [overviewView setSelectionIndexes:[NSIndexSet indexSetWithIndex:pageIndex]];
    if ([self hasOverview])
        [overviewView scrollRectToVisible:[overviewView frameForItemAtIndex:pageIndex]];
    
    if (beforeMarkedPageIndex != NSNotFound && [[pdfView currentPage] pageIndex] != markedPageIndex)
        beforeMarkedPageIndex = NSNotFound;
    
    [self synchronizeWindowTitleWithDocumentName];
    
    if ([self interactionMode] == SKPresentationMode && [self presentationNotesDocument]) {
        PDFDocument *pdfDoc = [[self presentationNotesDocument] pdfDocument];
        NSInteger offset = [self presentationNotesOffset];
        pageIndex = (NSUInteger)MAX(0, MIN((NSInteger)[pdfDoc pageCount], (NSInteger)pageIndex + offset));
        if ([self presentationNotesDocument] == [self document])
            [[presentationPreview pdfView] goToCurrentPage:[pdfDoc pageAtIndex:pageIndex]];
        else
            [[self presentationNotesDocument] setCurrentPage:[pdfDoc pageAtIndex:pageIndex]];
    }
    
    mwcFlags.recentInfoNeedsUpdate = 1;
}

- (void)handleDisplayBoxChangedNotification:(NSNotification *)notification {
    [self allThumbnailsNeedUpdate];
}

- (void)handleSelectionOrMagnificationChangedNotification:(NSNotification *)notification {}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification {
    if ([self interactionMode] == SKPresentationMode)
        [self exitPresentation];
}

- (void)handleApplicationDidResignActiveNotification:(NSNotification *)notification {
    if ([self interactionMode] == SKPresentationMode && [[NSUserDefaults standardUserDefaults] boolForKey:SKUseNormalLevelForPresentationKey] == NO) {
        [[self window] setLevel:NSNormalWindowLevel];
    }
}

- (void)handleApplicationWillBecomeActiveNotification:(NSNotification *)notification {
    if ([self interactionMode] == SKPresentationMode && [[NSUserDefaults standardUserDefaults] boolForKey:SKUseNormalLevelForPresentationKey] == NO) {
        [[self window] setLevel:NSPopUpMenuWindowLevel];
    }
}

- (void)setHasOutline:(BOOL)hasOutline forAnnotation:(PDFAnnotation *)annotation {
    SKNoteOutlineView *ov = rightSideController.noteOutlineView;
    NSInteger row = [ov rowForItem:annotation];
    NSUInteger column = [ov columnWithIdentifier:TYPE_COLUMNID];
    if (row != -1 && column != NSNotFound) {
        NSTableCellView *view = [ov viewAtColumn:column row:row makeIfNecessary:NO];
        if (view)
            [(SKAnnotationTypeImageView *)[view imageView] setHasOutline:hasOutline];
    }
}

- (void)handleCurrentAnnotationChangedNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [pdfView currentAnnotation];
    SKNoteOutlineView *ov = rightSideController.noteOutlineView;
    
    [self setHasOutline:NO forAnnotation:[[notification userInfo] objectForKey:SKPDFViewAnnotationKey]];
    
    if ([[self window] isMainWindow])
        [self updateUtilityPanel];
    if ([annotation isSkimNote]) {
        if ([[self selectedNotes] containsObject:annotation] == NO) {
            [ov selectRowIndexes:[NSIndexSet indexSetWithIndex:[ov rowForItem:annotation]] byExtendingSelection:NO];
        }
        [self setHasOutline:YES forAnnotation:annotation];
    } else {
        [ov deselectAll:self];
    }
    [ov reloadData];
}

- (void)handleReadingBarDidChangeNotification:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    PDFPage *oldPage = [userInfo objectForKey:SKPDFViewOldPageKey];
    PDFPage *newPage = [userInfo objectForKey:SKPDFViewNewPageKey];
    if (oldPage)
        [self updateThumbnailAtPageIndex:[oldPage pageIndex]];
    if (newPage && [newPage isEqual:oldPage] == NO)
        [self updateThumbnailAtPageIndex:[newPage pageIndex]];
}

- (void)handleWillRemoveDocumentNotification:(NSNotification *)notification {
    if ([[notification userInfo] objectForKey:SKDocumentControllerDocumentKey] == presentationNotesDocument)
        [self setPresentationNotesDocument:nil];
}

- (void)handleNoteViewFrameDidChangeNotification:(NSNotification *)notification {
    if (mwcFlags.autoResizeNoteRows && [splitView isAnimating] == NO) {
        [rowHeights removeAllObjects];
        [rightSideController.noteOutlineView noteHeightOfRowsChangedAnimating:NO];
    }
}

- (void)handlePageLabelsChangedNotification:(NSNotification *)notification {
    [self updatePageLabels];
}

- (void)observeUndoManagerCheckpoint:(NSNotification *)notification {
    // Start the coalescing of note property changes over.
    undoGroupOldPropertiesPerNote = nil;
}

- (void)handleOpenOrCloseUndoGroupNotification:(NSNotification *)notification {
    [pdfView undoManagerDidOpenOrCloseUndoGroup];
}

#pragma mark Observer registration

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    // Application
    [nc addObserver:self selector:@selector(handleApplicationWillTerminateNotification:) 
                             name:SKApplicationStartsTerminatingNotification object:NSApp];
    [nc addObserver:self selector:@selector(handleApplicationDidResignActiveNotification:)
                             name:NSApplicationDidResignActiveNotification object:NSApp];
    [nc addObserver:self selector:@selector(handleApplicationWillBecomeActiveNotification:) 
                             name:NSApplicationWillBecomeActiveNotification object:NSApp];
    // PDFView
    [nc addObserver:self selector:@selector(handlePageChangedNotification:) 
                             name:PDFViewPageChangedNotification object:pdfView];
    [nc addObserver:self selector:@selector(handleSelectionOrMagnificationChangedNotification:) 
                             name:SKPDFViewSelectionChangedNotification object:pdfView];
    [nc addObserver:self selector:@selector(handleSelectionOrMagnificationChangedNotification:) 
                             name:SKPDFViewMagnificationChangedNotification object:pdfView];
    [nc addObserver:self selector:@selector(handleDisplayBoxChangedNotification:) 
                             name:PDFViewDisplayBoxChangedNotification object:pdfView];
    [nc addObserver:self selector:@selector(handleCurrentAnnotationChangedNotification:)
                             name:SKPDFViewCurrentAnnotationChangedNotification object:pdfView];
    [nc addObserver:self selector:@selector(handleReadingBarDidChangeNotification:) 
                             name:SKPDFViewReadingBarDidChangeNotification object:pdfView];
    // View
    [nc addObserver:self selector:@selector(handleNoteViewFrameDidChangeNotification:) 
                             name:NSViewFrameDidChangeNotification object:[rightSideController.noteOutlineView enclosingScrollView]];
    //  UndoManager
    [nc addObserver:self selector:@selector(observeUndoManagerCheckpoint:)
                             name:NSUndoManagerCheckpointNotification object:[[self document] undoManager]];
    [nc addObserver:self selector:@selector(handleOpenOrCloseUndoGroupNotification:)
                             name:NSUndoManagerDidOpenUndoGroupNotification object:[[self document] undoManager]];
    [nc addObserver:self selector:@selector(handleOpenOrCloseUndoGroupNotification:)
                             name:NSUndoManagerDidCloseUndoGroupNotification object:[[self document] undoManager]];
    //  SKDocumentController
    [nc addObserver:self selector:@selector(handleWillRemoveDocumentNotification:)
                             name:SKDocumentControllerWillRemoveDocumentNotification object:nil];
    // PDFPage
    [nc addObserver:self selector:@selector(handlePageLabelsChangedNotification:)
                             name:SKPageLabelsChangedNotification object:nil];
}

@end
