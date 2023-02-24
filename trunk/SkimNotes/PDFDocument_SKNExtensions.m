//
//  PDFDocument_SKNExtensions.m
//  SkimNotes
//
//  Created by Christiaan Hofman on 6/15/08.
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

#import "PDFDocument_SKNExtensions.h"
#import "PDFAnnotation_SKNExtensions.h"
#import "SKNPDFAnnotationNote.h"
#import "NSFileManager_SKNExtensions.h"

#if defined(PDFKIT_PLATFORM_IOS)

#define SKNRectFromString(string)   CGRectFromString(string)
#define SKNEqualRects(rect1, rect2) CGRectEqual(CGRectIntegral(rect1), CGRectIntegral(rect2))

#else

#ifndef PDFRect
#define PDFRect NSRect
#endif

#define SKNRectFromString(string)   NSRectFromString(string)
#define SKNEqualRects(rect1, rect2) NSEqualRects(NSIntegralRect(rect1), NSIntegralRect(rect2))

#if !defined(MAC_OS_X_VERSION_10_12) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_12
@interface PDFAnnotation (SKNSierraDeclarations)
- (id)valueForAnnotationKey:(NSString *)key;
@end
#endif

#if !defined(MAC_OS_X_VERSION_10_13) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_13
@interface PDFAnnotation (SKNHighSierraDeclarations)
- (void)setButtonWidgetState:(NSInteger)state;
- (void)setWidgetStringValue:(NSString *)stringValue;
@end
#endif

#endif

@implementation PDFDocument (SKNExtensions)

- (id)initWithURL:(NSURL *)url readSkimNotes:(NSArray **)notes {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *pdfURL = url;
    BOOL isPDFBundle = [[[url path] pathExtension] caseInsensitiveCompare:@"pdfd"] == NSOrderedSame;
    if (isPDFBundle)
        pdfURL = [fm bundledFileURLWithExtension:@"pdf" inPDFBundleAtURL:url error:NULL];
    self = [self initWithURL:pdfURL];
    if (self) {
        NSArray *noteDicts = nil;
        NSArray *annotations = nil;
        if (isPDFBundle)
            noteDicts = [fm readSkimNotesFromPDFBundleAtURL:url error:NULL];
        else
            noteDicts = [fm readSkimNotesFromExtendedAttributesAtURL:url error:NULL];
        if ([noteDicts count])
            annotations = [self addSkimNotesWithProperties:noteDicts];
        if (notes)
            *notes = annotations;
    }
    return self;
}

static inline SKNPDFWidgetType SKNWidgetTypeForAnnotation(PDFAnnotation *annotation) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([annotation isKindOfClass:[PDFAnnotationTextWidget class]])
        return kSKNPDFWidgetTypeText;
    else if ([annotation isKindOfClass:[PDFAnnotationButtonWidget class]])
        return kSKNPDFWidgetTypeButton;
    else if ([annotation isKindOfClass:[PDFAnnotationChoiceWidget class]])
        return kSKNPDFWidgetTypeChoice;
    else if ([annotation respondsToSelector:@selector(valueForAnnotationKey:)] == NO)
        return kSKNPDFWidgetTypeUnknown;
#pragma clang diagnostic pop
    NSString *ft = [annotation valueForAnnotationKey:@"/FT"];
    if ([ft isKindOfClass:[NSString class]] == NO)
        return kSKNPDFWidgetTypeUnknown;
    else if ([ft isEqualToString:@"/Tx"])
        return kSKNPDFWidgetTypeText;
    else if ([ft isEqualToString:@"/Btn"])
        return kSKNPDFWidgetTypeButton;
    else if ([ft isEqualToString:@"/Ch"])
        return kSKNPDFWidgetTypeChoice;
    else
        return kSKNPDFWidgetTypeUnknown;
}

static inline NSString *SKNFieldNameForAnnotation(PDFAnnotation *annotation) {
    if ([annotation respondsToSelector:@selector(fieldName)])
        return [(id)annotation fieldName];
    else if ([annotation respondsToSelector:@selector(valueForAnnotationKey:)])
        return [annotation valueForAnnotationKey:@"/T"];
    else
        return nil;
}

- (NSArray *)addSkimNotesWithProperties:(NSArray *)noteDicts {
    NSEnumerator *e = [noteDicts objectEnumerator];
    PDFAnnotation *annotation;
    NSDictionary *dict;
    NSMutableArray *notes = [NSMutableArray array];
    
    if ([self pageCount] == 0) return nil;
    
    // create new annotations from the dictionary and add them to their page and to the document
    while (dict = [e nextObject]) {
        NSUInteger pageIndex = [[dict objectForKey:SKNPDFAnnotationPageIndexKey] unsignedIntegerValue];
        if ([[dict objectForKey:SKNPDFAnnotationTypeKey] isEqualToString:SKNWidgetString]) {
            if (pageIndex >= [self pageCount])
                continue;
            PDFPage *page = [self pageAtIndex:pageIndex];
            PDFRect bounds = SKNRectFromString([dict objectForKey:SKNPDFAnnotationBoundsKey]);
            SKNPDFWidgetType widgetType = [[dict objectForKey:SKNPDFAnnotationWidgetTypeKey] integerValue];
            NSString *fieldName = [dict objectForKey:SKNPDFAnnotationFieldNameKey] ?: @"";
            for (annotation in [page annotations]) {
                if ([[annotation type] isEqualToString:SKNWidgetString] &&
                    SKNWidgetTypeForAnnotation(annotation) == widgetType &&
                    [fieldName isEqualToString:(SKNFieldNameForAnnotation(annotation) ?: @"")] &&
                    SKNEqualRects([annotation bounds], bounds)) {
                    if (widgetType == kSKNPDFWidgetTypeButton) {
                        if ([annotation respondsToSelector:@selector(setButtonWidgetState:)])
                            [annotation setButtonWidgetState:[[dict objectForKey:SKNPDFAnnotationStateKey] integerValue]];
                        else if ([annotation respondsToSelector:@selector(setState:)])
                            [(id)annotation setState:[[dict objectForKey:SKNPDFAnnotationStateKey] integerValue]];
                    } else {
                        if ([annotation respondsToSelector:@selector(setWidgetStringValue:)])
                            [annotation setWidgetStringValue:[dict objectForKey:SKNPDFAnnotationStringValueKey]];
                        else if ([annotation respondsToSelector:@selector(setStringValue:)])
                            [(id)annotation setStringValue:[dict objectForKey:SKNPDFAnnotationStringValueKey]];
                    }
                    break;
                }
            }
        } else if ((annotation = [[PDFAnnotation alloc] initSkimNoteWithProperties:dict])) {
            if (pageIndex == NSNotFound || pageIndex == INT_MAX)
                pageIndex = 0;
            else if (pageIndex >= [self pageCount])
                pageIndex = [self pageCount] - 1;
            PDFPage *page = [self pageAtIndex:pageIndex];
            [page addAnnotation:annotation];
            [notes addObject:annotation];
            [annotation release];
        }
    }
    
    return notes;
}
@end
