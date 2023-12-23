//
//  PDFAnnotation_SKExtensions.h
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

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <SkimNotes/SkimNotes.h>
#import "NSGeometry_SKExtensions.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *SKPDFAnnotationScriptingColorKey;
extern NSString *SKPDFAnnotationScriptingModificationDateKey;
extern NSString *SKPDFAnnotationScriptingUserNameKey;
extern NSString *SKPDFAnnotationScriptingTextContentsKey;
extern NSString *SKPDFAnnotationScriptingInteriorColorKey;

extern NSString *SKPDFAnnotationBoundsOrderKey;

extern NSString *SKPasteboardTypeSkimNote;

@class SKPDFView, SKNoteText;

@interface PDFAnnotation (SKExtensions) <NSPasteboardReading, NSPasteboardWriting>

+ (nullable PDFAnnotation *)newSkimNoteWithBounds:(NSRect)bounds forType:(NSString *)type;

+ (nullable PDFAnnotation *)newSkimNoteWithProperties:(NSDictionary<NSString *, id> *)dict;

+ (nullable PDFAnnotation *)newSkimNoteWithPaths:(NSArray<NSBezierPath *> *)paths;

+ (nullable PDFAnnotation *)newSkimNoteWithSelection:(PDFSelection *)selection forType:(NSString *)type;

+ (nullable NSArray<NSArray *> *)SkimNotesAndPagesWithSelection:(PDFSelection *)selection forType:(NSString *)type;

+ (NSDictionary<NSString *, id> *)textToNoteSkimNoteProperties:(NSDictionary<NSString *, id> *)properties;

@property (nonatomic, nullable, readonly) NSString *fdfString;

@property (nonatomic, readonly) NSUInteger pageIndex;

@property (nonatomic) PDFBorderStyle borderStyle;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, nullable, copy) NSArray<NSNumber *> *dashPattern;

@property (nonatomic) NSPoint observedStartPoint;
@property (nonatomic) NSPoint observedEndPoint;

@property (nonatomic, readonly) CGFloat pathInset;

@property (nonatomic, nullable, copy) NSArray<NSBezierPath *> *bezierPaths;

@property (nonatomic, nullable, readonly) NSArray<NSBezierPath *> *pagePaths;

@property (nonatomic, nullable, readonly) NSImage *image;
@property (nonatomic, nullable, readonly) NSAttributedString *text;

@property (nonatomic, readonly) BOOL hasNoteText;
@property (nonatomic, nullable, readonly) SKNoteText *noteText;

@property (nonatomic, nullable, readonly) PDFSelection *selection;

@property (nonatomic, nullable, strong) id objectValue;

@property (nonatomic, readonly) SKNPDFWidgetType widgetType;

@property (nonatomic, nullable, readonly) NSString *textString;

- (BOOL)isMarkup;
- (BOOL)isNote;
- (BOOL)isText;
- (BOOL)isLine;
- (BOOL)isInk;
- (BOOL)isLink;
- (BOOL)isWidget;
- (BOOL)isResizable;
- (BOOL)isMovable;
- (BOOL)isEditable;
- (BOOL)hasBorder;
- (BOOL)hasInteriorColor;

- (BOOL)isConvertibleAnnotation;

- (BOOL)hitTest:(NSPoint)point;

@property (nonatomic, readonly) CGFloat boundsOrder;

- (NSRect)displayRectForBounds:(NSRect)bounds lineWidth:(CGFloat)lineWidth;
@property (nonatomic, readonly) NSRect displayRect;

- (SKRectEdges)resizeHandleForPoint:(NSPoint)point scaleFactor:(CGFloat)scaleFactor;

- (void)drawSelectionHighlightWithLineWidth:(CGFloat)lineWidth active:(BOOL)active inContext:(CGContextRef)context;

- (void)registerUserName;

- (void)autoUpdateString;

@property (nonatomic, readonly) NSString *uniqueID;

- (void)setColor:(NSColor *)color alternate:(BOOL)alternate updateDefaults:(BOOL)update;

@property (nonatomic, nullable, readonly) NSURL *skimURL;

@property (nonatomic, readonly) NSSet *keysForValuesToObserveForUndo;

@property (class, nonatomic, readonly) NSSet *customScriptingKeys;
@property (nonatomic, readonly) NSScriptObjectSpecifier *objectSpecifier;
@property (nonatomic, nullable, copy) NSColor *scriptingColor;
@property (nonatomic, nullable, readonly) PDFPage *scriptingPage;
@property (nonatomic, nullable, copy) NSDate *scriptingModificationDate;
@property (nonatomic, nullable, copy) NSString *scriptingUserName;
@property (nonatomic, readonly) PDFTextAnnotationIconType scriptingIconType;
@property (nonatomic, nullable, copy) id textContents;
@property (nonatomic, nullable, readonly) id richText;
@property (nonatomic, copy) NSData *boundsAsQDRect;
@property (nonatomic, readonly) NSInteger scriptingAlignment;
@property (nonatomic, nullable, readonly) NSString *fontName;
@property (nonatomic, readonly) CGFloat fontSize;
@property (nonatomic, nullable, readonly) NSColor *scriptingFontColor;
@property (nonatomic, nullable, readonly) NSColor *scriptingInteriorColor;
@property (nonatomic, nullable, readonly) NSData *startPointAsQDPoint;
@property (nonatomic, nullable, readonly) NSData *endPointAsQDPoint;
@property (nonatomic, readonly) PDFLineStyle scriptingStartLineStyle;
@property (nonatomic, readonly) PDFLineStyle scriptingEndLineStyle;
@property (nonatomic, nullable, readonly) id selectionSpecifier;
@property (nonatomic, nullable, readonly) NSArray<NSArray<NSData *> *> *scriptingPointLists;

- (void)handleEditScriptCommand:(NSScriptCommand *)command;

@end

@interface PDFAnnotation (SKDefaultExtensions)
@property (nonatomic, nullable, readonly) NSColor *interiorColor;
@property (nonatomic, nullable, readonly) NSString *fieldName;
@end

NS_ASSUME_NONNULL_END
