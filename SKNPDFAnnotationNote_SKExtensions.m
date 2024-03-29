//
//  SKNPDFAnnotationNote_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 2/6/07.
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

#import "SKNPDFAnnotationNote_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKFDFParser.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "SKNoteText.h"


NSString *SKPDFAnnotationRichTextKey = @"richText";

@interface SKNPDFAnnotationNote (SKPrivateDeclarations)
- (NSTextStorage *)mutableText;
- (NSArray *)texts;
- (void)setTexts:(NSArray *)texts;
@end

@implementation SKNPDFAnnotationNote (SKExtensions)

- (void)setDefaultSkimNoteProperties {
    [self setColor:[[NSUserDefaults standardUserDefaults] colorForKey:SKAnchoredNoteColorKey]];
    [self setIconType:[[NSUserDefaults standardUserDefaults] integerForKey:SKAnchoredNoteIconTypeKey]];
    [self setTexts:@[[[SKNoteText alloc] initWithNote:self]]];
    [self setPopup:nil];
}

- (BOOL)isNote { return YES; }

- (BOOL)isMovable { return [self isSkimNote]; }

- (BOOL)hasBorder { return NO; }

// override these Leopard methods to avoid showing the standard tool tips over our own
- (NSString *)toolTip { return @""; }

- (BOOL)hasNoteText { return YES; }

- (SKNoteText *)noteText {
    return [[self texts] firstObject];
}

- (NSString *)textString {
    return [[self text] string];
}

- (NSString *)colorDefaultKey { return SKAnchoredNoteColorKey; }

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *noteKeys = nil;
    if (noteKeys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:SKNPDFAnnotationTextKey];
        [mutableKeys addObject:SKNPDFAnnotationImageKey];
        noteKeys = [mutableKeys copy];
    }
    return noteKeys;
}

#pragma mark Scripting support

+ (NSSet *)customScriptingKeys {
    static NSSet *customNoteScriptingKeys = nil;
    if (customNoteScriptingKeys == nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSMutableSet *customKeys = [[super customScriptingKeys] mutableCopy];
#pragma clang diagnostic pop
        [customKeys addObject:SKPDFAnnotationRichTextKey];
        customNoteScriptingKeys = [customKeys copy];
    }
    return customNoteScriptingKeys;
}

- (id)richText {
    return [self mutableText];
}

- (void)setRichText:(id)newText {
    if ([self isEditable] && newText != [self mutableText]) {
        // We are willing to accept either a string or an attributed string.
        if ([newText isKindOfClass:[NSAttributedString class]])
            [[self mutableText] replaceCharactersInRange:NSMakeRange(0, [[self mutableText] length]) withAttributedString:newText];
        else
            [[self mutableText] replaceCharactersInRange:NSMakeRange(0, [[self mutableText] length]) withString:newText];
    }
}

- (id)coerceValueForRichText:(id)value {
    if ([value isKindOfClass:[NSScriptObjectSpecifier class]])
        value = [(NSScriptObjectSpecifier *)value objectsByEvaluatingSpecifier];
    // We want to just get Strings unchanged.  We will detect this and do the right thing in setRichText.  We do this because, this way, we will do more reasonable things about attributes when we are receiving plain text.
    if ([value isKindOfClass:[NSString class]])
        return value;
    else
        return [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:value toClass:[NSTextStorage class]];
}

@end
