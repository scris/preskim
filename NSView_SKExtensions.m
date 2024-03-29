//
//  NSView_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 9/17/07.
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

#import "NSView_SKExtensions.h"
#import "SKLineWell.h"
#import "SKFontWell.h"
#import "SKStringConstants.h"

@implementation NSView (SKExtensions)

- (id)descendantOfClass:(Class)aClass {
	if ([self isKindOfClass:aClass])
		return self;
	
	NSView *view;
	
	for (NSView *subview in [self subviews]) {
		if ((view = [subview descendantOfClass:aClass]))
			return view;
	}
	return nil;
}

- (void)deactivateWellSubcontrols {
    [[self subviews] makeObjectsPerformSelector:_cmd];
}

- (void)deactivateColorWellSubcontrols {
    [[self subviews] makeObjectsPerformSelector:_cmd];
}

- (SKFontWell *)activeFontWell {
	SKFontWell *fontWell;
    for (NSView *subview in [self subviews]) {
        if ((fontWell = [subview activeFontWell]))
            return fontWell;
    }
    return nil;
}

- (NSRect)convertRectToScreen:(NSRect)rect {
    return [[self window] convertRectToScreen:[self convertRect:rect toView:nil]];
}

- (NSRect)convertRectFromScreen:(NSRect)rect {
    return [self convertRect:[[self window] convertRectFromScreen:rect] fromView:nil];
}

- (NSPoint)convertPointToScreen:(NSPoint)point {
    NSRect rect = NSZeroRect;
    rect.origin = [self convertPoint:point toView:nil];
    return [[self window] convertRectToScreen:rect].origin;
}

- (NSPoint)convertPointFromScreen:(NSPoint)point {
    NSRect rect = NSZeroRect;
    rect.origin = point;
    return [self convertPoint:[[self window] convertRectFromScreen:rect].origin fromView:nil];
}

- (NSBitmapImageRep *)bitmapImageRepCachingDisplayInRect:(NSRect)rect {
    NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:rect];
    [self cacheDisplayInRect:rect toBitmapImageRep:imageRep];
    return imageRep;
}

- (void)activateConstraintsToSuperview {
    NSView *superview = [self superview];
    NSArray *constraints = @[
        [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:superview attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:superview attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:superview attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:superview attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0]];
    [NSLayoutConstraint activateConstraints:constraints];
}

- (NSLayoutConstraint *)constraintWithFirstItem:(id)item firstAttribute:(NSLayoutAttribute)attribute {
    for (NSLayoutConstraint *constraint in [self constraints]) {
        if ([constraint firstItem] == item && [constraint firstAttribute] == attribute)
            return constraint;
    }
    return nil;
}

- (NSLayoutConstraint *)constraintWithSecondItem:(id)item secondAttribute:(NSLayoutAttribute)attribute {
    for (NSLayoutConstraint *constraint in [self constraints]) {
        if ([constraint secondItem] == item && [constraint secondAttribute] == attribute)
            return constraint;
    }
    return nil;
}

+ (BOOL)shouldShowSlideAnimation {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableAnimationsKey])
        return NO;
    if ([[NSWorkspace sharedWorkspace] accessibilityDisplayShouldReduceMotion])
        return NO;
    return YES;
}

+ (BOOL)shouldShowFadeAnimation {
    return NO == [[NSUserDefaults standardUserDefaults] boolForKey:SKDisableAnimationsKey];
}

@end


@interface NSColorWell (SKNSViewExtensions)
@end

@implementation NSColorWell (SKNSViewExtensions)

- (void)deactivateWellSubcontrols {
    [self deactivate];
    [super deactivateWellSubcontrols];
}

- (void)deactivateColorWellSubcontrols {
    [self deactivate];
    [super deactivateColorWellSubcontrols];
}

@end


@interface SKLineWell (SKNSViewExtensions)
@end

@implementation SKLineWell (SKNSViewExtensions)

- (void)deactivateWellSubcontrols {
    [self deactivate];
    [super deactivateWellSubcontrols];
}

@end


@interface SKFontWell (SKNSViewExtensions)
@end

@implementation SKFontWell (SKNSViewExtensions)

- (void)deactivateWellSubcontrols {
    [self deactivate];
    [super deactivateWellSubcontrols];
}

- (SKFontWell *)activeFontWell {
    if ([self isActive])
        return self;
    return [super activeFontWell];
}

@end
