//
//  SKTocOutlineView.m
//  Skim
//
//  Created by Christiaan Hofman on 2/25/07.
/*
 This software is Copyright (c) 2007-2009
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

#import "SKTocOutlineView.h"
#import "SKTypeSelectHelper.h"
#import "NSColor_SKExtensions.h"


@implementation SKTocOutlineView

+ (BOOL)usesDefaultFontSize { return YES; }

+ (float)rowHeightForFont:(NSFont *)font {
    float rowHeight = [super rowHeightForFont:font];
    if ([self instancesRespondToSelector:@selector(setSelectionHighlightStyle:)])
        rowHeight += 2.0;
    return rowHeight;
}

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)])
            [self setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
        else
            [self setBackgroundColor:[NSColor tableBackgroundColor]];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)])
            [self setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
        else
            [self setBackgroundColor:[NSColor tableBackgroundColor]];
    }
    return self;
}

- (void)dealloc {
    if (trackingRects != NULL)
        CFRelease(trackingRects);
    [super dealloc];
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect {
    NSColor *color;
    int row;
    NSRect rect;
    
    if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
        if ([[self window] isMainWindow] == NO)
            color = [NSColor colorWithDeviceRed:40606.0/65535.0 green:40606.0/65535.0 blue:40606.0/65535.0 alpha:1.0];
        else if ([[self window] isKeyWindow] && [[self window] firstResponder] == self)
            color = [NSColor colorWithDeviceRed:14135.0/65535.0 green:29298.0/65535.0 blue:48830.0/65535.0 alpha:1.0];
        else
            color = [NSColor colorWithDeviceRed:34695.0/65535.0 green:39064.0/65535.0 blue:48316.0/65535.0 alpha:1.0];
    } else {
        if ([[self window] isKeyWindow] && [[self window] firstResponder] == self)
            color = [NSColor alternateSelectedControlColor];
        else
            color = [NSColor secondarySelectedTableColor];
    }
    
    [NSGraphicsContext saveGraphicsState];
    
    if ([[self delegate] respondsToSelector:@selector(outlineViewHighlightedRows:)]) {
        NSMutableIndexSet *rowIndexes = [[[self selectedRowIndexes] mutableCopy] autorelease];
        NSArray *rows = [[self delegate] outlineViewHighlightedRows:self];
        int i, count = MIN((int)[rows count], 5);
        
        for (i = 0; i < count; i++) {
            row = [[rows objectAtIndex:i] intValue];
            rect = [self rectOfRow:row];
            if (NSIntersectsRect(rect, clipRect) && [rowIndexes containsIndex:row] == NO) {
                [[color colorWithAlphaComponent:0.5 - 0.1 * i] setFill];
                [NSBezierPath fillRect:rect];
            }
            [rowIndexes addIndex:row];
        }
    }
    
    [NSGraphicsContext restoreGraphicsState];
    
    [super highlightSelectionInClipRect:clipRect];
}

- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extendSelection {
    [super selectRowIndexes:indexes byExtendingSelection:extendSelection];
    [self setNeedsDisplay:YES];
}

- (void)deselectRow:(int)row {
    [super deselectRow:row];
    [self setNeedsDisplay:YES];
}

- (void)removeTrackingRects {
    if (trackingRects) {
        CFIndex idx = CFArrayGetCount(trackingRects);
        while(idx--)
            [self removeTrackingRect:(NSTrackingRectTag)CFArrayGetValueAtIndex(trackingRects, idx)];
        CFArrayRemoveAllValues(trackingRects);
    }
}

- (void)rebuildTrackingRects {
    if ([[self delegate] respondsToSelector:@selector(outlineView:shouldTrackTableColumn:item:)] == NO)
        return;
    
    if (trackingRects == nil)
        trackingRects = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
    else
        [self removeTrackingRects];
    
    if ([self window]) {
        NSRange rowRange = [self rowsInRect:[self visibleRect]];
        NSRange columnRange = [self columnsInRect:[self visibleRect]];
        unsigned int row, column;
        NSTableColumn *tableColumn;
        int userData;
        NSTrackingRectTag tag;
        
        for (column = columnRange.location; column < NSMaxRange(columnRange); column++) {
            tableColumn = [[self tableColumns] objectAtIndex:column];
            for (row = rowRange.location; row < NSMaxRange(rowRange); row++) {
                if ([[self delegate] outlineView:self shouldTrackTableColumn:tableColumn item:[self itemAtRow:row]]) {
                    userData = row * [self numberOfColumns] + column;
                    tag = [self addTrackingRect:[self frameOfCellAtColumn:column row:row] owner:self userData:(void *)userData assumeInside:NO];
                    CFArrayAppendValue(trackingRects, (const void *)tag);
                }
            }
        }
    }
}

- (void)expandItem:(id)item expandChildren:(BOOL)collapseChildren {
    // NSOutlineView does not call resetCursorRect when expanding
    [super expandItem:item expandChildren:collapseChildren];
	[self rebuildTrackingRects];
}

- (void)collapseItem:(id)item collapseChildren:(BOOL)collapseChildren {
    // NSOutlineView does not call resetCursorRect when collapsing
    [super collapseItem:item collapseChildren:collapseChildren];
	[self rebuildTrackingRects];
}

- (void)reloadData{
    [super reloadData];
	[self rebuildTrackingRects];
}

- (void)resetCursorRects {
	[super resetCursorRects];
    [self rebuildTrackingRects];
}

- (void)setDataSource:(id)anObject {
	[super setDataSource:anObject];
	[self rebuildTrackingRects];
}

- (void)noteNumberOfRowsChanged {
	[super noteNumberOfRowsChanged];
	[self rebuildTrackingRects];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    if ([self window])
        [self removeTrackingRects];
}

- (void)viewDidMoveToWindow {
	if ([self window])
        [self rebuildTrackingRects];
}

- (void)mouseEntered:(NSEvent *)theEvent{
    if ([[self delegate] respondsToSelector:@selector(outlineView:mouseEnteredTableColumn:item:)]) {
        int userData = (int)[theEvent userData];
        int numCols = [self numberOfColumns];
		int column = userData % numCols;
		int row = userData / numCols;
        if (column != -1 && row != -1) {
            NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:column];
            [[self delegate] outlineView:self mouseEnteredTableColumn:tableColumn item:[self itemAtRow:row]];
        }
	}
}

- (void)mouseExited:(NSEvent *)theEvent{
    if ([[self delegate] respondsToSelector:@selector(outlineView:mouseExitedTableColumn:item:)]) {
        int userData = (int)[theEvent userData];
        int numCols = [self numberOfColumns];
		int column = userData % numCols;
		int row = userData / numCols;
        if (column != -1 && row != -1) {
            NSTableColumn *tableColumn = [[self tableColumns] objectAtIndex:column];
            [[self delegate] outlineView:self mouseExitedTableColumn:tableColumn item:[self itemAtRow:row]];
        }
	}
}

@end
