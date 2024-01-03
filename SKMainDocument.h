//
//  SKMainDocument.h
//  Skim
//
//  Created by Michael McCracken on 12/5/06.
/*
 This software is Copyright (c) 2006
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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
#import "SKPDFSynchronizer.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *SKSkimFileDidSaveNotification;

@class PDFDocument, SKMainWindowController, SKPDFView, SKLine, SKProgressController, SKTemporaryData, SKFileUpdateChecker, SKExportAccessoryController, PDFAnnotation, SKSnapshotWindowController;

@interface SKMainDocument : NSDocument <SKPDFSynchronizerDelegate>
{
    SKMainWindowController *mainWindowController;
    
    // variables to be saved:
    NSData *pdfData;
    NSData *originalData;
    
    // temporary variables:
    SKTemporaryData *tmpData;
    
    NSMapTable *pageOffsets;
    
    SKPDFSynchronizer *synchronizer;
    
    SKFileUpdateChecker *fileUpdateChecker;
    
    SKExportAccessoryController *exportAccessoryController;
    
    struct _mdFlags {
        unsigned int exportOption:2;
        unsigned int exportUsingPanel:1;
        unsigned int gettingFileType:1;
        unsigned int convertingNotes:1;
        unsigned int needsPasswordToConvert:1;
    } mdFlags;
}

- (IBAction)readNotes:(nullable id)sender;
- (IBAction)convertNotes:(nullable id)sender;
- (IBAction)moveToTrash:(nullable id)sender;

@property (nonatomic, nullable, readonly) SKMainWindowController *mainWindowController;
@property (nonatomic, nullable, readonly) PDFDocument *pdfDocument;

@property (nonatomic, nullable, readonly) SKPDFView *pdfView;

- (void)savePasswordInKeychain:(NSString *)password;

@property (nonatomic, readonly) SKPDFSynchronizer *synchronizer;

@property (nonatomic, nullable, readonly) NSArray<SKSnapshotWindowController *> *snapshots;

@property (nonatomic, nullable, readonly) NSArray<NSString *> *tags;
@property (nonatomic, readonly) double rating;

@property (nonatomic, nullable, readonly) NSArray<PDFAnnotation *> *notes;
- (PDFAnnotation *)valueInNotesWithUniqueID:(NSString *)aUniqueID;
- (void)insertObject:(PDFAnnotation *)newNote inNotesAtIndex:(NSUInteger)anIndex;
- (void)removeObjectFromNotesAtIndex:(NSUInteger)anIndex;

@property (nonatomic, nullable, strong) PDFPage *currentPage;
@property (nonatomic, nullable, strong) PDFAnnotation *activeNote;
@property (nonatomic, readonly) NSTextStorage *richText;
@property (nonatomic, nullable, copy) id selectionSpecifier;
@property (nonatomic, copy) NSData *selectionQDRect;
@property (nonatomic, nullable, strong) PDFPage *selectionPage;
@property (nonatomic, nullable, copy) NSDictionary<NSString *, id> *pdfViewSettings;

- (void)handleRevertScriptCommand:(NSScriptCommand *)command;
- (void)handleGoToScriptCommand:(NSScriptCommand *)command;
- (nullable id)handleFindScriptCommand:(NSScriptCommand *)command;
- (void)handleEditScriptCommand:(NSScriptCommand *)command;
- (void)handleConvertNotesScriptCommand:(NSScriptCommand *)command;
- (void)handleReadNotesScriptCommand:(NSScriptCommand *)command;

@end

NS_ASSUME_NONNULL_END
