//
//  SKNoteTableRowView.m
//  Skim
//
//  Created by Christiaan Hofman on 22/04/2019.
/*
 This software is Copyright (c) 2019
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

#import "SKNoteTableRowView.h"
#import "NSGeometry_SKExtensions.h"
#import "SKNoteText.h"
#import "SKNoteOutlineView.h"

#define RESIZE_EDGE_HEIGHT 5.0

@implementation SKNoteTableRowView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (resizeIndicatorCell == nil) {
        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(7.0, 5.0)];
        [image lockFocus];
        [[NSColor colorWithGenericGamma22White:0.0 alpha:0.7] setStroke];
        [NSBezierPath strokeLineFromPoint:NSMakePoint(1.0, 3.5) toPoint:NSMakePoint(7.0, 3.5)];
        [NSBezierPath strokeLineFromPoint:NSMakePoint(3.0, 1.5) toPoint:NSMakePoint(5.0, 1.5)];
        [image unlockFocus];
        [image setTemplate:YES];
        
        resizeIndicatorCell = [[NSImageCell alloc] initImageCell:image];
        [resizeIndicatorCell setImageScaling:NSImageScaleNone];
        [resizeIndicatorCell setImageAlignment:NSImageAlignBottom];
    }
    
    [resizeIndicatorCell setBackgroundStyle:[self interiorBackgroundStyle]];
    [resizeIndicatorCell drawWithFrame:[self bounds] inView:self];
}

- (void)resetCursorRects {
    [self discardCursorRects];
    [super resetCursorRects];
    
    NSCursor *cursor = [NSCursor resizeUpDownCursor];
    NSTableView *ov = (id)[self superview];
    if ([ov isKindOfClass:[NSTableView class]] && [ov rowHeight] + [ov intercellSpacing].height >= NSHeight([self frame]))
            cursor = [NSCursor resizeDownCursor];
    
    [self addCursorRect:SKSliceRect([self bounds], RESIZE_EDGE_HEIGHT, [self isFlipped] ? NSMaxYEdge : NSMinYEdge) cursor:cursor];
}

@end


@implementation SKNoteTableCellView

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
}

@end
