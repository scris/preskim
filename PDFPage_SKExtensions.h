//
//  PDFPage_SKExtensions.h
//  Skim
//
//  Created by Christiaan Hofman on 2/16/07.
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

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "NSValue_SKExtensions.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *SKPDFPageBoundsDidChangeNotification;

extern NSString *SKPDFPagePageKey;
extern NSString *SKPDFPageActionKey;
extern NSString *SKPDFPageActionCrop;
extern NSString *SKPDFPageActionResize;
extern NSString *SKPDFPageActionRotate;

@class SKMainDocument, SKReadingBar, SKLine;

@interface PDFPage (SKExtensions) <NSFilePromiseProviderDelegate>

@property (class, nonatomic) BOOL usesSequentialPageNumbering;

@property (nonatomic, readonly) NSRect foregroundRect;
@property (nonatomic, readonly) NSRect autoCropBox;
@property (nonatomic, readonly) NSRect boundingBox;

- (NSImage *)thumbnailWithSize:(CGFloat)size forBox:(PDFDisplayBox)box;
- (NSImage *)thumbnailWithSize:(CGFloat)size forBox:(PDFDisplayBox)box readingBar:(nullable SKReadingBar *)readingBar;
- (NSImage *)thumbnailWithSize:(CGFloat)size forBox:(PDFDisplayBox)box shadowBlurRadius:(CGFloat)shadowBlurRadius highlights:(nullable NSArray *)highlights;

- (NSAttributedString *)thumbnailAttachmentWithSize:(CGFloat)size;
@property (nonatomic, readonly) NSAttributedString *thumbnailAttachment;
@property (nonatomic, readonly) NSAttributedString *thumbnail512Attachment;
@property (nonatomic, readonly) NSAttributedString *thumbnail256Attachment;
@property (nonatomic, readonly) NSAttributedString *thumbnail128Attachment;
@property (nonatomic, readonly) NSAttributedString *thumbnail64Attachment;
@property (nonatomic, readonly) NSAttributedString *thumbnail32Attachment;

- (nullable NSData *)PDFDataForRect:(NSRect)rect;
- (nullable NSData *)TIFFDataForRect:(NSRect)rect;

- (nullable id<NSPasteboardWriting>)filePromiseForPageIndexes:(nullable NSIndexSet *)pageIndexes;
- (void)writeToClipboardForPageIndexes:(nullable NSIndexSet *)pageIndexes;

@property (nonatomic, nullable, readonly) NSURL *skimURL;

@property (nonatomic, nullable, readonly) NSPointerArray *lineRects;
- (NSInteger)indexOfLineRectAtPoint:(NSPoint)point lower:(BOOL)lower;

@property (nonatomic, readonly) NSUInteger pageIndex;
@property (nonatomic, readonly) NSString *sequentialLabel;
@property (nonatomic, readonly) NSString *displayLabel;

@property (nonatomic, readonly) NSInteger intrinsicRotation;
@property (nonatomic, readonly) NSInteger characterDirectionAngle;
@property (nonatomic, readonly) NSInteger lineDirectionAngle;

@property (nonatomic, readonly, getter=isEditable) BOOL editable;

- (NSAffineTransform *)affineTransformForBox:(PDFDisplayBox)box;

- (CGFloat)sortOrderForBounds:(NSRect)bounds;

@property (nonatomic, nullable, readonly) NSScriptObjectSpecifier *objectSpecifier;
@property (nonatomic, nullable, readonly) NSDocument *containingDocument;
@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic) NSInteger rotationAngle;
@property (nonatomic, nullable, copy) NSData *boundsAsQDRect;
@property (nonatomic, nullable, copy) NSData *mediaBoundsAsQDRect;
@property (nonatomic, nullable, readonly) NSData *contentBoundsAsQDRect;
@property (nonatomic, nullable, readonly) NSArray<NSData *> *lineBoundsAsQDRects;
- (NSUInteger)countOfLines;
- (SKLine *)objectInLinesAtIndex:(NSUInteger)anIndex;
@property (nonatomic, nullable, readonly) NSTextStorage *richText;
@property (nonatomic, nullable, readonly) NSArray<PDFAnnotation *> *notes;
- (nullable PDFAnnotation *)valueInNotesWithUniqueID:(NSString *)aUniqueID;
- (void)insertObject:(PDFAnnotation *)newNote inNotesAtIndex:(NSUInteger)index;
- (void)removeObjectFromNotesAtIndex:(NSUInteger)index;

- (nullable id)handleGrabScriptCommand:(NSScriptCommand *)command;

@end

NS_ASSUME_NONNULL_END
