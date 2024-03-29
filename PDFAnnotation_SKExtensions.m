//
//  PDFAnnotation_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 4/1/08.
/*
 This software is Copyright (c) 2008
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

#import "PDFAnnotation_SKExtensions.h"
#import "PDFAnnotationCircle_SKExtensions.h"
#import "PDFAnnotationSquare_SKExtensions.h"
#import "PDFAnnotationLine_SKExtensions.h"
#import "PDFAnnotationMarkup_SKExtensions.h"
#import "PDFAnnotationFreeText_SKExtensions.h"
#import "PDFAnnotationText_SKExtensions.h"
#import "PDFAnnotationInk_SKExtensions.h"
#import "SKNPDFAnnotationNote_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKFDFParser.h"
#import "PDFPage_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "SKPDFView.h"
#import "NSGraphics_SKExtensions.h"
#import "NSData_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSBezierPath_SKExtensions.h"
#import "SKVersionNumber.h"
#import "NSColor_SKExtensions.h"
#import "NSResponder_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "SKMainDocument.h"
#import "NSView_SKExtensions.h"
#import "SKNoteText.h"
#import "PDFView_SKExtensions.h"
#import "NSDate_SKExtensions.h"
#import "SKRuntime.h"
#import "SKAnnotationTypeImageCell.h"


NSString *SKPDFAnnotationScriptingColorKey = @"scriptingColor";
NSString *SKPDFAnnotationScriptingModificationDateKey = @"scriptingModificationDate";
NSString *SKPDFAnnotationScriptingUserNameKey = @"scriptingUserName";
NSString *SKPDFAnnotationScriptingTextContentsKey = @"textContents";
NSString *SKPDFAnnotationScriptingInteriorColorKey = @"interiorColor";

NSString *SKPDFAnnotationBoundsOrderKey = @"boundsOrder";

NSString *SKPasteboardTypeSkimNote = @"scris.ds.preskim.pasteboard.skimnote";


@implementation PDFAnnotation (SKExtensions)

- (NSColor *)fallback_interiorColor { return nil; }

- (NSString *)fallback_fieldName {
    return [self valueForAnnotationKey:@"/T"];
}

+ (void)load {
    SKAddInstanceMethodImplementationFromSelector(self, @selector(interiorColor), @selector(fallback_interiorColor));
    SKAddInstanceMethodImplementationFromSelector(self, @selector(fieldName), @selector(fallback_fieldName));
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return @[SKPasteboardTypeSkimNote];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
    return NSPasteboardReadingAsData;
}

+ (NSSet *)keyPathsForValuesAffectingObjectValue {
    return [NSSet setWithObjects:SKNPDFAnnotationStringKey, nil];
}

- (instancetype)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type {
    if ([type isEqualToString:SKPasteboardTypeSkimNote] &&
        [propertyList isKindOfClass:[NSData class]]) {
        self = [self initSkimNoteWithProperties:[NSKeyedUnarchiver unarchiveObjectWithData:propertyList]];
    } else {
        self = [self init];
        self = nil;
    }
    return self;
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return @[SKPasteboardTypeSkimNote];
}

- (id)pasteboardPropertyListForType:(NSString *)type {
    if ([type isEqualToString:SKPasteboardTypeSkimNote])
        return [NSKeyedArchiver archivedDataWithRootObject:[self SkimNoteProperties]];
    return nil;
}

static inline Class SKAnnotationClassForType(NSString *type) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([type isEqualToString:SKNNoteString] || [type isEqualToString:SKNTextString])
        return [SKNPDFAnnotationNote class];
    else if ([type isEqualToString:SKNFreeTextString])
        return [PDFAnnotationFreeText class];
    else if ([type isEqualToString:SKNCircleString])
        return [PDFAnnotationCircle class];
    else if ([type isEqualToString:SKNSquareString])
        return [PDFAnnotationSquare class];
    else if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNMarkUpString] || [type isEqualToString:SKNUnderlineString] || [type isEqualToString:SKNStrikeOutString])
        return [PDFAnnotationMarkup class];
    else if ([type isEqualToString:SKNLineString])
        return [PDFAnnotationLine class];
    else if ([type isEqualToString:SKNInkString])
        return [PDFAnnotationInk class];
    else
        return Nil;
#pragma clang diagnostic pop
}

+ (PDFAnnotation *)newSkimNoteWithBounds:(NSRect)bounds forType:(NSString *)type {
    return [[SKAnnotationClassForType(type) alloc] initSkimNoteWithBounds:bounds forType:type];
}

+ (PDFAnnotation *)newSkimNoteWithProperties:(NSDictionary *)dict {
    return [[SKAnnotationClassForType([dict objectForKey:SKNPDFAnnotationTypeKey]) alloc] initSkimNoteWithProperties:dict];
}

+ (PDFAnnotation *)newSkimNoteWithSelection:(PDFSelection *)selection forType:(NSString *)type {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [[PDFAnnotationMarkup alloc] initSkimNoteWithSelection:selection forPage:nil forType:type];
#pragma clang diagnostic pop
}

+ (NSArray *)SkimNotesAndPagesWithSelection:(PDFSelection *)selection forType:(NSString *)type {
    NSMutableArray *annotations = [NSMutableArray array];
    for (PDFPage *page in [selection pages]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        PDFAnnotation *annotation = [[PDFAnnotationMarkup alloc] initSkimNoteWithSelection:selection forPage:page forType:type];
#pragma clang diagnostic pop
        if (annotation) {
            [annotations addObject:@[annotation, page]];
        }
    }
    return [annotations count] > 0 ? annotations : nil;
}

+ (PDFAnnotation *)newSkimNoteWithPaths:(NSArray *)paths {
    NSRect bounds = NSZeroRect;
    NSAffineTransform *transform = [NSAffineTransform transform];
    NSBezierPath *path;
    
    for (path in paths)
        bounds = NSUnionRect(bounds, [path nonEmptyBounds]);
    bounds = NSInsetRect(NSIntegralRect(bounds), -8.0, -8.0);
    [transform translateXBy:-NSMinX(bounds) yBy:-NSMinY(bounds)];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    PDFAnnotation *annotation = [[PDFAnnotationInk alloc] initSkimNoteWithBounds:bounds forType:SKNInkString];
#pragma clang diagnostic pop
    for (path in paths)
        [annotation addBezierPath:[transform transformBezierPath:path]];
    return annotation;
}

+ (NSDictionary *)textToNoteSkimNoteProperties:(NSDictionary *)properties {
    if ([[properties objectForKey:SKNPDFAnnotationTypeKey] isEqualToString:SKNTextString]) {
        NSMutableDictionary *mutableProperties = [properties mutableCopy];
        NSRect bounds = NSRectFromString([properties objectForKey:SKNPDFAnnotationBoundsKey]);
        NSString *contents = [properties objectForKey:SKNPDFAnnotationContentsKey];
        [mutableProperties setObject:SKNNoteString forKey:SKNPDFAnnotationTypeKey];
        bounds.origin.y = NSMaxY(bounds) - SKNPDFAnnotationNoteSize.height;
        bounds.size = SKNPDFAnnotationNoteSize;
        [mutableProperties setObject:NSStringFromRect(bounds) forKey:SKNPDFAnnotationBoundsKey];
        if (contents) {
            NSRange r = [contents rangeOfString:@"  "];
            NSRange r1 = [contents rangeOfString:@"\n"];
            if (r1.location < r.location)
                r = r1;
            if (NSMaxRange(r) < [contents length]) {
                NSFont *font = [[NSUserDefaults standardUserDefaults] fontForNameKey:SKAnchoredNoteFontNameKey sizeKey:SKAnchoredNoteFontSizeKey];
                NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:[contents substringFromIndex:NSMaxRange(r)]
                                                    attributes:[NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil]];
                [mutableProperties setObject:attrString forKey:SKNPDFAnnotationTextKey];
                [mutableProperties setObject:[contents substringToIndex:r.location] forKey:SKNPDFAnnotationContentsKey];
            }
        }
        return mutableProperties;
    }
    return properties;
}

- (NSString *)fdfString {
    NSMutableString *fdfString = [NSMutableString string];
    NSRect bounds = [self bounds];
    CGFloat r, g, b, a = 0.0;
    PDFBorder *border = [self border];
    NSString *contents = [self contents];
    NSDate *modDate = [self modificationDate];
    NSString *userName = [self userName];
    [[[self color] colorUsingColorSpaceName:NSDeviceRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
    [fdfString appendFDFName:SKFDFTypeKey];
    [fdfString appendFDFName:SKFDFAnnotation];
    [fdfString appendFDFName:SKFDFAnnotationTypeKey];
    [fdfString appendFormat:@"/%@", [self isNote] ? SKNTextString : [self type]];
    [fdfString appendFDFName:SKFDFAnnotationBoundsKey];
    [fdfString appendFormat:@"[%f %f %f %f]", NSMinX(bounds), NSMinY(bounds), NSMaxX(bounds), NSMaxY(bounds)];
    [fdfString appendFDFName:SKFDFAnnotationPageIndexKey];
    [fdfString appendFormat:@" %lu", (unsigned long)[self pageIndex]];
    [fdfString appendFDFName:SKFDFAnnotationFlagsKey];
    [fdfString appendString:@" 4"];
    if (a > 0.0) {
        [fdfString appendFDFName:SKFDFAnnotationColorKey];
        [fdfString appendFormat:@"[%f %f %f]", r, g, b];
    }
    if (border) {
        [fdfString appendFDFName:SKFDFAnnotationBorderStylesKey];
        [fdfString appendString:@"<<"];
        if ([border lineWidth] > 0.0) {
            [fdfString appendFDFName:SKFDFAnnotationLineWidthKey];
            [fdfString appendFormat:@" %f", [border lineWidth]];
            [fdfString appendFDFName:SKFDFAnnotationBorderStyleKey];
            [fdfString appendFDFName:SKFDFBorderStyleFromPDFBorderStyle([border style])];
            [fdfString appendFDFName:SKFDFAnnotationDashPatternKey];
            [fdfString appendFormat:@"[%@]", [[[border dashPattern] valueForKey:@"stringValue"] componentsJoinedByString:@" "]];
        } else {
            [fdfString appendFDFName:SKFDFAnnotationLineWidthKey];
            [fdfString appendString:@" 0.0"];
        }
        [fdfString appendString:@">>"];
    }
    if (contents) {
        [fdfString appendFDFName:SKFDFAnnotationContentsKey];
        [fdfString appendString:@"("];
        [fdfString appendString:[[contents lossyStringUsingEncoding:NSISOLatin1StringEncoding] stringByEscapingParenthesis]];
        [fdfString appendString:@")"];
    }
    if (modDate) {
        [fdfString appendFDFName:SKFDFAnnotationModificationDateKey];
        [fdfString appendFormat:@"(%@)", [modDate PDFDescription]];
    }
    if (userName) {
        [fdfString appendFDFName:SKFDFAnnotationUserNameKey];
        [fdfString appendFormat:@"(%@)", [[userName lossyStringUsingEncoding:NSISOLatin1StringEncoding] stringByEscapingParenthesis]];
    }
    return fdfString;
}

- (NSUInteger)pageIndex {
    PDFPage *page = [self page];
    return page ? [page pageIndex] : NSNotFound;
}

- (PDFBorderStyle)borderStyle {
    return [[self border] style];
}

- (void)setBorderStyle:(PDFBorderStyle)style {
    if ([self isEditable] && [self hasBorder]) {
        PDFBorder *oldBorder = [self border];
        PDFBorder *border = nil;
        if (oldBorder || style)
            border = [[PDFBorder alloc] init];
        if (oldBorder) {
            [border setLineWidth:[oldBorder lineWidth]];
            [border setDashPattern:[oldBorder dashPattern]];
        }
        if (border)
            [border setStyle:style];
        [self setBorder:border];
    }
}

- (CGFloat)lineWidth {
    PDFBorder *border = [self border];
    return border ? [border lineWidth] : 0.0;
}

- (void)setLineWidth:(CGFloat)width {
    if ([self isEditable] && [self hasBorder]) {
        PDFBorder *border = nil;
        if (width > 0.0) {
            PDFBorder *oldBorder = [self border];
            border = [[PDFBorder alloc] init];
            if (oldBorder && [oldBorder lineWidth] > 0.0) {
                [border setDashPattern:[oldBorder dashPattern]];
                [border setStyle:[oldBorder style]];
            }
            [border setLineWidth:width];
            [self setBorder:border];
        } else {
            [self setBorder:nil];
            if ([self border] != nil) {
                border = [[PDFBorder alloc] init];
                [border setLineWidth:0.0];
                [self setBorder:border];
            }
        }
    }
}

- (NSArray *)dashPattern {
    return [[self border] dashPattern];
}

- (void)setDashPattern:(NSArray *)pattern {
    if ([self isEditable] && [self hasBorder]) {
        PDFBorder *oldBorder = [self border];
        PDFBorder *border = nil;
        if (oldBorder || [pattern count])
            border = [[PDFBorder alloc] init];
        if (oldBorder) {
            [border setLineWidth:[oldBorder lineWidth]];
            [border setStyle:[oldBorder style]];
        }
        if (border)
            [border setDashPattern:pattern];
        [self setBorder:border];
    }
}

- (NSPoint)observedStartPoint {
    return [self startPoint];
}

- (void)setObservedStartPoint:(NSPoint)point {
    [self setStartPoint:point];
}

- (NSPoint)observedEndPoint {
    return [self endPoint];
}

- (void)setObservedEndPoint:(NSPoint)point {
    [self setEndPoint:point];
}

- (CGFloat)pathInset {
    NSRect bounds = NSZeroRect;
    NSSize size = [self bounds].size;
    for (NSBezierPath *path in [self paths])
        bounds = NSUnionRect(bounds, [path nonEmptyBounds]);
    return floor(fmin(8.0, fmax(0.0, fmin(NSMinX(bounds), fmin(NSMinY(bounds), fmin(size.width - NSMaxX(bounds), size.height - NSMaxY(bounds)))))));
}

// use a copy of the paths so to ensure different old and new values for undo
- (NSArray *)bezierPaths {
    return [[self paths] copy];
}

- (void)setBezierPaths:(NSArray *)newPaths {
    NSArray *paths = [[self paths] copy];
    NSBezierPath *path;
    for (path in paths)
        [self removeBezierPath:path];
    for (path in newPaths)
        [self addBezierPath:path];
}

- (NSArray *)pagePaths {
    NSMutableArray *paths = [[NSMutableArray alloc] initWithArray:[self paths] copyItems:YES];
    NSRect bounds = [self bounds];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:NSMinX(bounds) yBy:NSMinY(bounds)];
    [paths makeObjectsPerformSelector:@selector(transformUsingAffineTransform:) withObject:transform];
    return paths;
}

- (NSImage *)image { return nil; }

- (NSAttributedString *)text { return nil; }

- (BOOL)hasNoteText { return NO; }

- (SKNoteText *)noteText { return nil; }

- (PDFSelection *)selection { return nil; }

- (id)objectValue {
    if ([[self type] isEqualToString:SKNWidgetString] == NO)
        return [self string];
    else if ([self widgetType] == kSKNPDFWidgetTypeButton)
        return [NSNumber numberWithInteger:[self buttonWidgetState]];
    else
        return [self widgetStringValue];
}

- (void)setObjectValue:(id)newObjectValue {
    if ([[self type] isEqualToString:SKNWidgetString]) {
        if ([self widgetType] == kSKNPDFWidgetTypeButton)
            [self setButtonWidgetState:[newObjectValue integerValue]];
        else
            [self setWidgetStringValue:newObjectValue];
    } else if ([newObjectValue isKindOfClass:[NSString class]]) {
        [self setString:newObjectValue];
    }
}

- (SKNPDFWidgetType)widgetType {
    if ([[self type] isEqualToString:SKNWidgetString]) {
        NSString *ft = [self valueForAnnotationKey:@"/FT"];
        if ([ft isEqualToString:@"/Tx"])
            return kSKNPDFWidgetTypeText;
        else if ([ft isEqualToString:@"/Btn"])
            return kSKNPDFWidgetTypeButton;
        else if ([ft isEqualToString:@"/Ch"])
            return kSKNPDFWidgetTypeChoice;
    }
    return kSKNPDFWidgetTypeUnknown;
}

- (NSString *)textString { return nil; }

- (BOOL)isMarkup { return NO; }

- (BOOL)isNote { return NO; }

- (BOOL)isText { return NO; }

- (BOOL)isLine { return NO; }

- (BOOL)isInk { return NO; }

- (BOOL)isLink { return [[self type] isEqualToString:@"Link"]; }

- (BOOL)isWidget { return [self widgetType] != kSKNPDFWidgetTypeUnknown; }

- (BOOL)isResizable { return NO; }

- (BOOL)isMovable { return NO; }

- (BOOL)isEditable { return [self isSkimNote] && ([self page] == nil || [[self page] isEditable]); }

- (BOOL)hasBorder { return [self isSkimNote]; }

- (BOOL)hasInteriorColor { return NO; }

- (BOOL)isConvertibleAnnotation {
    static NSSet *convertibleTypes = nil;
    if (convertibleTypes == nil)
        convertibleTypes = [[NSSet alloc] initWithObjects:SKNFreeTextString, SKNTextString, SKNNoteString, SKNCircleString, SKNSquareString, SKNHighlightString, SKNUnderlineString, SKNStrikeOutString, SKNLineString, SKNInkString, nil];
    return [convertibleTypes containsObject:[self type]];
}

- (BOOL)hitTest:(NSPoint)point {
    return [self shouldDisplay] ? NSPointInRect(point, [self bounds]) : NO;
}

- (CGFloat)boundsOrder {
    return [[self page] sortOrderForBounds:[self bounds]];
}

- (NSRect)displayRectForBounds:(NSRect)bounds lineWidth:(CGFloat)lineWidth {
    return bounds;
}

- (NSRect)displayRect {
    return [self displayRectForBounds:[self bounds] lineWidth:[self lineWidth]];
}

- (SKRectEdges)resizeHandleForPoint:(NSPoint)point scaleFactor:(CGFloat)scaleFactor {
    return [self isResizable] ? SKResizeHandleForPointFromRect(point, [self bounds], 4.0 / scaleFactor) : 0;
}

- (void)drawSelectionHighlightWithLineWidth:(CGFloat)lineWidth active:(BOOL)active inContext:(CGContextRef)context {
    if (NSIsEmptyRect([self bounds]))
        return;
    if ([self isSkimNote]) {
        CGRect rect = CGContextConvertRectToUserSpace(context, CGRectIntegral(CGContextConvertRectToDeviceSpace(context, NSRectToCGRect([self bounds]))));
        CGContextSaveGState(context);
        if ([self isResizable]) {
            SKDrawResizeHandles(context, NSRectFromCGRect(rect), lineWidth, YES, active);
        } else {
            CGColorRef color = [[NSColor selectionHighlightColor:active] CGColor];
            CGContextSetStrokeColorWithColor(context, color);
            CGContextStrokeRectWithWidth(context, CGRectInset(rect, -0.5 * lineWidth, -0.5 * lineWidth), lineWidth);
        }
        CGContextRestoreGState(context);
    } else if ([self isLink]) {
        CGContextSaveGState(context);
        CGColorRef color = CGColorCreateGenericGray(0.0, 0.2);
        CGContextSetFillColorWithColor(context, color);
        CGColorRelease(color);
        CGContextFillRect(context, NSRectToCGRect([self bounds]));
        CGContextRestoreGState(context);
    }
}

- (void)registerUserName {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKUseUserNameKey]) {
        NSString *userName = [[NSUserDefaults standardUserDefaults] stringForKey:SKUserNameKey];
        [self setUserName:[userName length] ? userName : NSFullUserName()];
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableModificationDateKey] == NO)
        [self setModificationDate:[NSDate date]];
}

- (void)autoUpdateString {}

- (NSString *)colorDefaultKey { return nil; }

- (NSString *)alternateColorDefaultKey { return nil; }

- (void)setColor:(NSColor *)color alternate:(BOOL)alternate updateDefaults:(BOOL)update {
    BOOL isFill = alternate && [self hasInteriorColor];
    BOOL isText = alternate && [self isText];
    NSColor *oldColor = (isFill ? [(id)self interiorColor] : (isText ? [(id)self fontColor] : [self color])) ?: [NSColor clearColor];
    if ([oldColor isEqual:color] == NO) {
        if (isFill)
            [(id)self setInteriorColor:[color alphaComponent] > 0.0 ? color : nil];
        else if (isText)
            [(id)self setFontColor:[color alphaComponent] > 0.0 ? color : nil];
        else
            [self setColor:color];
    }
    if (update) {
        NSString *key = (isFill || isText) ? [self alternateColorDefaultKey] : [self colorDefaultKey];
        if (key)
            [[NSUserDefaults standardUserDefaults] setColor:color forKey:key];
    }
}

- (NSURL *)skimURL {
    return [[self page] skimURL];
}

- (NSSet *)keysForValuesToObserveForUndo {
    if ([[self type] isEqualToString:SKNWidgetString])
        return [NSSet setWithObject:@"objectValue"];
    static NSSet *keys = nil;
    if (keys == nil)
        keys = [[NSSet alloc] initWithObjects:SKNPDFAnnotationBoundsKey, SKNPDFAnnotationStringKey, SKNPDFAnnotationColorKey, SKNPDFAnnotationBorderKey, SKNPDFAnnotationModificationDateKey, SKNPDFAnnotationUserNameKey, nil];
    return keys;
}

#pragma mark Scripting support

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptObjectSpecifier *containerRef = [[self page] objectSpecifier];
    return [[NSUniqueIDSpecifier alloc
             ] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"notes" uniqueID:[self uniqueID]];
}

- (NSString *)uniqueID {
    return [NSString stringWithFormat:@"%p", (void *)self];
}

// overridden by subclasses to add or remove custom scripting keys relevant for the class, subclasses should call super first
+ (NSSet *)customScriptingKeys {
    static NSSet *customScriptingKeys = nil;
    if (customScriptingKeys == nil)
        customScriptingKeys = [[NSSet alloc] initWithObjects:SKNPDFAnnotationLineWidthKey, SKNPDFAnnotationBorderStyleKey, SKNPDFAnnotationDashPatternKey, nil];
    return customScriptingKeys;
}

- (NSDictionary *)scriptingProperties {
    static NSSet *allCustomScriptingKeys = nil;
    if (allCustomScriptingKeys == nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSMutableSet *customScriptingKeys = [NSMutableSet set];
        [customScriptingKeys unionSet:[PDFAnnotationCircle customScriptingKeys]];
        [customScriptingKeys unionSet:[PDFAnnotationSquare customScriptingKeys]];
        [customScriptingKeys unionSet:[PDFAnnotationFreeText customScriptingKeys]];
        [customScriptingKeys unionSet:[SKNPDFAnnotationNote customScriptingKeys]];
        [customScriptingKeys unionSet:[PDFAnnotationMarkup customScriptingKeys]];
        [customScriptingKeys unionSet:[PDFAnnotationLine customScriptingKeys]];
        [customScriptingKeys unionSet:[PDFAnnotationInk customScriptingKeys]];
        allCustomScriptingKeys = [customScriptingKeys copy];
#pragma clang diagnostic pop
    }
    // remove all custom properties that are not valid for this class
    NSMutableDictionary *properties = [[super scriptingProperties] mutableCopy];
    NSMutableSet *customKeys = [allCustomScriptingKeys mutableCopy];
    [customKeys minusSet:[[self class] customScriptingKeys]];
    [properties removeObjectsForKeys:[customKeys allObjects]];
    return properties;
}

- (void)setScriptingProperties:(NSDictionary *)properties {
    [super setScriptingProperties:properties];
    // set the borderStyle afterwards, as this may have been changed when setting the dash pattern
    id style = [properties objectForKey:SKNPDFAnnotationBorderStyleKey];
    if ([style respondsToSelector:@selector(integerValue)] && [properties objectForKey:SKNPDFAnnotationDashPatternKey])
        [self setBorderStyle:[style integerValue]];
}

- (NSColor *)scriptingColor {
    return [self color];
}

- (void)setScriptingColor:(NSColor *)newColor {
    if ([self isEditable]) {
        [self setColor:newColor];
    }
}

- (PDFPage *)scriptingPage {
    return [self page];
}

- (NSDate *)scriptingModificationDate {
    return [self modificationDate];
}

- (void)setScriptingModificationDate:(NSDate *)date {
    if ([self isEditable]) {
        [self setModificationDate:date];
    }
}

- (NSString *)scriptingUserName {
    return [self userName];
}

- (void)setScriptingUserName:(NSString *)name {
    if ([self isEditable]) {
        [self setUserName:name];
    }
}

- (PDFTextAnnotationIconType)scriptingIconType {
    return kPDFTextAnnotationIconNote;
}

- (id)textContents;
{
    return [[NSTextStorage alloc] initWithString:[self string] ?: @""];
}

- (void)setTextContents:(id)text;
{
    if ([self isEditable]) {
        [self setString:[text string]];
    }
}

- (id)coerceValueForTextContents:(id)value {
    if ([value isKindOfClass:[NSScriptObjectSpecifier class]])
        value = [(NSScriptObjectSpecifier *)value objectsByEvaluatingSpecifier];
    return [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:value toClass:[NSTextStorage class]];
}

- (id)richText {
    return nil;
}

- (void)setBoundsAsQDRect:(NSData *)inQDBoundsAsData {
    if ([self isMovable] && [self isEditable]) {
        NSRect newBounds = [inQDBoundsAsData rectValueAsQDRect];
        if ([self isResizable] == NO) {
            newBounds.size = [self bounds].size;
        } else {
            if (NSWidth(newBounds) < 0.0)
                newBounds.size.width = 0.0;
            if (NSHeight(newBounds) < 0.0)
                newBounds.size.height = 0.0;
        }
        [self setBounds:newBounds];
    }

}

- (NSData *)boundsAsQDRect {
    return [NSData dataWithRectAsQDRect:[self bounds]];
}

- (NSColor *)scriptingInteriorColor {
    return nil;
}

- (NSString *)fontName {
    return nil;
}

- (CGFloat)fontSize {
    return 0;
}

- (NSColor *)scriptingFontColor {
    return nil;
}

- (NSInteger)scriptingAlignment {
    return NSTextAlignmentLeft;
}

- (NSData *)startPointAsQDPoint {
    return nil;
}

- (NSData *)endPointAsQDPoint {
    return nil;
}

- (PDFLineStyle)scriptingStartLineStyle {
    return kPDFLineStyleNone;
}

- (PDFLineStyle)scriptingEndLineStyle {
    return kPDFLineStyleNone;
}

- (id)selectionSpecifier {
    return nil;
}

- (NSArray *)scriptingPointLists {
    return nil;
}

- (void)handleEditScriptCommand:(NSScriptCommand *)command {
    if ([self isEditable]) {
        NSDocument *doc = [[self page] containingDocument];
        if ([doc isPDFDocument])
            [[(SKMainDocument *)doc pdfView] editAnnotation:self];
    }
}

- (BOOL)accessibilityPerformPress {
    if ([self isSkimNote] == NO)
        return NO;
    NSDocument *doc = [[self page] containingDocument];
    if ([doc respondsToSelector:@selector(pdfView)] == NO)
        return NO;
    [[(SKMainDocument *)doc pdfView] editAnnotation:self];
    return YES;
}

- (BOOL)accessibilityPerformPick {
    if ([self isSkimNote] == NO)
        return NO;
    NSDocument *doc = [[self page] containingDocument];
    if ([doc respondsToSelector:@selector(pdfView)] == NO)
        return NO;
    [[(SKMainDocument *)doc pdfView] setCurrentAnnotation:self];
    return YES;
}

- (BOOL)accessibilityPerformShowMenu {
    if ([self isSkimNote] == NO)
        return NO;
    NSDocument *doc = [[self page] containingDocument];
    if ([doc respondsToSelector:@selector(pdfView)] == NO)
        return NO;
    PDFView *pdfView = [(SKMainDocument *)doc pdfView];
    NSPoint point = SKCenterPoint([pdfView convertRect:[self bounds] fromPage:[self page]]);
    NSEvent *event = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown
                                        location:[pdfView convertPoint:point toView:nil]
                                   modifierFlags:0
                                       timestamp:0
                                    windowNumber:[[pdfView window] windowNumber]
                                         context:nil
                                     eventNumber:0
                                      clickCount:1
                                        pressure:0.0];
    NSMenu *menu = [pdfView menuForEvent:event];
    [NSMenu popUpContextMenu:menu withEvent:event forView:pdfView];
    return YES;
}

@end
