//
//  PDFAnnotationButtonWidget_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 11/04/2020.
/*
This software is Copyright (c) 2020
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

#import "PDFAnnotationButtonWidget_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "SKFDFParser.h"
#import "NSString_SKExtensions.h"

@implementation PDFAnnotationButtonWidget (SKExtensions)

- (NSString *)fdfString {
    NSMutableString *fdfString = [[super fdfString] mutableCopy];
    [fdfString appendFDFName:SKFDFAnnotationFieldTypeKey];
    [fdfString appendFDFName:SKFDFFieldTypeButton];
    [fdfString appendFDFName:SKFDFAnnotationFieldNameKey];
    [fdfString appendFormat:@"(%@)", [[[self fieldName] ?: @"" lossyStringUsingEncoding:NSISOLatin1StringEncoding] stringByEscapingParenthesis]];
    [fdfString appendFDFName:SKFDFAnnotationFieldValueKey];
    [fdfString appendFormat:@"/%@", [self state] == NSControlStateValueOn ? [self onStateValue] : @"Off"];
    return fdfString;
}

- (id)objectValue {
    return [NSNumber numberWithInteger:[self state]];
}

- (void)setObjectValue:(id)newObjectValue {
    [self setState:[newObjectValue integerValue]];
}

- (SKNPDFWidgetType)widgetType {
    return kSKNPDFWidgetTypeButton;
}

- (BOOL)isWidget {
    return [self controlType] == kPDFWidgetCheckBoxControl || [self controlType] == kPDFWidgetRadioButtonControl;
}

- (BOOL)isLnk { return NO; }

- (NSSet *)keysForValuesToObserveForUndo {
    if ([self controlType] != kPDFWidgetCheckBoxControl && [self controlType] != kPDFWidgetRadioButtonControl)
        return nil;
    static NSSet *keys = nil;
    if (keys == nil)
        keys = [[NSSet alloc] initWithObjects:SKNPDFAnnotationStateKey, nil];
    return keys;
}

@end
