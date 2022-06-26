//
//  SKReadingBar.m
//  Skim
//
//  Created by Christiaan Hofman on 3/30/07.
/*
 This software is Copyright (c) 2007-2022
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

#import "SKReadingBar.h"
#import "PDFPage_SKExtensions.h"
#import "SKStringConstants.h"
#import "NSGeometry_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSPointerArray_SKExtensions.h"

#define SKReadingBarNumberOfLinesKey @"SKReadingBarNumberOfLines"

@interface SKReadingBar ()
@property (retain) PDFPage *page;
@property NSRect currentBounds;
@end

@implementation SKReadingBar

@synthesize page, currentLine, numberOfLines, currentBounds, delegate;
@dynamic maxLine;

- (id)initWithPage:(PDFPage *)aPage line:(NSInteger)line delegate:(id <SKReadingBarDelegate>)aDelegate {
    self = [super init];
    if (self) {
        numberOfLines = MAX(1, [[NSUserDefaults standardUserDefaults] integerForKey:SKReadingBarNumberOfLinesKey]);
        delegate = aDelegate;
        NSPointerArray *lines = [aPage lineRects];
        if ([lines count]) {
            page = [aPage retain];
            lineRects = [lines retain];
            currentLine = MAX(0, MIN([self maxLine], line));
        } else {
            PDFDocument *doc = [aPage document];
            NSInteger i = [aPage pageIndex], iMax = [doc pageCount];
            while (++i < iMax) {
                PDFPage *nextPage = [doc pageAtIndex:i];
                lines = [nextPage lineRects];
                if ([lines count]) {
                    page = [nextPage retain];
                    lineRects = [lines retain];
                    currentLine = 0;
                    break;
                }
            }
            if (page == nil) {
                i = [aPage pageIndex];
                while (--i >= 0) {
                    PDFPage *nextPage = [doc pageAtIndex:i];
                    lines = [nextPage lineRects];
                    if ([lines count]) {
                        page = [nextPage retain];
                        lineRects = [lines retain];
                        currentLine = [self maxLine];
                        break;
                    }
                }
            }
        }
        if (page) {
            currentBounds = [lineRects rectAtIndex:currentLine];
            if (numberOfLines > 1) {
                NSInteger i, endLine = MIN([lineRects count], currentLine + numberOfLines);
                for (i = currentLine + 1; i < endLine; i++)
                    currentBounds = NSUnionRect(currentBounds, [lineRects rectAtIndex:i]);
            }
        } else {
            page = [aPage retain];
            currentLine = -1;
            currentBounds = NSZeroRect;
        }
    }
    return self;
}

- (id)init {
    return [self initWithPage:nil line:-1 delegate:nil];
}

- (void)dealloc {
    delegate = nil;
    SKDESTROY(page);
    SKDESTROY(lineRects);
    [super dealloc];
}

- (void)updateCurrentBounds {
    NSRect rect = NSZeroRect;
    if (currentLine >= 0) {
        NSInteger i, endLine = MIN([lineRects count], currentLine + numberOfLines);
        for (i = currentLine; i < endLine; i++)
            rect = NSUnionRect(rect, [lineRects rectAtIndex:i]);
    }
    [self setCurrentBounds:page == nil ? NSZeroRect : rect];
}

- (void)setNumberOfLines:(NSUInteger)number {
    if (number != numberOfLines) {
        PDFPage *oldPage = currentLine != -1 ? page : nil;
        NSRect oldBounds = currentBounds;
        numberOfLines = number;
        [self updateCurrentBounds];
        [[NSUserDefaults standardUserDefaults] setInteger:numberOfLines forKey:SKReadingBarNumberOfLinesKey];
        if (delegate && NSEqualRects(oldBounds, currentBounds) == NO)
            [delegate readingBar:self didChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:NO];
    }
}

- (NSInteger)maxLine {
    NSInteger lineCount = (NSInteger)[lineRects count];
    return lineCount == 0 ? -1 : MAX(0, lineCount - (NSInteger)numberOfLines);
}

+ (NSRect)bounds:(NSRect)rect forBox:(PDFDisplayBox)box onPage:(PDFPage *)aPage {
    if (NSEqualRects(rect, NSZeroRect))
        return NSZeroRect;
    NSRect bounds = [aPage boundsForBox:box];
    if (([aPage lineDirectionAngle] % 180) == 0) {
        rect.origin.y = NSMinY(bounds);
        rect.size.height = NSHeight(bounds);
    } else {
        rect.origin.x = NSMinX(bounds);
        rect.size.width = NSWidth(bounds);
    }
    return rect;
}

- (NSRect)currentBoundsForBox:(PDFDisplayBox)box {
    return [[self class] bounds:[self currentBounds] forBox:box onPage:[self page]];
}

- (BOOL)goToNextPageAtTop:(BOOL)atTop {
    BOOL didMove = NO;
    PDFDocument *doc = [page document];
    NSInteger i = [page pageIndex], iMax = [doc pageCount];
    
    while (++i < iMax) {
        PDFPage *nextPage = [doc pageAtIndex:i];
        NSPointerArray *lines = [nextPage lineRects];
        if ([lines count]) {
            [self setPage:nextPage];
            [lineRects release];
            lineRects = [lines retain];
            currentLine = atTop ? 0 : [self maxLine];
            [self updateCurrentBounds];
            didMove = YES;
            break;
        }
    }
    return didMove;
}

- (BOOL)goToPreviousPageAtTop:(BOOL)atTop {
    BOOL didMove = NO;
    PDFDocument *doc = [page document];
    NSInteger i = [doc indexForPage:page];
    
    while (i-- > 0) {
        PDFPage *prevPage = [doc pageAtIndex:i];
        NSPointerArray *lines = [prevPage lineRects];
        if ([lines count]) {
            [self setPage:prevPage];
            [lineRects release];
            lineRects = [lines retain];
            currentLine = atTop ? 0 : [self maxLine];
            [self updateCurrentBounds];
            didMove = YES;
            break;
        }
    }
    return didMove;
}

- (BOOL)goToNextLine {
    PDFPage *oldPage = currentLine != -1 ? page : nil;
    NSRect oldBounds = currentBounds;
    BOOL didMove = NO;
    if (currentLine < [self maxLine]) {
        ++currentLine;
        [self updateCurrentBounds];
        didMove = YES;
    } else if ([self goToNextPageAtTop:YES]) {
        didMove = YES;
    }
    if (didMove && delegate)
        [delegate readingBar:self didChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:YES];
    return didMove;
}

- (BOOL)goToPreviousLine {
    PDFPage *oldPage = currentLine != -1 ? page : nil;
    NSRect oldBounds = currentBounds;
    BOOL didMove = NO;
    if (currentLine == -1 && [lineRects count])
        currentLine = [lineRects count];
    if (currentLine > 0) {
        --currentLine;
        [self updateCurrentBounds];
        didMove =  YES;
    } else if ([self goToPreviousPageAtTop:NO]) {
        didMove = YES;
    }
    if (didMove && delegate)
        [delegate readingBar:self didChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:YES];
    return didMove;
}

- (BOOL)goToNextPage {
    PDFPage *oldPage = currentLine != -1 ? page : nil;
    NSRect oldBounds = currentBounds;
    BOOL didMove = [self goToNextPageAtTop:YES];
    if (didMove && delegate)
        [delegate readingBar:self didChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:YES];
    return didMove;
}

- (BOOL)goToPreviousPage {
    PDFPage *oldPage = currentLine != -1 ? page : nil;
    NSRect oldBounds = currentBounds;
    BOOL didMove = [self goToPreviousPageAtTop:YES];
    if (didMove && delegate)
        [delegate readingBar:self didChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:YES];
    return didMove;
}

- (void)goToLine:(NSInteger)line onPage:(PDFPage *)aPage {
    PDFPage *oldPage = currentLine != -1 ? page : nil;
    NSRect oldBounds = currentBounds;
    if (page != aPage) {
        [self setPage:aPage];
        [lineRects release];
        lineRects = [[page lineRects] retain];
        currentLine = -1;
    }
    if ([lineRects count]) {
        currentLine = MAX(0, MIN([self maxLine], line));
        [self updateCurrentBounds];
    } else {
        [self goToNextPageAtTop:YES] || [self goToPreviousPageAtTop:NO];
    }
    if (delegate && (page != oldPage || NSEqualRects(oldBounds, currentBounds) == NO))
        [delegate readingBar:self didChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:NO];
}

- (void)drawForPage:(PDFPage *)pdfPage withBox:(PDFDisplayBox)box inContext:(CGContextRef)context {
    BOOL invert = [[NSUserDefaults standardUserDefaults] boolForKey:SKReadingBarInvertKey];
    
    CGContextSaveGState(context);
    
    CGContextSetFillColorWithColor(context, [[[NSUserDefaults standardUserDefaults] colorForKey:SKReadingBarColorKey] CGColor]);
    
    if ([[self page] isEqual:pdfPage]) {
        NSRect rect = [self currentBoundsForBox:box];
        if (invert) {
            NSRect bounds = [pdfPage boundsForBox:box];
            if (NSEqualRects(rect, NSZeroRect)) {
                CGContextFillRect(context, NSRectToCGRect(bounds));
            } else if (([pdfPage lineDirectionAngle] % 180)) {
                CGContextFillRect(context, NSRectToCGRect(SKSliceRect(bounds, NSMaxY(bounds) - NSMaxY(rect), NSMaxYEdge)));
                CGContextFillRect(context, NSRectToCGRect(SKSliceRect(bounds, NSMinY(rect) - NSMinY(bounds), NSMinYEdge)));
            } else {
                CGContextFillRect(context, NSRectToCGRect(SKSliceRect(bounds, NSMaxX(bounds) - NSMaxX(rect), NSMaxXEdge)));
                CGContextFillRect(context, NSRectToCGRect(SKSliceRect(bounds, NSMinX(rect) - NSMinX(bounds), NSMinXEdge)));
            }
        } else {
            CGContextSetBlendMode(context, kCGBlendModeMultiply);
            CGContextFillRect(context, NSRectToCGRect(rect));
        }
    } else if (invert) {
        CGContextFillRect(context, NSRectToCGRect([pdfPage boundsForBox:box]));
    }
    
    
    CGContextRestoreGState(context);
}

- (void)drawForPage:(PDFPage *)pdfPage withBox:(PDFDisplayBox)box active:(BOOL)active {
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    [pdfPage transformContext:context forBox:box];
    [self drawForPage:pdfPage withBox:box inContext:context];
}

@end
