//
//  PDFAnnotationSquare_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 4/1/08.
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

#import "PDFAnnotationSquare_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKFDFParser.h"
#import "PDFSelection_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"


@implementation PDFAnnotationSquare (SKExtensions)

- (void)setDefaultSkimNoteProperties {
    NSColor *color = [[NSUserDefaults standardUserDefaults] colorForKey:SKSquareNoteInteriorColorKey];
    if ([color alphaComponent] > 0.0)
        [self setInteriorColor:color];
    [self setColor:[[NSUserDefaults standardUserDefaults] colorForKey:SKSquareNoteColorKey]];
    [[self border] setLineWidth:[[NSUserDefaults standardUserDefaults] floatForKey:SKSquareNoteLineWidthKey]];
    [[self border] setDashPattern:[[NSUserDefaults standardUserDefaults] arrayForKey:SKSquareNoteDashPatternKey]];
    [[self border] setStyle:[[NSUserDefaults standardUserDefaults] floatForKey:SKSquareNoteLineStyleKey]];

}

- (NSString *)fdfString {
    NSMutableString *fdfString = [[super fdfString] mutableCopy];
    CGFloat r, g, b, a = 0.0;
    [[[self interiorColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];
    if (a > 0.0) {
        [fdfString appendFDFName:SKFDFAnnotationInteriorColorKey];
        [fdfString appendFormat:@"[%f %f %f]", r, g, b];
    }
    return fdfString;
}

- (BOOL)isWidget { return NO; }

- (BOOL)isLnk { return NO; }

- (BOOL)isResizable { return [self isSkimNote]; }

- (BOOL)isMovable { return [self isSkimNote]; }

- (BOOL)hasInteriorColor { return [self isSkimNote]; }

- (BOOL)isConvertibleAnnotation { return YES; }

- (BOOL)hitTest:(NSPoint)point {
    if ([super hitTest:point] == NO)
        return NO;
    
    if ([self interiorColor])
        return YES;
    
    NSRect bounds = [self bounds];
    CGFloat delta = fmax(8.0, [self lineWidth]);
    return NSWidth(bounds) <= 2.0 * delta || NSHeight(bounds) <= 2.0 * delta || NSPointInRect(point, NSInsetRect(bounds, delta, delta)) == NO;
}

- (void)autoUpdateString {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableUpdateContentsFromEnclosedTextKey])
        return;
    NSRect bounds = NSInsetRect([self bounds], [self lineWidth] - 1.0, [self lineWidth] - 1.0);
    if (NSWidth(bounds) <= 0.0 || NSHeight(bounds) <= 0.0)
        return;
    NSString *selString = [[[self page] selectionForRect:bounds] cleanedString];
    if ([selString length])
        [self setString:selString];
}

- (NSString *)colorDefaultKey { return SKSquareNoteColorKey; }

- (NSString *)alternateColorDefaultKey { return SKSquareNoteInteriorColorKey; }

- (NSSet *)keysForValuesToObserveForUndo {
    static NSSet *squareKeys = nil;
    if (squareKeys == nil) {
        NSMutableSet *mutableKeys = [[super keysForValuesToObserveForUndo] mutableCopy];
        [mutableKeys addObject:SKNPDFAnnotationInteriorColorKey];
        squareKeys = [mutableKeys copy];
    }
    return squareKeys;
}

#pragma mark Scripting support

+ (NSSet *)customScriptingKeys {
    static NSSet *customSquareScriptingKeys = nil;
    if (customSquareScriptingKeys == nil) {
        NSMutableSet *customKeys = [[super customScriptingKeys] mutableCopy];
        [customKeys addObject:SKPDFAnnotationScriptingInteriorColorKey];
        customSquareScriptingKeys = [customKeys copy];
    }
    return customSquareScriptingKeys;
}

- (NSColor *)scriptingInteriorColor {
    return [self interiorColor];
}

- (void)setScriptingInteriorColor:(NSColor *)newColor {
    if ([self isEditable]) {
        [self setInteriorColor:newColor];
    }
}

@end
