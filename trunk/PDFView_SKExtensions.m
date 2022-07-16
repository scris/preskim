//
//  PDFView_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 7/3/11.
/*
 This software is Copyright (c) 2011-2022
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

#import "PDFView_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"
#import "SKMainDocument.h"
#import "SKPDFSynchronizer.h"
#import "PDFPage_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "NSEvent_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "SKStringConstants.h"
#import "NSGraphics_SKExtensions.h"
#import "SKApplication.h"
#import "NSView_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSResponder_SKExtensions.h"


#if SDK_BEFORE(10_13)

typedef NS_ENUM(NSInteger, PDFDisplayDirection) {
    kPDFDisplayDirectionVertical = 0,
    kPDFDisplayDirectionHorizontal = 1,
};

@interface PDFView (SKHighSierraDeclarations)
- (CGFloat)minScaleFactor;
- (CGFloat)maxScaleFactor;
@property (nonatomic) PDFDisplayDirection displayDirection;
@property (nonatomic) NSEdgeInsets pageBreakMargins;
@end

#endif

@implementation PDFView (SKExtensions)

@dynamic physicalScaleFactor, scrollView, displayedPages, minimumScaleFactor, maximumScaleFactor, visibleContentRect, drawsActiveSelections;

static inline CGFloat physicalScaleFactorForView(NSView *view) {
    NSScreen *screen = [[view window] screen];
    NSDictionary *deviceDescription = [screen deviceDescription];
	CGDirectDisplayID displayID = (CGDirectDisplayID)[[deviceDescription objectForKey:@"NSScreenNumber"] unsignedIntValue];
	CGSize physicalSize = CGDisplayScreenSize(displayID);
    NSSize resolution = [[deviceDescription objectForKey:NSDeviceResolution] sizeValue];
    CGFloat backingScaleFactor = [screen backingScaleFactor];
	return CGSizeEqualToSize(physicalSize, CGSizeZero) ? 1.0 : (physicalSize.width * resolution.width) / (CGDisplayPixelsWide(displayID) * backingScaleFactor * 25.4f);
}

- (CGFloat)physicalScaleFactor {
    return [self scaleFactor] * physicalScaleFactorForView(self);
}

- (void)setPhysicalScaleFactor:(CGFloat)scale {
    [self setScaleFactor:scale / physicalScaleFactorForView(self)];
}

- (NSScrollView *)scrollView {
    // don't go through the documentView, because that may not exist,
    // e.g. in init or when the document is locked
    // also when -documentView is called from -initWithCoder: it may crash
    return [self descendantOfClass:[NSScrollView class]];
}

- (void)setNeedsDisplayInRect:(NSRect)rect ofPage:(PDFPage *)page {
    if ([self isPageAtIndexDisplayed:[page pageIndex]]) {
        // for some versions we need to dirty the documentView, otherwise it won't redisplay when scrolled out of view,
        // for 10.12 dirtying the documentView dioes not do anything
        NSView *view = RUNNING_BEFORE(10_12) ? [self documentView] : self;
        rect = NSIntegralRect([self convertRect:NSInsetRect(rect, -1.0, -1.0) fromPage:page]);
        rect = NSIntersectionRect([view bounds], [self convertRect:rect toView:view]);
        if (NSIsEmptyRect(rect) == NO)
            [view setNeedsDisplayInRect:rect];
    }
}

- (void)setNeedsDisplayForAnnotation:(PDFAnnotation *)annotation onPage:(PDFPage *)page {
    [self setNeedsDisplayInRect:[annotation displayRect] ofPage:page];
    [self annotationsChangedOnPage:page];
}

- (void)setNeedsDisplayForAnnotation:(PDFAnnotation *)annotation {
    [self setNeedsDisplayForAnnotation:annotation onPage:[annotation page]];
}

- (void)requiresDisplay {
    NSView *view = RUNNING_BEFORE(10_12) ? [self documentView] : self;
    [view setNeedsDisplay:YES];
}

- (void)doPdfsyncWithEvent:(NSEvent *)theEvent {
    // eat up mouseDragged/mouseUp events, so we won't get their event handlers
    while (YES) {
        if ([[[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask] type] == NSLeftMouseUp)
            break;
    }
    
    SKMainDocument *document = (SKMainDocument *)[[[self window] windowController] document];
    
    if ([document respondsToSelector:@selector(synchronizer)]) {
        
        NSPoint location = NSZeroPoint;
        PDFPage *page = [self pageAndPoint:&location forEvent:theEvent nearest:YES];
        NSUInteger pageIndex = [page pageIndex];
        PDFSelection *sel = [page selectionForLineAtPoint:location];
        NSRect rect = [sel hasCharacters] ? [sel boundsForPage:page] : NSMakeRect(location.x - 20.0, location.y - 5.0, 40.0, 10.0);
        
        [[document synchronizer] findFileAndLineForLocation:location inRect:rect pageBounds:[page boundsForBox:kPDFDisplayBoxMediaBox] atPageIndex:pageIndex];
    }
}

- (void)doDragWithEvent:(NSEvent *)theEvent {
    NSView *contentView = [[self scrollView] contentView];
	NSPoint startLocation = [theEvent locationInView:contentView];
	
    [[NSCursor closedHandCursor] push];
    
	while (YES) {
        
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        if ([theEvent type] == NSLeftMouseUp)
            break;
        
        // convert takes flipping and scaling into account
        NSPoint	newLocation = [theEvent locationInView:contentView];
        NSPoint	point = SKAddPoints([contentView bounds].origin, SKSubstractPoints(startLocation, newLocation));
        
        [contentView scrollPoint:point];
	}
    
    [NSCursor pop];
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(mouseMoved:) withObject:theEvent afterDelay:0];
}

#pragma mark NSDraggingSource protocol

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return context == NSDraggingContextWithinApplication ? NSDragOperationNone : NSDragOperationCopy;
}

- (BOOL)doDragTextWithEvent:(NSEvent *)theEvent {
    if ([[self currentSelection] hasCharacters] == NO)
        return NO;
    
    NSPoint point;
    PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:NO];
    
    if (page == nil || NSPointInRect(point, [[self currentSelection] boundsForPage:page]) == NO || [NSApp willDragMouse] == NO)
        return NO;
    
    NSImage *dragImage = [NSImage bitmapImageWithSize:NSMakeSize(32.0, 32.0) scale:[self backingScale] drawingHandler:^(NSRect rect){
        [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kClippingTextType)] drawInRect:rect fromRect:rect operation:NSCompositeCopy fraction:1.0 respectFlipped:YES hints:nil];
    }];
    
    NSRect dragFrame = SKRectFromCenterAndSize([theEvent locationInView:self], [dragImage size]);
    
    NSDraggingItem *dragItem = [[[NSDraggingItem alloc] initWithPasteboardWriter:[[self currentSelection] attributedString]] autorelease];
    [dragItem setDraggingFrame:dragFrame contents:dragImage];
    [self beginDraggingSessionWithItems:[NSArray arrayWithObjects:dragItem, nil] event:theEvent source:self];

    return YES;
}

- (PDFPage *)pageAndPoint:(NSPoint *)point forEvent:(NSEvent *)event nearest:(BOOL)nearest {
    NSPoint p = [event locationInView:self];
    PDFPage *page = [self pageForPoint:p nearest:nearest];
    if (page && point)
        *point = [self convertPoint:p toPage:page];
    return page;
}

- (NSUInteger)currentPageIndexAndPoint:(NSPoint *)point rotated:(BOOL *)rotated {
    PDFPage *page = [self currentPage];
    // don't use currentDestination, as that always gives the top-left of the page in non-continuous mode, rather than the visible area
    if (point) {
        NSPoint p = SKTopLeftPoint([self bounds]);
        p.y -= [[self scrollView] contentInsets].top;
        *point = [self convertPoint:p toPage:page];
    }
    if (rotated)
        *rotated = [page rotation] != [page intrinsicRotation];
    return [page pageIndex];
}

- (void)goToPageAtIndex:(NSUInteger)pageIndex point:(NSPoint)point {
    PDFPage *page = [[self document] pageAtIndex:pageIndex];
    PDFDestination *destination = [[PDFDestination alloc] initWithPage:page atPoint:point];
    [self goToDestination:destination];
    [destination release];
}

- (NSRange)displayedPageIndexRange {
    NSUInteger pageCount = [[self document] pageCount];
    PDFDisplayMode displayMode = [self displayMode];
    NSRange range = NSMakeRange(0, pageCount);
    if (pageCount > 0 && (displayMode & kPDFDisplaySinglePageContinuous) == 0) {
        range = NSMakeRange([[self currentPage] pageIndex], 1);
        if (displayMode == kPDFDisplayTwoUp) {
            if ([self displaysAsBook] == (BOOL)(range.location % 2)) {
                if (NSMaxRange(range) < pageCount)
                    range.length = 2;
            } else if (range.location > 0) {
                range.location -= 1;
                range.length = 2;
            }
        }
    }
    return range;
}

- (BOOL)isPageAtIndexDisplayed:(NSUInteger)pageIndex {
    return NSLocationInRange(pageIndex, [self displayedPageIndexRange]);
}

- (NSArray *)displayedPages {
    NSMutableArray *displayedPages = [NSMutableArray array];
    PDFDocument *pdfDoc = [self document];
    NSRange range = [self displayedPageIndexRange];
    NSUInteger i;
    for (i = range.location; i < NSMaxRange(range); i++)
        [displayedPages addObject:[pdfDoc pageAtIndex:i]];
    return displayedPages;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"

- (CGFloat)minimumScaleFactor {
    if ([self respondsToSelector:@selector(minScaleFactor)])
        return [self minScaleFactor];
    return 0.1;
}

- (NSRect)visibleContentRect {
    NSScrollView *scrollView = [self scrollView];
    NSView *clipView = [scrollView contentView];
    NSRect rect = [self convertRect:[clipView bounds] fromView:clipView];
    rect.size.height -= [scrollView contentInsets].top;
    return rect;
}

- (CGFloat)maximumScaleFactor {
    if ([self respondsToSelector:@selector(maxScaleFactor)])
        return [self maxScaleFactor];
    return 20.0;
}

#pragma clang diagnostic pop

- (CGFloat)unitWidthOnPage:(PDFPage *)page {
    return NSWidth([self convertRect:NSMakeRect(0.0, 0.0, 1.0, 1.0) toPage:page]);
}

- (NSRect)backingAlignedRect:(NSRect)rect onPage:(PDFPage *)page {
    // this is called from drawing methods that on 10.12+ may run on a background thread
    return RUNNING_AFTER(10_11) ? rect : [self convertRect:[self backingAlignedRect:[self convertRect:rect fromPage:page] options:NSAlignAllEdgesOutward] toPage:page];
}

- (BOOL)drawsActiveSelections {
    if (RUNNING_AFTER(10_14))
        return [[self window] isKeyWindow];
    else if (RUNNING_AFTER(10_11))
        return YES;
    else
        return ([[self window] isKeyWindow] && [[[self window] firstResponder] isDescendantOf:self]);
}

static NSColor *defaultBackgroundColor(NSString *backgroundColorKey, NSString *darkBackgroundColorKey) {
    NSColor *color = nil;
    if (SKHasDarkAppearance(NSApp))
        color = [[NSUserDefaults standardUserDefaults] colorForKey:darkBackgroundColorKey];
    if (color == nil)
        color = [[NSUserDefaults standardUserDefaults] colorForKey:backgroundColorKey];
    return color;
}

+ (NSColor *)defaultBackgroundColor {
    return defaultBackgroundColor(SKBackgroundColorKey, SKDarkBackgroundColorKey);
}

+ (NSColor *)defaultFullScreenBackgroundColor {
    return defaultBackgroundColor(SKFullScreenBackgroundColorKey, SKDarkFullScreenBackgroundColorKey);
}

- (BOOL)accessibilityPerformShowMenu {
    NSPoint point = SKCenterPoint([self visibleContentRect]);
    NSEvent *event = [NSEvent mouseEventWithType:NSRightMouseDown
                                        location:[self convertPoint:point toView:nil]
                                   modifierFlags:0
                                       timestamp:0
                                    windowNumber:[[self window] windowNumber]
                                         context:nil
                                     eventNumber:0
                                      clickCount:1
                                        pressure:0.0];
    NSMenu *menu = [self menuForEvent:event];
    return [menu popUpMenuPositioningItem:nil atLocation:point inView:self];
}

@end
