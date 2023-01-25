//
//  SKPDFView.m
//  Skim
//
//  Created by Michael McCracken on 12/6/06.
/*
 This software is Copyright (c) 2006-2023
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "SKPDFView.h"
#import "SKNavigationWindow.h"
#import "SKImageToolTipWindow.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "PDFAnnotationMarkup_SKExtensions.h"
#import "PDFAnnotationInk_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSCursor_SKExtensions.h"
#import "SKApplication.h"
#import "SKStringConstants.h"
#import "NSUserDefaultsController_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "SKReadingBar.h"
#import "SKTransitionController.h"
#import "SKTextNoteEditor.h"
#import "SKSyncDot.h"
#import "SKLineInspector.h"
#import "SKLineWell.h"
#import "SKTypeSelectHelper.h"
#import <CoreServices/CoreServices.h>
#import "NSDocument_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "NSBezierPath_SKExtensions.h"
#import "PDFDocument_SKExtensions.h"
#import "PDFDocumentView_SKExtensions.h"
#import "NSResponder_SKExtensions.h"
#import "NSEvent_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSArray_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "NSPointerArray_SKExtensions.h"
#import "NSShadow_SKExtensions.h"
#import "PDFAnnotationLine_SKExtensions.h"
#import "NSScroller_SKExtensions.h"
#import "SKColorMenuView.h"
#import "SKMainWindowController_Actions.h"
#import "NSObject_SKExtensions.h"
#import "SKLoupeController.h"

#define ANNOTATION_MODE_COUNT 9
#define TOOL_MODE_COUNT 5

#define IS_MARKUP(noteType) (noteType == SKHighlightNote || noteType == SKUnderlineNote || noteType == SKStrikeOutNote)

#define READINGBAR_RESIZE_EDGE_HEIGHT 3.0
#define NAVIGATION_BOTTOM_EDGE_HEIGHT 5.0

#define TEXT_SELECT_MARGIN_SIZE ((NSSize){80.0, 100.0})

#define TOOLTIP_OFFSET_FRACTION 0.3

#define DEFAULT_SNAPSHOT_HEIGHT 200.0

#define MIN_NOTE_SIZE 8.0

#define HANDLE_SIZE 4.0

#define DEFAULT_MAGNIFICATION 2.5
#define SMALL_MAGNIFICATION   1.5
#define LARGE_MAGNIFICATION   4.0

#define AUTO_HIDE_DELAY 3.0
#define SHOW_NAV_DELAY  0.25

#define DEFAULT_PACER_SPEED 10.0
#define PACER_LINE_HEIGHT 20.0

NSString *SKPDFViewDisplaysAsBookChangedNotification = @"SKPDFViewDisplaysAsBookChangedNotification";
NSString *SKPDFViewDisplaysPageBreaksChangedNotification = @"SKPDFViewDisplaysPageBreaksChangedNotification";
NSString *SKPDFViewDisplaysHorizontallyChangedNotification = @"SKPDFViewDisplaysHorizontallyChangedNotification";
NSString *SKPDFViewDisplaysRTLChangedNotification = @"SKPDFViewDisplaysRTLChangedNotification";
NSString *SKPDFViewAutoScalesChangedNotification = @"SKPDFViewAutoScalesChangedNotification";
NSString *SKPDFViewToolModeChangedNotification = @"SKPDFViewToolModeChangedNotification";
NSString *SKPDFViewTemporaryToolModeChangedNotification = @"SKPDFViewTemporaryToolModeChangedNotification";
NSString *SKPDFViewAnnotationModeChangedNotification = @"SKPDFViewAnnotationModeChangedNotification";
NSString *SKPDFViewCurrentAnnotationChangedNotification = @"SKPDFViewCurrentAnnotationChangedNotification";
NSString *SKPDFViewDidAddAnnotationNotification = @"SKPDFViewDidAddAnnotationNotification";
NSString *SKPDFViewDidRemoveAnnotationNotification = @"SKPDFViewDidRemoveAnnotationNotification";
NSString *SKPDFViewDidMoveAnnotationNotification = @"SKPDFViewDidMoveAnnotationNotification";
NSString *SKPDFViewReadingBarDidChangeNotification = @"SKPDFViewReadingBarDidChangeNotification";
NSString *SKPDFViewSelectionChangedNotification = @"SKPDFViewSelectionChangedNotification";
NSString *SKPDFViewMagnificationChangedNotification = @"SKPDFViewMagnificationChangedNotification";
NSString *SKPDFViewPacerStartedOrStoppedNotification = @"SKPDFViewPacerStartedOrStoppedNotification";

NSString *SKPDFViewAnnotationKey = @"annotation";
NSString *SKPDFViewPageKey = @"page";
NSString *SKPDFViewOldPageKey = @"oldPage";
NSString *SKPDFViewNewPageKey = @"newPage";

#define SKMoveReadingBarModifiersKey @"SKMoveReadingBarModifiers"
#define SKResizeReadingBarModifiersKey @"SKResizeReadingBarModifiers"
#define SKDefaultFreeTextNoteContentsKey @"SKDefaultFreeTextNoteContents"
#define SKDefaultAnchoredNoteContentsKey @"SKDefaultAnchoredNoteContents"
#define SKUseToolModeCursorsKey @"SKUseToolModeCursors"
#define SKMagnifyWithMousePressedKey @"SKMagnifyWithMousePressed"
#define SKPacerSpeedKey @"SKPacerSpeed"
#define SKUseArrowCursorInPresentationKey @"SKUseArrowCursorInPresentation"
#define SKLaserPointerColorKey @"SKLaserPointerColor"

#define SKAnnotationKey @"SKAnnotation"

static char SKPDFViewDefaultsObservationContext;

static NSUInteger moveReadingBarModifiers = NSAlternateKeyMask;
static NSUInteger resizeReadingBarModifiers = NSAlternateKeyMask | NSShiftKeyMask;

static BOOL useToolModeCursors = NO;

static inline PDFAreaOfInterest SKAreaOfInterestForResizeHandle(SKRectEdges mask, PDFPage *page);

static inline NSSize SKFitTextNoteSize(NSString *string, NSFont *font, CGFloat width);

enum {
    SKNavigationNone,
    SKNavigationBottom,
    SKNavigationEverywhere,
};

enum {
    SKLayerNone,
    SKLayerUse,
    SKLayerAdd,
    SKLayerRemove
};

enum {
    SKLayerTypeNote,
    SKLayerTypeRect
};

@protocol SKLayerDelegate <NSObject>
- (void)drawLayerController:(SKLayerController *)controller inContext:(CGContextRef)context;
@end

// this class is a proxy for the layer delegate
// to avoid overriding NSView's CALayerDelegate methods
@interface SKLayerController : NSObject <CALayerDelegate> {
    CALayer *layer;
    id<SKLayerDelegate> delegate;
    NSRect rect;
    NSInteger type;
}
@property (nonatomic, retain) CALayer *layer;
@property (nonatomic, assign) id<SKLayerDelegate> delegate;
@property (nonatomic) NSRect rect;
@property (nonatomic) NSInteger type;
@end

#pragma mark -

#if SDK_BEFORE(10_12)
@interface PDFView (SKSierraDeclarations)
- (void)drawPage:(PDFPage *)page toContext:(CGContextRef)context;
@end
#endif

#if SDK_BEFORE(10_13)
typedef NS_ENUM(NSInteger, PDFDisplayDirection) {
    kPDFDisplayDirectionVertical = 0,
    kPDFDisplayDirectionHorizontal = 1,
};
@interface PDFView (SKHighSierraDeclarations)
@property (nonatomic) PDFDisplayDirection displayDirection;
@property (nonatomic) BOOL displaysRTL;
@end
#endif

#pragma mark -

@interface SKPDFView () <SKReadingBarDelegate, SKLayerDelegate>
@property (retain) SKReadingBar *readingBar;
@property (retain) SKSyncDot *syncDot;
@end

@interface SKPDFView (Private)

- (void)editTextNoteWithEvent:(NSEvent *)theEvent;
- (BOOL)isEditingAnnotation:(PDFAnnotation *)annotation;

- (void)beginNewUndoGroupIfNeeded;

- (void)enableNavigation;
- (void)disableNavigation;

- (void)stopPacer;
- (void)updatePacer;

- (void)doAutoHide;
- (void)showNavWindow;

- (void)setNeedsDisplayForReadingBarBounds:(NSRect)rect onPage:(PDFPage *)page;

- (void)doMoveCurrentAnnotationForKey:(unichar)eventChar byAmount:(CGFloat)delta;
- (void)doResizeCurrentAnnotationForKey:(unichar)eventChar byAmount:(CGFloat)delta;
- (void)doAutoSizeActiveNoteIgnoringWidth:(BOOL)ignoreWidth;
- (void)doMoveReadingBarForKey:(unichar)eventChar;
- (void)doResizeReadingBarForKey:(unichar)eventChar;

- (BOOL)doSelectAnnotationWithEvent:(NSEvent *)theEvent;
- (void)doDragAnnotationWithEvent:(NSEvent *)theEvent;
- (void)doClickLinkWithEvent:(NSEvent *)theEvent;
- (void)doSelectSnapshotWithEvent:(NSEvent *)theEvent;
- (void)doMagnifyWithEvent:(NSEvent *)theEvent;
- (void)doDrawFreehandNoteWithEvent:(NSEvent *)theEvent;
- (void)doEraseAnnotationsWithEvent:(NSEvent *)theEvent;
- (void)doSelectWithEvent:(NSEvent *)theEvent;
- (void)doDragReadingBarWithEvent:(NSEvent *)theEvent;
- (void)doResizeReadingBarWithEvent:(NSEvent *)theEvent;
- (void)doMarqueeZoomWithEvent:(NSEvent *)theEvent;
- (BOOL)doDragMouseWithEvent:(NSEvent *)theEvent;
- (BOOL)doDragTextWithEvent:(NSEvent *)theEvent;
- (void)doDragWindowWithEvent:(NSEvent *)theEvent;
- (void)setCursorForMouse:(NSEvent *)theEvent;
- (void)showHelpMenu;

- (void)removeLoupeWindow;

- (void)handlePageChangedNotification:(NSNotification *)notification;
- (void)handleScaleChangedNotification:(NSNotification *)notification;
- (void)handleUndoGroupOpenedOrClosedNotification:(NSNotification *)notification;

@end

#pragma mark -

@implementation SKPDFView

@synthesize toolMode, annotationMode, temporaryToolMode, interactionMode, currentAnnotation, readingBar, pacerSpeed, transitionController, typeSelectHelper, syncDot, zooming;
@dynamic extendedDisplayMode, displaysHorizontally, displaysRightToLeft, hideNotes, hasReadingBar, hasPacer, currentSelectionPage, currentSelectionRect, currentMagnification, needsRewind, editing;

+ (void)initialize {
    SKINITIALIZE;
    
    NSArray *sendTypes = @[NSPasteboardTypePDF, NSPasteboardTypeTIFF, NSPasteboardTypeString, NSPasteboardTypeRTF];
    [NSApp registerServicesMenuSendTypes:sendTypes returnTypes:@[]];
    
    NSNumber *moveReadingBarModifiersNumber = [[NSUserDefaults standardUserDefaults] objectForKey:SKMoveReadingBarModifiersKey];
    NSNumber *resizeReadingBarModifiersNumber = [[NSUserDefaults standardUserDefaults] objectForKey:SKResizeReadingBarModifiersKey];
    if (moveReadingBarModifiersNumber)
        moveReadingBarModifiers = [moveReadingBarModifiersNumber integerValue];
    if (resizeReadingBarModifiersNumber)
        resizeReadingBarModifiers = [resizeReadingBarModifiersNumber integerValue];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{SKDefaultFreeTextNoteContentsKey:NSLocalizedString(@"Double-click to edit.", @"Default text for new text note"), SKDefaultAnchoredNoteContentsKey:NSLocalizedString(@"New note", @"Default text for new anchored note")}];
    
    
    useToolModeCursors = [[NSUserDefaults standardUserDefaults] boolForKey:SKUseToolModeCursorsKey];
    
    SKSwizzlePDFDocumentViewMethods();
    SKSwizzlePDFAccessibilityNodeAnnotationMethods();
}

+ (NSArray *)defaultKeysToObserve {
    return @[SKReadingBarColorKey, SKReadingBarInvertKey];
}

- (void)commonInitialization {
    toolMode = [[NSUserDefaults standardUserDefaults] integerForKey:SKLastToolModeKey];
    annotationMode = [[NSUserDefaults standardUserDefaults] integerForKey:SKLastAnnotationModeKey];
    interactionMode = SKNormalMode;
    
    transitionController = nil;
    
    typeSelectHelper = nil;
    
    spellingTag = [NSSpellChecker uniqueSpellDocumentTag];
    
    pdfvFlags.hideNotes = 0;
    pdfvFlags.wantsNewUndoGroup = 0;
    pdfvFlags.cursorHidden = 0;
    pdfvFlags.useArrowCursorInPresentation = [[NSUserDefaults standardUserDefaults] boolForKey:SKUseArrowCursorInPresentationKey];
    inKeyWindow = NO;
    
    laserPointerColor = [[NSUserDefaults standardUserDefaults] integerForKey:SKLaserPointerColorKey];
    
    navWindow = nil;
    
    readingBar = nil;
    
    pacerTimer = nil;
    pacerSpeed = [[NSUserDefaults standardUserDefaults] doubleForKey:SKPacerSpeedKey];
    if (pacerSpeed <= 0.0)
        pacerSpeed = DEFAULT_PACER_SPEED;
    
    currentAnnotation = nil;
    selectionRect = NSZeroRect;
    selectionPageIndex = NSNotFound;
    
    syncDot = nil;
    
    gestureRotation = 0.0;
    gesturePageIndex = NSNotFound;
    
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect owner:self userInfo:nil];
    [self addTrackingArea:trackingArea];
    
    [self registerForDraggedTypes:@[NSPasteboardTypeColor, SKPasteboardTypeLineStyle]];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handlePageChangedNotification:)
                                                 name:PDFViewPageChangedNotification object:self];
    [nc addObserver:self selector:@selector(handleScaleChangedNotification:)
                                                 name:PDFViewScaleChangedNotification object:self];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeys:[[self class] defaultKeysToObserve] context:&SKPDFViewDefaultsObservationContext];
}

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInitialization];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        [self commonInitialization];
    }
    return self;
}

- (void)dealloc {
    // we should have been cleaned up in setDelegate:nil which is called from windowWillClose:
    SKDESTROY(syncDot);
    SKDESTROY(trackingArea);
    SKDESTROY(currentAnnotation);
    SKDESTROY(typeSelectHelper);
    SKDESTROY(transitionController);
    SKDESTROY(navWindow);
    SKDESTROY(readingBar);
    SKDESTROY(editor);
    SKDESTROY(highlightAnnotation);
    SKDESTROY(highlightLayerController);
    SKDESTROY(rewindPage);
    [super dealloc];
}

- (void)cleanup {
    [[NSSpellChecker sharedSpellChecker] closeSpellDocumentWithTag:spellingTag];
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeys:[[self class] defaultKeysToObserve] context:&SKPDFViewDefaultsObservationContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self disableNavigation];
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
    [self removePDFToolTipRects];
    [syncDot invalidate];
    SKDESTROY(syncDot);
    [self stopPacer];
    [self removeLoupeWindow];
}

- (void)resetHistory {
    if ([self respondsToSelector:@selector(currentHistoryIndex)])
        minHistoryIndex = [self currentHistoryIndex];
}

#pragma mark Tool Tips

- (void)removePDFToolTipRects {
    NSView *docView = [self documentView];
    NSArray *trackingAreas = [[[docView trackingAreas] copy] autorelease];
    for (NSTrackingArea *area in trackingAreas) {
        if ([area owner] == self && [[area userInfo] objectForKey:SKAnnotationKey])
            [docView removeTrackingArea:area];
    }
}

- (void)resetPDFToolTipRects {
    [self removePDFToolTipRects];
    
    if ([self document] && [self window] && interactionMode != SKPresentationMode) {
        NSRect visibleRect = [self visibleContentRect];
        NSView *docView = [self documentView];
        BOOL hasLinkToolTips = (toolMode == SKTextToolMode || toolMode == SKMoveToolMode || toolMode == SKNoteToolMode);
        NSPoint mouseLoc = [docView convertPointFromScreen:[NSEvent mouseLocation]];
        BOOL mouseInView = [[self window] isVisible] && NSMouseInRect(mouseLoc, [docView visibleRect], [docView isFlipped]);
        PDFAnnotation *hoverAnnotation = nil;
        
        for (PDFPage *page in [self visiblePages]) {
            for (PDFAnnotation *annotation in [page annotations]) {
                if ([annotation isNote] || (hasLinkToolTips && [annotation linkDestination])) {
                    NSRect rect = NSIntersectionRect([self convertRect:[annotation bounds] fromPage:page], visibleRect);
                    if (NSIsEmptyRect(rect) == NO) {
                        rect = [self convertRect:rect toView:docView];
                        NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:annotation, SKAnnotationKey, nil];
                        NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp;
                        if (mouseInView && NSMouseInRect(mouseLoc, rect, [docView isFlipped])) {
                            options |= NSTrackingAssumeInside;
                            hoverAnnotation = annotation;
                        }
                        NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:rect options:options owner:self userInfo:userInfo];
                        [docView addTrackingArea:area];
                        [area release];
                        [userInfo release];
                    }
                }
            }
        }
        
        if (mouseInView && hoverAnnotation != [[SKImageToolTipWindow sharedToolTipWindow] currentImageContext]) {
            if (hoverAnnotation)
                [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:hoverAnnotation scale:[self scaleFactor] atPoint:NSZeroPoint];
            else
                [[SKImageToolTipWindow sharedToolTipWindow] fadeOut];
        }
    }
}

#pragma mark Drawing

- (BOOL)drawsActiveSelections {
    if (RUNNING_AFTER(10_14))
        return atomic_load(&inKeyWindow);
    else if (RUNNING_AFTER(10_11))
        return YES;
    else
        return (inKeyWindow && [[[self window] firstResponder] isDescendantOf:self]);
}

- (CGFloat)unitWidthOnPage:(PDFPage *)page {
    return NSWidth([self convertRect:NSMakeRect(0.0, 0.0, 1.0, 1.0) toPage:page]);
}

- (void)drawSelectionForPage:(PDFPage *)pdfPage inContext:(CGContextRef)context {
    NSRect rect;
    NSUInteger pageIndex;
    @synchronized (self) {
        pageIndex = selectionPageIndex;
        rect = selectionRect;
    }
    if (pageIndex != NSNotFound) {
        NSRect bounds = [pdfPage boundsForBox:[self displayBox]];
        CGColorRef color = CGColorCreateGenericGray(0.0, 0.6);
        rect = CGContextConvertRectToUserSpace(context, CGRectIntegral(CGContextConvertRectToDeviceSpace(context, rect)));
        CGContextSetFillColorWithColor(context, color);
        CGColorRelease(color);
        CGContextBeginPath(context);
        CGContextAddRect(context, NSRectToCGRect(bounds));
        CGContextAddRect(context, NSRectToCGRect(rect));
        CGContextEOFillPath(context);
        if ([pdfPage pageIndex] != pageIndex) {
            color = CGColorCreateGenericGray(0.0, 0.3);
            CGContextSetFillColorWithColor(context, color);
            CGColorRelease(color);
            CGContextFillRect(context, NSRectToCGRect(rect));
        }
        SKDrawResizeHandles(context, rect, [self unitWidthOnPage:pdfPage], NO, [self drawsActiveSelections]);
    }
}

- (void)drawPageHighlights:(PDFPage *)pdfPage toContext:(CGContextRef)context {
    CGContextSaveGState(context);
    
    [pdfPage transformContext:context forBox:[self displayBox]];
    
    [[self readingBar] drawForPage:pdfPage withBox:[self displayBox] inContext:context];
    
    if (atomic_load(&highlightLayerState) != SKLayerUse) {
        PDFAnnotation *annotation = nil;
        @synchronized (self) {
            annotation = [[currentAnnotation retain] autorelease];
        }
        
        if ([[annotation page] isEqual:pdfPage])
            [annotation drawSelectionHighlightWithLineWidth:[self unitWidthOnPage:pdfPage] active:[self drawsActiveSelections] inContext:context];
    }
    
    [self drawSelectionForPage:pdfPage inContext:context];
    
    SKSyncDot *aSyncDot = [self syncDot];
    if ([[aSyncDot page] isEqual:pdfPage])
        [aSyncDot drawInContext:context];
    
    CGContextRestoreGState(context);
}

- (void)drawPage:(PDFPage *)pdfPage toContext:(CGContextRef)context {
    NSInteger state = atomic_load(&highlightLayerState);
    if (state == SKLayerAdd) {
        atomic_store(&highlightLayerState, SKLayerUse);
        dispatch_async(dispatch_get_main_queue(), ^{ [self makeHighlightLayerForType:SKLayerTypeNote]; });
    } else if (state == SKLayerRemove) {
        atomic_store(&highlightLayerState, SKLayerNone);
        dispatch_async(dispatch_get_main_queue(), ^{ [self removeHighlightLayer]; });
    }

    // Let PDFView do most of the hard work.
    [super drawPage:pdfPage toContext:context];
    [self drawPageHighlights:pdfPage toContext:context];
}

- (void)drawPage:(PDFPage *)pdfPage {
    // Let PDFView do most of the hard work.
    [super drawPage:pdfPage];
    if ([PDFView instancesRespondToSelector:@selector(drawPage:toContext:)] == NO) {
        // on 10.12+ this should be called from drawPage:toContext:
        [self drawPageHighlights:pdfPage toContext:[[NSGraphicsContext currentContext] CGContext]];
    }
}

- (void)drawLayerController:(SKLayerController *)controller inContext:(CGContextRef)context {
    if ([controller type] == SKLayerTypeNote) {
        if (currentAnnotation == nil)
            return;
        PDFPage *page = [currentAnnotation page];
        NSPoint offset = SKSubstractPoints([self convertRect:[page boundsForBox:[self displayBox]] fromPage:page].origin, [self visibleContentRect].origin);
        CGFloat scaleFactor = [self scaleFactor];
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, offset.x, offset.y);
        CGContextScaleCTM(context, scaleFactor, scaleFactor);
        [page transformContext:context forBox:[self displayBox]];
        [currentAnnotation drawSelectionHighlightWithLineWidth:1.0 / scaleFactor active:[self drawsActiveSelections] inContext:context];
        CGContextRestoreGState(context);
    } else {
        CGRect rect = NSRectToCGRect([controller rect]);
        if (CGRectIsEmpty(rect))
            return;
        rect = CGContextConvertRectToUserSpace(context, CGRectIntegral(CGContextConvertRectToDeviceSpace(context, NSRectToCGRect(rect))));
        CGContextSaveGState(context);
        if (CGRectGetWidth(rect) > 1.0 && CGRectGetHeight(rect) > 1.0) {
            CGContextSetStrokeColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
            CGContextSetLineWidth(context, 1.0);
            CGContextStrokeRect(context, CGRectInset(rect, 0.5, 0.5 ));
        } else {
            CGContextSetFillColorWithColor(context, CGColorGetConstantColor(kCGColorBlack));
            CGContextFillRect(context, rect);
        }
        CGContextRestoreGState(context);
    }
}

- (void)makeHighlightLayerForType:(NSInteger)type {
    if (highlightLayerController) {
        [[highlightLayerController layer] removeFromSuperlayer];
        [highlightLayerController release];
    }
    CALayer *layer = [[CALayer alloc] init];
    [layer setFrame:NSRectToCGRect([self visibleContentRect])];
    [layer setBounds:[layer frame]];
    [layer setMasksToBounds:YES];
    [layer setZPosition:1.0];
    [layer setContentsScale:[[self layer] contentsScale]];
    [layer setFilters:SKColorEffectFilters()];
    highlightLayerController = [[SKLayerController alloc] init];
    [highlightLayerController setType:type];
    [highlightLayerController setDelegate:self];
    [highlightLayerController setLayer:layer];
    [layer setDelegate:highlightLayerController];
    [[self layer] addSublayer:layer];
    [layer setNeedsDisplay];
    [layer release];
}

- (void)removeHighlightLayer {
    [[highlightLayerController layer] removeFromSuperlayer];
    SKDESTROY(highlightLayerController);
}

#pragma mark Accessors

- (void)setDocument:(PDFDocument *)document {
    SKDESTROY(rewindPage);
    
    BOOL shouldHideReadingBar = [syncDot shouldHideReadingBar];
    [syncDot invalidate];
    [self setSyncDot:nil];
    
    @synchronized (self) {
        selectionRect = NSZeroRect;
        selectionPageIndex = NSNotFound;
    }
    
    [self removePDFToolTipRects];
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
    
    NSUInteger readingBarPageIndex = NSNotFound;
    NSInteger readingBarLine = -1;
    [self stopPacer];
    if ([self hasReadingBar]) {
        if (shouldHideReadingBar == NO) {
            readingBarPageIndex = [[readingBar page] pageIndex];
            readingBarLine = [readingBar currentLine];
        }
        [self setReadingBar:nil];
    }
    
    [super setDocument:document];
    
    [self resetPDFToolTipRects];
    
    if (readingBarPageIndex != NSNotFound) {
        PDFPage *page = nil;
        if (readingBarPageIndex < [document pageCount]) {
            page = [document pageAtIndex:readingBarPageIndex];
        } else if ([document pageCount] > 0) {
            page = [document pageAtIndex:[document pageCount] - 1];
            readingBarLine = 0;
        }
        if (page) {
            SKReadingBar *aReadingBar = [[SKReadingBar alloc] initWithPage:page line:readingBarLine delegate:self];
            [self setReadingBar:aReadingBar];
            [aReadingBar release];
        }
    }
    
    [loupeController updateContents];
}

- (NSUndoManager *)undoManager {
    NSUndoManager *undoManager = [super undoManager];
    if (undoManager == nil && [[self delegate] respondsToSelector:@selector(document)])
        undoManager = [[(NSWindowController *)[self delegate] document] undoManager];
    return undoManager;
}

- (void)setBackgroundColor:(NSColor *)newBackgroundColor {
    [super setBackgroundColor:newBackgroundColor];
    [loupeController updateBackgroundColor];
}

- (NSColor *)backgroundColor {
    if (RUNNING(10_15))
        return [super backgroundColor] ?: [[self scrollView] backgroundColor];
    return [super backgroundColor];
}

- (void)setToolMode:(SKToolMode)newToolMode {
    if (toolMode != newToolMode) {
        [self setTemporaryToolMode:SKNoToolMode];
        if (toolMode == SKTextToolMode || toolMode == SKNoteToolMode) {
            if (newToolMode != SKTextToolMode) {
                if (newToolMode != SKNoteToolMode && currentAnnotation)
                    [self setCurrentAnnotation:nil];
                if ([[self currentSelection] hasCharacters])
                    [self setCurrentSelection:nil];
            }
        } else if (toolMode == SKSelectToolMode) {
            if (NSEqualRects(selectionRect, NSZeroRect) == NO) {
                [self setCurrentSelectionRect:NSZeroRect];
                [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewSelectionChangedNotification object:self];
            }
        } else if (toolMode == SKMagnifyToolMode) {
            [self removeLoupeWindow];
        }
        
        toolMode = newToolMode;
        
        [[NSUserDefaults standardUserDefaults] setInteger:toolMode forKey:SKLastToolModeKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewToolModeChangedNotification object:self];
        [self setCursorForMouse:nil];
        [self resetPDFToolTipRects];
        if (toolMode == SKMagnifyToolMode && [[NSUserDefaults standardUserDefaults] boolForKey:SKMagnifyWithMousePressedKey] == NO)
            [self doMagnifyWithEvent:nil];
    }
}

- (void)setAnnotationMode:(SKNoteType)newAnnotationMode {
    if (annotationMode != newAnnotationMode) {
        annotationMode = newAnnotationMode;
        [[NSUserDefaults standardUserDefaults] setInteger:annotationMode forKey:SKLastAnnotationModeKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewAnnotationModeChangedNotification object:self];
        // hack to make sure we update the cursor
        [self setCursorForMouse:nil];
    }
}

- (void)setTemporaryToolMode:(SKTemporaryToolMode)newTemporaryToolMode {
    if (temporaryToolMode != newTemporaryToolMode) {
        temporaryToolMode = newTemporaryToolMode;
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewTemporaryToolModeChangedNotification object:self];
    }
}

- (void)setInteractionMode:(SKInteractionMode)newInteractionMode {
    if (interactionMode != newInteractionMode) {
        [self setTemporaryToolMode:SKNoToolMode];
        if (interactionMode == SKPresentationMode) {
            pdfvFlags.cursorHidden = NO;
            [NSCursor setHiddenUntilMouseMoves:NO];
            if ([[self documentView] isHidden])
                [[self documentView] setHidden:NO];
        }
        interactionMode = newInteractionMode;
        if (interactionMode == SKPresentationMode) {
            if (toolMode == SKTextToolMode || toolMode == SKNoteToolMode) {
                if (currentAnnotation)
                    [self setCurrentAnnotation:nil];
                if ([[self currentSelection] hasCharacters])
                    [self setCurrentSelection:nil];
            } else if (toolMode == SKSelectToolMode && NSEqualRects(selectionRect, NSZeroRect) == NO) {
                [self setCurrentSelectionRect:NSZeroRect];
                [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewSelectionChangedNotification object:self];
            }
            [self stopPacer];
        }
        // always clean up navWindow and hanging perform requests
        [self disableNavigation];
        if (interactionMode == SKPresentationMode)
            [self enableNavigation];
        [self resetPDFToolTipRects];
    }
}

- (void)setCurrentAnnotation:(PDFAnnotation *)newAnnotation {
	if (newAnnotation != currentAnnotation) {
        PDFAnnotation *wasAnnotation = currentAnnotation;
        
        // Will need to redraw old active anotation.
        if (currentAnnotation != nil) {
            [self setNeedsDisplayForAnnotation:currentAnnotation];
            NSInteger level = [[self undoManager] groupingLevel];
            if (editor && [self commitEditing] == NO)
                [self discardEditing];
            if ([[self undoManager] groupingLevel] > level)
                pdfvFlags.wantsNewUndoGroup = YES;
        }
        
        // Assign.
        @synchronized (self) {
            [currentAnnotation release];
            currentAnnotation = [newAnnotation retain];
        }
        if (newAnnotation) {
            // Force redisplay.
            [self setNeedsDisplayForAnnotation:currentAnnotation];
        }
        
        NSDictionary *userInfo = wasAnnotation ? @{SKPDFViewAnnotationKey:wasAnnotation} : nil;
		[[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewCurrentAnnotationChangedNotification object:self userInfo:userInfo];
    }
}

- (BOOL)isEditing {
    return editor != nil;
}

- (void)setDisplayMode:(PDFDisplayMode)mode {
    if (mode != [self displayMode] || (mode == kPDFDisplaySinglePageContinuous && [self displaysHorizontally])) {
        PDFPage *page = [self currentPage];
        [super setDisplayMode:mode];
        if (page && [page isEqual:[self currentPage]] == NO)
            [self goToPage:page];
        [self resetPDFToolTipRects];
        [editor layoutWithEvent:nil];
    }
}

- (void)setDisplayModeAndRewind:(PDFDisplayMode)mode {
    if (mode != [self displayMode]) {
        if (mode != kPDFDisplaySinglePage)
            [self setNeedsRewind:YES];
        [self setDisplayMode:mode];
    }
}

- (void)_setDisplaysHorizontally:(BOOL)flag {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if (RUNNING_AFTER(10_12) && flag != ([self displayDirection] == kPDFDisplayDirectionHorizontal)) {
        [super setDisplayDirection:flag ? kPDFDisplayDirectionHorizontal : kPDFDisplayDirectionVertical];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDisplaysHorizontallyChangedNotification object:self];
    }
#pragma clang diagnostic pop
}

- (PDFDisplayMode)extendedDisplayMode {
    PDFDisplayMode displayMode = [self displayMode];
    if (displayMode == kPDFDisplaySinglePageContinuous && [self displaysHorizontally])
        return kPDFDisplayHorizontalContinuous;
    return displayMode;
}

- (void)setExtendedDisplayMode:(PDFDisplayMode)mode {
    if (mode != [self extendedDisplayMode]) {
        PDFPage *page = [self currentPage];
        BOOL horizontal = NO;
        if (mode == kPDFDisplayHorizontalContinuous) {
            mode = kPDFDisplaySinglePageContinuous;
            horizontal = YES;
        }
        [super setDisplayMode:mode];
        [self _setDisplaysHorizontally:horizontal];
        if (page && [page isEqual:[self currentPage]] == NO)
            [self goToPage:page];
        [self resetPDFToolTipRects];
        [editor layoutWithEvent:nil];
    }
}

- (void)setExtendedDisplayModeAndRewind:(PDFDisplayMode)mode {
    if (mode != [self extendedDisplayMode]) {
        if (mode != kPDFDisplaySinglePage)
            [self setNeedsRewind:YES];
        [self setExtendedDisplayMode:mode];
    }
}

- (BOOL)displaysHorizontally {
    if (RUNNING_BEFORE(10_13))
        return NO;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    return [self displayDirection] == kPDFDisplayDirectionHorizontal;
#pragma clang diagnostic pop
}

- (void)setDisplaysHorizontally:(BOOL)flag {
    if (RUNNING_AFTER(10_12) && flag != [self displaysHorizontally]) {
        PDFPage *page = [self currentPage];
        [self _setDisplaysHorizontally:flag];
        if (page && [page isEqual:[self currentPage]] == NO)
            [self goToPage:page];
        [self resetPDFToolTipRects];
        [editor layoutWithEvent:nil];
    }
}

- (void)setDisplaysHorizontallyAndRewind:(BOOL)flag {
    if (RUNNING_AFTER(10_12) && flag != [self displaysHorizontally]) {
        [self setNeedsRewind:YES];
        [self setDisplaysHorizontally:flag];
    }
}

- (BOOL)displaysRightToLeft {
    if (RUNNING_BEFORE(10_13))
        return NO;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    return [self displaysRTL];
#pragma clang diagnostic pop
}

- (void)setDisplaysRightToLeft:(BOOL)flag {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if (RUNNING_AFTER(10_12) && flag != [self displaysRTL]) {
        PDFPage *page = [self currentPage];
        [self setDisplaysRTL:flag];
        // on 10.15 this does not relayout the view...
        [self layoutDocumentView];
        if (page && [page isEqual:[self currentPage]] == NO)
            [self goToPage:page];
        [self resetPDFToolTipRects];
        [editor layoutWithEvent:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDisplaysRTLChangedNotification object:self];
    }
#pragma clang diagnostic pop
}

- (void)setDisplaysRightToLeftAndRewind:(BOOL)flag {
    if (RUNNING_AFTER(10_12) && flag != [self displaysRightToLeft]) {
        if ([self displayMode] != kPDFDisplaySinglePage)
            [self setNeedsRewind:YES];
        [self setDisplaysRightToLeft:flag];
    }
}

- (void)setDisplayBox:(PDFDisplayBox)box {
    if (box != [self displayBox]) {
        PDFPage *page = [self currentPage];
        [super setDisplayBox:box];
        if (page && [page isEqual:[self currentPage]] == NO)
            [self goToPage:page];
        [self resetPDFToolTipRects];
        [editor layoutWithEvent:nil];
    }
}

- (void)setDisplayBoxAndRewind:(PDFDisplayBox)box {
    if (box != [self displayBox]) {
        if ([self displayMode] != kPDFDisplaySinglePage)
            [self setNeedsRewind:YES];
        [self setDisplayBox:box];
    }
}

- (void)setDisplaysAsBook:(BOOL)asBook {
    if (asBook != [self displaysAsBook]) {
        PDFPage *page = [self currentPage];
        [super setDisplaysAsBook:asBook];
        if (page && [page isEqual:[self currentPage]] == NO)
            [self goToPage:page];
        [self resetPDFToolTipRects];
        [editor layoutWithEvent:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDisplaysAsBookChangedNotification object:self];
    }
}

- (void)setDisplaysAsBookAndRewind:(BOOL)asBook {
    if (asBook != [self displaysAsBook]) {
        if ([self displayMode] != kPDFDisplaySinglePageContinuous)
            [self setNeedsRewind:YES];
        [self setDisplaysAsBook:asBook];
    }
}

- (void)setDisplaysPageBreaks:(BOOL)pageBreaks {
    if (pageBreaks != [self displaysPageBreaks]) {
        [super setDisplaysPageBreaks:pageBreaks];
        [self resetPDFToolTipRects];
        [editor layoutWithEvent:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDisplaysPageBreaksChangedNotification object:self];
    }
}

- (void)setAutoScales:(BOOL)autoScales {
    if (autoScales != [self autoScales]) {
        [super setAutoScales:autoScales];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewAutoScalesChangedNotification object:self];
    }
}

- (void)setCurrentSelection:(PDFSelection *)selection {
    if ((toolMode == SKNoteToolMode && annotationMode == SKHighlightNote) || temporaryToolMode == SKHighlightToolMode)
        [selection setColor:[[NSUserDefaults standardUserDefaults] colorForKey:SKHighlightNoteColorKey]];
    [super setCurrentSelection:selection];
}

- (NSRect)currentSelectionRect {
    if (toolMode == SKSelectToolMode)
        return selectionRect;
    return NSZeroRect;
}

- (void)setCurrentSelectionRect:(NSRect)rect {
    if (toolMode == SKSelectToolMode) {
        if (NSEqualRects(selectionRect, rect) == NO)
            [self requiresDisplay];
        @synchronized (self) {
            if (NSIsEmptyRect(rect)) {
                selectionRect = NSZeroRect;
                selectionPageIndex = NSNotFound;
            } else {
                selectionRect = rect;
                if (selectionPageIndex == NSNotFound)
                    selectionPageIndex = [[self currentPage] pageIndex];
            }
        }
    }
}

- (PDFPage *)currentSelectionPage {
    return selectionPageIndex == NSNotFound ? nil : [[self document] pageAtIndex:selectionPageIndex];
}

- (void)setCurrentSelectionPage:(PDFPage *)page {
    if (toolMode == SKSelectToolMode) {
        if (selectionPageIndex != [page pageIndex] || (page == nil && selectionPageIndex != NSNotFound))
            [self requiresDisplay];
        @synchronized (self) {
            if (page == nil) {
                selectionPageIndex = NSNotFound;
                selectionRect = NSZeroRect;
            } else {
                selectionPageIndex = [page pageIndex];
                if (NSIsEmptyRect(selectionRect))
                    selectionRect = [page boundsForBox:kPDFDisplayBoxCropBox];
            }
        }
    }
}

- (CGFloat)currentMagnification {
    return loupeController ? [loupeController magnification] : 0.0;
}

- (BOOL)hideNotes {
    return pdfvFlags.hideNotes;
}

- (void)setHideNotes:(BOOL)flag {
    if (pdfvFlags.hideNotes != flag) {
        pdfvFlags.hideNotes = flag;
        if (pdfvFlags.hideNotes)
            [self setCurrentAnnotation:nil];
        [self requiresDisplay];
    }
}

- (SKTransitionController * )transitionController {
    if (transitionController == nil) {
        transitionController = [[SKTransitionController alloc] init];
        [transitionController setView:self];
    }
    return transitionController;
}

- (void)setHighlightAnnotation:(PDFAnnotation *)annotation {
    if (annotation != highlightAnnotation) {
        [highlightAnnotation release];
        highlightAnnotation = [annotation retain];
        if (highlightAnnotation) {
            if (highlightLayerController == nil)
                [self makeHighlightLayerForType:SKLayerTypeRect];
            
            NSRect rect = [self convertRect:[highlightAnnotation bounds] fromPage:[highlightAnnotation page]];
            [highlightLayerController setRect:NSInsetRect(rect, -1.0, -1.0)];
        } else if (highlightLayerController) {
            [self removeHighlightLayer];
        }
    }
}

#pragma mark Reading bar

- (BOOL)hasReadingBar {
    return readingBar != nil;
}

- (void)toggleReadingBar {
    PDFPage *page = nil;
    NSRect bounds = NSZeroRect;
    NSDictionary *userInfo = nil;
    if (readingBar) {
        page = [readingBar page];
        bounds = [readingBar currentBounds];
        [self setReadingBar:nil];
        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:page, SKPDFViewOldPageKey, nil];
    } else {
        page = [self currentPage];
        NSInteger line = 0;
        PDFSelection *sel = [self currentSelection];
        if ([[sel pages] containsObject:page]) {
            NSRect rect = [sel boundsForPage:page];
            NSPoint point = [page lineDirectionAngle] < 180 ? NSMakePoint(NSMinX(rect) + 1.0, NSMinY(rect) + 1.0) : NSMakePoint(NSMaxY(rect) - 1.0, NSMaxY(rect) - 1.0);
            line = [page indexOfLineRectAtPoint:point lower:YES];
        }
        SKReadingBar *aReadingBar = [[SKReadingBar alloc] initWithPage:page line:line delegate:self];
        if ([aReadingBar currentLine] == -1) {
            [aReadingBar release];
            NSBeep();
            return;
        }
        page = [aReadingBar page];
        bounds = [aReadingBar currentBounds];
        NSRect rect = [aReadingBar currentBounds];
        rect = ([page lineDirectionAngle] % 180) ? NSInsetRect(rect, 0.0, -20.0) : NSInsetRect(rect, -20.0, 0.0);
        [self goToRect:rect onPage:page];
        [self setReadingBar:aReadingBar];
        [aReadingBar release];
        userInfo = [NSDictionary dictionaryWithObjectsAndKeys:page, SKPDFViewNewPageKey, nil];
    }
    [self updatePacer];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKReadingBarInvertKey])
        [self requiresDisplay];
    else
        [self setNeedsDisplayForReadingBarBounds:bounds onPage:page];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewReadingBarDidChangeNotification object:self userInfo:userInfo];
}

- (void)readingBar:(SKReadingBar *)aReadingBar didChangeBounds:(NSRect)oldBounds onPage:(PDFPage *)oldPage toBounds:(NSRect)newBounds onPage:(PDFPage *)newPage scroll:(BOOL)shouldScroll {
    [syncDot setShouldHideReadingBar:NO];
    
    if (shouldScroll) {
        NSRect rect = newBounds;
        NSInteger lineAngle = [newPage lineDirectionAngle];
        if ((lineAngle % 180)) {
            rect = NSInsetRect(rect, 0.0, -20.0) ;
            if (([self displayMode] & kPDFDisplaySinglePageContinuous)) {
                NSRect visibleRect = [self convertRect:[self visibleContentRect] toPage:newPage];
                rect = NSInsetRect(rect, 0.0, - floor( ( NSHeight(visibleRect) - NSHeight(rect) ) / 2.0 ) );
                if (NSWidth(rect) <= NSWidth(visibleRect)) {
                    if (NSMinX(rect) > NSMinX(visibleRect))
                        rect.origin.x = fmax(NSMinX(visibleRect), NSMaxX(rect) - NSWidth(visibleRect));
                } else if (lineAngle == 90) {
                    rect.origin.x = NSMaxX(rect) - NSWidth(visibleRect);
                }
                rect.size.width = NSWidth(visibleRect);
            }
        } else {
            rect = NSInsetRect(rect, -20.0, 0.0) ;
            if (([self displayMode] & kPDFDisplaySinglePageContinuous)) {
                NSRect visibleRect = [self convertRect:[self visibleContentRect] toPage:newPage];
                rect = NSInsetRect(rect, - floor( ( NSWidth(visibleRect) - NSWidth(rect) ) / 2.0 ), 0.0 );
                if (NSHeight(rect) <= NSHeight(visibleRect)) {
                    if (NSMinY(rect) > NSMinY(visibleRect))
                        rect.origin.y = fmax(NSMinY(visibleRect), NSMaxY(rect) - NSHeight(visibleRect));
                } else if (lineAngle == 180) {
                    rect.origin.y = NSMaxY(rect) - NSHeight(visibleRect);
                }
                rect.size.height = NSHeight(visibleRect);
            }
        }
        [self goToRect:rect onPage:newPage];
    }
    
    if (oldPage)
        [self setNeedsDisplayForReadingBarBounds:oldBounds onPage:oldPage];
    if (newPage)
        [self setNeedsDisplayForReadingBarBounds:newBounds onPage:newPage];
    
    NSDictionary *userInfo = newPage ? [NSDictionary dictionaryWithObjectsAndKeys:newPage, SKPDFViewNewPageKey, oldPage, SKPDFViewOldPageKey, nil] : [NSDictionary dictionaryWithObjectsAndKeys:oldPage, SKPDFViewOldPageKey, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewReadingBarDidChangeNotification object:self userInfo:userInfo];
}

#pragma mark Pacer

- (void)setPacerSpeed:(CGFloat)speed {
    if (speed > 0.0) {
        pacerSpeed = speed;
        [self updatePacer];
        [[NSUserDefaults standardUserDefaults] setDouble:speed forKey:SKPacerSpeedKey];
    }
}

- (BOOL)hasPacer {
    return pacerTimer != nil;
}

- (void)stopPacer {
    if (pacerTimer) {
        [pacerTimer invalidate];
        SKDESTROY(pacerTimer);
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewPacerStartedOrStoppedNotification object:self];
    }
}

- (void)pacerScroll:(NSTimer *)timer {
    NSScrollView *scrollView = [self scrollView];
    NSClipView *clipView = [scrollView contentView];
    NSRect bounds = [clipView bounds];
    NSRect docRect = [[scrollView documentView] frame];
    if (NSHeight(docRect) + [scrollView contentInsets].top <= NSHeight(bounds))
        return;
    NSPoint currentOrigin = bounds.origin;
    CGFloat offset = [clipView convertSizeFromBacking:NSMakeSize(0.0, 1.0)].height;
    if ([clipView isFlipped]) {
        bounds.origin.y += offset;
        if (NSMaxY(docRect) < NSMaxY(bounds))
            bounds.origin.y = NSMaxY(docRect) - NSHeight(bounds);
    } else {
        bounds.origin.y -= offset;
        if (NSMinY(docRect) > NSMinY(bounds))
            bounds.origin.y = NSMinY(docRect);
    }
    if (NSEqualPoints(bounds.origin, currentOrigin) == NO)
        [clipView scrollToPoint:bounds.origin];
}

- (void)pacerMoveReadingBar:(NSTimer *)timer {
    [readingBar goToNextLine];
}

- (void)togglePacer {
    if (pacerTimer) {
        [self stopPacer];
    } else if (pacerSpeed > 0.0 && [[self document] isLocked] == NO) {
        CGFloat interval;
        SEL selector;
        if ([self hasReadingBar]) {
            interval = PACER_LINE_HEIGHT / pacerSpeed;
            selector = @selector(pacerMoveReadingBar:);
        } else {
            interval = 1.0 / (pacerSpeed * [self backingScale] * [self scaleFactor]);
            selector = @selector(pacerScroll:);
        }
        pacerTimer = [[NSTimer scheduledTimerWithTimeInterval:interval target:self selector:selector userInfo:nil repeats:YES] retain];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewPacerStartedOrStoppedNotification object:self];
    }
}

- (void)updatePacer {
    if (pacerTimer) {
        [self stopPacer];
        [self togglePacer];
    }
}

#pragma mark Actions

- (void)animateTransitionForNextPage:(BOOL)next {
    PDFPage *fromPage = [self currentPage];
    NSUInteger idx = [fromPage pageIndex];
    NSUInteger toIdx = (next ? idx + 1 : idx - 1);
    PDFPage *toPage = [[self document] pageAtIndex:toIdx];
    if ([transitionController pageTransitions] ||
        ([fromPage label] && [toPage label] && [[fromPage label] isEqualToString:[toPage label]] == NO)) {
        NSRect rect = [self convertRect:[fromPage boundsForBox:[self displayBox]] fromPage:fromPage];
        [[self transitionController] animateForRect:rect from:idx to:toIdx change:^{
            if (next)
                [super goToNextPage:self];
            else
                [super goToPreviousPage:self];
            return [self convertRect:[toPage boundsForBox:[self displayBox]] fromPage:toPage];
        }];
    } else if (next) {
        [super goToNextPage:self];
    } else {
        [super goToPreviousPage:self];
    }
}

- (void)doAutoHideCursor {
    if ([NSWindow windowNumberAtPoint:[NSEvent mouseLocation] belowWindowWithWindowNumber:0] == [[self window] windowNumber]) {
        [[NSCursor emptyCursor] set];
        pdfvFlags.cursorHidden = YES;
        [NSCursor setHiddenUntilMouseMoves:YES];
    }
}

- (void)doAutoHideCursorIfNeeded {
    if (interactionMode == SKPresentationMode && [self window] && pdfvFlags.cursorHidden) {
        [self performSelector:@selector(doAutoHideCursor) withObject:nil afterDelay:0.0];
        [self performSelector:@selector(doAutoHideCursor) withObject:nil afterDelay:0.1];
    }
}

- (IBAction)goToNextPage:(id)sender {
    if (RUNNING(10_12) && [NSEvent standardModifierFlags] == (NSCommandKeyMask | NSAlternateKeyMask)) {
        [self setToolMode:([self toolMode] + 1) % TOOL_MODE_COUNT];
        return;
    }
    if (interactionMode == SKPresentationMode && [self window] && [transitionController hasTransition] && [self canGoToNextPage])
        [self animateTransitionForNextPage:YES];
    else
        [super goToNextPage:sender];
    [self doAutoHideCursorIfNeeded];
}

- (IBAction)goToPreviousPage:(id)sender {
    if (RUNNING(10_12) && [NSEvent standardModifierFlags] == (NSCommandKeyMask | NSAlternateKeyMask)) {
        [self setToolMode:([self toolMode] + TOOL_MODE_COUNT - 1) % TOOL_MODE_COUNT];
        return;
    }
    if (interactionMode == SKPresentationMode && [self window] && [transitionController hasTransition] && [self canGoToPreviousPage])
        [self animateTransitionForNextPage:NO];
    else
        [super goToPreviousPage:sender];
    [self doAutoHideCursorIfNeeded];
}

- (IBAction)goToFirstPage:(id)sender {
    if (RUNNING(10_12) && [NSEvent standardModifierFlags] == (NSCommandKeyMask | NSAlternateKeyMask)) {
        [self setAnnotationMode:([self annotationMode] + ANNOTATION_MODE_COUNT - 1) % ANNOTATION_MODE_COUNT];
        return;
    } else {
        [super goToFirstPage:sender];
    }
}

- (IBAction)goToLastPage:(id)sender {
    if (RUNNING(10_12) && [NSEvent standardModifierFlags] == (NSCommandKeyMask | NSAlternateKeyMask)) {
        [self setAnnotationMode:([self annotationMode] + 1) % ANNOTATION_MODE_COUNT];
        return;
    } else {
        [super goToLastPage:sender];
    }
}

- (IBAction)delete:(id)sender
{
	if ([currentAnnotation isSkimNote])
        [self removeCurrentAnnotation:self];
    else
        NSBeep();
}

- (IBAction)copy:(id)sender
{
    NSAttributedString *attrString = [[self currentSelection] attributedString];
    NSPasteboardItem *imageItem = nil;
    PDFAnnotation *note = nil;
    
    if ([self hideNotes] == NO && [currentAnnotation isSkimNote]) {
        if ([currentAnnotation isMovable])
            note = currentAnnotation;
        else if (attrString == nil && [currentAnnotation isMarkup])
            attrString = [[(PDFAnnotationMarkup *)currentAnnotation selection] attributedString];
    }
    
    if (toolMode == SKSelectToolMode && NSIsEmptyRect(selectionRect) == NO && selectionPageIndex != NSNotFound) {
        NSRect selRect = NSIntegralRect(selectionRect);
        PDFPage *page = [self currentSelectionPage];
        NSData *pdfData = nil;
        NSData *tiffData = nil;
        
        imageItem = [[[NSPasteboardItem alloc] init] autorelease];
        
        if ([[self document] allowsPrinting] && (pdfData = [page PDFDataForRect:selRect]))
            [imageItem setData:pdfData forType:NSPasteboardTypePDF];
        if ((tiffData = [page TIFFDataForRect:selRect]))
            [imageItem setData:tiffData forType:NSPasteboardTypeTIFF];
        
        /*
         Possible hidden default?  Alternate way of getting a bitmap rep; this varies resolution with zoom level, which is very useful if you want to copy a single figure or equation for a non-PDF-capable program.  The first copy: action has some odd behavior, though (view moves).  Preview produces a fixed resolution bitmap for a given selection area regardless of zoom.
         
        sourceRect = [self convertRect:selectionRect fromPage:[self currentPage]];
        NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:sourceRect];
        [self cacheDisplayInRect:sourceRect toBitmapImageRep:imageRep];
        tiffData = [imageRep TIFFRepresentation];
         */
    }
    
    if ([attrString length] > 0 || imageItem || note) {
    
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        
        [pboard clearContents];
        
        if ([attrString length] > 0)
            [pboard writeObjects:@[attrString]];
        if (imageItem)
            [pboard writeObjects:@[imageItem]];
        if (note)
            [pboard writeObjects:@[note]];
        
    } else {
        [super copy:sender];
    }
}

- (void)pasteNote:(BOOL)preferNote plainText:(BOOL)isPlainText {
    if ([self hideNotes]) {
        NSBeep();
        return;
    }
    
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    NSDictionary *options = @{};
    NSArray *newAnnotations = nil;
    PDFPage *page;
    
    if (isPlainText == NO)
        newAnnotations = [pboard readObjectsForClasses:@[[PDFAnnotation class]] options:options];
    
    if ([newAnnotations count] > 0) {
        
        for (PDFAnnotation *newAnnotation in newAnnotations) {
            
            NSRect bounds = [newAnnotation bounds];
            page = [self currentPage];
            bounds = SKConstrainRect(bounds, [page boundsForBox:[self displayBox]]);
            
            [newAnnotation setBounds:bounds];
            
            [newAnnotation registerUserName];
            [self addAnnotation:newAnnotation toPage:page];
            
            [self setCurrentAnnotation:newAnnotation];

        }
        
        [[self undoManager] setActionName:NSLocalizedString(@"Add Note", @"Undo action name")];
        
    } else {
        
        id str = nil;
        
        if (isPlainText || preferNote)
            str = [[pboard readObjectsForClasses:@[[NSAttributedString class], [NSString class]] options:options] firstObject];
        else
            str = [[pboard readObjectsForClasses:@[[NSString class]] options:options] firstObject];
        
        
        if (str) {
            
            // First try the current mouse position
            NSPoint center = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
            
            // if the mouse was in the toolbar and there is a page below the toolbar, we get a point outside of the visible rect
            page = NSMouseInRect(center, [self visibleContentRect], [self isFlipped]) ? [self pageForPoint:center nearest:NO] : nil;
            
            if (page == nil) {
                // Get center of the PDFView.
                NSRect viewFrame = [self frame];
                center = SKCenterPoint(viewFrame);
                page = [self pageForPoint: center nearest: YES];
            }
            
            // Convert to "page space".
            center = [self convertPoint: center toPage: page];
            
            NSSize defaultSize = SKNPDFAnnotationNoteSize;
            if (preferNote == NO) {
                if ([str isKindOfClass:[NSAttributedString class]])
                    str = [str string];
                NSFont *font = [[NSUserDefaults standardUserDefaults] fontForNameKey:SKFreeTextNoteFontNameKey sizeKey:SKFreeTextNoteFontSizeKey];
                CGFloat width = [[NSUserDefaults standardUserDefaults] floatForKey:SKDefaultNoteWidthKey];
                defaultSize = SKFitTextNoteSize(str, font, width);
                if (([page rotation] % 180))
                    defaultSize = NSMakeSize(defaultSize.height, defaultSize.width);
            }
            
            NSRect bounds = SKRectFromCenterAndSize(center, defaultSize);
            bounds.origin = SKIntegralPoint(bounds.origin);
            bounds = SKConstrainRect(bounds, [page boundsForBox:[self displayBox]]);
            
            PDFAnnotation *newAnnotation = nil;
            
            if (preferNote) {
                newAnnotation = [[[SKNPDFAnnotationNote alloc] initSkimNoteWithBounds:bounds] autorelease];
                NSMutableAttributedString *attrString = nil;
                if ([str isKindOfClass:[NSString class]])
                    attrString = [[[NSMutableAttributedString alloc] initWithString:str] autorelease];
                else if ([str isKindOfClass:[NSAttributedString class]])
                    attrString = [[[NSMutableAttributedString alloc] initWithAttributedString:str] autorelease];
                if (isPlainText || [str isKindOfClass:[NSString class]]) {
                    NSFont *font = [[NSUserDefaults standardUserDefaults] fontForNameKey:SKAnchoredNoteFontNameKey sizeKey:SKAnchoredNoteFontSizeKey];
                    if (font)
                        [attrString setAttributes:@{NSFontAttributeName:font} range:NSMakeRange(0, [attrString length])];
                }
                [(SKNPDFAnnotationNote *)newAnnotation setText:attrString];
            } else {
                newAnnotation = [[[PDFAnnotationFreeText alloc] initSkimNoteWithBounds:bounds] autorelease];
                [newAnnotation setString:str];
            }
            
            [newAnnotation registerUserName];
            [self addAnnotation:newAnnotation toPage:page];
            [[self undoManager] setActionName:NSLocalizedString(@"Add Note", @"Undo action name")];

            [self setCurrentAnnotation:newAnnotation];
            
        } else {
            
            NSBeep();
            
        }
    }
}

- (IBAction)paste:(id)sender {
    [self pasteNote:NO plainText:NO];
}

- (IBAction)alternatePaste:(id)sender {
    [self pasteNote:YES plainText:NO];
}

- (IBAction)pasteAsPlainText:(id)sender {
    [self pasteNote:YES plainText:YES];
}

- (IBAction)cut:(id)sender
{
	if ([self hideNotes] == NO && [currentAnnotation isSkimNote]) {
        [self copy:sender];
        [self delete:sender];
    } else
        NSBeep();
}

- (IBAction)selectAll:(id)sender {
    [self setTemporaryToolMode:SKNoToolMode];
    if (toolMode == SKTextToolMode)
        [super selectAll:sender];
}

- (IBAction)deselectAll:(id)sender {
    [self setCurrentSelection:nil];
}

- (IBAction)autoSelectContent:(id)sender {
    if (toolMode == SKSelectToolMode) {
        PDFPage *page = [self currentPage];
        @synchronized (self) {
            selectionRect = NSIntersectionRect(NSUnionRect([page foregroundBox], selectionRect), [page boundsForBox:[self displayBox]]);
            selectionPageIndex = [page pageIndex];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewSelectionChangedNotification object:self];
        [self requiresDisplay];
    }
}

- (IBAction)changeToolMode:(id)sender {
    [self setToolMode:[sender tag]];
}

- (IBAction)changeAnnotationMode:(id)sender {
    [self setToolMode:SKNoteToolMode];
    [self setAnnotationMode:[sender tag]];
}

- (void)zoomLog:(id)sender {
    [self setScaleFactor:exp([sender doubleValue])];
}

- (void)toggleAutoActualSize:(id)sender {
    if ([self autoScales])
        [self setScaleFactor:1.0];
    else
        [self setAutoScales:YES];
    [self doAutoHideCursorIfNeeded];
}

- (void)_setSinglePageScrolling:(id)sender {
    [self setExtendedDisplayModeAndRewind:kPDFDisplaySinglePageContinuous];
}

- (void)_setDoublePageScrolling:(id)sender {
    [self setExtendedDisplayModeAndRewind:kPDFDisplayTwoUpContinuous];
}

- (void)_setDoublePage:(id)sender {
    [self setExtendedDisplayModeAndRewind:kPDFDisplayTwoUp];
}

- (void)setHorizontalScrolling:(id)sender {
    [self setExtendedDisplayModeAndRewind:kPDFDisplayHorizontalContinuous];
}

- (void)exitPresentation:(id)sender {
    if ([[self delegate] respondsToSelector:@selector(PDFViewExitPresentation:)])
        [[self delegate] PDFViewExitPresentation:self];
}

- (void)showColorsForThisAnnotation:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    if (annotation)
        [self setCurrentAnnotation:annotation];
    [[NSColorPanel sharedColorPanel] orderFront:sender];
}

- (void)showLinesForThisAnnotation:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    if (annotation)
        [self setCurrentAnnotation:annotation];
    [[[SKLineInspector sharedLineInspector] window] orderFront:sender];
}

- (void)showFontsForThisAnnotation:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    if (annotation)
        [self setCurrentAnnotation:annotation];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:sender];
}

- (void)zoomIn:(id)sender {
    zooming = YES;
    [super zoomIn:sender];
    zooming = NO;
}

- (void)zoomOut:(id)sender {
    zooming = YES;
    [super zoomOut:sender];
    zooming = NO;
}

- (void)setScaleFactor:(CGFloat)scale {
    zooming = YES;
    [super setScaleFactor:scale];
    zooming = NO;
}

- (void)zoomToPhysicalSize:(id)sender {
    [self setPhysicalScaleFactor:1.0];
}

// we don't want to steal the printDocument: action from the responder chain
- (void)printDocument:(id)sender{}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return aSelector != @selector(printDocument:) && [super respondsToSelector:aSelector];
}

- (BOOL)canZoomIn {
    return [[self document] isLocked] == NO && [super canZoomIn];
}

- (BOOL)canZoomOut {
    return [[self document] isLocked] == NO && [super canZoomOut];
}

- (BOOL)canGoToNextPage {
    return [[self document] isLocked] == NO && [super canGoToNextPage];
}

- (BOOL)canGoToPreviousPage {
    return [[self document] isLocked] == NO && [super canGoToPreviousPage];
}

- (BOOL)canGoToFirstPage {
    return [[self document] isLocked] == NO && [super canGoToFirstPage];
}

- (BOOL)canGoToLastPage {
    return [[self document] isLocked] == NO && [super canGoToLastPage];
}

- (BOOL)canGoBack {
    if ([[self document] isLocked])
        return NO;
    else if ([self respondsToSelector:@selector(currentHistoryIndex)] && minHistoryIndex > 0)
        return minHistoryIndex < [self currentHistoryIndex];
    else
        return [super canGoBack];
}

- (BOOL)canGoForward {
    return [[self document] isLocked] == NO && [super canGoForward];
}

- (void)checkSpelling:(id)sender {
    PDFSelection *selection = [self currentSelection];
    PDFPage *page;
    NSUInteger idx, i, first, iMax = [[self document] pageCount];
    BOOL didWrap = NO;
    NSRange range;
    
    if ([selection hasCharacters]) {
        page = [selection safeLastPage];
        idx = [selection safeIndexOfLastCharacterOnPage:page];
        if (idx == NSNotFound)
            idx = 0;
    } else {
        page = [self currentPage];
        idx = 0;
    }
    
    i = first = [page pageIndex];
    while (YES) {
        range = [[NSSpellChecker sharedSpellChecker] checkSpellingOfString:[page string] startingAt:idx language:nil wrap:NO inSpellDocumentWithTag:spellingTag wordCount:NULL];
        if (range.location != NSNotFound) break;
        if (didWrap && i == first) break;
        if (++i >= iMax) {
            i = 0;
            didWrap = YES;
        }
        page = [[self document] pageAtIndex:i];
        idx = 0;
    }
    
    [self setTemporaryToolMode:SKNoToolMode];
    
    if (range.location != NSNotFound) {
        selection = [page selectionForRange:range];
        [self setCurrentSelection:selection];
        [self goToRect:[selection boundsForPage:page] onPage:page];
        [[NSSpellChecker sharedSpellChecker] updateSpellingPanelWithMisspelledWord:[selection string]];
    } else NSBeep();
}

- (void)showGuessPanel:(id)sender {
    [self checkSpelling:sender];
    [[[NSSpellChecker sharedSpellChecker] spellingPanel] orderFront:self];
}

- (void)ignoreSpelling:(id)sender {
    [[NSSpellChecker sharedSpellChecker] ignoreWord:[[sender selectedCell] stringValue] inSpellDocumentWithTag:spellingTag];
}

- (void)toggleBlackout:(id)sender {
    NSView *documentView = [self documentView];
    [documentView setHidden:[documentView isHidden] == NO];
}

- (void)toggleLaserPointer:(id)sender {
    pdfvFlags.useArrowCursorInPresentation = pdfvFlags.useArrowCursorInPresentation == NO;
    [self setCursorForMouse:nil];
    [[NSUserDefaults standardUserDefaults] setBool:pdfvFlags.useArrowCursorInPresentation forKey:SKUseArrowCursorInPresentationKey];
}

- (void)nextLaserPointerColor:(id)sender {
    laserPointerColor = (laserPointerColor + 1) % 7;
    pdfvFlags.cursorHidden = 0;
    [self setCursorForMouse:nil];
    [self performSelectorOnce:@selector(doAutoHide) afterDelay:AUTO_HIDE_DELAY];
    [[NSUserDefaults standardUserDefaults] setInteger:laserPointerColor forKey:SKLaserPointerColorKey];
}

- (void)previousLaserPointerColor:(id)sender {
    laserPointerColor = (laserPointerColor + 6) % 7;
    pdfvFlags.cursorHidden = 0;
    [self setCursorForMouse:nil];
    [self performSelectorOnce:@selector(doAutoHide) afterDelay:AUTO_HIDE_DELAY];
    [[NSUserDefaults standardUserDefaults] setInteger:laserPointerColor forKey:SKLaserPointerColorKey];
}

- (void)nextToolMode:(id)sender {
    [self setToolMode:(toolMode + 1) % TOOL_MODE_COUNT];
}

- (void)moveCurrentAnnotation:(id)sender {
    [self doMoveCurrentAnnotationForKey:NSRightArrowFunctionKey byAmount:[sender tag] ? 10.0 : 1.0];
}

- (void)resizeCurrentAnnotation:(id)sender {
    [self doResizeCurrentAnnotationForKey:NSRightArrowFunctionKey byAmount:[sender tag] ? 10.0 : 1.0];
}

- (void)autoSizeCurrentAnnotation:(id)sender {
    [self doAutoSizeActiveNoteIgnoringWidth:[sender tag]];
}

- (void)changeOnlyAnnotationMode:(id)sender {
    [self setAnnotationMode:[sender tag]];
}

- (void)moveReadingBar:(id)sender {
    [self doMoveReadingBarForKey:NSDownArrowFunctionKey];
}

- (void)resizeReadingBar:(id)sender {
    [self doResizeReadingBarForKey:NSDownArrowFunctionKey];
}

#pragma mark Rewind

- (void)scrollToPage:(PDFPage *)page {
    if ([self isPageAtIndexDisplayed:[page pageIndex]] == NO) {
        [self goToPage:page];
        return;
    }
    PDFDisplayMode mode = [self extendedDisplayMode];
    if (mode != kPDFDisplaySinglePage) {
        NSScrollView *scrollView = [self scrollView];
        NSClipView *clipView = [scrollView contentView];
        NSRect bounds = [clipView bounds];
        CGFloat inset = [self convertSize:NSMakeSize(0.0, [scrollView contentInsets].top) toView:clipView].height;
        NSRect docRect = [[scrollView documentView] frame];
        NSRect pageRect = [self convertRect:[page boundsForBox:[self displayBox]] fromPage:page];
        if ([self displaysPageBreaks]) {
            CGFloat scale = [self scaleFactor];
            if (RUNNING_BEFORE(10_13)) {
                pageRect = NSInsetRect(pageRect, -4.0 * scale, -4.0 * scale);
            } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
                NSEdgeInsets margins = [self pageBreakMargins];
#pragma clang diagnostic pop
                pageRect = NSInsetRect(pageRect, -scale * margins.left, -scale * margins.bottom);
                pageRect.size.width += scale * (margins.right - margins.left);
                pageRect.size.height += scale * (margins.top - margins.bottom);
            }
        }
        pageRect = [self convertRect:pageRect toView:clipView];
        if ((mode & (kPDFDisplayHorizontalContinuous | kPDFDisplayTwoUp)) && NSWidth(docRect) > NSWidth(bounds)) {
            bounds.origin.x = fmin(fmax(fmin(NSMidX(pageRect) - 0.5 * NSWidth(bounds), NSMinX(pageRect)), NSMinX(docRect)), NSMaxX(docRect) - NSWidth(bounds));
        }
        if ((mode & kPDFDisplaySinglePageContinuous) && NSHeight(docRect) > NSHeight(bounds) - inset) {
            if ([clipView isFlipped])
                bounds.origin.y = fmin(fmax(fmin(NSMidY(pageRect) - 0.5 * (NSHeight(bounds) + inset), NSMinY(pageRect) - inset), NSMinY(docRect) - inset), NSMaxY(docRect) - NSHeight(bounds));
            else
                bounds.origin.y = fmin(fmax(fmax(NSMaxY(pageRect) - NSHeight(bounds) + inset, NSMidY(pageRect) - 0.5 * (NSHeight(bounds) - inset)), NSMinY(docRect)), NSMaxY(docRect) - NSHeight(bounds) + inset);
        }
        [clipView scrollToPoint:bounds.origin];
    }
}

- (BOOL)needsRewind {
    return rewindPage != nil;
}

- (void)setNeedsRewind:(BOOL)flag {
    if (flag) {
        [rewindPage release];
        rewindPage = [[self currentPage] retain];
        DISPATCH_MAIN_AFTER_SEC(0.25, ^{
            if (rewindPage) {
                if ([[self currentPage] isEqual:rewindPage] == NO)
                    [self scrollToPage:rewindPage];
                SKDESTROY(rewindPage);
            }
        });
    } else {
        SKDESTROY(rewindPage);
    }
}

#pragma mark Event Handling

// PDFView has duplicated key equivalents for Cmd-+/- as well as Opt-Cmd-+/-, which is totoally unnecessary and harmful
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent { return NO; }

#define IS_LEFT_RIGHT_ARROW(eventChar) (eventChar == NSRightArrowFunctionKey || eventChar == NSLeftArrowFunctionKey)
#define IS_UP_DOWN_ARROW(eventChar) (eventChar == NSUpArrowFunctionKey || eventChar == NSDownArrowFunctionKey)
#define IS_ARROW(eventChar) (eventChar == NSRightArrowFunctionKey || eventChar == NSLeftArrowFunctionKey || eventChar == NSUpArrowFunctionKey || eventChar == NSDownArrowFunctionKey)
#define IS_ENTER(eventChar) (eventChar == NSEnterCharacter || eventChar == NSFormFeedCharacter || eventChar == NSNewlineCharacter || eventChar == NSCarriageReturnCharacter)

- (void)keyDown:(NSEvent *)theEvent
{
    unichar eventChar = [theEvent firstCharacter];
	NSUInteger modifiers = [theEvent standardModifierFlags];
    
    if (interactionMode == SKPresentationMode) {
        // Presentation mode
        if ([[self scrollView] hasHorizontalScroller] == NO && 
            (eventChar == NSRightArrowFunctionKey) &&  (modifiers == 0)) {
            [self goToNextPage:self];
        } else if ([[self scrollView] hasHorizontalScroller] == NO && 
                   (eventChar == NSLeftArrowFunctionKey) &&  (modifiers == 0)) {
            [self goToPreviousPage:self];
        } else if ((eventChar == 'p') && (modifiers == 0)) {
            if ([[self delegate] respondsToSelector:@selector(PDFViewTogglePages:)])
                [[self delegate] PDFViewTogglePages:self];
        } else if ((eventChar == 't') && (modifiers == 0)) {
            if ([[self delegate] respondsToSelector:@selector(PDFViewToggleContents:)])
                [[self delegate] PDFViewToggleContents:self];
        } else if ((eventChar == 'a') && (modifiers == 0)) {
            [self toggleAutoActualSize:self];
        } else if ((eventChar == 'b') && (modifiers == 0)) {
            [self toggleBlackout:self];
        } else if ((eventChar == 'l') && (modifiers == 0)) {
            [self toggleLaserPointer:nil];
        } else if (pdfvFlags.useArrowCursorInPresentation == 0 && (eventChar == 'c') && (modifiers == 0)) {
            [self nextLaserPointerColor:nil];
        } else if (pdfvFlags.useArrowCursorInPresentation == 0 && (eventChar == 'C') && ((modifiers & ~NSShiftKeyMask) == 0)) {
            [self previousLaserPointerColor:nil];
        } else if ((eventChar == '?') && ((modifiers & ~NSShiftKeyMask) == 0)) {
            [self showHelpMenu];
        } else {
            [super keyDown:theEvent];
        }
    } else {
        // Normal or fullscreen mode
        if ((eventChar == NSDeleteCharacter || eventChar == NSDeleteFunctionKey) &&
            (modifiers == 0)) {
            [self delete:self];
        } else if (([self toolMode] == SKTextToolMode || [self toolMode] == SKNoteToolMode) && currentAnnotation && editor == nil && IS_ENTER(eventChar) && (modifiers == 0)) {
            [self editCurrentAnnotation:self];
        } else if (([self toolMode] == SKTextToolMode || [self toolMode] == SKNoteToolMode) && 
                   (eventChar == SKEscapeCharacter) && (modifiers == NSAlternateKeyMask)) {
            [self setCurrentAnnotation:nil];
        } else if (([self toolMode] == SKTextToolMode || [self toolMode] == SKNoteToolMode) && 
                   (eventChar == NSTabCharacter) && (modifiers == NSAlternateKeyMask)) {
            [self selectNextCurrentAnnotation:self];
        // backtab is a bit inconsistent, it seems Shift+Tab gives a Shift-BackTab key event, I would have expected either Shift-Tab (as for the raw event) or BackTab (as for most shift-modified keys)
        } else if (([self toolMode] == SKTextToolMode || [self toolMode] == SKNoteToolMode) && 
                   (((eventChar == NSBackTabCharacter) && ((modifiers & ~NSShiftKeyMask) == NSAlternateKeyMask)) || 
                    ((eventChar == NSTabCharacter) && (modifiers == (NSAlternateKeyMask | NSShiftKeyMask))))) {
            [self selectPreviousCurrentAnnotation:self];
        } else if ([self hasReadingBar] && IS_ARROW(eventChar) && (modifiers == moveReadingBarModifiers)) {
            [self doMoveReadingBarForKey:eventChar];
        } else if ([self hasReadingBar] && IS_UP_DOWN_ARROW(eventChar) && (modifiers == resizeReadingBarModifiers)) {
            [self doResizeReadingBarForKey:eventChar];
        } else if (IS_LEFT_RIGHT_ARROW(eventChar) && (modifiers == (NSAlternateKeyMask | NSCommandKeyMask))) {
            [self setToolMode:(toolMode + (eventChar == NSRightArrowFunctionKey ? 1 : TOOL_MODE_COUNT - 1)) % TOOL_MODE_COUNT];
        } else if (IS_UP_DOWN_ARROW(eventChar) && (modifiers == (NSAlternateKeyMask | NSCommandKeyMask))) {
            [self setAnnotationMode:(annotationMode + (eventChar == NSDownArrowFunctionKey ? 1 : ANNOTATION_MODE_COUNT - 1)) % ANNOTATION_MODE_COUNT];
        } else if ([currentAnnotation isMovable] && IS_ARROW(eventChar) && ((modifiers & ~NSShiftKeyMask) == 0)) {
            [self doMoveCurrentAnnotationForKey:eventChar byAmount:(modifiers & NSShiftKeyMask) ? 10.0 : 1.0];
        } else if ([currentAnnotation isResizable] && IS_ARROW(eventChar) && (modifiers == (NSAlternateKeyMask | NSControlKeyMask) || modifiers == (NSShiftKeyMask | NSControlKeyMask))) {
            [self doResizeCurrentAnnotationForKey:eventChar byAmount:(modifiers & NSShiftKeyMask) ? 10.0 : 1.0];
        // with some keyboard layouts, e.g. Japanese, the '=' character requires Shift
        } else if ([currentAnnotation isResizable] && [currentAnnotation isLine] == NO && [currentAnnotation isInk] == NO && (eventChar == '=') && ((modifiers & ~(NSAlternateKeyMask | NSShiftKeyMask)) == NSControlKeyMask)) {
            [self doAutoSizeActiveNoteIgnoringWidth:(modifiers & NSAlternateKeyMask) != 0];
        } else if ([self toolMode] == SKNoteToolMode && (eventChar == 't') && (modifiers == 0)) {
            [self setAnnotationMode:SKFreeTextNote];
        } else if ([self toolMode] == SKNoteToolMode && (eventChar == 'n') && (modifiers == 0)) {
            [self setAnnotationMode:SKAnchoredNote];
        } else if ([self toolMode] == SKNoteToolMode && (eventChar == 'c') && (modifiers == 0)) {
            [self setAnnotationMode:SKCircleNote];
        } else if ([self toolMode] == SKNoteToolMode && (eventChar == 'b') && (modifiers == 0)) {
            [self setAnnotationMode:SKSquareNote];
        } else if ([self toolMode] == SKNoteToolMode && (eventChar == 'h') && (modifiers == 0)) {
            [self setAnnotationMode:SKHighlightNote];
        } else if ([self toolMode] == SKNoteToolMode && (eventChar == 'u') && (modifiers == 0)) {
            [self setAnnotationMode:SKUnderlineNote];
        } else if ([self toolMode] == SKNoteToolMode && (eventChar == 's') && (modifiers == 0)) {
            [self setAnnotationMode:SKStrikeOutNote];
        } else if ([self toolMode] == SKNoteToolMode && (eventChar == 'l') && (modifiers == 0)) {
            [self setAnnotationMode:SKLineNote];
        } else if ([self toolMode] == SKNoteToolMode && (eventChar == 'f') && (modifiers == 0)) {
            [self setAnnotationMode:SKInkNote];
        } else if ((eventChar == '?') && ((modifiers & ~NSShiftKeyMask) == 0)) {
            [self showHelpMenu];
        } else if ([typeSelectHelper handleEvent:theEvent] == NO) {
            [super keyDown:theEvent];
        }
        
    }
}

#define IS_TABLET_EVENT(theEvent, deviceType) (([theEvent subtype] == NSTabletProximityEventSubtype || [theEvent subtype] == NSTabletPointEventSubtype) && [NSEvent currentPointingDeviceType] == deviceType)

- (void)mouseDown:(NSEvent *)theEvent{
    if ([currentAnnotation isLink])
        [self setCurrentAnnotation:nil];
    
    // 10.6 does not automatichally make us firstResponder, that's annoying
    // but we don't want an edited text note to stop editing when we're resizing it
    if ([[[self window] firstResponder] isDescendantOf:self] == NO)
        [[self window] makeFirstResponder:self];
    
	NSUInteger modifiers = [theEvent standardModifierFlags];
    PDFAreaOfInterest area = [self areaOfInterestForMouse:theEvent];
    PDFAnnotation *wasCurrentAnnotation = currentAnnotation;
    
    if ((modifiers & NSCommandKeyMask) != 0)
        [self setTemporaryToolMode:SKNoToolMode];
    
    if ([[self document] isLocked]) {
        [self setTemporaryToolMode:SKNoToolMode];
        [super mouseDown:theEvent];
    } else if (interactionMode == SKPresentationMode) {
        [self setTemporaryToolMode:SKNoToolMode];
        BOOL didHideMouse = pdfvFlags.cursorHidden;
        if (pdfvFlags.hideNotes == NO && [[self document] allowsNotes] && IS_TABLET_EVENT(theEvent, NSPenPointingDevice)) {
            [[NSCursor arrowCursor] set];
            [self doDrawFreehandNoteWithEvent:theEvent];
            [self setCurrentAnnotation:nil];
        } else if ((area & kPDFLinkArea)) {
            [super mouseDown:theEvent];
        } else if (([[self window] styleMask] & NSResizableWindowMask) != 0 && [NSApp willDragMouse]) {
            [[NSCursor closedHandCursor] set];
            [self doDragWindowWithEvent:theEvent];
        } else {
            [self goToNextPage:self];
            // Eat up drag events because we don't want to select
            [self doDragMouseWithEvent:theEvent];
        }
        if (didHideMouse) {
            [self doAutoHideCursor];
        } else {
            [self updateCursorForMouse:nil];
            [self performSelectorOnce:@selector(doAutoHideCursor) afterDelay:AUTO_HIDE_DELAY];
        }
    } else if (modifiers == NSCommandKeyMask) {
        BOOL wantsLoupe = [loupeController hide];
        [self doSelectSnapshotWithEvent:theEvent];
        if (wantsLoupe)
            [loupeController update];
    } else if (modifiers == (NSCommandKeyMask | NSShiftKeyMask)) {
        BOOL wantsLoupe = [loupeController hide];
        [self doPdfsyncWithEvent:theEvent];
        if (wantsLoupe)
            [loupeController update];
    } else if (modifiers == (NSCommandKeyMask | NSAlternateKeyMask)) {
        BOOL wantsLoupe = [loupeController hide];
        [self doMarqueeZoomWithEvent:theEvent];
        if (wantsLoupe)
            [loupeController update];
    } else if ((area & SKReadingBarArea) && (area & kPDFLinkArea) == 0) {
        [self setTemporaryToolMode:SKNoToolMode];
        BOOL wantsLoupe = [loupeController hide];
        if ((area & (SKResizeUpDownArea | SKResizeLeftRightArea | SKResizeRightArea | SKResizeUpArea | SKResizeLeftArea | SKResizeDownArea)))
            [self doResizeReadingBarWithEvent:theEvent];
        else
            [self doDragReadingBarWithEvent:theEvent];
        if (wantsLoupe)
            [loupeController update];
    } else if ((area & kPDFPageArea) == 0) {
        [self doDragWithEvent:theEvent];
    } else if (temporaryToolMode != SKNoToolMode && (modifiers & NSCommandKeyMask) == 0) {
        BOOL wantsLoupe = [loupeController hide];
        if (temporaryToolMode == SKZoomToolMode) {
            [self doMarqueeZoomWithEvent:theEvent];
        } else if (temporaryToolMode == SKSnapshotToolMode) {
            [self doSelectSnapshotWithEvent:theEvent];
        } else if (temporaryToolMode == SKInkToolMode) {
            [self doDrawFreehandNoteWithEvent:theEvent];
        } else {
            [self setCurrentAnnotation:nil];
            [super mouseDown:theEvent];
            if ([[self currentSelection] hasCharacters]) {
                [self addAnnotationWithType:(SKNoteType)temporaryToolMode];
                [self setCurrentSelection:nil];
            }
        }
        [self setTemporaryToolMode:SKNoToolMode];
        if (wantsLoupe)
            [loupeController update];
    } else if (toolMode == SKMoveToolMode) {
        [self setCurrentSelection:nil];
        if ((area & kPDFLinkArea))
            [super mouseDown:theEvent];
        else
            [self doDragWithEvent:theEvent];	
    } else if (toolMode == SKSelectToolMode) {
        [self setCurrentSelection:nil];                
        [self doSelectWithEvent:theEvent];
    } else if (toolMode == SKMagnifyToolMode) {
        [self setCurrentSelection:nil];
        [self doMagnifyWithEvent:theEvent];
    } else if (pdfvFlags.hideNotes == NO && [[self document] allowsNotes] && IS_TABLET_EVENT(theEvent, NSEraserPointingDevice)) {
        [self doEraseAnnotationsWithEvent:theEvent];
    } else if ([self doSelectAnnotationWithEvent:theEvent]) {
        if ([currentAnnotation isLink]) {
            [self doClickLinkWithEvent:theEvent];
        } else if ([theEvent clickCount] == 1 && [currentAnnotation isText] && currentAnnotation == wasCurrentAnnotation && [NSApp willDragMouse] == NO) {
            [self editTextNoteWithEvent:theEvent];
        } else if ([theEvent clickCount] == 2 && [currentAnnotation isEditable]) {
            if ([self doDragMouseWithEvent:theEvent] == NO)
                [self editCurrentAnnotation:nil];
        } else if ([currentAnnotation isMovable]) {
            [self doDragAnnotationWithEvent:theEvent];
        } else {
            [self doDragMouseWithEvent:theEvent];
        }
    } else if (toolMode == SKNoteToolMode && pdfvFlags.hideNotes == NO && [[self document] allowsNotes] && IS_MARKUP(annotationMode) == NO) {
        if (annotationMode == SKInkNote) {
            [self doDrawFreehandNoteWithEvent:theEvent];
        } else {
            [self setCurrentAnnotation:nil];
            [self doDragAnnotationWithEvent:theEvent];
        }
    } else if ((area & SKDragArea)) {
        [self setCurrentAnnotation:nil];
        [self doDragWithEvent:theEvent];
    } else if ([self doDragTextWithEvent:theEvent] == NO) {
        [self setCurrentAnnotation:nil];
        [super mouseDown:theEvent];
        if ((toolMode == SKNoteToolMode && pdfvFlags.hideNotes == NO && [[self document] allowsNotes] && IS_MARKUP(annotationMode)) && [[self currentSelection] hasCharacters]) {
            [self addAnnotationWithType:annotationMode];
            [self setCurrentSelection:nil];
        }
    }
}

- (void)mouseMoved:(NSEvent *)theEvent {
    pdfvFlags.cursorHidden = NO;
    
    if (interactionMode != SKPresentationMode)
        [super mouseMoved:theEvent];
    
    if (toolMode == SKMagnifyToolMode && loupeController) {
        [loupeController update];
    } else {
        
        // make sure the cursor is set, at least outside the pages this does not happen
        [self setCursorForMouse:theEvent];
        
        if ([currentAnnotation isLink]) {
            [[SKImageToolTipWindow sharedToolTipWindow] fadeOut];
            [self setCurrentAnnotation:nil];
        }
    }
    
    if (navWindow && [navWindow isVisible] == NO) {
        if (navigationMode == SKNavigationEverywhere && NSPointInRect([theEvent locationInWindow], [[[self window] contentView] frame])) {
            [navWindow showForWindow:[self window]];
            NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor([self documentView]), NSAccessibilityLayoutChangedNotification, [NSDictionary dictionaryWithObjectsAndKeys:NSAccessibilityUnignoredChildrenForOnlyChild(navWindow), NSAccessibilityUIElementsKey, nil]);
        } else if (navigationMode == SKNavigationBottom && NSPointInRect([theEvent locationInWindow], SKSliceRect([[[self window] contentView] frame], NAVIGATION_BOTTOM_EDGE_HEIGHT, NSMinYEdge))) {
            [self performSelectorOnce:@selector(showNavWindow) afterDelay:SHOW_NAV_DELAY];
        }
    }
    if (navigationMode != SKNavigationNone || interactionMode == SKPresentationMode)
        [self performSelectorOnce:@selector(doAutoHide) afterDelay:AUTO_HIDE_DELAY];
}

- (void)flagsChanged:(NSEvent *)theEvent {
    [super flagsChanged:theEvent];
    [self setCursorForMouse:nil];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *menu = [super menuForEvent:theEvent];
    NSMenu *submenu;
    NSMenuItem *item;
    NSInteger i = 0;
    
    if ([[menu itemAtIndex:0] view] != nil) {
        [menu removeItemAtIndex:0];
        if ([[menu itemAtIndex:0] isSeparatorItem])
            [menu removeItemAtIndex:0];
    }
    
    static NSSet *annotationActions = nil;
    if (annotationActions == nil)
        annotationActions = [[NSSet alloc] initWithObjects:@"_removeNote:", @"_removeMarkup:", nil];
    while ([menu numberOfItems] > 0) {
        item = [menu itemAtIndex:0];
        if ([item isSeparatorItem] || [annotationActions containsObject:NSStringFromSelector([item action])])
            [menu removeItemAtIndex:0];
        else
            break;
    }
    
    // On Leopard the selection is automatically set. In some cases we never want a selection though.
    if ((interactionMode == SKPresentationMode) || (toolMode != SKTextToolMode && [[self currentSelection] hasCharacters])) {
        static NSSet *selectionActions = nil;
        if (selectionActions == nil)
            selectionActions = [[NSSet alloc] initWithObjects:@"_searchInSpotlight:", @"_searchInGoogle:", @"_searchInDictionary:", @"_revealSelection:", nil];
        [self setCurrentSelection:nil];
        BOOL allowsSeparator = NO;
        while ([menu numberOfItems] > i) {
            item = [menu itemAtIndex:i];
            if ([item isSeparatorItem]) {
                if (allowsSeparator) {
                    i++;
                    allowsSeparator = NO;
                } else {
                    [menu removeItemAtIndex:i];
                }
            } else if ([self validateMenuItem:item] == NO || [selectionActions containsObject:NSStringFromSelector([item action])]) {
                [menu removeItemAtIndex:i];
            } else {
                i++;
                allowsSeparator = YES;
            }
        }
    }
    
    if (interactionMode == SKPresentationMode)
        return menu;
    
    NSValue *pointValue = [NSValue valueWithPoint:[theEvent locationInView:self]];
    
    i = [menu indexOfItemWithTarget:self andAction:@selector(copy:)];
    if (i != -1) {
        [menu removeItemAtIndex:i];
        if ([menu numberOfItems] > i && [[menu itemAtIndex:i] isSeparatorItem] && (i == 0 || [[menu itemAtIndex:i - 1] isSeparatorItem]))
            [menu removeItemAtIndex:i];
        if (i > 0 && i == [menu numberOfItems] && [[menu itemAtIndex:i - 1] isSeparatorItem])
            [menu removeItemAtIndex:i - 1];
    }
    
    i = [menu indexOfItemWithTarget:self andAction:NSSelectorFromString(@"_setActualSize:")];
    if (i != -1) {
        item = [menu insertItemWithTitle:NSLocalizedString(@"Physical Size", @"Menu item title") action:@selector(zoomToPhysicalSize:) target:self atIndex:i + 1];
        [item setKeyEquivalentModifierMask:NSAlternateKeyMask];
        [item setAlternate:YES];
    }
    
    i = [menu indexOfItemWithTarget:self andAction:NSSelectorFromString(@"_setDoublePageScrolling:")];
    if (i != -1) {
        if (RUNNING_AFTER(10_12)) {
            [menu insertItem:[NSMenuItem separatorItem] atIndex:i + 1];
            item = [menu insertItemWithTitle:NSLocalizedString(@"Horizontal Continuous", @"Menu item title") action:@selector(setHorizontalScrolling:) target:self atIndex:i + 1];
        }
    }
    
    [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
    
    item = [menu insertItemWithSubmenuAndTitle:NSLocalizedString(@"Tools", @"Menu item title") atIndex:0];
    submenu = [item submenu];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Text", @"Menu item title") action:@selector(changeToolMode:) target:self tag:SKTextToolMode];

    [submenu addItemWithTitle:NSLocalizedString(@"Scroll", @"Menu item title") action:@selector(changeToolMode:) target:self tag:SKMoveToolMode];

    [submenu addItemWithTitle:NSLocalizedString(@"Magnify", @"Menu item title") action:@selector(changeToolMode:) target:self tag:SKMagnifyToolMode];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Select", @"Menu item title") action:@selector(changeToolMode:) target:self tag:SKSelectToolMode];
    
    [submenu addItem:[NSMenuItem separatorItem]];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKFreeTextNote];

    [submenu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKAnchoredNote];

    [submenu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKCircleNote];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKSquareNote];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKHighlightNote];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKUnderlineNote];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKStrikeOutNote];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKLineNote];
    
    [submenu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") action:@selector(changeAnnotationMode:) target:self tag:SKInkNote];
    
    [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
    
    item = [menu insertItemWithTitle:NSLocalizedString(@"Take Snapshot", @"Menu item title") action:@selector(takeSnapshot:) target:self atIndex:0];
    [item setRepresentedObject:pointValue];
    
    if (([self toolMode] == SKTextToolMode || [self toolMode] == SKNoteToolMode) && [self hideNotes] == NO && [[self document] allowsNotes]) {
        
        [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
        
        item = [menu insertItemWithSubmenuAndTitle:NSLocalizedString(@"New Note or Highlight", @"Menu item title") atIndex:0];
        submenu = [item submenu];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") action:@selector(addAnnotationForContext:) target:self tag:SKFreeTextNote];
        [item setRepresentedObject:pointValue];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") action:@selector(addAnnotationForContext:) target:self tag:SKAnchoredNote];
        [item setRepresentedObject:pointValue];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") action:@selector(addAnnotationForContext:) target:self tag:SKCircleNote];
        [item setRepresentedObject:pointValue];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") action:@selector(addAnnotationForContext:) target:self tag:SKSquareNote];
        [item setRepresentedObject:pointValue];
        
        if ([[self currentSelection] hasCharacters]) {
            item = [submenu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") action:@selector(addAnnotationForContext:) target:self tag:SKHighlightNote];
            [item setRepresentedObject:pointValue];
            
            item = [submenu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") action:@selector(addAnnotationForContext:) target:self tag:SKUnderlineNote];
            [item setRepresentedObject:pointValue];
            
            item = [submenu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") action:@selector(addAnnotationForContext:) target:self tag:SKStrikeOutNote];
            [item setRepresentedObject:pointValue];
        }
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") action:@selector(addAnnotationForContext:) target:self tag:SKLineNote];
        [item setRepresentedObject:pointValue];
        
        [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
        
        NSPoint point = NSZeroPoint;
        PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:YES];
        PDFAnnotation *annotation = nil;
        
        if (page) {
            annotation = [page annotationAtPoint:point];
            if ([annotation isSkimNote] == NO)
                annotation = nil;
        }
        
        if (annotation) {
            SKColorMenuView *menuView = [[[SKColorMenuView alloc] initWithAnnotation:annotation] autorelease];
            item = [menu insertItemWithTitle:@"" action:NULL target:nil atIndex:0];
            [item setView:menuView];
            
            [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
            
            if ((annotation != currentAnnotation || [NSFontPanel sharedFontPanelExists] == NO || [[NSFontPanel sharedFontPanel] isVisible] == NO) &&
                [annotation isText]) {
                item = [menu insertItemWithTitle:[NSLocalizedString(@"Note Font", @"Menu item title") stringByAppendingEllipsis] action:@selector(showFontsForThisAnnotation:) target:self atIndex:0];
                [item setRepresentedObject:annotation];
            }
            
            if ((annotation != currentAnnotation || [SKLineInspector sharedLineInspectorExists] == NO || [[[SKLineInspector sharedLineInspector] window] isVisible] == NO) &&
                [annotation isMarkup] == NO && [annotation isNote] == NO) {
                item = [menu insertItemWithTitle:[NSLocalizedString(@"Note Line", @"Menu item title") stringByAppendingEllipsis] action:@selector(showLinesForThisAnnotation:) target:self atIndex:0];
                [item setRepresentedObject:annotation];
            }
            
            if (annotation != currentAnnotation || [NSColorPanel sharedColorPanelExists] == NO || [[NSColorPanel sharedColorPanel] isVisible] == NO) {
                item = [menu insertItemWithTitle:[NSLocalizedString(@"Note Color", @"Menu item title") stringByAppendingEllipsis] action:@selector(showColorsForThisAnnotation:) target:self atIndex:0];
                [item setRepresentedObject:annotation];
            }
            
            if ([self isEditingAnnotation:annotation] == NO && [annotation isEditable]) {
                item = [menu insertItemWithTitle:NSLocalizedString(@"Edit Note", @"Menu item title") action:@selector(editThisAnnotation:) target:self atIndex:0];
                [item setRepresentedObject:annotation];
            }
            
            item = [menu insertItemWithTitle:NSLocalizedString(@"Remove Note", @"Menu item title") action:@selector(removeThisAnnotation:) target:self atIndex:0];
            [item setRepresentedObject:annotation];
        } else if ([currentAnnotation isSkimNote]) {
            SKColorMenuView *menuView = [[[SKColorMenuView alloc] initWithAnnotation:currentAnnotation] autorelease];
            item = [menu insertItemWithTitle:@"" action:NULL target:nil atIndex:0];
            [item setView:menuView];
            
            [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
            
            if (([NSFontPanel sharedFontPanelExists] == NO || [[NSFontPanel sharedFontPanel] isVisible] == NO) &&
                [currentAnnotation isText]) {
                [menu insertItemWithTitle:[NSLocalizedString(@"Note Font", @"Menu item title") stringByAppendingEllipsis] action:@selector(showFontsForThisAnnotation:) target:self atIndex:0];
            }
            
            if (([SKLineInspector sharedLineInspectorExists] == NO || [[[SKLineInspector sharedLineInspector] window] isVisible] == NO) &&
                [currentAnnotation isMarkup] == NO && [currentAnnotation isNote] == NO) {
                [menu insertItemWithTitle:[NSLocalizedString(@"Current Note Line", @"Menu item title") stringByAppendingEllipsis] action:@selector(showLinesForThisAnnotation:) target:self atIndex:0];
            }
            
            if ([NSColorPanel sharedColorPanelExists] == NO || [[NSColorPanel sharedColorPanel] isVisible] == NO) {
                [menu insertItemWithTitle:[NSLocalizedString(@"Current Note Color", @"Menu item title") stringByAppendingEllipsis] action:@selector(showColorsForThisAnnotation:) target:self atIndex:0];
            }
            
            if (editor == nil && [currentAnnotation isEditable]) {
                [menu insertItemWithTitle:NSLocalizedString(@"Edit Current Note", @"Menu item title") action:@selector(editCurrentAnnotation:) target:self atIndex:0];
            }
            
            [menu insertItemWithTitle:NSLocalizedString(@"Remove Current Note", @"Menu item title") action:@selector(removeCurrentAnnotation:) target:self atIndex:0];
        }
        
        if ([[NSPasteboard generalPasteboard] canReadObjectForClasses:@[[PDFAnnotation class], [NSString class]] options:@{}]) {
            [menu insertItemWithTitle:NSLocalizedString(@"Paste", @"Menu item title") action:@selector(paste:) keyEquivalent:@"" atIndex:0];
            item = [menu insertItemWithTitle:NSLocalizedString(@"Paste", @"Menu item title") action:@selector(alternatePaste:) keyEquivalent:@"" atIndex:1];
            [item setKeyEquivalentModifierMask:NSAlternateKeyMask];
            [item setAlternate:YES];
        }
        
        if (([currentAnnotation isSkimNote] && [currentAnnotation isMovable]) || [[self currentSelection] hasCharacters]) {
            if ([currentAnnotation isSkimNote] && [currentAnnotation isMovable])
                [menu insertItemWithTitle:NSLocalizedString(@"Cut", @"Menu item title") action:@selector(cut:) keyEquivalent:@"" atIndex:0];
            [menu insertItemWithTitle:NSLocalizedString(@"Copy", @"Menu item title") action:@selector(copy:) keyEquivalent:@"" atIndex:0];
        }
        
        if ([[menu itemAtIndex:0] isSeparatorItem])
            [menu removeItemAtIndex:0];
        
    } else if ((toolMode == SKSelectToolMode && NSIsEmptyRect(selectionRect) == NO) || ([self toolMode] == SKTextToolMode && [self hideNotes] && [[self currentSelection] hasCharacters])) {
        
        [menu insertItem:[NSMenuItem separatorItem] atIndex:0];
        
        [menu insertItemWithTitle:NSLocalizedString(@"Copy", @"Menu item title") action:@selector(copy:) keyEquivalent:@"" atIndex:0];
        
    }
    
    return menu;
}

- (void)magnifyWheel:(NSEvent *)theEvent {
    CGFloat dy = [theEvent deltaY];
    dy = dy > 0 ? fmin(0.2, dy) : fmax(-0.2, dy);
    [self setScaleFactor:[self scaleFactor] * exp(0.5 * dy)];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    NSTrackingArea *eventArea = [theEvent trackingArea];
    PDFAnnotation *annotation;
    if ([eventArea owner] == self && [eventArea isEqual:trackingArea]) {
        [[self window] setAcceptsMouseMovedEvents:YES];
    } else if ([eventArea owner] == self && (annotation = [[eventArea userInfo] objectForKey:SKAnnotationKey])) {
        [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:annotation scale:[self scaleFactor] atPoint:NSZeroPoint];
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        [super mouseEntered:theEvent];
    }
}
 
- (void)mouseExited:(NSEvent *)theEvent {
    NSTrackingArea *eventArea = [theEvent trackingArea];
    PDFAnnotation *annotation;
    if ([eventArea owner] == self && [eventArea isEqual:trackingArea]) {
        [[self window] setAcceptsMouseMovedEvents:NO];
        [[NSCursor arrowCursor] set];
        if (toolMode == SKMagnifyToolMode)
            [loupeController hide];
    } else if ([eventArea owner] == self && (annotation = [[eventArea userInfo] objectForKey:SKAnnotationKey])) {
        if ([annotation isEqual:[[SKImageToolTipWindow sharedToolTipWindow] currentImageContext]])
            [[SKImageToolTipWindow sharedToolTipWindow] fadeOut];
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        [super mouseExited:theEvent];
    }
}

- (void)rotatePageAtIndex:(NSUInteger)idx by:(NSInteger)rotation {
    NSUndoManager *undoManager = [self undoManager];
    [[undoManager prepareWithInvocationTarget:self] rotatePageAtIndex:idx by:-rotation];
    [undoManager setActionName:NSLocalizedString(@"Rotate Page", @"Undo action name")];
    NSDocument *doc = [[self delegate] respondsToSelector:@selector(document)] ? [(NSWindowController *)[self delegate] document] : [[[self window] windowController] document];
    [doc undoableActionIsDiscardable];
    
    PDFPage *page = [[self document] pageAtIndex:idx];
    [page setRotation:[page rotation] + rotation];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFPageBoundsDidChangeNotification 
                                                        object:[self document] userInfo:@{SKPDFPageActionKey:SKPDFPageActionRotate, SKPDFPagePageKey:page}];
}

- (void)beginGestureWithEvent:(NSEvent *)theEvent {
    [super beginGestureWithEvent:theEvent];
    PDFPage *page = [self pageAndPoint:NULL forEvent:theEvent nearest:YES];
    gestureRotation = 0.0;
    gesturePageIndex = [(page ?: [self currentPage]) pageIndex];
}

- (void)endGestureWithEvent:(NSEvent *)theEvent {
    [super endGestureWithEvent:theEvent];
    gestureRotation = 0.0;
    gesturePageIndex = NSNotFound;
}

- (void)rotateWithEvent:(NSEvent *)theEvent {
    if (interactionMode == SKPresentationMode)
        return;
    if ([theEvent phase] == NSEventPhaseBegan) {
        PDFPage *page = [self pageAndPoint:NULL forEvent:theEvent nearest:YES];
        gestureRotation = 0.0;
        gesturePageIndex = [(page ?: [self currentPage]) pageIndex];
    }
    gestureRotation -= [theEvent rotation];
    if (fabs(gestureRotation) > 45.0 && gesturePageIndex != NSNotFound) {
        CGFloat rotation = 90.0 * round(gestureRotation / 90.0);
        [self rotatePageAtIndex:gesturePageIndex by:rotation];
        gestureRotation -= rotation;
    }
    if (([theEvent phase] == NSEventPhaseEnded || [theEvent phase] == NSEventPhaseCancelled)) {
        gestureRotation = 0.0;
        gesturePageIndex = NSNotFound;
    }
}

- (void)magnifyWithEvent:(NSEvent *)theEvent {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisablePinchZoomKey] == NO && interactionMode != SKPresentationMode)
        [super magnifyWithEvent:theEvent];
}

- (void)swipeWithEvent:(NSEvent *)theEvent {
    if (interactionMode == SKPresentationMode && [transitionController hasTransition]) {
        if ([theEvent deltaX] < 0.0 || [theEvent deltaY] < 0.0) {
            if ([self canGoToNextPage])
                [self goToNextPage:nil];
        } else if ([theEvent deltaX] > 0.0 || [theEvent deltaY] > 0.0) {
            if ([self canGoToPreviousPage])
                [self goToPreviousPage:nil];
        }
    } else {
        [super swipeWithEvent:theEvent];
    }
}

#pragma mark NSDraggingDestination protocol

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSDragOperation dragOp = NSDragOperationNone;
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor, SKPasteboardTypeLineStyle]]) {
        return [self draggingUpdated:sender];
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        dragOp = [super draggingEntered:sender];
    }
    return dragOp;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    NSDragOperation dragOp = NSDragOperationNone;
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor, SKPasteboardTypeLineStyle]]) {
        NSPoint location = [self convertPoint:[sender draggingLocation] fromView:nil];
        PDFPage *page = [self pageForPoint:location nearest:NO];
        if (page) {
            NSArray *annotations = [page annotations];
            PDFAnnotation *annotation = nil;
            NSInteger i = [annotations count];
            location = [self convertPoint:location toPage:page];
            while (i-- > 0) {
                annotation = [annotations objectAtIndex:i];
                if ([annotation isSkimNote] && [annotation hitTest:location] &&
                    ([pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor]] || [annotation hasBorder])) {
                    [self setHighlightAnnotation:annotation];
                    dragOp = NSDragOperationGeneric;
                    break;
                }
            }
        }
        if (dragOp == NSDragOperationNone)
            [self setHighlightAnnotation:nil];
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        dragOp = [super draggingUpdated:sender];
    }
    return dragOp;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor, SKPasteboardTypeLineStyle]])
        [self setHighlightAnnotation:nil];
    else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd])
        [super draggingExited:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    BOOL performedDrag = NO;
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ([pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor, SKPasteboardTypeLineStyle]]) {
        if (highlightAnnotation) {
            if ([pboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeColor]]) {
                BOOL isShift = ([NSEvent standardModifierFlags] & NSShiftKeyMask) != 0;
                BOOL isAlt = ([NSEvent standardModifierFlags] & NSAlternateKeyMask) != 0;
                [highlightAnnotation setColor:[NSColor colorFromPasteboard:pboard] alternate:isAlt updateDefaults:isShift];
                performedDrag = YES;
            } else if ([highlightAnnotation hasBorder]) {
                [pboard types];
                NSDictionary *dict = [pboard propertyListForType:SKPasteboardTypeLineStyle];
                NSNumber *number;
                if ((number = [dict objectForKey:SKLineWellLineWidthKey]))
                    [highlightAnnotation setLineWidth:[number doubleValue]];
                [highlightAnnotation setDashPattern:[dict objectForKey:SKLineWellDashPatternKey]];
                if ((number = [dict objectForKey:SKLineWellStyleKey]))
                    [highlightAnnotation setBorderStyle:[number integerValue]];
                if ([highlightAnnotation isLine]) {
                    if ((number = [dict objectForKey:SKLineWellStartLineStyleKey]))
                        [(PDFAnnotationLine *)highlightAnnotation setStartLineStyle:[number integerValue]];
                    if ((number = [dict objectForKey:SKLineWellEndLineStyleKey]))
                        [(PDFAnnotationLine *)highlightAnnotation setEndLineStyle:[number integerValue]];
                }
                performedDrag = YES;
            }
            [self setHighlightAnnotation:nil];
        }
    } else if ([[SKPDFView superclass] instancesRespondToSelector:_cmd]) {
        performedDrag = [super performDragOperation:sender];
    }
    return performedDrag;
}

#pragma mark Services

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types {
    if ([self toolMode] == SKSelectToolMode && NSIsEmptyRect(selectionRect) == NO && selectionPageIndex != NSNotFound) {
        NSMutableArray *writeTypes = [NSMutableArray array];
        NSString *pdfType = nil;
        NSData *pdfData = nil;
        NSString *tiffType = nil;
        NSData *tiffData = nil;
        NSRect selRect = NSIntegralRect(selectionRect);
        
        // Unfortunately only old PboardTypes are requested rather than preferred UTIs, even if we only validate and the Service only requests UTIs, so we need to support both
        if ([[self document] allowsPrinting] && [[self document] isLocked] == NO) {
            if ([types containsObject:NSPasteboardTypePDF])
                pdfType = NSPasteboardTypePDF;
            else if ([types containsObject:NSPDFPboardType])
                pdfType = NSPDFPboardType;
            if (pdfType && (pdfData = [[self currentSelectionPage] PDFDataForRect:selRect]))
                [writeTypes addObject:pdfType];
        }
        if ([types containsObject:NSPasteboardTypeTIFF])
            tiffType = NSPasteboardTypeTIFF;
        else if ([types containsObject:NSTIFFPboardType])
            tiffType = NSTIFFPboardType;
        if (tiffType && (tiffData = [[self currentSelectionPage] TIFFDataForRect:selRect]))
            [writeTypes addObject:tiffType];
        if ([writeTypes count] > 0) {
            [pboard declareTypes:writeTypes owner:nil];
            if (pdfData)
                [pboard setData:pdfData forType:pdfType];
            if (tiffData)
                [pboard setData:tiffData forType:tiffType];
            return YES;
        }
    }
    if ([[self currentSelection] hasCharacters]) {
        if ([types containsObject:NSPasteboardTypeRTF] || [types containsObject:NSRTFPboardType]) {
            [pboard clearContents];
            [pboard writeObjects:@[[[self currentSelection] attributedString]]];
            return YES;
        } else if ([types containsObject:NSPasteboardTypeString] || [types containsObject:NSStringPboardType]) {
            [pboard clearContents];
            [pboard writeObjects:@[[[self currentSelection] string]]];
            return YES;
        }
    }
    if ([[SKPDFView superclass] instancesRespondToSelector:_cmd])
        return [super writeSelectionToPasteboard:pboard types:types];
    return NO;
}

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType {
    if ([self toolMode] == SKSelectToolMode && NSIsEmptyRect(selectionRect) == NO && selectionPageIndex != NSNotFound && returnType == nil && 
        (([[self document] allowsPrinting] && [[self document] isLocked] == NO && [sendType isEqualToString:NSPasteboardTypePDF]) || [sendType isEqualToString:NSPasteboardTypeTIFF])) {
        return self;
    }
    if ([[self currentSelection] hasCharacters] && returnType == nil && ([sendType isEqualToString:NSPasteboardTypeString] || [sendType isEqualToString:NSPasteboardTypeRTF])) {
        return self;
    }
    return [super validRequestorForSendType:sendType returnType:returnType];
}

#pragma mark Annotation management

- (BOOL)addAnnotationWithType:(SKNoteType)annotationType selection:(PDFSelection *)selection page:(PDFPage *)page bounds:(NSRect)bounds {
    PDFAnnotation *newAnnotation = nil;
    NSArray *newAnnotations = nil;
    NSString *text = [selection cleanedString];
    BOOL isInitial = NSEqualSizes(bounds.size, NSZeroSize) && selection == nil;
    
    // new note added by note tool mode, don't add actual zero sized notes
    if (isInitial)
        bounds = annotationType == SKAnchoredNote ? SKRectFromCenterAndSize(bounds.origin, SKNPDFAnnotationNoteSize) : SKRectFromCenterAndSquareSize(bounds.origin, MIN_NOTE_SIZE);
    
    if ([[NSUserDefaults standardUserDefaults] integerForKey:SKDisableUpdateContentsFromEnclosedTextKey] > 1)
        text = nil;
    
    // Create annotation and add to page.
    switch (annotationType) {
        case SKFreeTextNote:
            newAnnotation = [[PDFAnnotationFreeText alloc] initSkimNoteWithBounds:bounds];
            break;
        case SKAnchoredNote:
            newAnnotation = [[SKNPDFAnnotationNote alloc] initSkimNoteWithBounds:bounds];
            break;
        case SKCircleNote:
            newAnnotation = [[PDFAnnotationCircle alloc] initSkimNoteWithBounds:bounds];
            break;
        case SKSquareNote:
            newAnnotation = [[PDFAnnotationSquare alloc] initSkimNoteWithBounds:bounds];
            break;
        case SKHighlightNote:
            newAnnotations = [PDFAnnotationMarkup SkimNotesAndPagesWithSelection:selection markupType:kPDFMarkupTypeHighlight];
            break;
        case SKUnderlineNote:
            newAnnotations = [PDFAnnotationMarkup SkimNotesAndPagesWithSelection:selection markupType:kPDFMarkupTypeUnderline];
            break;
        case SKStrikeOutNote:
            newAnnotations = [PDFAnnotationMarkup SkimNotesAndPagesWithSelection:selection markupType:kPDFMarkupTypeStrikeOut];
            break;
        case SKLineNote:
            newAnnotation = [[PDFAnnotationLine alloc] initSkimNoteWithBounds:bounds];
            break;
        case SKInkNote:
            // we need a drawn path to add an ink note
            break;
    }
    
    if ([newAnnotations count] == 1) {
        newAnnotation = [[[newAnnotations firstObject] firstObject] retain];
        page = [[newAnnotations firstObject] lastObject];
        newAnnotations = nil;
    }
    
    if ([newAnnotations count] > 0) {
        for (NSArray *annotationAndPage in newAnnotations) {
            newAnnotation = [annotationAndPage firstObject];
            page = [annotationAndPage lastObject];
            if ([text length] > 0 || [newAnnotation string] == nil)
                [newAnnotation setString:text ?: @""];
            [newAnnotation registerUserName];
            [self addAnnotation:newAnnotation toPage:page];
            if ([text length] == 0 && isInitial == NO)
                [newAnnotation autoUpdateString];
        }
        [[self undoManager] setActionName:NSLocalizedString(@"Add Note", @"Undo action name")];

        [self setCurrentAnnotation:newAnnotation];
        
        return YES;
    } else if (newAnnotation) {
        if (annotationType != SKLineNote && annotationType != SKInkNote && [text length] > 0)
            [newAnnotation setString:text];
        [newAnnotation registerUserName];
        [self addAnnotation:newAnnotation toPage:page];
        if ([text length] == 0 && isInitial == NO)
            [newAnnotation autoUpdateString];
        if ([newAnnotation string] == nil)
            [newAnnotation setString:@""];
        [[self undoManager] setActionName:NSLocalizedString(@"Add Note", @"Undo action name")];

        [self setCurrentAnnotation:newAnnotation];
        [newAnnotation release];
        
        return YES;
    } else {
        return NO;
    }
}

// y=primaryOutset(x) approximately solves x*secondaryOutset(y)=y
// y=cubrt(1/2x^2)+..., x->0; y=sqrt(2)-1+1/2(sqrt(2)-1)(x-1)+..., x->1
// 0.436947024419157 = 4/3cubrt(1/2)-3/2(sqrt(2)-1)
// 0.057460060808152 = 1/3cubrt(1/2)-1/2(sqrt(2)-1)
static inline CGFloat primaryOutset(CGFloat x) {
    return pow(M_SQRT1_2 * x, 2.0/3.0) - 0.436947024419157 * x + 0.057460060808152 * x * x;
}

// an ellipse outset by 1/2*w*x and 1/2*h*secondaryOutset(x) circumscribes a rect with size {w,h} for any x
static inline CGFloat secondaryOutset(CGFloat x) {
    return (x + 1.0) / sqrt(x * (x + 2.0)) - 1.0;
}

// context should be nil or (an array of) PDFSelection or NSValue objects wrapping a NSPoint
- (void)addAnnotationWithType:(SKNoteType)annotationType context:(id)context {
    if ([context isKindOfClass:[NSArray class]]) {
        for (id item in context)
            [self addAnnotationWithType:annotationType context:item];
        return;
    }
    
	PDFPage *page = nil;
	NSRect bounds = NSZeroRect;
    PDFSelection *selection = [context isKindOfClass:[PDFSelection class]] ? context : nil;
    BOOL noSelection = selection == nil;
    BOOL isMarkup = IS_MARKUP(annotationType);
    
    if (noSelection)
        selection = [self currentSelection];
	page = [selection safeFirstPage];
    
	if (isMarkup) {
        
        // add new markup to the active markup if it's the same type on the same page, unless we add a specific selection
        if (noSelection && page && [[currentAnnotation page] isEqual:page] &&
            [[currentAnnotation type] isEqualToString:(annotationType == SKHighlightNote ? SKNHighlightString : annotationType == SKUnderlineNote ? SKNUnderlineString : annotationType == SKStrikeOutNote ? SKNStrikeOutString : nil)]) {
            selection = [[selection copy] autorelease];
            [selection addSelection:[(PDFAnnotationMarkup *)currentAnnotation selection]];
            [self removeCurrentAnnotation:nil];
        }
        
    } else if (page) {
        
		// Get bounds (page space) for selection (first page in case selection spans multiple pages)
		bounds = [selection boundsForPage:page];
        if (annotationType == SKCircleNote) {
            CGFloat dw, dh, w = NSWidth(bounds), h = NSHeight(bounds);
            if (h < w) {
                dw = primaryOutset(h / w);
                dh = secondaryOutset(dw);
            } else {
                dh = primaryOutset(w / h);
                dw = secondaryOutset(dh);
            }
            CGFloat lw = [[NSUserDefaults standardUserDefaults] doubleForKey:SKCircleNoteLineWidthKey];
            bounds = NSInsetRect(bounds, -0.5 * w * dw - lw, -0.5 * h * dh - lw);
        } else if (annotationType == SKSquareNote) {
            CGFloat lw = [[NSUserDefaults standardUserDefaults] doubleForKey:SKSquareNoteLineWidthKey];
            bounds = NSInsetRect(bounds, -lw, -lw);
        } else if (annotationType == SKLineNote) {
            CGFloat defaultWidth = [[NSUserDefaults standardUserDefaults] floatForKey:SKDefaultNoteWidthKey];
            CGFloat defaultHeight = [[NSUserDefaults standardUserDefaults] floatForKey:SKDefaultNoteHeightKey];
            NSRect pageBounds = [page boundsForBox:[self displayBox]];
            NSPoint p1, p2;
            switch ([page intrinsicRotation]) {
                case 0:
                    p2.x = floor(NSMinX(bounds));
                    p2.y = ceil(NSMidY(bounds));
                    p1.x = fmax(NSMinX(pageBounds), p2.x - defaultWidth);
                    p1.y = fmax(NSMinY(pageBounds), p2.y - defaultHeight);
                    break;
                case 90:
                    p2.x = floor(NSMidX(bounds));
                    p2.y = floor(NSMinY(bounds));
                    p1.x = fmin(NSMaxX(pageBounds), p2.x + defaultHeight);
                    p1.y = fmax(NSMinY(pageBounds), p2.y - defaultWidth);
                    break;
                case 180:
                    p2.x = ceil(NSMaxX(bounds));
                    p2.y = floor(NSMidY(bounds));
                    p1.x = fmin(NSMaxX(pageBounds), p2.x + defaultWidth);
                    p1.y = fmin(NSMaxY(pageBounds), p2.y + defaultHeight);
                    break;
                case 270:
                    p2.x = ceil(NSMidX(bounds));
                    p2.y = ceil(NSMaxY(bounds));
                    p1.x = fmax(NSMinX(pageBounds), p2.x - defaultHeight);
                    p1.y = fmin(NSMaxY(pageBounds), p2.y + defaultWidth);
                    break;
                default:
                    p2.x = floor(NSMinX(bounds));
                    p2.y = ceil(NSMidY(bounds));
                    p1.x = fmax(NSMinX(pageBounds), p2.x - defaultWidth);
                    p1.y = fmax(NSMinY(pageBounds), p2.y - defaultHeight);
                    break;
            }
            bounds = SKRectFromPoints(p1, p2);
        } else if (annotationType == SKAnchoredNote) {
            switch ([page intrinsicRotation]) {
                case 0:
                    bounds.origin.x = floor(NSMinX(bounds)) - SKNPDFAnnotationNoteSize.width;
                    bounds.origin.y = floor(NSMaxY(bounds)) - SKNPDFAnnotationNoteSize.height;
                    break;
                case 90:
                    bounds.origin.x = ceil(NSMinX(bounds));
                    bounds.origin.y = floor(NSMinY(bounds)) - SKNPDFAnnotationNoteSize.height;
                    break;
                case 180:
                    bounds.origin.x = ceil(NSMaxX(bounds));
                    bounds.origin.y = ceil(NSMinY(bounds));
                    break;
                case 270:
                    bounds.origin.x = floor(NSMaxX(bounds)) - SKNPDFAnnotationNoteSize.height;
                    bounds.origin.y = ceil(NSMaxY(bounds));
                    break;
                default:
                    break;
            }
            bounds.size = SKNPDFAnnotationNoteSize;
        }
        bounds = NSIntegralRect(bounds);
        
	} else {
        
		// First try the current mouse position
        NSPoint center = [context isKindOfClass:[NSValue class]] ? [context pointValue] : [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
        
        // if the mouse was in the toolbar and there is a page below the toolbar, we get a point outside of the visible rect
        page = NSMouseInRect(center, [self visibleContentRect], [self isFlipped]) ? [self pageForPoint:center nearest:NO] : nil;
        
        if (page == nil) {
            // Get center of the PDFView.
            NSRect viewFrame = [self frame];
            center = SKCenterPoint(viewFrame);
            page = [self pageForPoint: center nearest: YES];
            if (page == nil) {
                // Get center of the current page
                page = [self currentPage];
                center = [self convertPoint:SKCenterPoint([page boundsForBox:[self displayBox]]) fromPage:page];
            }
        }
        
        CGFloat defaultWidth = [[NSUserDefaults standardUserDefaults] floatForKey:SKDefaultNoteWidthKey];
        CGFloat defaultHeight = [[NSUserDefaults standardUserDefaults] floatForKey:SKDefaultNoteHeightKey];
        NSSize defaultSize = (annotationType == SKAnchoredNote) ? SKNPDFAnnotationNoteSize : ([page rotation] % 180 == 0) ? NSMakeSize(defaultWidth, defaultHeight) : NSMakeSize(defaultHeight, defaultWidth);
		
		// Convert to "page space".
		center = SKIntegralPoint([self convertPoint: center toPage: page]);
        bounds = SKRectFromCenterAndSize(center, defaultSize);
        
        // Make sure it fits in the page
        bounds = SKConstrainRect(bounds, [page boundsForBox:[self displayBox]]);
        
	}
    
    if (page != nil && [self addAnnotationWithType:annotationType selection:selection page:page bounds:bounds]) {
        if (annotationType == SKAnchoredNote || annotationType == SKFreeTextNote)
            [self editCurrentAnnotation:self];
        else if (isMarkup && noSelection)
            [self setCurrentSelection:nil];
    } else NSBeep();
}

- (void)addAnnotationWithType:(SKNoteType)annotationType {
    if ((toolMode == SKTextToolMode || toolMode == SKNoteToolMode) && (annotationType == SKInkNote || (annotationType >= SKHighlightNote && annotationType <= SKStrikeOutNote && [[self currentSelection] hasCharacters] == NO))) {
        [self setTemporaryToolMode:(SKTemporaryToolMode)annotationType];
    } else {
        [self addAnnotationWithType:annotationType context:nil];
    }
}

- (void)addAnnotationForContext:(id)sender {
    [self addAnnotationWithType:[sender tag] context:[sender representedObject]];
}

- (void)addAnnotation:(PDFAnnotation *)annotation toPage:(PDFPage *)page {
    [self beginNewUndoGroupIfNeeded];
    
    [[[self undoManager] prepareWithInvocationTarget:self] removeAnnotation:annotation];
    [annotation setShouldDisplay:pdfvFlags.hideNotes == NO || [annotation isSkimNote] == NO];
    [annotation setShouldPrint:pdfvFlags.hideNotes == NO || [annotation isSkimNote] == NO];
    [page addAnnotation:annotation];
    [self setNeedsDisplayForAnnotation:annotation];
    [self annotationsChangedOnPage:page];
    [self resetPDFToolTipRects];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDidAddAnnotationNotification object:self userInfo:@{SKPDFViewPageKey:page, SKPDFViewAnnotationKey:annotation}];
}

- (void)removeCurrentAnnotation:(id)sender{
    if ([currentAnnotation isSkimNote]) {
        [self removeAnnotation:currentAnnotation];
        [[self undoManager] setActionName:NSLocalizedString(@"Remove Note", @"Undo action name")];
    }
}

- (void)removeThisAnnotation:(id)sender{
    PDFAnnotation *annotation = [sender representedObject];
    
    if (annotation)
        [self removeAnnotation:annotation];
}

- (void)removeAnnotation:(PDFAnnotation *)annotation {
    [self beginNewUndoGroupIfNeeded];
    
    PDFAnnotation *wasAnnotation = [annotation retain];
    PDFPage *page = [[wasAnnotation page] retain];
    
    [[[self undoManager] prepareWithInvocationTarget:self] addAnnotation:wasAnnotation toPage:page];
	if (currentAnnotation == annotation)
		[self setCurrentAnnotation:nil];
    [self setNeedsDisplayForAnnotation:wasAnnotation];
    [page removeAnnotation:wasAnnotation];
    [self annotationsChangedOnPage:page];
    if ([wasAnnotation isNote]) {
        if (RUNNING(10_12) && [[page annotations] containsObject:wasAnnotation])
            [page removeAnnotation:wasAnnotation];
        [self resetPDFToolTipRects];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDidRemoveAnnotationNotification object:self
                                                      userInfo:@{SKPDFViewAnnotationKey:wasAnnotation, SKPDFViewPageKey:page}];
    [wasAnnotation release];
    [page release];
}

- (void)moveAnnotation:(PDFAnnotation *)annotation toPage:(PDFPage *)page {
    PDFPage *oldPage = [[annotation page] retain];
    [[[self undoManager] prepareWithInvocationTarget:self] moveAnnotation:annotation toPage:oldPage];
    [[self undoManager] setActionName:NSLocalizedString(@"Edit Note", @"Undo action name")];
    [self setNeedsDisplayForAnnotation:annotation];
    [annotation retain];
    [oldPage removeAnnotation:annotation];
    [page addAnnotation:annotation];
    [annotation release];
    [self setNeedsDisplayForAnnotation:annotation];
    [self annotationsChangedOnPage:oldPage];
    [self annotationsChangedOnPage:page];
    if ([annotation isNote])
        [self resetPDFToolTipRects];
    if ([self isEditingAnnotation:annotation])
        [editor layoutWithEvent:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDidMoveAnnotationNotification object:self userInfo:@{SKPDFViewOldPageKey:oldPage, SKPDFViewNewPageKey:page, SKPDFViewAnnotationKey:annotation}];                
    [oldPage release];
}

- (void)editThisAnnotation:(id)sender {
    [self editAnnotation:[sender representedObject]];
}

- (void)editAnnotation:(PDFAnnotation *)annotation {
    if (annotation == nil || [self isEditingAnnotation:annotation])
        return;
    
    if (currentAnnotation != annotation)
        [self setCurrentAnnotation:annotation];
    [self editCurrentAnnotation:nil];
}

- (void)editCurrentAnnotation:(id)sender {
    if (nil == currentAnnotation || [self isEditingAnnotation:currentAnnotation])
        return;
    
    [self commitEditing];
    
    if ([currentAnnotation isLink]) {
        
        [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
        PDFDestination *dest = [currentAnnotation linkDestination];
        NSURL *url;
        if (dest)
            [self goToDestination:dest];
        else if ((url = [currentAnnotation linkURL]))
            [[NSWorkspace sharedWorkspace] openURL:url];
        [self setCurrentAnnotation:nil];
        
    } else if (pdfvFlags.hideNotes == NO && [currentAnnotation isEditable]) {
        
        if ([currentAnnotation isText] == NO) {
            
            [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
            
            if ([[self delegate] respondsToSelector:@selector(PDFView:editAnnotation:)])
                [[self delegate] PDFView:self editAnnotation:currentAnnotation];
            
        } else if ([self window]) {
            
            [self scrollAnnotationToVisible:currentAnnotation];
            [self editTextNoteWithEvent:nil];
            
        }
        
    }
    
}

- (void)editTextNoteWithEvent:(NSEvent *)theEvent {
    if ([self isEditingAnnotation:currentAnnotation])
        return;
    
    editor = [[SKTextNoteEditor alloc] initWithPDFView:self annotation:(PDFAnnotationFreeText *)currentAnnotation];
    [[self window] makeFirstResponder:self];
    [editor layoutWithEvent:theEvent];
    
    [self setNeedsDisplayForAnnotation:currentAnnotation];
}

- (void)textNoteEditorDidBeginEditing:(SKTextNoteEditor *)textNoteEditor {
    if ([[self delegate] respondsToSelector:@selector(PDFViewDidBeginEditing:)])
        [[self delegate] PDFViewDidBeginEditing:self];
}

- (void)textNoteEditorDidEndEditing:(SKTextNoteEditor *)textNoteEditor {
    SKDESTROY(editor);
    
    [self setNeedsDisplayForAnnotation:currentAnnotation];
    
    if ([[self delegate] respondsToSelector:@selector(PDFViewDidEndEditing:)])
        [[self delegate] PDFViewDidEndEditing:self];
}

- (void)discardEditing {
    [editor discardEditing];
}

- (BOOL)commitEditing {
    if (editor)
        return [editor commitEditing];
    return YES;
}

- (void)beginNewUndoGroupIfNeeded {
    if (pdfvFlags.wantsNewUndoGroup) {
        NSUndoManager *undoManger = [self undoManager];
        if ([undoManger groupingLevel] > 0) {
            [undoManger endUndoGrouping];
            [undoManger beginUndoGrouping];
        }
    }
}

- (void)selectNextCurrentAnnotation:(id)sender {
    PDFDocument *pdfDoc = [self document];
    NSInteger numberOfPages = [pdfDoc pageCount];
    NSInteger i = -1;
    NSInteger pageIndex, startPageIndex = -1;
    PDFAnnotation *annotation = nil;
    
    if (currentAnnotation) {
        [self commitEditing];
        pageIndex = [[currentAnnotation page] pageIndex];
        i = [[[currentAnnotation page] annotations] indexOfObject:currentAnnotation];
    } else {
        pageIndex = [[self currentPage] pageIndex];
    }
    while (annotation == nil) {
        NSArray *annotations = [[pdfDoc pageAtIndex:pageIndex] annotations];
        while (++i < (NSInteger)[annotations count] && annotation == nil) {
            annotation = [annotations objectAtIndex:i];
            if (([self hideNotes] || [annotation isSkimNote] == NO) && [annotation isLink] == NO)
                annotation = nil;
        }
        if (startPageIndex == -1)
            startPageIndex = pageIndex;
        else if (pageIndex == startPageIndex)
            break;
        if (++pageIndex == numberOfPages)
            pageIndex = 0;
        i = -1;
    }
    if (annotation) {
        [self scrollAnnotationToVisible:annotation];
        [self setCurrentAnnotation:annotation];
        if ([annotation isLink] || [annotation text]) {
            NSRect bounds = [annotation bounds]; 
            NSPoint point = NSMakePoint(NSMinX(bounds) + TOOLTIP_OFFSET_FRACTION * NSWidth(bounds), NSMinY(bounds) + TOOLTIP_OFFSET_FRACTION * NSHeight(bounds));
            point = [self convertPoint:point fromPage:[annotation page]];
            point = [self convertPointToScreen:NSMakePoint(round(point.x), round(point.y))];
            [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:annotation scale:[self scaleFactor] atPoint:point];
        } else {
            [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
        }
    }
}

- (void)selectPreviousCurrentAnnotation:(id)sender {
    PDFDocument *pdfDoc = [self document];
    NSInteger numberOfPages = [pdfDoc pageCount];
    NSInteger i = -1;
    NSInteger pageIndex, startPageIndex = -1;
    PDFAnnotation *annotation = nil;
    NSArray *annotations = nil;
    
    if (currentAnnotation) {
        [self commitEditing];
        pageIndex = [[currentAnnotation page] pageIndex];
        annotations = [[currentAnnotation page] annotations];
        i = [annotations indexOfObject:currentAnnotation];
    } else {
        pageIndex = [[self currentPage] pageIndex];
        annotations = [[self currentPage] annotations];
        i = [annotations count];
    }
    while (annotation == nil) {
        while (--i >= 0 && annotation == nil) {
            annotation = [annotations objectAtIndex:i];
            if (([self hideNotes] || [annotation isSkimNote] == NO) && [annotation isLink] == NO)
                annotation = nil;
        }
        if (startPageIndex == -1)
            startPageIndex = pageIndex;
        else if (pageIndex == startPageIndex)
            break;
        if (--pageIndex == -1)
            pageIndex = numberOfPages - 1;
        annotations = [[pdfDoc pageAtIndex:pageIndex] annotations];
        i = [annotations count];
    }
    if (annotation) {
        [self scrollAnnotationToVisible:annotation];
        [self setCurrentAnnotation:annotation];
        if ([annotation isLink] || [annotation text]) {
            NSRect bounds = [annotation bounds]; 
            NSPoint point = NSMakePoint(NSMinX(bounds) + TOOLTIP_OFFSET_FRACTION * NSWidth(bounds), NSMinY(bounds) + TOOLTIP_OFFSET_FRACTION * NSHeight(bounds));
            point = [self convertPoint:point fromPage:[annotation page]] ;
            point = [self convertPointToScreen:NSMakePoint(round(point.x), round(point.y))];
            [[SKImageToolTipWindow sharedToolTipWindow] showForImageContext:annotation scale:[self scaleFactor] atPoint:point];
        } else {
            [[SKImageToolTipWindow sharedToolTipWindow] orderOut:self];
        }
    }
}

- (BOOL)isEditingAnnotation:(PDFAnnotation *)annotation {
    return editor && currentAnnotation == annotation;
}

- (void)scrollAnnotationToVisible:(PDFAnnotation *)annotation {
    [self goToRect:[annotation bounds] onPage:[annotation page]];
}

- (void)setNeedsDisplayForAnnotation:(PDFAnnotation *)annotation onPage:(PDFPage *)page {
    NSRect rect = [annotation displayRect];
    if (annotation == currentAnnotation) {
        CGFloat margin = ([annotation isResizable] ? HANDLE_SIZE  : 1.0) / [self scaleFactor];
        rect = NSInsetRect(rect, -margin, -margin);
    }
    [self setNeedsDisplayInRect:rect ofPage:page];
    [self annotationsChangedOnPage:page];
}

- (void)setNeedsDisplayForReadingBarBounds:(NSRect)rect onPage:(PDFPage *)page {
    [self setNeedsDisplayInRect:[SKReadingBar bounds:rect forBox:[self displayBox] onPage:page] ofPage:page];
}

- (void)requiresDisplay {
    [super requiresDisplay];
    [loupeController updateContents];
}

- (void)setNeedsDisplayInRect:(NSRect)rect ofPage:(PDFPage *)page {
    [super setNeedsDisplayInRect:rect ofPage:page];
    [loupeController updateContents];
}

#pragma mark Sync

// @@ Horizontal layout
- (void)displayLineAtPoint:(NSPoint)point inPageAtIndex:(NSUInteger)pageIndex select:(BOOL)select showReadingBar:(BOOL)showBar {
    if (pageIndex < [[self document] pageCount]) {
        PDFPage *page = [[self document] pageAtIndex:pageIndex];
        PDFSelection *sel = [page selectionForLineAtPoint:point];
        NSRect lineRect = [sel hasCharacters] ? [sel boundsForPage:page] : SKRectFromCenterAndSquareSize(point, 10.0);
        NSRect rect = lineRect;
        NSRect visibleRect;
        BOOL wasPageDisplayed = [self isPageAtIndexDisplayed:pageIndex];
        BOOL shouldHideReadingBar = NO;
        
        if (wasPageDisplayed == NO)
            [self goToPage:page];
        
        if (interactionMode != SKPresentationMode) {
            if (showBar) {
                if ([self hasReadingBar] == NO || [syncDot shouldHideReadingBar])
                    shouldHideReadingBar = YES;
                [self stopPacer];
                BOOL invert = [[NSUserDefaults standardUserDefaults] boolForKey:SKReadingBarInvertKey];
                NSInteger line = [page indexOfLineRectAtPoint:point lower:YES];
                if ([self hasReadingBar] == NO) {
                    SKReadingBar *aReadingBar = [[SKReadingBar alloc] initWithPage:page line:line delegate:self];
                    [self setReadingBar:aReadingBar];
                    [aReadingBar release];
                    if (invert)
                        [self requiresDisplay];
                    else
                        [self setNeedsDisplayForReadingBarBounds:[readingBar currentBounds] onPage:[readingBar page]];
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[readingBar page], SKPDFViewNewPageKey, nil];
                    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewReadingBarDidChangeNotification object:self userInfo:userInfo];
                } else {
                    [readingBar goToLine:line onPage:page];
                }
            }
            if (select && [sel hasCharacters] && [self toolMode] == SKTextToolMode) {
                [self setCurrentSelection:sel];
            }
        }
        
        visibleRect = [self convertRect:[self visibleContentRect] toPage:page];
        
        if (wasPageDisplayed == NO || NSContainsRect(visibleRect, lineRect) == NO) {
            if ([self displayMode] == kPDFDisplaySinglePageContinuous || [self displayMode] == kPDFDisplayTwoUpContinuous)
                rect = NSInsetRect(lineRect, 0.0, - floor( ( NSHeight(visibleRect) - NSHeight(rect) ) / 2.0 ) );
            if (NSWidth(rect) > NSWidth(visibleRect)) {
                if (NSMaxX(rect) < point.x + 0.5 * NSWidth(visibleRect))
                    rect.origin.x = NSMaxX(rect) - NSWidth(visibleRect);
                else if (NSMinX(rect) < point.x - 0.5 * NSWidth(visibleRect))
                    rect.origin.x = floor( point.x - 0.5 * NSWidth(visibleRect) );
                rect.size.width = NSWidth(visibleRect);
            }
            rect = [self convertRect:[self convertRect:rect fromPage:page] toView:[self documentView]];
            [[self documentView] scrollRectToVisible:rect];
        }
        
        [syncDot invalidate];
        [self setSyncDot:[[[SKSyncDot alloc] initWithPoint:point page:page updateHandler:^(BOOL finished){
                [self setNeedsDisplayInRect:[syncDot bounds] ofPage:[syncDot page]];
            if (finished) {
                if ([syncDot shouldHideReadingBar] && [self hasReadingBar])
                    [self toggleReadingBar];
                [self setSyncDot:nil];
            }
            }] autorelease]];
        [syncDot setShouldHideReadingBar:shouldHideReadingBar];
    }
}

#pragma mark Snapshots

- (void)takeSnapshot:(id)sender {
    NSPoint point;
    PDFPage *page = nil;
    NSRect rect = NSZeroRect;
    BOOL autoFits = NO;
    
    if (toolMode == SKSelectToolMode && NSIsEmptyRect(selectionRect) == NO && selectionPageIndex != NSNotFound) {
        page = [self currentSelectionPage];
        rect = NSIntersectionRect(selectionRect, [page boundsForBox:kPDFDisplayBoxCropBox]);
        autoFits = YES;
	}
    if (NSIsEmptyRect(rect)) {
        
        if ([sender representedObject] == nil) {
            [self setTemporaryToolMode:SKSnapshotToolMode];
            return;
        }
        
        // the represented object should be the location for the menu event
        point = [[sender representedObject] pointValue];
        page = [self pageForPoint:point nearest:NO];
        if (page == nil) {
            // Get the center
            NSRect viewFrame = [self frame];
            point = SKCenterPoint(viewFrame);
            page = [self pageForPoint:point nearest:YES];
        }
        
        point = [self convertPoint:point toPage:page];
        
        rect = [self convertRect:[page boundsForBox:kPDFDisplayBoxCropBox] fromPage:page];
        rect.origin.y = point.y - 0.5 * DEFAULT_SNAPSHOT_HEIGHT;
        rect.size.height = DEFAULT_SNAPSHOT_HEIGHT;
        
        rect = [self convertRect:rect toPage:page];
    }
    
    if ([[self delegate] respondsToSelector:@selector(PDFView:showSnapshotAtPageNumber:forRect:scaleFactor:autoFits:)])
        [[self delegate] PDFView:self showSnapshotAtPageNumber:[page pageIndex] forRect:rect scaleFactor:[self scaleFactor] autoFits:autoFits];
}

#pragma mark Zooming

- (void)zoomToRect:(NSRect)rect onPage:(PDFPage *)page {
    if (NSIsEmptyRect(rect) == NO) {
        CGFloat scrollerWidth = [NSScroller effectiveScrollerWidth];
        NSRect bounds = [self bounds];
        CGFloat scale = 1.0;
        bounds.size.width -= scrollerWidth;
        bounds.size.height -= scrollerWidth;
        if (NSWidth(bounds) * NSHeight(rect) > NSWidth(rect) * NSHeight(bounds))
            scale = NSHeight(bounds) / NSHeight(rect);
        else
            scale = NSWidth(bounds) / NSWidth(rect);
        [self setScaleFactor:scale];
        NSScrollView *scrollView = [self scrollView];
        if (scrollerWidth > 0.0 && ([scrollView hasHorizontalScroller] == NO || [scrollView hasVerticalScroller] == NO)) {
            if ([scrollView hasVerticalScroller])
                bounds.size.width -= scrollerWidth;
            if ([scrollView hasHorizontalScroller])
                bounds.size.height -= scrollerWidth;
            if (NSWidth(bounds) * NSHeight(rect) > NSWidth(rect) * NSHeight(bounds))
                scale = NSHeight(bounds) / NSHeight(rect);
            else
                scale = NSWidth(bounds) / NSWidth(rect);
            [self setScaleFactor:scale];
        }
        [self goToRect:rect onPage:page];
    }
}

#pragma mark Notification handling

- (void)handlePageChangedNotification:(NSNotification *)notification {
    if ([self displayMode] == kPDFDisplaySinglePage || [self displayMode] == kPDFDisplayTwoUp) {
        [editor layoutWithEvent:nil];
        [self resetPDFToolTipRects];
        if (toolMode == SKMagnifyToolMode)
            [loupeController updateContents];
    }
}

- (void)handleScaleChangedNotification:(NSNotification *)notification {
    [self resetPDFToolTipRects];
    [self updatePacer];
    if (interactionMode == SKPresentationMode && [self autoScales] == NO && fabs([self scaleFactor] - 1.0) > 0.0)
        [self setAutoScales:YES];
}

- (void)handleUndoGroupOpenedOrClosedNotification:(NSNotification *)notification {
    pdfvFlags.wantsNewUndoGroup = NO;
}

- (void)handleKeyStateChangedNotification:(NSNotification *)notification {
    atomic_store(&inKeyWindow, [[self window] isKeyWindow]);
    if (RUNNING_BEFORE(10_12) || RUNNING_AFTER(10_14)) {
        if (selectionPageIndex != NSNotFound) {
            CGFloat margin = HANDLE_SIZE / [self scaleFactor];
            for (PDFPage *page in [self displayedPages])
                [self setNeedsDisplayInRect:NSInsetRect(selectionRect, -margin, -margin) ofPage:page];
        }
        if (currentAnnotation)
            [self setNeedsDisplayForAnnotation:currentAnnotation];
    }
    if ([[notification name] isEqualToString:NSWindowDidResignKeyNotification])
        [self setTemporaryToolMode:SKNoToolMode];
}

- (void)handleMainStateChangedNotification:(NSNotification *)notification {
    [self setTemporaryToolMode:SKNoToolMode];
}

#pragma mark Key and window changes

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    if (editor && [self commitEditing] == NO)
        [self discardEditing];
    
    [self removeLoupeWindow];
    
    [self stopPacer];
    
    if (interactionMode == SKPresentationMode) {
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(showNavWindow) object:nil];
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(doAutoHide) object:nil];
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(doAutoHideCursor) object:nil];
    }
    
    [self setTemporaryToolMode:SKNoToolMode];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSWindow *oldWindow = [self window];
    if (oldWindow) {
        [nc removeObserver:self name:NSWindowDidBecomeKeyNotification object:oldWindow];
        [nc removeObserver:self name:NSWindowDidResignKeyNotification object:oldWindow];
        [nc removeObserver:self name:NSWindowDidResignMainNotification object:oldWindow];
    }
    if (newWindow) {
        atomic_store(&inKeyWindow, [newWindow isKeyWindow]);
        [nc addObserver:self selector:@selector(handleKeyStateChangedNotification:) name:NSWindowDidBecomeKeyNotification object:newWindow];
        [nc addObserver:self selector:@selector(handleKeyStateChangedNotification:) name:NSWindowDidResignKeyNotification object:newWindow];
        [nc addObserver:self selector:@selector(handleMainStateChangedNotification:) name:NSWindowDidResignMainNotification object:newWindow];
    }
    
    [super viewWillMoveToWindow:newWindow];
}

- (BOOL)becomeFirstResponder {
    if ([super becomeFirstResponder]) {
        if (RUNNING_BEFORE(10_12))
            [self handleKeyStateChangedNotification:nil];
        return YES;
    }
    return NO;
}

- (BOOL)resignFirstResponder {
    if ([super resignFirstResponder]) {
        if (RUNNING_BEFORE(10_12))
            [self handleKeyStateChangedNotification:nil];
        return YES;
    }
    return NO;
}

#pragma mark Dark mode

- (void)viewDidChangeEffectiveAppearance {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    [super viewDidChangeEffectiveAppearance];
#pragma clang diagnostic pop
    [loupeController updateColorFilters];
}

- (void)colorFiltersDidChange {
    [super colorFiltersDidChange];
    [loupeController updateColorFilters];
}

#pragma mark Menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(changeToolMode:)) {
        [menuItem setState:[self toolMode] == (SKToolMode)[menuItem tag] ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(changeAnnotationMode:)) {
        if ([[menuItem menu] numberOfItems] > ANNOTATION_MODE_COUNT)
            [menuItem setState:[self toolMode] == SKNoteToolMode && [self annotationMode] == (SKNoteType)[menuItem tag] ? NSOnState : NSOffState];
        else
            [menuItem setState:[self annotationMode] == (SKNoteType)[menuItem tag] ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(copy:)) {
        return ([[self currentSelection] hasCharacters] || [currentAnnotation isSkimNote] ||
            (toolMode == SKSelectToolMode && NSIsEmptyRect(selectionRect) == NO && selectionPageIndex != NSNotFound && [[self document] isLocked] == NO));
    } else if (action == @selector(cut:)) {
        if ([currentAnnotation isSkimNote] && [currentAnnotation isMovable])
            return YES;
        return NO;
    } else if (action == @selector(paste:)) {
        return [[NSPasteboard generalPasteboard] canReadObjectForClasses:@[[PDFAnnotation class], [NSString class]] options:@{}];
    } else if (action == @selector(alternatePaste:)) {
        return [[NSPasteboard generalPasteboard] canReadObjectForClasses:@[[PDFAnnotation class], [NSAttributedString class], [NSString class]] options:@{}];
    } else if (action == @selector(pasteAsPlainText:)) {
        return [[NSPasteboard generalPasteboard] canReadObjectForClasses:@[[NSAttributedString class], [NSString class]] options:@{}];
    } else if (action == @selector(delete:)) {
        return [currentAnnotation isSkimNote];
    } else if (action == @selector(selectAll:)) {
        return toolMode == SKTextToolMode;
    } else if (action == @selector(deselectAll:)) {
        return [[self currentSelection] hasCharacters] != 0;
    } else if (action == @selector(autoSelectContent:)) {
        return toolMode == SKSelectToolMode;
    } else if (action == @selector(takeSnapshot:)) {
        return [[self document] isLocked] == NO;
    } else if (action == @selector(_setSinglePageScrolling:)) {
        [menuItem setState:[self extendedDisplayMode] == kPDFDisplaySinglePageContinuous ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(_setDoublePageScrolling:)) {
        [menuItem setState:[self extendedDisplayMode] == kPDFDisplayTwoUpContinuous ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(_setDoublePage:)) {
        [menuItem setState:[self extendedDisplayMode] == kPDFDisplayTwoUp ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(setHorizontalScrolling:)) {
        [menuItem setState:[self extendedDisplayMode] == kPDFDisplayHorizontalContinuous ? NSOnState : NSOffState];
        return YES;
    } else if (action == @selector(zoomToPhysicalSize:)) {
        [menuItem setState:([self autoScales] || fabs([self physicalScaleFactor] - 1.0) > 0.001) ? NSOffState : NSOnState];
        return YES;
    } else if (action == @selector(editCurrentAnnotation:)) {
        return [[self currentAnnotation] isEditable];
    } else if (action == @selector(moveCurrentAnnotation:)) {
        return [[self currentAnnotation] isMovable];
    } else if (action == @selector(resizeCurrentAnnotation:)) {
        return [[self currentAnnotation] isResizable];
    } else if (action == @selector(autoSizeCurrentAnnotation:)) {
        return [[self currentAnnotation] isResizable] && [[self currentAnnotation] isLine] == NO && [currentAnnotation isInk] == NO;
    } else if (action == @selector(changeOnlyAnnotationMode:)) {
        return toolMode == SKNoteToolMode;
    } else if (action == @selector(moveReadingBar:) || action == @selector(resizeReadingBar:)) {
        return [self hasReadingBar];
    } else if (action == @selector(nextLaserPointerColor:) || action == @selector(nextLaserPointerColor:)) {
        return pdfvFlags.useArrowCursorInPresentation == 0;
    } else {
        return [super validateMenuItem:menuItem];
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKPDFViewDefaultsObservationContext) {
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:SKReadingBarColorKey] || [key isEqualToString:SKReadingBarInvertKey]) {
            if (readingBar) {
                PDFPage *page = [readingBar page];
                if ([key isEqualToString:SKReadingBarInvertKey] || [[NSUserDefaults standardUserDefaults] boolForKey:SKReadingBarInvertKey])
                    [self requiresDisplay];
                else
                    [self setNeedsDisplayForReadingBarBounds:[readingBar currentBounds] onPage:page];
                [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewReadingBarDidChangeNotification
                    object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:page, SKPDFViewOldPageKey, page, SKPDFViewNewPageKey, nil]];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark FullScreen navigation and autohide

- (void)enableNavigation {
    navigationMode = [[NSUserDefaults standardUserDefaults] integerForKey:SKPresentationNavigationOptionKey];
    
    if (navigationMode != SKNavigationNone)
        navWindow = [[SKNavigationWindow alloc] initWithPDFView:self];
    
    [self performSelectorOnce:@selector(doAutoHide) afterDelay:AUTO_HIDE_DELAY];
}

- (void)disableNavigation {
    navigationMode = SKNavigationNone;
    
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(showNavWindow) object:nil];
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(doAutoHide) object:nil];
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(doAutoHideCursor) object:nil];
    if (navWindow) {
        [navWindow remove];
        SKDESTROY(navWindow);
    }
}

- (void)doAutoHide {
    if (interactionMode == SKPresentationMode && ([navWindow isVisible] == NO || NSPointInRect([NSEvent mouseLocation], [navWindow frame]) == NO)) {
        [self doAutoHideCursor];
        if ([navWindow isVisible]) {
            [navWindow fadeOut];
            NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor([self documentView]), NSAccessibilityLayoutChangedNotification, nil);
        }
    }
}

- (void)showNavWindow {
    if ([navWindow isVisible] == NO && NSPointInRect([[self window] mouseLocationOutsideOfEventStream], SKSliceRect([[[self window] contentView] frame], NAVIGATION_BOTTOM_EDGE_HEIGHT, NSMinYEdge))) {
        [navWindow showForWindow:[self window]];
        NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor([self documentView]), NSAccessibilityLayoutChangedNotification, [NSDictionary dictionaryWithObjectsAndKeys:NSAccessibilityUnignoredChildrenForOnlyChild(navWindow), NSAccessibilityUIElementsKey, nil]);
    }
}

#pragma mark Event handling

- (void)doMoveCurrentAnnotationForKey:(unichar)eventChar byAmount:(CGFloat)delta {
    NSRect bounds = [currentAnnotation bounds];
    NSRect newBounds = bounds;
    PDFPage *page = [currentAnnotation page];
    NSRect pageBounds = [page boundsForBox:[self displayBox]];
    
    switch ([page rotation]) {
        case 0:
            if (eventChar == NSRightArrowFunctionKey) {
                if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds))
                    newBounds.origin.x += delta;
                else if (NSMaxX(bounds) < NSMaxX(pageBounds))
                    newBounds.origin.x += NSMaxX(pageBounds) - NSMaxX(bounds);
            } else if (eventChar == NSLeftArrowFunctionKey) {
                if (NSMinX(bounds) - delta >= NSMinX(pageBounds))
                    newBounds.origin.x -= delta;
                else if (NSMinX(bounds) > NSMinX(pageBounds))
                    newBounds.origin.x -= NSMinX(bounds) - NSMinX(pageBounds);
            } else if (eventChar == NSUpArrowFunctionKey) {
                if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds))
                    newBounds.origin.y += delta;
                else if (NSMaxY(bounds) < NSMaxY(pageBounds))
                    newBounds.origin.y += NSMaxY(pageBounds) - NSMaxY(bounds);
            } else if (eventChar == NSDownArrowFunctionKey) {
                if (NSMinY(bounds) - delta >= NSMinY(pageBounds))
                    newBounds.origin.y -= delta;
                else if (NSMinY(bounds) > NSMinY(pageBounds))
                    newBounds.origin.y -= NSMinY(bounds) - NSMinY(pageBounds);
            }
            break;
        case 90:
            if (eventChar == NSRightArrowFunctionKey) {
                if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds))
                    newBounds.origin.y += delta;
            } else if (eventChar == NSLeftArrowFunctionKey) {
                if (NSMinY(bounds) - delta >= NSMinY(pageBounds))
                    newBounds.origin.y -= delta;
            } else if (eventChar == NSUpArrowFunctionKey) {
                if (NSMinX(bounds) - delta >= NSMinX(pageBounds))
                    newBounds.origin.x -= delta;
            } else if (eventChar == NSDownArrowFunctionKey) {
                if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds))
                    newBounds.origin.x += delta;
            }
            break;
        case 180:
            if (eventChar == NSRightArrowFunctionKey) {
                if (NSMinX(bounds) - delta >= NSMinX(pageBounds))
                    newBounds.origin.x -= delta;
            } else if (eventChar == NSLeftArrowFunctionKey) {
                if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds))
                    newBounds.origin.x += delta;
            } else if (eventChar == NSUpArrowFunctionKey) {
                if (NSMinY(bounds) - delta >= NSMinY(pageBounds))
                    newBounds.origin.y -= delta;
            } else if (eventChar == NSDownArrowFunctionKey) {
                if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds))
                    newBounds.origin.y += delta;
            }
            break;
        case 270:
            if (eventChar == NSRightArrowFunctionKey) {
                if (NSMinY(bounds) - delta >= NSMinY(pageBounds))
                    newBounds.origin.y -= delta;
            } else if (eventChar == NSLeftArrowFunctionKey) {
                if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds))
                    newBounds.origin.y += delta;
            } else if (eventChar == NSUpArrowFunctionKey) {
                if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds))
                    newBounds.origin.x += delta;
            } else if (eventChar == NSDownArrowFunctionKey) {
                if (NSMinX(bounds) - delta >= NSMinX(pageBounds))
                    newBounds.origin.x -= delta;
            }
            break;
    }
    
    if (NSEqualRects(bounds, newBounds) == NO) {
        [currentAnnotation setBounds:newBounds];
        [currentAnnotation autoUpdateString];
    }
}

- (void)doResizeCurrentAnnotationForKey:(unichar)eventChar byAmount:(CGFloat)delta {
    NSRect bounds = [currentAnnotation bounds];
    NSRect newBounds = bounds;
    PDFPage *page = [currentAnnotation page];
    NSRect pageBounds = [page boundsForBox:[self displayBox]];
    
    if ([currentAnnotation isLine]) {
        
        PDFAnnotationLine *annotation = (PDFAnnotationLine *)currentAnnotation;
        NSPoint startPoint = SKIntegralPoint(SKAddPoints([annotation startPoint], bounds.origin));
        NSPoint endPoint = SKIntegralPoint(SKAddPoints([annotation endPoint], bounds.origin));
        NSPoint oldEndPoint = endPoint;
        
        // Resize the annotation.
        switch ([page rotation]) {
            case 0:
                if (eventChar == NSRightArrowFunctionKey) {
                    endPoint.x += delta;
                    if (endPoint.x > NSMaxX(pageBounds))
                        endPoint.x = NSMaxX(pageBounds);
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    endPoint.x -= delta;
                    if (endPoint.x < NSMinX(pageBounds))
                        endPoint.x = NSMinX(pageBounds);
                } else if (eventChar == NSUpArrowFunctionKey) {
                    endPoint.y += delta;
                    if (endPoint.y > NSMaxY(pageBounds))
                        endPoint.y = NSMaxY(pageBounds);
                } else if (eventChar == NSDownArrowFunctionKey) {
                    endPoint.y -= delta;
                    if (endPoint.y < NSMinY(pageBounds))
                        endPoint.y = NSMinY(pageBounds);
                }
                break;
            case 90:
                if (eventChar == NSRightArrowFunctionKey) {
                    endPoint.y += delta;
                    if (endPoint.y > NSMaxY(pageBounds))
                        endPoint.y = NSMaxY(pageBounds);
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    endPoint.y -= delta;
                    if (endPoint.y < NSMinY(pageBounds))
                        endPoint.y = NSMinY(pageBounds);
                } else if (eventChar == NSUpArrowFunctionKey) {
                    endPoint.x -= delta;
                    if (endPoint.x < NSMinX(pageBounds))
                        endPoint.x = NSMinX(pageBounds);
                } else if (eventChar == NSDownArrowFunctionKey) {
                    endPoint.x += delta;
                    if (endPoint.x > NSMaxX(pageBounds))
                        endPoint.x = NSMaxX(pageBounds);
                }
                break;
            case 180:
                if (eventChar == NSRightArrowFunctionKey) {
                    endPoint.x -= delta;
                    if (endPoint.x < NSMinX(pageBounds))
                        endPoint.x = NSMinX(pageBounds);
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    endPoint.x += delta;
                    if (endPoint.x > NSMaxX(pageBounds))
                        endPoint.x = NSMaxX(pageBounds);
                } else if (eventChar == NSUpArrowFunctionKey) {
                    endPoint.y -= delta;
                    if (endPoint.y < NSMinY(pageBounds))
                        endPoint.y = NSMinY(pageBounds);
                } else if (eventChar == NSDownArrowFunctionKey) {
                    endPoint.y += delta;
                    if (endPoint.y > NSMaxY(pageBounds))
                        endPoint.y = NSMaxY(pageBounds);
                }
                break;
            case 270:
                if (eventChar == NSRightArrowFunctionKey) {
                    endPoint.y -= delta;
                    if (endPoint.y < NSMinY(pageBounds))
                        endPoint.y = NSMinY(pageBounds);
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    endPoint.y += delta;
                    if (endPoint.y > NSMaxY(pageBounds))
                        endPoint.y = NSMaxY(pageBounds);
                } else if (eventChar == NSUpArrowFunctionKey) {
                    endPoint.x += delta;
                    if (endPoint.x > NSMaxX(pageBounds))
                        endPoint.x = NSMaxX(pageBounds);
                } else if (eventChar == NSDownArrowFunctionKey) {
                    endPoint.x -= delta;
                    if (endPoint.x < NSMinX(pageBounds))
                        endPoint.x = NSMinX(pageBounds);
                }
                break;
        }
        
        endPoint.x = floor(endPoint.x);
        endPoint.y = floor(endPoint.y);
        
        if (NSEqualPoints(endPoint, oldEndPoint) == NO) {
            newBounds = SKIntegralRectFromPoints(startPoint, endPoint);
            
            if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
                newBounds.size.width = MIN_NOTE_SIZE;
                newBounds.origin.x = floor(0.5 * ((startPoint.x + endPoint.x) - MIN_NOTE_SIZE));
            }
            if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
                newBounds.size.height = MIN_NOTE_SIZE;
                newBounds.origin.y = floor(0.5 * ((startPoint.y + endPoint.y) - MIN_NOTE_SIZE));
            }
            
            startPoint = SKSubstractPoints(startPoint, newBounds.origin);
            endPoint = SKSubstractPoints(endPoint, newBounds.origin);
            
            [annotation setBounds:newBounds];
            [annotation setObservedStartPoint:startPoint];
            [annotation setObservedEndPoint:endPoint];
        }
        
    } else {
        
        switch ([page rotation]) {
            case 0:
                if (eventChar == NSRightArrowFunctionKey) {
                    if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds)) {
                        newBounds.size.width += delta;
                    } else if (NSMaxX(bounds) < NSMaxX(pageBounds)) {
                        newBounds.size.width += NSMaxX(pageBounds) - NSMaxX(bounds);
                    }
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    newBounds.size.width -= delta;
                    if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.size.width = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSUpArrowFunctionKey) {
                    newBounds.origin.y += delta;
                    newBounds.size.height -= delta;
                    if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.origin.y += NSHeight(newBounds) - MIN_NOTE_SIZE;
                        newBounds.size.height = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSDownArrowFunctionKey) {
                    if (NSMinY(bounds) - delta >= NSMinY(pageBounds)) {
                        newBounds.origin.y -= delta;
                        newBounds.size.height += delta;
                    } else if (NSMinY(bounds) > NSMinY(pageBounds)) {
                        newBounds.origin.y -= NSMinY(bounds) - NSMinY(pageBounds);
                        newBounds.size.height += NSMinY(bounds) - NSMinY(pageBounds);
                    }
                }
                break;
            case 90:
                if (eventChar == NSRightArrowFunctionKey) {
                    if (NSMinY(bounds) + delta <= NSMaxY(pageBounds)) {
                        newBounds.size.height += delta;
                    } else if (NSMinY(bounds) < NSMaxY(pageBounds)) {
                        newBounds.size.height += NSMaxY(pageBounds) - NSMinY(bounds);
                    }
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    newBounds.size.height -= delta;
                    if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.size.height = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSUpArrowFunctionKey) {
                    newBounds.size.width -= delta;
                    if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.size.width = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSDownArrowFunctionKey) {
                    if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds)) {
                        newBounds.size.width += delta;
                    } else if (NSMaxX(bounds) < NSMaxX(pageBounds)) {
                        newBounds.size.width += NSMaxX(pageBounds) - NSMaxX(bounds);
                    }
                }
                break;
            case 180:
                if (eventChar == NSRightArrowFunctionKey) {
                    if (NSMinX(bounds) - delta >= NSMinX(pageBounds)) {
                        newBounds.origin.x -= delta;
                        newBounds.size.width += delta;
                    } else if (NSMinX(bounds) > NSMinX(pageBounds)) {
                        newBounds.origin.x -= NSMinX(bounds) - NSMinX(pageBounds);
                        newBounds.size.width += NSMinX(bounds) - NSMinX(pageBounds);
                    }
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    newBounds.origin.x += delta;
                    newBounds.size.width -= delta;
                    if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.origin.x += NSWidth(newBounds) - MIN_NOTE_SIZE;
                        newBounds.size.width = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSUpArrowFunctionKey) {
                    newBounds.size.height -= delta;
                    if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.size.height = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSDownArrowFunctionKey) {
                    if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds)) {
                        newBounds.size.height += delta;
                    } else if (NSMaxY(bounds) < NSMaxY(pageBounds)) {
                        newBounds.size.height += NSMaxY(pageBounds) - NSMaxY(bounds);
                    }
                }
                break;
            case 270:
                if (eventChar == NSRightArrowFunctionKey) {
                    if (NSMinY(bounds) - delta >= NSMinY(pageBounds)) {
                        newBounds.origin.y -= delta;
                        newBounds.size.height += delta;
                    } else if (NSMinY(bounds) > NSMinY(pageBounds)) {
                        newBounds.origin.y -= NSMinY(bounds) - NSMinY(pageBounds);
                        newBounds.size.height += NSMinY(bounds) - NSMinY(pageBounds);
                    }
                } else if (eventChar == NSLeftArrowFunctionKey) {
                    newBounds.origin.y += delta;
                    newBounds.size.height -= delta;
                    if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.origin.y += NSHeight(newBounds) - MIN_NOTE_SIZE;
                        newBounds.size.height = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSUpArrowFunctionKey) {
                    newBounds.origin.x += delta;
                    newBounds.size.width -= delta;
                    if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
                        newBounds.origin.x += NSWidth(newBounds) - MIN_NOTE_SIZE;
                        newBounds.size.width = MIN_NOTE_SIZE;
                    }
                } else if (eventChar == NSDownArrowFunctionKey) {
                    if (NSMinX(bounds) - delta >= NSMinX(pageBounds)) {
                        newBounds.origin.x -= delta;
                        newBounds.size.width += delta;
                    } else if (NSMinX(bounds) > NSMinX(pageBounds)) {
                        newBounds.origin.x -= NSMinX(bounds) - NSMinX(pageBounds);
                        newBounds.size.width += NSMinX(bounds) - NSMinX(pageBounds);
                    }
                }
                break;
        }
        
        if (NSEqualRects(bounds, newBounds) == NO) {
            if ([currentAnnotation isInk]) {
                CGFloat margin = [(PDFAnnotationInk *)currentAnnotation pathInset];
                NSMutableArray *paths = [NSMutableArray array];
                NSAffineTransform *transform = [NSAffineTransform transform];
                [transform translateXBy:margin yBy:margin];
                [transform scaleXBy:fmax(1.0, NSWidth(newBounds) - 2.0 * margin) / fmax(1.0, NSWidth(bounds) - 2.0 * margin) yBy:fmax(1.0, NSHeight(newBounds) - 2.0 * margin) / fmax(1.0, NSHeight(bounds) - 2.0 * margin)];
                [transform translateXBy:-margin yBy:-margin];
                
                for (NSBezierPath *path in [(PDFAnnotationInk *)currentAnnotation paths])
                    [paths addObject:[transform transformBezierPath:path]];
                
                [(PDFAnnotationInk *)currentAnnotation setBezierPaths:paths];
            }
            
            [currentAnnotation setBounds:newBounds];
            [currentAnnotation autoUpdateString];
        }
    }
}

- (void)doAutoSizeActiveNoteIgnoringWidth:(BOOL)ignoreWidth {
    if ([currentAnnotation isResizable] == NO || [currentAnnotation isLine] || [currentAnnotation isInk]) {
        NSBeep();
    } else if ([currentAnnotation isText]) {
        
        NSString *string = [editor currentString] ?: [currentAnnotation string];
        if ([string length] == 0) {
            NSBeep();
            return;
        }
        
        PDFPage *page = [currentAnnotation page];
        NSRect pageBounds = [page boundsForBox:[self displayBox]];
        NSRect bounds = [currentAnnotation bounds];
        CGFloat width = ignoreWidth == NO ? NSWidth(bounds) : ([page rotation] % 180) ? NSHeight(pageBounds) : NSWidth(pageBounds);
        NSSize size = SKFitTextNoteSize(string, [currentAnnotation font], width);
        switch ([page rotation]) {
            case 0:
                bounds = NSMakeRect(NSMinX(bounds), NSMaxY(bounds) - size.height, size.width, size.height);
                break;
            case 90:
                bounds = NSMakeRect(NSMinX(bounds), NSMinY(bounds), size.height, size.width);
                break;
            case 180:
                bounds = NSMakeRect(NSMaxX(bounds) - size.width, NSMinY(bounds), size.width, size.height);
                break;
            case 270:
                bounds = NSMakeRect(NSMaxX(bounds) - size.height, NSMaxY(bounds) - size.width, size.height, size.width);
                break;
        }
        bounds = SKConstrainRect(bounds, pageBounds);
        if (NSEqualRects(bounds, [currentAnnotation bounds]) == NO)
            [currentAnnotation setBounds:bounds];
        
    } else if ([[[self currentSelection] pages] containsObject:[currentAnnotation page]]) {
        
        NSRect bounds = [[self currentSelection] boundsForPage:[currentAnnotation page]];
        CGFloat lw = [currentAnnotation lineWidth];
        if ([[currentAnnotation type] isEqualToString:SKNCircleString]) {
            CGFloat dw, dh, w = NSWidth(bounds), h = NSHeight(bounds);
            if (h < w) {
                dw = primaryOutset(h / w);
                dh = secondaryOutset(dw);
            } else {
                dh = primaryOutset(w / h);
                dw = secondaryOutset(dh);
            }
            bounds = NSInsetRect(bounds, -0.5 * w * dw - lw, -0.5 * h * dh - lw);
        } else if ([[currentAnnotation type] isEqualToString:SKNCircleString]) {
            bounds = NSInsetRect(bounds, -lw, -lw);
        } else {
            NSBeep();
            return;
        }
        [currentAnnotation setBounds:bounds];
        
    } else {
        NSBeep();
    }
}

- (void)doMoveReadingBarForKey:(unichar)eventChar {
    BOOL moved = NO;
    if (eventChar == NSDownArrowFunctionKey)
        moved = [readingBar goToNextLine];
    else if (eventChar == NSUpArrowFunctionKey)
        moved = [readingBar goToPreviousLine];
    else if (eventChar == NSRightArrowFunctionKey)
        moved = [readingBar goToNextPage];
    else if (eventChar == NSLeftArrowFunctionKey)
        moved = [readingBar goToPreviousPage];
    if (moved)
        [self updatePacer];
}

- (void)doResizeReadingBarForKey:(unichar)eventChar {
    NSInteger numberOfLines = [readingBar numberOfLines];
    if (eventChar == NSDownArrowFunctionKey)
        numberOfLines++;
    else if (eventChar == NSUpArrowFunctionKey)
        numberOfLines--;
    if (numberOfLines > 0) {
        [readingBar setNumberOfLines:numberOfLines];
        [self updatePacer];
    }
}

- (void)doMoveAnnotationWithEvent:(NSEvent *)theEvent offset:(NSPoint)offset {
    // Move annotation.
    [[[self scrollView] contentView] autoscroll:theEvent];
    
    NSPoint point = NSZeroPoint;
    PDFPage *newActivePage = [self pageAndPoint:&point forEvent:theEvent nearest:YES];
    
    if (newActivePage) { // newActivePage should never be nil, but just to be sure
        if (newActivePage != [currentAnnotation page]) {
            // move the annotation to the new page
            [self moveAnnotation:currentAnnotation toPage:newActivePage];
        }
        
        NSRect newBounds = [currentAnnotation bounds];
        newBounds.origin = SKIntegralPoint(SKSubstractPoints(point, offset));
        // constrain bounds inside page bounds
        newBounds = SKConstrainRect(newBounds, [newActivePage  boundsForBox:[self displayBox]]);
        
        // Change annotation's location.
        [currentAnnotation setBounds:newBounds];
    }
}

- (void)doResizeLineAnnotationWithEvent:(NSEvent *)theEvent fromPoint:(NSPoint)originalPagePoint originalStartPoint:(NSPoint)originalStartPoint originalEndPoint:(NSPoint)originalEndPoint resizeHandle:(SKRectEdges)resizeHandle {
    PDFPage *page = [currentAnnotation page];
    NSRect pageBounds = [page  boundsForBox:[self displayBox]];
    NSPoint currentPagePoint = [self convertPoint:[theEvent locationInView:self] toPage:page];
    NSPoint relPoint = SKSubstractPoints(currentPagePoint, originalPagePoint);
    NSPoint endPoint = originalEndPoint;
    NSPoint startPoint = originalStartPoint;
    NSPoint *draggedPoint = (resizeHandle & SKMinXEdgeMask) ? &startPoint : &endPoint;
    
    *draggedPoint = SKConstrainPointInRect(SKAddPoints(*draggedPoint, relPoint), pageBounds);
    draggedPoint->x = floor(draggedPoint->x);
    draggedPoint->y = floor(draggedPoint->y);
    
    if (([theEvent modifierFlags] & NSShiftKeyMask)) {
        NSPoint *fixedPoint = (resizeHandle & SKMinXEdgeMask) ? &endPoint : &startPoint;
        NSPoint diffPoint = SKSubstractPoints(*draggedPoint, *fixedPoint);
        CGFloat dx = fabs(diffPoint.x), dy = fabs(diffPoint.y);
        
        if (dx < 0.4 * dy) {
            diffPoint.x = 0.0;
        } else if (dy < 0.4 * dx) {
            diffPoint.y = 0.0;
        } else {
            dx = fmin(dx, dy);
            diffPoint.x = diffPoint.x < 0.0 ? -dx : dx;
            diffPoint.y = diffPoint.y < 0.0 ? -dx : dx;
        }
        *draggedPoint = SKAddPoints(*fixedPoint, diffPoint);
    }
    
    if (NSEqualPoints(startPoint, endPoint) == NO) {
        NSRect newBounds = SKIntegralRectFromPoints(startPoint, endPoint);
        
        if (NSWidth(newBounds) < MIN_NOTE_SIZE) {
            newBounds.size.width = MIN_NOTE_SIZE;
            newBounds.origin.x = floor(0.5 * ((startPoint.x + endPoint.x) - MIN_NOTE_SIZE));
        }
        if (NSHeight(newBounds) < MIN_NOTE_SIZE) {
            newBounds.size.height = MIN_NOTE_SIZE;
            newBounds.origin.y = floor(0.5 * ((startPoint.y + endPoint.y) - MIN_NOTE_SIZE));
        }
        
        [(PDFAnnotationLine *)currentAnnotation setObservedStartPoint:SKSubstractPoints(startPoint, newBounds.origin)];
        [(PDFAnnotationLine *)currentAnnotation setObservedEndPoint:SKSubstractPoints(endPoint, newBounds.origin)];
        [currentAnnotation setBounds:newBounds];
    }
}

- (void)doResizeAnnotationWithEvent:(NSEvent *)theEvent fromPoint:(NSPoint)originalPagePoint originalBounds:(NSRect)originalBounds originalPaths:(NSArray *)originalPaths margin:(CGFloat)margin resizeHandle:(SKRectEdges *)resizeHandlePtr {
    PDFPage *page = [currentAnnotation page];
    NSRect newBounds = originalBounds;
    NSRect pageBounds = [page  boundsForBox:[self displayBox]];
    NSPoint currentPagePoint = [self convertPoint:[theEvent locationInView:self] toPage:page];
    NSPoint relPoint = SKSubstractPoints(currentPagePoint, originalPagePoint);
    SKRectEdges resizeHandle = *resizeHandlePtr;
    CGFloat minSize = fmax(MIN_NOTE_SIZE, 2.0 * margin + 2.0);
    BOOL isInk = [currentAnnotation isInk];
    
    if (NSEqualSizes(originalBounds.size, NSZeroSize)) {
        SKRectEdges currentResizeHandle = (relPoint.x < 0.0 ? SKMinXEdgeMask : SKMaxXEdgeMask) | (relPoint.y <= 0.0 ? SKMinYEdgeMask : SKMaxYEdgeMask);
        if (currentResizeHandle != resizeHandle) {
            *resizeHandlePtr = resizeHandle = currentResizeHandle;
            [self setCursorForAreaOfInterest:SKAreaOfInterestForResizeHandle(resizeHandle, page)];
        }
    }
    
    if (([theEvent modifierFlags] & NSShiftKeyMask) == 0) {
        
        if ((resizeHandle & SKMaxXEdgeMask)) {
            newBounds.size.width += relPoint.x;
            if (NSMaxX(newBounds) > NSMaxX(pageBounds))
                newBounds.size.width = NSMaxX(pageBounds) - NSMinX(newBounds);
            if (NSWidth(newBounds) < minSize) {
                newBounds.size.width = minSize;
            }
        } else if ((resizeHandle & SKMinXEdgeMask)) {
            newBounds.origin.x += relPoint.x;
            newBounds.size.width -= relPoint.x;
            if (NSMinX(newBounds) < NSMinX(pageBounds)) {
                newBounds.size.width = NSMaxX(newBounds) - NSMinX(pageBounds);
                newBounds.origin.x = NSMinX(pageBounds);
            }
            if (NSWidth(newBounds) < minSize) {
                newBounds.origin.x = NSMaxX(newBounds) - minSize;
                newBounds.size.width = minSize;
            }
        }
        if ((resizeHandle & SKMaxYEdgeMask)) {
            newBounds.size.height += relPoint.y;
            if (NSMaxY(newBounds) > NSMaxY(pageBounds)) {
                newBounds.size.height = NSMaxY(pageBounds) - NSMinY(newBounds);
            }
            if (NSHeight(newBounds) < minSize) {
                newBounds.size.height = minSize;
            }
        } else if ((resizeHandle & SKMinYEdgeMask)) {
            newBounds.origin.y += relPoint.y;
            newBounds.size.height -= relPoint.y;
            if (NSMinY(newBounds) < NSMinY(pageBounds)) {
                newBounds.size.height = NSMaxY(newBounds) - NSMinY(pageBounds);
                newBounds.origin.y = NSMinY(pageBounds);
            }
            if (NSHeight(newBounds) < minSize) {
                newBounds.origin.y = NSMaxY(newBounds) - minSize;
                newBounds.size.height = minSize;
            }
        }
        
    } else {
        
        CGFloat width = NSWidth(newBounds);
        CGFloat height = NSHeight(newBounds);
        CGFloat ds = 2.0 * margin;
        CGFloat ratio = isInk ? fmax(1.0, NSWidth(originalBounds) - ds) / fmax(1.0, NSHeight(originalBounds) - ds) : 1.0;

        if ((resizeHandle & SKMaxXEdgeMask))
            width = fmax(minSize, width + relPoint.x);
        else if ((resizeHandle & SKMinXEdgeMask))
            width = fmax(minSize, width - relPoint.x);
        if ((resizeHandle & SKMaxYEdgeMask))
            height = fmax(minSize, height + relPoint.y);
        else if ((resizeHandle & SKMinYEdgeMask))
            height = fmax(minSize, height - relPoint.y);
        
        if ((resizeHandle & (SKMinXEdgeMask | SKMaxXEdgeMask)) == 0) {
            width = ds + (height - ds) * ratio;
            if (width < minSize) {
                width = minSize;
                height = ds + (width - ds) / ratio;
            }
        } else if ((resizeHandle & (SKMinYEdgeMask | SKMaxYEdgeMask)) == 0) {
            height = ds + (width - ds) / ratio;
            if (height < minSize) {
                height = minSize;
                width = ds + (height - ds) * ratio;
            }
        } else {
            width = fmax(width, ds + (height - ds) * ratio);
            height = ds + (width - ds) / ratio;
        }
        
        if ((resizeHandle & SKMinXEdgeMask)) {
            if (NSMaxX(newBounds) - width < NSMinX(pageBounds)) {
                width = fmax(minSize, NSMaxX(newBounds) - NSMinX(pageBounds));
                height = ds + (width - ds) / ratio;
            }
        } else {
            if (NSMinX(newBounds) + width > NSMaxX(pageBounds)) {
                width = fmax(minSize, NSMaxX(pageBounds) - NSMinX(newBounds));
                height = ds + (width - ds) / ratio;
            }
        }
        if ((resizeHandle & SKMinYEdgeMask)) {
            if (NSMaxY(newBounds) - height < NSMinY(pageBounds)) {
                height = fmax(minSize, NSMaxY(newBounds) - NSMinY(pageBounds));
                width = ds + (height - ds) * ratio;
            }
        } else {
            if (NSMinY(newBounds) + height > NSMaxY(pageBounds)) {
                height = fmax(minSize, NSMaxY(pageBounds) - NSMinY(newBounds));
                width = ds + (height - ds) * ratio;
            }
        }
        
        if ((resizeHandle & SKMinXEdgeMask))
            newBounds.origin.x = NSMaxX(newBounds) - width;
        if ((resizeHandle & SKMinYEdgeMask))
            newBounds.origin.y = NSMaxY(newBounds) - height;
        newBounds.size.width = width;
        newBounds.size.height = height;
        
    }
    
    newBounds = NSIntegralRect(newBounds);
    
    if (isInk) {
        NSMutableArray *paths = [NSMutableArray array];
        NSAffineTransform *transform = [NSAffineTransform transform];
        CGFloat sx = fmax(1.0, NSWidth(newBounds) - 2.0 * margin) / fmax(1.0, NSWidth(originalBounds) - 2.0 * margin);
        CGFloat sy = fmax(1.0, NSHeight(newBounds) - 2.0 * margin) / fmax(1.0, NSHeight(originalBounds) - 2.0 * margin);
        
        [transform translateXBy:margin yBy:margin];
        if (([theEvent modifierFlags] & NSShiftKeyMask))
            [transform scaleBy:fmin(sx, sy)];
        else
            [transform scaleXBy:sx yBy:sy];
        [transform translateXBy:-margin yBy:-margin];
        
        for (NSBezierPath *path in originalPaths)
            [paths addObject:[transform transformBezierPath:path]];
        
        [(PDFAnnotationInk *)currentAnnotation setBezierPaths:paths];
    }
    
    [currentAnnotation setBounds:newBounds];
}

- (void)updateCursorForMouse:(NSEvent *)theEvent {
    [self setCursorForAreaOfInterest:[self areaOfInterestForMouse:theEvent]];
}

- (void)doDragAnnotationWithEvent:(NSEvent *)theEvent {
    // currentAnnotation should be movable, or nil to be added in an appropriate note tool mode
    
    // Old (current) annotation location and click point relative to it
    NSRect originalBounds = [currentAnnotation bounds];
    BOOL isLine = [currentAnnotation isLine];
    NSPoint pagePoint = NSZeroPoint;
    PDFPage *page = [self pageAndPoint:&pagePoint forEvent:theEvent nearest:YES];
    BOOL shouldAddAnnotation = currentAnnotation == nil;
    NSPoint originalStartPoint = NSZeroPoint;
    NSPoint originalEndPoint = NSZeroPoint;
    NSArray *originalPaths = nil;
    CGFloat margin = 0.0;
    
    // Hit-test for resize box.
    SKRectEdges resizeHandle = [currentAnnotation resizeHandleForPoint:pagePoint scaleFactor:[self scaleFactor]];
    
    if (RUNNING_AFTER(10_11)) {
        atomic_store(&highlightLayerState, SKLayerAdd);
        if (currentAnnotation)
            [self setNeedsDisplayForAnnotation:currentAnnotation];
    }
    
    if (shouldAddAnnotation) {
        if (annotationMode == SKAnchoredNote) {
            [self addAnnotationWithType:SKAnchoredNote selection:nil page:page bounds:SKRectFromCenterAndSquareSize(SKIntegralPoint(pagePoint), 0.0)];
            originalBounds = [[self currentAnnotation] bounds];
        } else {
            originalBounds = SKRectFromCenterAndSquareSize(SKIntegralPoint(pagePoint), 0.0);
            if (annotationMode == SKLineNote) {
                isLine = YES;
                resizeHandle = SKMaxXEdgeMask;
                originalStartPoint = originalEndPoint = originalBounds.origin;
            } else {
                resizeHandle = SKMaxXEdgeMask | SKMinYEdgeMask;
            }
        }
    } else if (isLine) {
        originalStartPoint = SKIntegralPoint(SKAddPoints([(PDFAnnotationLine *)currentAnnotation startPoint], originalBounds.origin));
        originalEndPoint = SKIntegralPoint(SKAddPoints([(PDFAnnotationLine *)currentAnnotation endPoint], originalBounds.origin));
    } else if ([currentAnnotation isInk]) {
        originalPaths = [[[(PDFAnnotationInk *)currentAnnotation paths] copy] autorelease];
        margin = [(PDFAnnotationInk *)currentAnnotation pathInset];
    }
    
    // we move or resize the annotation in an event loop, which ensures it's enclosed in a single undo group
    BOOL draggedAnnotation = NO;
    NSEvent *lastMouseEvent = theEvent;
    NSPoint offset = SKSubstractPoints(pagePoint, originalBounds.origin);
    NSUInteger eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask;
    
    [self setCursorForAreaOfInterest:SKAreaOfInterestForResizeHandle(resizeHandle, page)];
    if (resizeHandle == 0) {
        [[NSCursor closedHandCursor] push];
        [NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.1];
        eventMask |= NSPeriodicMask;
    }
    
    while (YES) {
        theEvent = [[self window] nextEventMatchingMask:eventMask];
        if ([theEvent type] == NSLeftMouseUp) {
            break;
        } else if ([theEvent type] == NSLeftMouseDragged) {
            if (currentAnnotation == nil) {
                [self addAnnotationWithType:annotationMode selection:nil page:page bounds:SKRectFromCenterAndSquareSize(originalBounds.origin, 0.0)];
            }
            lastMouseEvent = theEvent;
            draggedAnnotation = YES;
        } else if (currentAnnotation == nil) {
            continue;
        }
        [self beginNewUndoGroupIfNeeded];
        if (resizeHandle == 0)
            [self doMoveAnnotationWithEvent:lastMouseEvent offset:offset];
        else if (isLine)
            [self doResizeLineAnnotationWithEvent:lastMouseEvent fromPoint:pagePoint originalStartPoint:originalStartPoint originalEndPoint:originalEndPoint resizeHandle:resizeHandle];
        else
            [self doResizeAnnotationWithEvent:lastMouseEvent fromPoint:pagePoint originalBounds:originalBounds originalPaths:originalPaths margin:margin resizeHandle:&resizeHandle];
        if (RUNNING_AFTER(10_11))
            [[highlightLayerController layer] setNeedsDisplay];
    }
    
    if (resizeHandle == 0) {
        [NSEvent stopPeriodicEvents];
        [NSCursor pop];
    }
    
    if (currentAnnotation) {
        if (draggedAnnotation)
            [currentAnnotation autoUpdateString];
        
        if (shouldAddAnnotation && toolMode == SKNoteToolMode && (annotationMode == SKAnchoredNote || annotationMode == SKFreeTextNote))
            [self editCurrentAnnotation:self]; 	 
        
        if (RUNNING_AFTER(10_11))
            atomic_store(&highlightLayerState, SKLayerRemove);
        [self setNeedsDisplayForAnnotation:currentAnnotation];
    } else if (RUNNING_AFTER(10_11)) {
        atomic_store(&highlightLayerState, SKLayerNone);
        [self removeHighlightLayer];
    }
    
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(setCursorForMouse:) withObject:theEvent afterDelay:0];
}

- (void)doClickLinkWithEvent:(NSEvent *)theEvent {
	PDFAnnotation *annotation = currentAnnotation;
    PDFPage *annotationPage = [annotation page];
    NSRect bounds = [annotation bounds];
    
    while (YES) {
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        
        if ([theEvent type] == NSLeftMouseUp)
            break;
        
        NSPoint point = NSZeroPoint;
        PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:NO];
        if (page == annotationPage && NSPointInRect(point, bounds))
            [self setCurrentAnnotation:annotation];
        else
            [self setCurrentAnnotation:nil];
	}
    
    if (currentAnnotation)
        [self editCurrentAnnotation:nil];
}

- (BOOL)doSelectAnnotationWithEvent:(NSEvent *)theEvent {
    PDFAnnotation *newCurrentAnnotation = nil;
    NSPoint point = NSZeroPoint;
    PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:YES];
    
    if ([currentAnnotation page] == page && [currentAnnotation isResizable] && [currentAnnotation resizeHandleForPoint:point scaleFactor:[self scaleFactor]] != 0) {
        newCurrentAnnotation = currentAnnotation;
    } else {
        
        PDFAnnotation *linkAnnotation = nil;
        BOOL foundCoveringAnnotation = NO;
        id annotations = RUNNING(10_12) ? [page annotations] : [[page annotations] reverseObjectEnumerator];
        
        // Hit test for annotation.
        for (PDFAnnotation *annotation in annotations) {
            if ([annotation isSkimNote] && [annotation hitTest:point] && [self isEditingAnnotation:annotation] == NO) {
                newCurrentAnnotation = annotation;
                break;
            } else if ([annotation shouldDisplay] && NSPointInRect(point, [annotation bounds]) && (toolMode == SKTextToolMode || IS_MARKUP(annotationMode)) && linkAnnotation == nil) {
                if ([annotation isLink])
                    linkAnnotation = annotation;
                else
                    foundCoveringAnnotation = YES;
            }
        }
        
        // if we did not find a Skim note, get the first link covered by another annotation to click
        if (newCurrentAnnotation == nil && linkAnnotation && foundCoveringAnnotation)
            newCurrentAnnotation = linkAnnotation;
    }
    
    if (pdfvFlags.hideNotes == NO && [[self document] allowsNotes] && page != nil && newCurrentAnnotation != nil) {
        BOOL isInk = toolMode == SKNoteToolMode && annotationMode == SKInkNote;
        NSUInteger modifiers = [theEvent modifierFlags];
        if ((modifiers & NSAlternateKeyMask) && [newCurrentAnnotation isMovable] &&
            [newCurrentAnnotation resizeHandleForPoint:point scaleFactor:[self scaleFactor]] == 0) {
            // select a new copy of the annotation
            PDFAnnotation *newAnnotation = [[PDFAnnotation alloc] initSkimNoteWithProperties:[newCurrentAnnotation SkimNoteProperties]];
            [newAnnotation registerUserName];
            [self addAnnotation:newAnnotation toPage:page];
            [[self undoManager] setActionName:NSLocalizedString(@"Add Note", @"Undo action name")];
            newCurrentAnnotation = newAnnotation;
            [newAnnotation release];
        } else if (([newCurrentAnnotation isMarkup] ||
                    (isInk && (newCurrentAnnotation != currentAnnotation || (modifiers & (NSShiftKeyMask | NSAlphaShiftKeyMask))))) &&
                   [NSApp willDragMouse]) {
            // don't drag markup notes or in freehand tool mode, unless the note was previously selected, so we can select text or draw freehand strokes
            newCurrentAnnotation = nil;
        } else if ((modifiers & NSShiftKeyMask) && currentAnnotation != newCurrentAnnotation && [[currentAnnotation page] isEqual:[newCurrentAnnotation page]] && [[currentAnnotation type] isEqualToString:[newCurrentAnnotation type]]) {
            PDFAnnotation *newAnnotation = nil;
            if ([currentAnnotation isMarkup]) {
                NSInteger markupType = [(PDFAnnotationMarkup *)currentAnnotation markupType];
                PDFSelection *sel = [(PDFAnnotationMarkup *)currentAnnotation selection];
                [sel addSelection:[(PDFAnnotationMarkup *)newCurrentAnnotation selection]];
                
                newAnnotation = [[[PDFAnnotationMarkup alloc] initSkimNoteWithSelection:sel markupType:markupType] autorelease];
                [newAnnotation setString:[sel cleanedString]];
            } else if ([currentAnnotation isInk]) {
                NSMutableArray *paths = [[(PDFAnnotationInk *)currentAnnotation pagePaths] mutableCopy];
                [paths addObjectsFromArray:[(PDFAnnotationInk *)newCurrentAnnotation pagePaths]];
                NSString *string1 = [currentAnnotation string];
                NSString *string2 = [newCurrentAnnotation string];
                
                newAnnotation = [[[PDFAnnotationInk alloc] initSkimNoteWithPaths:paths] autorelease];
                [newAnnotation setString:[string2 length] == 0 ? string1 : [string1 length] == 0 ? string2 : [NSString stringWithFormat:@"%@ %@", string1, string2]];
                [newAnnotation setBorder:[currentAnnotation border]];
                
                [paths release];
            }
            if (newAnnotation) {
                [newAnnotation setColor:[currentAnnotation color]];
                [newAnnotation registerUserName];
                [self removeAnnotation:newCurrentAnnotation];
                [self removeCurrentAnnotation:nil];
                [self addAnnotation:newAnnotation toPage:page];
                [[self undoManager] setActionName:NSLocalizedString(@"Join Notes", @"Undo action name")];
                newCurrentAnnotation = newAnnotation;
            }
        }
    }
    
    if (newCurrentAnnotation && newCurrentAnnotation != currentAnnotation)
        [self setCurrentAnnotation:newCurrentAnnotation];
    
    return newCurrentAnnotation != nil;
}

- (void)doDrawFreehandNoteWithEvent:(NSEvent *)theEvent {
    NSPoint point = NSZeroPoint;
    PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:YES];
    NSWindow *window = [self window];
    BOOL wasMouseCoalescingEnabled = [NSEvent isMouseCoalescingEnabled];
    BOOL isOption = ([theEvent modifierFlags] & NSAlternateKeyMask) != 0;
    BOOL wasOption = NO;
    BOOL wantsBreak = isOption;
    NSBezierPath *bezierPath = nil;
    CAShapeLayer *layer = nil;
    NSRect boxBounds = NSIntersectionRect([page boundsForBox:[self displayBox]], [self convertRect:[self visibleContentRect] toPage:page]);
    CGAffineTransform t = CGAffineTransformRotate(CGAffineTransformMakeScale([self scaleFactor], [self scaleFactor]), -M_PI_2 * [page rotation] / 90.0);
    CGFloat r = fmin(2.0, 2.0 * [self scaleFactor]);
    layer = [CAShapeLayer layer];
    // transform and place so that the path is in page coordinates
    [layer setBounds:NSRectToCGRect(boxBounds)];
    [layer setAnchorPoint:CGPointZero];
    [layer setPosition:NSPointToCGPoint([self convertPoint:boxBounds.origin fromPage:page])];
    [layer setAffineTransform:t];
    [layer setZPosition:1.0];
    [layer setMasksToBounds:YES];
    [layer setFillColor:NULL];
    [layer setLineJoin:kCALineJoinRound];
    [layer setLineCap:kCALineCapRound];
    if (([theEvent modifierFlags] & (NSShiftKeyMask | NSAlphaShiftKeyMask)) && [currentAnnotation isInk] && [[currentAnnotation page] isEqual:page]) {
        [layer setStrokeColor:[[currentAnnotation color] CGColor]];
        [layer setLineWidth:[currentAnnotation lineWidth]];
        if ([currentAnnotation borderStyle] == kPDFBorderStyleDashed) {
            [layer setLineDashPattern:[currentAnnotation dashPattern]];
            [layer setLineCap:kCALineCapButt];
        }
        [layer setShadowRadius:r / [self scaleFactor]];
        [layer setShadowOffset:CGSizeApplyAffineTransform(CGSizeMake(0.0, -r), CGAffineTransformInvert(t))];
        [layer setShadowOpacity:0.33333];
    } else {
        [self setCurrentAnnotation:nil];
        NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
        [layer setStrokeColor:[[sud colorForKey:SKInkNoteColorKey] CGColor]];
        [layer setLineWidth:[sud floatForKey:SKInkNoteLineWidthKey]];
        if ((PDFBorderStyle)[sud integerForKey:SKInkNoteLineStyleKey] == kPDFBorderStyleDashed) {
            [layer setLineDashPattern:[sud arrayForKey:SKInkNoteDashPatternKey]];
            [layer setLineCap:kCALineCapButt];
        }
    }
    
    [layer setContentsScale:[[self layer] contentsScale]];
    [[self layer] addSublayer:layer];
    [layer setFilters:SKColorEffectFilters()];
    
    // don't coalesce mouse event from mouse while drawing,
    // but not from tablets because those fire very rapidly and lead to serious delays
    if ([NSEvent currentPointingDeviceType] == NSUnknownPointingDevice)
        [NSEvent setMouseCoalescingEnabled:NO];
    
    while (YES) {
        theEvent = [window nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSFlagsChangedMask];
        
        if ([theEvent type] == NSLeftMouseUp) {
            
            break;
            
        } else if ([theEvent type] == NSLeftMouseDragged) {
            
            if (bezierPath == nil) {
                bezierPath = [NSBezierPath bezierPath];
                [bezierPath moveToPoint:point];
            } else if (wantsBreak && NO == NSEqualPoints(point, [bezierPath associatedPointForElementAtIndex:[bezierPath elementCount] - 2])) {
                [PDFAnnotationInk addPoint:point toSkimNotesPath:bezierPath];
            }
            
            point = [self convertPoint:[theEvent locationInView:self] toPage:page];
            
            if (isOption && wantsBreak == NO) {
                NSInteger eltCount = [bezierPath elementCount];
                NSPoint points[3] = {point, point, point};
                if (NSCurveToBezierPathElement == [bezierPath elementAtIndex:eltCount - 1]) {
                    points[0] = [bezierPath associatedPointForElementAtIndex:eltCount - 2];
                    points[0].x += ( point.x - points[0].x ) / 3.0;
                    points[0].y += ( point.y - points[0].y ) / 3.0;
                }
                [bezierPath setAssociatedPoints:points atIndex:eltCount - 1];
            } else {
                [PDFAnnotationInk addPoint:point toSkimNotesPath:bezierPath];
            }
            
            wasOption = isOption;
            wantsBreak = NO;
            
            [layer setPath:[bezierPath CGPath]];
            
        } else if ((([theEvent modifierFlags] & NSAlternateKeyMask) != 0) != isOption) {
            
            isOption = isOption == NO;
            wantsBreak = isOption || wasOption;
            
        }
    }
    
    [layer removeFromSuperlayer];
    
    [NSEvent setMouseCoalescingEnabled:wasMouseCoalescingEnabled];
    
    if (bezierPath) {
        NSMutableArray *paths = [[NSMutableArray alloc] init];
        if (currentAnnotation)
            [paths addObjectsFromArray:[(PDFAnnotationInk *)currentAnnotation pagePaths]];
        [paths addObject:bezierPath];
        
        PDFAnnotationInk *annotation = [[PDFAnnotationInk alloc] initSkimNoteWithPaths:paths];
        if (currentAnnotation) {
            [annotation setColor:[currentAnnotation color]];
            [annotation setBorder:[currentAnnotation border]];
            [annotation setString:[currentAnnotation string]];
        }
        [annotation registerUserName]; 
        [self addAnnotation:annotation toPage:page];
        [[self undoManager] setActionName:NSLocalizedString(@"Add Note", @"Undo action name")];
        
        [paths release];
        [annotation release];
        
        if (currentAnnotation) {
            [self removeCurrentAnnotation:nil];
            [self setCurrentAnnotation:annotation];
        } else if (([theEvent modifierFlags] & (NSShiftKeyMask | NSAlphaShiftKeyMask))) {
            [self setCurrentAnnotation:annotation];
        }
    } else if (([theEvent modifierFlags] & NSAlphaShiftKeyMask)) {
        [self setCurrentAnnotation:nil];
    }
    
}

- (void)doEraseAnnotationsWithEvent:(NSEvent *)theEvent {
    while (YES) {
        theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        if ([theEvent type] == NSLeftMouseUp)
            break;
        
        NSPoint point = NSZeroPoint;
        PDFPage *page = [self pageAndPoint:&point forEvent:theEvent nearest:YES];
        id annotations = RUNNING(10_12) ? [page annotations] : [[page annotations] reverseObjectEnumerator];
        
        for (PDFAnnotation *annotation in annotations) {
            if ([annotation isSkimNote] && [annotation hitTest:point] && [self isEditingAnnotation:annotation] == NO) {
                [self removeAnnotation:annotation];
                [[self undoManager] setActionName:NSLocalizedString(@"Remove Note", @"Undo action name")];
                break;
            }
        }
    }
}

- (void)doSelectWithEvent:(NSEvent *)theEvent {
    NSPoint initialPoint = NSZeroPoint;
    PDFPage *page = [self pageAndPoint:&initialPoint forEvent:theEvent nearest:NO];
    if (page == nil) {
        // should never get here, see mouseDown:
        [self doDragMouseWithEvent:theEvent];
        return;
    }
    
    CGFloat margin = HANDLE_SIZE / [self scaleFactor];
    
    if (selectionPageIndex != NSNotFound && [page pageIndex] != selectionPageIndex) {
        [self setNeedsDisplayInRect:NSInsetRect(selectionRect, -margin, -margin) ofPage:[self currentSelectionPage]];
        [self setNeedsDisplayInRect:NSInsetRect(selectionRect, -margin, -margin) ofPage:page];
    }
    
    selectionPageIndex = [page pageIndex];
    
    BOOL didSelect = (NO == NSIsEmptyRect(selectionRect));
    
    SKRectEdges resizeHandle = didSelect ? SKResizeHandleForPointFromRect(initialPoint, selectionRect, margin) : 0;
    
    if (resizeHandle == 0 && (didSelect == NO || NSPointInRect(initialPoint, selectionRect) == NO)) {
        selectionRect.origin = initialPoint;
        selectionRect.size = NSZeroSize;
        resizeHandle = SKMaxXEdgeMask | SKMinYEdgeMask;
        if (didSelect)
            [self requiresDisplay];
    }
    
	NSRect initialRect = selectionRect;
    NSRect pageBounds = [page boundsForBox:[self displayBox]];
    SKRectEdges newEffectiveResizeHandle, effectiveResizeHandle = resizeHandle;
    
    [self setCursorForAreaOfInterest:SKAreaOfInterestForResizeHandle(resizeHandle, page)];
    
	while (YES) {
        
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        if ([theEvent type] == NSLeftMouseUp)
            break;
		
        // we must be dragging
        NSPoint	newPoint;
        NSRect	newRect = initialRect;
        NSPoint delta;
        
        newPoint = [self convertPoint:[theEvent locationInView:self] toPage:page];
        delta = SKSubstractPoints(newPoint, initialPoint);
        
        if (resizeHandle) {
            newEffectiveResizeHandle = 0;
            if ((resizeHandle & SKMaxXEdgeMask))
                newEffectiveResizeHandle |= newPoint.x < NSMinX(initialRect) ? SKMinXEdgeMask : SKMaxXEdgeMask;
            else if ((resizeHandle & SKMinXEdgeMask))
                newEffectiveResizeHandle |= newPoint.x > NSMaxX(initialRect) ? SKMaxXEdgeMask : SKMinXEdgeMask;
            if ((resizeHandle & SKMaxYEdgeMask))
                newEffectiveResizeHandle |= newPoint.y < NSMinY(initialRect) ? SKMinYEdgeMask : SKMaxYEdgeMask;
            else if ((resizeHandle & SKMinYEdgeMask))
                newEffectiveResizeHandle |= newPoint.y > NSMaxY(initialRect) ? SKMaxYEdgeMask : SKMinYEdgeMask;
            if (newEffectiveResizeHandle != effectiveResizeHandle) {
                effectiveResizeHandle = newEffectiveResizeHandle;
                [self setCursorForAreaOfInterest:SKAreaOfInterestForResizeHandle(effectiveResizeHandle, page)];
            }
        }
        
        if (resizeHandle == 0) {
            newRect.origin = SKAddPoints(newRect.origin, delta);
        } else if (([theEvent modifierFlags] & NSShiftKeyMask)) {
            CGFloat width = NSWidth(newRect);
            CGFloat height = NSHeight(newRect);
            CGFloat square;
            
            if ((resizeHandle & SKMaxXEdgeMask))
                width += delta.x;
            else if ((resizeHandle & SKMinXEdgeMask))
                width -= delta.x;
            if ((resizeHandle & SKMaxYEdgeMask))
                height += delta.y;
            else if ((resizeHandle & SKMinYEdgeMask))
                height -= delta.y;
            
            if (0 == (resizeHandle & (SKMinXEdgeMask | SKMaxXEdgeMask)))
                square = fabs(height);
            else if (0 == (resizeHandle & (SKMinYEdgeMask | SKMaxYEdgeMask)))
                square = fabs(width);
            else
                square = fmax(fabs(width), fabs(height));
            
            if ((resizeHandle & SKMinXEdgeMask)) {
                if (width >= 0.0 && NSMaxX(newRect) - square < NSMinX(pageBounds))
                    square = NSMaxX(newRect) - NSMinX(pageBounds);
                else if (width < 0.0 && NSMaxX(newRect) + square > NSMaxX(pageBounds))
                    square =  NSMaxX(pageBounds) - NSMaxX(newRect);
            } else {
                if (width >= 0.0 && NSMinX(newRect) + square > NSMaxX(pageBounds))
                    square = NSMaxX(pageBounds) - NSMinX(newRect);
                else if (width < 0.0 && NSMinX(newRect) - square < NSMinX(pageBounds))
                    square = NSMinX(newRect) - NSMinX(pageBounds);
            }
            if ((resizeHandle & SKMinYEdgeMask)) {
                if (height >= 0.0 && NSMaxY(newRect) - square < NSMinY(pageBounds))
                    square = NSMaxY(newRect) - NSMinY(pageBounds);
                else if (height < 0.0 && NSMaxY(newRect) + square > NSMaxY(pageBounds))
                    square = NSMaxY(pageBounds) - NSMaxY(newRect);
            } else {
                if (height >= 0.0 && NSMinY(newRect) + square > NSMaxY(pageBounds))
                    square = NSMaxY(pageBounds) - NSMinY(newRect);
                if (height < 0.0 && NSMinY(newRect) - square < NSMinY(pageBounds))
                    square = NSMinY(newRect) - NSMinY(pageBounds);
            }
            
            if ((resizeHandle & SKMinXEdgeMask))
                newRect.origin.x = width < 0.0 ? NSMaxX(newRect) : NSMaxX(newRect) - square;
            else if (width < 0.0 && (resizeHandle & SKMaxXEdgeMask))
                newRect.origin.x = NSMinX(newRect) - square;
            if ((resizeHandle & SKMinYEdgeMask))
                newRect.origin.y = height < 0.0 ? NSMaxY(newRect) : NSMaxY(newRect) - square;
            else if (height < 0.0 && (resizeHandle & SKMaxYEdgeMask))
                newRect.origin.y = NSMinY(newRect) - square;
            newRect.size.width = newRect.size.height = square;
        } else {
            if ((resizeHandle & SKMaxXEdgeMask)) {
                newRect.size.width += delta.x;
                if (NSWidth(newRect) < 0.0) {
                    newRect.size.width *= -1.0;
                    newRect.origin.x -= NSWidth(newRect);
                }
            } else if ((resizeHandle & SKMinXEdgeMask)) {
                newRect.origin.x += delta.x;
                newRect.size.width -= delta.x;
                if (NSWidth(newRect) < 0.0) {
                    newRect.size.width *= -1.0;
                    newRect.origin.x -= NSWidth(newRect);
                }
            }
            
            if ((resizeHandle & SKMaxYEdgeMask)) {
                newRect.size.height += delta.y;
                if (NSHeight(newRect) < 0.0) {
                    newRect.size.height *= -1.0;
                    newRect.origin.y -= NSHeight(newRect);
                }
            } else if ((resizeHandle & SKMinYEdgeMask)) {
                newRect.origin.y += delta.y;
                newRect.size.height -= delta.y;
                if (NSHeight(newRect) < 0.0) {
                    newRect.size.height *= -1.0;
                    newRect.origin.y -= NSHeight(newRect);
                }
            }
        }
        
        // don't use NSIntersectionRect, because we want to keep empty rects
        newRect = SKIntersectionRect(newRect, pageBounds);
        if (didSelect) {
            NSRect dirtyRect = NSUnionRect(NSInsetRect(selectionRect, -margin, -margin), NSInsetRect(newRect, -margin, -margin));
            for (PDFPage *p in [self displayedPages])
                [self setNeedsDisplayInRect:dirtyRect ofPage:p];
        } else {
            [self requiresDisplay];
            didSelect = YES;
        }
        @synchronized (self) {
            selectionRect = newRect;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewSelectionChangedNotification object:self];
	}
    
    if (NSIsEmptyRect(selectionRect)) {
        @synchronized (self) {
            selectionRect = NSZeroRect;
            selectionPageIndex = NSNotFound;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewSelectionChangedNotification object:self];
        [self requiresDisplay];
    } else if (resizeHandle) {
        [self setNeedsDisplayInRect:NSInsetRect(selectionRect, -margin, -margin) ofPage:page];
    }
    
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(setCursorForMouse:) withObject:theEvent afterDelay:0];
}

- (void)doDragReadingBarWithEvent:(NSEvent *)theEvent {
    PDFPage *readingBarPage = [readingBar page];
    PDFPage *page = readingBarPage;
    NSInteger numberOfLines = [[page lineRects] count];
    NSInteger lineAngle = [page lineDirectionAngle];
    
    NSEvent *lastMouseEvent = theEvent;
    NSPoint lastMouseLoc = [theEvent locationInView:self];
    NSPoint point = [self convertPoint:lastMouseLoc toPage:page];
    NSInteger lineOffset = [page indexOfLineRectAtPoint:point lower:YES] - [readingBar currentLine];
    NSDate *lastPageChangeDate = [NSDate distantPast];
    BOOL isDoubleClick = [theEvent clickCount] == 2;
    
    lastMouseLoc = [self convertPoint:lastMouseLoc toView:[self documentView]];
    
    [[NSCursor closedHandBarCursor] push];
    
    [NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.1];
    
	while (YES) {
		
        theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask];
		
        if ([theEvent type] == NSLeftMouseUp)
            break;
        if ([theEvent type] == NSLeftMouseDragged) {
            lastMouseEvent = theEvent;
            isDoubleClick = NO;
        }
        
        // dragging
        NSPoint mouseLocInWindow = [lastMouseEvent locationInWindow];
        NSPoint mouseLoc = [self convertPoint:mouseLocInWindow fromView:nil];
        if ([[[self scrollView] contentView] autoscroll:lastMouseEvent] == NO &&
            ([self displayMode] == kPDFDisplaySinglePage || [self displayMode] == kPDFDisplayTwoUp) &&
            [[NSDate date] timeIntervalSinceDate:lastPageChangeDate] > 0.7) {
            if (mouseLoc.y < NSMinY([self bounds])) {
                if ([self canGoToNextPage]) {
                    [self goToNextPage:self];
                    lastMouseLoc.y = NSMaxY([[self documentView] bounds]);
                    lastPageChangeDate = [NSDate date];
                }
            } else if (mouseLoc.y > NSMaxY([self bounds])) {
                if ([self canGoToPreviousPage]) {
                    [self goToPreviousPage:self];
                    lastMouseLoc.y = NSMinY([[self documentView] bounds]);
                    lastPageChangeDate = [NSDate date];
                }
            }
        }
        
        mouseLoc = [self convertPoint:mouseLocInWindow fromView:nil];
        
        PDFPage *mousePage = [self pageForPoint:mouseLoc nearest:YES];
        NSPoint mouseLocInPage = [self convertPoint:mouseLoc toPage:mousePage];
        NSPoint mouseLocInDocument = [self convertPoint:mouseLoc toView:[self documentView]];
        NSInteger currentLine;
        
        if ([mousePage isEqual:page] == NO) {
            page = mousePage;
            numberOfLines = [[page lineRects] count];
            lineAngle = [page lineDirectionAngle];
        }
        
        if (numberOfLines == 0)
            continue;
        
        currentLine = [page indexOfLineRectAtPoint:mouseLocInPage lower:mouseLocInDocument.y < lastMouseLoc.y] - lineOffset;
        currentLine = MAX(0, MIN(numberOfLines - (NSInteger)[readingBar numberOfLines], currentLine));
        
        if ([page isEqual:readingBarPage] == NO || currentLine != [readingBar currentLine]) {
            [readingBar goToLine:currentLine onPage:page];
            readingBarPage = page;
            lastMouseLoc = mouseLocInDocument;
        }
    }
    
    [NSEvent stopPeriodicEvents];
    
    if (isDoubleClick) {
        if (([lastMouseEvent modifierFlags] & NSShiftKeyMask) != 0)
            [readingBar goToPreviousLine];
        else
            [readingBar goToNextLine];
    }
    
    [self updatePacer];
    
    [NSCursor pop];
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(setCursorForMouse:) withObject:lastMouseEvent afterDelay:0];
}

static inline NSCursor *resizeCursor(NSInteger angle, BOOL single) {
    if (single) {
        switch (angle) {
            case 0:
                return [NSCursor resizeRightCursor];
            case 90:
                return [NSCursor resizeUpCursor];
            case 180:
                return [NSCursor resizeLeftCursor];
            case 270:
            default:
                return [NSCursor resizeDownCursor];
        }
    } else if ((angle % 180)) {
        return [NSCursor resizeUpDownCursor];
    } else {
        return [NSCursor resizeLeftRightCursor];
    }
}

- (void)doResizeReadingBarWithEvent:(NSEvent *)theEvent {
    PDFPage *page = [readingBar page];
    NSInteger firstLine = [readingBar currentLine];
    NSInteger angle = (360 - [page rotation] + [page lineDirectionAngle]) % 360;
    
    [resizeCursor(angle, [readingBar numberOfLines] == 1) push];
    
	while (YES) {
		
        theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
		if ([theEvent type] == NSLeftMouseUp)
            break;
        
        // dragging
        NSPoint point = NSZeroPoint;
        if ([[self pageAndPoint:&point forEvent:theEvent nearest:YES] isEqual:page] == NO)
            continue;
        
        NSInteger numberOfLines = MAX(0, [page indexOfLineRectAtPoint:point lower:YES]) - firstLine + 1;
        
        if (numberOfLines > 0 && numberOfLines != (NSInteger)[readingBar numberOfLines]) {
            [readingBar setNumberOfLines:numberOfLines];
            [resizeCursor(angle, numberOfLines == 1) set];
        }
    }
    
    [NSCursor pop];
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(setCursorForMouse:) withObject:theEvent afterDelay:0];
}


- (NSRect)doSelectRectWithEvent:(NSEvent *)theEvent didDrag:(BOOL *)didDrag {
    NSPoint mouseLoc = [theEvent locationInWindow];
    NSPoint startPoint = [[self documentView] convertPoint:mouseLoc fromView:nil];
    NSPoint currentPoint;
    NSRect selRect = {startPoint, NSZeroSize};
    BOOL dragged = NO;
    NSWindow *window = [self window];
    
    [self makeHighlightLayerForType:SKLayerTypeRect];
    
    while (YES) {
        theEvent = [window nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSFlagsChangedMask];
        
        if ([theEvent type] == NSLeftMouseUp)
            break;
        
        if ([theEvent type] == NSLeftMouseDragged) {
            // change mouseLoc
            [[[self scrollView] contentView] autoscroll:theEvent];
            mouseLoc = [theEvent locationInWindow];
            dragged = YES;
        }
        
        // dragging or flags changed
        
        currentPoint = [[self documentView] convertPoint:mouseLoc fromView:nil];
        
        // center around startPoint when holding down the Shift key
        if (([theEvent modifierFlags] & NSShiftKeyMask))
            selRect = SKRectFromCenterAndPoint(startPoint, currentPoint);
        else
            selRect = SKRectFromPoints(startPoint, currentPoint);
        
        // intersect with the bounds, project on the bounds if necessary and allow zero width or height
        selRect = SKIntersectionRect(selRect, [[self documentView] bounds]);
        
        [highlightLayerController setRect:[self convertRect:selRect fromView:[self documentView]]];
        [[highlightLayerController layer] setNeedsDisplay];
    }
    
    [self removeHighlightLayer];

    [self setCursorForMouse:theEvent];
    
    *didDrag = dragged;
    return selRect;
}

- (void)doSelectSnapshotWithEvent:(NSEvent *)theEvent {
    [[NSCursor cameraCursor] set];
    
    BOOL dragged = NO;
    NSRect selRect = [self doSelectRectWithEvent:theEvent didDrag:&dragged];
    
    NSPoint point = [self convertPoint:SKCenterPoint(selRect) fromView:[self documentView]];
    PDFPage *page = [self pageForPoint:point nearest:YES];
    NSRect rect = [self convertRect:selRect fromView:[self documentView]];
    NSRect bounds;
    NSInteger factor = 1;
    BOOL autoFits = NO;
    
    if (dragged) {
    
        bounds = [self convertRect:[[self documentView] bounds] fromView:[self documentView]];
        
        if (NSWidth(rect) < 40.0 && NSHeight(rect) < 40.0)
            factor = 3;
        else if (NSWidth(rect) < 60.0 && NSHeight(rect) < 60.0)
            factor = 2;
        
        if (factor * NSWidth(rect) < 60.0) {
            rect = NSInsetRect(rect, 0.5 * (NSWidth(rect) - 60.0 / factor), 0.0);
            if (NSMinX(rect) < NSMinX(bounds))
                rect.origin.x = NSMinX(bounds);
            if (NSMaxX(rect) > NSMaxX(bounds))
                rect.origin.x = NSMaxX(bounds) - NSWidth(rect);
        }
        if (factor * NSHeight(rect) < 60.0) {
            rect = NSInsetRect(rect, 0.0, 0.5 * (NSHeight(rect) - 60.0 / factor));
            if (NSMinY(rect) < NSMinY(bounds))
                rect.origin.y = NSMinY(bounds);
            if (NSMaxX(rect) > NSMaxY(bounds))
                rect.origin.y = NSMaxY(bounds) - NSHeight(rect);
        }
        
        autoFits = YES;
        
    } else if (toolMode == SKSelectToolMode && NSIsEmptyRect(selectionRect) == NO) {
        
        rect = NSIntersectionRect(selectionRect, [page boundsForBox:kPDFDisplayBoxCropBox]);
        rect = [self convertRect:rect fromPage:page];
        autoFits = YES;
        
    } else {
        
        PDFAnnotation *annotation = [page annotationAtPoint:[self convertPoint:point toPage:page]];
        if ([annotation isLink]) {
            PDFDestination *destination = [annotation linkDestination];
            if ([destination page]) {
                page = [destination page];
                point = [self convertPoint:[destination point] fromPage:page];
                point.y -= 0.5 * DEFAULT_SNAPSHOT_HEIGHT;
            }
        }
        
        rect = [self convertRect:[page boundsForBox:kPDFDisplayBoxCropBox] fromPage:page];
        rect.origin.y = point.y - 0.5 * DEFAULT_SNAPSHOT_HEIGHT;
        rect.size.height = DEFAULT_SNAPSHOT_HEIGHT;
        
    }
    
    if ([[self delegate] respondsToSelector:@selector(PDFView:showSnapshotAtPageNumber:forRect:scaleFactor:autoFits:)])
        [[self delegate] PDFView:self showSnapshotAtPageNumber:[page pageIndex] forRect:[self convertRect:rect toPage:page] scaleFactor:[self scaleFactor] * factor autoFits:autoFits];
}

- (void)removeLoupeWindow {
    if (loupeController) {
        [loupeController hide];
        SKDESTROY(loupeController);
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewMagnificationChangedNotification object:self];
    }
}

- (void)doMagnifyWithEvent:(NSEvent *)theEvent {
    if (loupeController && [theEvent clickCount] == 1) {
        
        [self removeLoupeWindow];
        
        // ??? PDFView's delayed layout seems to reset the cursor to an arrow
        [self performSelector:@selector(setCursorForMouse:) withObject:theEvent afterDelay:0];
        
        // eat up mouse moved and mouse up events
        [self doDragMouseWithEvent:theEvent];
        
    } else {
        
        NSWindow *window = [self window];
        
        if (window == nil)
            return;
        
        if (loupeController == nil)
            loupeController = [[SKLoupeController alloc] initWithPDFView:self];
        
        NSInteger startLevel = MAX(1, [theEvent clickCount]);
        
        [theEvent retain];
        while ([theEvent type] != NSLeftMouseUp) {
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            
            if ([theEvent type] != NSLeftMouseUp && [theEvent type] != NSLeftMouseDragged) {
                // set up the currentLevel and magnification
                NSUInteger modifierFlags = [theEvent modifierFlags];
                CGFloat newMagnification = (modifierFlags & NSAlternateKeyMask) ? LARGE_MAGNIFICATION : (modifierFlags & NSControlKeyMask) ? SMALL_MAGNIFICATION : DEFAULT_MAGNIFICATION;
                if ((modifierFlags & NSShiftKeyMask))
                    newMagnification = 1.0 / newMagnification;
                if (fabs([loupeController magnification] - newMagnification) > 0.0001) {
                    [loupeController setMagnification:newMagnification];
                    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewMagnificationChangedNotification object:self];
                }
                [loupeController setLevel:(modifierFlags & NSCommandKeyMask) ? startLevel + 1 : startLevel];
            }
            
            [loupeController update];
            
            [pool drain];

            if (theEvent == nil)
                break;
            
            [theEvent release];
            theEvent = [[window nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSFlagsChangedMask] retain];
        }
        [theEvent release];
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:SKMagnifyWithMousePressedKey])
            [self removeLoupeWindow];
    }
}

- (void)doMarqueeZoomWithEvent:(NSEvent *)theEvent {
    [[NSCursor zoomInCursor] set];
    
    BOOL dragged = NO;
    NSRect selRect = [self doSelectRectWithEvent:theEvent didDrag:&dragged];
    
    if (dragged && NSIsEmptyRect(selRect) == NO) {
        
        NSPoint point = [self convertPoint:SKCenterPoint(selRect) fromView:[self documentView]];
        PDFPage *page = [self pageForPoint:point nearest:YES];
        NSRect rect = [self convertRect:[self convertRect:selRect fromView:[self documentView]] toPage:page];
        
        [self zoomToRect:rect onPage:page];
    }
}

- (BOOL)doDragMouseWithEvent:(NSEvent *)theEvent {
    BOOL didDrag = NO;;
    // eat up mouseDragged/mouseUp events, so we won't get their event handlers
    while (YES) {
        if ([[[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask] type] == NSLeftMouseUp)
            break;
        didDrag = YES;
    }
    return didDrag;
}

- (void)doDragWindowWithEvent:(NSEvent *)theEvent {
    NSWindow *window = [self window];
    NSRect frame = [window frame];
    NSPoint offset = SKSubstractPoints(frame.origin, [theEvent locationOnScreen]);
    while (YES) {
        theEvent = [window nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        if ([theEvent type] == NSLeftMouseUp)
             break;
        frame.origin = SKAddPoints([theEvent locationOnScreen], offset);
        [window setFrame:SKConstrainRect(frame, [[window screen] frame]) display:YES];
    }
}

- (void)showHelpMenu {
    NSMenu *menu = nil;
    NSMenuItem *item;
    if (interactionMode == SKPresentationMode) {
        menu = [NSMenu menu];
        item = [menu addItemWithTitle:NSLocalizedString(@"Go To Next Page", @"Menu item title") action:@selector(goToNextPage:) keyEquivalent:@"\uF703"];
        [item setKeyEquivalentModifierMask:0];
        item = [menu addItemWithTitle:NSLocalizedString(@"Go To Previous Page", @"Menu item title") action:@selector(goToPreviousPage:) keyEquivalent:@"\uF702"];
        [item setKeyEquivalentModifierMask:0];
        item = [menu addItemWithTitle:NSLocalizedString(@"Show Overview", @"Menu item title") action:@selector(toggleOverview:) keyEquivalent:@"p"];
        [item setKeyEquivalentModifierMask:0];
        item = [menu addItemWithTitle:NSLocalizedString(@"Show Contents Pane", @"Menu item title") action:@selector(toggleLeftSidePane:) keyEquivalent:@"t"];
        [item setKeyEquivalentModifierMask:0];
        item = [menu addItemWithTitle:[NSString stringWithFormat:@"%@ / %@", NSLocalizedString(@"Actual Size", @"Menu item title"), NSLocalizedString(@"Fit to Screen", @"Menu item title")] action:@selector(toggleAutoActualSize:) keyEquivalent:@"a"];
        [item setKeyEquivalentModifierMask:0];
        item = [menu addItemWithTitle:NSLocalizedString(@"Blackout", @"Menu item title") action:@selector(toggleBlackout:) keyEquivalent:@"b"];
        [item setKeyEquivalentModifierMask:0];
        item = [menu addItemWithTitle:NSLocalizedString(@"Laser Pointer", @"Menu item title") action:@selector(toggleLaserPointer:) keyEquivalent:@"l"];
        [item setKeyEquivalentModifierMask:0];
        item = [menu addItemWithTitle:NSLocalizedString(@"Laser Pointer Color", @"Menu item title") action:@selector(nextLaserPointerColor:) keyEquivalent:@"c"];
        [item setKeyEquivalentModifierMask:0];
        item = [menu addItemWithTitle:NSLocalizedString(@"End", @"Menu item title") action:@selector(cancelOperation:) keyEquivalent:@"\e"];
        [item setKeyEquivalentModifierMask:0];
        [[NSCursor arrowCursor] set];
    } else {
        menu = [NSMenu menu];
        item = [menu addItemWithTitle:NSLocalizedString(@"Move Current Note", @"Menu item title") action:@selector(moveCurrentAnnotation:) keyEquivalent:@"\uF703"];
        [item setKeyEquivalentModifierMask:0];
        item = [menu addItemWithTitle:NSLocalizedString(@"Move Current Note", @"Menu item title") action:@selector(moveCurrentAnnotation:) keyEquivalent:@"\uF703"];
        [item setKeyEquivalentModifierMask:NSShiftKeyMask];
        [item setTag:1];
        item = [menu addItemWithTitle:NSLocalizedString(@"Resize Current Note", @"Menu item title") action:@selector(resizeCurrentAnnotation:) keyEquivalent:@"\uF703"];
        [item setKeyEquivalentModifierMask:NSAlternateKeyMask | NSControlKeyMask];
        item = [menu addItemWithTitle:NSLocalizedString(@"Resize Current Note", @"Menu item title") action:@selector(resizeCurrentAnnotation:) keyEquivalent:@"\uF703"];
        [item setKeyEquivalentModifierMask:NSShiftKeyMask | NSControlKeyMask];
        [item setTag:1];
        item = [menu addItemWithTitle:NSLocalizedString(@"Auto Size Current Note", @"Menu item title") action:@selector(autoSizeCurrentAnnotation:) keyEquivalent:@"="];
        [item setKeyEquivalentModifierMask:NSControlKeyMask];
        item = [menu addItemWithTitle:NSLocalizedString(@"Auto Size Current Note", @"Menu item title") action:@selector(autoSizeCurrentAnnotation:) keyEquivalent:@"="];
        [item setKeyEquivalentModifierMask:NSControlKeyMask | NSAlternateKeyMask];
        [item setTag:1];
        item = [menu addItemWithTitle:NSLocalizedString(@"Edit Current Note", @"Menu item title") action:@selector(editCurrentAnnotation:) keyEquivalent:@"\r"];
        [item setKeyEquivalentModifierMask:0];
        item = [menu addItemWithTitle:NSLocalizedString(@"Select Next Note", @"Menu item title") action:@selector(selectNextCurrentAnnotation:) keyEquivalent:@"\t"];
        [item setKeyEquivalentModifierMask:NSAlternateKeyMask];
        item = [menu addItemWithTitle:NSLocalizedString(@"Select Previous Note", @"Menu item title") action:@selector(selectPreviousCurrentAnnotation:) keyEquivalent:@"\t"];
        [item setKeyEquivalentModifierMask:NSShiftKeyMask | NSAlternateKeyMask];
        [menu addItem:[NSMenuItem separatorItem]];
        item = [menu addItemWithTitle:NSLocalizedString(@"Move Reading Bar", @"Menu item title") action:@selector(moveReadingBar:) keyEquivalent:@"\uF701"];
        [item setKeyEquivalentModifierMask:moveReadingBarModifiers];
        item = [menu addItemWithTitle:NSLocalizedString(@"Resize Reading Bar", @"Menu item title") action:@selector(resizeReadingBar:) keyEquivalent:@"\uF701"];
        [item setKeyEquivalentModifierMask:resizeReadingBarModifiers];
        [menu addItem:[NSMenuItem separatorItem]];
        item = [menu addItemWithTitle:NSLocalizedString(@"Tool Mode", @"Menu item title") action:@selector(nextToolMode:) keyEquivalent:@"\uF703"];
        [item setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
        item = [menu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"t"];
        [item setKeyEquivalentModifierMask:0];
        [item setTag:SKFreeTextNote];
        item = [menu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"n"];
        [item setKeyEquivalentModifierMask:0];
        [item setTag:SKAnchoredNote];
        item = [menu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"c"];
        [item setKeyEquivalentModifierMask:0];
        [item setTag:SKCircleNote];
        item = [menu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"b"];
        [item setKeyEquivalentModifierMask:0];
        [item setTag:SKSquareNote];
        item = [menu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"h"];
        [item setKeyEquivalentModifierMask:0];
        [item setTag:SKHighlightNote];
        item = [menu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"u"];
        [item setKeyEquivalentModifierMask:0];
        [item setTag:SKUnderlineNote];
        item = [menu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"s"];
        [item setKeyEquivalentModifierMask:0];
        [item setTag:SKStrikeOutNote];
        item = [menu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"l"];
        [item setKeyEquivalentModifierMask:0];
        [item setTag:SKLineNote];
        item = [menu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") action:@selector(changeOnlyAnnotationMode:) keyEquivalent:@"f"];
        [item setKeyEquivalentModifierMask:0];
        [item setTag:SKInkNote];
    }
    NSPoint point = SKTopLeftPoint(SKRectFromCenterAndSize(SKCenterPoint([self bounds]), [menu size]));
    [menu popUpMenuPositioningItem:nil atLocation:point inView:self];
}

- (NSCursor *)cursorForNoteType:(SKNoteType)noteType {
    if (useToolModeCursors) {
        switch (noteType) {
            case SKFreeTextNote:  return [NSCursor textNoteCursor];
            case SKAnchoredNote:  return [NSCursor anchoredNoteCursor];
            case SKCircleNote:    return [NSCursor circleNoteCursor];
            case SKSquareNote:    return [NSCursor squareNoteCursor];
            case SKHighlightNote: return [NSCursor highlightNoteCursor];
            case SKUnderlineNote: return [NSCursor underlineNoteCursor];
            case SKStrikeOutNote: return [NSCursor strikeOutNoteCursor];
            case SKLineNote:      return [NSCursor lineNoteCursor];
            case SKInkNote:       return [NSCursor inkNoteCursor];
            default:              return [NSCursor arrowCursor];
        }
    }
    return [NSCursor arrowCursor];
}

- (NSCursor *)cursorForTemporaryToolMode {
    switch (temporaryToolMode) {
        case SKNoToolMode:       return [NSCursor arrowCursor];
        case SKZoomToolMode:     return [NSCursor zoomInCursor];
        case SKSnapshotToolMode: return [NSCursor cameraCursor];
        default:                 return [self cursorForNoteType:(SKNoteType)temporaryToolMode];
    }
    return [NSCursor arrowCursor];
}

- (PDFAreaOfInterest)areaOfInterestForMouse:(NSEvent *)theEvent {
    PDFAreaOfInterest area = [super areaOfInterestForMouse:theEvent];
    NSPoint p = [theEvent locationInWindow];
    NSInteger modifiers = [theEvent standardModifierFlags];
    
    if ([[self document] isLocked]) {
    } else if (NSPointInRect(p, [self convertRect:[self visibleContentRect] toView:nil]) == NO || ([navWindow isVisible] && NSPointInRect([theEvent locationOnScreen], [navWindow frame]))) {
        area = kPDFNoArea;
    } else if (interactionMode == SKPresentationMode) {
        area &= (kPDFPageArea | kPDFLinkArea);
    } else if ((modifiers == NSCommandKeyMask || modifiers == (NSCommandKeyMask | NSShiftKeyMask) || modifiers == (NSCommandKeyMask | NSAlternateKeyMask))) {
        area = (area & kPDFPageArea) | SKSpecialToolArea;
    } else if ((modifiers & NSCommandKeyMask) == 0 && temporaryToolMode != SKNoToolMode) {
        area = (area & kPDFPageArea) | SKTemporaryToolArea;
    } else {

        SKRectEdges resizeHandle = SKNoEdgeMask;
        PDFPage *page = [self pageAndPoint:&p forEvent:theEvent nearest:YES];
        
        if (readingBar && [[readingBar page] isEqual:page]) {
            NSRect bounds = [readingBar currentBounds];
            NSInteger lineAngle = [page lineDirectionAngle];
            if ((lineAngle % 180)) {
                if (p.y >= NSMinY(bounds) && p.y <= NSMaxY(bounds)) {
                    area |= SKReadingBarArea;
                    if ((lineAngle == 270 && p.y < NSMinY(bounds) + READINGBAR_RESIZE_EDGE_HEIGHT) || (lineAngle == 90 && p.y > NSMaxY(bounds) - READINGBAR_RESIZE_EDGE_HEIGHT)) {
                        if ([readingBar numberOfLines] == 1)
                            area |= SKResizeRightArea << (((360 - [page rotation] + lineAngle) % 360) / 90);
                        else
                            area |= ([page rotation] % 180) ? SKResizeLeftRightArea : SKResizeUpDownArea;
                    }
                }
            } else {
                if (p.x >= NSMinX(bounds) && p.x <= NSMaxX(bounds)) {
                    area |= SKReadingBarArea;
                    if ((lineAngle == 0 && p.x > NSMaxX(bounds) - READINGBAR_RESIZE_EDGE_HEIGHT) || (lineAngle == 180 && p.x < NSMinX(bounds) + READINGBAR_RESIZE_EDGE_HEIGHT)) {
                        if ([readingBar numberOfLines] == 1)
                            area |= SKResizeRightArea << (((360 - [page rotation] + lineAngle) % 360) / 90);
                        else
                            area |= ([page rotation] % 180) ? SKResizeUpDownArea : SKResizeLeftRightArea;
                    }
                }
            }
        }
        
        if ((area & kPDFPageArea) == 0 || toolMode == SKMoveToolMode) {
            if ((area & SKReadingBarArea) == 0)
                area |= SKDragArea;
        } else if (toolMode == SKTextToolMode || toolMode == SKNoteToolMode) {
            if (toolMode == SKNoteToolMode)
                area &= ~kPDFLinkArea;
            if (editor && [[currentAnnotation page] isEqual:page] && NSPointInRect(p, [currentAnnotation bounds])) {
                area = kPDFTextFieldArea;
            } else if ((area & SKReadingBarArea) == 0) {
                if ([[currentAnnotation page] isEqual:page] && [currentAnnotation isMovable] &&
                    ((resizeHandle = [currentAnnotation resizeHandleForPoint:p scaleFactor:[self scaleFactor]]) || [currentAnnotation hitTest:p]))
                    area |= SKAreaOfInterestForResizeHandle(resizeHandle, page);
                else if ((toolMode == SKTextToolMode || pdfvFlags.hideNotes || IS_MARKUP(annotationMode)) && area == kPDFPageArea && modifiers == 0 &&
                         [[page selectionForRect:SKRectFromCenterAndSize(p, TEXT_SELECT_MARGIN_SIZE)] hasCharacters] == NO)
                    area |= SKDragArea;
            }
        } else {
            area = kPDFPageArea;
            if (toolMode == SKSelectToolMode && NSIsEmptyRect(selectionRect) == NO &&
                ((resizeHandle = SKResizeHandleForPointFromRect(p, selectionRect, HANDLE_SIZE / [self scaleFactor])) || NSPointInRect(p, selectionRect)))
                area |= SKAreaOfInterestForResizeHandle(resizeHandle, page);
        }
    }
    
    return area;
}

- (void)setCursorForAreaOfInterest:(PDFAreaOfInterest)area {
    if ((area & kPDFLinkArea))
        [[NSCursor pointingHandCursor] set];
    else if (interactionMode == SKPresentationMode)
        [pdfvFlags.cursorHidden ? [NSCursor emptyCursor] : pdfvFlags.useArrowCursorInPresentation ? [NSCursor arrowCursor] : [NSCursor laserPointerCursorWithColor:laserPointerColor] set];
    else if ((area & SKSpecialToolArea))
        [[NSCursor arrowCursor] set];
    else if ((area & SKTemporaryToolArea))
        [[self cursorForTemporaryToolMode] set];
    else if ((area & SKDragArea))
        [[NSCursor openHandCursor] set];
    else if ((area & SKResizeUpDownArea))
        [[NSCursor resizeUpDownCursor] set];
    else if ((area & SKResizeLeftRightArea))
        [[NSCursor resizeLeftRightCursor] set];
    else if ((area & SKResizeDiagonal45Area))
        [[NSCursor resizeDiagonal45Cursor] set];
    else if ((area & SKResizeDiagonal135Area))
        [[NSCursor resizeDiagonal135Cursor] set];
    else if ((area & SKResizeRightArea))
        [[NSCursor resizeRightCursor] set];
    else if ((area & SKResizeUpArea))
        [[NSCursor resizeUpCursor] set];
    else if ((area & SKResizeLeftArea))
        [[NSCursor resizeLeftCursor] set];
    else if ((area & SKResizeDownArea))
        [[NSCursor resizeDownCursor] set];
    else if ((area & SKReadingBarArea))
        [[NSCursor openHandBarCursor] set];
    else if (area == kPDFTextFieldArea)
        [[NSCursor IBeamCursor] set];
    else if (toolMode == SKNoteToolMode && (area & kPDFPageArea))
        [[self cursorForNoteType:annotationMode] set];
    else if (toolMode == SKSelectToolMode && (area & kPDFPageArea))
        [[NSCursor crosshairCursor] set];
    else if (toolMode == SKMagnifyToolMode && (area & kPDFPageArea))
        [(([NSEvent standardModifierFlags] & NSShiftKeyMask) ? [NSCursor zoomOutCursor] : [NSCursor zoomInCursor]) set];
    else
        [super setCursorForAreaOfInterest:area & ~kPDFIconArea];
}

- (void)setCursorForMouse:(NSEvent *)theEvent {
    if (theEvent == nil)
        theEvent = [NSEvent mouseEventWithType:NSMouseMoved
                                      location:[[self window] mouseLocationOutsideOfEventStream]
                                 modifierFlags:[NSEvent standardModifierFlags]
                                     timestamp:0
                                  windowNumber:[[self window] windowNumber]
                                       context:nil
                                   eventNumber:0
                                    clickCount:1
                                      pressure:0.0];
    [self setCursorForAreaOfInterest:[self areaOfInterestForMouse:theEvent]];
}

- (id <SKPDFViewDelegate>)delegate {
    return (id <SKPDFViewDelegate>)[super delegate];
}

- (void)setDelegate:(id <SKPDFViewDelegate>)newDelegate {
    if ([self delegate] && newDelegate == nil)
        [self cleanup];
    [super setDelegate:newDelegate];
    if ([self delegate]) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        NSUndoManager *undoManager = [self undoManager];
        [nc addObserver:self selector:@selector(handleUndoGroupOpenedOrClosedNotification:)
                                                     name:NSUndoManagerDidOpenUndoGroupNotification object:undoManager];
        [nc addObserver:self selector:@selector(handleUndoGroupOpenedOrClosedNotification:)
                                                     name:NSUndoManagerDidCloseUndoGroupNotification object:undoManager];
    }
}

- (NSString *)currentColorDefaultKeyForAlternate:(BOOL)isAlt {
    if ([self toolMode] != SKNoteToolMode)
        return nil;
    switch ([self annotationMode]) {
        case SKFreeTextNote:  return isAlt ? SKFreeTextNoteFontColorKey : SKFreeTextNoteColorKey;
        case SKAnchoredNote:  return SKAnchoredNoteColorKey;
        case SKCircleNote:    return isAlt ? SKCircleNoteInteriorColorKey : SKCircleNoteColorKey;
        case SKSquareNote:    return isAlt ? SKSquareNoteInteriorColorKey : SKSquareNoteColorKey;
        case SKHighlightNote: return SKHighlightNoteColorKey;
        case SKUnderlineNote: return SKUnderlineNoteColorKey;
        case SKStrikeOutNote: return SKStrikeOutNoteColorKey;
        case SKLineNote:      return isAlt ? SKLineNoteInteriorColorKey : SKLineNoteColorKey;
        case SKInkNote:       return SKInkNoteColorKey;
        default: return nil;
    }
}

- (BOOL)accessibilityPerformShowAlternateUI {
    if (interactionMode == SKPresentationMode) {
        if ([navWindow isVisible] == NO) {
            [navWindow showForWindow:[self window]];
            NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor([self documentView]), NSAccessibilityLayoutChangedNotification, [NSDictionary dictionaryWithObjectsAndKeys:NSAccessibilityUnignoredChildrenForOnlyChild(navWindow), NSAccessibilityUIElementsKey, nil]);
        }
    } else if ([[self delegate] respondsToSelector:@selector(PDFViewPerformFind:)]) {
        [[self delegate] PDFViewPerformFind:self];
        return YES;
    }
    return NO;
}

- (BOOL)accessibilityPerformShowDefaultUI {
    if (interactionMode == SKPresentationMode) {
        if ([navWindow isVisible]) {
            [navWindow fadeOut];
            NSAccessibilityPostNotificationWithUserInfo(NSAccessibilityUnignoredAncestor([self documentView]), NSAccessibilityLayoutChangedNotification, nil);
        }
    } else if ([[self delegate] respondsToSelector:@selector(PDFViewPerformHideFind:)]) {
        [[self delegate] PDFViewPerformHideFind:self];
        return YES;
    }
    return NO;
}

- (BOOL)isAccessibilityAlternateUIVisible{
    if (interactionMode == SKPresentationMode) {
        return [navWindow isVisible];
    } else {
        return [[self delegate] respondsToSelector:@selector(PDFViewIsFindVisible:)] && [[self delegate] PDFViewIsFindVisible:self];
    }
}

@end

static inline PDFAreaOfInterest SKAreaOfInterestForResizeHandle(SKRectEdges mask, PDFPage *page) {
    BOOL rotated = ([page rotation] % 180 != 0);
    if (mask == 0)
        return SKDragArea;
    else if (mask == SKMaxXEdgeMask || mask == SKMinXEdgeMask)
        return rotated ? SKResizeUpDownArea : SKResizeLeftRightArea;
    else if (mask == (SKMaxXEdgeMask | SKMaxYEdgeMask) || mask == (SKMinXEdgeMask | SKMinYEdgeMask))
        return rotated ? SKResizeDiagonal135Area : SKResizeDiagonal45Area;
    else if (mask == SKMaxYEdgeMask || mask == SKMinYEdgeMask)
        return rotated ? SKResizeLeftRightArea : SKResizeUpDownArea;
    else if (mask == (SKMaxXEdgeMask | SKMinYEdgeMask) || mask == (SKMinXEdgeMask | SKMaxYEdgeMask))
        return rotated ? SKResizeDiagonal45Area : SKResizeDiagonal135Area;
    else
        return kPDFNoArea;
}

static inline NSSize SKFitTextNoteSize(NSString *string, NSFont *font, CGFloat width) {
    NSMutableParagraphStyle *parStyle = [[NSMutableParagraphStyle alloc] init];
    CGFloat descent = -[font descender];
    CGFloat lineHeight = ceil([font ascender]) + ceil(descent);
    [parStyle setLineBreakMode:NSLineBreakByWordWrapping];
    [parStyle setLineSpacing:-[font leading]];
    [parStyle setMinimumLineHeight:lineHeight];
    [parStyle setMaximumLineHeight:lineHeight];
    NSDictionary *attrs = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, parStyle, NSParagraphStyleAttributeName, nil];
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:string attributes:attrs];
    NSSize size = [attrString boundingRectWithSize:NSMakeSize(width - 4.0, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin].size;
    [attrs release];
    [attrString release];
    size.width = ceil(size.width + 4.0);
    size.height = ceil(size.height + (RUNNING_AFTER(10_13) ? 6.0 : 2.0));
    return size;
}

#pragma mark -

@implementation SKLayerController

@synthesize layer, delegate, rect, type;

- (void)dealloc {
    delegate = nil;
    SKDESTROY(layer);
    [super dealloc];
}

- (void)drawLayer:(CALayer *)aLayer inContext:(CGContextRef)context {
    [delegate drawLayerController:self inContext:context];
}

@end

