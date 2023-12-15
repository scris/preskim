//
//  SKTopBarView.m
//  Skim
//
//  Created by Adam Maxwell on 10/26/05.
/*
 This software is Copyright (c) 2005-2023
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "SKTopBarView.h"
#import "NSGeometry_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSView_SKExtensions.h"

#define SEPARATOR_WIDTH 1.0

@interface SKBackgroundView : NSView {
    NSColor *backgroundColor;
    NSColor *separatorColor;
}
@property (nonatomic, strong) NSColor *backgroundColor;
@property (nonatomic, strong) NSColor *separatorColor;
@end

#pragma mark -

@implementation SKTopBarView

@synthesize style, drawsBackground;

- (instancetype)initWithFrame:(NSRect)frame {
    wantsSubviews = YES;
    self = [super initWithFrame:frame];
    if (self) {
        drawsBackground = YES;
        blurView = [[NSVisualEffectView alloc] initWithFrame:[self bounds]];
        [super addSubview:blurView];
        backgroundView = [[SKBackgroundView alloc] initWithFrame:[self bounds]];
        [super addSubview:backgroundView];
        contentView = [[NSView alloc] initWithFrame:[self bounds]];
        [super addSubview:contentView];
        wantsSubviews = NO;
        [self setStyle:SKTopBarStyleDefault];
    }
    return self;
}

- (void)resizeSubviewsWithOldSize:(NSSize)size {
    [super resizeSubviewsWithOldSize:size];
    NSRect rect = [self bounds];
    [blurView setFrame:rect];
    [backgroundView setFrame:rect];
    [contentView setFrame:rect];
}

- (void)addSubview:(NSView *)aView {
    if (wantsSubviews)
        [super addSubview:aView];
    else
        [contentView addSubview:aView];
}

- (void)addSubview:(NSView *)aView positioned:(NSWindowOrderingMode)place relativeTo:(NSView *)otherView {
    if (wantsSubviews)
        [super addSubview:aView positioned:place relativeTo:otherView];
    else
        [contentView addSubview:aView positioned:place relativeTo:otherView];
}

- (void)replaceSubview:(NSView *)aView with:(NSView *)newView {
    if (wantsSubviews)
        [super replaceSubview:aView with:newView];
    else
        [contentView replaceSubview:aView with:newView];

}

- (void)setDrawsBackground:(BOOL)flag {
    if (drawsBackground != flag) {
        drawsBackground = flag;
        [blurView setHidden:drawsBackground == NO];
        [backgroundView setHidden:drawsBackground == NO];
    }
}

- (void)setStyle:(SKTopBarStyle)newStyle {
    style = newStyle;
    NSColor *sepColor = nil;
    switch (style) {
        case SKTopBarStyleDefault:
            if (@available(macOS 11.0, *))
                [blurView setMaterial:NSVisualEffectMaterialTitlebar];
            else if (@available(macOS 10.14, *))
                [blurView setMaterial:NSVisualEffectMaterialHeaderView];
            else
                [blurView setMaterial:NSVisualEffectMaterialTitlebar];
            [blurView setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
            if (@available(macOS 10.14, *)) {
                sepColor = [NSColor separatorColor];
            } else{
                [backgroundView setBackgroundColor:[NSColor colorWithGenericGamma22White:1.0 alpha:0.25]];
                sepColor = [NSColor colorWithGenericGamma22White:0.8 alpha:0.35];
            }
            break;
        case SKTopBarStylePDFControlBackground:
            if (@available(macOS 11.0, *))
                [blurView setMaterial:NSVisualEffectMaterialTitlebar];
            else if (@available(macOS 10.14, *))
                [blurView setMaterial:NSVisualEffectMaterialHeaderView];
            else
                [blurView setMaterial:NSVisualEffectMaterialLight];
            [blurView setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
            if (@available(macOS 10.14, *)) {} else {
                [backgroundView setBackgroundColor:[NSColor colorWithGenericGamma22White:0.98 alpha:0.5]];
            }
            break;
        case SKTopBarStylePresentation:
            if (@available(macOS 10.14, *)) {
                [blurView setMaterial:NSVisualEffectMaterialSidebar];
                [blurView setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
            } else {
                [backgroundView setBackgroundColor:[NSColor windowBackgroundColor]];
            }
            break;
    }
    [backgroundView setSeparatorColor:sepColor];
    [backgroundView setNeedsDisplay:YES];
}

@end

#pragma mark -

@implementation SKBackgroundView

@synthesize backgroundColor, separatorColor;

- (void)drawRect:(NSRect)aRect {
    NSRect rect = [self bounds];
    NSRect sepRect = NSZeroRect;
    if ([self separatorColor])
        NSDivideRect(rect, &sepRect, &rect, SEPARATOR_WIDTH, NSMinYEdge);
    
    [NSGraphicsContext saveGraphicsState];
    
    if ([self backgroundColor]) {
        [[self backgroundColor] setFill];
        [NSBezierPath fillRect:rect];
    }
    
    if ([self separatorColor]) {
        [[self separatorColor] setFill];
        [NSBezierPath fillRect:sepRect];
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

@end

