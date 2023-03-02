//
//  SKColorSwatch.m
//  Skim
//
//  Created by Christiaan Hofman on 7/4/07.
/*
 This software is Copyright (c) 2007-2023
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

#define BEZEL_INSET_LEFTRIGHT   1.0
#define BEZEL_INSET_TOP         1.0
#define BEZEL_INSET_BOTTOM      2.0
#define COLOR_INSET             2.0

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

@interface SKColorSwatchItemView : NSView <NSAccessibilityElement> {
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
- (NSRect)frameForItemViewAtIndex:(NSInteger)anIndex collapsedIndex:(NSInteger)collapsedIndex;
- (void)setColor:(NSColor *)color atIndex:(NSInteger)i fromPanel:(BOOL)fromPanel;
@end

@implementation SKColorSwatch

@synthesize colors, autoResizes, selects, alternate, clickedColorIndex=clickedIndex, selectedColorIndex=selectedIndex;
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
    
    bezelHeight = 22.0;
    
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
        
        [self commonInit];
        
        SKColorSwatchBackgroundView *view = [[SKColorSwatchBackgroundView alloc] initWithFrame:[self bounds]];
        [view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [view setWidth:[self fitWidth]];
        [self addSubview:view];
        backgroundView = [view retain];
        [view release];
        
        SKColorSwatchItemView *itemView = [[SKColorSwatchItemView alloc] initWithFrame:[self frameForItemViewAtIndex:0 collapsedIndex:-1]];
        [itemView setColor:[NSColor whiteColor]];
        [self addSubview:itemView];
        itemViews = [[NSMutableArray alloc] initWithObjects:itemView, nil];
        [itemView release];
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
        
        [self commonInit];
        
        itemViews = [[NSMutableArray alloc] init];
        
        for (NSView *view in [self subviews]) {
            if ([view isKindOfClass:[SKColorSwatchBackgroundView class]])
                backgroundView = [(SKColorSwatchBackgroundView *)view retain];
            else if ([view isKindOfClass:[SKColorSwatchItemView class]])
                [itemViews addObject:view];
        }
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

- (CGFloat)distanceBetweenColors {
    return bezelHeight - COLOR_INSET;
}

- (NSSize)contentSizeForNumberOfColors:(NSUInteger)count {
    return NSMakeSize(COLOR_INSET + count * [self distanceBetweenColors], bezelHeight);
}

- (NSRect)frameForColorAtIndex:(NSInteger)anIndex {
    NSEdgeInsets insets = [self alignmentRectInsets];
    NSRect rect = NSMakeRect(insets.left, insets.bottom, bezelHeight, bezelHeight);
    rect = NSInsetRect(rect, COLOR_INSET, COLOR_INSET);
    if (anIndex > 0)
        rect.origin.x += anIndex * [self distanceBetweenColors];
    return rect;
}

- (NSRect)frameForItemViewAtIndex:(NSInteger)anIndex collapsedIndex:(NSInteger)collapsedIndex {
    NSInteger i = anIndex;
    if (collapsedIndex != -1 && anIndex > collapsedIndex)
        i--;
    NSRect rect = NSInsetRect([self frameForColorAtIndex:i], -2.0, -2.0);
    if (collapsedIndex == anIndex)
        rect.size.width -= [self distanceBetweenColors];
    return rect;
}

- (NSInteger)colorIndexAtPoint:(NSPoint)point {
    NSRect rect = [self frameForColorAtIndex:0];
    NSInteger i, count = [colors count];
    
    for (i = 0; i < count; i++) {
        if (NSMouseInRect(point, rect, [self isFlipped]))
            return i;
        rect.origin.x += [self distanceBetweenColors];
    }
    return -1;
}

- (NSInteger)insertionIndexAtPoint:(NSPoint)point {
    NSRect rect = [self frameForColorAtIndex:0];
    CGFloat x = NSMidX(rect);
    NSInteger i, count = [colors count];
    
    for (i = 0; i < count; i++) {
        if (point.x < x)
            return i;
        x += [self distanceBetweenColors];
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
    return NSEdgeInsetsMake(BEZEL_INSET_TOP, BEZEL_INSET_LEFTRIGHT, BEZEL_INSET_BOTTOM, BEZEL_INSET_LEFTRIGHT);
}

- (void)updateSubviewLayout {
    NSUInteger i, iMax = [itemViews count];
    for (i = 0; i < iMax; i++)
        [[itemViews objectAtIndex:i] setFrame:[self frameForItemViewAtIndex:i collapsedIndex:-1]];
    [backgroundView setWidth:[self fitWidth]];
}

#pragma mark Drawing

- (NSRect)focusRingMaskBounds {
    if (focusedIndex == -1)
        return NSZeroRect;
    return [self frameForColorAtIndex:focusedIndex];
}

- (void)drawFocusRingMask {
    NSRect rect = [self focusRingMaskBounds];
    if (NSIsEmptyRect(rect) == NO) {
        CGFloat r = RUNNING_AFTER(10_15) ? 3.0 : 2.0;
        [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:r yRadius:r] fill];
    }
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
    NSArray *names = @[NSWindowDidBecomeMainNotification, NSWindowDidResignMainNotification, NSWindowDidBecomeKeyNotification, NSWindowDidResignKeyNotification];
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
    if ([self window]) {
        CGFloat height = [[backgroundView cell] cellSize].height - BEZEL_INSET_TOP - BEZEL_INSET_BOTTOM;
        if (fabs(height - bezelHeight) > 0.0) {
            bezelHeight = height;
            [self updateSubviewLayout];
            if (autoResizes)
                [self sizeToFit];
        }
    }
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
            theEvent = [[self window] nextEventMatchingMask: NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged];
            switch ([theEvent type]) {
                case NSEventTypeLeftMouseDragged:
                {
                    if ([self isEnabled])
                        [[itemViews objectAtIndex:i] setHighlighted:NO];
                    
                    draggedIndex = i;
                    
                    NSColor *color = [colors objectAtIndex:i];
                    CGFloat r = RUNNING_AFTER(10_15) ? 2.5 : 1.5;
                    
                    NSImage *image = [NSImage bitmapImageWithSize:NSMakeSize(12.0, 12.0) scale:[self backingScale] drawingHandler:^(NSRect rect){
                        [color drawSwatchInRect:NSInsetRect(rect, 1.0, 1.0)];
                        [[NSColor blackColor] set];
                        [NSBezierPath setDefaultLineWidth:1.0];
                        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 0.5, 0.5) xRadius:r yRadius:r] stroke];
                    }];
                    
                    NSRect rect = SKRectFromCenterAndSquareSize([theEvent locationInView:self], 12.0);
                    
                    NSDraggingItem *dragItem = [[[NSDraggingItem alloc] initWithPasteboardWriter:color] autorelease];
                    [dragItem setDraggingFrame:rect contents:image];
                    [self beginDraggingSessionWithItems:@[dragItem] event:theEvent source:self];
                    
                    keepOn = NO;
                    break;
                }
                case NSEventTypeLeftMouseUp:
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
    NSAccessibilityPostNotification(self, NSAccessibilityFocusedUIElementChangedNotification);
}

- (void)moveLeft:(id)sender {
    if (--focusedIndex < 0)
        focusedIndex = (NSInteger)[colors count] - 1;
    [self noteFocusRingMaskChanged];
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
    for (i = 0; i < iMax; i++) {
        SKColorSwatchItemView *itemView;
        if (i < [itemViews count]) {
            itemView = [itemViews objectAtIndex:i];
        } else {
            itemView = [[[SKColorSwatchItemView alloc] init] autorelease];
            [self addSubview:itemView];
            [itemViews addObject:itemView];
        }
        [itemView setColor:[newColors objectAtIndex:i]];
    }
    while ([itemViews count] > iMax) {
        [[itemViews objectAtIndex:iMax] removeFromSuperview];
        [itemViews removeObjectAtIndex:iMax];
    }
    [self updateSubviewLayout];
    [self invalidateIntrinsicContentSize];
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
        [[backgroundView animator] setWidth:size.width];
        if (autoResizes)
            [[self animator] setFrameSize:size];
    }
}

- (void)insertColor:(NSColor *)color atIndex:(NSInteger)i {
    if (color && i >= 0 && i <= (NSInteger)[colors count]) {
        [self deactivate];
        [self willChangeColors];
        [colors insertObject:color atIndex:i];
        [self invalidateIntrinsicContentSize];
        SKColorSwatchItemView *itemView = [[SKColorSwatchItemView alloc] initWithFrame:[self frameForItemViewAtIndex:i collapsedIndex:i]];
        [itemView setColor:color];
        if (i < (NSInteger)[itemViews count])
            [self addSubview:itemView positioned:NSWindowBelow relativeTo:[itemViews objectAtIndex:i]];
        else
            [self addSubview:itemView positioned:NSWindowAbove relativeTo:nil];
        [itemViews insertObject:itemView atIndex:i];
        [itemView release];
        NSSize size = [self sizeForNumberOfColors:[colors count]];
        [self noteFocusRingMaskChanged];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [self animateItemViewsCollapsing:-1 frameSize:size];
            }
            completionHandler:^{
                if (autoResizes)
                    [self sizeToFit];
                [self noteFocusRingMaskChanged];
            }];
        [self didChangeColors];
    }
}

- (void)removeColorAtIndex:(NSInteger)i {
    if (i >= 0 && i < (NSInteger)[colors count] && [colors count] > 1) {
        [self deactivate];
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
                if (autoResizes)
                    [self sizeToFit];
                [self invalidateIntrinsicContentSize];
                [self noteFocusRingMaskChanged];
            }];
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
    return context == NSDraggingContextWithinApplication ? NSDragOperationGeneric : [colors count] > 1 ? NSDragOperationDelete : NSDragOperationNone;
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    if ((operation & NSDragOperationDelete) != 0 && operation != NSDragOperationEvery && draggedIndex != -1 && [self isEnabled])
        [self removeColorAtIndex:draggedIndex];
    draggedIndex = -1;
}

#pragma mark NSDraggingDestination protocol 

- (void)setDropLocation:(SKColorSwatchDropLocation)dropLocation atIndex:(NSInteger)anIndex {
    NSInteger i, iMax = [itemViews count];
    for (i = 0; i < iMax; i++) {
        SKColorSwatchDropLocation location = SKColorSwatchNoDrop;
        if (i == anIndex)
            location = dropLocation;
        else if (dropLocation == SKColorSwatchDropBefore && i + 1 == anIndex)
            location = SKColorSwatchDropAfter;
        [[itemViews objectAtIndex:i] setDropLocation:location];
    }
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    NSPoint mouseLoc = [self convertPoint:[sender draggingLocation] fromView:nil];
    BOOL isCopy = ([NSEvent standardModifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagOption;
    BOOL isMove = [sender draggingSource] == self && isCopy == NO;
    NSInteger i = isCopy || isMove ? [self insertionIndexAtPoint:mouseLoc] : [self colorIndexAtPoint:mouseLoc];
    NSDragOperation dragOp = isCopy ? NSDragOperationCopy : NSDragOperationGeneric;
    if ([self isEnabled] == NO || i == -1 ||
        (isMove && (i == draggedIndex || i == draggedIndex + 1))) {
        [self setDropLocation:SKColorSwatchNoDrop atIndex:-1];
        dragOp = NSDragOperationNone;
    } else {
        [self setDropLocation:(isCopy || isMove) ? SKColorSwatchDropBefore : SKColorSwatchDropOn atIndex:i];
    }
    return dragOp;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    [self setDropLocation:SKColorSwatchNoDrop atIndex:-1];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSColor *color = [NSColor colorFromPasteboard:pboard];
    NSPoint mouseLoc = [self convertPoint:[sender draggingLocation] fromView:nil];
    BOOL isCopy = ([NSEvent standardModifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagOption;
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
    
    [self setDropLocation:SKColorSwatchNoDrop atIndex:-1];
    
	return YES;
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

- (NSArray *)accessibilityChildren {
    return NSAccessibilityUnignoredChildren(itemViews);
}

- (NSArray *)accessibilityContents {
    return [self accessibilityChildren];
}

- (NSString *)accessibilityLabel {
    return NSLocalizedString(@"colors", @"accessibility description");
}

- (NSArray *)accessibilitySelectedChildren {
    if ([self selects] == NO)
        return nil;
    else if (selectedIndex == -1)
        return @[];
    else
        return NSAccessibilityUnignoredChildrenForOnlyChild([itemViews objectAtIndex:selectedIndex]);
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
    return [[self window] firstResponder] == self && focusedIndex == (NSInteger)[itemViews indexOfObject:itemView];
}

- (void)itemView:(SKColorSwatchItemView *)itemView setFocused:(BOOL)focused {
    if (focused) {
        NSUInteger anIndex = [itemViews indexOfObject:itemView];
        if (anIndex < [[self colors] count]) {
            focusedIndex = anIndex;
            [self noteFocusRingMaskChanged];
        }
        if ([[self window] firstResponder] != self)
            [[self window] makeFirstResponder:self];
    }
}

- (BOOL)isItemViewSelected:(SKColorSwatchItemView *)itemView {
    return selectedIndex !=-1 && selectedIndex == (NSInteger)[itemViews indexOfObject:itemView];
}

- (void)pressItemView:(SKColorSwatchItemView *)itemView  alternate:(BOOL)isAlternate {
    NSUInteger anIndex = [itemViews indexOfObject:itemView];
    if (anIndex < [[self colors] count]) {
        alternate = isAlternate;
        [self performClickAtIndex:anIndex];
        alternate = NO;
    }
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

- (BOOL)isAccessibilityElement {
    return NO;
}

- (NSArray *)accessibilityChildren {
    return nil;
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
    if (NSWidth(rect) < 5.0)
        return;
    rect = NSInsetRect(rect, 2.0, 2.0);
    CGFloat r = RUNNING_AFTER(10_15) ? 3.0 : 2.0;
    BOOL disabled = RUNNING_AFTER(10_13) && [[self window] isMainWindow] == NO && [[self window] isKeyWindow] == NO && ([self isDescendantOf:[[self window] contentView]] == NO || [[self window] isKindOfClass:NSClassFromString(@"NSToolbarSnapshotWindow")]);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 0.5, 0.5) xRadius:r - 0.5 yRadius:r - 0.5];

    if (NSWidth(rect) > 2.0) {
        [NSGraphicsContext saveGraphicsState];
        
        NSColor *aColor = color;
        if (disabled) {
            aColor = [aColor colorUsingColorSpace:[NSColorSpace genericGamma22GrayColorSpace]];
            CGContextSetAlpha([[NSGraphicsContext currentContext] CGContext], 0.5);
        }
        
        [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:r yRadius:r] addClip];
        [aColor drawSwatchInRect:rect];
        
        if (SKHasDarkAppearance(self)) {
            [[NSColor colorWithGenericGamma22White:1.0 alpha:0.25] setStroke];
            [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositingOperationScreen];
        } else {
            [[NSColor colorWithGenericGamma22White:0.0 alpha:0.25] setStroke];
            [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositingOperationMultiply];
        }
        [path stroke];
        
        [NSGraphicsContext restoreGraphicsState];
    }
    
    [NSGraphicsContext saveGraphicsState];
    
    if (highlighted || selected) {
        if (selected) {
            path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:r yRadius:r];
            [path setLineWidth:2.0];
        }
        [[NSColor systemGrayColor] setStroke];
        [path stroke];
    }
    
    if (dropLocation != SKColorSwatchNoDrop) {
        NSColor *dropColor = disabled ? [NSColor secondarySelectedControlColor] : [NSColor alternateSelectedControlColor];
        [dropColor setStroke];
        if (dropLocation == SKColorSwatchDropOn) {
            path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:r yRadius:r];
        } else if (dropLocation == SKColorSwatchDropBefore) {
            path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(NSMinX(rect) - 0.5, NSMinY(rect) - 1.0)];
            [path lineToPoint:NSMakePoint(NSMinX(rect) - 0.5, NSMaxY(rect) + 1.0)];
        } else if (dropLocation == SKColorSwatchDropAfter) {
            path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(NSMaxX(rect) + 0.5, NSMinY(rect) - 1.0)];
            [path lineToPoint:NSMakePoint(NSMaxX(rect) + 0.5, NSMaxY(rect) + 1.0)];
        }
        [path setLineWidth:3.0];
        if ((dropLocation == SKColorSwatchDropBefore && NSMinX([[self superview] bounds]) + 2.0 >= NSMinX([self frame])) ||
            (dropLocation == SKColorSwatchDropAfter && NSMaxX([[self superview] bounds]) - 2.0 <= NSMaxX([self frame])))
            [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, -2.0, -2.0) xRadius:r + 2.0 yRadius:r + 2.0] addClip];
        [path stroke];
    }
    
    [NSGraphicsContext restoreGraphicsState];
}

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSString *)accessibilityRole {
    return NSAccessibilityColorWellRole;
}

- (NSString *)accessibilityRoleDescription {
    return NSAccessibilityRoleDescription(NSAccessibilityColorWellRole, nil);
}

- (NSRect)accessibilityFrame {
    return [self convertRectToScreen:[self bounds]];
}

- (id)accessibilityParent {
    return NSAccessibilityUnignoredAncestor([self superview]);
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

- (BOOL)isAccessibilitySelected {
    return [(SKColorSwatch *)[self superview] isItemViewSelected:self];
}

- (BOOL)accessibilityPerformPress {
    [(SKColorSwatch *)[self superview] pressItemView:self alternate:NO];
    return YES;
}

- (BOOL)accessibilityPerformPick {
    [(SKColorSwatch *)[self superview] pressItemView:self alternate:YES];
    return YES;
}

- (id)accessibilityFocusedUIElement {
    return NSAccessibilityUnignoredAncestor(self);
}

@end

