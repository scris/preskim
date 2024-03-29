//
//  PDFDocument_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 2/17/08.
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

#import "PDFDocument_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "NSNumber_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "NSData_SKExtensions.h"
#import "NSDocument_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"

NSString *SKPDFDocumentDidAddAnnotationNotification = @"SKPDFDocumentDidAddAnnotationNotification";
NSString *SKPDFDocumentWillRemoveAnnotationNotification = @"SKPDFDocumentWillRemoveAnnotationNotification";
NSString *SKPDFDocumentDidRemoveAnnotationNotification = @"SKPDFDocumentDidRemoveAnnotationNotification";
NSString *SKPDFDocumentWillMoveAnnotationNotification = @"SKPDFDocumentWillMoveAnnotationNotification";
NSString *SKPDFDocumentDidMoveAnnotationNotification = @"SKPDFDocumentDidMoveAnnotationNotification";

NSString *SKPDFDocumentAnnotationKey = @"annotation";
NSString *SKPDFDocumentPageKey = @"page";
NSString *SKPDFDocumentOldPageKey = @"oldPage";

@implementation PDFDocument (SKExtensions)

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained *)stackbuf count:(NSUInteger)len {
    NSUInteger start = state->state;
    NSUInteger end = [self pageCount];
    if (start == 0)
        state->mutationsPtr = &state->extra[0];
    if (start < end) {
        NSUInteger i;
        end = MIN(end, start + len);
        state->itemsPtr = stackbuf;
        state->state = end;
        for (i = 0; i < end - start; i++)
            stackbuf[i] = [self pageAtIndex:i + start];
        return end - start;
    } else {
        return 0;
    }
}

- (NSArray *)pageLabels {
    NSUInteger pageCount = [self pageCount];
    NSMutableArray *pageLabels = [NSMutableArray array];
    BOOL useSequential = [[self pageClass] usesSequentialPageNumbering];
    if (useSequential == NO) {
        CGPDFDocumentRef doc = [self documentRef];
        CGPDFDictionaryRef catalog = CGPDFDocumentGetCatalog(doc);
        CGPDFDictionaryRef labelsDict = NULL;
        CGPDFArrayRef labelsArray = NULL;
        if (catalog) {
            if(false == CGPDFDictionaryGetDictionary(catalog, "PageLabels", &labelsDict)) {
                useSequential = YES;
            } else if (CGPDFDictionaryGetArray(labelsDict, "Nums", &labelsArray)) {
                size_t i = CGPDFArrayGetCount(labelsArray);
                CGPDFInteger j = pageCount;
                while (i > 0) {
                    CGPDFInteger labelIndex;
                    CGPDFDictionaryRef labelDict = NULL;
                    const char *labelStyle;
                    CGPDFStringRef labelPDFPrefix;
                    NSString *labelPrefix;
                    CGPDFInteger labelStart;
                    if (false == CGPDFArrayGetDictionary(labelsArray, --i, &labelDict) ||
                        false == CGPDFArrayGetInteger(labelsArray, --i, &labelIndex)) {
                        [pageLabels removeAllObjects];
                        break;
                    }
                    if (false == CGPDFDictionaryGetName(labelDict, "S", &labelStyle))
                        labelStyle = NULL;
                    if (CGPDFDictionaryGetString(labelDict, "P", &labelPDFPrefix))
                        labelPrefix = CFBridgingRelease(CGPDFStringCopyTextString(labelPDFPrefix));
                    else
                        labelPrefix = nil;
                    if (false == CGPDFDictionaryGetInteger(labelDict, "St", &labelStart))
                        labelStart = 1;
                    while (j > labelIndex) {
                        NSNumber *labelNumber = [NSNumber numberWithInteger:--j - labelIndex + labelStart];
                        NSMutableString *string = [NSMutableString string];
                        if (labelPrefix)
                            [string appendString:labelPrefix];
                        if (labelStyle) {
                            if (0 == strcmp(labelStyle, "D"))
                                [string appendFormat:@"%@", labelNumber];
                            else if (0 == strcmp(labelStyle, "R"))
                                [string appendString:[[labelNumber romanNumeralValue] uppercaseString]];
                            else if (0 == strcmp(labelStyle, "r"))
                                [string appendString:[labelNumber romanNumeralValue]];
                            else if (0 == strcmp(labelStyle, "A"))
                                [string appendString:[[labelNumber alphaCounterValue] uppercaseString]];
                            else if (0 == strcmp(labelStyle, "a"))
                                [string appendString:[labelNumber alphaCounterValue]];
                        }
                        [pageLabels insertObject:string atIndex:0];
                    }
                }
            }
        }
    }
    if ([pageLabels count] != pageCount) {
        NSUInteger i;
        [pageLabels removeAllObjects];
        for (i = 0; i < pageCount; i++)
            [pageLabels addObject:useSequential ? [NSString stringWithFormat:@"%lu", (unsigned long)(i + 1)] : [[self pageAtIndex:i] displayLabel]];
    }
    return pageLabels;
}

- (NSArray *)fileIDStrings {
    CGPDFDocumentRef doc = [self documentRef];
    CGPDFArrayRef idArray = CGPDFDocumentGetID(doc);
    
    if (idArray == NULL)
        return nil;
    
    NSMutableArray *fileIDStrings = [NSMutableArray array];
    size_t i, iMax = CGPDFArrayGetCount(idArray);
    
    for (i = 0; i < iMax; i++) {
        CGPDFStringRef idString;
        if (CGPDFArrayGetString(idArray, i, &idString)) {
            size_t j = 0, k = 0, length = CGPDFStringGetLength(idString);
            const unsigned char *inputBuffer = CGPDFStringGetBytePtr(idString);
            unsigned char outputBuffer[length * 2]; // length should be 16 so no need to malloc
            static unsigned char hexEncodeTable[17] = "0123456789abcdef";
            
            for (j = 0; j < length; j++) {
                outputBuffer[k++] = hexEncodeTable[(inputBuffer[j] & 0xF0) >> 4];
                outputBuffer[k++] = hexEncodeTable[(inputBuffer[j] & 0x0F)];
            }
            
            NSString *fileID = [[NSString alloc] initWithBytes:outputBuffer length:k encoding:NSASCIIStringEncoding];
            [fileIDStrings addObject:fileID];
        }
    }
    
    return fileIDStrings;
}

- (NSDictionary *)initialSettings {
    CGPDFDocumentRef doc = [self documentRef];
    CGPDFDictionaryRef catalog = CGPDFDocumentGetCatalog(doc);
    const char *pageLayout = NULL;
    CGPDFDictionaryRef viewerPrefs = NULL;
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    if (catalog) {
        if (CGPDFDictionaryGetName(catalog, "PageLayout", &pageLayout)) {
            if (0 == strcmp(pageLayout, "SinglePage")) {
                [settings setObject:[NSNumber numberWithInteger:kPDFDisplaySinglePage] forKey:@"displayMode"];
            } else if (0 == strcmp(pageLayout, "OneColumn")) {
                [settings setObject:[NSNumber numberWithInteger:kPDFDisplaySinglePageContinuous] forKey:@"displayMode"];
                [settings setObject:@0 forKey:@"displayDirection"];
            } else if (0 == strcmp(pageLayout, "TwoColumnLeft")) {
                [settings setObject:[NSNumber numberWithInteger:kPDFDisplayTwoUpContinuous] forKey:@"displayMode"];
                [settings setObject:@NO forKey:@"displaysAsBook"];
            } else if (0 == strcmp(pageLayout, "TwoColumnRight")) {
                [settings setObject:[NSNumber numberWithInteger:kPDFDisplayTwoUpContinuous] forKey:@"displayMode"];
                [settings setObject:@YES forKey:@"displaysAsBook"];
            } else if (0 == strcmp(pageLayout, "TwoPageLeft")) {
                [settings setObject:[NSNumber numberWithInteger:kPDFDisplayTwoUp] forKey:@"displayMode"];
                [settings setObject:@NO forKey:@"displaysAsBook"];
            } else if (0 == strcmp(pageLayout, "TwoPageRight")) {
                [settings setObject:[NSNumber numberWithInteger:kPDFDisplayTwoUp] forKey:@"displayMode"];
                [settings setObject:@YES forKey:@"displaysAsBook"];
            }
        }
        if (CGPDFDictionaryGetDictionary(catalog, "ViewerPreferences", &viewerPrefs)) {
            const char *direction = NULL;
            const char *viewArea = NULL;
            CGPDFBoolean fitWindow = false;
            if (CGPDFDictionaryGetName(viewerPrefs, "Direction", &direction)) {
                if (0 == strcmp(direction, "L2R"))
                    [settings setObject:@NO forKey:@"displaysRTL"];
                else if (0 == strcmp(direction, "R2L"))
                    [settings setObject:@YES forKey:@"displaysRTL"];
            }
            if (CGPDFDictionaryGetName(viewerPrefs, "ViewArea", &viewArea)) {
                if (0 == strcmp(viewArea, "CropBox"))
                    [settings setObject:[NSNumber numberWithInteger:kPDFDisplayBoxCropBox] forKey:@"displayBox"];
                else if (0 == strcmp(viewArea, "MediaBox"))
                    [settings setObject:[NSNumber numberWithInteger:kPDFDisplayBoxMediaBox] forKey:@"displayBox"];
            }
            if (CGPDFDictionaryGetBoolean(viewerPrefs, "FitWindow", &fitWindow))
                [settings setObject:[NSNumber numberWithBool:(BOOL)fitWindow] forKey:@"fitWindow"];
        }
    }
    return [settings count] > 0 ? settings : nil;
}

static inline NSInteger angleForDirection(NSLocaleLanguageDirection direction, BOOL isLine) {
    switch (direction) {
        case NSLocaleLanguageDirectionLeftToRight: return 0;
        case NSLocaleLanguageDirectionRightToLeft: return 180;
        case NSLocaleLanguageDirectionTopToBottom: return 270;
        case NSLocaleLanguageDirectionBottomToTop: return 90;
        case NSLocaleLanguageDirectionUnknown:
        default:                                   return isLine ? 270 : 0;
    }
}

- (SKLanguageDirectionAngles)languageDirectionAngles {
    CGPDFDocumentRef doc = [self documentRef];
    CGPDFDictionaryRef catalog = CGPDFDocumentGetCatalog(doc);
    SKLanguageDirectionAngles angles = (SKLanguageDirectionAngles){0, 270};
    if (catalog) {
        CGPDFStringRef lang = NULL;
        CGPDFDictionaryRef viewerPrefs = NULL;
        const char *direction = NULL;
        if (CGPDFDictionaryGetString(catalog, "Lang", &lang)) {
            NSString *language = CFBridgingRelease(CGPDFStringCopyTextString(lang));
            NSLocaleLanguageDirection characterDirection = [NSLocale characterDirectionForLanguage:language];
            NSLocaleLanguageDirection lineDirection = [NSLocale lineDirectionForLanguage:language];
            if (lineDirection == NSLocaleLanguageDirectionUnknown) {
                if (characterDirection < NSLocaleLanguageDirectionTopToBottom)
                    lineDirection = NSLocaleLanguageDirectionTopToBottom;
                else
                    lineDirection = NSLocaleLanguageDirectionLeftToRight;
            }
            if (characterDirection == NSLocaleLanguageDirectionUnknown) {
                if (lineDirection > NSLocaleLanguageDirectionRightToLeft)
                    characterDirection = NSLocaleLanguageDirectionLeftToRight;
                else
                    characterDirection = NSLocaleLanguageDirectionTopToBottom;
            }
            angles.characterDirection = angleForDirection(characterDirection, NO);
            angles.lineDirection = angleForDirection(lineDirection, YES);
        } else if (CGPDFDictionaryGetDictionary(catalog, "ViewerPreferences", &viewerPrefs) && CGPDFDictionaryGetName(viewerPrefs, "Direction", &direction)) {
            if (0 == strcmp(direction, "L2R"))
                angles.characterDirection = 0;
            else if (0 == strcmp(direction, "R2L"))
                angles.characterDirection = 180;
        }
    }
    return angles;
}

- (BOOL)allowsNotes {
    return [self isLocked] == NO && [self allowsCommenting];
}

- (BOOL)realAllowsCommenting {
    return [self allowsCommenting];
}

- (NSDocument *)containingDocument {
    NSDocument *document = nil;
    
    for (document in [[NSDocumentController sharedDocumentController] documents]) {
        if ([self isEqual:[document pdfDocument]])
            break;
    }
    
    return document;
}

- (void)setContainingDocument:(NSDocument *)document  {}

- (NSArray *)detectedWidgets { return nil; }

- (void)addAnnotation:(PDFAnnotation *)annotation toPage:(PDFPage *)page {
    NSDictionary *userInfo = @{SKPDFDocumentAnnotationKey:annotation, SKPDFDocumentPageKey:page};
    [page addAnnotation:annotation];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFDocumentDidAddAnnotationNotification object:self userInfo:userInfo];
}

- (void)removeAnnotation:(PDFAnnotation *)annotation {
    PDFPage *page = [annotation page];
    NSDictionary *userInfo = @{SKPDFDocumentAnnotationKey:annotation, SKPDFDocumentPageKey:page};
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFDocumentWillRemoveAnnotationNotification object:self userInfo:userInfo];
    [page removeAnnotation:annotation];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFDocumentDidRemoveAnnotationNotification object:self userInfo:userInfo];
}

- (void)moveAnnotation:(PDFAnnotation *)annotation toPage:(PDFPage *)page {
    PDFPage *oldPage = [annotation page];
    NSDictionary *userInfo = @{SKPDFDocumentAnnotationKey:annotation, SKPDFDocumentPageKey:page, SKPDFDocumentOldPageKey:oldPage};
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFDocumentWillMoveAnnotationNotification object:self userInfo:userInfo];
    [oldPage removeAnnotation:annotation];
    [page addAnnotation:annotation];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFDocumentDidMoveAnnotationNotification object:self userInfo:userInfo];
}

@end
