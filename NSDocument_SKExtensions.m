//
//  NSDocument_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 5/23/08.
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

#import "NSDocument_SKExtensions.h"
#import <Quartz/Quartz.h>
#import "SKApplicationController.h"
#import "SKTemplateParser.h"
#import "NSFileManager_SKExtensions.h"
#import "SKDocumentController.h"
#import "SKAlias.h"
#import "SKInfoWindowController.h"
#import "SKFDFParser.h"
#import "PDFAnnotation_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "SKBookmarkSheetController.h"
#import "SKBookmarkController.h"
#import "SKBookmark.h"
#import "NSWindowController_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "SKTemplateManager.h"
#import "NSWindow_SKExtensions.h"
#import "SKStringConstants.h"
#import <SkimNotes/SkimNotes.h>
#import "NSPasteboard_SKExtensions.h"

#define SKDisableExportAttributesKey @"SKDisableExportAttributes"

NSString *SKDocumentFileURLDidChangeNotification = @"SKDocumentFileURLDidChangeNotification";


@implementation NSDocument (SKExtensions)

+ (BOOL)isPDFDocument { return NO; }

- (SKInteractionMode)systemInteractionMode { return SKNormalMode; }

- (NSWindow *)mainWindow {
    return [[[self windowControllers] firstObject] window];
}

- (IBAction)copyURL:(id)sender {
    NSURL *fileURL = [self fileURL];
    if (fileURL) {
        NSURLComponents *components = [[NSURLComponents alloc] initWithURL:fileURL resolvingAgainstBaseURL:NO];
        [components setScheme:@"pskn"];
        NSURL *skimURL = [components URL];
        if (skimURL) {
            NSPasteboard *pboard = [NSPasteboard generalPasteboard];
            [pboard clearContents];
            [pboard writeURLs:@[skimURL] names:@[[self displayName]]];
        } else {
            NSBeep();
        }
    } else {
        NSBeep();
    }
}

- (NSMenu *)notesMenu { return nil; }

#pragma mark Document Setup

- (void)saveRecentDocumentInfo {}

- (void)applySetup:(NSDictionary *)setup {}

- (void)applyOptions:(NSDictionary *)options {}

// these are necessary for the app controller, we may change it there
- (NSDictionary *)currentDocumentSetup {
    NSMutableDictionary *setup = [NSMutableDictionary dictionary];
    NSURL *fileURL = [self fileURL];
    
    if (fileURL) {
        [setup setObject:[fileURL path] forKey:SKDocumentSetupFileNameKey];
        
        SKAlias *alias = [[SKAlias alloc] initWithURL:fileURL];
        NSData *data = [alias data];
        if (data)
            [setup setObject:data forKey:[alias isBookmark] ? SKDocumentSetupBookmarkKey : SKDocumentSetupAliasKey];
    }
    
    NSWindow *window = [self mainWindow];
    if (window)
        [setup setObject:NSStringFromRect([window frame]) forKey:SKDocumentSetupWindowFrameKey];
    
    NSArray *windows = [[NSApp orderedDocuments] valueForKey:@"mainWindow"];
    NSString *tabs = [[self mainWindow] tabIndexesInWindows:windows];
    if (tabs)
        [setup setObject:tabs forKey:SKDocumentSetupTabsKey];
    
    return setup;
}

#pragma mark Bookmark Actions

enum { SKAddBookmarkTypeBookmark, SKAddBookmarkTypeSetup, SKAddBookmarkTypeSession };

- (IBAction)addBookmark:(id)sender {
    NSInteger addBookmarkType = [sender tag];
    SKBookmarkSheetController *bookmarkSheetController = [[SKBookmarkSheetController alloc] init];
	[bookmarkSheetController setStringValue:[self displayName]];
    [bookmarkSheetController beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK) {
                NSString *label = [bookmarkSheetController stringValue];
                SKBookmark *folder = [bookmarkSheetController selectedFolder] ?: [[SKBookmarkController sharedBookmarkController] bookmarkRoot];
                SKBookmark *bookmark = nil;
                switch (addBookmarkType) {
                    case SKAddBookmarkTypeBookmark:
                    {
                        PDFPage *page = [self currentPage];
                        NSUInteger pageIndex = page ? [page pageIndex] : NSNotFound;
                        bookmark = [[SKBookmark alloc] initWithURL:[self fileURL] pageIndex:pageIndex label:label];
                        break;
                    }
                    case SKAddBookmarkTypeSetup:
                    {
                        NSDictionary *setup = [self currentDocumentSetup];
                        bookmark = [[SKBookmark alloc] initWithSetup:setup label:label];
                        break;
                    }
                    case SKAddBookmarkTypeSession:
                    {
                        NSArray *setups = [[NSApp orderedDocuments] valueForKey:@"currentDocumentSetup"];
                        bookmark = [[SKBookmark alloc] initSessionWithSetups:setups label:label];
                        break;
                    }
                    default:
                        break;
                }
                if (bookmark) {
                    SKBookmarkController *bookmarks = [SKBookmarkController sharedBookmarkController];
                    NSUInteger i = [[[folder children] valueForKey:@"label"] indexOfObject:[bookmark label]];
                    if (i != NSNotFound) {
                        [[bookmarkSheetController window] orderOut:nil];
                        NSAlert *alert = [[NSAlert alloc] init];
                        [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"\"%@\" already exists", @"Message text in alert dialog when getting duplicate bookmark label"), [bookmark label]]];
                        [alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"An item named \"%@\" already exists in this location. Do you want to replace it with this bookmark?", @"Informative text in alert dialog when getting duplicate bookmark label"), [bookmark label]]];
                        [alert addButtonWithTitle:NSLocalizedString(@"Replace", @"button title")];
                        [alert addButtonWithTitle:NSLocalizedString(@"Add", @"button title")];
                        [alert beginSheetModalForWindow:[self windowForSheet] completionHandler:^(NSModalResponse returnCode){
                            if (returnCode == NSAlertFirstButtonReturn)
                                [bookmarks replaceBookmarkAtIndex:i ofBookmark:folder withBookmark:bookmark animate:YES];
                            else
                                [bookmarks insertBookmark:bookmark atIndex:[folder countOfChildren] ofBookmark:folder animate:YES];
                        }];
                    } else {
                        [bookmarks insertBookmark:bookmark atIndex:[folder countOfChildren] ofBookmark:folder animate:YES];
                    }
                }
            }
        }];
}

- (void)share:(id)sender {
    NSURL *fileURL = [self fileURL];
    if (fileURL) {
        NSSharingService *service = [sender representedObject];
        [service setSubject:[self displayName]];
        [service performWithItems:@[fileURL]];
    } else {
        NSBeep();
    }
}

#pragma mark PDF Document

- (PDFDocument *)pdfDocument { return nil; }

- (PDFDocument *)placeholderPdfDocument { return nil; }

#pragma mark Notes

- (BOOL)hasNotes { return [[self notes] count] > 0; }

- (NSArray *)notes { return nil; }

- (NSArray *)SkimNoteProperties {
    return [[self notes] valueForKey:@"SkimNoteProperties"];
}

- (NSData *)notesData {
    NSArray *array = [self SkimNoteProperties];
    return SKNDataFromSkimNotes(array, [[NSUserDefaults standardUserDefaults] boolForKey:SKWriteLegacySkimNotesKey] == NO && [[NSUserDefaults standardUserDefaults] boolForKey:SKWriteSkimNotesAsArchiveKey] == NO);
}

- (NSString *)notesStringForTemplateType:(NSString *)typeName {
    NSString *string = nil;
    if ([[SKTemplateManager sharedManager] isRichTextTemplateType:typeName] == NO) {
        NSURL *templateURL = [[SKTemplateManager sharedManager] URLForTemplateType:typeName];
        NSError *error = nil;
        NSString *templateString = [[NSString alloc] initWithContentsOfURL:templateURL encoding:NSUTF8StringEncoding error:&error];
        string = [SKTemplateParser stringByParsingTemplateString:templateString usingObject:self];
    }
    return string;
}

- (NSData *)notesDataForTemplateType:(NSString *)typeName {
    NSData *data = nil;
    if ([[SKTemplateManager sharedManager] isRichTextTemplateType:typeName]) {
        NSURL *templateURL = [[SKTemplateManager sharedManager] URLForTemplateType:typeName];
        NSDictionary *docAttributes = nil;
        NSError *error = nil;
        NSAttributedString *templateAttrString = [[NSAttributedString alloc] initWithURL:templateURL options:@{} documentAttributes:&docAttributes error:NULL];
        NSAttributedString *attrString = [SKTemplateParser attributedStringByParsingTemplateAttributedString:templateAttrString usingObject:self];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableExportAttributesKey] == NO) {
            NSMutableDictionary *mutableAttributes = [docAttributes mutableCopy];
            [mutableAttributes addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:NSFullUserName(), NSAuthorDocumentAttribute, [NSDate date], NSCreationTimeDocumentAttribute, [[[[self fileURL] path] lastPathComponent] stringByDeletingPathExtension], NSTitleDocumentAttribute, nil]];
            docAttributes = mutableAttributes;
        }
        data = [attrString dataFromRange:NSMakeRange(0, [attrString length]) documentAttributes:docAttributes error:&error];
    } else {
        data = [[self notesStringForTemplateType:typeName] dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    }
    return data;
}

- (NSFileWrapper *)notesFileWrapperForTemplateType:(NSString *)typeName {
    NSFileWrapper *fileWrapper = nil;
    if ([[SKTemplateManager sharedManager] isRichTextBundleTemplateType:typeName]) {
        NSURL *templateURL = [[SKTemplateManager sharedManager] URLForTemplateType:typeName];
        NSDictionary *docAttributes = nil;
        NSAttributedString *templateAttrString = [[NSAttributedString alloc] initWithURL:templateURL options:@{} documentAttributes:&docAttributes error:NULL];
        NSAttributedString *attrString = [SKTemplateParser attributedStringByParsingTemplateAttributedString:templateAttrString usingObject:self];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableExportAttributesKey] == NO) {
            NSMutableDictionary *mutableAttributes = [docAttributes mutableCopy];
            [mutableAttributes addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:NSFullUserName(), NSAuthorDocumentAttribute, [NSDate date], NSCreationTimeDocumentAttribute, [[[[self fileURL] path] lastPathComponent] stringByDeletingPathExtension], NSTitleDocumentAttribute, nil]];
            docAttributes = mutableAttributes;
        }
        fileWrapper = [attrString RTFDFileWrapperFromRange:NSMakeRange(0, [attrString length]) documentAttributes:docAttributes];
    }
    return fileWrapper;
}

- (NSString *)notesString {
    return [self notesStringForTemplateType:SKNotesTextDocumentType];
}

- (NSData *)notesRTFData {
    return [self notesDataForTemplateType:SKNotesRTFDocumentType];
}

- (NSData *)notesFDFDataForFile:(NSString *)filename fileIDStrings:(NSArray *)fileIDStrings {
    NSInteger i = 0;
    NSMutableString *string = [NSMutableString stringWithFormat:@"%%FDF-1.2\n%%%C%C%C%C\n", (unichar)0xe2, (unichar)0xe3, (unichar)0xcf, (unichar)0xd3];
    NSMutableString *annots = [NSMutableString string];
    for (PDFAnnotation *note in [self notes]) {
        [string appendFormat:@"%ld 0 obj<<%@>>\nendobj\n", (long)(++i), [note fdfString]];
        [annots appendFormat:@"%ld 0 R ", (long)i];
    }
    [string appendFormat:@"%ld 0 obj<<", (long)(++i)];
    [string appendFDFName:SKFDFFDFKey];
    [string appendString:@"<<"];
    [string appendFDFName:SKFDFAnnotationsKey];
    [string appendFormat:@"[%@]", annots];
    [string appendFDFName:SKFDFFileKey];
    [string appendString:@"("];
    if (filename)
        [string appendString:[[filename lossyStringUsingEncoding:NSISOLatin1StringEncoding] stringByEscapingParenthesis]];
    [string appendString:@")"];
    if ([fileIDStrings count] == 2) {
        [string appendFDFName:SKFDFFileIDKey];
        [string appendFormat:@"[<%@><%@>]", [fileIDStrings objectAtIndex:0], [fileIDStrings objectAtIndex:1]];
    }
    [string appendString:@">>"];
    [string appendString:@">>\nendobj\n"];
    [string appendString:@"trailer\n<<"];
    [string appendFDFName:SKFDFRootKey];
    [string appendFormat:@" %ld 0 R", (long)i];
    [string appendString:@">>\n"];
    [string appendString:@"%%EOF\n"];
    return [string dataUsingEncoding:NSISOLatin1StringEncoding];
}
#pragma mark Outlines

- (BOOL)isOutlineExpanded:(PDFOutline *)outline { return NO; }

- (void)setExpanded:(BOOL)flag forOutline:(PDFOutline *)outline {}

#pragma mark Scripting

- (NSUInteger)countOfPages {
    return [[self pdfDocument] pageCount];
}

- (PDFPage *)objectInPagesAtIndex:(NSUInteger)theIndex {
    return [[self pdfDocument] pageAtIndex:theIndex];
}

- (NSUInteger)countOfOutlines { return 0; }

- (PDFOutline *)objectInOutlinesAtIndex:(NSUInteger)idx { return nil; }

- (PDFPage *)currentPage { return nil; }

- (void)setCurrentPage:(PDFPage *)page {}

- (NSData *)currentQDPoint { return nil; }

- (PDFAnnotation *)activeNote { return nil; }

- (NSTextStorage *)richText { return nil; }

- (id)selectionSpecifier { return nil; }

- (NSData *)selectionQDRect { return nil; }

- (id)selectionPage { return nil; }

- (NSArray *)noteSelection { return nil; }

- (void)setNoteSelection:(NSArray *)newNoteSelection {}

- (NSDictionary *)pdfViewSettings { return nil; }

- (NSInteger)toolMode { return 0; }

- (NSInteger)scriptingInteractionMode { return 0; }

- (NSDocument *)presentationNotesDocument { return nil; }

- (NSInteger)presentationNotesOffset { return 0; }

- (NSDictionary *)documentAttributes {
    return [[SKInfoWindowController sharedInstance] infoForDocument:self];
}

- (NSDictionary *)scriptingInfo {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    for (NSString *key in [[SKInfoWindowController sharedInstance] keys])
        [info setObject:[NSNull null] forKey:key];
    [info addEntriesFromDictionary:[self documentAttributes]];
    return info;
}

- (BOOL)isPDFDocument { return NO; }

- (id)readingBar { return nil; }

- (BOOL)hasReadingBar { return NO; }

- (void)handleRevertScriptCommand:(NSScriptCommand *)command {
    if ([self fileURL] && [[self fileURL] checkResourceIsReachableAndReturnError:NULL]) {
        if ([self revertToContentsOfURL:[self fileURL] ofType:[self fileType] error:NULL] == NO) {
            [command setScriptErrorNumber:NSInternalScriptError];
            [command setScriptErrorString:@"Revert failed."];
        }
    } else {
        [command setScriptErrorNumber:NSArgumentsWrongScriptError];
        [command setScriptErrorString:@"File does not exist."];
    }
}

- (void)handleGoToScriptCommand:(NSScriptCommand *)command {
    [command setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [command setScriptErrorString:@"Notes document does not understand the 'go' command."];
}

- (id)handleFindScriptCommand:(NSScriptCommand *)command {
    [command setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [command setScriptErrorString:@"Notes document does not understand the 'find' command."];
    return nil;
}

- (void)handleShowTeXScriptCommand:(NSScriptCommand *)command {
    [command setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [command setScriptErrorString:@"Notes document does not understand the 'show TeX file' command."];
}

- (void)handleConvertNotesScriptCommand:(NSScriptCommand *)command {
    [command setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [command setScriptErrorString:@"Notes document does not understand the 'convert notes' command."];
}

- (void)handleReadNotesScriptCommand:(NSScriptCommand *)command {
    [command setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [command setScriptErrorString:@"Notes document does not understand the 'read notes' command."];
}

@end
