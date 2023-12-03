//
//  SKNPDFAnnotationNote.m
//  SkimNotes
//
//  Created by Christiaan Hofman on 6/15/08.
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

#import "SKNPDFAnnotationNote.h"
#import "PDFAnnotation_SKNExtensions.h"

NSString *SKNPDFAnnotationTextKey = @"text";
NSString *SKNPDFAnnotationImageKey = @"image";

PDFSize SKNPDFAnnotationNoteSize = {16.0, 16.0};

#if !defined(PDFKIT_PLATFORM_IOS)

#import <CoreGraphics/CoreGraphics.h>

static inline void drawIconComment(CGContextRef context, NSRect bounds);
static inline void drawIconKey(CGContextRef context, NSRect bounds);
static inline void drawIconNote(CGContextRef context, NSRect bounds);
static inline void drawIconHelp(CGContextRef context, NSRect bounds);
static inline void drawIconNewParagraph(CGContextRef context, NSRect bounds);
static inline void drawIconParagraph(CGContextRef context, NSRect bounds);
static inline void drawIconInsert(CGContextRef context, NSRect bounds);

#define SKNAppKitVersionNumber10_12 1504
#define SKNAppKitVersionNumber10_14 1671

#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_12
@interface PDFAnnotation (SKNSierraDeclarations)
- (void)drawWithBox:(PDFDisplayBox)box inContext:(CGContextRef)context;
@end
@interface PDFPage (SKNSierraDeclarations)
- (void)transformContext:(CGContextRef)context forBox:(PDFDisplayBox)box;
@end
#endif

@interface SKNPDFAnnotationNote ()
@property (nonatomic, readonly) NSTextStorage *mutableText;
@property (nonatomic, strong, nullable) NSArray *texts;
@end

#endif

@interface PDFAnnotation (SKNPrivateDeclarations)
- (NSMutableDictionary *)genericSkimNoteProperties;
@end

@implementation SKNPDFAnnotationNote

@synthesize string = _string;
@synthesize text = _text;
@dynamic image;
@dynamic mutableText;
@synthesize texts = _texts;

- (void)updateContents {
    NSMutableString *contents = [NSMutableString string];
    if ([_string length])
        [contents appendString:_string];
    if ([_text length]) {
        [contents appendString:@"  "];
        [contents appendString:[_text string]];
    }
    [super setContents:contents];
}

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class attrStringClass = [NSAttributedString class];
        Class stringClass = [NSString class];
        Class imageClass = [PDFKitPlatformImage class];
        Class dataClass = [NSData class];
        NSAttributedString *aText = [dict objectForKey:SKNPDFAnnotationTextKey];
        PDFKitPlatformImage *anImage = [dict objectForKey:SKNPDFAnnotationImageKey];
        if ([anImage isKindOfClass:imageClass])
            _image = anImage;
        else if ([anImage isKindOfClass:dataClass])
            _image = [[PDFKitPlatformImage alloc] initWithData:(NSData *)anImage];
        if ([aText isKindOfClass:stringClass])
            aText = [[NSAttributedString alloc] initWithString:(NSString *)aText];
        else if ([aText isKindOfClass:dataClass])
            aText = [[NSAttributedString alloc] initWithData:(NSData *)aText options:[NSDictionary dictionary] documentAttributes:NULL error:NULL];
        if ([aText isKindOfClass:attrStringClass])
            [self setText:aText];
        [self updateContents];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    [dict setValue:[NSNumber numberWithInteger:[self iconType]] forKey:SKNPDFAnnotationIconTypeKey];
    [dict setValue:[self text] forKey:SKNPDFAnnotationTextKey];
    [dict setValue:[self image] forKey:SKNPDFAnnotationImageKey];
    return dict;
}

- (NSString *)type {
    return SKNNoteString;
}

- (void)setString:(NSString *)string {
    if (_string != string) {
        _string = [string copy];
        // update the contents to string + text
        [self updateContents];
    }
}

#if defined(PDFKIT_PLATFORM_IOS)

- (void)setText:(NSAttributedString *)text {
    if (_text != text) {
        _text = [text copy];
        // update the contents to string + text
        [self updateContents];
    }
}

#else

- (void)setText:(NSAttributedString *)text {
    if ([self mutableText] != text) {
        // edit the textStorage, this will trigger KVO and update the text automatically
        if (text)
            [_textStorage replaceCharactersInRange:NSMakeRange(0, [_textStorage length]) withAttributedString:text];
        else
            [_textStorage deleteCharactersInRange:NSMakeRange(0, [_textStorage length])];
    }
}

// changes to text are made through textStorage, this allows Skim to provide edits through AppleScript, which works directly on the textStorage
// KVO is triggered manually when the textStorage is edited, either through setText: or through some other means, e.g. through AppleScript
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:SKNPDFAnnotationTextKey])
        return NO;
    else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [super automaticallyNotifiesObserversForKey:key];
#pragma clang diagnostic pop
}

- (void)textDidChange:(NSNotification *)notification {
    // texts should be an array of objects wrapping the text of the note, used by Skim to provide a data source for the children in the outlineView
    [_texts makeObjectsPerformSelector:@selector(willChangeValueForKey:) withObject:SKNPDFAnnotationTextKey];
    // trigger KVO manually
    [self willChangeValueForKey:SKNPDFAnnotationTextKey];
    // update the text
    _text = [[NSAttributedString alloc] initWithAttributedString:_textStorage];
    [self didChangeValueForKey:SKNPDFAnnotationTextKey];
    [_texts makeObjectsPerformSelector:@selector(didChangeValueForKey:) withObject:SKNPDFAnnotationTextKey];
    // update the contents to string + text
    [self updateContents];
}

- (NSTextStorage *)mutableText {
    if (_textStorage == nil) {
        _textStorage = [[NSTextStorage alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSTextStorageDidProcessEditingNotification object:_textStorage];
    }
    return _textStorage;
}

// private method called by -drawWithBox: before to 10.12, made public on 10.12, now calling -drawWithBox:
- (void)drawWithBox:(PDFDisplayBox)box inContext:(CGContextRef)context {
    if (floor(NSAppKitVersionNumber) < SKNAppKitVersionNumber10_12 || floor(NSAppKitVersionNumber) > SKNAppKitVersionNumber10_14 || [self hasAppearanceStream]) {
        [super drawWithBox:box inContext:context];
    } else {
        // on 10.12 draws based on the type rather than the (super)class
        // as PDFKit does not know type Note we need to draw ourselves
        // type Text does just draws a dumb filled square anyway
        NSRect bounds = [self bounds];
        CGContextSaveGState(context);
        [[self page] transformContext:context forBox:box];
        if (NSWidth(bounds) > 2.0 && NSHeight(bounds) > 2.0) {
            CGContextSetFillColorWithColor(context, [[self color] CGColor]);
            CGContextSetStrokeColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
            CGContextSetLineWidth(context, 1.0);
            CGContextSetLineCap(context, kCGLineCapButt);
            CGContextSetLineJoin(context, kCGLineJoinMiter);
            CGContextClipToRect(context, NSRectToCGRect(bounds));
            switch ([self iconType]) {
                case kPDFTextAnnotationIconComment:      drawIconComment(context, bounds);      break;
                case kPDFTextAnnotationIconKey:          drawIconKey(context, bounds);          break;
                case kPDFTextAnnotationIconNote:         drawIconNote(context, bounds);         break;
                case kPDFTextAnnotationIconHelp:         drawIconHelp(context, bounds);         break;
                case kPDFTextAnnotationIconNewParagraph: drawIconNewParagraph(context, bounds); break;
                case kPDFTextAnnotationIconParagraph:    drawIconParagraph(context, bounds);    break;
                case kPDFTextAnnotationIconInsert:       drawIconInsert(context, bounds);       break;
                default:                                 drawIconNote(context, bounds);         break;
            }
        } else {
            CGContextSetFillColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
            CGContextFillRect(context, NSRectToCGRect(bounds));
        }
        CGContextRestoreGState(context);
    }
}

#endif

@end

#if !defined(PDFKIT_PLATFORM_IOS)

static inline void drawIconComment(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGFloat r = 0.1 * fmin(w, h);
    CGContextMoveToPoint(context, x + 0.3 * w, y + 0.3 * h - 0.5);
    CGContextAddArcToPoint(context, x, y + 0.3 * h - 0.5, x, y + h, r);
    CGContextAddArcToPoint(context, x, y + h, x + w, y + h, r);
    CGContextAddArcToPoint(context, x + w, y + h, x + w, y, r);
    CGContextAddArcToPoint(context, x + w, y + 0.3 * h - 0.5, x, y + 0.35 * h, r);
    CGContextAddLineToPoint(context, x + 0.5 * w, y + 0.3 * h - 0.5);
    CGContextAddLineToPoint(context, x + 0.25 * w, y);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
    x += 0.5; y += 0.5; w -= 1.0; h -= 1.0;
    CGPoint points3[6] = {{x + 0.1 * w, y + 0.85 * h},
        {x + 0.9 * w, y + 0.85 * h},
        {x + 0.1 * w, y + 0.65 * h},
        {x + 0.9 * w, y + 0.65 * h},
        {x + 0.1 * w, y + 0.45 * h},
        {x + 0.7 * w, y + 0.45 * h}};
    CGContextSetLineWidth(context, 0.1 * h);
    CGContextStrokeLineSegments(context, points3, 6);
}

static inline void drawIconKey(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGFloat r = 0.1 * fmin(w, h);
    CGPoint points[9] = {{x + 0.55 * w, y + 0.65 * h},
        {x + w, y + 0.15 * h},
        {x + w, y},
        {x + 0.7 * w, y},
        {x + 0.7 * w, y + 0.15 * h},
        {x + 0.55 * w, y + 0.15 * h},
        {x + 0.55 * w, y + 0.3 * h},
        {x + 0.4 * w, y + 0.3 * h},
        {x + 0.4 * w, y + 0.45 * h}};
    CGContextAddLines(context, points, 9);
    CGContextAddArcToPoint(context, x, y + 0.45 * h, x, y + h, r);
    CGContextAddArcToPoint(context, x, y + h, x + w, y + h, 2.0 * r);
    CGContextAddArcToPoint(context, x + 0.55 * w, y + h, x + 0.55 * w, y, r);
    CGContextClosePath(context);
    CGContextAddEllipseInRect(context, CGRectMake(x + 1.0 * r, y + h - 3.0 * r, 2.0 * r, 2.0 * r));
    CGContextDrawPath(context, kCGPathEOFillStroke);
}

static inline void drawIconNote(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.075 * NSWidth(bounds) + 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGPoint points1[5] = {{x, y},
        {x, y + h},
        {x + w, y + h},
        {x + w, y + 0.25 * h},
        {x + 0.75 * w, y}};
    CGPoint points2[3] = {{x + 0.75 * w, y},
        {x + 0.75 * w, y + 0.25 * h},
        {x + w, y + 0.25 * h}};
    CGContextAddLines(context, points1, 5);
    CGContextClosePath(context);
    CGContextAddLines(context, points2, 3);
    CGContextDrawPath(context, kCGPathFillStroke);
    x += 0.5; y += 0.5; w -= 1.0; h -= 1.0;
    CGPoint points3[6] = {{x + 0.1 * w, y + 0.85 * h},
        {x + 0.9 * w, y + 0.85 * h},
        {x + 0.1 * w, y + 0.65 * h},
        {x + 0.9 * w, y + 0.65 * h},
        {x + 0.1 * w, y + 0.45 * h},
        {x + 0.7 * w, y + 0.45 * h}};
    CGContextSetLineWidth(context, 0.1 * h);
    CGContextStrokeLineSegments(context, points3, 6);
}

static inline void drawIconHelp(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.5, 0.5);
    if (NSWidth(bounds) < NSHeight(bounds))
        bounds = NSInsetRect(bounds, 0.0, 0.5 * (NSWidth(bounds) - NSHeight(bounds)));
    else if (NSHeight(bounds) < NSWidth(bounds))
        bounds = NSInsetRect(bounds, 0.5 * (NSHeight(bounds) - NSWidth(bounds)), 0.0);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGContextSetLineWidth(context, 0.1 * w);
    CGContextAddArc(context, x + 0.5 * w, y + 0.65 * h, 0.175 * w, M_PI, -M_PI_4, 1);
    CGContextAddArc(context, x + 0.675 * w, y + (0.825 - 0.35 * M_SQRT2) * h, 0.175 * w, 3.0 * M_PI_4, M_PI, 0);
    CGContextReplacePathWithStrokedPath(context);
    CGContextSetLineWidth(context, 1.0);
    CGContextAddEllipseInRect(context, CGRectMake(x + 0.425 * w, y + 0.1 * h, 0.15 * w, 0.15 * h));
    CGContextAddEllipseInRect(context, NSRectToCGRect(bounds));
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathEOFillStroke);
}

static inline void drawIconNewParagraph(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.075 * NSWidth(bounds) + 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGFloat r = fmin(0.3 * w, 0.1 * h);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGPoint points1[3] = {{x + 0.1 * w, y + 0.5 * h},
        {x + 0.5 * w, y + h},
        {x + 0.9 * w, y + 0.5 * h}};
    CGContextAddLines(context, points1, 3);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
    CGPoint points2[4] = {{x + 0.1 * w, y - 0.5},
        {x + 0.1 * w, y + 0.4 * h},
        {x + 0.4 * w, y},
        {x + 0.4 * w, y + 0.4 * h + 0.5}};
    CGContextAddLines(context, points2, 4);
    CGContextMoveToPoint(context, x + 0.6 * w, y - 0.5);
    CGContextAddLineToPoint(context, x + 0.6 * w, y + 0.4 * h);
    CGContextAddArcToPoint(context, x + 0.9 * w, y + 0.4 * h, x + 0.9 * w, y + 0.2 * h, r);
    CGContextAddArcToPoint(context, x + 0.9 * w, y + 0.2 * h, x + 0.6 * w, y + 0.2 * h, r);
    CGContextAddLineToPoint(context, x + 0.6 * w, y + 0.2 * h);
    CGContextStrokePath(context);
}

static inline void drawIconParagraph(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.075 * NSWidth(bounds) + 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGFloat r = fmin(0.4 * w, 0.25 * h);
    CGPoint points[8] = {{x + 0.9 * w, y + h},
        {x + 0.9 * w, y},
        {x + 0.76 * w, y},
        {x + 0.76 * w, y + 0.8 * h},
        {x + 0.63 * w, y + 0.8 * h},
        {x + 0.63 * w, y},
        {x + 0.5 * w, y},
        {x + 0.5 * w, y + 0.5 * h}};
    CGContextAddLines(context, points, 8);
    CGContextAddArcToPoint(context, x + 0.1 * w, y + 0.5 * h, x + 0.1 * w, y + h, r);
    CGContextAddArcToPoint(context, x + 0.1 * w, y + h, x + 0.9 * w, y + h, r);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
}

static inline void drawIconInsert(CGContextRef context, NSRect bounds) {
    bounds = NSInsetRect(bounds, 0.5, 0.5);
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextMoveToPoint(context, x, y);
    CGContextAddLineToPoint(context, x + 0.5 * w, y + h);
    CGContextAddLineToPoint(context, x + w, y);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
}

#endif
