//
//  SKNotePrefs.m
//  Skim
//
//  Created by Christiaan Hofman on 03/12/2021.
/*
 This software is Copyright (c) 2021-2023
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

#import "SKNotePrefs.h"
#import "SKStringConstants.h"
#import <SkimNotes/SkimNotes.h>
#import "NSUserDefaults_SKExtensions.h"


@implementation SKNotePrefs

@synthesize type;
@dynamic name, scriptingColor, scriptingInteriorColor, lineWidth, borderStyle, dashPattern, scriptingStartLineStyle, scriptingEndLineStyle, fontName, fontSize, scriptingFontColor, scriptingAlignment, scriptingIconType, scriptingUserName, scriptingProperties;

static NSDictionary *alternateTypeNames = nil;
static NSDictionary *colorKeys = nil;
static NSDictionary *interiorColorKeys = nil;
static NSDictionary *lineWidthKeys = nil;
static NSDictionary *lineStyleKeys = nil;
static NSDictionary *dashPatternKeys = nil;
static NSDictionary *propertyKeys = nil;

+ (void)initialize {
    SKINITIALIZE;
    alternateTypeNames = [[NSDictionary alloc] initWithObjectsAndKeys:SKNFreeTextString, @"text note", SKNNoteString, @"anchored note", SKNCircleString, @"circle note", SKNSquareString, @"square note", SKNHighlightString, @"highlight note", SKNUnderlineString, @"underline note", SKNStrikeOutString, @"strike out note", SKNLineString, @"line note", SKNInkString, @"freehand note", nil];
    colorKeys = [[NSDictionary alloc] initWithObjectsAndKeys:SKFreeTextNoteColorKey, SKNFreeTextString, SKAnchoredNoteColorKey, SKNNoteString, SKCircleNoteColorKey, SKNCircleString, SKSquareNoteColorKey, SKNSquareString, SKHighlightNoteColorKey, SKNHighlightString, SKUnderlineNoteColorKey, SKNUnderlineString, SKStrikeOutNoteColorKey, SKNStrikeOutString, SKLineNoteColorKey, SKNLineString, SKInkNoteColorKey, SKNInkString, nil];
    interiorColorKeys = [[NSDictionary alloc] initWithObjectsAndKeys:SKCircleNoteInteriorColorKey, SKNCircleString, SKSquareNoteInteriorColorKey, SKNSquareString, SKLineNoteInteriorColorKey, SKNLineString, nil];
    lineWidthKeys = [[NSDictionary alloc] initWithObjectsAndKeys:SKFreeTextNoteLineWidthKey, SKNFreeTextString, SKCircleNoteLineWidthKey, SKNCircleString, SKSquareNoteLineWidthKey, SKNSquareString, SKLineNoteLineWidthKey, SKNLineString, SKInkNoteLineWidthKey, SKNInkString, nil];
    lineStyleKeys = [[NSDictionary alloc] initWithObjectsAndKeys:SKFreeTextNoteLineStyleKey, SKNFreeTextString, SKCircleNoteLineStyleKey, SKNCircleString, SKSquareNoteLineStyleKey, SKNSquareString, SKLineNoteLineStyleKey, SKNLineString, SKInkNoteLineStyleKey, SKNInkString, nil];
    dashPatternKeys = [[NSDictionary alloc] initWithObjectsAndKeys:SKFreeTextNoteDashPatternKey, SKNFreeTextString, SKCircleNoteDashPatternKey, SKNCircleString, SKSquareNoteDashPatternKey, SKNSquareString, SKLineNoteDashPatternKey, SKNLineString, SKInkNoteDashPatternKey, SKNInkString, nil];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSArray *array = @[@"name", @"type", @"classCode", @"scriptingUserName", @"scriptingColor", @"lineWidth", @"bBorderStyle", @"dashPattern", @"fontName", @"fontSize", @"scriptingFontColor", @"scriptingAlignment"];
    [dict setObject:array forKey:SKNFreeTextString];
    array = @[@"name", @"type", @"classCode", @"scriptingUserName", @"scriptingColor", @"fontName", @"fontSize", @"scriptingIconType"];
    [dict setObject:array forKey:SKNNoteString];
    array = @[@"name", @"type", @"classCode", @"scriptingUserName", @"scriptingColor", @"scriptingInteriorColor", @"lineWidth", @"bBorderStyle", @"dashPattern"];
    [dict setObject:array forKey:SKNCircleString];
    [dict setObject:array forKey:SKNSquareString];
    array = @[@"name", @"type", @"classCode", @"scriptingUserName", @"scriptingColor"];
    [dict setObject:array forKey:SKNHighlightString];
    [dict setObject:array forKey:SKNUnderlineString];
    [dict setObject:array forKey:SKNStrikeOutString];
    array = @[@"name", @"type", @"classCode", @"scriptingUserName", @"scriptingColor", @"scriptingInteriorColor", @"lineWidth", @"bBorderStyle", @"dashPattern", @"scriptingStartLineStyle", @"scriptingEndLineStyle"];
    [dict setObject:array forKey:SKNLineString];
    array = @[@"name", @"type", @"classCode", @"scriptingUserName", @"scriptingColor", @"lineWidth", @"bBorderStyle", @"dashPattern"];
    [dict setObject:array forKey:SKNInkString];
    propertyKeys = [dict copy];
}

- (id)initWithType:(NSString *)aType {
    if (aType && [propertyKeys objectForKey:aType] == nil)
        aType = [alternateTypeNames objectForKey:aType];
    if (aType == nil) {
        [self release];
        self = nil;
    } else {
        self = [super init];
        if (self) {
            type = [aType retain];
        }
    }
    return self;
}

- (void)dealloc {
    SKDESTROY(type);
    [super dealloc];
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptClassDescription *containerClassDescription = [NSScriptClassDescription classDescriptionForClass:[NSApp class]];
    return [[[NSNameSpecifier alloc] initWithContainerClassDescription:containerClassDescription containerSpecifier:nil key:@"notePreferences" name:[self type]] autorelease];
}

- (NSString *)name {
    return type;
}

- (NSString *)scriptingUserName {
    if ([[NSUserDefaults standardUserDefaults] stringForKey:SKUseUserNameKey])
        return [[NSUserDefaults standardUserDefaults] stringForKey:SKUserNameKey];
    else
        return nil;
}

- (void)setScriptingUserName:(NSString *)name {
    if ([name length] == 0) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SKUseUserNameKey];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SKUseUserNameKey];
        [[NSUserDefaults standardUserDefaults] setObject:name forKey:SKUserNameKey];
    }
}

- (NSColor *)scriptingColor {
    NSString *key = [colorKeys objectForKey:type];
    return key ? [[NSUserDefaults standardUserDefaults] colorForKey:key] : nil;
    
}

- (void)setScriptingColor:(NSColor *)color {
    NSString *key = [colorKeys objectForKey:type];
    if (key)
        [[NSUserDefaults standardUserDefaults] setColor:color forKey:key];
}

- (NSColor *)scriptingInteriorColor {
    NSString *key = [interiorColorKeys objectForKey:type];
    return key ? [[NSUserDefaults standardUserDefaults] colorForKey:key] : nil;

}

- (void)setScriptingInteriorColor:(NSColor *)color {
    NSString *key = [interiorColorKeys objectForKey:type];
    if (key)
        [[NSUserDefaults standardUserDefaults] setColor:color forKey:key];
}

- (CGFloat)lineWidth {
    NSString *key = [lineWidthKeys objectForKey:type];
    return key ? [[NSUserDefaults standardUserDefaults] doubleForKey:key] : 0.0;
}

- (void)setLineWidth:(CGFloat)lineWidth {
    NSString *key = [lineWidthKeys objectForKey:type];
    if (key)
        [[NSUserDefaults standardUserDefaults] setDouble:lineWidth forKey:key];
}

- (PDFBorderStyle)borderStyle {
    NSString *key = [lineStyleKeys objectForKey:type];
    return key ? [[NSUserDefaults standardUserDefaults] integerForKey:key] : 0;
}

- (void)setBorderStyle:(PDFBorderStyle)borderStyle {
    NSString *key = [lineStyleKeys objectForKey:type];
    if (key)
        [[NSUserDefaults standardUserDefaults] setInteger:borderStyle forKey:key];
}

- (NSArray *)dashPattern {
    NSString *key = [dashPatternKeys objectForKey:type];
    return key ? [[NSUserDefaults standardUserDefaults] arrayForKey:key] : nil;
}

- (void)setDashPattern:(NSArray *)dashPattern {
    NSString *key = [dashPatternKeys objectForKey:type];
    if (key)
        [[NSUserDefaults standardUserDefaults] setObject:dashPattern forKey:key];
}

- (PDFLineStyle)scriptingStartLineStyle {
    if ([type isEqualToString:SKNLineString])
        return [[NSUserDefaults standardUserDefaults] integerForKey:SKLineNoteStartLineStyleKey];
    return 0;
}

- (void)setScriptingStartLineStyle:(PDFLineStyle)lineStyle {
    if ([type isEqualToString:SKNLineString])
        [[NSUserDefaults standardUserDefaults] setInteger:lineStyle forKey:SKLineNoteStartLineStyleKey];
}

- (PDFLineStyle)scriptingEndLineStyle {
    if ([type isEqualToString:SKNLineString])
        return [[NSUserDefaults standardUserDefaults] integerForKey:SKLineNoteEndLineStyleKey];
    return 0;
}

- (void)setScriptingEndLineStyle:(PDFLineStyle)lineStyle {
    if ([type isEqualToString:SKNLineString])
        [[NSUserDefaults standardUserDefaults] setInteger:lineStyle forKey:SKLineNoteEndLineStyleKey];
}

- (NSString *)fontName {
    if ([type isEqualToString:SKNFreeTextString])
        return [[NSUserDefaults standardUserDefaults] objectForKey:SKFreeTextNoteFontNameKey];
    else if ([type isEqualToString:SKNNoteString])
        return [[NSUserDefaults standardUserDefaults] objectForKey:SKAnchoredNoteFontNameKey];
    return nil;
}

- (void)setFontName:(NSString *)fontName {
    if ([type isEqualToString:SKNFreeTextString])
        [[NSUserDefaults standardUserDefaults] setObject:fontName forKey:SKFreeTextNoteFontNameKey];
    else if ([type isEqualToString:SKNNoteString])
        [[NSUserDefaults standardUserDefaults] setObject:fontName forKey:SKAnchoredNoteFontNameKey];
}

- (CGFloat)fontSize {
    if ([type isEqualToString:SKNFreeTextString])
        return [[NSUserDefaults standardUserDefaults] doubleForKey:SKFreeTextNoteFontSizeKey];
    else if ([type isEqualToString:SKNNoteString])
        return [[NSUserDefaults standardUserDefaults] doubleForKey:SKAnchoredNoteFontSizeKey];
    return 0.0;
}

- (void)setFontSize:(CGFloat)fontSize {
    if ([type isEqualToString:SKNFreeTextString])
        [[NSUserDefaults standardUserDefaults] setDouble:fontSize forKey:SKFreeTextNoteFontSizeKey];
    else if ([type isEqualToString:SKNNoteString])
        [[NSUserDefaults standardUserDefaults] setDouble:fontSize forKey:SKAnchoredNoteFontSizeKey];
}

- (NSInteger)scriptingAlignment {
    if ([type isEqualToString:SKNFreeTextString])
        return [[NSUserDefaults standardUserDefaults] integerForKey:SKFreeTextNoteAlignmentKey];
    return 0;
}

- (void)setScriptingAlignment:(NSInteger)alignment {
    if ([type isEqualToString:SKNFreeTextString])
        [[NSUserDefaults standardUserDefaults] setInteger:alignment forKey:SKFreeTextNoteAlignmentKey];
}

- (NSColor *)scriptingFontColor {
    if ([type isEqualToString:SKNFreeTextString])
        return [[NSUserDefaults standardUserDefaults] colorForKey:SKFreeTextNoteFontColorKey];
    return nil;
}

- (void)setScriptingFontColor:(NSColor *)color {
    if ([type isEqualToString:SKNFreeTextString])
        [[NSUserDefaults standardUserDefaults] setColor:color forKey:SKFreeTextNoteFontColorKey];
}

- (PDFTextAnnotationIconType)scriptingIconType {
    if ([type isEqualToString:SKNNoteString])
        [[NSUserDefaults standardUserDefaults] integerForKey:SKAnchoredNoteIconTypeKey];
    return 0;
}

- (void)setScriptingIconType:(PDFTextAnnotationIconType)iconType {
    if ([type isEqualToString:SKNNoteString])
        [[NSUserDefaults standardUserDefaults] setInteger:iconType forKey:SKAnchoredNoteIconTypeKey];
}

- (NSDictionary *)scriptingProperties {
    return [self dictionaryWithValuesForKeys:[propertyKeys objectForKey:type]];
}

- (void)setScriptingProperties:(NSDictionary *)scriptingProperties {
    [self setValuesForKeysWithDictionary:scriptingProperties];
}

@end
