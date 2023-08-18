//
//  SKNavigationWindow.m
//  Skim
//
//  Created by Christiaan Hofman on 12/19/06.
/*
 This software is Copyright (c) 2006-2023
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

#import "SKNavigationWindow.h"
#import <Quartz/Quartz.h>
#import "NSBezierPath_SKExtensions.h"
#import "SKPDFView.h"
#import "NSParagraphStyle_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "NSShadow_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "SKStringConstants.h"
#import <SkimNotes/SkimNotes.h>

#define BUTTON_WIDTH 50.0
#define BUTTON_HEIGHT 50.0
#define SLIDER_WIDTH 100.0
#define SEP_WIDTH 21.0
#define SMALL_SEP_WIDTH 13.0
#define BUTTON_MARGIN 7.0
#define WINDOW_OFFSET 20.0
#define LABEL_OFFSET 10.0
#define LABEL_TEXT_MARGIN 2.0

#define CORNER_RADIUS 10.0

static inline NSBezierPath *nextButtonPath(NSSize size);
static inline NSBezierPath *previousButtonPath(NSSize size);
static inline NSBezierPath *zoomButtonPath(NSSize size);
static inline NSBezierPath *alternateZoomButtonPath(NSSize size);
static inline NSBezierPath *cursorButtonPath(NSSize size);
static inline NSBezierPath *closeButtonPath(NSSize size);

@implementation SKHUDWindow

- (id)initWithPDFView:(SKPDFView *)pdfView {
    NSScreen *screen = [[pdfView window] screen] ?: [NSScreen mainScreen];
    CGFloat width = 5 * BUTTON_WIDTH + 3 * SEP_WIDTH + 2 * BUTTON_MARGIN;
    NSRect contentRect = NSMakeRect(NSMidX([screen frame]) - 0.5 * width, NSMinY([screen frame]) + WINDOW_OFFSET, width, BUTTON_HEIGHT + 2 * BUTTON_MARGIN);
    self = [super initWithContentRect:contentRect];
    if (self) {
        
        [self setIgnoresMouseEvents:NO];
        [self setDisplaysWhenScreenProfileChanges:YES];
        [self setLevel:[[pdfView window] level]];
        [self setMovableByWindowBackground:YES];
        
        contentRect.origin = NSZeroPoint;
        NSVisualEffectView *contentView = [[NSVisualEffectView alloc] initWithFrame:contentRect];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        [contentView setMaterial:RUNNING_BEFORE(10_14) ? NSVisualEffectMaterialDark : NSVisualEffectMaterialFullScreenUI];
#pragma clang diagnostic pop
        [contentView setState:NSVisualEffectStateActive];
        
        [self setContentView:contentView];
        [contentView release];
        
        SKSetHasDarkAppearance(self);
        
    }
    return self;
}

- (void)showForWindow:(NSWindow *)window {
    NSRect frame = [window frame];
    CGFloat width = NSWidth([self frame]);
    frame = NSMakeRect(NSMidX(frame) - 0.5 * width, NSMinY(frame) + WINDOW_OFFSET, width, NSHeight([self frame]));
    [self setFrame:frame display:NO];
    if ([self parentWindow] == nil) {
        [self setAlphaValue:0.0];
        [window addChildWindow:self ordered:NSWindowAbove];
    }
    [self fadeIn];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleParentWindowDidResizeNotification:) name:NSWindowDidResizeNotification object:window];
}

- (void)remove {
    if ([self parentWindow]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:[self parentWindow]];
        [[self parentWindow] removeChildWindow:self];
    }
    [super remove];
}

- (void)handleParentWindowDidResizeNotification:(NSNotification *)notification {
    NSWindow *window = [self parentWindow];
    NSRect frame = [window frame];
    frame.origin = NSMakePoint(NSMidX(frame) - 0.5 * NSWidth([self frame]), NSMinY(frame) + WINDOW_OFFSET);
    frame.size = [self frame].size;
    [self setFrame:frame display:YES];
}

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSArray *)accessibilityChildren {
    return NSAccessibilityUnignoredChildren([[self contentView] subviews]);
}

@end

#pragma mark -

@implementation SKNavigationWindow

- (id)initWithPDFView:(SKPDFView *)pdfView {
    self = [super initWithPDFView:pdfView];
    if (self) {
        
        NSRect rect = NSMakeRect(BUTTON_MARGIN, BUTTON_MARGIN, BUTTON_WIDTH, BUTTON_HEIGHT);
        previousButton = [[SKNavigationButton alloc] initWithFrame:rect];
        [previousButton setTarget:pdfView];
        [previousButton setAction:@selector(goToPreviousPage:)];
        [previousButton setToolTip:NSLocalizedString(@"Previous", @"Tool tip message")];
        [previousButton setPath:previousButtonPath(rect.size)];
        [previousButton setEnabled:[pdfView canGoToPreviousPage]];
        [[self contentView] addSubview:previousButton];
        
        rect.origin.x = NSMaxX(rect);
        nextButton = [[SKNavigationButton alloc] initWithFrame:rect];
        [nextButton setTarget:pdfView];
        [nextButton setAction:@selector(goToNextPage:)];
        [nextButton setToolTip:NSLocalizedString(@"Next", @"Tool tip message")];
        [nextButton setPath:nextButtonPath(rect.size)];
        [nextButton setEnabled:[pdfView canGoToNextPage]];
        [[self contentView] addSubview:nextButton];
        
        rect.origin.x = NSMaxX(rect);
        rect.size.width = SEP_WIDTH;
        [[self contentView] addSubview:[[[SKNavigationSeparator alloc] initWithFrame:rect] autorelease]];
        
        rect.origin.x = NSMaxX(rect);
        rect.size.width = BUTTON_WIDTH;
        zoomButton = [[SKNavigationButton alloc] initWithFrame:rect];
        [zoomButton setTarget:pdfView];
        [zoomButton setAction:@selector(toggleAutoActualSize:)];
        [zoomButton setToolTip:NSLocalizedString(@"Fit to Screen", @"Tool tip message")];
        [zoomButton setAlternateToolTip:NSLocalizedString(@"Actual Size", @"Tool tip message")];
        [zoomButton setPath:zoomButtonPath(rect.size)];
        [zoomButton setAlternatePath:alternateZoomButtonPath(rect.size)];
        [zoomButton setState:[pdfView autoScales]];
        [zoomButton setButtonType:NSPushOnPushOffButton];
        [[self contentView] addSubview:zoomButton];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScaleChangedNotification:) 
                                                     name:PDFViewScaleChangedNotification object:pdfView];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePageChangedNotification:) 
                                                     name:PDFViewPageChangedNotification object:pdfView];
        
        rect.origin.x = NSMaxX(rect);
        rect.size.width = SEP_WIDTH;
        [[self contentView] addSubview:[[[SKNavigationSeparator alloc] initWithFrame:rect] autorelease]];
        
        rect.origin.x = NSMaxX(rect);
        rect.size.width = BUTTON_WIDTH;
        cursorButton = [[SKNavigationButton alloc] initWithFrame:rect];
        [cursorButton setTarget:pdfView];
        [cursorButton setAction:@selector(showCursorStyleWindow:)];
        [cursorButton setToolTip:NSLocalizedString(@"Cursor", @"Tool tip message")];
        [cursorButton setPath:cursorButtonPath(rect.size)];
        [[self contentView] addSubview:cursorButton];
        
        rect.origin.x = NSMaxX(rect);
        rect.size.width = SEP_WIDTH;
        [[self contentView] addSubview:[[[SKNavigationSeparator alloc] initWithFrame:rect] autorelease]];
        
        rect.origin.x = NSMaxX(rect);
        rect.size.width = BUTTON_WIDTH;
        closeButton = [[SKNavigationButton alloc] initWithFrame:rect];
        [closeButton setTarget:pdfView];
        [closeButton setAction:@selector(exitPresentation:)];
        [closeButton setToolTip:NSLocalizedString(@"Close", @"Tool tip message")];
        [closeButton setPath:closeButtonPath(rect.size)];
        [[self contentView] addSubview:closeButton];
        
        NSScreen *screen = [[pdfView window] screen] ?: [NSScreen mainScreen];
        NSRect frame;
        frame.size.width = 5 * BUTTON_WIDTH + 3 * SEP_WIDTH + 2 * BUTTON_MARGIN;
        frame.size.height = BUTTON_HEIGHT + 2.0 * BUTTON_MARGIN;
        frame.origin.x = NSMidX([screen frame]) - 0.5 * NSWidth(frame);
        frame.origin.y = NSMinY([screen frame]) + WINDOW_OFFSET;
        [self setFrame:frame display:NO];
        [(NSVisualEffectView *)[self contentView] setMaskImage:[NSImage maskImageWithSize:frame.size cornerRadius:CORNER_RADIUS]];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SKDESTROY(previousButton);
    SKDESTROY(nextButton);
    SKDESTROY(zoomButton);
    SKDESTROY(cursorButton);
    SKDESTROY(closeButton);
    [super dealloc];
}

- (void)orderOut:(id)sender {
    [[SKNavigationToolTipWindow sharedToolTipWindow] orderOut:nil];
    [super orderOut:sender];
}

- (void)handleScaleChangedNotification:(NSNotification *)notification {
    [zoomButton setState:[[notification object] autoScales] ? NSOnState : NSOffState];
}

- (void)handlePageChangedNotification:(NSNotification *)notification {
    [previousButton setEnabled:[[notification object] canGoToPreviousPage]];
    [nextButton setEnabled:[[notification object] canGoToNextPage]];
}

@end

#pragma mark -

@interface SKCursorStyleWindow () <NSMenuDelegate>
@end

@implementation SKCursorStyleWindow

- (id)initWithPDFView:(SKPDFView *)pdfView {
    self = [super initWithPDFView:pdfView];
    if (self) {
        
        NSRect rect;
        
        styleButton = [[SKHUDSegmentedControl alloc] init];
        [styleButton setSegmentCount:8];
        [styleButton setTrackingMode:NSSegmentSwitchTrackingSelectOne];
        NSInteger i;
        for (i = 0; i < 8; i++) {
            [styleButton setWidth:24.0 forSegment:i];
            [[styleButton cell] setTag:i - 1 forSegment:i];
            [styleButton setImage:i > 0 ? [NSImage laserPointerImageWithColor:i - 1] : [[NSCursor arrowCursor] image] forSegment:i];
        }
        [styleButton sizeToFit];
        rect = [styleButton frame];
        rect.origin.x = rect.origin.y = BUTTON_MARGIN;
        [styleButton setFrame:rect];
        [[styleButton cell] selectSegmentWithTag:[pdfView cursorStyle]];
        [styleButton setTarget:pdfView];
        [styleButton setAction:@selector(changeCursorStyle:)];
        if (RUNNING_BEFORE(10_14))
            [[styleButton cell] setBackgroundStyle:NSBackgroundStyleDark];
        NSArray *segments = [NSAccessibilityUnignoredDescendant(styleButton) accessibilityChildren];
        [[segments objectAtIndex:0] setAccessibilityLabel:NSLocalizedString(@"arrow", @"Accessibility description")];
        [[segments objectAtIndex:1] setAccessibilityLabel:NSLocalizedString(@"red", @"Accessibility description")];
        [[segments objectAtIndex:2] setAccessibilityLabel:NSLocalizedString(@"orange", @"Accessibility description")];
        [[segments objectAtIndex:3] setAccessibilityLabel:NSLocalizedString(@"yellow", @"Accessibility description")];
        [[segments objectAtIndex:4] setAccessibilityLabel:NSLocalizedString(@"green", @"Accessibility description")];
        [[segments objectAtIndex:5] setAccessibilityLabel:NSLocalizedString(@"blue", @"Accessibility description")];
        [[segments objectAtIndex:6] setAccessibilityLabel:NSLocalizedString(@"indigo", @"Accessibility description")];
        [[segments objectAtIndex:7] setAccessibilityLabel:NSLocalizedString(@"violet", @"Accessibility description")];
        [[self contentView] addSubview:styleButton];
        
        rect.origin.x = NSMaxX(rect);
        rect.size.width = NSHeight(rect);
        removeShadowButton = [[SKHUDSegmentedControl alloc] initWithFrame:rect];
        [removeShadowButton setSegmentCount:1];
        [removeShadowButton setTrackingMode:NSSegmentSwitchTrackingSelectAny];
        [removeShadowButton setLabel:NSLocalizedString(@"Remove shadow", @"Button title") forSegment:0];
        [removeShadowButton setSelected:[pdfView removeCursorShadow] forSegment:0];
        [removeShadowButton setTarget:pdfView];
        [removeShadowButton setAction:@selector(toggleRemoveCursorShadow:)];
        if (RUNNING_BEFORE(10_14))
            [[removeShadowButton cell] setBackgroundStyle:NSBackgroundStyleDark];
        [removeShadowButton setWidth:ceil([[removeShadowButton labelForSegment:0] sizeWithAttributes:@{NSFontAttributeName:[removeShadowButton font]}].width) + 8.0 forSegment:0];
        [removeShadowButton sizeToFit];
        rect.size.width = NSWidth([removeShadowButton frame]);
        [[self contentView] addSubview:removeShadowButton];
        
        rect.origin.x = NSMaxX(rect);
        rect.size.width = SMALL_SEP_WIDTH;
        [[self contentView] addSubview:[[[SKNavigationSeparator alloc] initWithFrame:rect] autorelease]];
        
        rect.origin.x = NSMaxX(rect);
        rect.size.width = NSHeight(rect);
        drawButton = [[SKHUDSegmentedControl alloc] initWithFrame:rect];
        [drawButton setSegmentCount:1];
        [drawButton setTrackingMode:NSSegmentSwitchTrackingSelectAny];
        [drawButton setWidth:30.0 forSegment:0];
        [drawButton setImage:[NSImage imageNamed:SKImageNameInkToolAdorn] forSegment:0];
        [drawButton setSelected:[pdfView drawInPresentation] forSegment:0];
        [drawButton setTarget:pdfView];
        [drawButton setAction:@selector(toggleDrawInPresentation:)];
        if (RUNNING_BEFORE(10_14))
            [[drawButton cell] setBackgroundStyle:NSBackgroundStyleDark];
        [[[NSAccessibilityUnignoredDescendant(drawButton) accessibilityChildren] firstObject] setAccessibilityLabel:[SKNInkString typeName]];
        [drawButton sizeToFit];
        rect.size.width = NSWidth([drawButton frame]);
        [[self contentView] addSubview:drawButton];
        
        NSMenu *menu = [[[NSMenu alloc] init] autorelease];
        [menu setDelegate:self];
        [drawButton setMenu:menu forSegment:0];

        rect.origin.x = NSMaxX(rect);
        rect.size.width = SMALL_SEP_WIDTH;
        [[self contentView] addSubview:[[[SKNavigationSeparator alloc] initWithFrame:rect] autorelease]];
        
        rect.origin.x = NSMaxX(rect);
        rect.size.width = NSHeight(rect);
        closeButton = [[SKHUDSegmentedControl alloc] initWithFrame:rect];
        [closeButton setSegmentCount:1];
        [closeButton setTrackingMode:NSSegmentSwitchTrackingMomentary];
        [closeButton setWidth:24.0 forSegment:0];
        [closeButton setImage:[NSImage imageNamed:NSImageNameStopProgressTemplate] forSegment:0];
        [closeButton setTarget:pdfView];
        [closeButton setAction:@selector(closeCursorStyleWindow:)];
        if (RUNNING_BEFORE(10_14))
            [[closeButton cell] setBackgroundStyle:NSBackgroundStyleDark];
        [[[NSAccessibilityUnignoredDescendant(closeButton) accessibilityChildren] firstObject] setAccessibilityLabel:NSLocalizedString(@"close", @"Accessibility description")];
        [closeButton sizeToFit];
        [[self contentView] addSubview:closeButton];
        
        NSScreen *screen = [[pdfView window] screen] ?: [NSScreen mainScreen];
        NSRect frame;
        frame.size.width = NSWidth([styleButton frame]) + NSWidth([removeShadowButton frame]) + NSWidth([drawButton frame]) + NSWidth([closeButton frame]) + 2.0 * BUTTON_MARGIN + 2.0 * SMALL_SEP_WIDTH;
        frame.size.height = NSHeight(rect) + 2.0 * BUTTON_MARGIN;
        frame.origin.x = NSMidX([screen frame]) - 0.5 * NSWidth(frame);
        frame.origin.y = NSMinY([screen frame]) + WINDOW_OFFSET;
        [self setFrame:frame display:NO];
        [(NSVisualEffectView *)[self contentView] setMaskImage:[NSImage maskImageWithSize:frame.size cornerRadius:CORNER_RADIUS]];
    }
    return self;
}

- (void)dealloc {
    SKDESTROY(styleButton);
    SKDESTROY(removeShadowButton);
    SKDESTROY(drawButton);
    SKDESTROY(closeButton);
    [super dealloc];
}

- (void)selectCursorStyle:(NSInteger)style {
    [[styleButton cell] selectSegmentWithTag:style];
}

- (void)removeShadow:(BOOL)removeShadow {
    [removeShadowButton setSelected:removeShadow forSegment:0];
}

- (void)chooseColor:(id)sender {
    NSColor *color = [sender representedObject];
    if ([color isEqual:[[NSUserDefaults standardUserDefaults] colorForKey:SKInkNoteColorKey]])
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:SKPresentationInkNoteColorKey];
    else
        [[NSUserDefaults standardUserDefaults] setColor:color forKey:SKPresentationInkNoteColorKey];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [menu removeAllItems];
    
    NSMutableArray *colors = [[[NSColor favoriteColors] mutableCopy] autorelease];
    NSColor *inkColor = [[NSUserDefaults standardUserDefaults] colorForKey:SKInkNoteColorKey];
    NSColor *tmpColor = [[NSUserDefaults standardUserDefaults] colorForKey:SKPresentationInkNoteColorKey];
    if ([colors containsObject:inkColor] == NO)
        [colors insertObject:inkColor atIndex:0];
    if (tmpColor && [colors containsObject:tmpColor] == NO)
        [colors insertObject:tmpColor atIndex:0];
    
    NSSize size = NSMakeSize(16.0, 16.0);
    
    for (NSColor *color in colors) {
        NSMenuItem *item = [menu addItemWithTitle:@"" action:@selector(chooseColor:) target:self];
        
        NSImage *image = [NSImage imageWithSize:size flipped:NO drawingHandler:^(NSRect rect){
                [color drawSwatchInRoundedRect:rect];
                return YES;
            }];
        [image setAccessibilityDescription:[color accessibilityValue]];
        [item setRepresentedObject:color];
        [item setImage:image];
        if ([color isEqual:tmpColor ?: inkColor])
            [item setState:NSOnState];
    }
}

@end

#pragma mark -

@implementation SKNavigationToolTipWindow

@synthesize view;

+ (id)sharedToolTipWindow {
    static SKNavigationToolTipWindow *sharedToolTipWindow = nil;
    if (sharedToolTipWindow == nil)
        sharedToolTipWindow = [[self alloc] init];
    return sharedToolTipWindow;
}

- (id)init {
    self = [super initWithContentRect:NSZeroRect styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
    if (self) {
		[self setBackgroundColor:[NSColor clearColor]];
		[self setOpaque:NO];
        [self setDisplaysWhenScreenProfileChanges:YES];
        [self setReleasedWhenClosed:NO];
        [self setHidesOnDeactivate:NO];
        
        [self setContentView:[[[SKNavigationToolTipView alloc] init] autorelease]];
    }
    return self;
}

- (BOOL)canBecomeKeyWindow { return NO; }

- (BOOL)canBecomeMainWindow { return NO; }

- (void)showToolTip:(NSString *)toolTip forView:(NSView *)aView {
    [view release];
    view = [aView retain];
    [[self contentView] setStringValue:toolTip];
    NSRect newFrame = NSZeroRect;
    NSRect viewRect = [view convertRectToScreen:[view bounds]];
    newFrame.size = [[self contentView] fitSize];
    newFrame.origin = NSMakePoint(ceil(NSMidX(viewRect) - 0.5 * NSWidth(newFrame)), NSMaxY(viewRect) + LABEL_OFFSET);
    [self setFrame:newFrame display:YES];
    [self setLevel:[[view window] level]];
    if ([self parentWindow] != [view window])
        [[self parentWindow] removeChildWindow:self];
    if ([self parentWindow] == nil)
        [[view window] addChildWindow:self ordered:NSWindowAbove];
    [self orderFront:self];
}

- (void)orderOut:(id)sender {
    [[self parentWindow] removeChildWindow:self];
    [super orderOut:sender];
    SKDESTROY(view);
}

@end

#pragma mark -

@implementation SKNavigationToolTipView

@synthesize stringValue;
@dynamic attributedStringValue;

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        stringValue = nil;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        stringValue = [[decoder decodeObjectForKey:@"stringValue"] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:stringValue forKey:@"stringValue"];
}

- (void)dealloc {
    SKDESTROY(stringValue);
    [super dealloc];
}

- (NSAttributedString *)attributedStringValue {
    if (stringValue == nil)
        return nil;
    NSShadow *aShadow = [[NSShadow alloc] init];
    [aShadow setShadowColor:[NSColor blackColor]];
    [aShadow setShadowBlurRadius:2.0];
    NSDictionary *attrs = @{NSFontAttributeName:
        [NSFont boldSystemFontOfSize:15.0],
                            NSForegroundColorAttributeName:[NSColor whiteColor],
                            NSParagraphStyleAttributeName:[NSParagraphStyle defaultClippingParagraphStyle],
                            NSShadowAttributeName:aShadow};
    [aShadow release];
    return [[[NSAttributedString alloc] initWithString:stringValue attributes:attrs] autorelease];
}

- (NSSize)fitSize {
    NSSize stringSize = [[self attributedStringValue] size];
    return NSMakeSize(ceil(stringSize.width + 2 * LABEL_TEXT_MARGIN), ceil(stringSize.height + 2 * LABEL_TEXT_MARGIN));
}

- (void)drawRect:(NSRect)rect {
    NSRect textRect = NSInsetRect(rect, LABEL_TEXT_MARGIN, LABEL_TEXT_MARGIN);
    NSAttributedString *attrString = [self attributedStringValue];
    // draw it 3x to see some shadow
    [attrString drawInRect:textRect];
    [attrString drawInRect:textRect];
    [attrString drawInRect:textRect];
}

@end

#pragma mark -

@implementation SKNavigationButton

@dynamic path, alternatePath, toolTip, alternateToolTip;

+ (Class)cellClass { return [SKNavigationButtonCell class]; }

- (NSBezierPath *)path {
    return [(SKNavigationButtonCell *)[self cell] path];
}

- (void)setPath:(NSBezierPath *)newPath {
    [(SKNavigationButtonCell *)[self cell] setPath:newPath];
}

- (NSBezierPath *)alternatePath {
    return [(SKNavigationButtonCell *)[self cell] alternatePath];
}

- (void)setAlternatePath:(NSBezierPath *)newAlternatePath {
    [(SKNavigationButtonCell *)[self cell] setAlternatePath:newAlternatePath];
}

- (NSString *)toolTip {
    return [(SKNavigationButtonCell *)[self cell] toolTip];
}

// we don't use the superclass's ivar because we don't want the system toolTips
- (void)setToolTip:(NSString *)string {
    [(SKNavigationButtonCell *)[self cell] setToolTip:string];
    [self setShowsBorderOnlyWhileMouseInside:[string length] > 0];
}

- (NSString *)alternateToolTip {
    return [(SKNavigationButtonCell *)[self cell] alternateToolTip];
}

- (void)setAlternateToolTip:(NSString *)string {
    [(SKNavigationButtonCell *)[self cell] setAlternateToolTip:string];
}

@end

#pragma mark -

@implementation SKNavigationButtonCell

@synthesize path, alternatePath, toolTip, alternateToolTip;

- (id)initTextCell:(NSString *)aString {
    self = [super initTextCell:@""];
    if (self) {
		[self setBezelStyle:NSShadowlessSquareBezelStyle]; // this is mainly to make it selectable
        [self setBordered:NO];
        [self setButtonType:NSMomentaryPushInButton];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        toolTip = [[decoder decodeObjectForKey:@"toolTip"] retain];
        alternateToolTip = [[decoder decodeObjectForKey:@"alternateToolTip"] retain];
        path = [[decoder decodeObjectForKey:@"path"] retain];
        alternatePath = [[decoder decodeObjectForKey:@"alternatePath"] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:toolTip forKey:@"toolTip"];
    [coder encodeObject:alternateToolTip forKey:@"alternateToolTip"];
    [coder encodeObject:path forKey:@"path"];
    [coder encodeObject:alternatePath forKey:@"alternatePath"];
}

- (id)copyWithZone:(NSZone *)zone {
    SKNavigationButtonCell *copy = [super copyWithZone:zone];
    copy->toolTip = [toolTip retain];
    copy->alternateToolTip = [alternateToolTip retain];
    copy->path = [path retain];
    copy->alternatePath = [alternatePath retain];
    return copy;
}

- (void)dealloc {
    SKDESTROY(toolTip);
    SKDESTROY(alternateToolTip);
    SKDESTROY(path);
    SKDESTROY(alternatePath);
    [super dealloc];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [[NSColor colorWithDeviceWhite:1.0 alpha:[self isEnabled] == NO ? 0.3 : [self isHighlighted] ? 0.9 : 0.6] setFill];
    [([self state] == NSOnState && [self alternatePath] ? [self alternatePath] : [self path]) fill];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    NSString *currentToolTip = [self state] == NSOnState && alternateToolTip ? alternateToolTip : toolTip;
    [[SKNavigationToolTipWindow sharedToolTipWindow] showToolTip:currentToolTip forView:[self controlView]];
    [super mouseEntered:theEvent];
}

- (void)mouseExited:(NSEvent *)theEvent {
    if ([[[SKNavigationToolTipWindow sharedToolTipWindow] view] isEqual:[self controlView]])
        [[SKNavigationToolTipWindow sharedToolTipWindow] orderOut:nil];
    [super mouseExited:theEvent];
}

- (void)setState:(NSInteger)state {
    NSInteger oldState = [self state];
    NSView *button = [self controlView];
    [super setState:state];
    if (oldState != state && [[button window] isVisible]) {
        if (alternatePath)
            [button setNeedsDisplay:YES];
        if (alternateToolTip && [[[SKNavigationToolTipWindow sharedToolTipWindow] view] isEqual:button]) {
            NSString *currentToolTip = [self state] == NSOnState && alternateToolTip ? alternateToolTip : toolTip;
            [[SKNavigationToolTipWindow sharedToolTipWindow] showToolTip:currentToolTip forView:button];
        }
    }
    [self setAccessibilityLabel:state == NSOnState && alternateToolTip ? alternateToolTip : toolTip];
}

- (void)setToolTip:(NSString *)aToolTip {
    if (aToolTip != toolTip) {
        [toolTip release];
        toolTip = [aToolTip retain];
        if ([self state] == NSOffState || alternateToolTip == nil)
            [self setAccessibilityLabel:toolTip];
    }
}

- (void)setAlternateToolTip:(NSString *)aToolTip {
    if (aToolTip != alternateToolTip) {
        [alternateToolTip release];
        alternateToolTip = [aToolTip retain];
        if ([self state] == NSOnState)
            [self setAccessibilityLabel:alternateToolTip];
    }
}

- (NSString *)accessibilityLabel {
    return [self state] == NSOnState && alternateToolTip ? alternateToolTip : toolTip;
}

@end

#pragma mark -

@implementation SKNavigationSeparator

- (void)drawRect:(NSRect)rect {
    NSRect bounds = [self bounds];
    [[NSColor colorWithDeviceWhite:1.0 alpha:0.6] setFill];
    [NSBezierPath fillRect:NSMakeRect(NSMidX(bounds) - 0.5, NSMinY(bounds), 1.0, NSHeight(bounds))];
}

@end

#pragma mark -

@implementation SKHUDSegmentedControl

+ (Class)cellClass { return [SKHUDSegmentedCell class]; }

- (BOOL)allowsVibrancy { return NO; }

- (void)sizeToFit {
    [super sizeToFit];
    [self setFrameSize:NSMakeSize(NSWidth([self frame]), 24.0)];
}
@end

#pragma mark -

@implementation SKHUDSegmentedCell

- (NSRect)drawingRectForBounds:(NSRect)bounds {
    NSRect rect = [super drawingRectForBounds:bounds];
    rect.origin.y = NSMinY(bounds);
    rect.size.height = NSHeight(bounds);
    return rect;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [self drawInteriorWithFrame:[self drawingRectForBounds:cellFrame] inView:controlView];
}

- (void)drawSegment:(NSInteger)segment inFrame:(NSRect)frame withView:(NSView *)controlView {
    if ([self isSelectedForSegment:segment]) {
        [NSGraphicsContext saveGraphicsState];
        [[NSColor colorWithGenericGamma22White:1.0 alpha:[self isEnabledForSegment:segment] ? 0.5 : 0.3] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:frame xRadius:5.0 yRadius:5.0] fill];
        [NSGraphicsContext restoreGraphicsState];
    }
    NSString *label = [self labelForSegment:segment];
    NSImage *image = [self imageForSegment:segment];
    if ([label length]) {
        NSMutableParagraphStyle *paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        NSColor *color = nil;
        if ([self isSelectedForSegment:segment])
            color = [NSColor colorWithGenericGamma22White:0.0 alpha:[self isEnabledForSegment:segment] ? 0.9 : 0.7];
        else
            color = [NSColor colorWithGenericGamma22White:1.0 alpha:[self isEnabledForSegment:segment] ? 0.9 : 0.3];
        [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
        [paragraphStyle setAlignment:NSCenterTextAlignment];
        NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:label attributes:@{NSFontAttributeName:[self font], NSForegroundColorAttributeName:color, NSParagraphStyleAttributeName:paragraphStyle}];
        NSRect rect = frame;
        CGFloat height = [attrString size].height;
        rect.origin.y = NSMidY(rect) - 0.5 * height;
        rect.size.height = height;
        [attrString drawInRect:rect];
    } else if (image) {
        NSRect rect = frame;
        NSRect srcRect = (NSRect){NSZeroPoint, [image size]};
        CGFloat d = 0.5 * (NSWidth(rect) - NSWidth(srcRect));
        if (d > 0.0)
            rect = NSInsetRect(rect, d, 0.0);
        else if (d < 0.0)
            srcRect = NSInsetRect(srcRect, -d, 0.0);
        d = 0.5 * (NSHeight(rect) - NSHeight(srcRect));
        if (d > 0.0)
            rect = NSInsetRect(rect, 0.0, d);
        else if (d < 0.0)
            srcRect = NSInsetRect(srcRect, 0.0, -d);
        if ([image isTemplate]) {
            NSColor *color = nil;
            if ([self isSelectedForSegment:segment])
                color = [NSColor colorWithGenericGamma22White:0.0 alpha:[self isEnabledForSegment:segment] ? 1.0 : 0.7];
            else
                color = [NSColor colorWithGenericGamma22White:1.0 alpha:[self isEnabledForSegment:segment] ? 0.9 : 0.3];
            CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
            CGContextBeginTransparencyLayerWithRect(context, NSRectToCGRect(frame), NULL);
            [color setFill];
            [NSBezierPath fillRect:rect];
            [image drawInRect:rect fromRect:srcRect operation:NSCompositingOperationDestinationIn fraction:1.0 respectFlipped:YES hints:nil];
            CGContextEndTransparencyLayer(context);
        } else {
            [image drawInRect:rect fromRect:srcRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:YES hints:nil];
        }
    }
}

@end

#pragma mark Button paths

static inline NSBezierPath *nextButtonPath(NSSize size) {
    NSRect bounds = {NSZeroPoint, size};
    NSRect rect = NSInsetRect(bounds, 10.0, 10.0);
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(NSMaxX(rect), NSMidY(rect))];
    [path lineToPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect))];
    [path lineToPoint:NSMakePoint(NSMinX(rect), NSMinY(rect))];
    [path closePath];
    return path;
}

static inline NSBezierPath *previousButtonPath(NSSize size) {
    NSRect bounds = {NSZeroPoint, size};
    NSRect rect = NSInsetRect(bounds, 10.0, 10.0);
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(NSMinX(rect), NSMidY(rect))];
    [path lineToPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
    [path lineToPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect))];
    [path closePath];
    return path;
}

static inline NSBezierPath *zoomButtonPath(NSSize size) {
    NSRect bounds = {NSZeroPoint, size};
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 15.0, 15.0) xRadius:3.0 yRadius:3.0];
    CGFloat centerX = NSMidX(bounds), centerY = NSMidY(bounds);
    
    [path appendBezierPath:[NSBezierPath bezierPathWithRect:NSInsetRect(bounds, 19.0, 19.0)]];
    
    NSBezierPath *arrow = [NSBezierPath bezierPath];
    [arrow moveToPoint:NSMakePoint(centerX, NSMaxY(bounds) + 2.0)];
    [arrow relativeLineToPoint:NSMakePoint(-5.0, -5.0)];
    [arrow relativeLineToPoint:NSMakePoint(3.0, 0.0)];
    [arrow relativeLineToPoint:NSMakePoint(0.0, -5.0)];
    [arrow relativeLineToPoint:NSMakePoint(4.0, 0.0)];
    [arrow relativeLineToPoint:NSMakePoint(0.0, 5.0)];
    [arrow relativeLineToPoint:NSMakePoint(3.0, 0.0)];
    [arrow relativeLineToPoint:NSMakePoint(-5.0, 5.0)];
    
    NSAffineTransform *transform = [[[NSAffineTransform alloc] init] autorelease];
    [transform translateXBy:centerX yBy:centerY];
    [transform rotateByDegrees:45.0];
    [transform translateXBy:-centerX yBy:-centerY];
    [arrow transformUsingAffineTransform:transform];
    [transform translateXBy:centerX yBy:centerY];
    [transform rotateByDegrees:45.0];
    [transform translateXBy:-centerX yBy:-centerY];
    
    NSInteger i;
    for (i = 0; i < 4; i++) {
        [path appendBezierPath:arrow];
        [arrow transformUsingAffineTransform:transform];
    }
    
    [path setWindingRule:NSEvenOddWindingRule];
    
    return path;
}

static inline NSBezierPath *alternateZoomButtonPath(NSSize size) {
    NSRect bounds = {NSZeroPoint, size};
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 15.0, 15.0) xRadius:3.0 yRadius:3.0];
    CGFloat centerX = NSMidX(bounds), centerY = NSMidY(bounds);
    
    [path appendBezierPath:[NSBezierPath bezierPathWithRect:NSInsetRect(bounds, 19.0, 19.0)]];
    
    NSBezierPath *arrow = [NSBezierPath bezierPath];
    [arrow moveToPoint:NSMakePoint(centerX, NSMaxY(bounds) - 8.0)];
    [arrow relativeLineToPoint:NSMakePoint(-5.0, 5.0)];
    [arrow relativeLineToPoint:NSMakePoint(3.0, 0.0)];
    [arrow relativeLineToPoint:NSMakePoint(0.0, 5.0)];
    [arrow relativeLineToPoint:NSMakePoint(4.0, 0.0)];
    [arrow relativeLineToPoint:NSMakePoint(0.0, -5.0)];
    [arrow relativeLineToPoint:NSMakePoint(3.0, 0.0)];
    [arrow relativeLineToPoint:NSMakePoint(-5.0, -5.0)];
    
    NSAffineTransform *transform = [[[NSAffineTransform alloc] init] autorelease];
    [transform translateXBy:centerX yBy:centerY];
    [transform rotateByDegrees:45.0];
    [transform translateXBy:-centerX yBy:-centerY];
    [arrow transformUsingAffineTransform:transform];
    [transform translateXBy:centerX yBy:centerY];
    [transform rotateByDegrees:45.0];
    [transform translateXBy:-centerX yBy:-centerY];
    
    NSInteger i;
    for (i = 0; i < 4; i++) {
        [path appendBezierPath:arrow];
        [arrow transformUsingAffineTransform:transform];
    }
    
    [path setWindingRule:NSEvenOddWindingRule];
    
    return path;
}

static inline NSBezierPath *cursorButtonPath(NSSize size) {
    NSRect bounds = {NSZeroPoint, size};
    NSRect rect = NSInsetRect(bounds, 10.0, 10.0);
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(NSMidX(rect) - 2.0, NSMaxY(rect))];
    [path lineToPoint:NSMakePoint(NSMidX(rect) + 2.0, NSMaxY(rect))];
    [path lineToPoint:NSMakePoint(NSMidX(rect) + 2.0, NSMidY(rect) + 3.0)];
    [path lineToPoint:NSMakePoint(NSMidX(rect) + 9.0, NSMidY(rect) + 5.0)];
    [path lineToPoint:NSMakePoint(NSMidX(rect), NSMinY(rect))];
    [path lineToPoint:NSMakePoint(NSMidX(rect) - 9.0, NSMidY(rect) + 5.0)];
    [path lineToPoint:NSMakePoint(NSMidX(rect) - 2.0, NSMidY(rect) + 3.0)];
    [path closePath];
    
    NSAffineTransform *transform = [[[NSAffineTransform alloc] init] autorelease];
    CGFloat centerX = NSMidX(bounds), centerY = NSMidY(bounds);
    [transform translateXBy:centerX yBy:centerY];
    [transform rotateByDegrees:-20.0];
    [transform translateXBy:-centerX yBy:-centerY];
    [path transformUsingAffineTransform:transform];
    
    return path;
}

static inline NSBezierPath *closeButtonPath(NSSize size) {
    NSRect bounds = {NSZeroPoint, size};
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat radius = 2.0, halfWidth = 0.5 * NSWidth(bounds) - 15.0, halfHeight = 0.5 * NSHeight(bounds) - 15.0;
    
    [path moveToPoint:NSMakePoint(radius, radius)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(halfWidth, 0.0) radius:radius startAngle:90.0 endAngle:-90.0 clockwise:YES];
    [path lineToPoint:NSMakePoint(radius, -radius)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(0.0, -halfHeight) radius:radius startAngle:360.0 endAngle:180.0 clockwise:YES];
    [path lineToPoint:NSMakePoint(-radius, -radius)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(-halfWidth, 0.0) radius:radius startAngle:270.0 endAngle:90.0 clockwise:YES];
    [path lineToPoint:NSMakePoint(-radius, radius)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(0.0, halfHeight) radius:radius startAngle:180.0 endAngle:0.0 clockwise:YES];
    [path closePath];
    
    NSAffineTransform *transform = [[[NSAffineTransform alloc] init] autorelease];
    [transform translateXBy:NSMidX(bounds) yBy:NSMidY(bounds)];
    [transform rotateByDegrees:45.0];
    [path transformUsingAffineTransform:transform];
    
    [path appendBezierPath:[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(bounds, 8.0, 8.0)]];
    
    return path;
}
