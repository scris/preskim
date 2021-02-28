//
//  SKColorSwatch.m
//  Skim
//
//  Created by Christiaan Hofman on 7/4/07.
/*
 This software is Copyright (c) 2007-2021
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

#import "SKColorSwatch.h"
#import "NSColor_SKExtensions.h"
#import "NSEvent_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSShadow_SKExtensions.h"
#import "SKRuntime.h"

NSString *SKColorSwatchColorsChangedNotification = @"SKColorSwatchColorsChangedNotification";
NSString *SKColorSwatchOrWellWillActivateNotification = @"SKColorSwatchOrWellWillActivateNotification";

#define COLORS_KEY      @"colors"

#define ACTION_KEY      @"action"
#define TARGET_KEY      @"target"
#define AUTORESIZES_KEY @"autoResizes"
#define SELECTS_KEY     @"selects"

#define COLOR_KEY       @"color"

#define DROPLOCATION_KEY @"dropLocation"

#define BEZEL_HEIGHT 22.0
#define BEZEL_INSET_LR 1.0
#define BEZEL_INSET_T 1.0
#define BEZEL_INSET_B 2.0
#define COLOR_INSET 2.0
#define COLOR_OFFSET 3.0

#define BACKGROUND_WIDTH_OFFSET 6.0

@interface SKColorSwatchBackgroundView : NSControl
@property (nonatomic) CGFloat width;
@end
 
typedef NS_ENUM(NSUInteger, SKColorSwatchDropLocation) {
    SKColorSwatchNoDrop,
    SKColorSwatchDropOn,
    SKColorSwatchDropBefore,
    SKColorSwatchDropAfter
};

@interface SKColorSwatchItemView : NSView {
    NSColor *color;
    BOOL highlighted;
    BOOL selected;
    SKColorSwatchDropLocation dropLocation;
}
@property (nonatomic, retain) NSColor *color;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic) SKColorSwatchDropLocation dropLocation;

@end

#pragma mark -

@interface SKColorSwatch (SKAccessibilityColorSwatchElementParent)
- (BOOL)isItemViewFocused:(SKColorSwatchItemView *)itemView;
- (void)itemView:(SKColorSwatchItemView *)itemView setFocused:(BOOL)focused;
- (void)pressItemView:(SKColorSwatchItemView *)itemView;
@end

@interface SKColorSwatch ()
@property (nonatomic) NSInteger selectedColorIndex;
@property (nonatomic, readonly) CGFloat fitWidth;
- (void)setColor:(NSColor *)color atIndex:(NSInteger)i fromPanel:(BOOL)fromPanel;
@end

@implementation SKColorSwatch

@synthesize colors, autoResizes, selects, clickedColorIndex=clickedIndex, selectedColorIndex=selectedIndex;
@dynamic color, fitWidth;

+ (void)initialize {
    SKINITIALIZE;
    
    [self exposeBinding:COLORS_KEY];
}

- (Class)valueClassForBinding:(NSString *)binding {
    if ([binding isEqualToString:COLORS_KEY])
        return [NSArray class];
    else
        return [super valueClassForBinding:binding];
}

- (void)commonInit {
    focusedIndex = 0;
    clickedIndex = -1;
    selectedIndex = -1;
    draggedIndex = -1;
    
    [self registerForDraggedTypes:[NSColor readableTypesForPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]]];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        colors = [[NSMutableArray alloc] initWithObjects:[NSColor whiteColor], nil];
        action = NULL;
        target = nil;
        autoResizes = YES;
        selects = NO;
        
        SKColorSwatchBackgroundView *view = [[SKColorSwatchBackgroundView alloc] initWithFrame:[self bounds]];
        [view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [view setWidth:[self fitWidth]];
        [self addSubview:view];
        backgroundView = [view retain];
        [view release];
        
        SKColorSwatchItemView *itemView = [[SKColorSwatchItemView alloc] initWithFrame:[self frameForItemViewAtIndex:0 collapsedIndex:-1]];
        [itemView setColor:[NSColor whiteColor]];
        [self addSubview:view];
        itemViews = [[NSMutableArray alloc] initWithObjects:itemView, nil];
        [itemView release];
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        colors = [[NSMutableArray alloc] initWithArray:[decoder decodeObjectForKey:COLORS_KEY]];
        action = NSSelectorFromString([decoder decodeObjectForKey:ACTION_KEY]);
        target = [decoder decodeObjectForKey:TARGET_KEY];
        autoResizes = [decoder decodeBoolForKey:AUTORESIZES_KEY];
        selects = [decoder decodeBoolForKey:SELECTS_KEY];
        
        itemViews = [[NSMutableArray alloc] init];
        
        for (NSView *view in [self subviews]) {
            if ([view isKindOfClass:[SKColorSwatchBackgroundView class]])
                backgroundView = [view retain];
            else if ([view isKindOfClass:[SKColorSwatchItemView class]])
                [itemViews addObject:view];
        }
        
        [self commonInit];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:colors forKey:COLORS_KEY];
    [coder encodeObject:NSStringFromSelector(action) forKey:ACTION_KEY];
    [coder encodeConditionalObject:target forKey:TARGET_KEY];
    [coder encodeBool:autoResizes forKey:AUTORESIZES_KEY];
    [coder encodeBool:selects forKey:SELECTS_KEY];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if ([self infoForBinding:COLORS_KEY])
        SKENSURE_MAIN_THREAD( [self unbind:COLORS_KEY]; );
    SKDESTROY(colors);
    SKDESTROY(itemViews);
    SKDESTROY(backgroundView);
    [super dealloc];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent { return YES; }

- (BOOL)acceptsFirstResponder { return YES; }

#pragma mark Layout

- (NSSize)contentSizeForNumberOfColors:(NSUInteger)count {
    return NSMakeSize(count * (BEZEL_HEIGHT - COLOR_OFFSET) + COLOR_OFFSET, BEZEL_HEIGHT);
}

- (CGFloat)distanceBetweenColors {
    return BEZEL_HEIGHT - COLOR_OFFSET;
}

- (NSRect)frameForColorAtIndex:(NSInteger)anIndex {
    NSEdgeInsets insets = [self alignmentRectInsets];
    NSRect rect = NSMakeRect(insets.left, insets.bottom, BEZEL_HEIGHT, BEZEL_HEIGHT);
    rect = NSInsetRect(rect, COLOR_INSET, COLOR_INSET);
    if (anIndex > 0)
        rect.origin.x += anIndex * [self distanceBetweenColors];
    return rect;
}

- (NSRect)frameForItemViewAtIndex:(NSInteger)anIndex collapsedIndex:(NSInteger)collapsedIndex {
    NSInteger i = anIndex;
    if (collapsedIndex != -1 && anIndex > collapsedIndex)
        i--;
    NSRect rect = NSInsetRect([self frameForColorAtIndex:i], -1.0, -1.0);
    if (collapsedIndex == anIndex)
        rect.size.width = 1.0;
    return rect;
}

- (NSInteger)colorIndexAtPoint:(NSPoint)point {
    NSRect rect = [self frameForColorAtIndex:0];
    CGFloat distance = [self distanceBetweenColors];
    NSInteger i, count = [colors count];
    
    for (i = 0; i < count; i++) {
        if (NSMouseInRect(point, rect, [self isFlipped]))
            return i;
        rect.origin.x += distance;
    }
    return -1;
}

- (NSInteger)insertionIndexAtPoint:(NSPoint)point {
    NSRect rect = [self frameForColorAtIndex:0];
    CGFloat w = [self distanceBetweenColors];
    CGFloat x = NSMidX(rect);
    NSInteger i, count = [colors count];
    
    for (i = 0; i < count; i++) {
        if (point.x < x)
            return i;
        x += w;
    }
    return count;
}

- (NSSize)sizeForNumberOfColors:(NSUInteger)count {
    NSSize size = [self contentSizeForNumberOfColors:count];
    NSEdgeInsets insets = [self alignmentRectInsets];
    size.height += insets.bottom + insets.top;
    size.width += insets.left + insets.right;
    return size;
}

- (CGFloat)fitWidth {
    return [self sizeForNumberOfColors:[colors count]].width;
}

- (NSSize)intrinsicContentSize {
    return [self contentSizeForNumberOfColors:[colors count]];
}

- (void)sizeToFit {
    [self setFrameSize:[self sizeForNumberOfColors:[colors count]]];
}

- (NSEdgeInsets)alignmentRectInsets {
    return NSEdgeInsetsMake(BEZEL_INSET_T, BEZEL_INSET_LR, BEZEL_INSET_B, BEZEL_INSET_LR);
}

- (void)updateSubviewLayout {
    NSUInteger i, iMax = [itemViews count];
    for (i = 0; i < iMax; i++)
        [[itemViews objectAtIndex:i] setFrame:[self frameForItemViewAtIndex:i collapsedIndex:-1]];
    [(SKColorSwatchBackgroundView *)backgroundView setWidth:[self fitWidth]];
}

#pragma mark Drawing

- (void)drawSwatchAtIndex:(NSInteger)i inRect:(NSRect)rect borderColor:(NSColor *)borderColor disabled:(BOOL)disabled {return;
    if (NSWidth(rect) < 1.0)
        return;
    if (NSWidth(rect) > 2.0) {
        NSColor *color = [[self colors] objectAtIndex:i];
        if (disabled) {
            color = [color colorUsingColorSpaceName:NSCalibratedWhiteColorSpace];
            CGContextSetAlpha([[NSGraphicsContext currentContext] graphicsPort], 0.5);
        }
        [color drawSwatchInRect:NSInsetRect(rect, 1.0, 1.0)];
        if (disabled)
            CGContextSetAlpha([[NSGraphicsContext currentContext] graphicsPort], 1.0);
    }
    [borderColor setStroke];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 0.5, 0.5) xRadius:1.5 yRadius:1.5] stroke];
}

- (NSRect)focusRingMaskBounds {
    if (focusedIndex == -1)
        return NSZeroRect;
    return [self frameForColorAtIndex:focusedIndex];
}

- (void)drawFocusRingMask {
    NSRect rect = [self focusRingMaskBounds];
    if (NSIsEmptyRect(rect) == NO)
        [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:2.0 yRadius:2.0] fill];
}

#pragma mark Notification handling

- (void)deactivate:(NSNotification *)note {
    [self deactivate];
}

- (void)handleColorPanelColorChanged:(NSNotification *)note {
    if (selectedIndex != -1) {
        NSColor *color = [[NSColorPanel sharedColorPanel] color];
        [self setColor:color atIndex:selectedIndex fromPanel:YES];
    }
}

- (void)handleKeyOrMainStateChanged:(NSNotification *)note {
    if ([[note name] isEqualToString:NSWindowDidResignMainNotification])
        [self deactivate];
    [[self subviews] setValue:[NSNumber numberWithInt:YES] forKey:@"needsDisplay"];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSWindow *oldWindow = [self window];
    NSArray *names = [NSArray arrayWithObjects:NSWindowDidBecomeMainNotification, NSWindowDidResignMainNotification, NSWindowDidBecomeKeyNotification, NSWindowDidResignKeyNotification, nil];
    if (oldWindow) {
        for (NSString *name in names)
            [[NSNotificationCenter defaultCenter] removeObserver:self name:name object:oldWindow];
    }
    if (newWindow) {
        for (NSString *name in names)
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleKeyOrMainStateChanged:) name:name object:newWindow];
    }
    [self deactivate];
    [super viewWillMoveToWindow:newWindow];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if ([self window])
        [self handleKeyOrMainStateChanged:nil];
}

#pragma mark Event handling and actions

- (void)mouseDown:(NSEvent *)theEvent {
    NSPoint mouseLoc = [theEvent locationInView:self];
    NSInteger i = [self colorIndexAtPoint:mouseLoc];
    
    if (i != -1) {
        if ([self isEnabled])
            [[itemViews objectAtIndex:i] setHighlighted:YES];
        
        BOOL keepOn = YES;
        while (keepOn) {
            theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
            switch ([theEvent type]) {
                case NSLeftMouseDragged:
                {
                    if ([self isEnabled])
                        [[itemViews objectAtIndex:i] setHighlighted:NO];
                    
                    draggedIndex = i;
                    
                    NSColor *color = [colors objectAtIndex:i];
                    
                    NSImage *image = [NSImage bitmapImageWithSize:NSMakeSize(12.0, 12.0) scale:[self backingScale] drawingHandler:^(NSRect rect){
                        [color drawSwatchInRect:NSInsetRect(rect, 1.0, 1.0)];
                        [[NSColor blackColor] set];
                        [NSBezierPath setDefaultLineWidth:1.0];
                        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 0.5, 0.5) xRadius:1.5 yRadius:1.5] stroke];
                    }];
                    
                    NSRect rect = SKRectFromCenterAndSquareSize([theEvent locationInView:self], 12.0);
                    
                    NSDraggingItem *dragItem = [[[NSDraggingItem alloc] initWithPasteboardWriter:color] autorelease];
                    [dragItem setDraggingFrame:rect contents:image];
                    [self beginDraggingSessionWithItems:[NSArray arrayWithObjects:dragItem, nil] event:theEvent source:self];
                    
                    keepOn = NO;
                    break;
                }
                case NSLeftMouseUp:
                    if ([self isEnabled]) {
                        if ([self selects]) {
                            if (selectedIndex != -1 && selectedIndex == i)
                                [self deactivate];
                            else
                                [self selectColorAtIndex:i];
                        }
                        clickedIndex = i;
                        [self sendAction:[self action] to:[self target]];
                        [[itemViews objectAtIndex:i] setHighlighted:NO];
                        clickedIndex = -1;
                    }
                    keepOn = NO;
                    break;
                default:
                    break;
            }
        }
    }
}

- (void)performClickAtIndex:(NSInteger)i {
    if ([self isEnabled] && i != -1) {
        clickedIndex = i;
        [[itemViews objectAtIndex:i] setHighlighted:YES];
        if ([self selects]) {
            if (selectedIndex != -1 && selectedIndex == i)
                [self deactivate];
            else
                [self selectColorAtIndex:i];
        }
        [self sendAction:[self action] to:[self target]];
        DISPATCH_MAIN_AFTER_SEC(0.2, ^{
            [[itemViews objectAtIndex:i] setHighlighted:NO];
            clickedIndex = -1;
        });
    }
}

- (void)performClick:(id)sender {
    [self performClickAtIndex:focusedIndex];
}

- (void)moveRight:(id)sender {
    if (++focusedIndex >= (NSInteger)[colors count])
        focusedIndex = 0;
    [self noteFocusRingMaskChanged];
    [self setNeedsDisplay:YES];
    NSAccessibilityPostNotification(self, NSAccessibilityFocusedUIElementChangedNotification);
}

- (void)moveLeft:(id)sender {
    if (--focusedIndex < 0)
        focusedIndex = [colors count] - 1;
    [self noteFocusRingMaskChanged];
    [self setNeedsDisplay:YES];
    NSAccessibilityPostNotification(self, NSAccessibilityFocusedUIElementChangedNotification);
}

#pragma mark Accessors

- (SEL)action { return action; }

- (void)setAction:(SEL)newAction { action = newAction; }

- (id)target { return target; }

- (void)setTarget:(id)newTarget { target = newTarget; }

- (NSArray *)colors {
    return [[colors copy] autorelease];
}

- (void)setColors:(NSArray *)newColors {
    NSArray *oldColors = [self colors];
    NSUInteger i, iMax = [newColors count];
    [self deactivate];
    [colors setArray:newColors];
    if (autoResizes && [newColors count] != [oldColors count])
        [self sizeToFit];
    if ([self window]) {
        i = [oldColors count];
        while (i-- > 0)
            NSAccessibilityPostNotification([itemViews objectAtIndex:i], NSAccessibilityUIElementDestroyedNotification);
    }
    [itemViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [itemViews removeAllObjects];
    for (i = 0; i < iMax; i++) {
        SKColorSwatchItemView *itemView = [[SKColorSwatchItemView alloc] init];
        [itemView setColor:[newColors objectAtIndex:i]];
        [self addSubview:itemView];
        [itemViews addObject:itemView];
        [itemView release];
    }
    [self updateSubviewLayout];
    if ([self window]) {
        for (i = 0; i < iMax; i++)
            NSAccessibilityPostNotification([itemViews objectAtIndex:i], NSAccessibilityCreatedNotification);
        [self invalidateIntrinsicContentSize];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SKColorSwatchColorsChangedNotification object:self];
}

- (NSColor *)color {
    return clickedIndex == -1 ? nil : [colors objectAtIndex:clickedIndex];
}

- (void)setEnabled:(BOOL)enabled {
    if (enabled == NO)
        [self deactivate];
    [super setEnabled:enabled];
}

#pragma mark Modification

- (void)selectColorAtIndex:(NSInteger)idx {
    if (idx == -1) {
        [self deactivate];
    } else if ([self selects] && idx != selectedIndex && [self isEnabled] && [[self window] isMainWindow]) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
        if (selectedIndex != -1) {
            [nc removeObserver:self name:NSColorPanelColorDidChangeNotification object:colorPanel];
        } else {
            [nc postNotificationName:SKColorSwatchOrWellWillActivateNotification object:self];
            [nc addObserver:self selector:@selector(deactivate:) name:SKColorSwatchOrWellWillActivateNotification object:nil];
            [nc addObserver:self selector:@selector(deactivate:) name:NSWindowWillCloseNotification object:[NSColorPanel sharedColorPanel]];
        }
        [[[NSApp mainWindow] contentView] deactivateColorWellSubcontrols];
        [[[NSApp keyWindow] contentView] deactivateColorWellSubcontrols];
        if (selectedIndex != -1)
            [[itemViews objectAtIndex:selectedIndex] setSelected:NO];
        [self setSelectedColorIndex:idx];
        [[itemViews objectAtIndex:selectedIndex] setSelected:YES];
        [colorPanel setColor:[[self colors] objectAtIndex:selectedIndex]];
        [colorPanel orderFront:nil];
        [nc addObserver:self selector:@selector(handleColorPanelColorChanged:) name:NSColorPanelColorDidChangeNotification object:colorPanel];
    }
}

- (void)deactivate {
    if (selectedIndex != -1) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:NSColorPanelColorDidChangeNotification object:[NSColorPanel sharedColorPanel]];
        [nc removeObserver:self name:SKColorSwatchOrWellWillActivateNotification object:nil];
        if (selectedIndex != -1)
            [[itemViews objectAtIndex:selectedIndex] setSelected:NO];
        [self setSelectedColorIndex:-1];
    }
}

- (void)setSelects:(BOOL)flag {
    if (flag != selects) {
        if (flag == NO)
            [self deactivate];
        selects = flag;
    }
}

- (void)willChangeColors {
    [self willChangeValueForKey:COLORS_KEY];
}

- (void)didChangeColors {
    [self didChangeValueForKey:COLORS_KEY];
    
    NSDictionary *info = [self infoForBinding:COLORS_KEY];
    id observedObject = [info objectForKey:NSObservedObjectKey];
    NSString *observedKeyPath = [info objectForKey:NSObservedKeyPathKey];
    if (observedObject && observedKeyPath) {
        id value = [[colors copy] autorelease];
        NSValueTransformer *valueTransformer = [[info objectForKey:NSOptionsKey] objectForKey:NSValueTransformerBindingOption];
        if (valueTransformer == nil || [valueTransformer isEqual:[NSNull null]]) {
            NSString *transformerName = [[info objectForKey:NSOptionsKey] objectForKey:NSValueTransformerNameBindingOption];
            if (transformerName && [transformerName isEqual:[NSNull null]] == NO)
                valueTransformer = [NSValueTransformer valueTransformerForName:transformerName];
        }
        if (valueTransformer && [valueTransformer isEqual:[NSNull null]] == NO &&
            [[valueTransformer class] allowsReverseTransformation])
            value = [valueTransformer reverseTransformedValue:value];
        [observedObject setValue:value forKeyPath:observedKeyPath];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SKColorSwatchColorsChangedNotification object:self];
}

- (void)setColor:(NSColor *)color atIndex:(NSInteger)i fromPanel:(BOOL)fromPanel {
    if (color && i >= 0 && i < (NSInteger)[colors count]) {
        [self willChangeColors];
        [colors replaceObjectAtIndex:i withObject:color];
        [[itemViews objectAtIndex:i] setColor:color];
        NSAccessibilityPostNotification([itemViews objectAtIndex:i], NSAccessibilityValueChangedNotification);
        [self didChangeColors];
        if (fromPanel == NO && selectedIndex == i) {
            NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc removeObserver:self name:NSColorPanelColorDidChangeNotification object:colorPanel];
            [colorPanel setColor:color];
            [nc addObserver:self selector:@selector(handleColorPanelColorChanged:) name:NSColorPanelColorDidChangeNotification object:colorPanel];
        }
    }
}

- (void)setColor:(NSColor *)color atIndex:(NSInteger)i {
    [self setColor:color atIndex:i fromPanel:NO];
}

- (void)animateItemViewsCollapsing:(NSInteger)collapsedIndex frameSize:(NSSize)size {
    NSUInteger i = 0;
    for (SKColorSwatchItemView *itemView in itemViews)
        [[itemView animator] setFrame:[self frameForItemViewAtIndex:i++ collapsedIndex:collapsedIndex]];
    if (NSEqualSizes(size, NSZeroSize) == NO) {
        [[(SKColorSwatchBackgroundView *)backgroundView animator] setWidth:size.width];
        [[self animator] setFrameSize:size];
    }
}

- (void)insertColor:(NSColor *)color atIndex:(NSInteger)i {
    if (color && i >= 0 && i <= (NSInteger)[colors count]) {
        [self deactivate];
        [self willChangeColors];
        [colors insertObject:color atIndex:i];
        NSAccessibilityPostNotification([itemViews objectAtIndex:i], NSAccessibilityCreatedNotification);
        [self invalidateIntrinsicContentSize];
        SKColorSwatchItemView *itemView = [[SKColorSwatchItemView alloc] initWithFrame:[self frameForItemViewAtIndex:i collapsedIndex:i]];
        [itemView setColor:color];
        if (i < (NSInteger)[itemViews count])
            [self addSubview:itemView positioned:NSWindowBelow relativeTo:[itemViews objectAtIndex:i]];
        else
            [self addSubview:itemView positioned:NSWindowAbove relativeTo:nil];
        [itemViews insertObject:itemView atIndex:i];
        [itemView release];
        if (autoResizes) {
            NSSize size = [self sizeForNumberOfColors:[colors count]];
            [self noteFocusRingMaskChanged];
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                    [self animateItemViewsCollapsing:-1 frameSize:size];
                }
                completionHandler:^{
                    [self sizeToFit];
                    [self noteFocusRingMaskChanged];
                }];
        } else {
            [self updateSubviewLayout];
        }
        [self didChangeColors];
    }
}

- (void)removeColorAtIndex:(NSInteger)i {
    if (i >= 0 && i < (NSInteger)[colors count]) {
        [self deactivate];
        if (autoResizes) {
            NSSize size = [self sizeForNumberOfColors:[colors count] - 1];
            [self noteFocusRingMaskChanged];
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                    [self animateItemViewsCollapsing:i frameSize:size];
                }
                completionHandler:^{
                    [self willChangeColors];
                    [colors removeObjectAtIndex:i];
                    [[itemViews objectAtIndex:i] removeFromSuperview];
                    [itemViews removeObjectAtIndex:i];
                    [self didChangeColors];
                    [self sizeToFit];
                    [self invalidateIntrinsicContentSize];
                    [self noteFocusRingMaskChanged];
                    NSAccessibilityPostNotification([itemViews objectAtIndex:i], NSAccessibilityUIElementDestroyedNotification);
                }];
        } else {
            [self willChangeColors];
            [colors removeObjectAtIndex:i];
            [[itemViews objectAtIndex:i] removeFromSuperview];
            [itemViews removeObjectAtIndex:i];
            [self didChangeColors];
            [self invalidateIntrinsicContentSize];
            [self updateSubviewLayout];
            NSAccessibilityPostNotification([itemViews objectAtIndex:draggedIndex], NSAccessibilityUIElementDestroyedNotification);
        }
    }
}

- (void)moveColorAtIndex:(NSInteger)from toIndex:(NSInteger)to {
    if (from >= 0 && to >= 0 && from != to) {
        NSColor *color = [[colors objectAtIndex:from] retain];
        [self deactivate];
        [self willChangeColors];
        [colors removeObjectAtIndex:from];
        [colors insertObject:color atIndex:to];
        SKColorSwatchItemView *itemView = [[itemViews objectAtIndex:from] retain];
        [itemViews removeObjectAtIndex:from];
        [itemViews insertObject:itemView atIndex:to];
        if (to > from)
            [self addSubview:itemView positioned:NSWindowAbove relativeTo:[itemViews objectAtIndex:to - 1]];
        [itemView release];
        [color release];
        NSAccessibilityPostNotification([itemViews objectAtIndex:to], NSAccessibilityMovedNotification);
        [self noteFocusRingMaskChanged];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [self animateItemViewsCollapsing:-1 frameSize:NSZeroSize];
            }
            completionHandler:^{
                if (to < from)
                    [self addSubview:itemView positioned:NSWindowBelow relativeTo:[itemViews objectAtIndex:to + 1]];
                [self noteFocusRingMaskChanged];
            }];
        [self didChangeColors];
    }
}

#pragma mark NSDraggingSource protocol 

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    return context == NSDraggingContextWithinApplication ? NSDragOperationGeneric : NSDragOperationDelete;
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    if ((operation & NSDragOperationDelete) != 0 && operation != NSDragOperationEvery && draggedIndex != -1 && [self isEnabled])
        [self removeColorAtIndex:draggedIndex];
    draggedIndex = -1;
}

#pragma mark NSDraggingDestination protocol 

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    NSPoint mouseLoc = [self convertPoint:[sender draggingLocation] fromView:nil];
    BOOL isCopy = ([NSEvent standardModifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSAlternateKeyMask;
    BOOL isMove = [sender draggingSource] == self && isCopy == NO;
    NSInteger i = isCopy || isMove ? [self insertionIndexAtPoint:mouseLoc] : [self colorIndexAtPoint:mouseLoc];
    NSDragOperation dragOp = isCopy ? NSDragOperationCopy : NSDragOperationGeneric;
    if ([self isEnabled] == NO || i == -1 ||
        (isMove && (i == draggedIndex || i == draggedIndex + 1))) {
        [itemViews setValue:[NSNumber numberWithInteger:SKColorSwatchNoDrop] forKey:DROPLOCATION_KEY];
        dragOp = NSDragOperationNone;
    } else {
        [itemViews setValue:[NSNumber numberWithInteger:SKColorSwatchNoDrop] forKey:DROPLOCATION_KEY];
        if (isCopy || isMove) {
            if (i < (NSInteger)[itemViews count])
                [[itemViews objectAtIndex:i] setDropLocation:SKColorSwatchDropBefore];
            if (i > 0)
                [[itemViews objectAtIndex:i - 1] setDropLocation:SKColorSwatchDropAfter];
        } else {
            [[itemViews objectAtIndex:i] setDropLocation:SKColorSwatchDropOn];
        }
    }
    return dragOp;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    [itemViews setValue:[NSNumber numberWithInteger:SKColorSwatchNoDrop] forKey:DROPLOCATION_KEY];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSColor *color = [NSColor colorFromPasteboard:pboard];
    NSPoint mouseLoc = [self convertPoint:[sender draggingLocation] fromView:nil];
    BOOL isCopy = ([NSEvent standardModifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSAlternateKeyMask;
    BOOL isMove = [sender draggingSource] == self && isCopy == NO;
    NSInteger i = isCopy || isMove ? [self insertionIndexAtPoint:mouseLoc] : [self colorIndexAtPoint:mouseLoc];
    if ([self isEnabled] && i != -1 &&
        (isMove == NO || (i != draggedIndex && i != draggedIndex + 1))) {
        if (isMove)
            [self moveColorAtIndex:draggedIndex toIndex:i > draggedIndex ? i - 1 : i];
        else if (isCopy)
            [self insertColor:color atIndex:i];
        else
            [self setColor:color atIndex:i];
    }
    
    [itemViews setValue:[NSNumber numberWithInteger:SKColorSwatchNoDrop] forKey:DROPLOCATION_KEY];
    
	return YES;
}

#pragma mark Accessibility

- (NSString *)accessibilityRole {
    return NSAccessibilityGroupRole;
}

- (NSString *)accessibilityRoleDescription {
    return NSAccessibilityRoleDescriptionForUIElement(self);
}

- (NSArray *)accessibilityChildren {
    return NSAccessibilityUnignoredChildren(itemViews);
}

- (NSArray *)accessibilityContents {
    return [self accessibilityChildren];
}

- (id)accessibilityHitTest:(NSPoint)point {
    NSPoint localPoint = [self convertPointFromScreen:point];
    NSInteger i = [self colorIndexAtPoint:localPoint];
    if (i != -1) {
        return NSAccessibilityUnignoredAncestor([itemViews objectAtIndex:i]);
    } else {
        return [super accessibilityHitTest:point];
    }
}

- (id)accessibilityFocusedUIElement {
    if (focusedIndex != -1 && focusedIndex < (NSInteger)[colors count])
        return NSAccessibilityUnignoredAncestor([itemViews objectAtIndex:focusedIndex]);
    else
        return NSAccessibilityUnignoredAncestor(self);
}

- (BOOL)isItemViewFocused:(SKColorSwatchItemView *)itemView {
    return focusedIndex == (NSInteger)[itemViews indexOfObject:itemView];
}

- (void)itemView:(SKColorSwatchItemView *)itemView setFocused:(BOOL)focused {
    NSUInteger anIndex = [itemViews indexOfObject:itemView];
    if (focused && anIndex < [[self colors] count]) {
        [[self window] makeFirstResponder:self];
        focusedIndex = anIndex;
        [self noteFocusRingMaskChanged];
        [self setNeedsDisplay:YES];
    }
}

- (void)pressItemView:(SKColorSwatchItemView *)itemView {
    NSUInteger anIndex = [itemViews indexOfObject:itemView];
    if (anIndex < [[self colors] count])
        [self performClickAtIndex:anIndex];
}

@end

#pragma mark -

@implementation NSColorWell (SKExtensions)

static void (*original_activate)(id, SEL, BOOL) = NULL;

- (void)replacement_activate:(BOOL)exclusive {
    [[NSNotificationCenter defaultCenter] postNotificationName:SKColorSwatchOrWellWillActivateNotification object:self];
    original_activate(self, _cmd, exclusive);
}

+ (void)load {
    original_activate = (void (*)(id, SEL, BOOL))SKReplaceInstanceMethodImplementationFromSelector(self, @selector(activate:), @selector(replacement_activate:));
}

@end

#pragma mark -

@implementation SKColorSwatchBackgroundView

@dynamic width;

+ (id)defaultAnimationForKey:(NSString *)key {
    if ([key isEqualToString:@"width"])
        return [CABasicAnimation animation];
    else
        return [super defaultAnimationForKey:key];
}

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        NSSegmentedCell *cell = [[[NSSegmentedCell alloc] init] autorelease];
        [cell setSegmentCount:1];
        [cell setSegmentStyle:NSSegmentStyleTexturedSquare];
        [cell setWidth:fmax(0.0, NSWidth(frameRect) - BACKGROUND_WIDTH_OFFSET) forSegment:0];
        [self setCell:cell];
    }
    return self;
}

- (BOOL)canBecomeKeyView { return NO; }

- (CGFloat)width {
    return [[self cell] widthForSegment:0] + BACKGROUND_WIDTH_OFFSET;
}

- (void)setWidth:(CGFloat)width {
    [[self cell] setWidth:width - BACKGROUND_WIDTH_OFFSET forSegment:0];
}

- (void)mouseDown:(NSEvent *)event {
    [[self superview] mouseDown:event];
}

- (void)keyDown:(NSEvent *)event {
    [[self superview] keyDown:event];
}

@end

#pragma mark -

@implementation SKColorSwatchItemView

@synthesize color, highlighted, selected, dropLocation;

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        color = [[decoder decodeObjectForKey:COLOR_KEY] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:color forKey:COLOR_KEY];
}

- (void)dealloc {
    SKDESTROY(color);
    [super dealloc];
}

- (void)setColor:(NSColor *)newColor {
    if (color != newColor) {
        [color release];
        color = [newColor retain];
        [self setNeedsDisplay:YES];
    }
}

- (void)setHighlighted:(BOOL)flag {
    if (highlighted != flag) {
        highlighted = flag;
        [self setNeedsDisplay:YES];
    }
}

- (void)setSelected:(BOOL)flag {
    if (selected != flag) {
        selected = flag;
        [self setNeedsDisplay:YES];
    }
}

- (void)setDropLocation:(SKColorSwatchDropLocation)location {
    if (location != dropLocation) {
        dropLocation = location;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect rect = [self bounds];
    if (NSWidth(rect) < 3.0)
        return;
    rect = NSInsetRect(rect, 1.0, 1.0);
    BOOL disabled = RUNNING_AFTER(10_13) && [[self window] isMainWindow] == NO && [[self window] isKeyWindow] == NO && ([self isDescendantOf:[[self window] contentView]] == NO || [[self window] isKindOfClass:NSClassFromString(@"NSToolbarSnapshotWindow")]);
    if (NSWidth(rect) > 2.0) {
        NSColor *aColor = color;
        if (disabled) {
            aColor = [aColor colorUsingColorSpaceName:NSCalibratedWhiteColorSpace];
            CGContextSetAlpha([[NSGraphicsContext currentContext] graphicsPort], 0.5);
        }
        [aColor drawSwatchInRect:NSInsetRect(rect, 1.0, 1.0)];
        if (disabled)
            CGContextSetAlpha([[NSGraphicsContext currentContext] graphicsPort], 1.0);
    }
    CGFloat gray;
    if (SKHasDarkAppearance(self))
        gray = (highlighted || selected) ? 0.55 : 0.3;
    else
        gray = (highlighted || selected) ? 0.5 : 0.7;
    [[NSColor colorWithCalibratedWhite:gray alpha:1.0] setStroke];
    NSBezierPath *path;
    if (selected) {
        path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:2.0 yRadius:2.0];
        [path setLineWidth:2.0];
    } else {
        path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 0.5, 0.5) xRadius:1.5 yRadius:1.5];
    }
    [path stroke];
    if (dropLocation != SKColorSwatchNoDrop) {
        NSColor *dropColor = disabled ? [NSColor secondarySelectedControlColor] : [NSColor alternateSelectedControlColor];
        [dropColor setStroke];
        if (dropLocation == SKColorSwatchDropOn) {
            path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:2.0 yRadius:2.0];
        } else if (dropLocation == SKColorSwatchDropBefore) {
            path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(NSMinX(rect), NSMinY(rect) - 1.0)];
            [path lineToPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect) + 1.0)];
        } else {
            path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect) - 1.0)];
            [path lineToPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect) + 1.0)];
        }
        [path setLineWidth:2.0];
        [path stroke];
    }
}

- (BOOL)accessibilityElement {
    return YES;
}

- (NSString *)accessibilityRole {
    return NSAccessibilityColorWellRole;
}

- (NSString *)accessibilityRoleDescription {
    return NSAccessibilityRoleDescriptionForUIElement(self);
}

- (id)accessibilityValue {
    return [color accessibilityValue];
}

- (BOOL)isAccessibilityFocused {
    return [(SKColorSwatch *)[self superview] isItemViewFocused:self];
}

- (void)setAccessibilityFocused:(BOOL)flag {
    [(SKColorSwatch *)[self superview] itemView:self setFocused:flag];
}

- (BOOL)accessibilityPerformPress {
    [(SKColorSwatch *)[self superview] pressItemView:self];
    return YES;
}

- (BOOL)accessibilityPerformPick {
    [(SKColorSwatch *)[self superview] pressItemView:self];
    return YES;
}

- (id)accessibilityFocusedUIElement {
    return NSAccessibilityUnignoredAncestor(self);
}

@end

