//
//  PDFAnnotationMarkup_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 4/1/08.
/*
 This software is Copyright (c) 2008-2023
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

#import "PDFAnnotationMarkup_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "PDFAnnotationInk_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKFDFParser.h"
#import "PDFSelection_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSData_SKExtensions.h"
#import "NSCharacterSet_SKExtensions.h"
#import "NSPointerArray_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "NSResponder_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "SKNoteText.h"
#import "PDFView_SKExtensions.h"
#import <objc/objc-runtime.h>

NSString *SKPDFAnnotationSelectionSpecifierKey = @"selectionSpecifier";

static char SKLineRectsKey;
static char SKTextStringKey;
static char SKNoteTextKey;

@implementation PDFAnnotationMarkup (SKExtensions)

/*
 http://www.cocoabuilder.com/archive/message/cocoa/2007/2/16/178891
  The docs are wrong (as is Adobe's spec).  The ordering on the rotated page is:
 --------
 | 0  1 |
 | 2  3 |
 --------
 */

static void addQuadPointsWithBounds(NSMutableArray *quadPoints, const NSRect bounds, const NSPoint origin, NSInteger lineAngle)
{
    static NSInteger offset[4] = {0, 1, 3, 2};
    NSRect r = NSOffsetRect(bounds, -origin.x, -origin.y);
    NSInteger i = lineAngle / 90;
    NSPoint p[4];
    memset(&p, 0, 4 * sizeof(NSPoint));
    p[offset[i]] = SKBottomLeftPoint(r);
    p[offset[++i%4]] = SKTopLeftPoint(r);
    p[offset[++i%4]] = SKTopRightPoint(r);
    p[offset[++i%4]] = SKBottomRightPoint(r);
    for (i = 0; i < 4; i++)
        [quadPoints addObject:[NSValue valueWithPoint:p[i]]];
}

- (void)setDefaultSkimNoteProperties {
    NSString *key = nil;
    switch ([self markupType]) {
        case kPDFMarkupTypeUnderline: key = SKUnderlineNoteColorKey; break;
        case kPDFMarkupTypeStrikeOut: key = SKStrikeOutNoteColorKey; break;
        default: key = SKHighlightNoteColorKey; break;
    }
    [self setColor:[[NSUserDefaults standardUserDefaults] colorForKey:key]];
}

- (instancetype)initSkimNoteWithSelection:(PDFSelection *)selection forPage:(PDFPage *)page forType:(NSString *)type {
    if (page == nil)
        page = [selection safeFirstPage];
    NSRect bounds = NSZeroRect;
    NSPointerArray *lines = nil;
    if ([selection hasCharacters]) {
        for (PDFSelection *sel in [selection selectionsByLine]) {
            NSRect lineRect = [sel boundsForPage:page];
            if (NSIsEmptyRect(lineRect) == NO && [[sel string] rangeOfCharacterFromSet:[NSCharacterSet nonWhitespaceAndNewlineCharacterSet]].length) {
                if (lines == nil)
                    lines = [[NSPointerArray alloc] initForRectPointers];
                [lines addPointer:&lineRect];
                bounds = NSUnionRect(lineRect, bounds);
            }
        }
    }
    if (lines == nil) {
        [[self init] release];
        self = nil;
    } else {
        self = [self initSkimNoteWithBounds:bounds forType:type];
        if (self) {
            NSInteger lineAngle = [page lineDirectionAngle];
            NSMutableArray *quadPoints = [[NSMutableArray alloc] init];
            NSUInteger i, iMax = [lines count];
            for (i = 0; i < iMax; i++)
                addQuadPointsWithBounds(quadPoints, [lines rectAtIndex:i], bounds.origin, lineAngle);
            [self setQuadrilateralPoints:quadPoints];
            objc_setAssociatedObject(self, &SKLineRectsKey, lines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [quadPoints release];
            [lines release];
        }
    }
    return self;
}

- (NSString *)fdfString {
    NSMutableString *fdfString = [[[super fdfString] mutableCopy] autorelease];
    NSPoint point;
    NSRect bounds = [self bounds];
    [fdfString appendFDFName:SKFDFAnnotationQuadrilateralPointsKey];
    [fdfString appendString:@"["];
    for (NSValue *value in [self quadrilateralPoints]) {
        point = [value pointValue];
        [fdfString appendFormat:@"%f %f ", point.x + NSMinX(bounds), point.y + NSMinY(bounds)];
    }
    [fdfString appendString:@"]"];
    return fdfString;
}

- (NSPointerArray *)lineRects {
    NSPointerArray *lineRects = objc_getAssociatedObject(self, &SKLineRectsKey);
    if (lineRects == nil) {
        lineRects = [[NSPointerArray alloc] initForRectPointers];
        
        // archived annotations (or annotations we didn't create) won't have these
        NSArray *quadPoints = [self quadrilateralPoints];
        NSAssert([quadPoints count] % 4 == 0, @"inconsistent number of quad points");
        
        NSUInteger j, jMax = [quadPoints count] / 4;
        NSPoint origin = [self bounds].origin;
        NSRange range = NSMakeRange(0, 4);
        
        while ([lineRects count])
            [lineRects removePointerAtIndex:0];
        
        for (j = 0; j < jMax; j++) {
            
            range.location = 4 * j;
            
            NSPoint point;
            NSUInteger i;
            CGFloat minX = CGFLOAT_MAX, maxX = -CGFLOAT_MAX, minY = CGFLOAT_MAX, maxY = -CGFLOAT_MAX;
            for (i = 0; i < 4; i++) {
                point = [[quadPoints objectAtIndex:4 * j + i] pointValue];
                minX = fmin(minX, point.x);
                maxX = fmax(maxX, point.x);
                minY = fmin(minY, point.y);
                maxY = fmax(maxY, point.y);
            }
            
            NSRect lineRect = NSMakeRect(origin.x + minX, origin.y + minY, maxX - minX, maxY - minY);
            [lineRects addPointer:&lineRect];
        }
        
        objc_setAssociatedObject(self, &SKLineRectsKey, lineRects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [lineRects release];
    }
    return lineRects;
}

- (PDFSelection *)selection {
    NSMutableArray *selections = [NSMutableArray array];
    NSPointerArray *lines = [self lineRects];
    NSUInteger i, iMax = [lines count];
    
    for (i = 0; i < iMax; i++) {
        // slightly outset the rect to avoid rounding errors, as selectionForRect is pretty strict in some OS versions, but unfortunately not in others
        PDFSelection *selection = [[self page] selectionForRect:NSInsetRect([lines rectAtIndex:i], -1.0, -1.0)];
        if ([selection hasCharacters])
            [selections addObject:selection];
    }
    return [PDFSelection selectionByAddingSelections:selections];
}

- (BOOL)hitTest:(NSPoint)point {
    if ([super hitTest:point] == NO)
        return NO;
    
    NSPointerArray *lines = [self lineRects];
    NSUInteger i = [lines count];
    BOOL isContained = NO;
    
    while (i-- && NO == isContained)
        isContained = NSPointInRect(point, [lines rectAtIndex:i]);
    
    return isContained;
}

- (CGFloat)boundsOrder {
    NSPointerArray *lines = [self lineRects];
    NSRect bounds = [lines count] > 0 ? [lines rectAtIndex:0] : [self bounds];
    return [[self page] sortOrderForBounds:bounds];
}

- (NSRect)displayRectForBounds:(NSRect)bounds lineWidth:(CGFloat)lineWidth {
    bounds = [super displayRectForBounds:bounds lineWidth:lineWidth];
    if ([self markupType] == kPDFMarkupTypeHighlight) {
        CGFloat delta = -0.03 * NSHeight(bounds);
        bounds = ([[self page] lineDirectionAngle] % 180) != 0 ? NSInsetRect(bounds, 0.0, delta) : NSInsetRect(bounds, delta, 0.0);
    }
    return bounds;
}

- (void)drawSelectionHighlightWithLineWidth:(CGFloat)lineWidth active:(BOOL)active inContext:(CGContextRef)context {
    if (NSIsEmptyRect([self bounds]))
        return;
    
    NSPointerArray *lines = [self lineRects];
    NSUInteger i, iMax = [lines count];
    CGColorRef color = [[NSColor selectionHighlightColor:active] CGColor];
    
    CGContextSaveGState(context);
    CGContextSetStrokeColorWithColor(context, color);
    CGContextSetLineWidth(context, lineWidth);
    for (i = 0; i < iMax; i++) {
        CGRect rect = CGContextConvertRectToUserSpace(context, CGRectIntegral(CGContextConvertRectToDeviceSpace(context, NSRectToCGRect([lines rectAtIndex:i]))));
        CGContextStrokeRect(context, CGRectInset(rect, -0.5 * lineWidth, -0.5 * lineWidth));
    }
    CGContextRestoreGState(context);
}

- (BOOL)isMarkup { return YES; }

- (BOOL)isWidget { return NO; }

- (BOOL)isLnk { return NO; }

- (BOOL)hasBorder { return NO; }

- (BOOL)isConvertibleAnnotation { return YES; }

- (BOOL)hasNoteText { return [self isEditable]; }

- (SKNoteText *)noteText {
    if ([self isEditable] == NO)
        return nil;
    SKNoteText *noteText = objc_getAssociatedObject(self, &SKNoteTextKey);
    if (noteText == nil) {
        noteText = [[SKNoteText alloc] initWithNote:self];
        objc_setAssociatedObject(self, &SKNoteTextKey, noteText, OBJC_ASSOCIATION_RETAIN);
        [noteText release];
    }
    return noteText;
}

- (NSString *)textString {
    if ([[self page] pageRef] == NULL)
        return nil;
    NSString *textString = objc_getAssociatedObject(self, &SKTextStringKey);
    if (textString == nil) {
        textString = [[self selection] cleanedString] ?: @"";
        objc_setAssociatedObject(self, &SKTextStringKey, textString, OBJC_ASSOCIATION_RETAIN);
    }
    return textString;
}

- (NSString *)colorDefaultKey {
    switch ([self markupType]) {
        case kPDFMarkupTypeUnderline: return SKUnderlineNoteColorKey;
        case kPDFMarkupTypeStrikeOut: return SKStrikeOutNoteColorKey;
        case kPDFMarkupTypeHighlight: return SKHighlightNoteColorKey;
        default: return SKHighlightNoteColorKey;
    }
    return nil;
}

- (void)autoUpdateString {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableUpdateContentsFromEnclosedTextKey])
        return;
    NSString *selString = [self textString];
    if ([selString length])
        [self setString:selString];
}

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *markupKeys = nil;
    if (markupKeys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys removeObject:SKNPDFAnnotationBorderKey];
        markupKeys = [mutableKeys copy];
        [mutableKeys release];
    }
    return markupKeys;
}

#pragma mark Scripting support

+ (NSSet *)customScriptingKeys {
    static NSSet *customMarkupScriptingKeys = nil;
    if (customMarkupScriptingKeys == nil) {
        NSMutableSet *customKeys = [[super customScriptingKeys] mutableCopy];
        [customKeys addObject:SKPDFAnnotationSelectionSpecifierKey];
        [customKeys addObject:SKPDFAnnotationScriptingPointListsKey];
        [customKeys removeObject:SKNPDFAnnotationLineWidthKey];
        [customKeys removeObject:SKNPDFAnnotationBorderStyleKey];
        [customKeys removeObject:SKNPDFAnnotationDashPatternKey];
        customMarkupScriptingKeys = [customKeys copy];
        [customKeys release];
    }
    return customMarkupScriptingKeys;
}

- (id)selectionSpecifier {
    PDFSelection *sel = [self selection];
    return [sel hasCharacters] ? [sel objectSpecifiers] : @[];
}

- (NSArray *)scriptingPointLists {
    NSPoint origin = [self bounds].origin;
    NSMutableArray *pointLists = [NSMutableArray array];
    NSMutableArray *pointValues;
    NSPoint point;
    NSInteger i, j, iMax = [[self quadrilateralPoints] count] / 4;
    for (i = 0; i < iMax; i++) {
        pointValues = [[NSMutableArray alloc] initWithCapacity:iMax];
        for (j = 0; j < 4; j++) {
            point = [[[self quadrilateralPoints] objectAtIndex:4 * i + j] pointValue];
            [pointValues addObject:[NSData dataWithPointAsQDPoint:SKAddPoints(point, origin)]];
        }
        [pointLists addObject:pointValues];
        [pointValues release];
    }
    return pointLists;
}

@end
