//
//  SKBasePDFView.m
//  Skim
//
//  Created by Christiaan Hofman on 03/10/2021.
/*
 This software is Copyright (c) 2021
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

#if SDK_BEFORE_10_14
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
    if (@available(macOS 10.14, *))
        return @[SKInvertColorsInDarkModeKey, SKSepiaToneKey, SKWhitePointKey];
    else
        return @[SKSepiaToneKey, SKWhitePointKey];
}

// make sure we don't use the same method name as a superclass or a subclass
- (void)commonBaseInitialization {
    if (@available(macOS 10.14, *)) {
        [self setAppearance:nil];
        [[[self scrollView] contentView] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
            [[self scrollView] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        
        if (@available(macOS 10.15, *)) {} else if (@available(macOS 10.14, *)) {
            [self handleScrollerStyleChangedNotification:nil];
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScrollerStyleChangedNotification:)
                                                             name:NSPreferredScrollerStyleDidChangeNotification object:nil];
        }
    }
    
    [[self scrollView] setContentFilters:SKColorEffectFilters()];
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeys:defaultKeysToObserve() context:&SKBasePDFViewDefaultsObservationContext];
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonBaseInitialization];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self commonBaseInitialization];
    }
    return self;
}

- (void)dealloc {
    @try { [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeys:defaultKeysToObserve() context:&SKBasePDFViewDefaultsObservationContext]; }
    @catch (id e) {}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKBasePDFViewDefaultsObservationContext)
        [self colorFiltersDidChange];
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)colorFiltersDidChange {
    if (@available(macOS 10.14, *)) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
            [[self scrollView] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        else
            [[self scrollView] setAppearance:nil];
    }
    [[self scrollView] setContentFilters:SKColorEffectFilters()];
}

- (void)viewDidChangeEffectiveAppearance {
    if (@available(macOS 10.14, *))
        [super viewDidChangeEffectiveAppearance];
    [[self scrollView] setContentFilters:SKColorEffectFilters()];
}

- (void)handleScrollerStyleChangedNotification:(NSNotification *)notification {
    if (@available(macOS 10.14, *)) {
        if ([NSScroller preferredScrollerStyle] == NSScrollerStyleLegacy) {
            [[[self scrollView] verticalScroller] setAppearance:nil];
            [[[self scrollView] horizontalScroller] setAppearance:nil];
        } else {
            [[[self scrollView] verticalScroller] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
            [[[self scrollView] horizontalScroller] setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        }
    }
}

- (void)setDisplaysPageBreaks:(BOOL)pageBreaks {
    [super setDisplaysPageBreaks:pageBreaks];
    if (@available(macOS 10.14, *))
        [self enablePageShadows:pageBreaks];
}

#pragma mark Bug fixes

- (void)goToRect:(NSRect)rect onPage:(PDFPage *)page {
    if (@available(macOS 10.14, *)) {
        [super goToRect:rect onPage:page];
    } else {
        NSView *docView = [self documentView];
        if ([self isPageAtIndexDisplayed:[page pageIndex]] == NO)
            [self goToPage:page];
        [docView scrollRectToVisible:[self convertRect:[self convertRect:rect fromPage:page] toView:docView]];
    }
}

static inline BOOL hasHorizontalLayout(PDFView *pdfView) {
    return [pdfView displayDirection] == kPDFDisplayDirectionHorizontal && [pdfView displayMode] == kPDFDisplaySinglePageContinuous;
}

static inline BOOL hasVerticalLayout(PDFView *pdfView) {
    return [pdfView displayDirection] == kPDFDisplayDirectionVertical && ([pdfView displayMode] & kPDFDisplaySinglePageContinuous);
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
    if ([self displaysPageBreaks])
        margin = [self convertSize:NSMakeSize(0.0, [self pageBreakMargins].top * [self scaleFactor]) toView:clipView].height;
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

- (void)drawPagesInRect:(NSRect)rect toContext:(CGContextRef)context {
    PDFDisplayBox *box = [self displayBox];
    CGFloat scale = [self scaleFactor];
    CGContextSetInterpolationQuality(context, [self interpolationQuality] + 1);
    for (PDFPage *page in [self visiblePages]) {
        NSRect pageRect = [self convertRect:[page boundsForBox:box] fromPage:page];
        if (NSIntersectsRect(pageRect, rect) == NO) continue;
        CGContextSetFillColorWithColor(context, CGColorGetConstantColor(kCGColorWhite));
        CGContextFillRect(context, SKPixelAlignedRect(NSRectToCGRect(pageRect), context));
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, NSMinX(pageRect), NSMinY(pageRect));
        CGContextScaleCTM(context, scale, scale);
        [page drawWithBox:box toContext:context];
        CGContextRestoreGState(context);
    }
}

- (NSBitmapImageRep *)bitmapImageRepCachingDisplayInRect:(NSRect)rect {
    // draw our own bitmap, because macOS 12 does it wrong
    // ignore background and page shadows because
    NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:rect];
    CGContextRef context = [[NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep] CGContext];
    if (NSEqualPoints(rect.origin, NSZeroPoint) == NO)
        CGContextTranslateCTM(context, -NSMinX(rect), -NSMinY(rect));
    [self drawPagesInRect:rect toContext:context];
    return imageRep;
}

@end
