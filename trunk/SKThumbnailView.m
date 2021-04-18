//
//  SKThumbnailView.m
//  Skim
//
//  Created by Christiaan Hofman on 17/02/2020.
/*
This software is Copyright (c) 2020-2021
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

#import "SKThumbnailView.h"
#import "SKThumbnail.h"
#import "SKApplication.h"
#import "SKOverviewView.h"
#import "NSView_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSBitmapImageRep_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import <Quartz/Quartz.h>
#import "PDFPage_SKExtensions.h"

#define MARGIN 8.0
#define TEXT_MARGIN 4.0
#define TEXT_SPACE 32.0
#define SELECTION_MARGIN 6.0
#define IMAGE_SEL_RADIUS 8.0
#define TEXT_SEL_RADIUS 4.0

#define IMAGE_KEY @"image"

#define HIGHLIGHT_ID @"highlight"
#define MARK_ID @"mark"

static char SKThumbnailViewThumbnailObservationContext;

@implementation SKThumbnailView

@synthesize selected, thumbnail, backgroundStyle, highlightLevel, controller;
@dynamic marked;

- (void)commonInit {
    NSRect bounds = [self bounds];
    NSRect rect = NSOffsetRect(NSInsetRect(bounds, MARGIN, MARGIN + 0.5 * TEXT_SPACE), 0.0, 0.5 * TEXT_SPACE);
    imageView = [[NSImageView alloc] initWithFrame:rect];
    [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [imageView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self addSubview:imageView];
    
    labelView = [[NSTextField alloc] init];
    [labelView setBezeled:NO];
    [labelView setBordered:NO];
    [labelView setDrawsBackground:NO];
    [labelView setEditable:NO];
    [labelView setSelectable:NO];
    [labelView setAlignment:NSCenterTextAlignment];
    [labelView setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
    rect = NSInsetRect(bounds, TEXT_MARGIN, TEXT_SPACE);
    rect.size.height = [[labelView cell] cellSize].height;
    rect.origin.y -= NSHeight(rect);
    [labelView setFrame:rect];
    [self addSubview:labelView];
}

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    @try { [thumbnail removeObserver:self forKeyPath:IMAGE_KEY]; }
    @catch (id e) {}
    controller = nil;
    SKDESTROY(imageView);
    SKDESTROY(labelView);
    SKDESTROY(markView);
    SKDESTROY(imageHighlightView);
    SKDESTROY(labelHighlightView);
    SKDESTROY(thumbnail);
    [super dealloc];
}

+ (NSSize)sizeForImageSize:(NSSize)size {
    return NSMakeSize(size.width + 2.0 * MARGIN, size.height + 2.0 * MARGIN + TEXT_SPACE);
}

#pragma mark Updating

- (void)updateImage {
    if ([self window] && NSIsEmptyRect([imageView visibleRect]) == NO)
        [imageView setImage:[thumbnail image]];
    else
        [imageView setImage:nil];
}

- (void)updateBackgroundStyle {
    NSBackgroundStyle style = [self backgroundStyle];
    if ([self isSelected] && ([[self window] isKeyWindow] || [[self window] isMainWindow]))
        style = NSBackgroundStyleDark;
    if ([[labelView cell] backgroundStyle] != style) {
        [[labelView cell] setBackgroundStyle:style];
        [labelView setNeedsDisplay:YES];
    }
}

- (NSVisualEffectView *)newHighlightView {
    SKOverviewView *overviewView = (SKOverviewView *)[[self controller] collectionView];
    NSVisualEffectView *highlightView = [overviewView newViewWithIdentifier:HIGHLIGHT_ID];
    if (highlightView == nil) {
        highlightView = [[NSVisualEffectView alloc] init];
        [highlightView setIdentifier:HIGHLIGHT_ID];
        [highlightView setMaterial:NSVisualEffectMaterialSelection];
    }
    return highlightView;
}

- (void)removeView:(id)view {
    [view removeFromSuperview];
    [(SKOverviewView *)[[self controller] collectionView] cacheView:view];
}

- (void)updateImageHighlightMask:(NSNotification *)note {
    NSRect rect = [imageHighlightView bounds];
    NSImage *mask = [[NSImage alloc] initWithSize:rect.size];
    [mask lockFocus];
    [[NSColor colorWithGenericGamma22White:0.0 alpha:1.0] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:IMAGE_SEL_RADIUS yRadius:IMAGE_SEL_RADIUS] fill];
    [mask unlockFocus];
    [imageHighlightView setMaskImage:mask];
    [mask release];
}

- (void)updateImageHighlight {
    if (RUNNING_AFTER(10_15)) {
        if ([self isSelected]) {
            if (imageHighlightView == nil) {
                imageHighlightView = [self newHighlightView];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
                [imageHighlightView setEmphasized:NO];
#pragma clang diagnostic pop
                [imageHighlightView setFrame:NSInsetRect([imageView frame], -SELECTION_MARGIN, -SELECTION_MARGIN)];
                [imageHighlightView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
                [self addSubview:imageHighlightView positioned:NSWindowBelow relativeTo:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateImageHighlightMask:) name:NSViewFrameDidChangeNotification object:imageHighlightView];
            }
            [self updateImageHighlightMask:nil];
        } else if (imageHighlightView) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:imageHighlightView];
            [self removeView:imageHighlightView];
            SKDESTROY(imageHighlightView);
        }
    } else {
        [self setNeedsDisplayInRect:NSInsetRect([imageView frame], -SELECTION_MARGIN, -SELECTION_MARGIN)];
    }
}

- (void)updateLabelHighlightMask:(NSNotification *)note {
    NSRect rect = [labelHighlightView bounds];
    CGFloat inset = fmax(0.0, floor(0.5 * (NSWidth(rect) - [[labelView cell] cellSize].width)));
    CGFloat alpha = [self isSelected] ? 1.0 : 0.05 * [self highlightLevel];
    NSImage *mask = [[NSImage alloc] initWithSize:rect.size];
    [mask lockFocus];
    [[NSColor colorWithGenericGamma22White:0.0 alpha:alpha] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, inset, 0.0) xRadius:TEXT_SEL_RADIUS yRadius:TEXT_SEL_RADIUS] fill];
    [mask unlockFocus];
    [labelHighlightView setMaskImage:mask];
    [mask release];
}

- (void)updateLabelHighlight {
    if (RUNNING_AFTER(10_15)) {
        if ([self isSelected] || [self highlightLevel] > 0) {
            if (labelHighlightView == nil) {
                labelHighlightView = [self newHighlightView];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
                [labelHighlightView setEmphasized:[[self window] isKeyWindow] || [[self window] isMainWindow]];
#pragma clang diagnostic pop
                [labelHighlightView setFrame:[labelView frame]];
                [labelHighlightView setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
                [self addSubview:labelHighlightView positioned:NSWindowBelow relativeTo:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLabelHighlightMask:) name:NSViewFrameDidChangeNotification object:labelHighlightView];
            }
            [self updateLabelHighlightMask:nil];
        } else if (labelHighlightView) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:labelHighlightView];
            [self removeView:labelHighlightView];
            SKDESTROY(labelHighlightView);
        }
    } else {
        [self setNeedsDisplayInRect:[labelView frame]];
    }
}

#pragma mark Accessors

- (void)setThumbnail:(SKThumbnail *)newThumbnail {
    if (thumbnail != newThumbnail) {
        [thumbnail removeObserver:self forKeyPath:IMAGE_KEY];
        [thumbnail release];
        thumbnail = [newThumbnail retain];
        [labelView setObjectValue:[thumbnail label]];
        [self updateImage];
        [thumbnail addObserver:self forKeyPath:IMAGE_KEY options:0 context:&SKThumbnailViewThumbnailObservationContext];
        if ([self isSelected] || [self highlightLevel] > 0)
            [self updateLabelHighlight];
    }
}

- (void)setSelected:(BOOL)newSelected {
    if (selected != newSelected) {
        selected = newSelected;
        [self updateBackgroundStyle];
        [self updateImageHighlight];
        [self updateLabelHighlight];
    }
}

- (void)setBackgroundStyle:(NSBackgroundStyle)newBackgroundStyle {
    if (backgroundStyle != newBackgroundStyle) {
        backgroundStyle = newBackgroundStyle;
        [self updateBackgroundStyle];
        if ([self isSelected])
            [self setNeedsDisplay:YES];
        else if ([self highlightLevel] > 0)
            [self setNeedsDisplayInRect:[labelView frame]];
    }
}

- (void)setHighlightLevel:(NSInteger)newHighlightLevel {
    if (newHighlightLevel != highlightLevel) {
        highlightLevel = newHighlightLevel;
        [self updateLabelHighlight];
    }
}

- (BOOL)isMarked {
    return (markView != nil);
}

- (void)setMarked:(BOOL)newMarked {
    if (newMarked) {
        if (markView == nil) {
            NSRect rect = [self bounds];
            rect = NSMakeRect(NSMaxX(rect) - MARGIN, NSMaxY(rect) - MARGIN - 16.0, 6.0, 10.0);
            markView = [(SKOverviewView *)[[self controller] collectionView] newViewWithIdentifier:MARK_ID];
            if (markView == nil) {
                markView = [[NSImageView alloc] initWithFrame:rect];
                [markView setIdentifier:MARK_ID];
                [markView setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
                static NSImage *markImage = nil;
                if (markImage == nil) {
                    markImage = [[NSImage alloc] initWithSize:rect.size];
                    [markImage lockFocus];
                    [[NSColor colorWithSRGBRed:0.654 green:0.166 blue:0.392 alpha:1.0] setFill];
                    NSBezierPath *path = [NSBezierPath bezierPath];
                    [path moveToPoint:NSMakePoint(0.0, 0.0)];
                    [path lineToPoint:NSMakePoint(0.5 * NSWidth(rect), 0.5 * NSWidth(rect))];
                    [path lineToPoint:NSMakePoint(NSWidth(rect), 0.0)];
                    [path lineToPoint:NSMakePoint(NSWidth(rect), NSHeight(rect))];
                    [path lineToPoint:NSMakePoint(0.0, NSHeight(rect))];
                    [path closePath];
                    [path fill];
                    [markImage unlockFocus];
                }
                [markView setImage:markImage];
            }
            [markView setFrame:rect];
            [self addSubview:markView positioned:NSWindowAbove relativeTo:imageView];
        }
    } else if (markView) {
        [self removeView:markView];
        SKDESTROY(markView);
    }
}

#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect {
    if (RUNNING_AFTER(10_15))
        return;
    if ([self isSelected]) {
        NSRect rect = NSInsetRect([imageView frame], -SELECTION_MARGIN, -SELECTION_MARGIN);
        if (NSIntersectsRect(dirtyRect, rect)) {
            [NSGraphicsContext saveGraphicsState];
            if ([self backgroundStyle] == NSBackgroundStyleDark)
                [[NSColor darkGrayColor] setFill];
            else
                [[NSColor secondarySelectedControlColor] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:IMAGE_SEL_RADIUS yRadius:IMAGE_SEL_RADIUS] fill];
            [NSGraphicsContext restoreGraphicsState];
        }
        
        rect = [labelView frame];
        CGFloat inset = floor(0.5 * (NSWidth(rect) - [[labelView cell] cellSize].width));
        rect = NSInsetRect(rect, inset, 0.0);
        if (NSIntersectsRect(dirtyRect, rect)) {
            [NSGraphicsContext saveGraphicsState];
            if ([[self window] isKeyWindow] || [[self window] isMainWindow])
                [[NSColor alternateSelectedControlColor] setFill];
            else if ([self backgroundStyle] == NSBackgroundStyleDark)
                [[NSColor darkGrayColor] setFill];
            else
                [[NSColor secondarySelectedControlColor] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:TEXT_SEL_RADIUS yRadius:TEXT_SEL_RADIUS] fill];
            [NSGraphicsContext restoreGraphicsState];
        }
    } else if ([self highlightLevel] > 0) {
        NSRect rect = [labelView frame];
        CGFloat inset = fmax(0.0, floor(0.5 * (NSWidth(rect) - [[labelView cell] cellSize].width)));
        rect = NSInsetRect(rect, inset, 0.0);
        if (NSIntersectsRect(rect, dirtyRect)) {
            NSColor *color;
            if ([[self window] isKeyWindow] || [[self window] isMainWindow])
                color = [NSColor alternateSelectedControlColor];
            else if ([self backgroundStyle] == NSBackgroundStyleDark)
                color = [NSColor darkGrayColor];
            else
                color = [NSColor secondarySelectedControlColor];
            [NSGraphicsContext saveGraphicsState];
            [[color colorWithAlphaComponent:fmin(1.0, 0.1 * [self highlightLevel])] setStroke];
            [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 0.5, 0.5) xRadius:TEXT_SEL_RADIUS - 0.5 yRadius:TEXT_SEL_RADIUS - 0.5] stroke];
            [NSGraphicsContext restoreGraphicsState];
        }
    }
}

#pragma mark State change observation

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == &SKThumbnailViewThumbnailObservationContext)
        [self updateImage];
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)handleKeyOrMainStateChangedNotification:(NSNotification *)note {
    if ([self isSelected] || [self highlightLevel] > 0) {
        [self updateBackgroundStyle];
        if (RUNNING_AFTER(10_15))
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
            [labelHighlightView setEmphasized:[[self window] isKeyWindow] || [[self window] isMainWindow]];
#pragma clang diagnostic pop
        else
            [self setNeedsDisplayInRect:[labelView frame]];
    }
}

- (void)handleScrollBoundsChangedNotification:(NSNotification *)note {
    if ([imageView image] == nil)
        [self updateImage];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSWindow *oldWindow = [self window];
    if (oldWindow) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:NSWindowDidBecomeMainNotification object:oldWindow];
        [nc removeObserver:self name:NSWindowDidResignMainNotification object:oldWindow];
        [nc removeObserver:self name:NSWindowDidBecomeKeyNotification object:oldWindow];
        [nc removeObserver:self name:NSWindowDidResignKeyNotification object:oldWindow];
        NSView *clipView = [[self enclosingScrollView] contentView];
        if (clipView)
            [nc removeObserver:self name:NSViewBoundsDidChangeNotification object:clipView];
    }
    if (newWindow) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidBecomeMainNotification object:newWindow];
        [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidResignMainNotification object:newWindow];
        [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidBecomeKeyNotification object:newWindow];
        [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidResignKeyNotification object:newWindow];
    }
    [super viewWillMoveToWindow:newWindow];
}

- (void)viewDidMoveToWindow {
    if ([self window]) {
        NSView *clipView = [[self enclosingScrollView] contentView];
        if (clipView) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScrollBoundsChangedNotification:) name:NSViewBoundsDidChangeNotification object:clipView];
            [self handleScrollBoundsChangedNotification:nil];
        }
        [self handleKeyOrMainStateChangedNotification:nil];
    }
    [super viewDidMoveToWindow];
}

#pragma mark Event handling

- (void)mouseDown:(NSEvent *)theEvent {
    if ([NSApp willDragMouse]) {
        
        id<NSPasteboardWriting> item = [[[self thumbnail] page] filePromise];
        
        if (item) {
            NSRect rect = [imageView frame];
            NSBitmapImageRep *imageRep = [imageView bitmapImageRepCachingDisplayInRect:[imageView bounds]];
            NSImage *dragImage = [[[NSImage alloc] initWithSize:rect.size] autorelease];
            [dragImage addRepresentation:imageRep];
            
            NSDraggingItem *dragItem = [[[NSDraggingItem alloc] initWithPasteboardWriter:item] autorelease];
            [dragItem setDraggingFrame:rect contents:dragImage];
            [self beginDraggingSessionWithItems:[NSArray arrayWithObjects:dragItem, nil] event:theEvent source:self];
        }
        
    } else {
        
        [super mouseDown:theEvent];
        
    }
}

- (void)copyPage:(id)sender {
    [[[self thumbnail] page] writeToClipboard];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    PDFPage *page = [[self thumbnail] page];
    NSMenu *menu = nil;
    if (page && [[page document] isLocked] == NO) {
        menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
        [menu addItemWithTitle:NSLocalizedString(@"Copy", @"Menu item title") action:@selector(copyPage:) target:self];
    }
    return menu;
}

#pragma mark NSDraggingSource protocol

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return context == NSDraggingContextWithinApplication ? NSDragOperationNone : NSDragOperationEvery;
}

- (void)draggingSession:(NSDraggingSession *)session
           endedAtPoint:(NSPoint)screenPoint
              operation:(NSDragOperation)operation {
    [[session draggingPasteboard] clearContents];
}

@end
