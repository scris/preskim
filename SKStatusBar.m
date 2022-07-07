//
//  SKStatusBar.m
//  Skim
//
//  Created by Christiaan Hofman on 7/8/07.
/*
 This software is Copyright (c) 2007-2022
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

#import "SKStatusBar.h"
#import "NSGeometry_SKExtensions.h"
#import "SKStringConstants.h"
#import "NSEvent_SKExtensions.h"
#import "SKApplication.h"
#import "NSView_SKExtensions.h"

#define LEFT_MARGIN         8.0
#define RIGHT_MARGIN        16.0
#define SEPARATION          4.0
#define ICON_OFFSET         1.0


@interface SKStatusTextField : NSTextField
@end

@interface SKStatusTextFieldCell : NSTextFieldCell {
    BOOL underlined;
}
@property (nonatomic, getter=isUnderlined) BOOL underlined;
@end

#pragma mark -

@implementation SKStatusBar

@synthesize animating, leftField, rightField, progressIndicator;
@dynamic visible, icon, progressIndicatorStyle;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
`        leftField = [[SKStatusTextField alloc] init];
        [leftField setBezeled:NO];
        [leftField setBordered:NO];
        [leftField setDrawsBackground:NO];
        [leftField setEditable:NO];
        [leftField setSelectable:NO];
        [leftField setControlSize:NSSmallControlSize];
        [leftField setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:leftField];
        
        rightField = [[SKStatusTextField alloc] init];
        [rightField setBezeled:NO];
        [rightField setBordered:NO];
        [rightField setDrawsBackground:NO];
        [rightField setEditable:NO];
        [rightField setSelectable:NO];
        [rightField setControlSize:NSSmallControlSize];
        [rightField setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self addSubview:rightField];
        
        [NSLayoutConstraint activateConstraints:[NSArray arrayWithObjects:
             [NSLayoutConstraint constraintWithItem:leftField attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeading multiplier:1.0 constant:LEFT_MARGIN],
             [NSLayoutConstraint constraintWithItem:leftField attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0],
             [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:rightField attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:RIGHT_MARGIN],
            [NSLayoutConstraint constraintWithItem:rightField attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0], nil]];
        
        iconView = nil;
		progressIndicator = nil;
        animating = NO;
    }
    return self;
}

- (void)dealloc {
    SKDESTROY(leftField);
    SKDESTROY(rightField);
    SKDESTROY(iconView);
    SKDESTROY(progressIndicator);
	[super dealloc];
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super initWithCoder:decoder];
    if (self) {
        leftField = [[decoder decodeObjectForKey:@"leftField"] retain];
        rightField = [[decoder decodeObjectForKey:@"rightField"] retain];
        iconView = [[decoder decodeObjectForKey:@"iconView"] retain];
        progressIndicator = [[decoder decodeObjectForKey:@"progressIndicator"] retain];
        animating = NO;
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:leftField forKey:@"leftField"];
    [coder encodeObject:rightField forKey:@"rightField"];
    [coder encodeObject:iconView forKey:@"iconView"];
    [coder encodeObject:progressIndicator forKey:@"progressIndicator"];
}

- (BOOL)isVisible {
	return [self superview] && [self isHidden] == NO;
}

- (void)toggleBelowView:(NSView *)view animate:(BOOL)animate {
    if (animating)
        return;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableAnimationsKey])
        animate = NO;
    
    NSView *contentView = [view superview];
    BOOL visible = (nil == [self superview]);
    NSView *bottomView = visible ? view : self;
    NSLayoutConstraint *bottomConstraint = [contentView constraintWithSecondItem:bottomView secondAttribute:NSLayoutAttributeBottom];
    CGFloat statusHeight = NSHeight([self frame]);
    NSArray *constraints;
    
    if (visible) {
        [[view window] setContentBorderThickness:statusHeight forEdge:NSMinYEdge];
        [contentView addSubview:self];
        constraints = [NSArray arrayWithObjects:
            [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:animate ? -statusHeight : 0.0],
            [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0], nil];
        [bottomConstraint setActive:NO];
        [NSLayoutConstraint activateConstraints:constraints];
        [contentView layoutSubtreeIfNeeded];
        bottomConstraint = [constraints objectAtIndex:2];
    } else {
        constraints = [NSArray arrayWithObjects:[NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0], nil];
    }
    
    if (animate) {
        animating = YES;
        CGFloat target = visible ? 0.0 : -statusHeight;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [context setDuration:0.5 * [context duration]];
                [[bottomConstraint animator] setConstant:target];
            }
            completionHandler:^{
                if (visible == NO) {
                    [[self window] setContentBorderThickness:0.0 forEdge:NSMinYEdge];
                    [self removeFromSuperview];
                    [NSLayoutConstraint activateConstraints:constraints];
                } else {
                    // this fixes an AppKit bug, the window does not notice that its draggable areas change
                    [[self window] setMovableByWindowBackground:YES];
                    [[self window] setMovableByWindowBackground:NO];
                }
                animating = NO;
            }];
    } else if (visible == NO) {
        [[self window] setContentBorderThickness:0.0 forEdge:NSMinYEdge];
        [self removeFromSuperview];
        [NSLayoutConstraint activateConstraints:constraints];
        [contentView layoutSubtreeIfNeeded];
    }
}

#pragma mark Text cell accessors

- (NSString *)leftStringValue {
	return [leftField stringValue];
}

- (void)setLeftStringValue:(NSString *)aString {
	[leftField setStringValue:aString];
}

- (NSString *)rightStringValue {
	return [rightField stringValue];
}

- (void)setRightStringValue:(NSString *)aString {
	[rightField setStringValue:aString];
}

- (SEL)leftAction {
    return [leftField action];
}

- (void)setLeftAction:(SEL)selector {
    [leftField setAction:selector];
}

- (id)leftTarget {
    return [leftField target];
}

- (void)setLeftTarget:(id)newTarget {
    [leftField setTarget:newTarget];
}

- (SEL)rightAction {
    return [rightField action];
}

- (void)setRightAction:(SEL)selector {
    [rightField setAction:selector];
}

- (id)rightTarget {
    return [rightField target];
}

- (void)setRightTarget:(id)newTarget {
    [rightField setTarget:newTarget];
}

- (SEL)action {
    return [self rightAction];
}

- (void)setAction:(SEL)selector {
    [self setRightAction:selector];
}

- (id)target {
    return [self rightTarget];
}

- (void)setTarget:(id)newTarget {
    [self setRightTarget:newTarget];
}

- (NSInteger)leftState {
    return [[leftField cell] state];
}

- (void)setLeftState:(NSInteger)newState {
    [[leftField cell] setState:newState];
}

- (NSInteger)rightState {
    return [[rightField cell] state];
}

- (void)setRightState:(NSInteger)newState {
    [[rightField cell] setState:newState];
}

- (NSImage *)icon {
    return [iconView image];
}

- (void)setIcon:(NSImage *)icon {
    if (icon) {
        if (iconView == nil) {
            iconView = [[NSImageView alloc] init];
            [iconView setTranslatesAutoresizingMaskIntoConstraints:NO];
            [self addSubview:iconView];
            [[self constraintWithFirstItem:leftField firstAttribute:NSLayoutAttributeLeading] setActive:NO];
            [NSLayoutConstraint activateConstraints:[NSArray arrayWithObjects:
                 [NSLayoutConstraint constraintWithItem:iconView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeading multiplier:1.0 constant:LEFT_MARGIN],
                 [NSLayoutConstraint constraintWithItem:leftField attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:iconView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:SEPARATION],
                 [NSLayoutConstraint constraintWithItem:iconView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0 constant:1.0],
                 [NSLayoutConstraint constraintWithItem:iconView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:iconView attribute:NSLayoutAttributeHeight multiplier:1.0 constant:0.0], nil]];
        }
        [iconView setImage:icon];
    } else if (iconView) {
        [iconView removeFromSuperview];
        SKDESTROY(iconView);
        [[NSLayoutConstraint constraintWithItem:leftField attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeading multiplier:1.0 constant:LEFT_MARGIN] setActive:YES];
    }
}

#pragma mark Progress indicator

- (SKProgressIndicatorStyle)progressIndicatorStyle {
	if (progressIndicator == nil)
		return SKProgressIndicatorStyleNone;
	else
        return [progressIndicator isIndeterminate] ? SKProgressIndicatorStyleIndeterminate : SKProgressIndicatorStyleDeterminate;
}

- (void)setProgressIndicatorStyle:(SKProgressIndicatorStyle)style {
	if (style == SKProgressIndicatorStyleNone) {
		if (progressIndicator == nil)
			return;
		[progressIndicator removeFromSuperview];
		SKDESTROY(progressIndicator);
        [[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:rightField attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:RIGHT_MARGIN] setActive:YES];
	} else {
		if (progressIndicator && (NSInteger)[progressIndicator style] == style)
			return;
		if (progressIndicator == nil) {
            progressIndicator = [[NSProgressIndicator alloc] init];
            [progressIndicator setControlSize:NSSmallControlSize];
            [progressIndicator setDisplayedWhenStopped:YES];
            [progressIndicator setUsesThreadedAnimation:YES];
            [progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
            [progressIndicator setTranslatesAutoresizingMaskIntoConstraints:NO];
            [self addSubview:progressIndicator];
            [[self constraintWithSecondItem:rightField secondAttribute:NSLayoutAttributeTrailing] setActive:NO];
            [NSLayoutConstraint activateConstraints:[NSArray arrayWithObjects:
                 [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:progressIndicator attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:RIGHT_MARGIN],
                 [NSLayoutConstraint constraintWithItem:progressIndicator attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:rightField attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:SEPARATION],
                 [NSLayoutConstraint constraintWithItem:progressIndicator attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0], nil]];
		}
		[progressIndicator setIndeterminate:style == SKProgressIndicatorStyleIndeterminate];
	}
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSString *)accessibilityRole {
    return NSAccessibilityGroupRole;
}

- (NSString *)accessibilityRoleDescription {
    return NSAccessibilityRoleDescription(NSAccessibilityGroupRole, nil);
}

- (NSRect)accessibilityFrame {
    return [self convertRectToScreen:[self bounds]];
}

- (id)accessibilityParent {
    return NSAccessibilityUnignoredAncestor([self superview]);
}

@end

#pragma mark -

@implementation SKStatusTextField

+ (Class)cellClass { return [SKStatusTextFieldCell class]; }

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect owner:self userInfo:nil];
        [self addTrackingArea:area];
        [area release];
    }
    return self;
}

- (void)mouseEntered:(NSEvent *)theEvent {
    if ([[SKStatusTextField superclass] instancesRespondToSelector:_cmd])
        [super mouseEntered:theEvent];
    if ([self action] != NULL) {
        [(SKStatusTextFieldCell *)[self cell] setUnderlined:YES];
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    if ([[SKStatusTextField superclass] instancesRespondToSelector:_cmd])
        [super mouseExited:theEvent];
    if ([self action] != NULL) {
        [(SKStatusTextFieldCell *)[self cell] setUnderlined:NO];
        [self setNeedsDisplay:YES];
    }
}

- (void)setAction:(SEL)action {
    [super setAction:action];
    if ([self action] != NULL) {
        [(SKStatusTextFieldCell *)[self cell] setUnderlined:NO];
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    NSPoint mouseLoc = [theEvent locationInView:self];
    NSRect bounds = [self bounds];
    if ([self action]) {
        while ([theEvent type] != NSLeftMouseUp)
            theEvent = [[self window] nextEventMatchingMask: NSLeftMouseDraggedMask | NSLeftMouseUpMask];
        mouseLoc = [theEvent locationInView:self];
        if (NSMouseInRect(mouseLoc, bounds, [self isFlipped])) {
            [[self cell] setNextState];
            [self sendAction:[self action] to:[self target]];
        }
    } else {
        [super mouseDown:theEvent];
    }
}

@end

@implementation SKStatusTextFieldCell

@synthesize underlined;

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    if ([self isUnderlined]) {
        id objectValue = [[self objectValue] retain];
        NSMutableAttributedString *mutAttrString = [[self attributedStringValue] mutableCopy];
        [mutAttrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:NSMakeRange(0, [mutAttrString length])];
        [self setObjectValue:mutAttrString];
        [mutAttrString release];
        [super drawInteriorWithFrame:cellFrame inView:controlView];
        [self setObjectValue:objectValue];
        [objectValue release];
    } else {
        [super drawInteriorWithFrame:cellFrame inView:controlView];
    }
}

@end
