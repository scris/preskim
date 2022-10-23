//
//  SKBasePDFView.m
//  Skim
//
//  Created by Christiaan Hofman on 03/10/2021.
/*
 This software is Copyright (c) 2021-2022
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

static char SKBasePDFViewDefaultsObservationContext;

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

@interface SKBasePDFView (BDSKPrivate)

- (void)handleScrollerStyleChangedNotification:(NSNotification *)notification;

@end

@implementation SKBasePDFView

#pragma mark Dark mode and color inversion

static inline NSArray *defaultKeysToObserve() {
    if (RUNNING_AFTER(10_13))
        return [NSArray arrayWithObjects:SKInvertColorsInDarkModeKey, SKSepiaToneKey, nil];
    else
        return [NSArray arrayWithObjects:SKSepiaToneKey, nil];
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

#pragma mark Bug fixes

- (void)keyDown:(NSEvent *)theEvent {
    if (RUNNING_BEFORE(10_12)) {
        
        unichar eventChar = [theEvent firstCharacter];
        NSUInteger modifiers = [theEvent standardModifierFlags];
        
        if ((eventChar == SKSpaceCharacter) && ((modifiers & ~NSShiftKeyMask) == 0)) {
            eventChar = modifiers == NSShiftKeyMask ? NSPageUpFunctionKey : NSPageDownFunctionKey;
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

- (void)horizontallyGoToPage:(PDFPage *)page {
    if (page == [self currentPage])
        return;
    NSClipView *clipView = [[self scrollView] contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[[self scrollView] documentView] frame];
    if (NSWidth(docRect) <= NSWidth(bounds))
        return;
    NSRect pageBounds = [page boundsForBox:[self displayBox]];
    if ([self displaysPageBreaks]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        CGFloat margin = [self pageBreakMargins].left;
#pragma clang diagnostic pop
        pageBounds = NSInsetRect(pageBounds, -margin, -margin);
    }
    pageBounds = [self convertRect:[self convertRect:pageBounds fromPage:page] toView:clipView];
    bounds.origin.x = fmin(fmax(fmin(NSMidX(pageBounds) - 0.5 * NSWidth(bounds), NSMinX(pageBounds)), NSMinX(docRect)), NSMaxX(docRect) - NSWidth(bounds));
    [super goToPage:page];
    [clipView scrollToPoint:bounds.origin];
}

- (void)goToPreviousPage:(id)sender {
    if (hasHorizontalLayout(self) && [self canGoToPreviousPage]) {
        PDFDocument *doc = [self document];
        PDFPage *page = [doc pageAtIndex:[doc indexForPage:[self currentPage]] - 1];
        [self horizontallyGoToPage:page];
    } else {
        [super goToPreviousPage:sender];
    }
}

- (void)goToNextPage:(id)sender {
    if (hasHorizontalLayout(self) && [self canGoToNextPage]) {
        PDFDocument *doc = [self document];
        PDFPage *page = [doc pageAtIndex:[doc indexForPage:[self currentPage]] + 1];
        [self horizontallyGoToPage:page];
    } else {
        [super goToNextPage:sender];
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

- (void)goToPage:(PDFPage *)page {
    if (hasHorizontalLayout(self))
        [self horizontallyGoToPage:page];
    else
        [super goToPage:page];
}

@end
