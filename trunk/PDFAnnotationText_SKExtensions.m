//
//  PDFAnnotationText_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 6/3/08.
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

#import "PDFAnnotationText_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKFDFParser.h"


NSString *SKPDFAnnotationScriptingIconTypeKey = @"scriptingIconType";

@implementation PDFAnnotationText (SKExtensions)

- (NSString *)fdfString {
    NSMutableString *fdfString = [[super fdfString] mutableCopy];
    [fdfString appendFDFName:SKFDFAnnotationIconTypeKey];
    [fdfString appendFDFName:SKFDFTextAnnotationIconTypeFromPDFTextAnnotationIconType([self iconType])];
    return fdfString;
}

- (BOOL)isWidget { return NO; }

- (BOOL)isLnk { return NO; }

- (BOOL)isMovable { return [self isSkimNote]; }

- (BOOL)isConvertibleAnnotation { return YES; }

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *textKeys = nil;
    if (textKeys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:SKNPDFAnnotationIconTypeKey];
        [mutableKeys removeObject:SKNPDFAnnotationBorderKey];
        textKeys = [mutableKeys copy];
    }
    return textKeys;
}

#pragma mark Scripting support

+ (NSSet *)customScriptingKeys {
    static NSSet *customTextScriptingKeys = nil;
    if (customTextScriptingKeys == nil) {
        NSMutableSet *customKeys = [[super customScriptingKeys] mutableCopy];
        [customKeys addObject:SKPDFAnnotationScriptingIconTypeKey];
        [customKeys removeObject:SKNPDFAnnotationLineWidthKey];
        [customKeys removeObject:SKNPDFAnnotationBorderStyleKey];
        [customKeys removeObject:SKNPDFAnnotationDashPatternKey];
        customTextScriptingKeys = [customKeys copy];
    }
    return customTextScriptingKeys;
}

- (PDFTextAnnotationIconType)scriptingIconType {
    return [self iconType];
}

- (void)setScriptingIconType:(PDFTextAnnotationIconType)iconType {
    if ([self isEditable]) {
        [self setIconType:iconType];
    }
}

@end
