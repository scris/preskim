//
//  PDFAnnotation_SKNExtensions.m
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

#import "PDFAnnotation_SKNExtensions.h"
#import "SKNPDFAnnotationNote.h"
#import <tgmath.h>

#if defined(PDFKIT_PLATFORM_IOS)

#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

#define SKNMakePoint(x, y)          CGPointMake(x, y)
#define SKNPointFromString(string)  CGPointFromString(string)
#define SKNStringFromPoint(point)   NSStringFromCGPoint(point)
#define SKNRectFromString(string)   CGRectFromString(string)
#define SKNStringFromRect(point)    NSStringFromCGRect(point)
#define SKNPointFromValue(value)    [value CGPointValue]

#else

#import <objc/objc-runtime.h>

#if !defined(PDFKIT_PLATFORM_OSX)

#define PDFKIT_PLATFORM_OSX
#define PDFKitPlatformColor         NSColor
#define PDFKitPlatformFont          NSfont
#define PDFKitPlatformBezierPath    NSBezierPath
#define PDFRect                     NSRect
#define PDFPoint                    NSPoint
#define PDFPointZero                NSZeroPoint
#define PDFRectZero                 NSZeroRect

#endif

#define SKNMakePoint(x, y)          NSMakePoint(x, y)
#define SKNPointFromString(string)  NSPointFromString(string)
#define SKNStringFromPoint(point)   NSStringFromPoint(point)
#define SKNRectFromString(string)   NSRectFromString(string)
#define SKNStringFromRect(point)    NSStringFromRect(point)
#define SKNPointFromValue(value)    [value pointValue]

#endif

NSString *SKNFreeTextString = @"FreeText";
NSString *SKNTextString = @"Text";
NSString *SKNNoteString = @"Note";
NSString *SKNCircleString = @"Circle";
NSString *SKNSquareString = @"Square";
NSString *SKNMarkUpString = @"MarkUp";
NSString *SKNHighlightString = @"Highlight";
NSString *SKNUnderlineString = @"Underline";
NSString *SKNStrikeOutString = @"StrikeOut";
NSString *SKNLineString = @"Line";
NSString *SKNInkString = @"Ink";
NSString *SKNWidgetString = @"Widget";

NSString *SKNPDFAnnotationTypeKey = @"type";
NSString *SKNPDFAnnotationBoundsKey = @"bounds";
NSString *SKNPDFAnnotationPageKey = @"page";
NSString *SKNPDFAnnotationPageIndexKey = @"pageIndex";
NSString *SKNPDFAnnotationContentsKey = @"contents";
NSString *SKNPDFAnnotationStringKey = @"string";
NSString *SKNPDFAnnotationColorKey = @"color";
NSString *SKNPDFAnnotationBorderKey = @"border";
NSString *SKNPDFAnnotationLineWidthKey = @"lineWidth";
NSString *SKNPDFAnnotationBorderStyleKey = @"borderStyle";
NSString *SKNPDFAnnotationDashPatternKey = @"dashPattern";
NSString *SKNPDFAnnotationModificationDateKey = @"modificationDate";
NSString *SKNPDFAnnotationUserNameKey = @"userName";

NSString *SKNPDFAnnotationInteriorColorKey = @"interiorColor";

NSString *SKNPDFAnnotationStartLineStyleKey = @"startLineStyle";
NSString *SKNPDFAnnotationEndLineStyleKey = @"endLineStyle";
NSString *SKNPDFAnnotationStartPointKey = @"startPoint";
NSString *SKNPDFAnnotationEndPointKey = @"endPoint";

NSString *SKNPDFAnnotationFontKey = @"font";
NSString *SKNPDFAnnotationFontColorKey = @"fontColor";
NSString *SKNPDFAnnotationFontNameKey = @"fontName";
NSString *SKNPDFAnnotationFontSizeKey = @"fontSize";
NSString *SKNPDFAnnotationAlignmentKey = @"alignment";
NSString *SKNPDFAnnotationRotationKey = @"rotation";

NSString *SKNPDFAnnotationQuadrilateralPointsKey = @"quadrilateralPoints";

NSString *SKNPDFAnnotationIconTypeKey = @"iconType";

NSString *SKNPDFAnnotationPointListsKey = @"pointLists";

NSString *SKNPDFAnnotationStringValueKey = @"stringValue";
NSString *SKNPDFAnnotationStateKey = @"state";
NSString *SKNPDFAnnotationWidgetTypeKey = @"widgetType";
NSString *SKNPDFAnnotationFieldNameKey = @"fieldName";

#define SKNSquigglyString @"Squiggly"

static PDFKitPlatformColor *SKNColorFromArray(NSArray *array) {
    if ([array count] > 2) {
        CGFloat c[4] = {0.0, 0.0, 0.0, 1.0};
        NSUInteger i;
        for (i = 0; i < MAX([array count], 4); i++)
            c[i] = [[array objectAtIndex:i] doubleValue];
#if defined(PDFKIT_PLATFORM_IOS)
        return [UIColor colorWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
#else
        return [NSColor colorWithColorSpace:[NSColorSpace sRGBColorSpace] components:c count:4];
#endif
    } else if ([array count] > 0) {
        CGFloat c[2] = {0.0, 1.0};
        c[0] = [[array objectAtIndex:0] doubleValue];
        if ([array count] == 2)
            c[1] = [[array objectAtIndex:1] doubleValue];
#if defined(PDFKIT_PLATFORM_IOS)
        return [UIColor colorWithWhite:c[0] alpha:c[1]];
#else
        return [NSColor colorWithColorSpace:[NSColorSpace genericGamma22GrayColorSpace] components:c count:2];
#endif
    } else {
        return [PDFKitPlatformColor clearColor];
    }
}

#if defined(PDFKIT_PLATFORM_IOS) || (defined(MAC_OS_X_VERSION_10_12) && MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_12)

static inline NSInteger SKNAlignmentFromTextAlignment(NSTextAlignment alignment) {
    return alignment == NSTextAlignmentCenter ? 2 : alignment == NSTextAlignmentRight ? 1 : 0;
}

static inline NSTextAlignment SKNTextAlignmentFromAlignment(NSInteger alignment) {
    return alignment == 2 ? NSTextAlignmentCenter : alignment == 1 ? NSTextAlignmentRight : NSTextAlignmentLeft;
}

#else

static inline NSInteger SKNAlignmentFromTextAlignment(NSTextAlignment alignment) {
    return alignment == NSCenterTextAlignment ? 2 : alignment == NSRightTextAlignment ? 1 : 0;
}

static inline NSTextAlignment SKNTextAlignmentFromAlignment(NSInteger alignment) {
    return alignment == 2 ? NSCenterTextAlignment : alignment == 1 ? NSRightTextAlignment : NSLeftTextAlignment;
}

#endif

#if !defined(PDFKIT_PLATFORM_IOS)

#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_12
@interface PDFAnnotation (SKNSierraDeclarations)
- (id)valueForAnnotationKey:(NSString *)key;
@end
#endif

#if !defined(MAC_OS_X_VERSION_10_13) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_13
@interface PDFAnnotation (SKNHighSierraDeclarations)
- (NSString *)widgetFieldType;
- (NSInteger)buttonWidgetState;
- (NSString *)widgetStringValue;
@end
#endif

#endif

@implementation PDFAnnotation (SKNExtensions)

char SKNIsSkimNoteKey;

#if !defined(PDFKIT_PLATFORM_IOS)
static inline Class SKNAnnotationClassForType(NSString *type) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([type isKindOfClass:[NSString class]] == NO)
        return Nil;
    else if ([type isEqualToString:SKNNoteString] || [type isEqualToString:SKNTextString])
        return [SKNPDFAnnotationNote class];
    else if ([type isEqualToString:SKNFreeTextString])
        return [PDFAnnotationFreeText class];
    else if ([type isEqualToString:SKNCircleString])
        return [PDFAnnotationCircle class];
    else if ([type isEqualToString:SKNSquareString])
        return [PDFAnnotationSquare class];
    else if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNMarkUpString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString] || [type isEqualToString:SKNSquigglyString])
        return [PDFAnnotationMarkup class];
    else if ([type isEqualToString:SKNLineString])
        return [PDFAnnotationLine class];
    else if ([type isEqualToString:SKNInkString])
        return [PDFAnnotationInk class];
    else
        return Nil;
#pragma clang diagnostic pop
}
#endif

- (id)initSkimNoteWithBounds:(PDFRect)bounds forType:(NSString *)type {
    if ([type hasPrefix:@"/"])
        type = [type substringFromIndex:1];
    
#if defined(PDFKIT_PLATFORM_IOS)
    
    if ([type isEqualToString:SKNNoteString] || [type isEqualToString:SKNTextString]) {
        if ([self isMemberOfClass:[PDFAnnotation class]]) {
            // replace by our subclass
            [self init];
            self = [[SKNPDFAnnotationNote alloc] initSkimNoteWithBounds:bounds forType:type];
            return self;
        } else if ([self isKindOfClass:[SKNPDFAnnotationNote class]]) {
            // set Text as the type in the annotationDictionary to fool PDFKit
            type = SKNTextString;
        }
    }
    
    self = [self initWithBounds:bounds forType:[@"/" stringByAppendingString:type] withProperties:nil];
    if (self) {
        [self setShouldPrint:YES];
        [self setSkimNote:YES];
        [self setUserName:nil];
    }
    
#else
    
    if ([self isMemberOfClass:[PDFAnnotation class]]) {
        
        // generic, initalize the class for the type in the dictionary
        Class annotationClass = SKNAnnotationClassForType(type);
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        self = [self initWithBounds:NSZeroRect];
#pragma clang diagnostic pop
        self = [annotationClass alloc];
    }
    
    self = [self initSkimNoteWithBounds:bounds];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([[self class] isSubclassOfClass:[PDFAnnotationMarkup class]]) {
#pragma clang diagnostic pop
        NSInteger markupType = kPDFMarkupTypeHighlight;
        if ([type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNSquigglyString])
            markupType = kPDFMarkupTypeUnderline;
        else if ([type isEqualToString:SKNStrikeOutString])
            markupType = kPDFMarkupTypeStrikeOut;
        [(id)self setMarkupType:markupType];
        if ([[self class] respondsToSelector:@selector(defaultSkimNoteColorForMarkupType:)]) {
            NSColor *color = [[self class] defaultSkimNoteColorForMarkupType:markupType];
            if (color)
                [self setColor:color];
        }
    }
    
#endif
    
    if ([self respondsToSelector:@selector(setDefaultSkimNoteProperties)])
        [self setDefaultSkimNoteProperties];
    
    return self;
}

#if !defined(PDFKIT_PLATFORM_IOS)

- (id)initSkimNoteWithBounds:(NSRect)bounds {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    self = [self initWithBounds:bounds];
#pragma clang diagnostic pop
    if (self) {
        [self setShouldPrint:YES];
        [self setSkimNote:YES];
        if ([self respondsToSelector:@selector(setUserName:)])
            [self setUserName:nil];
    }
    return self;
}

#endif

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    Class stringClass = [NSString class];
    NSString *type = [dict objectForKey:SKNPDFAnnotationTypeKey];
    
        
#if defined(PDFKIT_PLATFORM_IOS)
    
    if (([type isEqualToString:SKNNoteString] || [type isEqualToString:SKNTextString]) && [self isMemberOfClass:[PDFAnnotation class]]) {
        // replace by our subclass
        [self init];
        self = [[SKNPDFAnnotationNote alloc] initSkimNoteWithProperties:dict];
        return self;
    }
    
#else
    
    if ([self isMemberOfClass:[PDFAnnotation class]]) {
        // generic, initalize the class for the type in the dictionary
        Class annotationClass = SKNAnnotationClassForType(type);
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        self = [self initWithBounds:NSZeroRect];
#pragma clang diagnostic pop
        self = [[annotationClass alloc] initSkimNoteWithProperties:dict];
        return self;
    }
    
#endif
    
    NSString *boundsString = [dict objectForKey:SKNPDFAnnotationBoundsKey];
    PDFRect bounds = [boundsString isKindOfClass:stringClass] ? SKNRectFromString(boundsString) : PDFRectZero;
    self = [self initSkimNoteWithBounds:bounds forType:type];
    if (self) {
        Class colorClass = [PDFKitPlatformColor class];
        Class arrayClass = [NSArray class];
        Class dateClass = [NSDate class];
        NSString *contents = [dict objectForKey:SKNPDFAnnotationContentsKey];
        PDFKitPlatformColor *color = [dict objectForKey:SKNPDFAnnotationColorKey];
        NSDate *modificationDate = [dict objectForKey:SKNPDFAnnotationModificationDateKey];
        NSString *userName = [dict objectForKey:SKNPDFAnnotationUserNameKey];
        NSNumber *lineWidth = [dict objectForKey:SKNPDFAnnotationLineWidthKey];
        NSNumber *borderStyle = [dict objectForKey:SKNPDFAnnotationBorderStyleKey];
        NSArray *dashPattern = [dict objectForKey:SKNPDFAnnotationDashPatternKey];
        
        if ([contents isKindOfClass:stringClass])
            [self setString:contents];
        if ([color isKindOfClass:colorClass])
            [self setColor:color];
        else if ([color isKindOfClass:arrayClass])
            [self setColor:SKNColorFromArray((NSArray *)color)];
        if ([modificationDate isKindOfClass:dateClass] && [self respondsToSelector:@selector(setModificationDate:)])
            [self setModificationDate:modificationDate];
        if ([userName isKindOfClass:stringClass] && [self respondsToSelector:@selector(setUserName:)])
            [self setUserName:userName];
        if (lineWidth || borderStyle || dashPattern) {
            if ([borderStyle respondsToSelector:@selector(integerValue)] == NO)
                borderStyle = nil;
            if ([self border] == nil)
                [self setBorder:[[PDFBorder alloc] init]];
            if ([lineWidth respondsToSelector:@selector(doubleValue)])
                [[self border] setLineWidth:[lineWidth doubleValue]];
            if ([dashPattern isKindOfClass:arrayClass])
                [[self border] setDashPattern:dashPattern];
            else if ([borderStyle integerValue] == kPDFBorderStyleDashed)
                [[self border] setDashPattern:[NSArray array]];
            else
                [[self border] setDashPattern:nil];
            if (borderStyle)
                [[self border] setStyle:[borderStyle integerValue]];
        } else if ([self border]) {
            [self setBorder:nil];
            // On 10.12 a border with lineWith 1 is inserted, so set its lineWidth to 0
            [[self border] setLineWidth:0.0];
        }
        
#if defined(PDFKIT_PLATFORM_IOS)
        
        color = [dict objectForKey:SKNPDFAnnotationInteriorColorKey];
        if ([color isKindOfClass:colorClass])
            [self setInteriorColor:color];
        else if ([color isKindOfClass:arrayClass])
            [self setInteriorColor:SKNColorFromArray((NSArray *)color)];
        
        if ([type isEqualToString:SKNLineString]) {
            NSString *startPoint = [dict objectForKey:SKNPDFAnnotationStartPointKey];
            NSString *endPoint = [dict objectForKey:SKNPDFAnnotationEndPointKey];
            NSNumber *startLineStyle = [dict objectForKey:SKNPDFAnnotationStartLineStyleKey];
            NSNumber *endLineStyle = [dict objectForKey:SKNPDFAnnotationEndLineStyleKey];
            if ([startPoint isKindOfClass:stringClass])
                [self setStartPoint:SKNPointFromString(startPoint)];
            if ([endPoint isKindOfClass:stringClass])
                [self setEndPoint:SKNPointFromString(endPoint)];
            if ([startLineStyle respondsToSelector:@selector(integerValue)])
                [self setStartLineStyle:[startLineStyle integerValue]];
            if ([endLineStyle respondsToSelector:@selector(integerValue)])
                [self setEndLineStyle:[endLineStyle integerValue]];
        }
        
        if ([type isEqualToString:SKNFreeTextString]) {
            Class fontClass = [PDFKitPlatformFont class];
            PDFKitPlatformFont *font = [dict objectForKey:SKNPDFAnnotationFontKey];
            PDFKitPlatformColor *fontColor = [dict objectForKey:SKNPDFAnnotationFontColorKey];
            NSNumber *alignment = [dict objectForKey:SKNPDFAnnotationAlignmentKey];
            if (font == nil) {
                NSString *fontName = [dict objectForKey:SKNPDFAnnotationFontNameKey];
                NSNumber *fontSize = [dict objectForKey:SKNPDFAnnotationFontSizeKey];
                if ([fontName isKindOfClass:[NSString class]])
                    font = [PDFKitPlatformFont fontWithName:fontName size:[fontSize respondsToSelector:@selector(doubleValue)] ? [fontSize doubleValue] : 0.0];
            }
            if ([font isKindOfClass:fontClass])
                [self setFont:font];
            if ([fontColor isKindOfClass:colorClass])
                [self setFontColor:fontColor];
            else if ([fontColor isKindOfClass:arrayClass])
                [self setFontColor:SKNColorFromArray((NSArray *)fontColor)];
            if ([alignment respondsToSelector:@selector(integerValue)])
                [self setAlignment:SKNTextAlignmentFromAlignment([alignment integerValue])];
        }
        
        if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNMarkUpString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString] || [type isEqualToString:SKNSquigglyString]) {
            NSArray *pointStrings = [dict objectForKey:SKNPDFAnnotationQuadrilateralPointsKey];
            NSMutableArray *pointValues = [[NSMutableArray alloc] initWithCapacity:[pointStrings count]];
            NSUInteger i, iMax = [pointStrings count];
            for (i = 0; i < iMax; i++) {
                PDFPoint p = SKNPointFromString([pointStrings objectAtIndex:i]);
                NSValue *val = [[NSValue alloc] initWithBytes:&p objCType:@encode(PDFPoint)];
                [pointValues addObject:val];
            }
            [self setQuadrilateralPoints:pointValues];
        }
        
        if ([type isEqualToString:SKNTextString] || [type isEqualToString:SKNNoteString]) {
            NSNumber *iconType = [dict objectForKey:SKNPDFAnnotationIconTypeKey];
            if ([iconType respondsToSelector:@selector(integerValue)])
                [self setIconType:[iconType integerValue]];
        }
        
        if ([type isEqualToString:SKNInkString]) {
            NSArray *pointLists = [dict objectForKey:SKNPDFAnnotationPointListsKey];
            if ([pointLists isKindOfClass:arrayClass]) {
                NSUInteger i, iMax = [pointLists count];
                for (i = 0; i < iMax; i++) {
                    NSArray *pointStrings = [pointLists objectAtIndex:i];
                    if ([pointStrings isKindOfClass:arrayClass]) {
                        PDFKitPlatformBezierPath *path = [[PDFKitPlatformBezierPath alloc] init];
                        [[self class] setPoints:pointStrings ofSkimNotePath:path];
                        [self addBezierPath:path];
                    }
                }
            }
        }
        
        if ([type isEqualToString:SKNWidgetString]) {
            SKNPDFWidgetType widgetType = [[dict objectForKey:SKNPDFAnnotationWidgetTypeKey] integerValue];
            NSString *fieldName = [dict objectForKey:SKNPDFAnnotationFieldNameKey];
            NSString *stringValue = [dict objectForKey:SKNPDFAnnotationStringValueKey];
            NSNumber *state = [dict objectForKey:SKNPDFAnnotationStateKey];
            switch (widgetType) {
                case kSKNPDFWidgetTypeText:
                    [self setWidgetFieldType:PDFAnnotationWidgetSubtypeText];
                    break;
                case kSKNPDFWidgetTypeButton:
                    [self setWidgetFieldType:PDFAnnotationWidgetSubtypeButton];
                    break;
                case kSKNPDFWidgetTypeChoice:
                    [self setWidgetFieldType:PDFAnnotationWidgetSubtypeChoice];
                    break;
            }
            if ([fieldName isKindOfClass:stringClass])
                [self setFieldName:fieldName];
            if ([stringValue isKindOfClass:stringClass])
                [self setWidgetStringValue:stringValue];
            if ([state respondsToSelector:@selector(integerValue)])
                [self setButtonWidgetState:[state integerValue]];
            [self setModificationDate:nil];
        }
        
#endif
    }
    return self;
}

- (NSMutableDictionary *)genericSkimNoteProperties{
    PDFPage *page = [self page];
    NSUInteger pageIndex = page ? [[page document] indexForPage:page] : NSNotFound;
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setValue:[self type] forKey:SKNPDFAnnotationTypeKey];
    [dict setValue:[self string] forKey:SKNPDFAnnotationContentsKey];
    [dict setValue:[self color] forKey:SKNPDFAnnotationColorKey];
    if ([self respondsToSelector:@selector(modificationDate)])
        [dict setValue:[self modificationDate] forKey:SKNPDFAnnotationModificationDateKey];
    if ([self respondsToSelector:@selector(userName)])
        [dict setValue:[self userName] forKey:SKNPDFAnnotationUserNameKey];
    [dict setValue:SKNStringFromRect([self bounds]) forKey:SKNPDFAnnotationBoundsKey];
    [dict setValue:[NSNumber numberWithUnsignedInteger:pageIndex == NSNotFound ? 0 : pageIndex] forKey:SKNPDFAnnotationPageIndexKey];
    if ([self border] && [[self border] lineWidth] > 0.0) {
        [dict setValue:[NSNumber numberWithDouble:[[self border] lineWidth]] forKey:SKNPDFAnnotationLineWidthKey];
        [dict setValue:[NSNumber numberWithInteger:[[self border] style]] forKey:SKNPDFAnnotationBorderStyleKey];
        [dict setValue:[[self border] dashPattern] forKey:SKNPDFAnnotationDashPatternKey];
    }
    return dict;
}

static PDFKitPlatformColor *SKNColorFromAnnotationValue(id value) {
    if ([value isKindOfClass:[PDFKitPlatformColor class]])
        return value;
    else if ([value isKindOfClass:[NSArray class]] == NO || [value count] == 0)
        return nil;
#if defined(PDFKIT_PLATFORM_IOS)
    CGFloat c[5] = {0.0, 1.0, 0.0, 1.0, 1.0};
    NSUInteger i;
    for (i = 0; i < MIN([value count], 4); i++)
        c[i] = [[value objectAtIndex:i] doubleValue];
    CGColorSpaceRef cs = [value count] < 3 ? CGColorSpaceCreateDeviceGray() : [value count] < 4 ? CGColorSpaceCreateDeviceRGB() : CGColorSpaceCreateDeviceCMYK();
    CGColorRef cgColor = CGColorCreate(cs, c);
    UIColor *color = [UIColor colorWithCGColor:cgColor];
    CGColorRelease(cgColor);
    CGColorSpaceRelease(cs);
    return color;
#else
    if ([value count] < 3)
        return [NSColor colorWithDeviceWhite:[[value objectAtIndex:0] doubleValue] alpha:1.0];
    else if ([value count] < 4)
        return [NSColor colorWithDeviceRed:[[value objectAtIndex:0] doubleValue] green:[[value objectAtIndex:1] doubleValue] blue:[[value objectAtIndex:2] doubleValue] alpha:1.0];
    else
        return [NSColor colorWithDeviceCyan:[[value objectAtIndex:0] doubleValue] magenta:[[value objectAtIndex:1] doubleValue] yellow:[[value objectAtIndex:2] doubleValue] black:[[value objectAtIndex:31] doubleValue] alpha:.0];
#endif
}

static inline PDFTextAnnotationIconType SKNIconTypeFromAnnotationValue(id value) {
    if ([value isKindOfClass:[NSString class]] == NO)
        return kPDFTextAnnotationIconNote;
    else if ([value isEqualToString:@"/Comment"])
        return kPDFTextAnnotationIconComment;
    else if ([value isEqualToString:@"/Key"])
        return kPDFTextAnnotationIconKey;
    else if ([value isEqualToString:@"/Note"])
        return kPDFTextAnnotationIconNote;
    else if ([value isEqualToString:@"/NewParagraph"])
        return kPDFTextAnnotationIconNewParagraph;
    else if ([value isEqualToString:@"/Paragraph"])
        return kPDFTextAnnotationIconParagraph;
    else if ([value isEqualToString:@"/Insert"])
        return kPDFTextAnnotationIconInsert;
    else
        return kPDFTextAnnotationIconNote;
}

static inline PDFLineStyle SKNPDFLineStyleFromAnnotationValue(id value) {
    if ([value isKindOfClass:[NSString class]] == NO)
        return kPDFLineStyleNone;
    else if ([value isEqualToString:@"/None"])
        return kPDFLineStyleNone;
    else if ([value isEqualToString:@"/Square"])
        return kPDFLineStyleSquare;
    else if ([value isEqualToString:@"/Circle"])
        return kPDFLineStyleCircle;
    else if ([value isEqualToString:@"/Diamond"])
        return kPDFLineStyleDiamond;
    else if ([value isEqualToString:@"/OpenArrow"])
        return kPDFLineStyleOpenArrow;
    else if ([value isEqualToString:@"/ClosedArrow"])
        return kPDFLineStyleClosedArrow;
    else
        return kPDFLineStyleNone;
}

static inline SKNPDFWidgetType SKNPDFWidgetTypeFromAnnotationValue(id value) {
    if ([value isKindOfClass:[NSString class]] == NO)
        return kSKNPDFWidgetTypeUnknown;
    else if ([value isEqualToString:@"/Tx"])
        return kSKNPDFWidgetTypeText;
    else if ([value isEqualToString:@"/Btn"])
        return kSKNPDFWidgetTypeButton;
    else if ([value isEqualToString:@"/Ch"])
        return kSKNPDFWidgetTypeChoice;
    else
        return kSKNPDFWidgetTypeUnknown;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    
    if ([self respondsToSelector:@selector(valueForAnnotationKey:)]) {
        NSString *type = [self type];
        PDFRect bounds = [self bounds];
        id value = nil;
        Class arrayClass = [NSArray class];
        Class stringClass = [NSString class];
        
        if (([type isEqualToString:SKNCircleString] || [type isEqualToString:SKNSquareString]) || [type isEqualToString:SKNLineString]) {
            PDFKitPlatformColor *color = nil;
            if ([self respondsToSelector:@selector(interiorColor)])
                color = [(id)self interiorColor];
            if (color == nil && (value = [self valueForAnnotationKey:@"/IC"]))
                color = SKNColorFromAnnotationValue(value);
            if (color)
                [dict setValue:color forKey:SKNPDFAnnotationInteriorColorKey];
        }
        
        if ([type isEqualToString:SKNTextString] || [type isEqualToString:SKNNoteString]) {
            if ([self respondsToSelector:@selector(iconType)])
                [dict setValue:[NSNumber numberWithInteger:[(id)self iconType]] forKey:SKNPDFAnnotationIconTypeKey];
            else if ((value = [self valueForAnnotationKey:@"/Name"]))
                [dict setValue:[NSNumber numberWithInteger:SKNIconTypeFromAnnotationValue(value)] forKey:SKNPDFAnnotationIconTypeKey];
        }
            
        if ([type isEqualToString:SKNLineString]) {
            if ([self respondsToSelector:@selector(startLineStyle)] && [self respondsToSelector:@selector(endLineStyle)]) {
                [dict setValue:[NSNumber numberWithInteger:[(id)self startLineStyle]] forKey:SKNPDFAnnotationStartLineStyleKey];
                [dict setValue:[NSNumber numberWithInteger:[(id)self endLineStyle]] forKey:SKNPDFAnnotationStartLineStyleKey];
            } else if ((value = [self valueForAnnotationKey:@"/LE"])) {
                if ([value isKindOfClass:arrayClass] && [value count] == 2) {
                    [dict setValue:[NSNumber numberWithInteger:SKNPDFLineStyleFromAnnotationValue([value objectAtIndex:0])] forKey:SKNPDFAnnotationStartLineStyleKey];
                    [dict setValue:[NSNumber numberWithInteger:SKNPDFLineStyleFromAnnotationValue([value objectAtIndex:1])] forKey:SKNPDFAnnotationEndLineStyleKey];
                }
            }
            
            if ([self respondsToSelector:@selector(startPoint)] && [self respondsToSelector:@selector(endPoint)]) {
                [dict setValue:SKNStringFromPoint([(id)self startPoint]) forKey:SKNPDFAnnotationStartPointKey];
                [dict setValue:SKNStringFromPoint([(id)self endPoint]) forKey:SKNPDFAnnotationEndPointKey];
            } else if ((value = [self valueForAnnotationKey:@"/L"])) {
                if ([value isKindOfClass:arrayClass] && [value count] == 4) {
                    PDFPoint p = SKNMakePoint([[value objectAtIndex:0] doubleValue] - bounds.origin.x, [[value objectAtIndex:1] doubleValue] - bounds.origin.y);
                    [dict setValue:SKNStringFromPoint(p) forKey:SKNPDFAnnotationStartPointKey];
                    p = SKNMakePoint([[value objectAtIndex:2] doubleValue] - bounds.origin.x, [[value objectAtIndex:3] doubleValue] - bounds.origin.y);
                    [dict setValue:SKNStringFromPoint(p) forKey:SKNPDFAnnotationEndPointKey];
                }
            }
        }
        
        if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNMarkUpString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString] || [type isEqualToString:SKNSquigglyString]) {
            if ([self respondsToSelector:@selector(quadrilateralPoints)]) {
                NSArray *quadPoints = [(id)self quadrilateralPoints];
                if (quadPoints) {
                    NSUInteger i, iMax = [quadPoints count];
                    NSMutableArray *quadPointStrings = [[NSMutableArray alloc] initWithCapacity:iMax];
                    for (i = 0; i < iMax; i++)
                        [quadPointStrings addObject:SKNStringFromPoint(SKNPointFromValue([quadPoints objectAtIndex:i]))];
                    [dict setValue:quadPointStrings forKey:SKNPDFAnnotationQuadrilateralPointsKey];
                }
            } else if ((value = [self valueForAnnotationKey:@"/QuadPoints"])) {
                if ([value isKindOfClass:arrayClass] && [value count] % 4 == 0) {
                    Class numberClass = [NSNumber class];
                    Class valueClass = [NSValue class];
                    NSMutableArray *quadPoints = [NSMutableArray array];
                    NSUInteger i, iMax = [value count];
                    for (i = 0; i < iMax; i++) {
                        NSValue *val = [value objectAtIndex:i];
                        PDFPoint p;
                        if ([val isKindOfClass:numberClass])
                            p = SKNMakePoint([(NSNumber *)val doubleValue], [(NSNumber *)[value objectAtIndex:++i] doubleValue]);
                        else if ([val isKindOfClass:valueClass])
                            p = SKNPointFromValue(val);
                        else
                            continue;
                        p.x -= bounds.origin.x;
                        p.y -= bounds.origin.y;
                        [quadPoints addObject:SKNStringFromPoint(p)];
                    }
                    [dict setValue:quadPoints forKey:SKNPDFAnnotationQuadrilateralPointsKey];
                }
            }
        }
        
        if ([type isEqualToString:SKNInkString]) {
            if ([self respondsToSelector:@selector(paths)]) {
                NSArray *paths = [(id)self paths];
                if (paths) {
                    Class selfClass = [self class];
                    NSUInteger i, iMax = [paths count];
                    NSMutableArray *pointLists = [[NSMutableArray alloc] initWithCapacity:iMax];
                    for (i = 0; i < iMax; i++) {
                        PDFKitPlatformBezierPath *path = [paths objectAtIndex:i];
                        NSArray *pointStrings = [selfClass pointsFromSkimNotePath:path];
                        if ([pointStrings count])
                            [pointLists addObject:pointStrings];
                    }
                    [dict setValue:pointLists forKey:SKNPDFAnnotationPointListsKey];
                }
           } else if ((value = [self valueForAnnotationKey:@"/InkList"])) {
                if ([value isKindOfClass:arrayClass]) {
                    Class pathClass = [PDFKitPlatformBezierPath class];
                    Class numberClass = [NSNumber class];
                    Class valueClass = [NSValue class];
                    NSMutableArray *pointLists = [NSMutableArray array];
                    NSUInteger i, iMax = [value count];
                    for (i = 0; i < iMax; i++) {
                        id path = [value objectAtIndex:i];
                        NSMutableArray *points = [NSMutableArray array];
                        if ([path isKindOfClass:pathClass]) {
                            [points addObjectsFromArray:[[self class] pointsFromSkimNotePath:path]];
                        } else if ([path isKindOfClass:arrayClass]) {
                            NSUInteger j, jMax = [path count];
                            for (j = 0; j < jMax; j++) {
                                NSValue *val = [path objectAtIndex:i];
                                PDFPoint p;
                                if ([val isKindOfClass:numberClass])
                                    p = SKNMakePoint([(NSNumber *)val doubleValue], [(NSNumber *)[value objectAtIndex:++j] doubleValue]);
                                else if ([val isKindOfClass:valueClass])
                                    p = SKNPointFromValue(val);
                                else
                                    continue;
                                p.x -= bounds.origin.x;
                                p.y -= bounds.origin.y;
                                [points addObject:SKNStringFromPoint(p)];
                            }
                        }
                        [pointLists addObject:points];
                    }
                    [dict setValue:pointLists forKey:SKNPDFAnnotationPointListsKey];
                }
            }
        }
        
        if ([type isEqualToString:SKNFreeTextString]) {
            if ([self respondsToSelector:@selector(alignment)]) {
                [dict setValue:[NSNumber numberWithInteger:SKNTextAlignmentFromAlignment([(id)self alignment])] forKey:SKNPDFAnnotationAlignmentKey];
            } else if ((value = [self valueForAnnotationKey:@"/Q"])) {
                [dict setValue:[NSNumber numberWithInteger:SKNTextAlignmentFromAlignment([value integerValue])] forKey:SKNPDFAnnotationAlignmentKey];
            }
            
            PDFKitPlatformFont *font = nil;
            if ([self respondsToSelector:@selector(font)]) {
                font = [(id)self font];
            }
            if (font == nil && (value = [self valueForAnnotationKey:@"/DA"])) {
                NSScanner *scanner = [[NSScanner alloc] initWithString:value];
                NSString *fontName;
                double fontSize;
                if ([scanner scanUpToString:@"Tf" intoString:NULL] && [scanner isAtEnd] == NO) {
                    NSUInteger location = [scanner scanLocation];
                    NSRange r = [value rangeOfString:@"/" options:NSBackwardsSearch range:NSMakeRange(0, location)];
                    if (r.location != NSNotFound) {
                        [scanner setScanLocation:NSMaxRange(r)];
                        if ([scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&fontName] &&
                            [scanner scanDouble:&fontSize] &&
                            [scanner scanString:@"Tf" intoString:NULL] &&
                            [scanner scanLocation] == location + 2) {
                            font = [PDFKitPlatformFont fontWithName:fontName size:fontSize];
                        }
                    }
                }
            }
            if (font)
                [dict setObject:font forKey:SKNPDFAnnotationFontKey];
            
            PDFKitPlatformColor *fontColor = nil;
            if ([self respondsToSelector:@selector(fontColor)]) {
                fontColor = [(id)self fontColor];
            }
            if (fontColor == nil && (value = [self valueForAnnotationKey:@"/DA"])) {
                NSUInteger end = [value rangeOfString:@"rg"].location;
                if (end != NSNotFound) {
                    NSCharacterSet *numberChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789. "];
                    NSUInteger start = end;
                    while (start > 0 && [numberChars characterIsMember:[value characterAtIndex:start--]]) {}
                    if (start < end) {
                        NSScanner *scanner = [[NSScanner alloc] initWithString:[value substringWithRange:NSMakeRange(start, end - start)]];
                        CGFloat c;
                        NSMutableArray *array = [NSMutableArray array];
                        while ([scanner scanDouble:&c])
                            [array addObject:[NSNumber numberWithDouble:c]];
                        fontColor = SKNColorFromArray(array);
                    }
                }
            }
            if (fontColor)
                [dict setObject:fontColor forKey:SKNPDFAnnotationFontColorKey];
        }
        
        if ([type isEqualToString:SKNWidgetString]) {
            [dict removeObjectForKey:SKNPDFAnnotationContentsKey];
            [dict removeObjectForKey:SKNPDFAnnotationColorKey];
            [dict removeObjectForKey:SKNPDFAnnotationModificationDateKey];
            [dict removeObjectForKey:SKNPDFAnnotationUserNameKey];
            
            SKNPDFWidgetType widgetType = kSKNPDFWidgetTypeUnknown;
            if ([self respondsToSelector:@selector(widgetFieldType)]) {
                widgetType = SKNPDFWidgetTypeFromAnnotationValue([self widgetFieldType]);
            } else if ((value = [self valueForAnnotationKey:@"/FT"])) {
                widgetType = SKNPDFWidgetTypeFromAnnotationValue(value);
            }
            [dict setObject:[NSNumber numberWithInteger:widgetType] forKey:SKNPDFAnnotationWidgetTypeKey];
            
            NSString *fieldName = nil;
            if ([self respondsToSelector:@selector(fieldName)])
                fieldName = [(id)self fieldName];
            if (fieldName == nil && (value = [self valueForAnnotationKey:@"/T"]) && [value isKindOfClass:stringClass])
                fieldName = value;
            if (fieldName)
                [dict setObject:fieldName forKey:SKNPDFAnnotationFieldNameKey];
            
            if (widgetType == kSKNPDFWidgetTypeButton) {
                if ([self respondsToSelector:@selector(buttonWidgetState)])
                    [dict setObject:[NSNumber numberWithInteger:[self buttonWidgetState]] forKey:SKNPDFAnnotationStateKey];
                else if ((value = [self valueForAnnotationKey:@"/V"]))
                    [dict setObject:[NSNumber numberWithInteger:[value isEqualToString:@"Off"] ? 0 : 1] forKey:SKNPDFAnnotationStateKey];
            } else {
                if ([self respondsToSelector:@selector(widgetStringValue)])
                    [dict setObject:[self widgetStringValue] forKey:SKNPDFAnnotationStringValueKey];
                else if ((value = [self valueForAnnotationKey:@"/V"]))
                    [dict setObject:value forKey:SKNPDFAnnotationStringValueKey];
            }
       }
    }
    
    return dict;
}

- (BOOL)isSkimNote {
    return [objc_getAssociatedObject(self, &SKNIsSkimNoteKey) boolValue];
}

- (void)setSkimNote:(BOOL)flag {
    objc_setAssociatedObject(self, &SKNIsSkimNoteKey, flag ? [NSNumber numberWithBool:YES] : nil, OBJC_ASSOCIATION_RETAIN);
}

- (NSString *)string {
    if ([[self type] isEqualToString:SKNWidgetString]) {
        if ([self respondsToSelector:@selector(valueForAnnotationKey:)]) {
            SKNPDFWidgetType widgetType;
            if ([self respondsToSelector:@selector(widgetFieldType)])
                widgetType = SKNPDFWidgetTypeFromAnnotationValue([self widgetFieldType]);
            else
                widgetType = SKNPDFWidgetTypeFromAnnotationValue([self valueForAnnotationKey:@"/FT"]);
            if (widgetType == kSKNPDFWidgetTypeButton) {
                if ([self respondsToSelector:@selector(buttonWidgetState)])
                    return [NSString stringWithFormat:@"%ld", (long)[self buttonWidgetState]];
                else if ([self respondsToSelector:@selector(valueForAnnotationKey:)])
                    return [[self valueForAnnotationKey:@"/V"] isEqual:@"Off"] ? @"0" : @"1";
            } else {
                if ([self respondsToSelector:@selector(widgetStringValue)])
                    return [self widgetStringValue];
                else if ([self respondsToSelector:@selector(valueForAnnotationKey:)])
                    return [self valueForAnnotationKey:@"/V"];
            }
        }
        return nil;
    }
    return [self contents];
}

- (void)setString:(NSString *)string {
    [self setContents:string];
}

+ (NSArray *)pointsFromSkimNotePath:(PDFKitPlatformBezierPath *)path {
    NSMutableArray *points = [NSMutableArray array];
#if defined(PDFKIT_PLATFORM_IOS)
    CGPathApplyWithBlock([path CGPath], ^(const CGPathElement *element){
        CGPoint *p = element->points;
        NSUInteger i = 0;
        switch (element->type) {
            case kCGPathElementAddQuadCurveToPoint: i = 1; break;
            case kCGPathElementAddCurveToPoint: i = 2; break;
            case kCGPathElementCloseSubpath: return;
            default: i = 0; break;
        }
        [points addObject:NSStringFromCGPoint(p[i])];
    });
#else
    NSInteger i, iMax = [path elementCount];
    for (i = 0; i < iMax; i++) {
        NSPoint p[3];
        NSUInteger j = 0;
        if (NSCurveToBezierPathElement == [path elementAtIndex:i associatedPoints:p])
            j = 2;
        [points addObject:NSStringFromPoint(p[j])];
    }
#endif
    return points;
}

+ (void)setPoints:(NSArray *)points ofSkimNotePath:(PDFKitPlatformBezierPath *)path {
    [path removeAllPoints];
    
    Class stringClass = [NSString class];
    Class valueClass = [NSValue class];
    NSUInteger i, iMax = [points count];
    PDFPoint point, controlPoint1, diff;
    CGFloat d2;
    
    for (i = 0; i < iMax; i++) {
        id pointValue = [points objectAtIndex:i];
        PDFPoint prevPoint = point;
        point = [pointValue isKindOfClass:stringClass] ? SKNPointFromString(pointValue) : [pointValue isKindOfClass:valueClass] ? SKNPointFromValue(pointValue) : PDFPointZero;
        
        if (i == 0) {
            [path moveToPoint:point];
        } else if (i == 1) {
            d2 = sqrt(diff.x * diff.x + diff.y * diff.y);
            diff.x = point.x - prevPoint.x;
            diff.y = point.y - prevPoint.y;
            controlPoint1 = prevPoint;
        } else {
            PDFPoint diff1, controlPoint2;
            CGFloat d0, d1;
            
            diff1 = diff;
            diff.x = point.x - prevPoint.x;
            diff.y = point.y - prevPoint.y;
            
            d1 = d2;
            d2 = sqrt(diff.x * diff.x + diff.y * diff.y);
            d0 = sqrt(d1 * d2);
            
            diff1.x = d2 * diff1.x + d1 * diff.x;
            diff1.y = d2 * diff1.y + d1 * diff.y;
            
            controlPoint2 = prevPoint;
            if (d2 > 0.0) {
                controlPoint2.x -= diff1.x / (3.0 * (d0 + d2));
                controlPoint2.y -= diff1.y / (3.0 * (d0 + d2));
            }
            
#if defined(PDFKIT_PLATFORM_IOS)
            [path addCurveToPoint:prevPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2];
#else
            [path curveToPoint:prevPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2];
#endif
            
            controlPoint1 = prevPoint;
            if (d1 > 0.0) {
                controlPoint1.x += diff1.x / (3.0 * (d0 + d1));
                controlPoint1.y += diff1.y / (3.0 * (d0 + d1));
            }
        }
    }
    
#if defined(PDFKIT_PLATFORM_IOS)
    if (iMax == 2)
        [path addLineToPoint:point];
    else if (iMax > 2)
        [path addCurveToPoint:point controlPoint1:controlPoint1 controlPoint2:point];
#else
    if (iMax == 2)
        [path lineToPoint:point];
    else if (iMax > 2)
        [path curveToPoint:point controlPoint1:controlPoint1 controlPoint2:point];
#endif
}

#if !defined(PDFKIT_PLATFORM_IOS)

+ (void)addPoint:(NSPoint)point toSkimNotesPath:(NSBezierPath *)path {
    NSUInteger count = [path elementCount];
    
    if (count == 0) {
        
        [path moveToPoint:point];
        
    } else if (count == 1) {
        
        [path lineToPoint:point];
        
    } else {
        
        NSBezierPathElement elt;
        NSPoint points[3];
        NSPoint diff1, diff2, controlPoint, point0, point1;
        CGFloat d0, d1, d2;
        
        elt = [path elementAtIndex:count - 2 associatedPoints:points];
        point0 = elt == NSCurveToBezierPathElement ? points[2] : points[0];
        
        elt = [path elementAtIndex:count - 1 associatedPoints:points];
        point1 = elt == NSCurveToBezierPathElement ? points[2] : points[0];
        
        diff1.x = point1.x - point0.x;
        diff1.y = point1.y - point0.y;
        diff2.x = point.x - point1.x;
        diff2.y = point.y - point1.y;
        
        d1 = sqrt(diff1.x * diff1.x + diff1.y * diff1.y);
        d2 = sqrt(diff2.x * diff2.x + diff2.y * diff2.y);
        d0 = sqrt(d1 * d2);
        
        diff1.x = d2 * diff1.x + d1 * diff2.x;
        diff1.y = d2 * diff1.y + d1 * diff2.y;
        
        controlPoint = point1;
        if (d2 > 0.0) {
            controlPoint.x -= diff1.x / (3.0 * (d0 + d2));
            controlPoint.y -= diff1.y / (3.0 * (d0 + d2));
        }
         
        if (elt == NSCurveToBezierPathElement) {
            points[1] = controlPoint;
            [path setAssociatedPoints:points atIndex:count - 1];
        } else if (count == 2) {
            [path removeAllPoints];
            [path moveToPoint:point0];
            [path curveToPoint:point1 controlPoint1:point0 controlPoint2:controlPoint];
        }
        
        controlPoint = point1;
        if (d1 > 0.0) {
            controlPoint.x += diff1.x / (3.0 * (d0 + d1));
            controlPoint.y += diff1.y / (3.0 * (d0 + d1));
        }
        
        [path curveToPoint:point controlPoint1:controlPoint controlPoint2:point];
        
    }
}

#endif

@end

#pragma mark -

#if !defined(PDFKIT_PLATFORM_IOS)

@implementation PDFAnnotationCircle (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class colorClass = [NSColor class];
        Class arrayClass = [NSArray class];
        NSColor *interiorColor = [dict objectForKey:SKNPDFAnnotationInteriorColorKey];
        if ([interiorColor isKindOfClass:colorClass])
            [self setInteriorColor:interiorColor];
        else if ([interiorColor isKindOfClass:arrayClass])
            [self setInteriorColor:SKNColorFromArray((NSArray *)interiorColor)];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    [dict setValue:[self interiorColor] forKey:SKNPDFAnnotationInteriorColorKey];
    return dict;
}

@end

#pragma mark -

@implementation PDFAnnotationSquare (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class colorClass = [NSColor class];
        Class arrayClass = [NSArray class];
        NSColor *interiorColor = [dict objectForKey:SKNPDFAnnotationInteriorColorKey];
        if ([interiorColor isKindOfClass:colorClass])
            [self setInteriorColor:interiorColor];
        else if ([interiorColor isKindOfClass:arrayClass])
            [self setInteriorColor:SKNColorFromArray((NSArray *)interiorColor)];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    [dict setValue:[self interiorColor] forKey:SKNPDFAnnotationInteriorColorKey];
    return dict;
}

@end

#pragma mark -

@implementation PDFAnnotationLine (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class stringClass = [NSString class];
        Class colorClass = [NSColor class];
        Class arrayClass = [NSArray class];
        NSString *startPoint = [dict objectForKey:SKNPDFAnnotationStartPointKey];
        NSString *endPoint = [dict objectForKey:SKNPDFAnnotationEndPointKey];
        NSNumber *startLineStyle = [dict objectForKey:SKNPDFAnnotationStartLineStyleKey];
        NSNumber *endLineStyle = [dict objectForKey:SKNPDFAnnotationEndLineStyleKey];
        NSColor *interiorColor = [dict objectForKey:SKNPDFAnnotationInteriorColorKey];
        if ([startPoint isKindOfClass:stringClass])
            [self setStartPoint:NSPointFromString(startPoint)];
        if ([endPoint isKindOfClass:stringClass])
            [self setEndPoint:NSPointFromString(endPoint)];
        if ([startLineStyle respondsToSelector:@selector(integerValue)])
            [self setStartLineStyle:[startLineStyle integerValue]];
        if ([endLineStyle respondsToSelector:@selector(integerValue)])
            [self setEndLineStyle:[endLineStyle integerValue]];
        if ([interiorColor isKindOfClass:colorClass])
            [self setInteriorColor:interiorColor];
        else if ([interiorColor isKindOfClass:arrayClass])
            [self setInteriorColor:SKNColorFromArray((NSArray *)interiorColor)];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties {
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    [dict setValue:[NSNumber numberWithInteger:[self startLineStyle]] forKey:SKNPDFAnnotationStartLineStyleKey];
    [dict setValue:[NSNumber numberWithInteger:[self endLineStyle]] forKey:SKNPDFAnnotationEndLineStyleKey];
    [dict setValue:NSStringFromPoint([self startPoint]) forKey:SKNPDFAnnotationStartPointKey];
    [dict setValue:NSStringFromPoint([self endPoint]) forKey:SKNPDFAnnotationEndPointKey];
    [dict setValue:[self interiorColor] forKey:SKNPDFAnnotationInteriorColorKey];
    return dict;
}

@end

#pragma mark -

@implementation PDFAnnotationFreeText (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class fontClass = [NSFont class];
        Class colorClass = [NSColor class];
        Class arrayClass = [NSArray class];
        NSFont *font = [dict objectForKey:SKNPDFAnnotationFontKey];
        NSColor *fontColor = [dict objectForKey:SKNPDFAnnotationFontColorKey];
        NSNumber *alignment = [dict objectForKey:SKNPDFAnnotationAlignmentKey];
        if (font == nil) {
            NSString *fontName = [dict objectForKey:SKNPDFAnnotationFontNameKey];
            NSNumber *fontSize = [dict objectForKey:SKNPDFAnnotationFontSizeKey];
            if ([fontName isKindOfClass:[NSString class]])
                font = [NSFont fontWithName:fontName size:[fontSize respondsToSelector:@selector(doubleValue)] ? [fontSize doubleValue] : 0.0];
        }
        if ([font isKindOfClass:fontClass])
            [self setFont:font];
        if ([fontColor isKindOfClass:colorClass])
            [self setFontColor:fontColor];
        else if ([fontColor isKindOfClass:arrayClass])
            [self setFontColor:SKNColorFromArray((NSArray *)fontColor)];
        if ([alignment respondsToSelector:@selector(integerValue)])
            [self setAlignment:SKNTextAlignmentFromAlignment([alignment integerValue])];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    NSColor *fontColor = [self fontColor];
    [dict setValue:[self font] forKey:SKNPDFAnnotationFontKey];
    if ([[fontColor colorSpace] colorSpaceModel] != NSGrayColorSpaceModel || [fontColor whiteComponent] > 0.0 || [fontColor alphaComponent] < 1.0)
        [dict setValue:fontColor forKey:SKNPDFAnnotationFontColorKey];
    [dict setValue:[NSNumber numberWithInteger:SKNAlignmentFromTextAlignment([self alignment])] forKey:SKNPDFAnnotationAlignmentKey];
    return dict;
}

@end

#pragma mark -

@implementation PDFAnnotationMarkup (SKNExtensions)
/*
 http://www.cocoabuilder.com/archive/message/cocoa/2007/2/16/178891
 The docs are wrong (as is Adobe's spec).  The ordering on the rotated page is:
 --------
 | 0  1 |
 | 2  3 |
 --------
 */

static inline void swapPoints(NSPoint p[4], NSUInteger i, NSUInteger j) {
    NSPoint tmp = p[i];
    p[i] = p[j];
    p[j] = tmp;
}

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class arrayClass = [NSArray class];
        NSArray *pointStrings = [dict objectForKey:SKNPDFAnnotationQuadrilateralPointsKey];
        if ([pointStrings isKindOfClass:arrayClass]) {
            // fix the order, as we have done it wrong for a long time
            NSUInteger i, iMax = [pointStrings count] / 4;
            NSMutableArray *quadPoints = [[NSMutableArray alloc] initWithCapacity:4 * iMax];
            for (i = 0; i < iMax; i++) {
                NSPoint p[4];
                NSUInteger j;
                for (j = 0; j < 4; j++)
                    p[j] = NSPointFromString([pointStrings objectAtIndex:4 * i + j]);
                // p[0]-p[1] should be in the same direction as p[2]-p[3]
                if ((p[1].x - p[0].x) * (p[3].x - p[2].x) + (p[1].y - p[0].y) * (p[3].y - p[2].y) < 0.0) {
                    swapPoints(p, 2, 3);
                }
                // p[0], p[1], p[2] should be ordered clockwise
                if ((p[1].y - p[0].y) * (p[2].x - p[0].x) - (p[1].x - p[0].x) * (p[2].y - p[0].y) < 0.0) {
                    swapPoints(p, 0, 2);
                    swapPoints(p, 1, 3);
                }
                for (j = 0; j < 4; j++) {
                    NSValue *value = [[NSValue alloc] initWithBytes:&p[j] objCType:@encode(NSPoint)];
                    [quadPoints addObject:value];
                }
            }
            [self setQuadrilateralPoints:quadPoints];
        }
        
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties {
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    NSArray *quadPoints = [self quadrilateralPoints];
    if (quadPoints) {
        NSUInteger i, iMax = [quadPoints count];
        NSMutableArray *quadPointStrings = [[NSMutableArray alloc] initWithCapacity:iMax];
        for (i = 0; i < iMax; i++)
            [quadPointStrings addObject:NSStringFromPoint([[quadPoints objectAtIndex:i] pointValue])];
        [dict setValue:quadPointStrings forKey:SKNPDFAnnotationQuadrilateralPointsKey];
    }
    return dict;
}

@end

#pragma mark -

@implementation PDFAnnotationText (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        NSNumber *iconType = [dict objectForKey:SKNPDFAnnotationIconTypeKey];
        if ([iconType respondsToSelector:@selector(integerValue)])
            [self setIconType:[iconType integerValue]];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    [dict setValue:[NSNumber numberWithInteger:[self iconType]] forKey:SKNPDFAnnotationIconTypeKey];
    return dict;
}

@end

#pragma mark -

@implementation PDFAnnotationInk (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class arrayClass = [NSArray class];
        Class selfClass = [self class];
        NSArray *pointLists = [dict objectForKey:SKNPDFAnnotationPointListsKey];
        if ([pointLists isKindOfClass:arrayClass]) {
            NSUInteger i, iMax = [pointLists count];
            for (i = 0; i < iMax; i++) {
                NSArray *pointStrings = [pointLists objectAtIndex:i];
                if ([pointStrings isKindOfClass:arrayClass]) {
                    NSBezierPath *path = [[NSBezierPath alloc] init];
                    [selfClass setPoints:pointStrings ofSkimNotePath:path];
                    [self addBezierPath:path];
                }
            }
        }
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties{
    NSMutableDictionary *dict = [self genericSkimNoteProperties];
    NSArray *paths = [self paths];
    if (paths) {
        Class selfClass = [self class];
        NSUInteger i, iMax = [paths count];
        NSMutableArray *pointLists = [[NSMutableArray alloc] initWithCapacity:iMax];
        for (i = 0; i < iMax; i++) {
            NSBezierPath *path = [paths objectAtIndex:i];
            NSArray *pointStrings = [selfClass pointsFromSkimNotePath:path];
            if ([pointStrings count])
                [pointLists addObject:pointStrings];
        }
        [dict setValue:pointLists forKey:SKNPDFAnnotationPointListsKey];
    }
    return dict;
}

@end

#pragma mark -

@implementation PDFAnnotationTextWidget (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class stringClass = [NSString class];
        NSString *stringValue = [dict objectForKey:SKNPDFAnnotationStringValueKey];
        if ([stringValue isKindOfClass:stringClass])
            [self setStringValue:stringValue];
        if ([self respondsToSelector:@selector(setModificationDate:)])
            [self setModificationDate:nil];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties {
    PDFPage *page = [self page];
    NSUInteger pageIndex = page ? [[page document] indexForPage:page] : NSNotFound;
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setValue:[self type] forKey:SKNPDFAnnotationTypeKey];
    [dict setValue:NSStringFromRect([self bounds]) forKey:SKNPDFAnnotationBoundsKey];
    [dict setValue:[NSNumber numberWithUnsignedInteger:pageIndex == NSNotFound ? 0 : pageIndex] forKey:SKNPDFAnnotationPageIndexKey];
    [dict setValue:[NSNumber numberWithInteger:kSKNPDFWidgetTypeText] forKey:SKNPDFAnnotationWidgetTypeKey];
    [dict setValue:[self fieldName] forKey:SKNPDFAnnotationFieldNameKey];
    [dict setValue:[self stringValue] forKey:SKNPDFAnnotationStringValueKey];
    return dict;
}

- (NSString *)string {
    return [self stringValue];
}

- (void)setString:(NSString *)string {
    [self setStringValue:string];
}

@end

#pragma mark -

@implementation PDFAnnotationButtonWidget (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        NSNumber *state = [dict objectForKey:SKNPDFAnnotationStateKey];
        if ([state respondsToSelector:@selector(integerValue)])
            [self setState:[state integerValue]];
        if ([self respondsToSelector:@selector(setModificationDate:)])
            [self setModificationDate:nil];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties {
    PDFPage *page = [self page];
    NSUInteger pageIndex = page ? [[page document] indexForPage:page] : NSNotFound;
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setValue:[self type] forKey:SKNPDFAnnotationTypeKey];
    [dict setValue:NSStringFromRect([self bounds]) forKey:SKNPDFAnnotationBoundsKey];
    [dict setValue:[NSNumber numberWithUnsignedInteger:pageIndex == NSNotFound ? 0 : pageIndex] forKey:SKNPDFAnnotationPageIndexKey];
    [dict setValue:[NSNumber numberWithInteger:kSKNPDFWidgetTypeButton] forKey:SKNPDFAnnotationWidgetTypeKey];
    [dict setValue:[self fieldName] forKey:SKNPDFAnnotationFieldNameKey];
    [dict setValue:[NSNumber numberWithInteger:[self state]] forKey:SKNPDFAnnotationStateKey];
    return dict;
}

- (NSString *)string {
    return [NSString stringWithFormat:@"%ld", (long)[self state]];
}

- (void)setString:(NSString *)string {
    [self setState:[string integerValue]];
}

@end

#pragma mark -

@implementation PDFAnnotationChoiceWidget (SKNExtensions)

- (id)initSkimNoteWithProperties:(NSDictionary *)dict{
    self = [super initSkimNoteWithProperties:dict];
    if (self) {
        Class stringClass = [NSString class];
        NSString *stringValue = [dict objectForKey:SKNPDFAnnotationStringValueKey];
        if ([stringValue isKindOfClass:stringClass])
            [self setStringValue:stringValue];
        if ([self respondsToSelector:@selector(setModificationDate:)])
            [self setModificationDate:nil];
    }
    return self;
}

- (NSDictionary *)SkimNoteProperties {
    PDFPage *page = [self page];
    NSUInteger pageIndex = page ? [[page document] indexForPage:page] : NSNotFound;
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:5];
    [dict setValue:[self type] forKey:SKNPDFAnnotationTypeKey];
    [dict setValue:NSStringFromRect([self bounds]) forKey:SKNPDFAnnotationBoundsKey];
    [dict setValue:[NSNumber numberWithUnsignedInteger:pageIndex == NSNotFound ? 0 : pageIndex] forKey:SKNPDFAnnotationPageIndexKey];
    [dict setValue:[NSNumber numberWithInteger:kSKNPDFWidgetTypeChoice] forKey:SKNPDFAnnotationWidgetTypeKey];
    [dict setValue:[self fieldName] forKey:SKNPDFAnnotationFieldNameKey];
    [dict setValue:[self stringValue] forKey:SKNPDFAnnotationStringValueKey];
    return dict;
}

- (NSString *)string {
    return [self stringValue];
}

- (void)setString:(NSString *)string {
    [self setStringValue:string];
}

@end

#endif
