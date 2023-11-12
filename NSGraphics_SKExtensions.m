//
//  NSGraphics_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 10/20/11.
/*
 This software is Copyright (c) 2011-2023
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

#import "NSGraphics_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import <Quartz/Quartz.h>
#import "SKStringConstants.h"


#if SDK_BEFORE(10_14)

@interface NSAppearance (SKMojaveExtensions)
- (NSString *)bestMatchFromAppearancesWithNames:(NSArray *)names;
@end

@interface NSApplication (SKMojaveExtensions) <NSAppearanceCustomization>
@end

#define NSAppearanceNameDarkAqua @"NSAppearanceNameDarkAqua"

#endif

BOOL SKHasDarkAppearance(id object) {
    if (@available(macOS 10.14, *)) {
        id appearance = nil;
        if (object == nil)
            appearance = [NSAppearance currentAppearance];
        else if ([object respondsToSelector:@selector(effectiveAppearance)])
            appearance = [(id<NSAppearanceCustomization>)object effectiveAppearance];
        return [[appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
    }
    return NO;
}

void SKSetHasDarkAppearance(id object) {
    if (@available(macOS 10.14, *)) {
        if ([object respondsToSelector:@selector(setAppearance:)])
            [(id<NSAppearanceCustomization>)object setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
    }
}

void SKSetHasLightAppearance(id object) {
    if (@available(macOS 10.14, *)) {
        if ([object respondsToSelector:@selector(setAppearance:)])
            [(id<NSAppearanceCustomization>)object setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
    }
}

void SKSetHasDefaultAppearance(id object) {
    if (@available(macOS 10.14, *)) {
        if ([object respondsToSelector:@selector(setAppearance:)])
            [(id<NSAppearanceCustomization>)object setAppearance:nil];
    }
}

void SKRunWithAppearance(id object, void (^code)(void)) {
    NSAppearance *appearance = nil;
    if ([object respondsToSelector:@selector(effectiveAppearance)]) {
        appearance = [[[NSAppearance currentAppearance] retain] autorelease];
        [NSAppearance setCurrentAppearance:[(id<NSAppearanceCustomization>)object effectiveAppearance]];
    }
    code();
    if ([object respondsToSelector:@selector(effectiveAppearance)])
        [NSAppearance setCurrentAppearance:appearance];
}

void SKRunWithLightAppearance(void (^code)(void)) {
    NSAppearance *appearance = [[[NSAppearance currentAppearance] retain] autorelease];
    [NSAppearance setCurrentAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
    code();
    [NSAppearance setCurrentAppearance:appearance];
}

#pragma mark -

void SKSetColorsForResizeHandle(CGContextRef context, BOOL active)
{
    NSColor *color = [NSColor selectionHighlightInteriorColor:active];
    CGContextSetFillColorWithColor(context, [color CGColor]);
    color = [NSColor selectionHighlightColor:active];
    CGContextSetStrokeColorWithColor(context, [color CGColor]);
}

void SKFillStrokeResizeHandle(CGContextRef context, NSPoint point, CGFloat lineWidth)
{
    CGRect rect = CGRectMake(point.x - 3.5 * lineWidth, point.y - 3.5 * lineWidth, 7.0 * lineWidth, 7.0 * lineWidth);
    CGContextFillEllipseInRect(context, rect);
    CGContextStrokeEllipseInRect(context, rect);
}

void SKDrawResizeHandles(CGContextRef context, NSRect rect, CGFloat lineWidth, BOOL connected, BOOL active)
{
    SKSetColorsForResizeHandle(context, active);
    CGContextSetLineWidth(context, lineWidth);
    SKFillStrokeResizeHandle(context, NSMakePoint(NSMinX(rect), NSMidY(rect)), lineWidth);
    SKFillStrokeResizeHandle(context, NSMakePoint(NSMidX(rect), NSMaxY(rect)), lineWidth);
    SKFillStrokeResizeHandle(context, NSMakePoint(NSMidX(rect), NSMinY(rect)), lineWidth);
    SKFillStrokeResizeHandle(context, NSMakePoint(NSMaxX(rect), NSMidY(rect)), lineWidth);
    SKFillStrokeResizeHandle(context, NSMakePoint(NSMinX(rect), NSMaxY(rect)), lineWidth);
    SKFillStrokeResizeHandle(context, NSMakePoint(NSMinX(rect), NSMinY(rect)), lineWidth);
    SKFillStrokeResizeHandle(context, NSMakePoint(NSMaxX(rect), NSMaxY(rect)), lineWidth);
    SKFillStrokeResizeHandle(context, NSMakePoint(NSMaxX(rect), NSMinY(rect)), lineWidth);
    if (connected) {
        if (NSWidth(rect) > 14.0 * lineWidth) {
            CGFloat minY = NSMinY(rect) - 0.5 * lineWidth;
            CGFloat maxY = NSMaxY(rect) + 0.5 * lineWidth;
            CGPoint points[8] = {
                {NSMinX(rect) + 3.5 * lineWidth, maxY},
                {NSMidX(rect) - 3.5 * lineWidth, maxY},
                {NSMidX(rect) + 3.5 * lineWidth, maxY},
                {NSMaxX(rect) - 3.5 * lineWidth, maxY},
                {NSMinX(rect) + 3.5 * lineWidth, minY},
                {NSMidX(rect) - 3.5 * lineWidth, minY},
                {NSMidX(rect) + 3.5 * lineWidth, minY},
                {NSMaxX(rect) - 3.5 * lineWidth, minY}};
            CGContextStrokeLineSegments(context, points, 8);
        }
        if (NSHeight(rect) > 14.0 * lineWidth) {
            CGFloat minX = NSMinX(rect) - 0.5 * lineWidth;
            CGFloat maxX = NSMaxX(rect) + 0.5 * lineWidth;
            CGPoint points[8] = {
                {minX, NSMinY(rect) + 3.5 * lineWidth},
                {minX, NSMidY(rect) - 3.5 * lineWidth},
                {minX, NSMidY(rect) + 3.5 * lineWidth},
                {minX, NSMaxY(rect) - 3.5 * lineWidth},
                {maxX, NSMinY(rect) + 3.5 * lineWidth},
                {maxX, NSMidY(rect) - 3.5 * lineWidth},
                {maxX, NSMidY(rect) + 3.5 * lineWidth},
                {maxX, NSMaxY(rect) - 3.5 * lineWidth}};
            CGContextStrokeLineSegments(context, points, 8);
        }
    }
}

void SKDrawResizeHandlePair(CGContextRef context, NSPoint point1, NSPoint point2, CGFloat lineWidth, BOOL active)
{
    SKSetColorsForResizeHandle(context, active);
    CGContextSetLineWidth(context, lineWidth);
    SKFillStrokeResizeHandle(context, point1, lineWidth);
    SKFillStrokeResizeHandle(context, point2, lineWidth);
}

#pragma mark -

void SKDrawTextFieldBezel(NSRect rect, NSView *controlView) {
    static NSTextFieldCell *cell = nil;
    if (cell == nil) {
        cell = [[NSTextFieldCell alloc] initTextCell:@""];
        [cell setBezeled:YES];
    }
    [cell drawWithFrame:rect inView:controlView];
    [cell setControlView:nil];
}

#pragma mark -

#define LR 0.2126
#define LG 0.7152
#define LB 0.0722

extern NSArray *SKColorEffectFilters(void) {
    NSMutableArray *filters = [NSMutableArray array];
    CIFilter *filter;
    CGFloat sepia = [[NSUserDefaults standardUserDefaults] doubleForKey:SKSepiaToneKey];
    if (sepia > 0.0) {
        if ((filter = [CIFilter filterWithName:@"CISepiaTone" keysAndValues:@"inputIntensity", [NSNumber numberWithDouble:fmin(sepia, 1.0)], nil]))
            [filters addObject:filter];
    }
    NSColor *white = [[NSUserDefaults standardUserDefaults] colorForKey:SKWhitePointKey];
    if (white) {
        if ((filter = [CIFilter filterWithName:@"CIWhitePointAdjust" keysAndValues:@"inputColor", [[[CIColor alloc] initWithColor:white] autorelease], nil]))
            [filters addObject:filter];
    }
    if (SKHasDarkAppearance(NSApp) && [[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey]) {
        // map the white page background to 45/255, or 30/255 with high contrast
        CGFloat f = [[NSWorkspace sharedWorkspace] accessibilityDisplayShouldIncreaseContrast] ? 1.9337 : 1.8972;
        // This is like CIColorInvert + CIHueAdjust, modified to map white to dark gray rather than black
        // Inverts a linear luminocity with weights from the CIE standards
        // see https://wiki.preterhuman.net/Matrix_Operations_for_Image_Processingand https://beesbuzz.biz/code/16-hsv-color-transforms
        if ((filter = [CIFilter filterWithName:@"CIGammaAdjust" keysAndValues:@"inputPower", [NSNumber numberWithDouble:0.625], nil]))
            [filters addObject:filter];
        if ((filter = [CIFilter filterWithName:@"CIColorMatrix" keysAndValues:@"inputRVector", [CIVector vectorWithX:1.0-LR*f Y:-LG*f Z:-LB*f W:0.0], @"inputGVector", [CIVector vectorWithX:-LR*f Y:1.0-LG*f Z:-LB*f W:0.0], @"inputBVector", [CIVector vectorWithX:-LR*f Y:-LG*f Z:1.0-LB*f W:0.0], @"inputAVector", [CIVector vectorWithX:0.0 Y:0.0 Z:0.0 W:1.0], @"inputBiasVector", [CIVector vectorWithX:1.0 Y:1.0 Z:1.0 W:0.0], nil]))
            [filters addObject:filter];
        if ((filter = [CIFilter filterWithName:@"CIGammaAdjust" keysAndValues:@"inputPower", [NSNumber numberWithDouble:1.6], nil]))
            [filters addObject:filter];
    }
    return filters;
}
