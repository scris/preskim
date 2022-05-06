//
//  SKTopBarView.m
//  Skim
//
//  Created by Adam Maxwell on 10/26/05.
/*
 This software is Copyright (c) 2005-2022
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

#define SKDisableSearchBarBlurringKey @"SKDisableSearchBarBlurring"

#define SEPARATOR_WIDTH 1.0

@implementation SKTopBarView

@synthesize contentView, backgroundColors, alternateBackgroundColors, hasSeparator, drawsBackground;

- (id)initWithFrame:(NSRect)frame {
    wantsSubviews = YES;
    self = [super initWithFrame:frame];
    if (self) {
        hasSeparator = NO; // we start with no separator, so we can use this in IB without getting weird offsets
        if (RUNNING_AFTER(10_13)) {
            backgroundView = [[NSVisualEffectView alloc] initWithFrame:[self bounds]];
            [super addSubview:backgroundView];
        }
        contentView = [[NSView alloc] initWithFrame:[self bounds]];
        [super addSubview:contentView];
        wantsSubviews = NO;
        [self applyDefaultBackground];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    wantsSubviews = YES;
	self = [super initWithCoder:decoder];
    if (self) {
		// this decodes only the reference, the actual view should already be decoded as a subview
        contentView = [[decoder decodeObjectForKey:@"contentView"] retain];
        backgroundView = [[decoder decodeObjectForKey:@"backgroundView"] retain];
        separatorView = [[decoder decodeObjectForKey:@"separatorView"] retain];
        backgroundColors = [[decoder decodeObjectForKey:@"backgroundColors"] retain];
        alternateBackgroundColors = [[decoder decodeObjectForKey:@"alternateBackgroundColors"] retain];
        hasSeparator = [decoder decodeBoolForKey:@"hasSeparator"];
        drawsBackground = [decoder decodeBoolForKey:@"drawsBackground"];
        wantsSubviews = NO;
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    // this encodes only a reference, the actual contentView should already be encoded because it's a subview
    [coder encodeConditionalObject:contentView forKey:@"contentView"];
    [coder encodeConditionalObject:backgroundView forKey:@"backgroundView"];
    [coder encodeObject:backgroundColors forKey:@"backgroundColors"];
    [coder encodeObject:alternateBackgroundColors forKey:@"alternateBackgroundColors"];
    [coder encodeBool:hasSeparator forKey:@"hasSeparator"];
    [coder encodeBool:drawsBackground forKey:@"drawsBackground"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SKDESTROY(contentView);
    SKDESTROY(backgroundView);
    SKDESTROY(separatorView);
    SKDESTROY(backgroundColors);
    SKDESTROY(alternateBackgroundColors);
	[super dealloc];
}

- (void)resizeSubviewsWithOldSize:(NSSize)size {
    [super resizeSubviewsWithOldSize:size];
    NSRect rect = [self bounds];
    [backgroundView setFrame:rect];
    [contentView setFrame:rect];
    [separatorView setFrame:SKSliceRect(rect, SEPARATOR_WIDTH, NSMinYEdge)];
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

- (void)drawRect:(NSRect)aRect {
    if (drawsBackground == NO)
        return;
    
    NSArray *colors = backgroundColors;
    if (alternateBackgroundColors && [[self window] isMainWindow] == NO && [[self window] isKeyWindow] == NO)
        colors = alternateBackgroundColors;
    
    if ([colors count] == 0)
        return;
    
    NSRect rect = [self bounds];
    NSRect sepRect = NSZeroRect;
    if (hasSeparator)
        NSDivideRect(rect, &sepRect, &rect, SEPARATOR_WIDTH, NSMinYEdge);
    
    [NSGraphicsContext saveGraphicsState];
    
    if ([colors count] > 1) {
        NSGradient *aGradient = [[NSGradient alloc] initWithColors:colors];
        [aGradient drawInRect:rect angle:90.0];
        [aGradient release];
    } else if ([colors count] == 1) {
        [[colors firstObject] setFill];
        [NSBezierPath fillRect:rect];
    }
    
    if (RUNNING_BEFORE(10_14) && hasSeparator) {
        [[NSColor colorWithGenericGamma22White:0.8 alpha:1.0] setFill];
        [NSBezierPath fillRect:rect];
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

- (void)handleKeyOrMainStateChangedNotification:(NSNotification *)note {
    [self setNeedsDisplay:YES];
}

- (void)startObservingWindow:(NSWindow *)window {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidBecomeMainNotification object:window];
    [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidResignMainNotification object:window];
    [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidBecomeKeyNotification object:window];
    [nc addObserver:self selector:@selector(handleKeyOrMainStateChangedNotification:) name:NSWindowDidResignKeyNotification object:window];
}

- (void)stopObservingWindow:(NSWindow *)window {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:NSWindowDidBecomeMainNotification object:window];
    [nc removeObserver:self name:NSWindowDidResignMainNotification object:window];
    [nc removeObserver:self name:NSWindowDidBecomeKeyNotification object:window];
    [nc removeObserver:self name:NSWindowDidResignKeyNotification object:window];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    if (alternateBackgroundColors) {
        NSWindow *oldWindow = [self window];
        if (oldWindow)
            [self stopObservingWindow:oldWindow];
        if (newWindow)
            [self startObservingWindow:newWindow];
    }
    [super viewWillMoveToWindow:newWindow];
}

- (void)setHasSeparator:(BOOL)flag {
	if (flag != hasSeparator) {
		hasSeparator = flag;
        if (RUNNING_AFTER(10_13)) {
            if (separatorView == nil && hasSeparator) {
                separatorView = [[NSBox alloc] initWithFrame:SKSliceRect([self bounds], SEPARATOR_WIDTH, NSMinYEdge)];
                [separatorView setBoxType:NSBoxCustom];
                [separatorView setBorderType:NSNoBorder];
                [separatorView setTitlePosition:NSNoTitle];
                [separatorView setBorderWidth:0.0];
                [separatorView setContentViewMargins:NSZeroSize];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
                [separatorView setFillColor:[NSColor separatorColor]];
#pragma clang diagnostic pop
                wantsSubviews = YES;
                [super addSubview:separatorView positioned:NSWindowBelow relativeTo:contentView];
                wantsSubviews = NO;
            }
            [separatorView setHidden:hasSeparator == NO];
        } else {
            [self setNeedsDisplay:YES];
        }
	}
}

- (void)setDrawsBackground:(BOOL)flag {
    if (drawsBackground != flag) {
        drawsBackground = flag;
        [backgroundView setHidden:drawsBackground == NO];
        [separatorView setHidden:drawsBackground == NO];
        if (RUNNING_BEFORE(10_14))
            [self setNeedsDisplay:YES];
    }
}

- (void)setAlternateBackgroundColors:(NSArray *)colors {
    if (colors != alternateBackgroundColors) {
        if ([self window]) {
            if (alternateBackgroundColors && colors == nil)
                [self stopObservingWindow:[self window]];
            else if (alternateBackgroundColors == nil && colors)
                [self startObservingWindow:[self window]];
        }
        [alternateBackgroundColors release];
        alternateBackgroundColors = [colors copy];
    }
}

- (void)applyDefaultBackground {
    if (RUNNING_AFTER(10_13)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        [backgroundView setMaterial:RUNNING_AFTER(10_15) ? NSVisualEffectMaterialTitlebar : NSVisualEffectMaterialHeaderView];
#pragma clang diagnostic pop
        [backgroundView setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
    } else {
        static CGFloat defaultGrays[5] = {0.85, 0.9,  0.9, 0.95};
        [self setBackgroundColors:[NSArray arrayWithObjects:[NSColor colorWithGenericGamma22White:defaultGrays[0] alpha:1.0], [NSColor colorWithGenericGamma22White:defaultGrays[1] alpha:1.0], nil]];
        [self setAlternateBackgroundColors:[NSArray arrayWithObjects:[NSColor colorWithGenericGamma22White:defaultGrays[2] alpha:1.0], [NSColor colorWithGenericGamma22White:defaultGrays[3] alpha:1.0], nil]];
    }
}

- (void)applyPresentationBackground {
    if (RUNNING_AFTER(10_13)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        [backgroundView setMaterial:NSVisualEffectMaterialSidebar];
#pragma clang diagnostic pop
        [backgroundView setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
    } else {
        [self setBackgroundColors:[NSArray arrayWithObjects:[NSColor windowBackgroundColor], nil]];
        [self setAlternateBackgroundColors:nil];
    }
}

@end
