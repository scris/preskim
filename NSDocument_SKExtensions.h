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
#import <Quartz/Quartz.h>

extern NSString *SKDocumentFileURLDidChangeNotification;

typedef NS_ENUM(NSInteger, SKInteractionMode) {
    SKNormalMode,
    SKFullScreenMode,
    SKPresentationMode
};

@interface NSDocument (SKExtensions)

+ (BOOL)isPDFDocument;

@property (nonatomic, readonly) SKInteractionMode systemInteractionMode;

@property (nonatomic, readonly) NSWindow *mainWindow;

- (IBAction)copyURL:(id)sender;

@property (nonatomic, readonly) NSMenu *notesMenu;

#pragma mark Document Setup

- (void)saveRecentDocumentInfo;
- (void)applySetup:(NSDictionary *)setup;
- (void)applyOptions:(NSDictionary *)options;
@property (nonatomic, readonly) NSDictionary *currentDocumentSetup;

#pragma mark PDF Document

@property (nonatomic, readonly) PDFDocument *pdfDocument;
@property (nonatomic, readonly) PDFDocument *placeholderPdfDocument;

#pragma mark Bookmark Actions

- (IBAction)addBookmark:(id)sender;
- (IBAction)share:(id)sender;

#pragma mark Notes

- (BOOL)hasNotes;

@property (nonatomic, readonly) NSArray *notes;

@property (nonatomic, readonly) NSArray *SkimNoteProperties;

@property (nonatomic, readonly) NSData *notesData;

- (NSString *)notesStringForTemplateType:(NSString *)typeName;
- (NSData *)notesDataForTemplateType:(NSString *)typeName;
- (NSFileWrapper *)notesFileWrapperForTemplateType:(NSString *)typeName;

@property (nonatomic, readonly) NSString *notesString;
@property (nonatomic, readonly) NSData *notesRTFData;

- (NSData *)notesFDFDataForFile:(NSString *)filename fileIDStrings:(NSArray *)fileIDStrings;

#pragma mark Outlines

- (BOOL)isOutlineExpanded:(PDFOutline *)outline;
- (void)setExpanded:(BOOL)flag forOutline:(PDFOutline *)outline;

#pragma mark Scripting

- (NSArray *)pages;
- (NSUInteger)countOfPages;
- (PDFPage *)objectInPagesAtIndex:(NSUInteger)theIndex;

- (NSUInteger)countOfOutlines;
- (PDFOutline *)objectInOutlinesAtIndex:(NSUInteger)idx;

@property (nonatomic, strong) PDFPage *currentPage;
@property (nonatomic, readonly) NSData *currentQDPoint;
@property (nonatomic, readonly) PDFAnnotation *activeNote;
@property (nonatomic, readonly) NSTextStorage *richText;
@property (nonatomic, readonly) id selectionSpecifier;
@property (nonatomic, readonly) NSData *selectionQDRect;
@property (nonatomic, readonly) id selectionPage;
@property (nonatomic, strong) NSArray *noteSelection;
@property (nonatomic, readonly) NSDictionary *pdfViewSettings;
@property (nonatomic, readonly) NSDictionary *documentAttributes;
@property (nonatomic, readonly, getter=isPDFDocument) BOOL PDFDocument;
@property (nonatomic, readonly) NSInteger toolMode;
@property (nonatomic, readonly) NSInteger scriptingInteractionMode;
@property (nonatomic, readonly) NSDocument *presentationNotesDocument;
@property (nonatomic, readonly) NSInteger presentationNotesOffset;
@property (nonatomic, readonly) id readingBar;
@property (nonatomic, readonly) BOOL hasReadingBar;

- (void)handleRevertScriptCommand:(NSScriptCommand *)command;
- (void)handleGoToScriptCommand:(NSScriptCommand *)command;
- (id)handleFindScriptCommand:(NSScriptCommand *)command;
- (void)handleShowTeXScriptCommand:(NSScriptCommand *)command;
- (void)handleConvertNotesScriptCommand:(NSScriptCommand *)command;
- (void)handleReadNotesScriptCommand:(NSScriptCommand *)command;

@end
