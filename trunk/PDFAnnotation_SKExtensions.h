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


extern NSString *SKPDFAnnotationScriptingColorKey;
extern NSString *SKPDFAnnotationScriptingModificationDateKey;
extern NSString *SKPDFAnnotationScriptingUserNameKey;
extern NSString *SKPDFAnnotationScriptingTextContentsKey;
extern NSString *SKPDFAnnotationScriptingInteriorColorKey;

extern NSString *SKPDFAnnotationBoundsOrderKey;

extern NSString *SKPasteboardTypeSkimNote;

@class SKPDFView, SKNoteText;

@interface PDFAnnotation (SKExtensions) <NSPasteboardReading, NSPasteboardWriting>

+ (PDFAnnotation *)newSkimNoteWithBounds:(NSRect)bounds forType:(NSString *)type;

+ (PDFAnnotation *)newSkimNoteWithProperties:(NSDictionary *)dict;

+ (PDFAnnotation *)newSkimNoteWithPaths:(NSArray *)paths;

+ (PDFAnnotation *)newSkimNoteWithSelection:(PDFSelection *)selection forType:(NSString *)type;

+ (NSArray *)SkimNotesAndPagesWithSelection:(PDFSelection *)selection forType:(NSString *)type;

+ (NSDictionary *)textToNoteSkimNoteProperties:(NSDictionary *)properties;

@property (nonatomic, readonly) NSString *fdfString;

@property (nonatomic, readonly) NSUInteger pageIndex;

@property (nonatomic) PDFBorderStyle borderStyle;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, copy) NSArray *dashPattern;

@property (nonatomic) NSPoint observedStartPoint;
@property (nonatomic) NSPoint observedEndPoint;

@property (nonatomic, readonly) CGFloat pathInset;

@property (nonatomic, copy) NSArray *bezierPaths;

@property (nonatomic, readonly) NSArray *pagePaths;

@property (nonatomic, readonly) NSImage *image;
@property (nonatomic, readonly) NSAttributedString *text;

@property (nonatomic, readonly) BOOL hasNoteText;
@property (nonatomic, readonly) SKNoteText *noteText;

@property (nonatomic, readonly) PDFSelection *selection;

@property (nonatomic, retain) id objectValue;

@property (nonatomic, readonly) SKNPDFWidgetType widgetType;

@property (nonatomic, readonly) NSString *textString;

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

@property (nonatomic, readonly) NSURL *skimURL;

@property (nonatomic, readonly) NSSet *keysForValuesToObserveForUndo;

@property (class, nonatomic, readonly) NSSet *customScriptingKeys;
@property (nonatomic, readonly) NSScriptObjectSpecifier *objectSpecifier;
@property (nonatomic, copy) NSColor *scriptingColor;
@property (nonatomic, readonly) PDFPage *scriptingPage;
@property (nonatomic, copy) NSDate *scriptingModificationDate;
@property (nonatomic, copy) NSString *scriptingUserName;
@property (nonatomic, readonly) PDFTextAnnotationIconType scriptingIconType;
@property (nonatomic, copy) id textContents;
@property (nonatomic, readonly) id richText;
@property (nonatomic, copy) NSData *boundsAsQDRect;
@property (nonatomic, readonly) NSInteger scriptingAlignment;
@property (nonatomic, readonly) NSString *fontName;
@property (nonatomic, readonly) CGFloat fontSize;
@property (nonatomic, readonly) NSColor *scriptingFontColor;
@property (nonatomic, readonly) NSColor *scriptingInteriorColor;
@property (nonatomic, readonly) NSData *startPointAsQDPoint;
@property (nonatomic, readonly) NSData *endPointAsQDPoint;
@property (nonatomic, readonly) PDFLineStyle scriptingStartLineStyle;
@property (nonatomic, readonly) PDFLineStyle scriptingEndLineStyle;
@property (nonatomic, readonly) id selectionSpecifier;
@property (nonatomic, readonly) NSArray *scriptingPointLists;

- (void)handleEditScriptCommand:(NSScriptCommand *)command;

@end

@interface PDFAnnotation (SKDefaultExtensions)
@property (nonatomic, readonly) NSColor *interiorColor;
@property (nonatomic, readonly) NSString *fieldName;
@end
