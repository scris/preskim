//
//  NSDocument_SKExtensions.h
//  Skim
//
//  Created by Christiaan Hofman on 5/23/08.
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

NS_ASSUME_NONNULL_BEGIN

extern NSString *SKDocumentFileURLDidChangeNotification;

typedef NS_ENUM(NSInteger, SKInteractionMode) {
    SKNormalMode,
    SKFullScreenMode,
    SKPresentationMode
};

@class PDFDocument, PDFPage, PDFAnnotation;

@interface NSDocument (SKExtensions)

+ (BOOL)isPDFDocument;

@property (nonatomic, readonly) SKInteractionMode systemInteractionMode;

@property (nonatomic, nullable, readonly) NSWindow *mainWindow;

- (IBAction)copyURL:(nullable id)sender;

@property (nonatomic, nullable, readonly) NSMenu *notesMenu;

#pragma mark Document Setup

- (void)saveRecentDocumentInfo;
- (void)applySetup:(NSDictionary<NSString *, id> *)setup;
- (void)applyOptions:(NSDictionary<NSString *, id> *)options;
@property (nonatomic, nullable, readonly) NSDictionary<NSString *, id> *currentDocumentSetup;

#pragma mark PDF Document

@property (nonatomic, nullable, readonly) PDFDocument *pdfDocument;
@property (nonatomic, nullable, readonly) PDFDocument *placeholderPdfDocument;

#pragma mark Bookmark Actions

- (IBAction)addBookmark:(nullable id)sender;
- (IBAction)share:(nullable id)sender;

#pragma mark Notes

- (BOOL)hasNotes;

@property (nonatomic, nullable, readonly) NSArray<PDFAnnotation *> *notes;

@property (nonatomic, nullable, readonly) NSArray<NSDictionary<NSString *, id> *> *SkimNoteProperties;

@property (nonatomic, nullable, readonly) NSData *notesData;

- (nullable NSString *)notesStringForTemplateType:(NSString *)typeName;
- (nullable NSData *)notesDataForTemplateType:(NSString *)typeName;
- (nullable NSFileWrapper *)notesFileWrapperForTemplateType:(NSString *)typeName;

@property (nonatomic, readonly) NSString *notesString;
@property (nonatomic, readonly) NSData *notesRTFData;

- (nullable NSData *)notesFDFDataForFile:(NSString *)filename fileIDStrings:(nullable NSArray *)fileIDStrings;

#pragma mark Outlines

- (BOOL)isOutlineExpanded:(PDFOutline *)outline;
- (void)setExpanded:(BOOL)flag forOutline:(PDFOutline *)outline;

#pragma mark Scripting

- (NSUInteger)countOfPages;
- (PDFPage *)objectInPagesAtIndex:(NSUInteger)theIndex;

- (NSUInteger)countOfOutlines;
- (PDFOutline *)objectInOutlinesAtIndex:(NSUInteger)idx;

@property (nonatomic, nullable, strong) PDFPage *currentPage;
@property (nonatomic, nullable, readonly) NSData *currentQDPoint;
@property (nonatomic, nullable, readonly) PDFAnnotation *activeNote;
@property (nonatomic, nullable, readonly) NSTextStorage *richText;
@property (nonatomic, nullable, readonly) id selectionSpecifier;
@property (nonatomic, nullable, readonly) NSData *selectionQDRect;
@property (nonatomic, nullable, readonly) id selectionPage;
@property (nonatomic, nullable, strong) NSArray<PDFAnnotation *> *noteSelection;
@property (nonatomic, nullable, readonly) NSDictionary<NSString *, id> *pdfViewSettings;
@property (nonatomic, nullable, readonly) NSDictionary<NSString *, id> *documentAttributes;
@property (nonatomic, readonly, getter=isPDFDocument) BOOL PDFDocument;
@property (nonatomic, readonly) NSInteger toolMode;
@property (nonatomic, readonly) NSInteger scriptingInteractionMode;
@property (nonatomic, nullable, readonly) NSDocument *presentationNotesDocument;
@property (nonatomic, readonly) NSInteger presentationNotesOffset;
@property (nonatomic, nullable, readonly) id readingBar;
@property (nonatomic, readonly) BOOL hasReadingBar;

- (void)handleRevertScriptCommand:(NSScriptCommand *)command;
- (void)handleGoToScriptCommand:(NSScriptCommand *)command;
- (nullable id)handleFindScriptCommand:(NSScriptCommand *)command;
- (void)handleShowTeXScriptCommand:(NSScriptCommand *)command;
- (void)handleConvertNotesScriptCommand:(NSScriptCommand *)command;
- (void)handleReadNotesScriptCommand:(NSScriptCommand *)command;

@end

NS_ASSUME_NONNULL_END
