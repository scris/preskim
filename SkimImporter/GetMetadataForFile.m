//
//  GetMetadataForFile.m
//  SkimImporter
//
//  Created by Christiaan Hofman on 5/21/07.
/*
 This software is Copyright (c) 2007
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

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <Quartz/Quartz.h>
#import <SkimNotesBase/SkimNotesBase.h>

static BOOL GetTextAndAttributesForPDFFile(NSURL *url, NSString **text, NSDictionary **info)
{
    PDFDocument *pdfDoc = [[PDFDocument alloc] initWithURL:url];
    if (pdfDoc) {
        if (text != NULL)
            *text = [pdfDoc string];
        if (info != NULL) {
            NSUInteger pageCount = [pdfDoc pageCount];
            NSSize size = pageCount ? [[pdfDoc pageAtIndex:0] boundsForBox:kPDFDisplayBoxCropBox].size : NSZeroSize;
            NSMutableDictionary *mutableInfo = [[pdfDoc documentAttributes] mutableCopy];
            [mutableInfo setValue:[NSString stringWithFormat: @"%ld.%ld", (long)[pdfDoc majorVersion], (long)[pdfDoc minorVersion]] forKey:@"Version"];
            [mutableInfo setValue:[NSNumber numberWithBool:[pdfDoc isEncrypted]] forKey:@"Encrypted"];
            [mutableInfo setValue:[NSNumber numberWithUnsignedInteger:pageCount] forKey:@"PageCount"];
            [mutableInfo setValue:[NSNumber numberWithDouble:size.width] forKey:@"PageWidth"];
            [mutableInfo setValue:[NSNumber numberWithDouble:size.height] forKey:@"PageHeight"];
            *info = mutableInfo;
        }
    }
    return pdfDoc != nil;
}

Boolean GetMetadataForFile(void* thisInterface, 
                           CFMutableDictionaryRef attributes, 
                           CFStringRef contentTypeUTI,
                           CFStringRef pathToFile)
{
    /* Pull any available metadata from the file at the specified path */
    /* Return the attribute keys and attribute values in the dict */
    /* Return TRUE if successful, FALSE if there was no data provided */
    Boolean success = false;
    
    @autoreleasepool{
        
        BOOL isSkimNotes = UTTypeConformsTo(contentTypeUTI, CFSTR("net.sourceforge.skim-app.skimnotes"));
        BOOL isPDFBundle = isSkimNotes == NO && UTTypeConformsTo(contentTypeUTI, CFSTR("net.sourceforge.skim-app.pdfd"));
        NSFileManager *fm = [NSFileManager defaultManager];
        
        success = [fm fileExistsAtPath:(__bridge NSString *)pathToFile] && (isSkimNotes || isPDFBundle);
        
        if (success) {
            NSURL *fileURL = [NSURL fileURLWithPath:(__bridge NSString *)pathToFile];
            NSArray *notes = nil;
            NSString *pdfText = nil;
            NSDictionary *info = nil;
            NSString *sourcePath = nil;
            
            if (isSkimNotes) {
                notes = [fm readSkimNotesFromSkimFileAtURL:fileURL error:NULL];
                sourcePath = [[(__bridge NSString *)pathToFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
            } else if (isPDFBundle) {
                notes = [fm readSkimNotesFromPDFBundleAtURL:fileURL error:NULL];
                NSString *textPath = [(__bridge NSString *)pathToFile stringByAppendingPathComponent:@"data.txt"];
                pdfText = [NSString stringWithContentsOfFile:textPath encoding:NSUTF8StringEncoding error:NULL];
                NSString *plistPath = [(__bridge NSString *)pathToFile stringByAppendingPathComponent:@"data.plist"];
                NSData *plistData = [NSData dataWithContentsOfFile:plistPath];
                info = plistData ? [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:NULL error:NULL] : nil;
                if (pdfText == nil || info == nil) {
                    NSString *pdfPath = [fm bundledFileWithExtension:@"pdf" inPDFBundleAtPath:(__bridge NSString *)pathToFile error:NULL];
                    if (pdfPath)
                        GetTextAndAttributesForPDFFile([NSURL fileURLWithPath:pdfPath], pdfText == nil ? &pdfText : NULL, info == nil ? &info : NULL);
                }
            }
            
            NSMutableString *textContent = [[NSMutableString alloc] init];
            
            if (notes) {
                NSEnumerator *noteEnum = [notes objectEnumerator];
                NSDictionary *note;
                while (note = [noteEnum nextObject]) {
                    NSString *contents = [note objectForKey:@"contents"];
                    if (contents) {
                        if ([textContent length])
                            [textContent appendString:@"\n\n"];
                        [textContent appendString:contents];
                    }
                    NSString *text = [[note objectForKey:@"text"] string];
                    if (text) {
                        if ([textContent length])
                            [textContent appendString:@"\n\n"];
                        [textContent appendString:text];
                    }
                }
            }
            
            if ([pdfText length]) {
                if ([textContent length])
                    [textContent appendString:@"\n\n"];
                [textContent appendString:pdfText];
            }
            
            if (info) {
                id value;
                id pageWidth = [info objectForKey:@"PageWidth"], pageHeight = [info objectForKey:@"PageHeight"];
                if ((value = [info objectForKey:@"Title"]))
                    CFDictionarySetValue(attributes, kMDItemTitle, (__bridge CFTypeRef)value);
                if ((value = [info objectForKey:@"Author"]))
                    CFDictionarySetValue(attributes, kMDItemAuthors, (__bridge CFTypeRef)value);
                if ((value = [info objectForKey:@"Keywords"]))
                    CFDictionarySetValue(attributes, kMDItemKeywords, (__bridge CFTypeRef)value);
                if ((value = [info objectForKey:@"Creator"]))
                    CFDictionarySetValue(attributes, kMDItemCreator, (__bridge CFTypeRef)value);
                if ((value = [info objectForKey:@"Producer"]))
                    CFDictionarySetValue(attributes, kMDItemEncodingApplications, (__bridge CFTypeRef)value);
                if ((value = [info objectForKey:@"Version"]))
                    CFDictionarySetValue(attributes, kMDItemVersion, (__bridge CFTypeRef)value);
                if ((value = [info objectForKey:@"Encrypted"]))
                    CFDictionarySetValue(attributes, kMDItemSecurityMethod, [value boolValue] ? CFSTR("Password Encrypted") : CFSTR("None"));
                if ((value = [info objectForKey:@"PageCount"]))
                    CFDictionarySetValue(attributes, kMDItemNumberOfPages, (__bridge CFTypeRef)value);
                if (pageWidth && pageHeight) {
                    CFDictionarySetValue(attributes, kMDItemPageWidth, (__bridge CFTypeRef)pageWidth);
                    CFDictionarySetValue(attributes, kMDItemPageHeight, (__bridge CFTypeRef)pageHeight);
                    CFDictionarySetValue(attributes, CFSTR("net_sourceforge_skim_app_dimensions"), (__bridge CFTypeRef)[NSString stringWithFormat:@"%@ x %@ points", pageWidth, pageHeight]);
                }
            }
            
            CFDictionarySetValue(attributes, kMDItemTextContent, (__bridge CFTypeRef)textContent);
            
            CFDictionarySetValue(attributes, kMDItemCreator, @"Skim");
            
            if (sourcePath && [[NSFileManager defaultManager] fileExistsAtPath:sourcePath])
                CFDictionarySetValue(attributes, kMDItemWhereFroms, (__bridge CFTypeRef)[NSArray arrayWithObjects:sourcePath, nil]);
            
            NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:(__bridge NSString *)pathToFile error:NULL];
            NSDate *date;
            if ((date = [fileAttributes objectForKey:NSFileModificationDate]))
                CFDictionarySetValue(attributes, kMDItemContentModificationDate, (__bridge CFTypeRef)date);
            if ((date = [fileAttributes objectForKey:NSFileCreationDate]))
                CFDictionarySetValue(attributes, kMDItemContentCreationDate, (__bridge CFTypeRef)date);
        }
        
    }
    
    return success;
}
