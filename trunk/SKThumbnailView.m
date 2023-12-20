//
//  SKThumbnailView.m
//  Skim
//
//  Created by Christiaan Hofman on 17/02/2020.
/*
This software is Copyright (c) 2020-2023
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
#import "NSColor_SKExtensions.h"
#import "SKThumbnailImageView.h"
#import "NSPasteboard_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"

#define MARGIN 8.0
#define TEXT_MARGIN 4.0
#define TEXT_SPACE 24.0
#define SELECTION_MARGIN 6.0
#define IMAGE_SEL_RADIUS 8.0
#define TEXT_SEL_RADIUS 4.0
#define MARK_OFFSET 16.0

#define IMAGE_KEY @"image"
#define LABEL_KEY @"label"

#define HIGHLIGHT_ID @"highlight"
#define MARK_ID @"mark"

#define SKPasteboardTypeDummy @"net.sourceforge.skim-app.pasteboard.dummy"

static char SKThumbnailViewThumbnailObservationContext;

@implementation SKThumbnailView

@synthesize selected, menuHighlighted, thumbnail, backgroundStyle, highlightLevel, controller;
@dynamic marked;

- (void)commonInit {
    NSRect bounds = [self bounds];
    CGFloat textSpace = TEXT_SPACE;
    NSRect rect = NSOffsetRect(NSInsetRect(bounds, MARGIN, MARGIN + 0.5 * textSpace), 0.0, 0.5 * textSpace);
    imageView = [[SKThumbnailImageView alloc] initWithFrame:rect];
    [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [imageView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self addSubview:imageView];
    
    labelView = [[NSTextField alloc] init];
    [labelView setBezeled:NO];
    [labelView setBordered:NO];
    [labelView setDrawsBackground:NO];
    [labelView setEditable:NO];
    [labelView setSelectable:NO];
    [labelView setAlignment:NSTextAlignmentCenter];
    [labelView setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
    rect = NSInsetRect(bounds, TEXT_MARGIN, textSpace);
    rect.size.height = [[labelView cell] cellSize].height;
    rect.origin.y -= NSHeight(rect);
    [labelView setFrame:rect];
    [self addSubview:labelView];
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [[[self subviews] copy] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    @try {
        [thumbnail removeObserver:self forKeyPath:IMAGE_KEY context:&SKThumbnailViewThumbnailObservationContext];
        [thumbnail removeObserver:self forKeyPath:LABEL_KEY context:&SKThumbnailViewThumbnailObservationContext];
    }
    @catch (id e) {}
}

+ (NSSize)sizeForImageSize:(NSSize)size {
    return NSMakeSize(size.width + 2.0 * MARGIN, size.height + 2.0 * MARGIN + TEXT_SPACE);
}

#pragma mark Updating

- (void)updateBackgroundStyle {
    NSBackgroundStyle style = [self backgroundStyle];
    if ([self isSelected] && [[self window] isKeyWindow])
        style = NSBackgroundStyleDark;
    if ([[labelView cell] backgroundStyle] != style) {
        [[labelView cell] setBackgroundStyle:style];
        [labelView setNeedsDisplay:YES];
    }
}

- (NSVisualEffectView *)newHighlightView {
    NSVisualEffectView *highlightView = [[self collectionView] newViewWithIdentifier:HIGHLIGHT_ID];
    if (highlightView == nil) {
        highlightView = [[NSVisualEffectView alloc] init];
        [highlightView setIdentifier:HIGHLIGHT_ID];
        [highlightView setMaterial:NSVisualEffectMaterialSelection];
    }
    return highlightView;
}

- (NSImageView *)newMarkView {
    NSImageView *view = [[self collectionView] newViewWithIdentifier:MARK_ID];
    if (view == nil) {
        NSImage *markImage = [NSImage markImage];
        NSRect rect = NSZeroRect;
        rect.size = markImage.size;
        view = [[NSImageView alloc] initWithFrame:rect];
        [view setIdentifier:MARK_ID];
        [view setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
        [view setImage:markImage];
    }
    return view;
}

- (void)removeView:(id)view {
    [view removeFromSuperview];
    [[self collectionView] cacheView:view];
}

- (void)updateImageHighlightMask:(NSNotification *)note {
    NSRect rect = [imageHighlightView bounds];
    NSImage *mask = [[NSImage alloc] initWithSize:rect.size];
    if (NSIsEmptyRect(rect) == NO) {
        [mask lockFocus];
        [[NSColor colorWithGenericGamma22White:0.0 alpha:1.0] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:IMAGE_SEL_RADIUS yRadius:IMAGE_SEL_RADIUS] fill];
        [mask unlockFocus];
    }
    [imageHighlightView setMaskImage:mask];
}

- (void)updateImageHighlight {
    if (@available(macOS 11.0, *)) {
        if ([self isSelected] || [self isMenuHighlighted]) {
            if (imageHighlightView == nil) {
                imageHighlightView = [self newHighlightView];
                [imageHighlightView setFrame:NSInsetRect([imageView frame], -SELECTION_MARGIN, -SELECTION_MARGIN)];
                [imageHighlightView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
                [self addSubview:imageHighlightView positioned:NSWindowBelow relativeTo:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateImageHighlightMask:) name:NSViewFrameDidChangeNotification object:imageHighlightView];
            }
            [imageHighlightView setEmphasized:[self isMenuHighlighted]];
            [self updateImageHighlightMask:nil];
        } else if (imageHighlightView) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:imageHighlightView];
            [self removeView:imageHighlightView];
            imageHighlightView = nil;
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
    if (NSIsEmptyRect(rect) == NO) {
        [mask lockFocus];
        [[NSColor colorWithGenericGamma22White:0.0 alpha:alpha] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, inset, 0.0) xRadius:TEXT_SEL_RADIUS yRadius:TEXT_SEL_RADIUS] fill];
        [mask unlockFocus];
    }
    [labelHighlightView setMaskImage:mask];
}

- (void)updateLabelHighlight {
    if (@available(macOS 11.0, *)) {
        if ([self isSelected] || [self highlightLevel] > 0) {
            if (labelHighlightView == nil) {
                labelHighlightView = [self newHighlightView];
                [labelHighlightView setEmphasized:[[self window] isKeyWindow]];
                [labelHighlightView setFrame:[labelView frame]];
                [labelHighlightView setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
                [self addSubview:labelHighlightView positioned:NSWindowBelow relativeTo:nil];
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLabelHighlightMask:) name:NSViewFrameDidChangeNotification object:labelHighlightView];
            }
            [self updateLabelHighlightMask:nil];
        } else if (labelHighlightView) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:labelHighlightView];
            [self removeView:labelHighlightView];
            labelHighlightView = nil;
        }
    } else {
        [self setNeedsDisplayInRect:[labelView frame]];
    }
}

#pragma mark Accessors

- (void)setThumbnail:(SKThumbnail *)newThumbnail {
    if (thumbnail != newThumbnail) {
        [thumbnail removeObserver:self forKeyPath:IMAGE_KEY context:&SKThumbnailViewThumbnailObservationContext];
        [thumbnail removeObserver:self forKeyPath:LABEL_KEY context:&SKThumbnailViewThumbnailObservationContext];
        thumbnail = newThumbnail;
        [labelView setObjectValue:[thumbnail label]];
        [thumbnail addObserver:self forKeyPath:IMAGE_KEY options:NSKeyValueObservingOptionInitial context:&SKThumbnailViewThumbnailObservationContext];
        [thumbnail addObserver:self forKeyPath:LABEL_KEY options:NSKeyValueObservingOptionInitial context:&SKThumbnailViewThumbnailObservationContext];
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

- (void)setMenuHighlighted:(BOOL)newMenuHighlighted {
    if (menuHighlighted != newMenuHighlighted) {
        menuHighlighted = newMenuHighlighted;
        [self updateImageHighlight];
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
            markView = [self newMarkView];
            NSRect bounds = [self bounds];
            [markView setFrameOrigin:NSMakePoint(NSMaxX(bounds) - MARGIN, NSMaxY(bounds) - MARGIN - MARK_OFFSET)];
            [self addSubview:markView positioned:NSWindowAbove relativeTo:imageView];
        }
    } else if (markView) {
        [self removeView:markView];
        markView = nil;
    }
}

- (SKOverviewView *)collectionView {
    return (SKOverviewView *)[[self controller] collectionView];
}

#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect {
    if (@available(macOS 11.0, *))
        return;
    
    if ([self isSelected] || [self isMenuHighlighted]) {
        NSRect rect = NSInsetRect([imageView frame], -SELECTION_MARGIN, -SELECTION_MARGIN);
        if (NSIntersectsRect(dirtyRect, rect)) {
            [NSGraphicsContext saveGraphicsState];
            if ([self isMenuHighlighted])
                [[NSColor alternateSelectedControlColor] setFill];
            else if ([self backgroundStyle] == NSBackgroundStyleDark)
                [[NSColor darkGrayColor] setFill];
            else
                [[NSColor secondarySelectedControlColor] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:IMAGE_SEL_RADIUS yRadius:IMAGE_SEL_RADIUS] fill];
            [NSGraphicsContext restoreGraphicsState];
        }
    }
    
    if ([self isSelected] || [self highlightLevel] > 0) {
        NSRect rect = [labelView frame];
        CGFloat inset = floor(0.5 * (NSWidth(rect) - [[labelView cell] cellSize].width));
        rect = NSInsetRect(rect, inset, 0.0);
        if (NSIntersectsRect(dirtyRect, rect)) {
            NSColor *color;
            if ([[self window] isKeyWindow])
                color = [NSColor alternateSelectedControlColor];
            else if ([self backgroundStyle] == NSBackgroundStyleDark)
                color = [NSColor darkGrayColor];
            else
                color = [NSColor secondarySelectedControlColor];
            if ([self isSelected] == NO)
                color = [color colorWithAlphaComponent:fmin(1.0, 0.05 * [self highlightLevel])];
            [NSGraphicsContext saveGraphicsState];
            [color setFill];
            [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:TEXT_SEL_RADIUS yRadius:TEXT_SEL_RADIUS] fill];
            [NSGraphicsContext restoreGraphicsState];
        }
    }
}

#pragma mark State change observation

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == &SKThumbnailViewThumbnailObservationContext) {
        if ([keyPath isEqualToString:IMAGE_KEY]) {
            if ([self window] && NSIsEmptyRect([imageView visibleRect]) == NO)
                [imageView setImage:[thumbnail image]];
            else
                [imageView setImage:nil];
        } else if ([keyPath isEqualToString:LABEL_KEY]) {
            [labelView setObjectValue:[thumbnail label]];
            if ([self isSelected] || [self highlightLevel] > 0) {
                if (@available(macOS 11.0, *))
                    [self updateLabelHighlightMask:nil];
                else
                    [self setNeedsDisplayInRect:NSInsetRect([imageView frame], -SELECTION_MARGIN, -SELECTION_MARGIN)];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)handleKeyStateChangedNotification:(NSNotification *)note {
    if ([self isSelected] || [self highlightLevel] > 0) {
        [self updateBackgroundStyle];
        if (@available(macOS 11.0, *))
            [labelHighlightView setEmphasized:[[self window] isKeyWindow]];
        else
            [self setNeedsDisplayInRect:[labelView frame]];
    }
}

- (void)handleScrollBoundsChangedNotification:(NSNotification *)note {
    if ([imageView image] == nil && [self window] && NSIsEmptyRect([imageView visibleRect]) == NO)
        [imageView setImage:[thumbnail image]];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSWindow *oldWindow = [self window];
    if (oldWindow) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:NSWindowDidBecomeKeyNotification object:oldWindow];
        [nc removeObserver:self name:NSWindowDidResignKeyNotification object:oldWindow];
        NSView *clipView = [[self enclosingScrollView] contentView];
        if (clipView)
            [nc removeObserver:self name:NSViewBoundsDidChangeNotification object:clipView];
    }
    if (newWindow) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(handleKeyStateChangedNotification:) name:NSWindowDidBecomeKeyNotification object:newWindow];
        [nc addObserver:self selector:@selector(handleKeyStateChangedNotification:) name:NSWindowDidResignKeyNotification object:newWindow];
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
        [self handleKeyStateChangedNotification:nil];
    }
    [super viewDidMoveToWindow];
}

#pragma mark Event handling

- (NSImage *)draggingImage {
    NSRect rect = [imageView bounds];
    NSImage *dragImage = [[NSImage alloc] initWithSize:rect.size];
    [dragImage addRepresentation:[imageView bitmapImageRepCachingDisplayInRect:rect]];
    return dragImage;
}

- (NSRect)draggingFrame {
    return [imageView frame];
}

- (void)mouseDown:(NSEvent *)theEvent {
    if ([NSApp willDragMouse]) {
        
        NSUInteger pageIndex = [[self thumbnail] pageIndex];
        NSCollectionView *collectionView = [self collectionView];
        NSIndexSet *selectionIndexes = [collectionView selectionIndexes];
        if ([selectionIndexes count] < 2 || [selectionIndexes containsIndex:pageIndex] == NO)
            selectionIndexes = nil;
        
        id<NSPasteboardWriting> item = [[[self thumbnail] page] filePromiseForPageIndexes:selectionIndexes];
        
        if (item) {
            
            NSMutableArray *dragItems = [NSMutableArray array];
            NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:item];
            __block BOOL selectLeaderIndex = NO;
            
            [dragItem setDraggingFrame:[self draggingFrame] contents:[self draggingImage]];
            if (selectionIndexes == nil) {
                [dragItems addObject:dragItem];
            } else {
                NSUInteger firstIndex = [selectionIndexes firstIndex];
                [selectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop){
                    if (idx == pageIndex) {
                        [dragItems addObject:dragItem];
                    } else {
                        NSPasteboardItem *dummyItem = [[NSPasteboardItem alloc] init];
                        [dummyItem setData:[NSData data] forType:SKPasteboardTypeDummy];
                        NSDraggingItem *dummyDragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:dummyItem];
                        NSRect rect;
                        SKThumbnailView *view = (SKThumbnailView *)[[collectionView itemAtIndexPath:[NSIndexPath indexPathForItem:idx inSection:0]] view];
                        if (view) {
                            rect = [self convertRect:[view draggingFrame] fromView:view];
                            if (idx == firstIndex)
                                selectLeaderIndex = YES;
                        } else {
                            rect = [self draggingFrame];
                        }
                        [dummyDragItem setDraggingFrame:rect contents:[view draggingImage]];
                        [dragItems addObject:dummyDragItem];
                    }
                }];
            }
            
            NSDraggingSession *session = [self beginDraggingSessionWithItems:dragItems event:theEvent source:self];
            [session setDraggingFormation:NSDraggingFormationStack];
            if (selectLeaderIndex)
                [session setDraggingLeaderIndex:0];
        }
        
    } else {
        
        [super mouseDown:theEvent];
        
    }
}

- (void)copy:(id)sender {
    PDFPage *page = [[self thumbnail] page];
    NSIndexSet *selectionIndexes = [[self collectionView] selectionIndexes];
    if ([selectionIndexes count] < 2 || [selectionIndexes containsIndex:[page pageIndex]] == NO)
        selectionIndexes = nil;
    [[[self thumbnail] page] writeToClipboardForPageIndexes:selectionIndexes];
}

- (void)copyURL:(id)sender {
    PDFPage *page = [[self thumbnail] page];
    NSIndexSet *selectionIndexes = [[self collectionView] selectionIndexes];
    if ([selectionIndexes count] < 2 || [selectionIndexes containsIndex:[page pageIndex]] == NO)
        selectionIndexes = nil;
    NSMutableArray *urls = [NSMutableArray array];
    NSMutableArray *names = [NSMutableArray array];
    NSString *name = [[[[self window] windowController] document] displayName];
    if (selectionIndexes) {
        [selectionIndexes enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop){
            PDFPage *aPage = [[page document] pageAtIndex:i];
            NSURL *url = [aPage skimURL];
            if (url) {
                [urls addObject:url];
                [names addObject:[name stringByAppendingFormat:@" (%@)", [NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), [aPage displayLabel]]]];
            }
        }];
    } else {
        NSURL *url = [page skimURL];
        if (url) {
            [urls addObject:url];
            [names addObject:name];
        }
    }
    if ([urls count]) {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard clearContents];
        [pboard writeURLs:urls names:names];
    }
}

- (void)applyMenuHighlighted:(BOOL)flag {
    NSCollectionView *collectionView = [self collectionView];
    NSIndexSet *selectionIndexes = [collectionView selectionIndexes];
    if ([selectionIndexes count] > 1 && [selectionIndexes containsIndex:[[[self thumbnail] page] pageIndex]]) {
        [selectionIndexes enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop){
            NSCollectionViewItem *item = [collectionView itemAtIndexPath:[NSIndexPath indexPathForItem:i inSection:0]];
            [(SKThumbnailView *)[item view] setMenuHighlighted:flag];
        }];
    } else {
        [self setMenuHighlighted:flag];
    }
}

- (void)handleMenuDidEndTracking:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSMenuDidEndTrackingNotification object:[notification object]];
    [self applyMenuHighlighted:NO];
}

- (void)willOpenMenu:(NSMenu *)menu
           withEvent:(NSEvent *)event {
    [self applyMenuHighlighted:YES];
}

- (void)didCloseMenu:(NSMenu *)menu
           withEvent:(NSEvent *)event {
    [self applyMenuHighlighted:NO];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    PDFPage *page = [[self thumbnail] page];
    NSMenu *menu = nil;
    if (page && [[page document] isLocked] == NO) {
        menu = [[NSMenu alloc] initWithTitle:@""];
        [menu addItemWithTitle:NSLocalizedString(@"Copy", @"Menu item title") action:@selector(copy:) target:self];
        [menu addItemWithTitle:NSLocalizedString(@"Copy URL", @"Menu item title") action:@selector(copyURL:) target:self];
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

#pragma mark Accessibility

- (NSString *)accessibilityLabel {
    return [NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), [thumbnail label]];
}

- (BOOL)isAccessibilitySelected {
    return [self isSelected];
}

- (BOOL)accessibilityPerformPress {
    [[self collectionView] setSelectionIndexes:[NSIndexSet indexSetWithIndex:[thumbnail pageIndex]]];
    return YES;
}

@end
