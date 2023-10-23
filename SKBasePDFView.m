//
//  SKBasePDFView.m
//  Skim
//
//  Created by Christiaan Hofman on 03/10/2021.
/*
 This software is Copyright (c) 2021-2023
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

#import "SKBasePDFView.h"
#import "SKStringConstants.h"
#import "PDFView_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSUserDefaultsController_SKExtensions.h"
#import "NSEvent_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "PDFDestination_SKExtensions.h"

static char SKBasePDFViewDefaultsObservationContext;

// don't use the constant, which is only defined on 10.13+
#define kPDFDestinationUnspecifiedValue FLT_MAX

#if SDK_BEFORE(10_12)
@interface PDFView (SKSierraDeclarations)
- (void)drawPage:(PDFPage *)page toContext:(CGContextRef)context;
@end

@interface PDFAnnotation (SKSierraDeclarations)
- (void)drawWithBox:(PDFDisplayBox)box inContext:(CGContextRef)context;
@end
#endif

#if SDK_BEFORE(10_13)
typedef NS_ENUM(NSInteger, PDFDisplayDirection) {
    kPDFDisplayDirectionVertical = 0,
    kPDFDisplayDirectionHorizontal = 1,
};
@interface PDFView (SKHighSierraDeclarations)
@property (nonatomic) PDFDisplayDirection displayDirection;
@property (nonatomic) BOOL displaysRTL;
@property (nonatomic) NSEdgeInsets pageBreakMargins;
@end
#endif

#if SDK_BEFORE(10_13)
@interface PDFView (SKMojaveDeclarations)
@property (nonatomic, setter=enablePageShadows:) BOOL pageShadowsEnabled;
@end
#endif

@interface SKBasePDFView (BDSKPrivate)

- (void)handleScrollerStyleChangedNotification:(NSNotification *)notification;

@end

@implementation SKBasePDFView

#pragma mark Dark mode and color inversion

static inline NSArray *defaultKeysToObserve() {
    if (RUNNING_AFTER(10_13))
        return @[SKInvertColorsInDarkModeKey, SKSepiaToneKey, SKWhitePointKey];
    else
        return @[SKSepiaToneKey, SKWhitePointKey];
}

// make sure we don't use the same method name as a superclass or a subclass
- (void)commonBaseInitialization {
    if (RUNNING_AFTER(10_13)) {
        SKSetHasDefaultAppearance(self);
        SKSetHasLightAppearance([[self scrollView] contentView]);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
            SKSetHasLightAppearance([self scrollView]);
        
        if (RUNNING(10_14)) {
            [self handleScrollerStyleChangedNotification:nil];
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScrollerStyleChangedNotification:)
                                                         name:NSPreferredScrollerStyleDidChangeNotification object:nil];
        }
    }
    
    [[self scrollView] setContentFilters:SKColorEffectFilters()];
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeys:defaultKeysToObserve() context:&SKBasePDFViewDefaultsObservationContext];
}

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonBaseInitialization];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self commonBaseInitialization];
    }
    return self;
}

- (void)dealloc {
    @try { [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeys:defaultKeysToObserve() context:&SKBasePDFViewDefaultsObservationContext]; }
    @catch (id e) {}
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKBasePDFViewDefaultsObservationContext)
        [self colorFiltersDidChange];
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)colorFiltersDidChange {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey]) {
        SKSetHasLightAppearance([self scrollView]);
    } else {
        SKSetHasDefaultAppearance([self scrollView]);
    }
    [[self scrollView] setContentFilters:SKColorEffectFilters()];
}

- (void)viewDidChangeEffectiveAppearance {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    [super viewDidChangeEffectiveAppearance];
#pragma clang diagnostic pop
    [[self scrollView] setContentFilters:SKColorEffectFilters()];
}

- (void)handleScrollerStyleChangedNotification:(NSNotification *)notification {
    if ([NSScroller preferredScrollerStyle] == NSScrollerStyleLegacy) {
        SKSetHasDefaultAppearance([[self scrollView] verticalScroller]);
        SKSetHasDefaultAppearance([[self scrollView] horizontalScroller]);
    } else {
        SKSetHasLightAppearance([[self scrollView] verticalScroller]);
        SKSetHasLightAppearance([[self scrollView] horizontalScroller]);
    }
}

- (void)setDisplaysPageBreaks:(BOOL)pageBreaks {
    [super setDisplaysPageBreaks:pageBreaks];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if ([self respondsToSelector:@selector(enablePageShadows:)])
        [self enablePageShadows:pageBreaks];
#pragma clang diagnostic pop
}

#pragma mark Bug fixes

- (void)keyDown:(NSEvent *)theEvent {
    if (RUNNING_BEFORE(10_12)) {
        
        unichar eventChar = [theEvent firstCharacter];
        NSUInteger modifiers = [theEvent standardModifierFlags];
        
        if ((eventChar == SKSpaceCharacter) && ((modifiers & ~NSEventModifierFlagShift) == 0)) {
            eventChar = modifiers == NSEventModifierFlagShift ? NSPageUpFunctionKey : NSPageDownFunctionKey;
            modifiers = 0;
        }
        
        if ((([self displayMode] & kPDFDisplaySinglePageContinuous) == 0) &&
            (eventChar == NSDownArrowFunctionKey || eventChar == NSUpArrowFunctionKey || eventChar == NSPageDownFunctionKey || eventChar == NSPageUpFunctionKey) &&
            (modifiers == 0)) {
            
            NSScrollView *scrollView = [self scrollView];
            NSClipView *clipView = [scrollView contentView];
            NSRect clipRect = [clipView bounds];
            BOOL flipped = [clipView isFlipped];
            CGFloat scroll = eventChar == NSUpArrowFunctionKey || eventChar == NSDownArrowFunctionKey ? [scrollView verticalLineScroll] : NSHeight([self convertRect:clipRect fromView:clipView]) - 6.0 * [scrollView verticalPageScroll];
            NSPoint point = [self convertPoint:clipRect.origin fromView:clipView];
            CGFloat margin = [self convertSize:NSMakeSize(1.0, 1.0) toView:clipView].height;
            CGFloat inset = [scrollView convertSize:NSMakeSize(0.0, [scrollView contentInsets].top) toView:clipView].height;
            
            if (eventChar == NSDownArrowFunctionKey || eventChar == NSPageDownFunctionKey) {
                point.y -= scroll;
                [clipView scrollPoint:[self convertPoint:point toView:clipView]];
                if (fabs(NSMinY(clipRect) - NSMinY([clipView bounds])) <= margin && [self canGoToNextPage]) {
                    [self goToNextPage:nil];
                    NSRect docRect = [[scrollView documentView] frame];
                    clipRect = [clipView bounds];
                    clipRect.origin.y = flipped ? NSMinY(docRect) - inset : NSMaxY(docRect) - NSHeight(clipRect) + inset;
                    [clipView scrollPoint:clipRect.origin];
                }
            } else if (eventChar == NSUpArrowFunctionKey || eventChar == NSPageUpFunctionKey) {
                point.y += scroll;
                [clipView scrollPoint:[self convertPoint:point toView:clipView]];
                if (fabs(NSMinY(clipRect) - NSMinY([clipView bounds])) <= margin && [self canGoToPreviousPage]) {
                    [self goToPreviousPage:nil];
                    NSRect docRect = [[scrollView documentView] frame];
                    clipRect = [clipView bounds];
                    clipRect.origin.y = flipped ? NSMaxY(docRect) - NSHeight(clipRect) : NSMinY(docRect);
                    [clipView scrollPoint:clipRect.origin];
                }
            }
            
            return;
        }
    }
    
    [super keyDown:theEvent];
}


- (void)drawPage:(PDFPage *)pdfPage toContext:(CGContextRef)context {
    [super drawPage:pdfPage toContext:context];
    
    if (RUNNING(10_12)) {
        // On (High) Sierra note annotations don't draw at all
        for (PDFAnnotation *annotation in [[[pdfPage annotations] copy] autorelease]) {
            if ([annotation shouldDisplay] && ([annotation isNote] || [[annotation type] isEqualToString:SKNTextString]))
                [annotation drawWithBox:[self displayBox] inContext:context];
        }
    }
}

- (void)goToRect:(NSRect)rect onPage:(PDFPage *)page {
    if (RUNNING(10_13)) {
        NSView *docView = [self documentView];
        if ([self isPageAtIndexDisplayed:[page pageIndex]] == NO)
            [self goToPage:page];
        [docView scrollRectToVisible:[self convertRect:[self convertRect:rect fromPage:page] toView:docView]];
    } else {
        [super goToRect:rect onPage:page];
    }
}

- (void)setCurrentSelection:(PDFSelection *)currentSelection {
    if (RUNNING(10_12) && currentSelection == nil)
        currentSelection = [[[PDFSelection alloc] initWithDocument:[self document]] autorelease];
    [super setCurrentSelection:currentSelection];
}

static inline BOOL hasHorizontalLayout(PDFView *pdfView) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    return RUNNING_AFTER(10_12) && [pdfView displayDirection] == kPDFDisplayDirectionHorizontal && [pdfView displayMode] == kPDFDisplaySinglePageContinuous;
#pragma clang diagnostic pop
}

static inline BOOL hasVerticalLayout(PDFView *pdfView) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    return RUNNING_AFTER(10_12) && [pdfView displayDirection] == kPDFDisplayDirectionVertical && ([pdfView displayMode] & kPDFDisplaySinglePageContinuous);
#pragma clang diagnostic pop
}

- (void)horizontallyGoToPage:(PDFPage *)page {
    if (page == [self currentPage])
        return;
    NSClipView *clipView = [[self scrollView] contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[[self scrollView] documentView] frame];
    if (NSWidth(docRect) <= NSWidth(bounds))
        return;
    NSRect pageBounds = [self convertRect:[self convertRect:[self layoutBoundsForPage:page] fromPage:page] toView:clipView];
    bounds.origin.x = fmin(fmax(fmin(NSMidX(pageBounds) - 0.5 * NSWidth(bounds), NSMinX(pageBounds)), NSMinX(docRect)), NSMaxX(docRect) - NSWidth(bounds));
    [self goToPage:page];
    [clipView scrollToPoint:bounds.origin];
}

- (void)verticallyScrollToPage:(PDFPage *)page {
    NSScrollView *scrollView = [self scrollView];
    CGFloat inset = [scrollView contentInsets].top;
    NSRect pageRect = [self convertRect:[page boundsForBox:[self displayBox]] fromPage:page];
    CGFloat midY = NSMidY([self bounds]) - 0.5 * inset;
    if (NSMinY(pageRect) <= midY && NSMaxY(pageRect) >= midY)
        return;
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[scrollView documentView] frame];
    CGFloat margin = 0.0;
    inset = [self convertSize:NSMakeSize(0.0, inset) toView:clipView].height;
    if ([self displaysPageBreaks]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        margin = RUNNING_BEFORE(10_13) ? 4.0 : [self pageBreakMargins].top;
#pragma clang diagnostic pop
        margin = [self convertSize:NSMakeSize(0.0, margin * [self scaleFactor]) toView:clipView].height;
    }
    pageRect = [self convertRect:pageRect toView:clipView];
    if ([clipView isFlipped])
        bounds.origin.y = fmin(fmax(fmin(NSMinY(pageRect) - 0.5 * (NSHeight(bounds) + inset), NSMinY(pageRect) - margin - inset), NSMinY(docRect) - inset), NSMaxY(docRect) - NSHeight(bounds));
    else
        bounds.origin.y = fmin(fmax(fmax(NSMaxY(pageRect) + margin - NSHeight(bounds) + inset, NSMinY(pageRect) - 0.5 * (NSHeight(bounds) - inset)), NSMinY(docRect)), NSMaxY(docRect) - NSHeight(bounds) + inset);
    [clipView scrollToPoint:bounds.origin];
}

- (void)goToPreviousPage:(id)sender {
    if (hasHorizontalLayout(self) && [self canGoToPreviousPage]) {
        PDFDocument *doc = [self document];
        PDFPage *page = [doc pageAtIndex:[doc indexForPage:[self currentPage]] - 1];
        [self horizontallyGoToPage:page];
    } else {
        PDFPage *page = nil;
        if (hasVerticalLayout(self)) {
            NSUInteger i = [[self currentPage] pageIndex];
            NSUInteger di = ([self displayMode] == kPDFDisplayTwoUpContinuous && (i > 1 || [self displaysAsBook] == NO)) ? 2 : 1;
            if (i >= di)
                page = [[self document] pageAtIndex:i - di];
        }
        [super goToPreviousPage:sender];
        if (page)
            [self verticallyScrollToPage:page];
    }
}

- (void)goToNextPage:(id)sender {
    if (hasHorizontalLayout(self) && [self canGoToNextPage]) {
        PDFDocument *doc = [self document];
        PDFPage *page = [doc pageAtIndex:[doc indexForPage:[self currentPage]] + 1];
        [self horizontallyGoToPage:page];
    } else {
        PDFPage *page = nil;
        if (hasVerticalLayout(self)) {
            NSUInteger i = [[self currentPage] pageIndex];
            NSUInteger di = ([self displayMode] == kPDFDisplayTwoUpContinuous && (i > 0 || [self displaysAsBook] == NO)) ? 2 : 1;
            if (i + di  < [[self document] pageCount])
                page = [[self document] pageAtIndex:i + di];
            else if (di == 2 && i + 1  < [[self document] pageCount])
                page = [[self document] pageAtIndex:i + 1];
        }
        [super goToNextPage:sender];
        if (page)
            [self verticallyScrollToPage:page];
    }
}

- (void)goToFirstPage:(id)sender {
    if (hasHorizontalLayout(self) && [self canGoToFirstPage]) {
        PDFDocument *doc = [self document];
        PDFPage *page = [doc pageAtIndex:0];
        [self horizontallyGoToPage:page];
    } else {
        [super goToFirstPage:sender];
    }
}

- (void)goToLastPage:(id)sender {
    if (hasHorizontalLayout(self) && [self canGoToLastPage]) {
        PDFDocument *doc = [self document];
        PDFPage *page = [doc pageAtIndex:[doc pageCount] - 1];
        [self horizontallyGoToPage:page];
    } else {
        [super goToLastPage:sender];
    }
}

- (void)goToCurrentPage:(PDFPage *)page {
    if (hasHorizontalLayout(self)) {
        [self horizontallyGoToPage:page];
    } else {
        [self goToPage:page];
        if (hasVerticalLayout(self))
            [self verticallyScrollToPage:page];
   }
}

- (void)goToDestination:(PDFDestination *)destination {
    destination = [destination effectiveDestinationForView:self];
    if ([destination zoom] < kPDFDestinationUnspecifiedValue && [destination zoom] > 0.0)
        [self setScaleFactor:[destination zoom]];
    [super goToDestination:destination];
}

static inline CGRect SKPixelAlignedRect(CGRect rect, CGContextRef context) {
    CGRect r;
    rect = CGContextConvertRectToDeviceSpace(context, rect);
    r.origin.x = round(CGRectGetMinX(rect));
    r.origin.y = round(CGRectGetMinY(rect));
    r.size.width = round(CGRectGetMaxX(rect)) - CGRectGetMinX(r);
    r.size.height = round(CGRectGetMaxY(rect)) - CGRectGetMinY(r);
    return CGRectGetWidth(r) > 0.0 && CGRectGetHeight(r) > 0.0 ? CGContextConvertRectToUserSpace(context, r) : NSZeroRect;
}

- (NSBitmapImageRep *)bitmapImageRepCachingDisplayInRect:(NSRect)rect {
    // draw our own bitmap, because macOS 12 does it wrong
    // ignore background and page shadows because
    NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:rect];
    PDFDisplayBox *box = [self displayBox];
    CGFloat scale = [self scaleFactor];
    CGContextRef context = [[NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep] CGContext];
    for (PDFPage *page in [self visiblePages]) {
        NSRect pageRect = [self convertRect:[page boundsForBox:box] fromPage:page];
        if (NSIntersectsRect(pageRect, rect) == NO) continue;
        pageRect.origin.x -= NSMinX(rect);
        pageRect.origin.y -= NSMinY(rect);
        CGContextSetFillColorWithColor(context, CGColorGetConstantColor(kCGColorWhite));
        CGContextFillRect(context, SKPixelAlignedRect(NSRectToCGRect(pageRect), context));
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, NSMinX(pageRect), NSMinY(pageRect));
        CGContextScaleCTM(context, scale, scale);
        [page drawWithBox:box toContext:context];
        CGContextRestoreGState(context);
    }
    return imageRep;
}

@end
