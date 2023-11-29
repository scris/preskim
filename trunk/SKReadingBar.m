//
//  SKReadingBar.m
//  Skim
//
//  Created by Christiaan Hofman on 3/30/07.
/*
 This software is Copyright (c) 2007-2023
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
#import "NSData_SKExtensions.h"
#import "SKLine.h"
#import "SKMainDocument.h"
#import "PDFSelection_SKExtensions.h"
#import "PDFDestination_SKExtensions.h"

#define SKReadingBarNumberOfLinesKey @"SKReadingBarNumberOfLines"

@interface SKReadingBar ()
@property (retain) PDFPage *page;
@property NSRect currentBounds;
- (NSRect)currentBoundsFromLineRects:(NSPointerArray *)lineRects;
@end

@implementation SKReadingBar

@synthesize page, currentLine, numberOfLines, currentBounds, delegate;
@dynamic maxLine, boundsAsQDRect;

- (instancetype)initWithPage:(PDFPage *)aPage line:(NSInteger)line delegate:(id <SKReadingBarDelegate>)aDelegate {
    self = [super init];
    if (self) {
        numberOfLines = MAX(1, [[NSUserDefaults standardUserDefaults] integerForKey:SKReadingBarNumberOfLinesKey]);
        delegate = aDelegate;
        NSPointerArray *lines = [aPage lineRects];
        if ([lines count]) {
            page = [aPage retain];
            lineCount = [lines count];
            currentLine = MAX(0, MIN([self maxLine], line));
            currentBounds = [self currentBoundsFromLineRects:lines];
        } else {
            PDFDocument *doc = [aPage document];
            NSInteger i = [aPage pageIndex], iMax = [doc pageCount];
            while (++i < iMax) {
                PDFPage *nextPage = [doc pageAtIndex:i];
                lines = [nextPage lineRects];
                if ([lines count]) {
                    page = [nextPage retain];
                    lineCount = [lines count];
                    currentLine = 0;
                    currentBounds = [self currentBoundsFromLineRects:lines];
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
                        lineCount = [lines count];
                        currentLine = [self maxLine];
                        currentBounds = [self currentBoundsFromLineRects:lines];
                        break;
                    }
                }
            }
        }
        if (page == nil) {
            page = [aPage retain];
            currentLine = -1;
            currentBounds = NSZeroRect;
        }
    }
    return self;
}

- (instancetype)init {
    return [self initWithPage:nil line:-1 delegate:nil];
}

- (void)dealloc {
    delegate = nil;
    SKDESTROY(page);
    [super dealloc];
}

- (NSRect)currentBoundsFromLineRects:(NSPointerArray *)lineRects {
    NSRect rect = NSZeroRect;
    if (page && currentLine >= 0) {
        if (lineRects == nil)
            lineRects = [page lineRects];
        NSInteger i, endLine = MIN(lineCount, currentLine + numberOfLines);
        for (i = currentLine; i < endLine; i++)
            rect = NSUnionRect(rect, [lineRects rectAtIndex:i]);
    }
    return rect;
}

#pragma mark Accessors

- (void)setNumberOfLines:(NSUInteger)number {
    if (number < 1) number = 1;
    if (number != numberOfLines) {
        PDFPage *oldPage = currentLine != -1 ? page : nil;
        NSRect oldBounds = currentBounds;
        numberOfLines = number;
        [self setCurrentBounds:[self currentBoundsFromLineRects:nil]];
        [[NSUserDefaults standardUserDefaults] setInteger:numberOfLines forKey:SKReadingBarNumberOfLinesKey];
        if (delegate && NSEqualRects(oldBounds, currentBounds) == NO)
            [delegate readingBarDidChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:NO];
    }
}

- (NSInteger)maxLine {
    return lineCount == 0 ? -1 : MAX(0, lineCount - (NSInteger)numberOfLines);
}

#pragma mark Navigation

- (BOOL)goToNextPageAtTop:(BOOL)atTop {
    BOOL didMove = NO;
    PDFDocument *doc = [page document];
    NSInteger i = [page pageIndex], iMax = [doc pageCount];
    
    while (++i < iMax) {
        PDFPage *nextPage = [doc pageAtIndex:i];
        NSPointerArray *lines = [nextPage lineRects];
        if ([lines count]) {
            [self setPage:nextPage];
            lineCount = [lines count];
            currentLine = atTop ? 0 : [self maxLine];
            [self setCurrentBounds:[self currentBoundsFromLineRects:lines]];
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
            lineCount = [lines count];
            currentLine = atTop ? 0 : [self maxLine];
            [self setCurrentBounds:[self currentBoundsFromLineRects:lines]];
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
        [self setCurrentBounds:[self currentBoundsFromLineRects:nil]];
        didMove = YES;
    } else if ([self goToNextPageAtTop:YES]) {
        didMove = YES;
    }
    if (didMove && delegate)
        [delegate readingBarDidChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:YES];
    return didMove;
}

- (BOOL)goToPreviousLine {
    PDFPage *oldPage = currentLine != -1 ? page : nil;
    NSRect oldBounds = currentBounds;
    BOOL didMove = NO;
    if (currentLine == -1 && lineCount)
        currentLine = [self maxLine] + 1;
    if (currentLine > 0) {
        --currentLine;
        [self setCurrentBounds:[self currentBoundsFromLineRects:nil]];
        didMove =  YES;
    } else if ([self goToPreviousPageAtTop:NO]) {
        didMove = YES;
    }
    if (didMove && delegate)
        [delegate readingBarDidChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:YES];
    return didMove;
}

- (BOOL)goToNextPage {
    PDFPage *oldPage = currentLine != -1 ? page : nil;
    NSRect oldBounds = currentBounds;
    BOOL didMove = [self goToNextPageAtTop:YES];
    if (didMove && delegate)
        [delegate readingBarDidChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:YES];
    return didMove;
}

- (BOOL)goToPreviousPage {
    PDFPage *oldPage = currentLine != -1 ? page : nil;
    NSRect oldBounds = currentBounds;
    BOOL didMove = [self goToPreviousPageAtTop:YES];
    if (didMove && delegate)
        [delegate readingBarDidChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:YES];
    return didMove;
}

- (void)goToLine:(NSInteger)line onPage:(PDFPage *)aPage scroll:(BOOL)shouldScroll {
    PDFPage *oldPage = currentLine != -1 ? page : nil;
    NSRect oldBounds = currentBounds;
    if (page != aPage) {
        [self setPage:aPage];
        lineCount = [[page lineRects] count];
        currentLine = -1;
    }
    if (lineCount) {
        currentLine = MAX(0, MIN([self maxLine], line));
        [self setCurrentBounds:[self currentBoundsFromLineRects:nil]];
    } else {
        [self goToNextPageAtTop:YES] || [self goToPreviousPageAtTop:NO];
    }
    if (delegate && (page != oldPage || NSEqualRects(oldBounds, currentBounds) == NO))
        [delegate readingBarDidChangeBounds:oldBounds onPage:oldPage toBounds:currentBounds onPage:page scroll:shouldScroll];
}

- (void)goToLine:(NSInteger)line onPage:(PDFPage *)aPage {
    [self goToLine:line onPage:aPage scroll:NO];
}

#pragma mark Scripting

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptObjectSpecifier *containerRef = [[page containingDocument] objectSpecifier];
    return [[[NSPropertySpecifier alloc] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"readingBar"] autorelease];
}

- (NSUInteger)countOfLines {
    return currentLine == -1 ? 0 : MIN(numberOfLines, lineCount - currentLine);
}

- (SKLine *)objectInLinesAtIndex:(NSUInteger)anIndex {
    return [[[SKLine alloc] initWithPage:page index:currentLine + anIndex] autorelease];
}

- (NSData *)boundsAsQDRect {
    return [NSData dataWithRectAsQDRect:currentBounds];
}

- (void)handleGoToScriptCommand:(NSScriptCommand *)command {
    NSDictionary *args = [command evaluatedArguments];
    id location = [args objectForKey:@"To"];
    PDFPage *aPage = nil;
    NSInteger line = -1;
    NSPoint point = NSZeroPoint;
    
    if ([location isKindOfClass:[PDFPage class]]) {
        aPage = location;
        id pointData = [args objectForKey:@"At"];
        if ([pointData isKindOfClass:[NSData class]])
            point = [(NSData *)pointData pointValueAsQDPoint];
        else
            line = 0;
    } else if ([location isKindOfClass:[PDFAnnotation class]]) {
        aPage = [(PDFAnnotation *)location page];
        point = SKCenterPoint([(PDFAnnotation *)location bounds]);
    } else if ([location isKindOfClass:[PDFOutline class]]) {
        PDFDestination *dest = [(PDFOutline *)location destination];
        if (dest == nil) {
            PDFAction *action = [(PDFOutline *)location action];
            if ([action respondsToSelector:@selector(destination)])
                dest = [(PDFActionGoTo *)action destination];
        }
        if (dest) {
            aPage = [dest page];
            point = [[dest effectiveDestinationForView:nil] point];
        }
    } else if ([location isKindOfClass:[SKLine class]]) {
        aPage = [(SKLine *)location page];
        line = [(SKLine *)location index];
    } else if ([location isKindOfClass:[NSNumber class]]) {
        id source = [args objectForKey:@"Source"];
        if ([source isKindOfClass:[NSString class]])
            source = [NSURL fileURLWithPath:source isDirectory:NO];
        else if ([source isKindOfClass:[NSURL class]] == NO)
            source = nil;
        SKPDFSynchronizerOption options = SKPDFSynchronizerShowReadingBarMask;
        if ([[args objectForKey:@"Selecting"] boolValue])
            options |= SKPDFSynchronizerSelectMask;
        [[(SKMainDocument *)[page containingDocument] synchronizer] findPageAndLocationForLine:[location integerValue] inFile:[source path] options:options];
        return;
    } else {
        PDFSelection *selection = [[[PDFSelection selectionWithSpecifier:[[command arguments] objectForKey:@"To"]] selectionsByLine] firstObject];
        if ([selection hasCharacters]) {
            aPage = [selection safeFirstPage];
            NSRect rect = [selection boundsForPage:aPage];
            point = [aPage lineDirectionAngle] < 180 ? NSMakePoint(NSMinX(rect) + 1.0, NSMinY(rect) + 1.0) : NSMakePoint(NSMaxX(rect) - 1.0, NSMaxY(rect) - 1.0);
        }
    }
    if (line == -1 && aPage)
        line = [aPage indexOfLineRectAtPoint:point lower:YES];
    if (aPage)
        [self goToLine:line onPage:aPage scroll:YES];
}

#pragma mark Drawing

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

- (void)drawForPage:(PDFPage *)pdfPage withBox:(PDFDisplayBox)box inContext:(CGContextRef)context {
    BOOL invert = [[NSUserDefaults standardUserDefaults] boolForKey:SKReadingBarInvertKey];
    
    if ([[self page] isEqual:pdfPage]) {
        
        CGContextSaveGState(context);
        
        CGContextSetFillColorWithColor(context, [[[NSUserDefaults standardUserDefaults] colorForKey:SKReadingBarColorKey] CGColor]);
        
        NSRect rect = [self currentBounds];
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
            rect = [[self class] bounds:rect forBox:box onPage:pdfPage];
            CGContextSetBlendMode(context, kCGBlendModeMultiply);
            CGContextFillRect(context, NSRectToCGRect(rect));
        }
        
        CGContextRestoreGState(context);
        
    } else if (invert) {
        
        CGContextSaveGState(context);
        
        CGContextSetFillColorWithColor(context, [[[NSUserDefaults standardUserDefaults] colorForKey:SKReadingBarColorKey] CGColor]);
        
        CGContextFillRect(context, NSRectToCGRect([pdfPage boundsForBox:box]));
        
        CGContextRestoreGState(context);
        
    }
}

- (void)drawForPage:(PDFPage *)pdfPage withBox:(PDFDisplayBox)box active:(BOOL)active {
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
    [page transformContext:context forBox:box];
    [self drawForPage:pdfPage withBox:box inContext:context];
}

@end
