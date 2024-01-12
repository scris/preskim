//
//  NSValueTransformer_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 4/2/08.
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

#import "NSValueTransformer_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>

NSString *SKUnarchiveColorTransformerName = @"SKUnarchiveColor";
NSString *SKUnarchiveColorArrayTransformerName = @"SKUnarchiveArrayColor";
NSString *SKTypeImageTransformerName = @"SKTypeImage";
NSString *SKHasWindowImageTransformerName = @"SKHasWindowImage";
NSString *SKIsZeroTransformerName = @"SKIsZero";
NSString *SKIsOneTransformerName = @"SKIsOne";
NSString *SKIsTwoTransformerName = @"SKIsTwo";

@interface SKUnarchiveColorTransformer : NSValueTransformer
@end

#pragma mark -

@interface SKUnarchiveColorArrayTransformer : SKUnarchiveColorTransformer
@end

#pragma mark -

@interface SKTypeImageTransformer : NSValueTransformer
@end

#pragma mark -

@interface SKHasWindowImageTransformer : NSValueTransformer
@end

#pragma mark -

@interface SKRadioTransformer : NSValueTransformer {
    NSInteger targetValue;
}
- (instancetype)initWithTargetValue:(NSInteger)value;
@end

#pragma mark -

@implementation NSValueTransformer (SKExtensions)

+ (void)registerCustomTransformers {
    [NSValueTransformer setValueTransformer:[[SKUnarchiveColorTransformer alloc] init] forName:SKUnarchiveColorTransformerName];
    [NSValueTransformer setValueTransformer:[[SKUnarchiveColorArrayTransformer alloc] init] forName:SKUnarchiveColorArrayTransformerName];
    [NSValueTransformer setValueTransformer:[[SKTypeImageTransformer alloc] init] forName:SKTypeImageTransformerName];
    [NSValueTransformer setValueTransformer:[[SKHasWindowImageTransformer alloc] init] forName:SKHasWindowImageTransformerName];
    [NSValueTransformer setValueTransformer:[[SKRadioTransformer alloc] initWithTargetValue:0] forName:SKIsZeroTransformerName];
    [NSValueTransformer setValueTransformer:[[SKRadioTransformer alloc] initWithTargetValue:1] forName:SKIsOneTransformerName];
    [NSValueTransformer setValueTransformer:[[SKRadioTransformer alloc] initWithTargetValue:2] forName:SKIsTwoTransformerName];
}

@end

#pragma mark -

@implementation SKUnarchiveColorTransformer

+ (Class)transformedValueClass {
    return [NSColor class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    if ([value isKindOfClass:[NSData class]] == NO)
        return nil;
    NSColor *color = nil;
    @try { color = [NSKeyedUnarchiver unarchiveObjectWithData:value]; }
    @catch (id e) {}
    if (color == nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        @try { color = [NSUnarchiver unarchiveObjectWithData:value]; }
#pragma clang diagnostic pop
        @catch (id e) {}
    }
    if ([color isKindOfClass:[NSColor class]] == NO)
        return nil;
    return color;
}

- (id)reverseTransformedValue:(id)value {
    if ([value isKindOfClass:[NSColor class]] == NO)
        return nil;
    return [NSKeyedArchiver archivedDataWithRootObject:value];
}

@end

#pragma mark -

@implementation SKUnarchiveColorArrayTransformer

+ (Class)transformedValueClass {
    return [NSArray class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)array {
    NSMutableArray *transformedArray = [NSMutableArray arrayWithCapacity:[array count]];
    for (id obj in array)
        [transformedArray addObject:[super transformedValue:obj] ?: [NSNull null]];
    return transformedArray;
}

- (id)reverseTransformedValue:(id)array {
    NSMutableArray *transformedArray = [NSMutableArray arrayWithCapacity:[array count]];
    for (id obj in array)
        [transformedArray addObject:[super reverseTransformedValue:obj] ?: [NSData data]];
    return transformedArray;
}

@end

#pragma mark -

@implementation SKTypeImageTransformer

+ (Class)transformedValueClass {
    return [NSImage class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)type {
    if ([type isKindOfClass:[NSString class]] == NO)
        return nil;
    else if ([type isEqualToString:SKNFreeTextString])
        return [NSImage imageNamed:SKImageNameTextNote];
    else if ([type isEqualToString:SKNNoteString] || [type isEqualToString:SKNTextString])
        return [NSImage imageNamed:SKImageNameAnchoredNote];
    else if ([type isEqualToString:SKNCircleString])
        return [NSImage imageNamed:SKImageNameCircleNote];
    else if ([type isEqualToString:SKNSquareString])
        return [NSImage imageNamed:SKImageNameSquareNote];
    else if ([type isEqualToString:SKNHighlightString] || [type isEqualToString:SKNMarkUpString])
        return [NSImage imageNamed:SKImageNameHighlightNote];
    else if ([type isEqualToString:SKNUnderlineString])
        return [NSImage imageNamed:SKImageNameUnderlineNote];
    else if ([type isEqualToString:SKNStrikeOutString])
        return [NSImage imageNamed:SKImageNameStrikeOutNote];
    else if ([type isEqualToString:SKNLineString])
        return [NSImage imageNamed:SKImageNameLineNote];
    else if ([type isEqualToString:SKNInkString])
        return [NSImage imageNamed:SKImageNameInkNote];
    else if ([type isEqualToString:SKNWidgetString])
        return [NSImage imageNamed:SKImageNameWidgetNote];
    else
        return nil;
}

@end

#pragma mark -

@implementation SKHasWindowImageTransformer

+ (Class)transformedValueClass {
    return [NSImage class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)hasWindow {
    if ([hasWindow boolValue]) {
        static NSImage *windowImage = nil;
        if (windowImage == nil) {
            windowImage = [NSImage imageWithSize:NSMakeSize(12.0, 12.0) flipped:NO drawingHandler:^(NSRect dstRect){
                NSBezierPath *path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(1.0, 2.0)];
                [path appendBezierPathWithArcWithCenter:NSMakePoint(3.0, 10.0) radius:2.0 startAngle:180.0 endAngle:90.0 clockwise:YES];
                [path appendBezierPathWithArcWithCenter:NSMakePoint(9.0, 10.0) radius:2.0 startAngle:90.0 endAngle:0.0 clockwise:YES];
                [path lineToPoint:NSMakePoint(11.0, 2.0)];
                [path closePath];
                [path appendBezierPath:[NSBezierPath bezierPathWithRect:NSMakeRect(2.0, 3.0, 8.0, 7.0)]];
                [path setWindingRule:NSEvenOddWindingRule];
                [[NSColor blackColor] setFill];
                [path fill];
                return YES;
            }];
            [windowImage setTemplate:YES];
            [windowImage setAccessibilityDescription:NSLocalizedString(@"window", @"Accessibility description")];
        }
        return windowImage;
    }
    return nil;
}

@end

#pragma mark -

@implementation SKRadioTransformer

+ (Class)transformedValueClass {
    return [NSNumber class];
}

- (instancetype)initWithTargetValue:(NSInteger)value {
    self = [super init];
    if (self) {
        targetValue = value;
    }
    return self;
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    return [NSNumber numberWithInteger:[value integerValue] == targetValue ? NSControlStateValueOn : NSOffState];
}

- (id)reverseTransformedValue:(id)value {
    return [NSNumber numberWithInteger:[value integerValue] == NSControlStateValueOn ? targetValue : 0];
}

@end
