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
#import "SKReflectionView.h"
#import "NSGeometry_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSView_SKExtensions.h"

#define SKDisableSearchBarBlurringKey @"SKDisableSearchBarBlurring"

#define SEPARATOR_WIDTH 1.0

@implementation SKTopBarView

@synthesize contentView, backgroundColors, alternateBackgroundColors, separatorColor, overflowEdge, hasSeparator, drawsBackground;
@dynamic contentRect;

- (id)initWithFrame:(NSRect)frame {
    wantsSubviews = YES;
    self = [super initWithFrame:frame];
    if (self) {
        hasSeparator = NO; // we start with no separator, so we can use this in IB without getting weird offsets
		overflowEdge = NSMaxXEdge;
        drawsBackground = YES;
        if (RUNNING_AFTER(10_13)) {
            backgroundColors = nil;
            alternateBackgroundColors = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
            separatorColor = [[NSColor separatorColor] retain];
#pragma clang diagnostic pop
            backgroundView = [[NSVisualEffectView alloc] initWithFrame:[self contentRect]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
            [backgroundView setMaterial:RUNNING_AFTER(10_15) ? NSVisualEffectMaterialTitlebar : NSVisualEffectMaterialHeaderView];
#pragma clang diagnostic pop
            [backgroundView setBlendingMode:NSVisualEffectBlendingModeWithinWindow];
            [super addSubview:backgroundView];
        } else {
            static CGFloat defaultGrays[5] = {0.85, 0.9,  0.9, 0.95,  0.8};
            backgroundColors = [[NSArray alloc] initWithObjects:[NSColor colorWithGenericGamma22White:defaultGrays[0] alpha:1.0], [NSColor colorWithGenericGamma22White:defaultGrays[1] alpha:1.0], nil];
            alternateBackgroundColors = [[NSArray alloc] initWithObjects:[NSColor colorWithGenericGamma22White:defaultGrays[2] alpha:1.0], [NSColor colorWithGenericGamma22White:defaultGrays[3] alpha:1.0], nil];
            separatorColor = [[NSColor colorWithGenericGamma22White:defaultGrays[4] alpha:1.0] retain];
        }
        contentView = [[NSView alloc] initWithFrame:[self contentRect]];
        [super addSubview:contentView];
        wantsSubviews = NO;
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
        reflectionView = [[decoder decodeObjectForKey:@"reflectionView"] retain];
        backgroundColors = [[decoder decodeObjectForKey:@"backgroundColors"] retain];
        alternateBackgroundColors = [[decoder decodeObjectForKey:@"alternateBackgroundColors"] retain];
        separatorColor = [[decoder decodeObjectForKey:@"separatorColor"] retain];
		overflowEdge = [decoder decodeIntegerForKey:@"overflowEdge"];
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
    [coder encodeConditionalObject:reflectionView forKey:@"reflectionView"];
    [coder encodeObject:backgroundColors forKey:@"backgroundColors"];
    [coder encodeObject:alternateBackgroundColors forKey:@"alternateBackgroundColors"];
    [coder encodeInteger:overflowEdge forKey:@"overflowEdge"];
    [coder encodeBool:hasSeparator forKey:@"hasSeparator"];
    [coder encodeBool:drawsBackground forKey:@"drawsBackground"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SKDESTROY(contentView);
    SKDESTROY(backgroundView);
    SKDESTROY(reflectionView);
    SKDESTROY(backgroundColors);
    SKDESTROY(alternateBackgroundColors);
    SKDESTROY(separatorColor);
	[super dealloc];
}

- (void)resizeSubviewsWithOldSize:(NSSize)size {
    [super resizeSubviewsWithOldSize:size];
    NSRect rect = [self contentRect];
    [backgroundView setFrame:rect];
    [reflectionView setFrame:rect];
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

- (void)drawRect:(NSRect)aRect
{        
	if ([self drawsBackground] == NO)
        return;
    
    NSRect rect = [self bounds];
	
    [NSGraphicsContext saveGraphicsState];
    
    if (hasSeparator) {
        NSRect edgeRect;
		NSDivideRect(rect, &edgeRect, &rect, SEPARATOR_WIDTH, NSMinYEdge);
        [[self separatorColor] setFill];
        [NSBezierPath fillRect:edgeRect];
	}
    
    NSArray *colors = backgroundColors;
    if (alternateBackgroundColors && [[self window] isMainWindow] == NO && [[self window] isKeyWindow] == NO)
        colors = alternateBackgroundColors;
    
    if ([colors count] > 1) {
        NSGradient *aGradient = [[NSGradient alloc] initWithColors:colors];
        [aGradient drawInRect:rect angle:90.0];
        [aGradient release];
    } else if ([colors count] == 1) {
        [[colors firstObject] setFill];
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
    if (drawsBackground && alternateBackgroundColors) {
        NSWindow *oldWindow = [self window];
        if (oldWindow)
            [self stopObservingWindow:oldWindow];
        if (newWindow)
            [self startObservingWindow:newWindow];
    }
    [super viewWillMoveToWindow:newWindow];
}

// required in order for redisplay to work properly with the controls
- (BOOL)isOpaque{ return [self drawsBackground] && [self backgroundColors]; }

- (void)setHasSeparator:(BOOL)flag {
	if (flag != hasSeparator) {
		hasSeparator = flag;
        NSRect rect = [self contentRect];
        [backgroundView setFrame:rect];
        [reflectionView setFrame:rect];
        [contentView setFrame:rect];
		[self setNeedsDisplay:YES];
	}
}

- (void)setDrawsBackground:(BOOL)flag {
    if (flag != drawsBackground) {
        if ([self window] && alternateBackgroundColors) {
            if (drawsBackground)
                [self stopObservingWindow:[self window]];
            else
                [self startObservingWindow:[self window]];
        }
        drawsBackground = flag;
        [backgroundView setHidden:drawsBackground == NO];
        [reflectionView setHidden:drawsBackground == NO];
        [self setNeedsDisplay:YES];
    }
}

- (void)setAlternateBackgroundColors:(NSArray *)colors {
    if (colors != alternateBackgroundColors) {
        if ([self window] && drawsBackground) {
            if (alternateBackgroundColors && colors == nil)
                [self stopObservingWindow:[self window]];
            else if (alternateBackgroundColors == nil && colors)
                [self startObservingWindow:[self window]];
        }
        [alternateBackgroundColors release];
        alternateBackgroundColors = [colors copy];
    }
}

- (NSRect)contentRect {
    NSRect rect = [self bounds];
    if (hasSeparator)
        rect = SKShrinkRect(rect, SEPARATOR_WIDTH, NSMinYEdge);
    return rect;
}

- (void)reflectView:(NSView *)view animate:(BOOL)animate wantsFilters:(BOOL)wantsFilters {
    if (RUNNING_BEFORE(10_14) || [[NSUserDefaults standardUserDefaults] boolForKey:SKDisableSearchBarBlurringKey])
        return;
    NSScrollView *scrollView = [view descendantOfClass:[NSScrollView class]];
    if (scrollView == [reflectionView reflectedScrollView]) {
        [reflectionView setWantsFilters:wantsFilters];
        return;
    }
    if (animate == NO || [self drawsBackground] == NO) {
        if (reflectionView == nil) {
            reflectionView = [[SKReflectionView alloc] initWithFrame:[self contentRect]];
            [reflectionView setHidden:drawsBackground == NO];
            [reflectionView setReflectedScrollView:scrollView];
            wantsSubviews = YES;
            [super addSubview:reflectionView positioned:NSWindowBelow relativeTo:nil];
            wantsSubviews = NO;
        } else {
            [reflectionView setReflectedScrollView:scrollView];
        }
        [reflectionView setWantsFilters:wantsFilters];
    } else {
        SKReflectionView *newView = [[SKReflectionView alloc] initWithFrame:[self contentRect]];
        [newView setHidden:drawsBackground == NO];
        [newView setReflectedScrollView:scrollView];
        [newView setWantsFilters:wantsFilters];
        wantsSubviews = YES;
        if (reflectionView)
            [[self animator] replaceSubview:reflectionView with:newView];
        else
            [[self animator] addSubview:newView positioned:NSWindowBelow relativeTo:nil];
        wantsSubviews = NO;
        [reflectionView release];
        reflectionView = newView;
    }
}

@end
