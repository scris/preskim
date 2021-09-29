//
//  NSGraphics_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 10/20/11.
/*
 This software is Copyright (c) 2011-2021
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
#import <Quartz/Quartz.h>


#if SDK_BEFORE(10_14)

@interface NSAppearance (SKMojaveExtensions)
- (NSString *)bestMatchFromAppearancesWithNames:(NSArray *)names;
@end

@interface NSApplication (SKMojaveExtensions) <NSAppearanceCustomization>
@end

#endif

BOOL SKHasDarkAppearance(id object) {
    if (RUNNING_AFTER(10_13)) {
        id appearance = nil;
        if (object == nil)
            appearance = [NSAppearance currentAppearance];
        else if ([object respondsToSelector:@selector(effectiveAppearance)])
            appearance = [(id<NSAppearanceCustomization>)object effectiveAppearance];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        return [[appearance bestMatchFromAppearancesWithNames:[NSArray arrayWithObjects:@"NSAppearanceNameAqua", @"NSAppearanceNameDarkAqua", nil]] isEqualToString:@"NSAppearanceNameDarkAqua"];
#pragma clang diagnostic pop
    }
    return NO;
}

void SKSetHasDarkAppearance(id object) {
    if (RUNNING_AFTER(10_13) && [object respondsToSelector:@selector(setAppearance:)])
        [(id<NSAppearanceCustomization>)object setAppearance:[NSAppearance appearanceNamed:@"NSAppearanceNameDarkAqua"]];
}

void SKSetHasLightAppearance(id object) {
    if (RUNNING_AFTER(10_13) && [object respondsToSelector:@selector(setAppearance:)])
        [(id<NSAppearanceCustomization>)object setAppearance:[NSAppearance appearanceNamed:@"NSAppearanceNameAqua"]];
}

void SKSetHasDefaultAppearance(id object) {
    if (RUNNING_AFTER(10_13) && [object respondsToSelector:@selector(setAppearance:)])
        [(id<NSAppearanceCustomization>)object setAppearance:nil];
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

void SKDrawResizeHandle(CGContextRef context, NSPoint point, CGFloat lineWidth, BOOL active)
{
    SKSetColorsForResizeHandle(context, active);
    CGContextSetLineWidth(context, lineWidth);
    SKFillStrokeResizeHandle(context, point, lineWidth);
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
            CGFloat minY = NSMinY(rect) + 0.5 * lineWidth;
            CGFloat maxY = NSMaxY(rect) - 0.5 * lineWidth;
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
            CGFloat minX = NSMinX(rect) + 0.5 * lineWidth;
            CGFloat maxX = NSMaxX(rect) - 0.5 * lineWidth;
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

extern NSArray *SKColorInvertFilters(void) {
    if (SKHasDarkAppearance(NSApp))
        return [NSArray arrayWithObjects:[CIFilter filterWithName:@"CIColorInvert"], [CIFilter filterWithName:@"CIHueAdjust" keysAndValues:kCIInputAngleKey, [NSNumber numberWithDouble:M_PI], nil], nil];
    else
        return [NSArray array];
}
