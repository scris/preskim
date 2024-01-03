//
//  SKMainWindowController_FullScreen.m
//  Skim
//
//  Created by Christiaan on 14/06/2019.
/*
 This software is Copyright (c) 2019
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

#import "SKMainWindowController_FullScreen.h"
#import "SKMainWindowController_UI.h"
#import "SKMainWindowController_Actions.h"
#import "SKSideWindow.h"
#import "SKFullScreenWindow.h"
#import "SKSideViewController.h"
#import "SKLeftSideViewController.h"
#import "SKRightSideViewController.h"
#import "SKApplication.h"
#import "SKTableView.h"
#import "SKSplitView.h"
#import "SKStringConstants.h"
#import "SKMainTouchBarController.h"
#import "SKMainDocument.h"
#import "SKSnapshotPDFView.h"
#import "SKSecondaryPDFView.h"
#import "SKOverviewView.h"
#import "SKTopBarView.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSResponder_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSScreen_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "SKStatusBar.h"
#import "SKAnimatedBorderlessWindow.h"

#define MAINWINDOWFRAME_KEY         @"windowFrame"
#define LEFTSIDEPANEWIDTH_KEY       @"leftSidePaneWidth"
#define RIGHTSIDEPANEWIDTH_KEY      @"rightSidePaneWidth"
#define HASHORIZONTALSCROLLER_KEY   @"hasHorizontalScroller"
#define HASVERTICALSCROLLER_KEY     @"hasVerticalScroller"
#define AUTOHIDESSCROLLERS_KEY      @"autoHidesScrollers"
#define DRAWSBACKGROUND_KEY         @"drawsBackground"

#define WINDOW_KEY @"window"

#define SKAutoHideToolbarInFullScreenKey @"SKAutoHideToolbarInFullScreen"
#define SKCollapseSidePanesInFullScreenKey @"SKCollapseSidePanesInFullScreen"
#define SKResizablePresentationKey @"SKResizablePresentation"

#define AppleMenuBarVisibleInFullscreenKey @"AppleMenuBarVisibleInFullscreen"

#define PRESENTATION_DURATION 0.5

static BOOL autoHideToolbarInFullScreen = NO;
static BOOL collapseSidePanesInFullScreen = NO;

static CGFloat fullScreenToolbarOffset = 0.0;

#if SDK_BEFORE_10_14
@interface PDFView (SKMojaveDeclarations)
@property (nonatomic, setter=enablePageShadows:) BOOL pageShadowsEnabled;
@end
#endif

@interface SKMainWindowController (SKFullScreenPrivate)
- (void)applyLeftSideWidth:(CGFloat)leftSideWidth rightSideWidth:(CGFloat)rightSideWidth;
@end

@implementation SKMainWindowController (FullScreen)

+ (void)defineFullScreenGlobalVariables {
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    autoHideToolbarInFullScreen = [sud boolForKey:SKAutoHideToolbarInFullScreenKey];
    collapseSidePanesInFullScreen = [sud boolForKey:SKCollapseSidePanesInFullScreenKey];
    
    fullScreenToolbarOffset = 0.0;
}

#pragma mark Side Windows

- (void)showSideWindow {
    if ([[[leftSideController.view window] firstResponder] isDescendantOf:leftSideController.view])
        [[leftSideController.view window] makeFirstResponder:nil];
    
    if (sideWindow == nil)
        sideWindow = [[SKSideWindow alloc] initWithView:leftSideController.view];
    
    if (mwcFlags.fullSizeContent) {
        [leftSideController.topBar setStyle:SKTopBarStylePresentation];
        [leftSideController setTopInset:0.0];
    } else {
        [leftSideController.topBar setDrawsBackground:NO];
    }

    mwcFlags.savedLeftSidePaneState = [self leftSidePaneState];
    [self setLeftSidePaneState:SKSidePaneStateThumbnail];
    [sideWindow makeFirstResponder:leftSideController.thumbnailTableView];
    [sideWindow attachToWindow:[self window]];
}

- (void)hideSideWindow {
    if ([[leftSideController.view window] isEqual:sideWindow]) {
        [sideWindow remove];
        
        if ([[sideWindow firstResponder] isDescendantOf:leftSideController.view])
            [sideWindow makeFirstResponder:nil];
        if (mwcFlags.fullSizeContent) {
            [leftSideController.topBar setStyle:SKTopBarStyleDefault];
            [leftSideController setTopInset:titleBarHeight];
        } else {
            [leftSideController.topBar setDrawsBackground:YES];
        }
        
        [leftSideController.view setFrame:[leftSideContentView bounds]];
        
        [leftSideContentView addSubview:leftSideController.view];
        [leftSideController.view activateConstraintsToSuperview];
        
        [self setLeftSidePaneState:mwcFlags.savedLeftSidePaneState];
        
        sideWindow = nil;
    }
}

#pragma mark Custom Full Screen Windows

- (BOOL)handleRightMouseDown:(NSEvent *)theEvent {
    if ([self interactionMode] == SKPresentationMode) {
        [self doGoToPreviousPage:nil];
        return YES;
    }
    return NO;
}

- (void)forceSubwindowsOnTop:(BOOL)flag {
    for (NSWindowController *wc in [[self document] windowControllers]) {
        if ([wc respondsToSelector:@selector(setForceOnTop:)] && wc != presentationPreview)
            [(id)wc setForceOnTop:flag];
    }
}

static inline BOOL insufficientScreenSize(NSValue *value) {
    NSSize size = [value sizeValue];
    return size.height < 100.0 && size.width < 100.0;
}

- (NSArray *)alternateScreensForScreen:(NSScreen *)screen {
    NSMutableDictionary *screens = [NSMutableDictionary dictionary];
    NSMutableArray *screenNumbers = [NSMutableArray array];
    NSNumber *screenNumber = nil;
    for (NSScreen *aScreen in [NSScreen screens]) {
        NSDictionary *deviceDescription = [aScreen deviceDescription];
        if ([deviceDescription objectForKey:NSDeviceIsScreen] == nil ||
            insufficientScreenSize([deviceDescription objectForKey:NSDeviceSize]))
            continue;
        NSNumber *aScreenNumber = [deviceDescription objectForKey:@"NSScreenNumber"];
        [screens setObject:aScreen forKey:aScreenNumber];
        CGDirectDisplayID displayID = (CGDirectDisplayID)[aScreenNumber unsignedIntValue];
        displayID = CGDisplayMirrorsDisplay(displayID);
        if (displayID == kCGNullDirectDisplay)
            [screenNumbers addObject:aScreenNumber];
        if ([aScreen isEqual:screen])
            screenNumber = displayID == kCGNullDirectDisplay ? aScreenNumber : [NSNumber numberWithUnsignedInt:displayID];
    }
    NSMutableArray *alternateScreens = [NSMutableArray array];
    for (NSNumber *aScreenNumber in screenNumbers) {
        if ([aScreenNumber isEqual:screenNumber] == NO)
            [alternateScreens addObject:[screens objectForKey:aScreenNumber]];
    }
    return alternateScreens;
}

- (void)enterPresentationMode {
    NSScrollView *scrollView = [pdfView scrollView];
    [savedNormalSetup setObject:[NSNumber numberWithBool:[scrollView hasHorizontalScroller]] forKey:HASHORIZONTALSCROLLER_KEY];
    [savedNormalSetup setObject:[NSNumber numberWithBool:[scrollView hasVerticalScroller]] forKey:HASVERTICALSCROLLER_KEY];
    [savedNormalSetup setObject:[NSNumber numberWithBool:[scrollView autohidesScrollers]] forKey:AUTOHIDESSCROLLERS_KEY];
    [savedNormalSetup setObject:[NSNumber numberWithBool:[scrollView drawsBackground]] forKey:DRAWSBACKGROUND_KEY];
    // Set up presentation mode
    [pdfView setNeedsRewind:YES];
    [pdfView setBackgroundColor:[NSColor clearColor]];
    [pdfView setAutoScales:YES];
    [pdfView setDisplayMode:kPDFDisplaySinglePage];
    [pdfView setDisplayBox:kPDFDisplayBoxCropBox];
    [pdfView setDisplaysPageBreaks:NO];
    if (@available(macOS 10.14, *))
        [pdfView enablePageShadows:NO];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setHasVerticalScroller:NO];
    [scrollView setDrawsBackground:NO];
    if (mwcFlags.fullSizeContent) {
        [scrollView setAutomaticallyAdjustsContentInsets:YES];
        [scrollView setContentInsets:NSEdgeInsetsZero];
    }
    
    [pdfView setCurrentSelection:nil];
    if ([pdfView hasReadingBar])
        [pdfView toggleReadingBar];
    
    if ([self presentationNotesDocument]) {
        PDFDocument *pdfDoc = [[self presentationNotesDocument] pdfDocument];
        NSInteger offset = [self presentationNotesOffset];
        NSUInteger pageIndex = MAX(0, MIN((NSInteger)[pdfDoc pageCount], (NSInteger)[[pdfView currentPage] pageIndex] + offset));
        if ([self presentationNotesDocument] == [self document]) {
            presentationPreview = [[SKSnapshotWindowController alloc] init];
            
            [presentationPreview setDelegate:self];
            
            NSScreen *screen = [[self window] screen];
            screen = [[self alternateScreensForScreen:screen] firstObject] ?: screen;
            
            [presentationPreview setPdfDocument:[pdfView document]
                              previewPageNumber:pageIndex
                                displayOnScreen:screen];
            
            [[self document] addWindowController:presentationPreview];
        } else {
            [[self presentationNotesDocument] setCurrentPage:[pdfDoc pageAtIndex:pageIndex]];
        }
        [self addPresentationNotesNavigation];
    }
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKResizablePresentationKey]) {
        [[self window] setStyleMask:[[self window] styleMask] | NSWindowStyleMaskResizable];
        [[self window] setHasShadow:YES];
    }
    
    // prevent sleep
    if (activity == nil)
        activity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiated | NSActivityIdleDisplaySleepDisabled | NSActivityIdleSystemSleepDisabled  reason:@"Presentation"];
}

- (void)exitPresentationMode {
    if (activity) {
        [[NSProcessInfo processInfo] endActivity:activity];
        activity = nil;
    }
    
    [self removePresentationNotesNavigation];
    
    if (@available(macOS 10.14, *))
        [pdfView enablePageShadows:YES];
    
    NSScrollView *scrollView = [pdfView scrollView];
    [scrollView setHasHorizontalScroller:[[savedNormalSetup objectForKey:HASHORIZONTALSCROLLER_KEY] boolValue]];
    [scrollView setHasVerticalScroller:[[savedNormalSetup objectForKey:HASVERTICALSCROLLER_KEY] boolValue]];
    [scrollView setAutohidesScrollers:[[savedNormalSetup objectForKey:AUTOHIDESSCROLLERS_KEY] boolValue]];
    [scrollView setDrawsBackground:[[savedNormalSetup objectForKey:DRAWSBACKGROUND_KEY] boolValue]];
    if (mwcFlags.fullSizeContent && [[findController view] window]) {
        [scrollView setAutomaticallyAdjustsContentInsets:NO];
        [scrollView setContentInsets:NSEdgeInsetsMake(NSHeight([[findController view] frame]) + titleBarHeight, 0.0, 0.0, 0.0)];
    }
}

- (void)addPresentationWindowOnScreen:(NSScreen *)screen {
    if ([[mainWindow firstResponder] isDescendantOf:pdfSplitView])
        [mainWindow makeFirstResponder:nil];
    
    NSWindow *fullScreenWindow = [[SKFullScreenWindow alloc] initWithScreen:screen ?: [mainWindow screen]];
    
    [mainWindow setDelegate:nil];
    [self setWindow:fullScreenWindow];
    [fullScreenWindow setAlphaValue:0.0];
    [fullScreenWindow orderFront:nil];
    [fullScreenWindow makeKeyWindow];
    [NSApp updatePresentationOptionsForWindow:fullScreenWindow];
    [mainWindow setAnimationBehavior:NSWindowAnimationBehaviorNone];
    [mainWindow orderOut:nil];
    [mainWindow setAnimationBehavior:NSWindowAnimationBehaviorDefault];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKUseNormalLevelForPresentationKey])
        [fullScreenWindow setLevel:NSNormalWindowLevel];
    [fullScreenWindow orderFront:nil];
    [NSApp addWindowsItem:fullScreenWindow title:[self windowTitleForDocumentDisplayName:[[self document] displayName]] filename:NO];
}

- (void)removePresentationWindow {
    NSWindow *fullScreenWindow = [self window];
    
    [self setWindow:mainWindow];
    [mainWindow setAlphaValue:0.0];
    [mainWindow setAnimationBehavior:NSWindowAnimationBehaviorNone];
    if (NSPointInRect(SKCenterPoint([mainWindow frame]), [[fullScreenWindow screen] frame])) {
        NSWindowCollectionBehavior collectionBehavior = [mainWindow collectionBehavior];
        // trick to make sure the main window shows up in the same space as the fullscreen window
        [fullScreenWindow addChildWindow:mainWindow ordered:NSWindowBelow];
        [fullScreenWindow removeChildWindow:mainWindow];
        // these can change due to the child window trick
        [mainWindow setLevel:NSNormalWindowLevel];
        [mainWindow setCollectionBehavior:collectionBehavior];
    } else {
        [mainWindow makeKeyAndOrderFront:nil];
    }
    [mainWindow display];
    [mainWindow makeFirstResponder:[self hasOverview] ? overviewView : pdfView];
    [mainWindow recalculateKeyViewLoop];
    [mainWindow setDelegate:self];
    [mainWindow makeKeyWindow];
    [NSApp updatePresentationOptionsForWindow:mainWindow];
    [mainWindow setAnimationBehavior:NSWindowAnimationBehaviorDefault];
    [NSApp removeWindowsItem:fullScreenWindow];
    [fullScreenWindow orderOut:nil];
}

- (void)showStaticContentForWindow:(NSWindow *)window {
    NSRect frame = [window frame];
    CGImageRef cgImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, (CGWindowID)[window windowNumber], kCGWindowImageBoundsIgnoreFraming);
    if (([window styleMask] & NSWindowStyleMaskFullScreen) != 0 && autoHideToolbarInFullScreen == NO && [[window toolbar] isVisible]) {
        NSWindow *tbWindow = nil;
        for (tbWindow in [window childWindows])
            if ([NSStringFromClass([tbWindow class]) containsString:@"Toolbar"])
                break;
        if (tbWindow) {
            CGImageRef tbCgImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, (CGWindowID)[tbWindow windowNumber], kCGWindowImageBoundsIgnoreFraming);
            NSRect tbFrame = [tbWindow frame];
            size_t width = CGImageGetWidth(cgImage), height = CGImageGetHeight(cgImage);
            CGFloat sx = width / NSWidth(frame), sy = height / NSHeight(frame);
            CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, 4 * width, CGImageGetColorSpace(cgImage), kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
            CGContextDrawImage(ctx, CGRectMake(0.0, 0.0, width, height), cgImage);
            CGContextDrawImage(ctx, CGRectMake(sx * (NSMinX(tbFrame) - NSMinX(frame)), sy * (NSMinY(tbFrame) - NSMinY(frame)), sx * NSWidth(tbFrame), sy * NSHeight(tbFrame)), tbCgImage);
            CGImageRelease(tbCgImage);
            CGImageRelease(cgImage);
            cgImage = CGBitmapContextCreateImage(ctx);
            CGContextRelease(ctx);
        }
    }
    NSImage *image = [[NSImage alloc] initWithCGImage:cgImage size:frame.size];
    CGImageRelease(cgImage);
    if (animationWindow == nil)
        animationWindow = [[SKAnimatedBorderlessWindow alloc] initWithContentRect:[window frame]];
    else
        [animationWindow setFrame:[window frame] display:NO];
    [(SKAnimatedBorderlessWindow *)animationWindow setBackgroundImage:image];
    [animationWindow setHasShadow:[window hasShadow]];
    [animationWindow setLevel:[window level]];
    [animationWindow orderWindow:NSWindowAbove relativeTo:window];
    [window setAlphaValue:0.0];
}

#pragma mark API

- (void)enterFullscreen {
    if ([self canEnterFullscreen]) {
        if ([self interactionMode] == SKPresentationMode)
            [self exitPresentation];
        [[self window] toggleFullScreen:nil];
    }
}

- (void)exitFullscreen {
    if ([self canExitFullscreen])
        [[self window] toggleFullScreen:nil];
}

- (void)enterPresentation {
    if ([self canEnterPresentation] == NO)
        return;
    
    if ([self interactionMode] == SKFullScreenMode) {
        mwcFlags.wantsPresentation = 1;
        [[self window] toggleFullScreen:nil];
        return;
    }
    
    if ([[[self window] tabbedWindows] count] > 1)
        [[self window] moveTabToNewWindow:nil];
    
    PDFPage *page = [[self pdfView] currentPage];
    
    // remember normal setup to return to, we must do this before changing the interactionMode
    [savedNormalSetup setDictionary:[self currentPDFSettings]];
    
    mwcFlags.isSwitchingFullScreen = 1;
    
    interactionMode = SKPresentationMode;
    
    NSScreen *screen = [mainWindow screen];
    if ([self presentationNotesDocument] && [self presentationNotesDocument] != [self document]) {
        NSArray *screens = [self alternateScreensForScreen:[[[self presentationNotesDocument] mainWindow] screen]];
        if ([screens count] > 0 && [screens containsObject:[screen primaryScreen]] == NO)
            screen = [screens firstObject];
    }
    
    [self showStaticContentForWindow:mainWindow];
    
    [self addPresentationWindowOnScreen:screen];
    
    if ([self hasOverview])
        [self hideOverviewAnimating:NO];
    
    [self enterPresentationMode];
    
    NSWindow *fullScreenWindow = [self window];
    
    [[fullScreenWindow contentView] addSubview:pdfView];
    [pdfView activateConstraintsToSuperview];
    [pdfView layoutDocumentView];
    [pdfView requiresDisplay];
    [fullScreenWindow makeFirstResponder:pdfView];
    [fullScreenWindow recalculateKeyViewLoop];
    [fullScreenWindow setDelegate:self];

    if ([[pdfView currentPage] isEqual:page] == NO)
        [pdfView goToPage:page];
    
    mwcFlags.isSwitchingFullScreen = 0;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [context setDuration:PRESENTATION_DURATION];
            [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [[fullScreenWindow animator] setAlphaValue:1.0];
            if (NSContainsRect([fullScreenWindow frame], [animationWindow frame]) == NO)
                [[animationWindow animator] setAlphaValue:0.0];
            [[[presentationPreview window] animator] setAlphaValue:1.0];
        }
        completionHandler:^{
            [animationWindow orderOut:nil];
            animationWindow = nil;
        }];
    
    [pdfView setInteractionMode:SKPresentationMode];
    [touchBarController interactionModeChanged];
}

- (void)exitPresentation {
    if ([self canExitPresentation] == NO)
        return;
    
    NSColor *backgroundColor = [PDFView defaultBackgroundColor];
    PDFPage *page = [[self pdfView] currentPage];
    
    mwcFlags.isSwitchingFullScreen = 1;
    
    if ([self leftSidePaneIsOpen])
        [self hideSideWindow];
    
    if ([presentationNotes count]) {
        PDFDocument *pdfDoc = [self pdfDocument];
        for (PDFAnnotation *annotation in [presentationNotes copy])
            [pdfDoc removeAnnotation:annotation];
    }
    presentationNotes = nil;
    presentationUndoManager = nil;
    
    // do this first, otherwise the navigation window may be covered by fadeWindow and then reveiled again, which looks odd
    [pdfView setInteractionMode:SKNormalMode];
    
    NSWindow *fullScreenWindow = [self window];
    
    [self showStaticContentForWindow:fullScreenWindow];
    
    while ([[fullScreenWindow childWindows] count] > 0) {
        NSWindow *childWindow = [[fullScreenWindow childWindows] lastObject];
        [fullScreenWindow removeChildWindow:childWindow];
        [childWindow orderOut:nil];
    }
    
    [fullScreenWindow setDelegate:nil];
    [fullScreenWindow makeFirstResponder:nil];
    
    interactionMode = SKNormalMode;
    
    // this should be done before exitPresentationMode to get a smooth transition
    [pdfContentView addSubview:pdfView positioned:NSWindowBelow relativeTo:nil];
    [pdfView activateConstraintsToSuperview];
    [pdfView setBackgroundColor:backgroundColor];
    [secondaryPdfView setBackgroundColor:backgroundColor];
    if ([self hasOverview])
        [overviewContentView removeFromSuperview];
    
    [self exitPresentationMode];
    [self applyPDFSettings:savedNormalSetup rewind:YES];
    [savedNormalSetup removeAllObjects];
    
    [pdfView layoutDocumentView];
    [pdfView requiresDisplay];
    
    if ([[[self pdfView] currentPage] isEqual:page] == NO)
        [[self pdfView] goToCurrentPage:page];
    
    mwcFlags.isSwitchingFullScreen = 0;
    
    [self forceSubwindowsOnTop:NO];
    
    [touchBarController interactionModeChanged];
    
    [self removePresentationWindow];
    
    [animationWindow setLevel:NSPopUpMenuWindowLevel];
    
    BOOL covered = NSContainsRect([animationWindow frame], [mainWindow frame]);
    if (covered)
        [mainWindow setAlphaValue:1.0];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [context setDuration:PRESENTATION_DURATION];
            [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            if (covered == NO)
                [[mainWindow animator] setAlphaValue:1.0];
            [[animationWindow animator] setAlphaValue:0.0];
            [[[presentationPreview window] animator] setAlphaValue:0.0];
        }
        completionHandler:^{
            [animationWindow orderOut:nil];
            animationWindow = nil;
            if (presentationPreview) {
                [[presentationPreview window] setAnimationBehavior:NSWindowAnimationBehaviorNone];
                [presentationPreview close];
            }
        }];
    
    // the page number may have changed
    [self synchronizeWindowTitleWithDocumentName];
}

- (BOOL)canEnterFullscreen {
    return mwcFlags.isSwitchingFullScreen == 0 && ([self interactionMode] == SKNormalMode || [self interactionMode] == SKPresentationMode);
}

- (BOOL)canEnterPresentation {
    return mwcFlags.isSwitchingFullScreen == 0 && [[self pdfDocument] isLocked] == NO && [self interactionMode] != SKPresentationMode;
}

- (BOOL)canExitFullscreen {
    return mwcFlags.isSwitchingFullScreen == 0 && [self interactionMode] == SKFullScreenMode;
}

- (BOOL)canExitPresentation {
    return mwcFlags.isSwitchingFullScreen == 0 && [self interactionMode] == SKPresentationMode;
}

#pragma mark NSWindowDelegate Full Screen Methods

static inline CGFloat fullScreenOffset(NSWindow *window) {
    CGFloat offset = 17.0;
    if (autoHideToolbarInFullScreen)
        offset = NSHeight([window frame]) - NSHeight([window contentLayoutRect]);
    else if ([[window toolbar] isVisible] == NO)
        offset = NSHeight([NSWindow frameRectForContentRect:NSZeroRect styleMask:NSWindowStyleMaskTitled]);
    else if (fullScreenToolbarOffset > 0.0)
        offset = fullScreenToolbarOffset;
    else if (@available(macOS 11.0, *))
        offset = 16.0;
    return offset;
}

static inline CGFloat toolbarViewOffset(NSWindow *window) {
    NSToolbar *toolbar = [window toolbar];
    NSView *view = nil;
    if ([toolbar displayMode] == NSToolbarDisplayModeLabelOnly) {
        @try { view = [toolbar valueForKey:@"toolbarView"]; }
        @catch (id e) {}
    } else {
        for (NSToolbarItem *item in [toolbar visibleItems])
            if ((view = [item view]))
                break;
    }
    if (view)
        return NSMaxY([view convertRectToScreen:[view frame]]) - NSMaxY([[view window] frame]);
    return 0.0;
}

static inline void setAlphaValueOfTitleBarControls(NSWindow *window, CGFloat alpha, BOOL animate) {
    for (NSView *view in [[[window standardWindowButton:NSWindowCloseButton] superview] subviews])
        if ([view isKindOfClass:[NSControl class]])
            [(animate ? (id)[view animator] : (id)view) setAlphaValue:alpha];
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification {
    mwcFlags.isSwitchingFullScreen = 1;
    interactionMode = SKFullScreenMode;
    if ([[pdfView document] isLocked] == NO || [savedNormalSetup count] == 0)
        [savedNormalSetup setDictionary:[self currentPDFSettings]];
    NSString *frameString = NSStringFromRect([[self window] frame]);
    [savedNormalSetup setObject:frameString forKey:MAINWINDOWFRAME_KEY];
}

- (NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions {
    if (autoHideToolbarInFullScreen)
        return proposedOptions | NSApplicationPresentationAutoHideToolbar;
    return proposedOptions;
}

- (NSArray *)customWindowsToEnterFullScreenForWindow:(NSWindow *)window {
    NSArray *windows = [[[self document] windowControllers] valueForKey:WINDOW_KEY];
    if ([[NSWorkspace sharedWorkspace] accessibilityDisplayShouldReduceMotion]) {
        animationWindow = [[SKAnimatedBorderlessWindow alloc] initWithContentRect:[window frame]];
        windows = [windows arrayByAddingObject:animationWindow];
    }
    return windows;
}

- (void)window:(NSWindow *)window startCustomAnimationToEnterFullScreenWithDuration:(NSTimeInterval)duration {
    if (fullScreenToolbarOffset <= 0.0 && autoHideToolbarInFullScreen == NO && [[mainWindow toolbar] isVisible])
        fullScreenToolbarOffset = toolbarViewOffset(mainWindow);
    NSRect frame = SKShrinkRect([[window screen] frame], -fullScreenOffset(window), NSMaxYEdge);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:AppleMenuBarVisibleInFullscreenKey])
        frame.size.height -= [[NSApp mainMenu] menuBarHeight] ?: 24.0;
    if (animationWindow != nil) {
        [self showStaticContentForWindow:window];
        [(SKMainWindow *)window setDisableConstrainedFrame:YES];
        [window setFrame:frame display:YES];
        [window orderWindow:NSWindowAbove relativeTo:animationWindow];
        setAlphaValueOfTitleBarControls(window, 0.0, NO);
        [(SKMainWindow *)window setDisableConstrainedFrame:NO];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                [context setDuration:duration];
                [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
                [[window animator] setAlphaValue:1.0];
            }
            completionHandler:^{
                [animationWindow orderOut:nil];
                animationWindow = nil;
            }];
    } else {
        [(SKMainWindow *)window setDisableConstrainedFrame:YES];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                [context setDuration:duration - 0.02];
                if (@available(macOS 12.0, *))
                    [[(SKMainWindow *)window animator] setWindowFrame:frame];
                else
                    [[window animator] setFrame:frame display:NO];
                setAlphaValueOfTitleBarControls(window, 0.0, YES);
            }
            completionHandler:^{
                [(SKMainWindow *)window setDisableConstrainedFrame:NO];
            }];
    }
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification {
    if (fullScreenToolbarOffset < 0.0 && autoHideToolbarInFullScreen == NO && [[mainWindow toolbar] isVisible]) {
        CGFloat toolbarItemOffset = toolbarViewOffset(mainWindow);
        if (toolbarItemOffset < 0.0)
            // save the offset for the next time, we may guess it wrong as it varies between OS versions
            fullScreenToolbarOffset = toolbarItemOffset - fullScreenToolbarOffset;
    }
    NSColor *backgroundColor = [PDFView defaultFullScreenBackgroundColor];
    NSDictionary *fullScreenSetup = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultFullScreenPDFDisplaySettingsKey];
    [pdfView setInteractionMode:SKFullScreenMode];
    [touchBarController interactionModeChanged];
    [pdfView setBackgroundColor:backgroundColor];
    [secondaryPdfView setBackgroundColor:backgroundColor];
    if ([[pdfView document] isLocked] == NO && [fullScreenSetup count])
        [self applyPDFSettings:fullScreenSetup rewind:YES];
    if (collapseSidePanesInFullScreen) {
        [savedNormalSetup setObject:[NSNumber numberWithDouble:[self leftSideWidth]] forKey:LEFTSIDEPANEWIDTH_KEY];
        [savedNormalSetup setObject:[NSNumber numberWithDouble:[self rightSideWidth]] forKey:RIGHTSIDEPANEWIDTH_KEY];
        [self applyLeftSideWidth:0.0 rightSideWidth:0.0];
    }
    [self forceSubwindowsOnTop:YES];
    mwcFlags.isSwitchingFullScreen = 0;
}

- (void)windowDidFailToEnterFullScreen:(NSWindow *)window {
    if ([[pdfView document] isLocked] == NO || [savedNormalSetup count] == 1)
        [savedNormalSetup removeAllObjects];
    animationWindow = nil;
    interactionMode = SKNormalMode;
    mwcFlags.isSwitchingFullScreen = 0;
}

- (void)windowWillExitFullScreen:(NSNotification *)notification {
    mwcFlags.isSwitchingFullScreen = 1;
    interactionMode = SKNormalMode;
    NSColor *backgroundColor = [PDFView defaultBackgroundColor];
    [pdfView setInteractionMode:SKNormalMode];
    [pdfView setBackgroundColor:backgroundColor];
    [secondaryPdfView setBackgroundColor:backgroundColor];
    if ([[[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultFullScreenPDFDisplaySettingsKey] count])
        [self applyPDFSettings:savedNormalSetup rewind:YES];
    NSNumber *leftWidth = [savedNormalSetup objectForKey:LEFTSIDEPANEWIDTH_KEY];
    NSNumber *rightWidth = [savedNormalSetup objectForKey:RIGHTSIDEPANEWIDTH_KEY];
    if (leftWidth && rightWidth)
        [self applyLeftSideWidth:[leftWidth doubleValue] rightSideWidth:[rightWidth doubleValue]];
    [self forceSubwindowsOnTop:NO];
}

- (NSArray *)customWindowsToExitFullScreenForWindow:(NSWindow *)window {
    NSArray *windows = [[[self document] windowControllers] valueForKey:WINDOW_KEY];
    if ([[NSWorkspace sharedWorkspace] accessibilityDisplayShouldReduceMotion]) {
        animationWindow = [[SKAnimatedBorderlessWindow alloc] initWithContentRect:[window frame]];
        windows = [windows arrayByAddingObject:animationWindow];
    }
    return windows;
}

- (void)window:(NSWindow *)window startCustomAnimationToExitFullScreenWithDuration:(NSTimeInterval)duration {
    NSRect frame = NSRectFromString([savedNormalSetup objectForKey:MAINWINDOWFRAME_KEY]);
    if (animationWindow != nil) {
        [self showStaticContentForWindow:window];
        [window setStyleMask:[window styleMask] & ~NSWindowStyleMaskFullScreen];
        setAlphaValueOfTitleBarControls(window, 1.0, NO);
        [window setFrame:frame display:YES];
        [window setLevel:NSNormalWindowLevel];
        BOOL covered = NSContainsRect([animationWindow frame], [window frame]);
        if (covered)
            [window setAlphaValue:1.0];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                [context setDuration:duration];
                [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
                if (covered == NO)
                    [[window animator] setAlphaValue:1.0];
                [[animationWindow animator] setAlphaValue:0.0];
            }
            completionHandler:^{
                [animationWindow orderOut:nil];
                animationWindow = nil;
            }];
    } else {
        NSRect startFrame = [window frame];
        startFrame.size.height += fullScreenOffset(window);
        [window setStyleMask:[window styleMask] & ~NSWindowStyleMaskFullScreen];
        setAlphaValueOfTitleBarControls(window, 0.0, NO);
        [(SKMainWindow *)window setDisableConstrainedFrame:YES];
        [window setFrame:startFrame display:YES];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                [context setDuration:duration];
                [[window animator] setFrame:frame display:YES];
                setAlphaValueOfTitleBarControls(window, 1.0, YES);
            }
            completionHandler:^{
                [(SKMainWindow *)window setDisableConstrainedFrame:NO];
                [window setLevel:NSNormalWindowLevel];
            }];
    }
}

- (void)windowDidExitFullScreen:(NSNotification *)notification {
    NSString *frameString = [savedNormalSetup objectForKey:MAINWINDOWFRAME_KEY];
    if (frameString)
        [[self window] setFrame:NSRectFromString(frameString) display:YES];
    if ([[pdfView document] isLocked] == NO || [savedNormalSetup count] == 1)
        [savedNormalSetup removeAllObjects];
    mwcFlags.isSwitchingFullScreen = 0;
    if (mwcFlags.wantsPresentation) {
        mwcFlags.wantsPresentation = 0;
        [self enterPresentation];
    } else {
        [touchBarController interactionModeChanged];
    }
}

- (void)windowDidFailToExitFullScreen:(NSWindow *)window {
    if (interactionMode == SKNormalMode) {
        interactionMode = SKFullScreenMode;
        NSColor *backgroundColor = [PDFView defaultFullScreenBackgroundColor];
        NSDictionary *fullScreenSetup = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultFullScreenPDFDisplaySettingsKey];
        [pdfView setInteractionMode:SKFullScreenMode];
        [pdfView setBackgroundColor:backgroundColor];
        [secondaryPdfView setBackgroundColor:backgroundColor];
        if ([[pdfView document] isLocked] == NO)
            [self applyPDFSettings:fullScreenSetup rewind:YES];
        [self applyLeftSideWidth:0.0 rightSideWidth:0.0];
        [self forceSubwindowsOnTop:YES];
    }
    animationWindow = nil;
    mwcFlags.isSwitchingFullScreen = 0;
    mwcFlags.wantsPresentation = 0;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (NO == [super respondsToSelector:aSelector])
        return NO;
    else if ((aSelector == @selector(customWindowsToEnterFullScreenForWindow:) ||
                aSelector == @selector(window:startCustomAnimationToEnterFullScreenWithDuration:) ||
                aSelector == @selector(customWindowsToExitFullScreenForWindow:) ||
                aSelector == @selector(window:startCustomAnimationToExitFullScreenWithDuration:)) &&
               [[[self document] windowControllers] count] == 1)
        return NO;
    else
        return YES;
}

#pragma mark Presentation Notes Navigation

- (NSView *)presentationNotesView {
    if ([[self presentationNotesDocument] isEqual:[self document]])
        return [presentationPreview pdfView];
    else
        return [(SKMainDocument *)[self presentationNotesDocument] pdfView];
}

- (void)addPresentationNotesNavigation {
    [self removePresentationNotesNavigation];
    NSView *notesView = [self presentationNotesView];
    if (notesView) {
        presentationNotesTrackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect owner:self userInfo:nil];
        [notesView addTrackingArea:presentationNotesTrackingArea];
    }
}

- (void)removePresentationNotesNavigation {
    if (presentationNotesTrackingArea) {
        [[self presentationNotesView] removeTrackingArea:presentationNotesTrackingArea];
        presentationNotesTrackingArea = nil;
    }
    if (presentationNotesButton) {
        [presentationNotesButton removeFromSuperview];
        presentationNotesButton = nil;
    }
}

- (void)mouseEntered:(NSEvent *)event {
    if ([event trackingArea] == presentationNotesTrackingArea) {
        NSView *notesView = [self presentationNotesView];
        if (presentationNotesButton == nil) {
            presentationNotesButton = [[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 30.0, 50.0)];
            [presentationNotesButton setButtonType:NSMomentaryChangeButton];
            [presentationNotesButton setBordered:NO];
            [presentationNotesButton setImage:[NSImage imageWithSize:NSMakeSize(30.0, 50.0) flipped:NO drawingHandler:^(NSRect rect){
                NSBezierPath *path = [NSBezierPath bezierPath];
                [path moveToPoint:NSMakePoint(5.0, 45.0)];
                [path lineToPoint:NSMakePoint(25.0, 25.0)];
                [path lineToPoint:NSMakePoint(5.0, 5.0)];
                [path setLineCapStyle:NSRoundLineCapStyle];
                [path setLineWidth:10.0];
                [[NSColor whiteColor] setStroke];
                [path stroke];
                [path setLineWidth:5.0];
                [[NSColor blackColor] setStroke];
                [path stroke];
                return YES;
            }]];
            [presentationNotesButton setTarget:self];
            [presentationNotesButton setAction:@selector(doGoToNextPage:)];
            [presentationNotesButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
            [[presentationNotesButton cell] setAccessibilityLabel:NSLocalizedString(@"Next", @"")];
        }
        [presentationNotesButton setAlphaValue:0.0];
        [presentationNotesButton setFrame:SKRectFromCenterAndSize(SKCenterPoint([notesView frame]), [presentationNotesButton frame].size)];
        [notesView addSubview:presentationNotesButton positioned:NSWindowAbove relativeTo:nil];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [[presentationNotesButton animator] setAlphaValue:1.0];
        } completionHandler:^{}];
        NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor(notesView), NSAccessibilityLayoutChangedNotification, [NSDictionary dictionaryWithObjectsAndKeys:NSAccessibilityUnignoredChildrenForOnlyChild(presentationNotesButton), NSAccessibilityUIElementsKey, nil]);
    } else if ([[SKMainWindowController superclass] instancesRespondToSelector:_cmd]) {
        [super mouseEntered:event];
    }
}

- (void)mouseExited:(NSEvent *)event {
    if ([event trackingArea] == presentationNotesTrackingArea && presentationNotesButton) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
            [[presentationNotesButton animator] setAlphaValue:0.0];
        } completionHandler:^{
            [presentationNotesButton removeFromSuperview];
        }];
        NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor([self presentationNotesView]), NSAccessibilityLayoutChangedNotification, nil);
    } else if ([[SKMainWindowController superclass] instancesRespondToSelector:_cmd]) {
        [super mouseExited:event];
    }
}

@end
