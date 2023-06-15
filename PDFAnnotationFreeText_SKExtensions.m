//
//  PDFAnnotationFreeText_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 4/1/08.
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

#import "PDFAnnotationFreeText_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKFDFParser.h"
#import "NSUserDefaults_SKExtensions.h"


NSString *SKPDFAnnotationScriptingFontColorKey = @"scriptingFontColor";
NSString *SKPDFAnnotationScriptingAlignmentKey = @"scriptingAlignment";


@implementation PDFAnnotationFreeText (SKExtensions)

static inline NSTextAlignment textAlignmentFromAlignment(NSInteger alignment) {
    switch (alignment) {
        case 0: return NSTextAlignmentLeft;
        case 1: return NSTextAlignmentRight;
        case 2: return NSTextAlignmentCenter;
        default: return NSTextAlignmentLeft;
    }
}

- (void)setDefaultSkimNoteProperties {
    NSFont *font = [[NSUserDefaults standardUserDefaults] fontForNameKey:SKFreeTextNoteFontNameKey sizeKey:SKFreeTextNoteFontSizeKey];
    if (font)
        [self setFont:font];
    [self setColor:[[NSUserDefaults standardUserDefaults] colorForKey:SKFreeTextNoteColorKey]];
    [self setFontColor:[[NSUserDefaults standardUserDefaults] colorForKey:SKFreeTextNoteFontColorKey]];
    [self setAlignment:textAlignmentFromAlignment([[NSUserDefaults standardUserDefaults] integerForKey:SKFreeTextNoteAlignmentKey])];
    PDFBorder *border = [[PDFBorder allocWithZone:[self zone]] init];
    [border setLineWidth:[[NSUserDefaults standardUserDefaults] floatForKey:SKFreeTextNoteLineWidthKey]];
    [border setDashPattern:[[NSUserDefaults standardUserDefaults] arrayForKey:SKFreeTextNoteDashPatternKey]];
    [border setStyle:[[NSUserDefaults standardUserDefaults] floatForKey:SKFreeTextNoteLineStyleKey]];
    if ([border lineWidth] > 0.0) {
        [self setBorder:border];
    } else {
        [self setBorder:nil];
        // on 10.12 you can't set the border to nil, so set its lineWidth to 0
        [[self border] setLineWidth:0.0];
    }
    [border release];
}

static inline NSString *alignmentStyleKeyword(NSTextAlignment alignment) {
    switch (alignment) {
        case NSTextAlignmentLeft: return @"left";
        case NSTextAlignmentRight: return @"right";
        case NSTextAlignmentCenter: return @"center";
        default: return @"left";
    }
}

- (NSString *)fdfString {
    NSMutableString *fdfString = [[[super fdfString] mutableCopy] autorelease];
    CGFloat r = 0.0, g = 0.0, b = 0.0, a;
    [[[self fontColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
    [fdfString appendFDFName:SKFDFDefaultAppearanceKey];
    [fdfString appendFormat:@"(/%@ %f Tf %f %f %f rg)", [self fontName], [self fontSize], r, g, b];
    [fdfString appendFDFName:SKFDFDefaultStyleKey];
    [[[self fontColor] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]] getRed:&r green:&g blue:&b alpha:&a];
    [fdfString appendFormat:@"(font: %@ %fpt; text-align:%@; color:#%.2x%.2x%.2x)", [self fontName], [self fontSize], alignmentStyleKeyword([self alignment]), (unsigned int)(255*r), (unsigned int)(255*g), (unsigned int)(255*b)];
    [fdfString appendFDFName:SKFDFAnnotationAlignmentKey];
    [fdfString appendFormat:@" %ld", (long)SKFDFFreeTextAnnotationAlignmentFromPDFFreeTextAnnotationAlignment([self alignment])];
    return fdfString;
}

- (BOOL)isText { return YES; }

- (BOOL)isWidget { return NO; }

- (BOOL)isResizable { return [self isSkimNote]; }

- (BOOL)isMovable { return [self isSkimNote]; }

- (BOOL)isConvertibleAnnotation { return YES; }

- (NSString *)colorDefaultKey { return SKFreeTextNoteColorKey; }

- (NSString *)alternateColorDefaultKey { return SKFreeTextNoteFontColorKey; }

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *freeTextKeys = nil;
    if (freeTextKeys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:SKNPDFAnnotationFontKey];
        [mutableKeys addObject:SKNPDFAnnotationFontColorKey];
        [mutableKeys addObject:SKNPDFAnnotationAlignmentKey];
        freeTextKeys = [mutableKeys copy];
        [mutableKeys release];
    }
    return freeTextKeys;
}

#pragma mark Scripting support

+ (NSSet *)customScriptingKeys {
    static NSSet *customFreeTextScriptingKeys = nil;
    if (customFreeTextScriptingKeys == nil) {
        NSMutableSet *customKeys = [[super customScriptingKeys] mutableCopy];
        [customKeys addObject:SKNPDFAnnotationFontNameKey];
        [customKeys addObject:SKNPDFAnnotationFontSizeKey];
        [customKeys addObject:SKPDFAnnotationScriptingFontColorKey];
        [customKeys addObject:SKPDFAnnotationScriptingAlignmentKey];
        customFreeTextScriptingKeys = [customKeys copy];
        [customKeys release];
    }
    return customFreeTextScriptingKeys;
}

- (id)textContents {
    NSTextStorage *textContents = [super textContents];
    if ([self font])
        [textContents addAttribute:NSFontAttributeName value:[self font] range:NSMakeRange(0, [textContents length])];
    if ([self fontColor])
        [textContents addAttribute:NSForegroundColorAttributeName value:[self fontColor] range:NSMakeRange(0, [textContents length])];
    return textContents;
}

- (NSString *)fontName {
    return [[self font] fontName];
}

- (void)setFontName:(NSString *)fontName {
    if ([self isEditable]) {
        NSFont *font = [NSFont fontWithName:fontName size:[[self font] pointSize]];
        if (font)
            [self setFont:font];
    }
}

- (CGFloat)fontSize {
    return [[self font] pointSize];
}

- (void)setFontSize:(CGFloat)pointSize {
    if ([self isEditable]) {
        NSFont *font = [NSFont fontWithName:[[self font] fontName] size:pointSize];
        if (font)
            [self setFont:font];
    }
}

- (NSColor *)scriptingFontColor {
    return [self fontColor];
}

- (void)setScriptingFontColor:(NSColor *)newScriptingFontColor {
    if ([self isEditable]) {
        [self setFontColor:newScriptingFontColor];
    }
}

- (NSInteger)scriptingAlignment {
    NSTextAlignment align = [self alignment];
    return align == 2 ? NSTextAlignmentCenter : align == 1 ? NSTextAlignmentRight : NSTextAlignmentLeft;
}

- (void)setScriptingAlignment:(NSInteger)alignment {
    if ([self isEditable]) {
        [self setAlignment:alignment == NSTextAlignmentCenter ? 2 : alignment == NSTextAlignmentRight ? 1 : 0];
    }
}

@end
