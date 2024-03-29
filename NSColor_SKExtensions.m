//
//  NSColor_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 6/17/07.
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

#import "NSColor_SKExtensions.h"
#import "SKRuntime.h"
#import "NSGraphics_SKExtensions.h"
#import "SKStringConstants.h"
#import "NSValueTransformer_SKExtensions.h"

@implementation NSColor (SKExtensions)

#pragma mark Note Highlight Colors

static NSColor *activeSelectionHighlightColor = nil;
static NSColor *inactiveSelectionHighlightColor = nil;
static NSColor *activeSelectionHighlightInteriorColor = nil;
static NSColor *inactiveSelectionHighlightInteriorColor = nil;

+ (void)handleSystemColorsDidChange:(NSNotification *)notification {
    NSColor *activeOut = nil;
    NSColor *inactiveOut = nil;
    NSColor *activeIn = nil;
    NSColor *inactiveIn = nil;
    if (@available(macOS 10.14, *)) {
        NSColorSpace *colorSpace = [NSColorSpace sRGBColorSpace];
        NSAppearance *appearance = [NSAppearance currentAppearance];
        [NSAppearance setCurrentAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
        activeOut = [[NSColor selectedContentBackgroundColor] colorUsingColorSpace:colorSpace];
        inactiveOut = [[NSColor grayColor] colorUsingColorSpace:colorSpace];
        activeIn = [[[[NSColor selectedContentBackgroundColor] colorUsingColorSpace:colorSpace] highlightWithLevel:0.66667] colorWithAlphaComponent:0.8];
        inactiveIn = [[[NSColor unemphasizedSelectedContentBackgroundColor] colorUsingColorSpace:colorSpace] colorWithAlphaComponent:0.8];
        [NSAppearance setCurrentAppearance:appearance];
    } else {
        NSColorSpace *colorSpace = [NSColorSpace genericRGBColorSpace];
        activeOut = [[NSColor selectedContentBackgroundColor] colorUsingColorSpace:colorSpace];
        inactiveOut = [[NSColor grayColor] colorUsingColorSpace:colorSpace];
        activeIn = [[[[NSColor selectedContentBackgroundColor] colorUsingColorSpace:colorSpace] highlightWithLevel:0.66667] colorWithAlphaComponent:0.8];
        inactiveIn = [[[NSColor unemphasizedSelectedContentBackgroundColor] colorUsingColorSpace:colorSpace] colorWithAlphaComponent:0.8];
    }
    @synchronized (self) {
        activeSelectionHighlightColor = activeOut;
        inactiveSelectionHighlightColor = inactiveOut;
        activeSelectionHighlightInteriorColor = activeIn;
        inactiveSelectionHighlightInteriorColor = inactiveIn;
    }
}

+ (void)makeHighlightColors {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSystemColorsDidChange:) name:NSSystemColorsDidChangeNotification object:nil];
    [self handleSystemColorsDidChange:nil];
}

+ (NSColor *)selectionHighlightColor:(BOOL)active {
    NSColor *color = nil;
    @synchronized (self) {
        color = active ? activeSelectionHighlightColor : inactiveSelectionHighlightColor;
    }
    return color;
}

+ (NSColor *)selectionHighlightInteriorColor:(BOOL)active {
    NSColor *color = nil;
    @synchronized (self) {
        color = active ? activeSelectionHighlightInteriorColor : inactiveSelectionHighlightInteriorColor;
    }
    return color;
}

#pragma mark Favorite Colors

+ (NSArray *)favoriteColors {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:SKUnarchiveColorArrayTransformerName];
    return [transformer transformedValue:[[NSUserDefaults standardUserDefaults] arrayForKey:SKSwatchColorsKey]];
}

#pragma mark Convenience

- (uint32_t)uint32HSBAValue {
    NSColor *rgbColor = [self colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (rgbColor) {
        CGFloat h = 0.0, s = 0.0, b = 0.0, a = 0.0;
        [rgbColor getHue:&h saturation:&s brightness:&b alpha:&a];
        union _ {
            struct {
                uint8_t h;
                uint8_t s;
                uint8_t b;
                uint8_t a;
            } hsba;
            uint32_t uintValue;
        } u;
        u.hsba.h = (uint8_t)(h * 255);
        u.hsba.s = (uint8_t)(s * 255);
        u.hsba.b = (uint8_t)(b * 255);
        u.hsba.a = (uint8_t)(a * 255);
        return CFSwapInt32HostToBig(u.uintValue);
    }
    return 0;
}

- (NSComparisonResult)colorCompare:(NSColor *)aColor {
    uint32_t value1 = [self uint32HSBAValue];
    uint32_t value2 = [aColor uint32HSBAValue];
    if (value1 < value2)
        return NSOrderedAscending;
    else if (value1 > value2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

- (CGFloat)luminance {
    CGFloat c[4];
    [[self colorUsingColorSpace:[NSColorSpace sRGBColorSpace]] getComponents:c];
    NSUInteger i;
    for (i = 0; i < 3; i++)
        c[i] = c[i] <= 0.04045 ? c[i] / 12.92 : pow((c[i] + 0.055) / 1.055, 2.4);
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

- (void)drawSwatchInRoundedRect:(NSRect)rect {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:3.0 yRadius:3.0];
    [path setLineWidth:2.0];
    [path addClip];
    [self drawSwatchInRect:rect];
    [[NSColor colorWithGenericGamma22White:0.0 alpha:0.3] setStroke];
    [path stroke];
}

- (NSColor *)opaqueColor {
    __block NSColor *color = nil;
    SKRunWithAppearance(NSApp, ^{
        if ([color alphaComponent] < 1.0)
            color = [color colorWithAlphaComponent:1.0];
    });
    return color ?: self;
}

#pragma mark Scripting

+ (instancetype)scriptingRgbaColorWithDescriptor:(NSAppleEventDescriptor *)descriptor {
    if ([descriptor descriptorType] == typeAEList) {
        CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
        if ([descriptor numberOfItems] > 0)
            red = green = blue = (CGFloat)[[descriptor descriptorAtIndex:1] int32Value] / 65535.0f;
        if ([descriptor numberOfItems] > 2) {
            green = (CGFloat)[[descriptor descriptorAtIndex:2] int32Value] / 65535.0f;
            blue = (CGFloat)[[descriptor descriptorAtIndex:3] int32Value] / 65535.0f;
        }
        if ([descriptor numberOfItems] == 2)
            alpha = (CGFloat)[[descriptor descriptorAtIndex:2] int32Value] / 65535.0f;
        else if ([descriptor numberOfItems] > 3)
            alpha = (CGFloat)[[descriptor descriptorAtIndex:4] int32Value] / 65535.0f;
        else
            alpha= 1.0;
        return [[NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    } else if ([descriptor descriptorType] == typeEnumerated) {
        switch ([descriptor enumCodeValue]) {
            case SKScriptingColorRed: return [NSColor redColor];
            case SKScriptingColorGreen: return [NSColor greenColor];
            case SKScriptingColorBlue: return [NSColor blueColor];
            case SKScriptingColorYellow: return [NSColor yellowColor];
            case SKScriptingColorMagenta: return [NSColor magentaColor];
            case SKScriptingColorCyan: return [NSColor cyanColor];
            case SKScriptingColorDarkRed: return [NSColor colorWithSRGBRed:0.5 green:0.0 blue:0.0 alpha:1.0];
            case SKScriptingColorDarkGreen: return [NSColor colorWithSRGBRed:0.0 green:0.5 blue:0.0 alpha:1.0];
            case SKScriptingColorDarkBlue: return [NSColor colorWithSRGBRed:0.0 green:0.0 blue:0.5 alpha:1.0];
            case SKScriptingColorBanana: return [NSColor colorWithSRGBRed:1.0 green:1.0 blue:0.5 alpha:1.0];
            case SKScriptingColorTurquoise: return [NSColor colorWithSRGBRed:1.0 green:0.5 blue:1.0 alpha:1.0];
            case SKScriptingColorViolet: return [NSColor colorWithSRGBRed:0.5 green:1.0 blue:1.0 alpha:1.0];
            case SKScriptingColorOrange: return [NSColor orangeColor];
            case SKScriptingColorDeepPink: return [NSColor colorWithSRGBRed:1.0 green:0.0 blue:0.5 alpha:1.0];
            case SKScriptingColorSpringGreen: return [NSColor colorWithSRGBRed:0.0 green:1.0 blue:0.5 alpha:1.0];
            case SKScriptingColorAqua: return [NSColor colorWithSRGBRed:0.0 green:0.5 blue:1.0 alpha:1.0];
            case SKScriptingColorLime: return [NSColor colorWithSRGBRed:0.5 green:1.0 blue:0.0 alpha:1.0];
            case SKScriptingColorDarkViolet: return [NSColor colorWithSRGBRed:0.5 green:0.0 blue:1.0 alpha:1.0];
            case SKScriptingColorPurple: return [NSColor purpleColor];
            case SKScriptingColorTeal: return [NSColor colorWithSRGBRed:0.0 green:0.5 blue:0.5 alpha:1.0];
            case SKScriptingColorOlive: return [NSColor colorWithSRGBRed:0.5 green:0.5 blue:0.0 alpha:1.0];
            case SKScriptingColorBrown: return [NSColor brownColor];
            case SKScriptingColorBlack: return [NSColor blackColor];
            case SKScriptingColorWhite: return [NSColor whiteColor];
            case SKScriptingColorGray: return [NSColor grayColor];
            case SKScriptingColorDarkGray: return [NSColor darkGrayColor];
            case SKScriptingColorLightGray: return [NSColor lightGrayColor];
            case SKScriptingColorClear: return [NSColor clearColor];
            case SKScriptingColorUnderPageBackground: return [NSColor underPageBackgroundColor];
            case SKScriptingColorWindowBackground: return [NSColor windowBackgroundColor];
            case SKScriptingColorControlBackground: return [NSColor controlBackgroundColor];
            default: return nil;
        }
    } else {
        NSString *string = nil;
        if ([descriptor descriptorType] == typeObjectSpecifier)
            string = [[descriptor descriptorForKeyword:keyAEKeyData] stringValue];
        else
            string = [descriptor stringValue];
        // Cocoa Scripting defines coercions from string to color for some standard color names
        NSColor *color = string ? [[NSScriptCoercionHandler sharedCoercionHandler] coerceValue:string toClass:[NSColor class]] : nil;
        // We should check the return value, because NSScriptCoercionHandler returns the input when it fails rather than nil, stupid
        if ([color isKindOfClass:[NSString class]]) {
            if ([string isEqualToString:@"under page background"])
                color = [NSColor underPageBackgroundColor];
            else if ([string isEqualToString:@"window background"])
                color = [NSColor windowBackgroundColor];
            else if ([string isEqualToString:@"control background"])
                color = [NSColor controlBackgroundColor];
            else
                color = nil;
        }
        return [color isKindOfClass:[NSColor class]] ? color : nil;
    }
}

- (NSAppleEventDescriptor *)scriptingRgbaColorDescriptor;
{
    if ([self isEqual:[NSColor underPageBackgroundColor]])
        return [NSAppleEventDescriptor descriptorWithEnumCode:SKScriptingColorUnderPageBackground];
    else if ([self isEqual:[NSColor windowBackgroundColor]])
        return [NSAppleEventDescriptor descriptorWithEnumCode:SKScriptingColorWindowBackground];
    else if ([self isEqual:[NSColor controlBackgroundColor]])
        return [NSAppleEventDescriptor descriptorWithEnumCode:SKScriptingColorControlBackground];
    
    CGFloat red, green, blue, alpha;
    [[self colorUsingColorSpaceName:NSCalibratedRGBColorSpace] getRed:&red green:&green blue:&blue alpha:&alpha];
    
    NSAppleEventDescriptor *descriptor = [NSAppleEventDescriptor listDescriptor];
    [descriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:(SInt32)round(65535 * red)] atIndex:1];
    [descriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:(SInt32)round(65535 * green)] atIndex:2];
    [descriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:(SInt32)round(65535 * blue)] atIndex:3];
    [descriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:(SInt32)round(65535 * alpha)] atIndex:4];
    
    return descriptor;
}

#pragma mark Accessibility

- (NSString *)accessibilityValue {
    static NSColorWell *colorWell = nil;
    if (colorWell == nil)
        colorWell = [[NSColorWell alloc] init];
    [colorWell setColor:self];
    return [colorWell accessibilityValue];
}

#pragma mark Templating

- (NSString *)hexString {
    NSColor *rgbColor = [self colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (rgbColor) {
        CGFloat r = 0.0, g = 0.0, b = 0.0, a = 0.0;
        [rgbColor getRed:&r green:&g blue:&b alpha:&a];
        return [NSString stringWithFormat:@"#%02x%02x%02x", (unsigned int)(r * 255), (unsigned int)(g * 255), (unsigned int)(b * 255)];
    }
    return nil;
}

- (NSString *)rgbString {
    NSColor *rgbColor = [self colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (rgbColor) {
        CGFloat r = 0.0, g = 0.0, b = 0.0, a = 0.0;
        [rgbColor getRed:&r green:&g blue:&b alpha:&a];
        return [NSString stringWithFormat:@"(%u, %u, %u)", (unsigned int)(r * 255), (unsigned int)(g * 255), (unsigned int)(b * 255)];
    }
    return nil;
}

@end
