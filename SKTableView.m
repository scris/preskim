//
//  NSTableView_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 8/20/07.
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

#import "SKTableView.h"
#import "SKTypeSelectHelper.h"
#import "NSEvent_SKExtensions.h"
#import "NSFont_SKExtensions.h"
#import "SKImageToolTipWindow.h"

#define SKImageToolTipRowViewKey @"SKImageToolTipRowView"
#define SKImageToolTipColumnKey @"SKImageToolTipColumn"

@implementation SKTableView

@synthesize typeSelectHelper, supportsQuickLook, imageToolTipLayout;
@dynamic canDelete, canCopy, canPaste, delegate;

- (void)dealloc {
    [typeSelectHelper setDelegate:nil];
}

- (void)setTypeSelectHelper:(SKTypeSelectHelper *)newTypeSelectHelper {
    if (typeSelectHelper != newTypeSelectHelper) {
        if ([typeSelectHelper delegate] == self)
            [typeSelectHelper setDelegate:nil];
        typeSelectHelper = newTypeSelectHelper;
        [typeSelectHelper setDelegate:self];
    }
}

- (void)reloadData {
    [super reloadData];
    [self reloadTypeSelectStrings];
}

- (void)reloadDataForRowIndexes:(NSIndexSet *)rowIndexes columnIndexes:(NSIndexSet *)columnIndexes {
    [super reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];
    [self reloadTypeSelectStrings];
}

- (void)endUpdates {
    [super endUpdates];
    [self reloadTypeSelectStrings];
}

- (void)reloadTypeSelectStrings {
    [typeSelectHelper rebuildTypeSelectSearchCache];
}

- (void)keyDown:(NSEvent *)theEvent {
    unichar eventChar = [theEvent firstCharacter];
	NSUInteger modifierFlags = [theEvent deviceIndependentModifierFlags];
    
	if ((eventChar == NSNewlineCharacter || eventChar == NSEnterCharacter || eventChar == NSCarriageReturnCharacter) && modifierFlags == 0) {
        if ([self doubleAction] == NULL || [self sendAction:[self doubleAction] to:[self target]] == NO)
            NSBeep();
    } else if ((eventChar == NSDeleteCharacter || eventChar == NSDeleteFunctionKey) && modifierFlags == 0 && [self canDelete]) {
        [self delete:self];
    } else if ((eventChar == SKSpaceCharacter) && modifierFlags == 0) {
        if (supportsQuickLook == NO)
            [[self enclosingScrollView] pageDown:nil];
        else if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible])
            [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
        else
            [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
    } else if ((eventChar == SKSpaceCharacter) && modifierFlags == NSEventModifierFlagShift) {
        if (supportsQuickLook == NO)
            [[self enclosingScrollView] pageUp:nil];
    } else if (eventChar == NSHomeFunctionKey && (modifierFlags & ~NSEventModifierFlagFunction) == 0) {
        [self scrollToBeginningOfDocument:nil];
    } else if (eventChar == NSEndFunctionKey && (modifierFlags & ~NSEventModifierFlagFunction) == 0) {
        [self scrollToEndOfDocument:nil];
	} else if (eventChar == NSLeftArrowFunctionKey && modifierFlags == 0) {
        [self moveLeft:nil];
    } else if (eventChar == NSRightArrowFunctionKey && modifierFlags == 0) {
        [self moveRight:nil];
    } else if ([typeSelectHelper handleEvent:theEvent] == NO) {
        [super keyDown:theEvent];
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    if ([self imageToolTipLayout] != SKTableImageToolTipNone)
        [[SKImageToolTipWindow sharedToolTipWindow] remove];
    if ([self allowsMultipleSelection] == NO && ([theEvent modifierFlags] & NSEventModifierFlagCommand) && [[self delegate] respondsToSelector:@selector(tableView:commandSelectRow:)]) {
        NSInteger row = [self rowAtPoint:[theEvent locationInView:self]];
        if (row != -1 && [[self delegate] tableView:self commandSelectRow:row])
            return;
    }
    [super mouseDown:theEvent];
}

- (void)scrollToBeginningOfDocument:(id)sender {
    if ([self numberOfRows])
        [self scrollRowToVisible:0];
}

- (void)scrollToEndOfDocument:(id)sender {
    if ([self numberOfRows])
        [self scrollRowToVisible:[self numberOfRows] - 1];
}

- (void)moveLeft:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(tableViewMoveLeft:)])
        [[self delegate] tableViewMoveLeft:self];
}

- (void)moveRight:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(tableViewMoveRight:)])
        [[self delegate] tableViewMoveRight:self];
}

- (BOOL)canDelete {
    NSIndexSet *indexes = [self selectedRowIndexes];
    if ([indexes count] && [[self delegate] respondsToSelector:@selector(tableView:deleteRowsWithIndexes:)]) {
        if ([[self delegate] respondsToSelector:@selector(tableView:canDeleteRowsWithIndexes:)])
            return [[self delegate] tableView:self canDeleteRowsWithIndexes:indexes];
        else
            return YES;
    }
    return NO;
}

- (void)delete:(id)sender {
    if ([self canDelete])
        [[self delegate] tableView:self deleteRowsWithIndexes:[self selectedRowIndexes]];
    else
        NSBeep();
}

- (BOOL)canCopy {
    NSIndexSet *indexes = [self selectedRowIndexes];
    if ([indexes count] && [[self delegate] respondsToSelector:@selector(tableView:copyRowsWithIndexes:)]) {
        if ([[self delegate] respondsToSelector:@selector(tableView:canCopyRowsWithIndexes:)])
            return [[self delegate] tableView:self canCopyRowsWithIndexes:indexes];
        else
            return YES;
    }
    return NO;
}

- (void)copy:(id)sender {
    if ([self canCopy])
        [[self delegate] tableView:self copyRowsWithIndexes:[self selectedRowIndexes]];
    else
        NSBeep();
}

- (BOOL)canPaste {
    if ([[self delegate] respondsToSelector:@selector(tableView:pasteFromPasteboard:)]) {
        if ([[self delegate] respondsToSelector:@selector(tableView:canPasteFromPasteboard:)])
            return [[self delegate] tableView:self canPasteFromPasteboard:[NSPasteboard generalPasteboard]];
        else
            return YES;
    }
    return NO;
}

- (void)paste:(id)sender {
    if ([self canPaste])
        [[self delegate] tableView:self pasteFromPasteboard:[NSPasteboard generalPasteboard]];
    else
        NSBeep();
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(delete:))
        return [self canDelete];
    else if ([menuItem action] == @selector(copy:))
        return [self canCopy];
    else if ([menuItem action] == @selector(paste:))
        return [self canPaste];
    else if ([menuItem action] == @selector(selectAll:))
        return [self allowsMultipleSelection];
    else if ([menuItem action] == @selector(deselectAll:))
        return [self allowsEmptySelection];
    else if ([[SKTableView superclass] instancesRespondToSelector:@selector(validateMenuItem:)])
        return [super validateMenuItem:menuItem];
    return YES;
}

- (NSFont *)font {
    return font;
}

- (void)setFont:(NSFont *)newFont {
    if (font != newFont) {
        font = newFont;
        
        for (NSTableColumn *tc in [self tableColumns]) {
            NSCell *cell = [tc dataCell];
            if ([cell type] == NSTextCellType)
                [cell setFont:font];
        }
        
        CGFloat rowHeight = [font defaultViewLineHeight];
        rowHeight += 4.0;
        [self setRowHeight:rowHeight];
        [self reloadData];
    }
}

- (id)makeViewWithIdentifier:(NSString *)identifier owner:(id)owner {
    id view = [super makeViewWithIdentifier:identifier owner:owner];
    if (font) {
        if ([view respondsToSelector:@selector(setFont:)])
            [view setFont:font];
        else if ([view respondsToSelector:@selector(textField)])
            [[view textField] setFont:font];
    }
    return view;
}

- (void)noteHeightOfRowsChangedAnimating:(BOOL)animate {
    if (animate == NO) {
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0.0];
    }
    [self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self numberOfRows])]];
    if (animate == NO) {
        [NSAnimationContext endGrouping];
    }
}

- (void)noteHeightOfRowChanged:(NSInteger)row animating:(BOOL)animate {
    if (animate == NO) {
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0.0];
    }
    [self noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:row]];
    if (animate == NO) {
        [NSAnimationContext endGrouping];
    }
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if ([self window] == nil)
        [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row){ [rowView setEmphasized:NO]; }];
}

#pragma mark Tracking

- (BOOL)hasRowImageToolTips {
    return [self imageToolTipLayout] == SKTableImageToolTipByRow && [[self delegate] respondsToSelector:@selector(tableView:imageContextForTableColumn:row:scale:)];
}

- (BOOL)hasCellImageToolTips {
    return [self imageToolTipLayout] == SKTableImageToolTipByCell && [[self delegate] respondsToSelector:@selector(tableView:imageContextForTableColumn:row:scale:)];
}

- (void)addTrackingAreaForRowView:(NSTableRowView *)rowView {
    NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[NSValue valueWithNonretainedObject:rowView], SKImageToolTipRowViewKey, nil];
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[rowView bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:userInfo];
    [rowView addTrackingArea:area];
}

- (void)addTrackingAreasForRowView:(NSTableRowView *)rowView {
    NSInteger column, numCols = [self numberOfColumns];
    for (column = 0; column < numCols; column++) {
        NSView *view = [rowView viewAtColumn:column];
        if (view) {
            NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[NSValue valueWithNonretainedObject:rowView], SKImageToolTipRowViewKey, [NSNumber numberWithInteger:column], SKImageToolTipColumnKey, nil];
            NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[view frame] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow owner:self userInfo:userInfo];
            [rowView addTrackingArea:area];
        }
    }
}

- (void)removeTrackingAreasForRowView:(NSTableRowView *)rowView {
    NSArray *areas = [[rowView trackingAreas] copy];
    for (NSTrackingArea *area in areas) {
        if ([[area userInfo] objectForKey:SKImageToolTipRowViewKey])
            [rowView removeTrackingArea:area];
    }
}

- (void)addTrackingAreasIfNeeded {
    if ([self hasRowImageToolTips])
        [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row){
            [self addTrackingAreaForRowView:rowView];
        }];
    else if ([self hasCellImageToolTips])
        [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row){
            [self addTrackingAreasForRowView:rowView];
        }];
}

- (void)removeTrackingAreasIfNeeded {
    if ([self imageToolTipLayout] != SKTableImageToolTipNone)
        [self enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row){
            [self removeTrackingAreasForRowView:rowView];
        }];
}

- (void)didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    [super didAddRowView:rowView forRow:row];
    if ([self hasRowImageToolTips])
        [self addTrackingAreaForRowView:rowView];
    else if ([self hasCellImageToolTips])
        [self addTrackingAreasForRowView:rowView];
}

- (void)didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    [super didRemoveRowView:rowView forRow:row];
    if ([self imageToolTipLayout] != SKTableImageToolTipNone)
        [self removeTrackingAreasForRowView:rowView];
}

- (void)mouseEntered:(NSEvent *)theEvent{
    if ([self imageToolTipLayout] != SKTableImageToolTipNone) {
        NSTableRowView *rowView = [[[[theEvent trackingArea] userInfo] objectForKey:SKImageToolTipRowViewKey] nonretainedObjectValue];
        if (rowView) {
            NSInteger row = [self rowForView:rowView];
            if (row != -1) {
                id <SKImageToolTipContext> context = nil;
                CGFloat scale = 1.0;
                NSNumber *colNum = [[[theEvent trackingArea] userInfo] objectForKey:SKImageToolTipColumnKey];
                if (colNum) {
                    NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:[colNum integerValue]];
                    context = [[self delegate] tableView:self imageContextForTableColumn:tableColumn row:row scale:&scale];
                } else {
                    context = [[self delegate] tableView:self imageContextForTableColumn:nil row:row scale:&scale];
                }
                if (context)
                    [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:context scale:scale atPoint:NSZeroPoint];
            }
            return;
        }
    }
    if ([[SKTableView superclass] instancesRespondToSelector:_cmd])
        [super mouseEntered:theEvent];
}

- (void)mouseExited:(NSEvent *)theEvent{
    if ([self imageToolTipLayout] != SKTableImageToolTipNone && [[[theEvent trackingArea] userInfo] objectForKey:SKImageToolTipRowViewKey])
        [[SKImageToolTipWindow sharedToolTipWindow] fadeOut];
    else if ([[SKTableView superclass] instancesRespondToSelector:_cmd])
        [super mouseExited:theEvent];
}

- (void)setImageToolTipLayout:(SKTableImageToolTipLayout)newImageToolTipLayout {
    if (newImageToolTipLayout != imageToolTipLayout) {
        [self removeTrackingAreasIfNeeded];
        imageToolTipLayout = newImageToolTipLayout;
        [self addTrackingAreasIfNeeded];
    }
}

#pragma mark SKTypeSelectHelper datasource protocol

- (NSArray *)typeSelectHelperSelectionStrings {
    if ([[self delegate] respondsToSelector:@selector(tableViewTypeSelectHelperSelectionStrings:)])
        return [[self delegate] tableViewTypeSelectHelperSelectionStrings:self];
    return nil;
}

- (NSUInteger)typeSelectHelperCurrentlySelectedIndex {
    return [[self selectedRowIndexes] lastIndex];
}

- (void)typeSelectHelperSelectItemAtIndex:(NSUInteger)itemIndex {
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
    [self scrollRowToVisible:itemIndex];
}

- (void)typeSelectHelperDidFailToFindMatchForSearchString:(NSString *)searchString {
    if ([[self delegate] respondsToSelector:@selector(tableView:typeSelectHelperDidFailToFindMatchForSearchString:)])
        [[self delegate] tableView:self typeSelectHelperDidFailToFindMatchForSearchString:searchString];
}

- (void)typeSelectHelperUpdateSearchString:(NSString *)searchString {
    if ([[self delegate] respondsToSelector:@selector(tableView:typeSelectHelperUpdateSearchString:)])
        [[self delegate] tableView:self typeSelectHelperUpdateSearchString:searchString];
}

- (id <SKTableViewDelegate>)delegate {
    return (id <SKTableViewDelegate>)[super delegate];
}

- (void)setDelegate:(id <SKTableViewDelegate>)newDelegate {
    [self removeTrackingAreasIfNeeded];
    [super setDelegate:newDelegate];
    [self addTrackingAreasIfNeeded];
}

@end
