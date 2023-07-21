//
//  SKMainWindowController.m
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

#import "SKMainWindowController.h"
#import "SKMainToolbarController.h"
#import "SKMainWindowController_UI.h"
#import "SKMainWindowController_FullScreen.h"
#import "SKMainWindowController_Actions.h"
#import "SKLeftSideViewController.h"
#import "SKRightSideViewController.h"
#import <Quartz/Quartz.h>
#import "SKStringConstants.h"
#import "SKNoteWindowController.h"
#import "SKInfoWindowController.h"
#import "SKBookmarkController.h"
#import "SKSideWindow.h"
#import "PDFPage_SKExtensions.h"
#import "SKMainDocument.h"
#import "SKThumbnail.h"
#import "SKPDFView.h"
#import <SkimNotes/SkimNotes.h>
#import "PDFAnnotation_SKExtensions.h"
#import "SKNoteText.h"
#import "SKSplitView.h"
#import "NSBezierPath_SKExtensions.h"
#import "NSUserDefaultsController_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "SKOutlineView.h"
#import "SKNoteOutlineView.h"
#import "SKTableView.h"
#import "SKNoteTypeSheetController.h"
#import "NSWindowController_SKExtensions.h"
#import "SKImageToolTipWindow.h"
#import "PDFSelection_SKExtensions.h"
#import "SKToolbarItem.h"
#import "NSValue_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "SKReadingBar.h"
#import "SKLineInspector.h"
#import "SKStatusBar.h"
#import "SKTransitionController.h"
#import "SKTransitionInfo.h"
#import "SKPresentationOptionsSheetController.h"
#import "SKTypeSelectHelper.h"
#import "NSGeometry_SKExtensions.h"
#import "SKProgressController.h"
#import "SKSecondaryPDFView.h"
#import "SKColorSwatch.h"
#import "SKApplicationController.h"
#import "NSSegmentedControl_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "SKGroupedSearchResult.h"
#import "HIDRemote.h"
#import "NSView_SKExtensions.h"
#import "NSResponder_SKExtensions.h"
#import "PDFOutline_SKExtensions.h"
#import "NSPointerArray_SKExtensions.h"
#import "SKColorCell.h"
#import "PDFDocument_SKExtensions.h"
#import "SKPDFPage.h"
#import "NSScreen_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "NSScanner_SKExtensions.h"
#import "SKScroller.h"
#import "SKMainWindow.h"
#import "PDFOutline_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSWindow_SKExtensions.h"
#import "SKMainTouchBarController.h"
#import "SKOverviewView.h"
#import "SKThumbnailItem.h"
#import "SKThumbnailView.h"
#import "SKDocumentController.h"
#import "NSColor_SKExtensions.h"
#import "NSObject_SKExtensions.h"

#define MULTIPLICATION_SIGN_CHARACTER (unichar)0x00d7

#define TINY_SIZE  32.0
#define SMALL_SIZE 64.0
#define LARGE_SIZE 128.0
#define HUGE_SIZE  256.0
#define FUDGE_SIZE 0.1

#define MAX_PAGE_COLUMN_WIDTH 100.0
#define MAX_MIN_COLUMN_WIDTH 100.0

#define PAGELABELS_KEY              @"pageLabels"
#define SEARCHRESULTS_KEY           @"searchResults"
#define GROUPEDSEARCHRESULTS_KEY    @"groupedSearchResults"
#define NOTES_KEY                   @"notes"
#define SNAPSHOTS_KEY               @"snapshots"

#define PAGE_COLUMNID   @"page"
#define COLOR_COLUMNID  @"color"
#define AUTHOR_COLUMNID @"author"
#define DATE_COLUMNID   @"date"

#define LABEL_COLUMNID  @"label"

#define RELEVANCE_COLUMNID  @"relevance"
#define RESULTS_COLUMNID    @"results"

#define PAGELABEL_KEY   @"pageLabel"

#define MAINWINDOWFRAME_KEY         @"windowFrame"
#define LEFTSIDEPANEWIDTH_KEY       @"leftSidePaneWidth"
#define RIGHTSIDEPANEWIDTH_KEY      @"rightSidePaneWidth"
#define SCALEFACTOR_KEY             @"scaleFactor"
#define AUTOSCALES_KEY              @"autoScales"
#define DISPLAYSPAGEBREAKS_KEY      @"displaysPageBreaks"
#define DISPLAYSASBOOK_KEY          @"displaysAsBook" 
#define DISPLAYMODE_KEY             @"displayMode"
#define DISPLAYDIRECTION_KEY        @"displayDirection"
#define DISPLAYSRTL_KEY             @"displaysRTL"
#define DISPLAYBOX_KEY              @"displayBox"
#define HASHORIZONTALSCROLLER_KEY   @"hasHorizontalScroller"
#define HASVERTICALSCROLLER_KEY     @"hasVerticalScroller"
#define AUTOHIDESSCROLLERS_KEY      @"autoHidesScrollers"
#define DRAWSBACKGROUND_KEY         @"drawsBackground"
#define PAGEINDEX_KEY               @"pageIndex"
#define SCROLLPOINT_KEY             @"scrollPoint"
#define LOCKED_KEY                  @"locked"
#define CROPBOXES_KEY               @"cropBpxes"

#define PAGETRANSITIONS_KEY @"pageTransitions"

#define WINDOW_KEY @"window"

#define SKMainWindowFrameAutosaveName @"SKMainWindow"

static char SKPDFAnnotationPropertiesObservationContext;

static char SKMainWindowDefaultsObservationContext;

static char SKMainWindowAppObservationContext;

static char SKMainWindowThumbnailSelectionObservationContext;

static char SKMainWindowContentLayoutObservationContext;

#define SKLeftSidePaneWidthKey @"SKLeftSidePaneWidth"
#define SKRightSidePaneWidthKey @"SKRightSidePaneWidth"

#define SKCollapseTOCSublevelsKey @"SKCollapseTOCSublevels"

#define SKDisableSearchBarBlurringKey @"SKDisableSearchBarBlurring"

#if SDK_BEFORE(10_11)
@interface NSCollectionView (SKElCapitanExtensions)
- (BOOL)allowsEmptySelection;
- (void)setAllowsEmptySelection:(BOOL)flag;
@end
#endif

#pragma mark -

@interface SKMainWindowController (SKPrivate)

- (void)cleanup;

- (void)applyLeftSideWidth:(CGFloat)leftSideWidth rightSideWidth:(CGFloat)rightSideWidth;

- (void)setupToolbar;

- (void)updateTableFont;

- (void)updatePageLabel;

- (SKProgressController *)progressController;

- (void)updateFindResultHighlightsForDirection:(NSSelectionDirection)direction;

- (void)registerForDocumentNotifications;
- (void)unregisterForDocumentNotifications;

- (void)registerAsObserver;
- (void)unregisterAsObserver;

- (void)startObservingNotes:(NSArray *)newNotes;
- (void)stopObservingNotes:(NSArray *)oldNotes;

- (void)observeUndoManagerCheckpoint:(NSNotification *)notification;

- (void)clearWidgets;

+ (void)defineFullScreenGlobalVariables;

@end


@implementation SKMainWindowController

@synthesize mainWindow, splitView, centerContentView, pdfSplitView, pdfContentView, statusBar, pdfView, secondaryPdfView, leftSideController, rightSideController, toolbarController, leftSideContentView, rightSideContentView, presentationNotesDocument, presentationNotesOffset, tags, rating, pageLabel, interactionMode, placeholderPdfDocument;
@dynamic pdfDocument, presentationOptions, selectedNotes, hasNotes, widgetProperties, autoScales, leftSidePaneState, rightSidePaneState, findPaneState, leftSidePaneIsOpen, rightSidePaneIsOpen, recentInfoNeedsUpdate, searchString, hasOverview, notesMenu;

+ (void)initialize {
    SKINITIALIZE;
    [self defineFullScreenGlobalVariables];
}

+ (BOOL)automaticallyNotifiesObserversOfPageLabel { return NO; }

- (id)init {
    self = [super initWithWindowNibName:@"MainWindow"];
    if (self) {
        NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
        interactionMode = SKNormalMode;
        searchResults = [[NSMutableArray alloc] init];
        searchResultIndex = 0;
        memset(&mwcFlags, 0, sizeof(mwcFlags));
        mwcFlags.fullSizeContent = NO == [sud boolForKey:SKDisableSearchBarBlurringKey];
        mwcFlags.caseInsensitiveSearch = [sud boolForKey:SKCaseInsensitiveSearchKey];
        mwcFlags.wholeWordSearch = [sud boolForKey:SKWholeWordSearchKey];
        mwcFlags.caseInsensitiveFilter = [sud boolForKey:SKCaseInsensitiveFilterKey];
        groupedSearchResults = [[NSMutableArray alloc] init];
        thumbnails = [[NSMutableArray alloc] init];
        notes = [[NSMutableArray alloc] init];
        tags = [[NSArray alloc] init];
        rating = 0.0;
        snapshots = [[NSMutableArray alloc] init];
        dirtySnapshots = [[NSMutableArray alloc] init];
        pageLabels = [[NSMutableArray alloc] init];
        lastViewedPages = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality];
        rowHeights = NSCreateMapTable(NSObjectMapKeyCallBacks, NSIntegerMapValueCallBacks, 0);
        savedNormalSetup = [[NSMutableDictionary alloc] init];
        mwcFlags.leftSidePaneState = SKSidePaneStateThumbnail;
        mwcFlags.rightSidePaneState = SKSidePaneStateNote;
        mwcFlags.findPaneState = SKFindPaneStateSingular;
        pageLabel = nil;
        markedPageIndex = NSNotFound;
        markedPagePoint = NSZeroPoint;
        beforeMarkedPageIndex = NSNotFound;
        beforeMarkedPagePoint = NSZeroPoint;
        activity = nil;
        presentationNotesDocument = nil;
        presentationNotesOffset = 0;
    }
    return self;
}

- (void)dealloc {
    if ([self isWindowLoaded] && [[self window] delegate])
        SKENSURE_MAIN_THREAD( [self cleanup]; );
    SKDESTROY(placeholderPdfDocument);
    SKDESTROY(placeholderWidgetProperties);
    SKDESTROY(undoGroupOldPropertiesPerNote);
    SKDESTROY(dirtySnapshots);
	SKDESTROY(searchResults);
	SKDESTROY(groupedSearchResults);
	SKDESTROY(thumbnails);
    SKDESTROY(notes);
    SKDESTROY(widgets);
    SKDESTROY(widgetValues);
	SKDESTROY(snapshots);
	SKDESTROY(tags);
    SKDESTROY(pageLabels);
    SKDESTROY(pageLabel);
	SKDESTROY(rowHeights);
    SKDESTROY(lastViewedPages);
	SKDESTROY(sideWindow);
    SKDESTROY(mainWindow);
    SKDESTROY(statusBar);
    SKDESTROY(findController);
    SKDESTROY(savedNormalSetup);
    SKDESTROY(progressController);
    SKDESTROY(colorAccessoryView);
    SKDESTROY(textColorAccessoryView);
    SKDESTROY(secondaryPdfView);
    SKDESTROY(presentationPreview);
    SKDESTROY(noteTypeSheetController);
    SKDESTROY(splitView);
    SKDESTROY(centerContentView);
    SKDESTROY(pdfSplitView);
    SKDESTROY(pdfContentView);
    SKDESTROY(pdfView);
    SKDESTROY(leftSideController);
    SKDESTROY(rightSideController);
    SKDESTROY(toolbarController);
    SKDESTROY(leftSideContentView);
    SKDESTROY(rightSideContentView);
    SKDESTROY(overviewView);
    SKDESTROY(overviewContentView);
    SKDESTROY(fieldEditor);
    SKDESTROY(presentationNotesDocument);
    [super dealloc];
}

// this is called from windowWillClose:
- (void)cleanup {
    if (activity) {
        [[NSProcessInfo processInfo] endActivity:activity];
        SKDESTROY(activity);
    }
    [overviewView removeObserver:self forKeyPath:RUNNING_BEFORE(10_11) ? @"selectionIndexes" : @"selectionIndexPaths" context:&SKMainWindowThumbnailSelectionObservationContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopObservingNotes:[self notes]];
    [self clearWidgets];
    [self unregisterAsObserver];
    [[self window] setDelegate:nil];
    [splitView setDelegate:nil];
    [pdfSplitView setDelegate:nil];
    [leftSideController setMainController:nil];
    [rightSideController setMainController:nil];
    [toolbarController setMainController:nil];
    [touchBarController setMainController:nil];
    [findController setDelegate:nil]; // this breaks the retain loop from binding
    [pdfView setDelegate:nil]; // this cleans up the pdfview
    [[pdfView document] setDelegate:nil];
    [noteTypeSheetController setDelegate:nil];
    // Sierra seems to have a retain cycle when the document has an outlineRoot
    [[[pdfView document] outlineRoot] clearDocument];
    [[pdfView document] setContainingDocument:nil];
    // Yosemite and El Capitan have a retain cycle when we leave the PDFView with a document
    if (RUNNING_BEFORE(10_12)) {
        [pdfView setDocument:nil];
        [secondaryPdfView setDocument:nil];
    }
    // we may retain our own document here
    [self setPresentationNotesDocument:nil];
}

- (void)windowDidLoad{
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    BOOL hasWindowSetup = [savedNormalSetup count] > 0;
    NSWindow *window = [self window];
    
    mwcFlags.settingUpWindow = 1;
    
    // Set up the panes and subviews, needs to be done before we resize them
    
    // make sure the first thing we call on the side view controllers is its view so their nib is loaded
    [leftSideContentView addSubview:leftSideController.view];
    [leftSideController.view activateConstraintsToSuperview];
    [rightSideContentView addSubview:rightSideController.view];
    [rightSideController.view activateConstraintsToSuperview];
    
    [leftSideContentView setAccessibilityLabel:NSLocalizedString(@"contents pane", @"Accessibility description")];
    [rightSideContentView setAccessibilityLabel:NSLocalizedString(@"notes pane", @"Accessibility description")];
    
    if (mwcFlags.fullSizeContent) {
        [leftSideController setCurrentView:[[leftSideController currentView] superview]];
        [rightSideController setCurrentView:[[rightSideController currentView] superview]];
    }
    
    [self updateTableFont];
    
    [self displayThumbnailViewAnimating:NO];
    [self displayNoteViewAnimating:NO];
    
    // we need to create the PDFView before setting the toolbar
    pdfView = [[SKPDFView alloc] initWithFrame:[pdfContentView bounds]];
    [pdfView setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    if ([pdfView maximumScaleFactor] < 20.0 && [pdfView respondsToSelector:NSSelectorFromString(@"setMaxScaleFactor:")])
        [pdfView setValue:[NSNumber numberWithDouble:20.0] forKey:@"maxScaleFactor"];
    
    // Set up the tool bar
    [toolbarController setupToolbar];
    
    // Set up the window
    [window setCollectionBehavior:[window collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];
    
    if ([window respondsToSelector:@selector(setToolbarStyle:)])
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        [window setToolbarStyle:NSWindowToolbarStyleExpanded];
#pragma clang diagnostic pop
    
    [window setStyleMask:[window styleMask] | NSWindowStyleMaskFullSizeContentView];
    if (mwcFlags.fullSizeContent) {
        titleBarHeight = NSHeight([window frame]) - NSHeight([window contentLayoutRect]);
        [leftSideController setTopInset:titleBarHeight];
        [rightSideController setTopInset:titleBarHeight];
    } else {
        NSLayoutConstraint *constraint = [[window contentView] constraintWithFirstItem:splitView firstAttribute:NSLayoutAttributeTop];
        if (constraint) {
            [constraint setActive:NO];
            [[NSLayoutConstraint constraintWithItem:splitView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:[window contentLayoutGuide] attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0] setActive:YES];
        }
    }
    
    [self setWindowFrameAutosaveNameOrCascade:SKMainWindowFrameAutosaveName];
    
    [window setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    
    [[statusBar rightField] setAction:@selector(statusBarClicked:)];
    [[statusBar rightField] setTarget:self];

    if ([sud boolForKey:SKShowStatusBarKey] == NO)
        [self toggleStatusBar:nil];
    else
        [window setContentBorderThickness:22.0 forEdge:NSMinYEdge];
    
    NSInteger windowSizeOption = [sud integerForKey:SKInitialWindowSizeOptionKey];
    if (hasWindowSetup) {
        NSString *rectString = [savedNormalSetup objectForKey:MAINWINDOWFRAME_KEY];
        if (rectString)
            [window setFrame:NSRectFromString(rectString) display:NO];
    } else if (windowSizeOption == SKWindowOptionMaximize) {
        [window setFrame:[[NSScreen mainScreen] visibleFrame] display:NO];
    }
    
    // Set up the PDF
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [pdfView setShouldAntiAlias:[sud boolForKey:SKShouldAntiAliasKey]];
    if (RUNNING_BEFORE(10_14))
        [pdfView setGreekingThreshold:[sud floatForKey:SKGreekingThresholdKey]];
#pragma clang diagnostic pop
    [pdfView setInterpolationQuality:[sud integerForKey:SKInterpolationQualityKey]];
    [pdfView setBackgroundColor:[PDFView defaultBackgroundColor]];
    
    [self applyPDFSettings:hasWindowSetup ? savedNormalSetup : [sud dictionaryForKey:SKDefaultPDFDisplaySettingsKey] rewind:NO];
    
    [pdfView setDelegate:self];
    
    NSNumber *leftWidthNumber = [savedNormalSetup objectForKey:LEFTSIDEPANEWIDTH_KEY] ?: [sud objectForKey:SKLeftSidePaneWidthKey];
    NSNumber *rightWidthNumber = [savedNormalSetup objectForKey:RIGHTSIDEPANEWIDTH_KEY] ?: [sud objectForKey:SKRightSidePaneWidthKey];
    
    if (leftWidthNumber && rightWidthNumber)
        [self applyLeftSideWidth:[leftWidthNumber doubleValue] rightSideWidth:[rightWidthNumber doubleValue]];
    
    // this needs to be done before loading the PDFDocument
    [self resetThumbnailSizeIfNeeded];
    [self resetSnapshotSizeIfNeeded];
    
    
    // NB: the next line will load the PDF document and annotations, so necessary setup must be finished first!
    // windowControllerDidLoadNib: is not called automatically because the document overrides makeWindowControllers
    [[self document] windowControllerDidLoadNib:self];
    
    // Show/hide left side pane if necessary
    BOOL hasOutline = ([[pdfView document] outlineRoot] != nil);
    if ([sud boolForKey:SKOpenContentsPaneOnlyForTOCKey] && [self leftSidePaneIsOpen] != hasOutline)
        [self toggleLeftSidePane:nil];
    if (hasOutline)
        [self setLeftSidePaneState:SKSidePaneStateOutline];
    else
        [leftSideController.button setEnabled:NO forSegment:SKSidePaneStateOutline];
    
    // Due to a bug in Leopard we should only resize and swap in the PDFView after loading the PDFDocument
    if ([[pdfView document] isLocked]) {
        // PDFView has the annoying habit for the password view to force a full window display
        CGFloat leftWidth = [self leftSideWidth];
        CGFloat rightWidth = [self rightSideWidth];
        [self applyLeftSideWidth:0.0 rightSideWidth:0.0];
        [pdfContentView addSubview:pdfView];
        [pdfView activateConstraintsToSuperview];
        [self applyLeftSideWidth:leftWidth rightSideWidth:rightWidth];
    } else {
        [pdfContentView addSubview:pdfView];
        [pdfView activateConstraintsToSuperview];
    }
    
    // get the initial display mode from the PDF if present and not overridden by an explicit setup
    if (hasWindowSetup == NO && [[NSUserDefaults standardUserDefaults] boolForKey:SKUseSettingsFromPDFKey]) {
        NSDictionary *initialSettings = [[self pdfDocument] initialSettings];
        if (initialSettings) {
            [self applyPDFSettings:initialSettings rewind:NO];
            if ([initialSettings objectForKey:@"fitWindow"])
                windowSizeOption = [[initialSettings objectForKey:@"fitWindow"] boolValue] ? SKWindowOptionFit : SKWindowOptionDefault;
        }
    }
    
    // Go to page?
    NSUInteger pageIndex = NSNotFound;
    NSString *pointString = nil;
    if (hasWindowSetup) {
        pageIndex = [[savedNormalSetup objectForKey:PAGEINDEX_KEY] unsignedIntegerValue];
        pointString = [savedNormalSetup objectForKey:SCROLLPOINT_KEY];
    } else if ([sud boolForKey:SKRememberLastPageViewedKey]) {
        pageIndex = [[SKBookmarkController sharedBookmarkController] pageIndexForRecentDocumentAtURL:[(NSDocument *)[self document] fileURL]];
    }
    if (pageIndex != NSNotFound && [[pdfView document] pageCount] > pageIndex) {
        if ([[pdfView document] isLocked]) {
            [savedNormalSetup setObject:[NSNumber numberWithUnsignedInteger:pageIndex] forKey:PAGEINDEX_KEY];
        } else if ([[pdfView currentPage] pageIndex] != pageIndex || pointString) {
            if (pointString)
                [pdfView goToPageAtIndex:pageIndex point:NSPointFromString(pointString)];
            else
                [pdfView goToCurrentPage:[[pdfView document] pageAtIndex:pageIndex]];
            [lastViewedPages setCount:0];
            [lastViewedPages addPointer:(void *)pageIndex];
            [pdfView resetHistory];
        }
    }
    
    // We can fit only after the PDF has been loaded
    if (windowSizeOption == SKWindowOptionFit && hasWindowSetup == NO) {
        [[window contentView] layoutSubtreeIfNeeded];
        [self performFit:self];
    }
    
    // Open snapshots?
    NSArray *snapshotSetups = nil;
    if (hasWindowSetup)
        snapshotSetups = [savedNormalSetup objectForKey:SNAPSHOTS_KEY];
    else if ([sud boolForKey:SKRememberSnapshotsKey])
        snapshotSetups = [[SKBookmarkController sharedBookmarkController] snapshotsForRecentDocumentAtURL:[(NSDocument *)[self document] fileURL]];
    if ([snapshotSetups count]) {
        if ([[pdfView document] isLocked])
            [savedNormalSetup setObject:snapshotSetups forKey:SNAPSHOTS_KEY];
        else
            [self showSnapshotsWithSetups:snapshotSetups];
    }
    
    noteTypeSheetController = [[SKNoteTypeSheetController alloc] init];
    [noteTypeSheetController setDelegate:self];
    
    NSMenu *menu = [[rightSideController.noteOutlineView headerView] menu];
    [menu addItem:[NSMenuItem separatorItem]];
    [[menu addItemWithTitle:NSLocalizedString(@"Note Type", @"Menu item title") action:NULL keyEquivalent:@""] setSubmenu:[noteTypeSheetController noteTypeMenu]];
    
    [pdfView setTypeSelectHelper:[leftSideController.thumbnailTableView typeSelectHelper]];
    
    [window recalculateKeyViewLoop];
    [window makeFirstResponder:pdfView];
    
    // initially autoScale does not take the content inset into account
    if (mwcFlags.fullSizeContent && [pdfView autoScales] && ([pdfView extendedDisplayMode] & kPDFDisplaySinglePageContinuous) == 0) {
        [pdfView setAutoScales:NO];
        [pdfView setAutoScales:YES];
    }
    
    // Update page states
    [self handlePageChangedNotification:nil];
    [toolbarController handlePageChangedNotification:nil];
    
    // Observe notifications and KVO
    [self registerForNotifications];
    [self registerAsObserver];
    
    if ([[pdfView document] isLocked]) {
        [window makeFirstResponder:[pdfView descendantOfClass:[NSSecureTextField class]]];
        [savedNormalSetup setObject:@YES forKey:LOCKED_KEY];
    } else {
        [savedNormalSetup removeAllObjects];
    }
    
    [self setRecentInfoNeedsUpdate:YES];
    
    mwcFlags.settingUpWindow = 0;
}

- (NSArray *)changedCropBoxes {
    NSMutableArray *cropBoxes = [NSMutableArray array];
    BOOL hasCrop = NO;
    for (PDFPage *page in [self pdfDocument]) {
        NSRect bounds = [page boundsForBox:kPDFDisplayBoxCropBox];
        NSRect origBounds = NSRectFromCGRect(CGPDFPageGetBoxRect([page pageRef], kCGPDFCropBox));
        if (NSEqualRects(bounds, origBounds)) {
            [cropBoxes addObject:@""];
        } else {
            [cropBoxes addObject:NSStringFromRect(bounds)];
            hasCrop = YES;
        }
    }
    return hasCrop ? cropBoxes : nil;
}

- (void)applyChangedCropBoxes:(NSArray *)cropBoxes {
    PDFDocument *pdfDoc = [self pdfDocument];
    NSUInteger i, iMax = [pdfDoc pageCount];
    if ([cropBoxes count] == iMax) {
        for (i = 0; i < iMax; i++) {
            NSString *box = [cropBoxes objectAtIndex:i];
            if ([box isEqualToString:@""] == NO)
                [[pdfDoc pageAtIndex:i] setBounds:NSRectFromString(box) forBox:kPDFDisplayBoxCropBox];
        }
        mwcFlags.hasCropped = 1;
    }
}

- (void)applyLeftSideWidth:(CGFloat)leftSideWidth rightSideWidth:(CGFloat)rightSideWidth {
    [splitView setPosition:leftSideWidth ofDividerAtIndex:0];
    [splitView setPosition:[splitView maxPossiblePositionOfDividerAtIndex:1] - [splitView dividerThickness] - rightSideWidth ofDividerAtIndex:1];
}

- (void)applySetup:(NSDictionary *)setup{
    if ([self isWindowLoaded] == NO) {
        [savedNormalSetup setDictionary:setup];
    } else {
        
        NSString *rectString = [setup objectForKey:MAINWINDOWFRAME_KEY];
        if (rectString)
            [mainWindow setFrame:NSRectFromString(rectString) display:[mainWindow isVisible]];
        
        NSNumber *leftWidth = [setup objectForKey:LEFTSIDEPANEWIDTH_KEY];
        NSNumber *rightWidth = [setup objectForKey:RIGHTSIDEPANEWIDTH_KEY];
        if (leftWidth && rightWidth)
            [self applyLeftSideWidth:[leftWidth doubleValue] rightSideWidth:[rightWidth doubleValue]];
        
        [self applyChangedCropBoxes:[setup objectForKey:CROPBOXES_KEY]];
        
        NSArray *snapshotSetups = [setup objectForKey:SNAPSHOTS_KEY];
        if ([snapshotSetups count])
            [self showSnapshotsWithSetups:snapshotSetups];
        
        if ([self interactionMode] == SKNormalMode)
            [self applyPDFSettings:setup rewind:NO];
        else
            [savedNormalSetup addEntriesFromDictionary:setup];
        
        NSNumber *pageIndexNumber = [setup objectForKey:PAGEINDEX_KEY];
        NSUInteger pageIndex = [pageIndexNumber unsignedIntegerValue];
        if (pageIndexNumber && pageIndex != NSNotFound && pageIndex != [[pdfView currentPage] pageIndex]) {
            NSString *pointString = [setup objectForKey:SCROLLPOINT_KEY];
            if (pointString)
                [pdfView goToPageAtIndex:pageIndex point:NSPointFromString(pointString)];
            else
                [pdfView goToCurrentPage:[[pdfView document] pageAtIndex:pageIndex]];
        }
    }
}

- (NSDictionary *)currentSetup {
    NSMutableDictionary *setup = [NSMutableDictionary dictionary];
    NSPoint point = NSZeroPoint;
    BOOL rotated = NO;
    NSUInteger pageIndex = [pdfView currentPageIndexAndPoint:&point rotated:&rotated];
    NSArray *cropBoxes = [self changedCropBoxes];
    
    [setup setObject:NSStringFromRect([mainWindow frame]) forKey:MAINWINDOWFRAME_KEY];
    [setup setObject:[NSNumber numberWithDouble:[self leftSideWidth]] forKey:LEFTSIDEPANEWIDTH_KEY];
    [setup setObject:[NSNumber numberWithDouble:[self rightSideWidth]] forKey:RIGHTSIDEPANEWIDTH_KEY];
    [setup setObject:[NSNumber numberWithUnsignedInteger:pageIndex] forKey:PAGEINDEX_KEY];
    if (rotated == NO)
        [setup setObject:NSStringFromPoint(point) forKey:SCROLLPOINT_KEY];
    if (cropBoxes)
        [setup setObject:cropBoxes forKey:CROPBOXES_KEY];
    if ([snapshots count])
        [setup setObject:[snapshots valueForKey:SKSnapshotCurrentSetupKey] forKey:SNAPSHOTS_KEY];
    if ([self interactionMode] == SKNormalMode) {
        [setup addEntriesFromDictionary:[self currentPDFSettings]];
    } else {
        [setup addEntriesFromDictionary:savedNormalSetup];
        [setup removeObjectsForKeys:@[HASHORIZONTALSCROLLER_KEY, HASVERTICALSCROLLER_KEY, AUTOHIDESSCROLLERS_KEY, DRAWSBACKGROUND_KEY, LOCKED_KEY]];
    }
    
    return setup;
}

- (void)applyPDFSettings:(NSDictionary *)setup rewind:(BOOL)rewind {
    if ([setup count] && rewind)
        [pdfView setNeedsRewind:YES];
    NSNumber *number;
    if ((number = [setup objectForKey:AUTOSCALES_KEY]))
        [pdfView setAutoScales:[number boolValue]];
    if ([pdfView autoScales] == NO && (number = [setup objectForKey:SCALEFACTOR_KEY]))
        [pdfView setScaleFactor:[number doubleValue]];
    if ((number = [setup objectForKey:DISPLAYSPAGEBREAKS_KEY]))
        [pdfView setDisplaysPageBreaks:[number boolValue]];
    if ((number = [setup objectForKey:DISPLAYSASBOOK_KEY]))
        [pdfView setDisplaysAsBook:[number boolValue]];
    if ((number = [setup objectForKey:DISPLAYMODE_KEY]))
        [pdfView setExtendedDisplayMode:[number integerValue]];
    if ((number = [setup objectForKey:DISPLAYDIRECTION_KEY]))
        [pdfView setDisplaysHorizontally:[number boolValue]];
    if ((number = [setup objectForKey:DISPLAYSRTL_KEY]))
        [pdfView setDisplaysRightToLeft:[number boolValue]];
    if ((number = [setup objectForKey:DISPLAYBOX_KEY]))
        [pdfView setDisplayBox:[number integerValue]];
}

- (NSDictionary *)currentPDFSettings {
    NSMutableDictionary *setup = [NSMutableDictionary dictionary];
    
    [setup setObject:[NSNumber numberWithBool:[pdfView displaysPageBreaks]] forKey:DISPLAYSPAGEBREAKS_KEY];
    [setup setObject:[NSNumber numberWithBool:[pdfView displaysAsBook]] forKey:DISPLAYSASBOOK_KEY];
    [setup setObject:[NSNumber numberWithInteger:[pdfView displayBox]] forKey:DISPLAYBOX_KEY];
    [setup setObject:[NSNumber numberWithDouble:[pdfView scaleFactor]] forKey:SCALEFACTOR_KEY];
    [setup setObject:[NSNumber numberWithBool:[pdfView autoScales]] forKey:AUTOSCALES_KEY];
    [setup setObject:[NSNumber numberWithInteger:[pdfView displayMode]] forKey:DISPLAYMODE_KEY];
    if (RUNNING_AFTER(10_12)) {
        [setup setObject:[NSNumber numberWithInteger:[pdfView displaysHorizontally] ? 1 : 0] forKey:DISPLAYDIRECTION_KEY];
        [setup setObject:[NSNumber numberWithBool:[pdfView displaysRightToLeft]] forKey:DISPLAYSRTL_KEY];
    }

    return setup;
}

- (void)applyOptions:(NSDictionary *)options {
    NSInteger page = [[options objectForKey:@"page"] integerValue];
    NSString *searchString = [options objectForKey:@"search"];
    NSMutableDictionary *settings = [options mutableCopy];
    [settings removeObjectForKey:@"page"];
    [settings removeObjectForKey:@"point"];
    [settings removeObjectForKey:@"search"];
    if ([settings count])
        [self applyPDFSettings:settings rewind:page == 0 && [[pdfView currentPage] pageIndex] > 0];
    [settings release];
    if (page > 0) {
        page = MIN(page, (NSInteger)[[pdfView document] pageCount]);
        NSString *pointString = [options objectForKey:@"point"];
        if ([pointString length] > 0) {
            if ([pointString hasPrefix:@"{"] == NO)
                pointString = [NSString stringWithFormat:@"{%@}", pointString];
            [pdfView goToPageAtIndex:page - 1 point:NSPointFromString(pointString)];
        } else if ((NSInteger)[[pdfView currentPage] pageIndex] != page) {
            [pdfView goToCurrentPage:[[pdfView document] pageAtIndex:page - 1]];
        }
    }
    if ([searchString length] > 0) {
        if ([self leftSidePaneIsOpen] == NO)
            [self toggleLeftSidePane:nil];
        [leftSideController.searchField setStringValue:searchString];
        [self performSelector:@selector(search:) withObject:leftSideController.searchField afterDelay:0.0];
    }
}

#pragma mark UI updating

- (void)updateLeftStatus {
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Page %ld of %ld", @"Status message"), (long)([[[self pdfView] currentPage] pageIndex] + 1), (long)[[pdfView document] pageCount]];
    [[statusBar leftField] setStringValue:message];
}

#define CM_PER_POINT 0.035277778
#define INCH_PER_POINT 0.013888889

- (void)updateRightStatus {
    NSRect rect = [pdfView currentSelectionRect];
    CGFloat magnification = [pdfView currentMagnification];
    NSString *message;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayNoteBoundsKey] && NSEqualRects(rect, NSZeroRect) && [pdfView currentAnnotation])
        rect = [[pdfView currentAnnotation] bounds];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayPageBoundsKey] && NSEqualRects(rect, NSZeroRect))
        rect = [[pdfView currentPage] boundsForBox:[pdfView displayBox]];

    if (NSEqualRects(rect, NSZeroRect) == NO) {
        if ([[[statusBar rightField] cell] state] == NSOnState) {
            BOOL useMetric = [[[NSLocale currentLocale] objectForKey:NSLocaleUsesMetricSystem] boolValue];
            NSString *units = useMetric ? NSLocalizedString(@"cm", @"size unit") : NSLocalizedString(@"in", @"size unit");
            CGFloat factor = useMetric ? CM_PER_POINT : INCH_PER_POINT;
            message = [NSString stringWithFormat:@"%.2f %C %.2f @ (%.2f, %.2f) %@", NSWidth(rect) * factor, MULTIPLICATION_SIGN_CHARACTER, NSHeight(rect) * factor, NSMinX(rect) * factor, NSMinY(rect) * factor, units];
        } else {
            message = [NSString stringWithFormat:@"%ld %C %ld @ (%ld, %ld) %@", (long)NSWidth(rect), MULTIPLICATION_SIGN_CHARACTER, (long)NSHeight(rect), (long)NSMinX(rect), (long)NSMinY(rect), NSLocalizedString(@"pt", @"size unit")];
        }
    } else if (magnification > 0.0001) {
        message = [NSString stringWithFormat:@"%.2f %C", magnification, MULTIPLICATION_SIGN_CHARACTER];
    } else {
        message = @"";
    }
    [[statusBar rightField] setStringValue:message];
}

- (void)updatePageColumnWidthForTableViews:(NSArray *)tvs {
    // this may happen for locked PDFs, nothing to do in this case
    if ([pageLabels count] == 0)
        return;
    
    NSTableView *tv = [tvs firstObject];
    NSTableColumn *tableColumn = [tv tableColumnWithIdentifier:PAGE_COLUMNID];
    id cell = [tableColumn dataCell];
    CGFloat labelWidth = 0.0;
    NSString *label = nil;
    
    for (NSString *aLabel in pageLabels) {
        [cell setStringValue:aLabel];
        CGFloat aLabelWidth = [cell cellSize].width;
        if (aLabelWidth > labelWidth) {
            labelWidth = aLabelWidth;
            label = aLabel;
        }
    }
    
    for (tv in tvs) {
        tableColumn = [tv tableColumnWithIdentifier:PAGE_COLUMNID];
        cell = [tableColumn dataCell];
        [cell setStringValue:label];
        labelWidth = [cell cellSize].width;
        if ([tv headerView])
            labelWidth = fmax(labelWidth, [[tableColumn headerCell] cellSize].width);
        labelWidth = fmin(ceil(labelWidth), MAX_PAGE_COLUMN_WIDTH);
        [tableColumn setMinWidth:labelWidth];
        [tableColumn setMaxWidth:labelWidth];
        [tableColumn setWidth:labelWidth];
        [tableColumn setResizingMask:NSTableColumnNoResizing];
        [tv sizeToFit];
        NSRect frame = [tv frame];
        CGFloat width = NSWidth([[[tv enclosingScrollView] contentView] visibleRect]);
        if (NSWidth(frame) < width) {
            frame.size.width = width;
            [tv setFrame:frame];
        }
    }
}

#define LABEL_KEY @"label"
#define EXPANDED_KEY @"expanded"
#define CHILDREN_KEY @"children"

- (NSDictionary *)expansionStateForOutline:(PDFOutline *)anOutline {
    if (anOutline == nil)
        return nil;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[anOutline label] forKey:LABEL_KEY];
    BOOL isExpanded = ([anOutline parent] == nil || [leftSideController.tocOutlineView isItemExpanded:anOutline]);
    [dict setValue:[NSNumber numberWithBool:isExpanded] forKey:EXPANDED_KEY];
    if (isExpanded) {
        NSUInteger i, iMax = [anOutline numberOfChildren];
        if (iMax > 0) {
            NSMutableArray *array = [[NSMutableArray alloc] init];
            for (i = 0; i < iMax; i++)
                [array addObject:[self expansionStateForOutline:[anOutline childAtIndex:i]]];
            [dict setValue:array forKey:CHILDREN_KEY];
            [array release];
        }
    }
    return dict;
}

- (void)expandOutline:(PDFOutline *)anOutline forExpansionState:(NSDictionary *)info level:(NSInteger)level {
    BOOL isExpanded = info ? [[info valueForKey:EXPANDED_KEY] boolValue] : level < 0 ? [anOutline isOpen] : level < 2;
    if (isExpanded && anOutline) {
        NSUInteger i, iMax = [anOutline numberOfChildren];
        NSMutableArray *children = [[NSMutableArray alloc] init];
        for (i = 0; i < iMax; i++)
            [children addObject:[anOutline childAtIndex:i]];
        if ([anOutline parent])
            [leftSideController.tocOutlineView expandItem:anOutline];
        if (level >= 0) ++level;
        NSArray *childrenStates = [info valueForKey:CHILDREN_KEY];
        NSEnumerator *infoEnum = nil;
        if (childrenStates && [[children valueForKey:LABEL_KEY] isEqualToArray:[childrenStates valueForKey:LABEL_KEY]])
            infoEnum = [childrenStates objectEnumerator];
        for (PDFOutline *child in children)
            [self expandOutline:child forExpansionState:[infoEnum nextObject] level:level];
        [children release];
    }
}

- (void)updateTableFont {
    NSFont *font = [NSFont systemFontOfSize:[[NSUserDefaults standardUserDefaults] floatForKey:SKTableFontSizeKey]];
    [leftSideController.tocOutlineView setFont:font];
    [rightSideController.noteOutlineView setFont:font];
    [leftSideController.findTableView setFont:font];
    [leftSideController.groupedFindTableView setFont:font];
}

- (void)updatePageLabelsAndOutlineForExpansionState:(NSDictionary *)info {
    // update page labels, also update the size of the table columns displaying the labels
    [self willChangeValueForKey:PAGELABELS_KEY];
    [pageLabels setArray:[[pdfView document] pageLabels]];
    [self didChangeValueForKey:PAGELABELS_KEY];
    
    [self updatePageLabel];
    
    // these carry a label, moreover when this is called the thumbnails will also be invalid
    [self resetThumbnails];
    [self allSnapshotsNeedUpdate];
    [rightSideController.noteOutlineView reloadData];
    [leftSideController.thumbnailTableView reloadTypeSelectStrings];

    [self updatePageColumnWidthForTableViews:@[leftSideController.thumbnailTableView, rightSideController.snapshotTableView, leftSideController.tocOutlineView, rightSideController.noteOutlineView, leftSideController.findTableView, leftSideController.groupedFindTableView]];
    
    PDFOutline *outlineRoot = [[pdfView document] outlineRoot];
    
    // layout of cellview in column: |-(18+(level-1)*indentation)-[label]-(10 or 2)-|
    // layout of textfield in cellview (leading/trailing!): |-(2)-[NSTextField]-(2)-|
    // column width = width of column - intercellspacing (??)
    NSOutlineView *ov = leftSideController.tocOutlineView;
    CGFloat minWidth = fmin(MAX_MIN_COLUMN_WIDTH, 7.0 + [ov indentationPerLevel] * [outlineRoot deepestLevel]);
    [[ov tableColumnWithIdentifier:LABEL_COLUMNID] setMinWidth:minWidth];
    
    mwcFlags.updatingOutlineSelection = 1;
    
    // If this is a reload following a TeX run and the user just killed the outline for some reason, we get a crash if the outlineView isn't reloaded, so no longer make it conditional on pdfOutline != nil
    [ov reloadData];
    if (outlineRoot) {
        NSInteger level = [[NSUserDefaults standardUserDefaults] boolForKey:SKCollapseTOCSublevelsKey] ? ([outlineRoot numberOfChildren] > 1) : -1;
        [self expandOutline:outlineRoot forExpansionState:info level:level];
    }
    mwcFlags.updatingOutlineSelection = 0;
    [self updateOutlineSelection];
    
    // handle the case as above where the outline has disappeared in a reload situation
    if (nil == outlineRoot)
        [self setLeftSidePaneState:SKSidePaneStateThumbnail];

    [leftSideController.button setEnabled:outlineRoot != nil forSegment:SKSidePaneStateOutline];
}

- (void)updatePageLabels {
    // called when changing between sequantial or logical page numbering
    // update page labels, also update the size of the table columns displaying the labels
    
    NSArray *newPageLabels = [[pdfView document] pageLabels];
    if ([newPageLabels isEqualToArray:pageLabels])
        return;
    
    [self willChangeValueForKey:PAGELABELS_KEY];
    [pageLabels setArray:newPageLabels];
    [self didChangeValueForKey:PAGELABELS_KEY];
    
    [self updatePageLabel];
    
    [leftSideController.thumbnailTableView reloadTypeSelectStrings];
    
    NSEnumerator *thumbnailEnum = [thumbnails objectEnumerator];
    for (NSString *label in pageLabels)
        [[thumbnailEnum nextObject] setLabel:label];
    
    PDFDocument *pdfDoc = [self pdfDocument];
    for (PDFPage *page in pdfDoc) {
        [page willChangeValueForKey:@"displayLabel"];
        [page didChangeValueForKey:@"displayLabel"];
    }
    
    [[pdfDoc outlineRoot] pageLabelDidUpdate];
    
    [[self snapshots] makeObjectsPerformSelector:@selector(updatePageLabel)];
    
    [self updatePageColumnWidthForTableViews:[NSArray arrayWithObjects:leftSideController.thumbnailTableView, rightSideController.snapshotTableView, leftSideController.tocOutlineView, rightSideController.noteOutlineView, leftSideController.findTableView, leftSideController.groupedFindTableView, nil]];
}

#pragma mark Notes and Widgets

- (void)registerWidgets:(NSArray *)array {
    [widgets addObjectsFromArray:array];
    [self startObservingNotes:array];
    for (PDFAnnotation *annotation in array) {
        id value = [annotation objectValue];
        if (value)
            [widgetValues setObject:value forKey:annotation];
    }
}

- (void)makeWidgets {
    [widgets release];
    widgets = [[NSMutableArray alloc] init];
    [widgetValues release];
    widgetValues = [[NSMapTable strongToStrongObjectsMapTable] retain];
    NSArray *array = [[self pdfDocument] detectedWidgets];
    if ([array count])
        [self registerWidgets:array];
}

- (void)document:(PDFDocument *)document didDetectWidgets:(NSArray *)newWidgets onPage:(PDFPage *)page {
    if ([newWidgets count] && widgets && [widgets containsObject:[newWidgets firstObject]] == NO)
        [self registerWidgets:newWidgets];
}

- (void)clearWidgets {
    if ([widgets count])
        [self stopObservingNotes:widgets];
    SKDESTROY(widgets);
    SKDESTROY(widgetValues);
}

- (void)setWidgetValues:(NSMapTable *)newWidgetValues {
    if (widgetValues) {
        [[[self document] undoManager] registerUndoWithTarget:self selector:@selector(setWidgetValues:) object:[[widgetValues copy] autorelease]];
        for (PDFAnnotation *widget in newWidgetValues) {
            [widgetValues setObject:[newWidgetValues objectForKey:widget] forKey:widget];
        }
    } else {
        widgetValues = [newWidgetValues retain];
    }
}

- (void)changeWidgetsFromDictionaries:(NSArray *)widgetDicts {
    for (NSDictionary *dict in widgetDicts) {
        NSRect bounds = NSIntegralRect(NSRectFromString([dict objectForKey:SKNPDFAnnotationBoundsKey]));
        NSUInteger pageIndex = [[dict objectForKey:SKNPDFAnnotationPageIndexKey] unsignedIntegerValue];
        SKNPDFWidgetType widgetType = [[dict objectForKey:SKNPDFAnnotationWidgetTypeKey] integerValue];
        NSString *fieldName = [dict objectForKey:SKNPDFAnnotationFieldNameKey] ?: @"";
        for (PDFAnnotation *annotation in [[[self pdfDocument] pageAtIndex:pageIndex] annotations]) {
            if ([annotation isWidget] &&
                [annotation widgetType] == widgetType &&
                [([annotation fieldName] ?: @"") isEqualToString:fieldName] &&
                NSEqualRects(NSIntegralRect([annotation bounds]), bounds)) {
                id value = [dict objectForKey:widgetType == kSKNPDFWidgetTypeButton ? SKNPDFAnnotationStateKey : SKNPDFAnnotationStringValueKey];
                if ([([annotation objectValue] ?: @"") isEqual:(value ?: @"")] == NO)
                    [annotation setObjectValue:value];
                break;
            }
        }
    }
}

- (NSArray *)widgetProperties {
    if (placeholderWidgetProperties)
        return placeholderWidgetProperties;
    NSMutableArray *properties = [NSMutableArray array];
    if (widgets) {
        for (PDFAnnotation *widget in widgets) {
            id value = [widget objectValue];
            id origValue = [widgetValues objectForKey:widget];
            if ([(value ?: @"") isEqual:(origValue ?: @"")] == NO)
                [properties addObject:[widget SkimNoteProperties]];
        }
    }
    return properties;
}

- (void)addAnnotationsFromDictionaries:(NSArray *)noteDicts removeAnnotations:(NSArray *)notesToRemove {
    PDFAnnotation *annotation;
    PDFDocument *pdfDoc = [pdfView document];
    NSMutableArray *notesToAdd = [NSMutableArray array];
    NSMutableArray *widgetProperties = [NSMutableArray array];
    NSMutableIndexSet *pageIndexes = [NSMutableIndexSet indexSet];
    BOOL isConvert = [notesToRemove count] > 0 && [[notesToRemove firstObject] isSkimNote] == NO;
    
    if ([pdfDoc allowsNotes] == NO && [noteDicts count] > 0) {
        // there should not be any notesToRemove at this point
        NSUInteger i, pageCount = MIN([pdfDoc pageCount], [[noteDicts valueForKeyPath:@"@max.pageIndex"] unsignedIntegerValue]);
        SKDESTROY(placeholderPdfDocument);
        pdfDoc = placeholderPdfDocument = [[SKPDFDocument alloc] init];
        [placeholderPdfDocument setContainingDocument:[self document]];
        for (i = 0; i < pageCount; i++) {
            PDFPage *page = [[SKPDFPage alloc] init];
            [placeholderPdfDocument insertPage:page atIndex:i];
            [page release];
        }
    }
    
    // disable automatic add/remove from the notification handlers
    // we want to do this in bulk as binding can be very slow and there are potentially many notes
    mwcFlags.addOrRemoveNotesInBulk = 1;
    
    if ([notesToRemove count]) {
        // notesToRemove is either all notes, no notes, or non Skim notes
        BOOL removeAllNotes = [[notesToRemove firstObject] isSkimNote];
        if (removeAllNotes) {
            [pdfView removePDFToolTipRects];
            // remove the current annotations
            [pdfView setCurrentAnnotation:nil];
        }
        for (annotation in [[notesToRemove copy] autorelease]) {
            [pageIndexes addIndex:[annotation pageIndex]];
            PDFAnnotation *popup = [annotation popup];
            if (popup)
                [pdfView removeAnnotation:popup];
            [pdfView removeAnnotation:annotation];
        }
        if (removeAllNotes)
            [self removeAllObjectsFromNotes];
    }
    if (notesToRemove && isConvert == NO && widgets) {
        for (PDFAnnotation *widget in widgets) {
            id origValue = [widgetValues objectForKey:widget];
            if ([([widget objectValue] ?: @"") isEqual:(origValue ?: @"")] == NO)
                [widget setObjectValue:origValue];
        }
    }
    
    // create new annotations from the dictionary and add them to their page and to the document
    for (NSDictionary *dict in noteDicts) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        if ([[dict objectForKey:SKNPDFAnnotationTypeKey] isEqualToString:SKNWidgetString]) {
            [widgetProperties addObject:dict];
        } else if ((annotation = [PDFAnnotation newSkimNoteWithProperties:dict])) {
            // this is only to make sure markup annotations generate the lineRects, for thread safety
            [annotation boundsOrder];
            NSUInteger pageIndex = [[dict objectForKey:SKNPDFAnnotationPageIndexKey] unsignedIntegerValue];
            if (pageIndex == NSNotFound)
                pageIndex = 0;
            else if (pageIndex >= [pdfDoc pageCount])
                pageIndex = [pdfDoc pageCount] - 1;
            [pageIndexes addIndex:pageIndex];
            PDFPage *page = [pdfDoc pageAtIndex:pageIndex];
            [pdfView addAnnotation:annotation toPage:page];
            if (isConvert && [[annotation contents] length] == 0)
                [annotation autoUpdateString];
            [notesToAdd addObject:annotation];
            [annotation release];
        }
        [pool release];
    }
    if ([notesToAdd count] > 0)
        [self insertNotes:notesToAdd atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange([notes count], [notesToAdd count])]];
    
    if ([[self pdfDocument] isLocked]) {
        [placeholderWidgetProperties release];
        placeholderWidgetProperties = [widgetProperties count] ? [widgetProperties copy] : nil;
    } else {
        if (widgets == nil)
            [self makeWidgets];
        if ([widgetProperties count])
            [self changeWidgetsFromDictionaries:widgetProperties];
        if (isConvert) {
            NSMapTable *values = [NSMapTable strongToStrongObjectsMapTable];
            for (PDFAnnotation *widget in widgets) {
                id value = [widget objectValue];
                if (value)
                    [values setObject:value forKey:widget];
            }
            if ([values count])
                [self setWidgetValues:values];
        }
    }
    
    // make sure we clear the undo handling
    [self observeUndoManagerCheckpoint:nil];
    [rightSideController.noteOutlineView reloadData];
    [self updateThumbnailsAtPageIndexes:pageIndexes];
    [pdfView resetPDFToolTipRects];
    
    mwcFlags.addOrRemoveNotesInBulk = 0;
}

#pragma mark Accessors

- (PDFDocument *)pdfDocument{
    return [pdfView document];
}

- (void)setPdfDocument:(PDFDocument *)document{

    if ([pdfView document] != document) {
        
        NSUInteger pageIndex = NSNotFound, secondaryPageIndex = NSNotFound;
        NSPoint point = NSZeroPoint, secondaryPoint = NSZeroPoint;
        BOOL rotated = NO, secondaryRotated = NO;
        NSArray *snapshotDicts = nil;
        NSDictionary *openState = nil;
        
        if ([pdfView document]) {
            pageIndex = [pdfView currentPageIndexAndPoint:&point rotated:&rotated];
            if (secondaryPdfView)
                secondaryPageIndex = [secondaryPdfView currentPageIndexAndPoint:&secondaryPoint rotated:&secondaryRotated];
            openState = [self expansionStateForOutline:[[pdfView document] outlineRoot]];
            
            [[pdfView document] cancelFindString];
            
            // make sure these will not be activated, or they can lead to a crash
            [pdfView removePDFToolTipRects];
            [pdfView setCurrentAnnotation:nil];
            
            // these will be invalid. If needed, the document will restore them
            [self setSearchResults:nil];
            [self setGroupedSearchResults:nil];
            [self removeAllObjectsFromNotes];
            [self setThumbnails:nil];
            [self clearWidgets];
            SKDESTROY(placeholderPdfDocument);
            SKDESTROY(placeholderWidgetProperties);

            // remmeber snapshots and close them, without animation
            snapshotDicts = [snapshots valueForKey:SKSnapshotCurrentSetupKey];
            [snapshots setValue:nil forKey:@"delegate"];
            [snapshots makeObjectsPerformSelector:@selector(close)];
            [self removeAllObjectsFromSnapshots];
            [rightSideController.snapshotTableView reloadData];
            
            [lastViewedPages setCount:0];
            
            [self unregisterForDocumentNotifications];
            
            [[pdfView document] setDelegate:nil];
            
            [[[pdfView document] outlineRoot] clearDocument];
            
            [[pdfView document] setContainingDocument:nil];
        }
        
        if ([document isLocked] && [pdfView window]) {
            // PDFView has the annoying habit for the password view to force a full window display
            CGFloat leftWidth = [self leftSideWidth];
            CGFloat rightWidth = [self rightSideWidth];
            [pdfView setDocument:document];
            [self applyLeftSideWidth:leftWidth rightSideWidth:rightWidth];
        } else {
            NSArray *cropBoxes = [savedNormalSetup objectForKey:CROPBOXES_KEY];
            NSUInteger i, iMax = [document pageCount];
            if ([cropBoxes count] == iMax) {
                for (i = 0; i < iMax; i++) {
                    NSString *box = [cropBoxes objectAtIndex:i];
                    if ([box isEqualToString:@""] == NO)
                        [[document pageAtIndex:i] setBounds:NSRectFromString(box) forBox:kPDFDisplayBoxCropBox];
                }
            }
            [pdfView setDocument:document];
        }
        [[pdfView document] setDelegate:self];
        
        [secondaryPdfView setDocument:document];
        
        [[pdfView document] setContainingDocument:[self document]];

        [self registerForDocumentNotifications];
        
        [self updatePageLabelsAndOutlineForExpansionState:openState];
        [self updateNoteSelection];
        
        if ([snapshotDicts count]) {
            if ([document isLocked] && ([self interactionMode] == SKNormalMode || [self interactionMode] == SKFullScreenMode))
                [savedNormalSetup setObject:snapshotDicts forKey:SNAPSHOTS_KEY];
            else
                [self showSnapshotsWithSetups:snapshotDicts];
        }
        
        if ([document pageCount] && (pageIndex != NSNotFound || secondaryPageIndex != NSNotFound)) {
            if (pageIndex != NSNotFound) {
                if (pageIndex >= [document pageCount])
                    pageIndex = [document pageCount] - 1;
                if ([document isLocked] && ([self interactionMode] == SKNormalMode || [self interactionMode] == SKFullScreenMode)) {
                    [savedNormalSetup setObject:[NSNumber numberWithUnsignedInteger:pageIndex] forKey:PAGEINDEX_KEY];
                } else {
                    if (rotated)
                        [pdfView goToCurrentPage:[document pageAtIndex:pageIndex]];
                    else
                        [pdfView goToPageAtIndex:pageIndex point:point];
                }
            }
            if (secondaryPageIndex != NSNotFound) {
                if (secondaryPageIndex >= [document pageCount])
                    secondaryPageIndex = [document pageCount] - 1;
                if (secondaryRotated)
                    [secondaryPdfView goToCurrentPage:[document pageAtIndex:secondaryPageIndex]];
                else
                    [secondaryPdfView goToPageAtIndex:secondaryPageIndex point:secondaryPoint];
            }
            [pdfView resetHistory];
        }
        
        if (markedPageIndex >= [document pageCount]) {
            markedPageIndex = NSNotFound;
            beforeMarkedPageIndex = NSNotFound;
        } else if (beforeMarkedPageIndex >= [document pageCount]) {
            beforeMarkedPageIndex = NSNotFound;
        }
        
        // the number of pages may have changed
        [toolbarController handleChangedHistoryNotification:nil];
        [toolbarController handlePageChangedNotification:nil];
        [self handlePageChangedNotification:nil];
        [self updateLeftStatus];
        [self updateRightStatus];
    }
}

- (void)updatePageLabel {
    NSString *label = [[pdfView currentPage] displayLabel];
    if ([label isEqualToString:pageLabel] == NO) {
        [self willChangeValueForKey:PAGELABEL_KEY];
        [pageLabel release];
        pageLabel = [label retain];
        [self didChangeValueForKey:PAGELABEL_KEY];
    }
}

- (void)setPageLabel:(NSString *)label {
    if (label != pageLabel) {
        [pageLabel release];
        pageLabel = [label retain];
    }
    NSUInteger idx = [pageLabels indexOfObject:label];
    if (idx != NSNotFound && [[pdfView currentPage] pageIndex] != idx)
        [pdfView goToCurrentPage:[[pdfView document] pageAtIndex:idx]];
}

- (BOOL)validatePageLabel:(id *)value error:(NSError **)error {
    if ([pageLabels indexOfObject:*value] == NSNotFound)
        *value = [self pageLabel];
    return YES;
}

- (BOOL)autoScales {
    return [pdfView autoScales];
}

- (SKLeftSidePaneState)leftSidePaneState {
    return mwcFlags.leftSidePaneState;
}

- (void)setLeftSidePaneState:(SKLeftSidePaneState)newLeftSidePaneState {
    if (mwcFlags.leftSidePaneState != newLeftSidePaneState) {
        mwcFlags.leftSidePaneState = newLeftSidePaneState;
        
        if ([leftSideController.searchField stringValue] && [[leftSideController.searchField stringValue] isEqualToString:@""] == NO) {
            [leftSideController.searchField setStringValue:@""];
        }
        
        if (mwcFlags.leftSidePaneState == SKSidePaneStateThumbnail)
            [self displayThumbnailViewAnimating:NO];
        else if (mwcFlags.leftSidePaneState == SKSidePaneStateOutline)
            [self displayTocViewAnimating:NO];
    }
}

- (SKRightSidePaneState)rightSidePaneState {
    return mwcFlags.rightSidePaneState;
}

- (void)setRightSidePaneState:(SKRightSidePaneState)newRightSidePaneState {
    if (mwcFlags.rightSidePaneState != newRightSidePaneState) {
        
        if ([[rightSideController.searchField stringValue] length] > 0) {
            [rightSideController.searchField setStringValue:@""];
            [self searchNotes:rightSideController.searchField];
        }
        
        mwcFlags.rightSidePaneState = newRightSidePaneState;
        
        if (mwcFlags.rightSidePaneState == SKSidePaneStateNote)
            [self displayNoteViewAnimating:NO];
        else if (mwcFlags.rightSidePaneState == SKSidePaneStateSnapshot)
            [self displaySnapshotViewAnimating:NO];
    }
}

- (SKFindPaneState)findPaneState {
    return mwcFlags.findPaneState;
}

- (void)setFindPaneState:(SKFindPaneState)newFindPaneState {
    if (mwcFlags.findPaneState != newFindPaneState) {
        mwcFlags.findPaneState = newFindPaneState;
        
        if (mwcFlags.findPaneState == SKFindPaneStateSingular) {
            if ([leftSideController.groupedFindTableView window])
                [self displayFindViewAnimating:NO];
        } else if (mwcFlags.findPaneState == SKFindPaneStateGrouped) {
            if ([leftSideController.findTableView window])
                [self displayGroupedFindViewAnimating:NO];
        }
        [self updateFindResultHighlightsForDirection:NSDirectSelection];
    }
}

- (BOOL)leftSidePaneIsOpen {
    if ([self interactionMode] == SKPresentationMode)
        return [sideWindow isVisible];
    else
        return NO == [splitView isSubviewCollapsed:leftSideContentView];
}

- (BOOL)rightSidePaneIsOpen {
    if ([self interactionMode] == SKPresentationMode)
        return NO;
    else
        return NO == [splitView isSubviewCollapsed:rightSideContentView];
}

- (CGFloat)leftSideWidth {
    return [self leftSidePaneIsOpen] ? NSWidth([leftSideContentView frame]) : 0.0;
}

- (CGFloat)rightSideWidth {
    return [self rightSidePaneIsOpen] ? NSWidth([rightSideContentView frame]) : 0.0;
}

- (BOOL)hasNotes {
    if ([notes count] > 0)
        return YES;
    if ([placeholderWidgetProperties count] > 0)
        return YES;
    for (PDFAnnotation *widget in widgets) {
        if ([([widget objectValue] ?: @"") isEqual:([widgetValues objectForKey:widget] ?: @"")] == NO)
            return YES;
    }
    return NO;
}

- (NSArray *)notes {
    return notes;
}
	 
- (NSUInteger)countOfNotes {
    return [notes count];
}

- (PDFAnnotation *)objectInNotesAtIndex:(NSUInteger)theIndex {
    return [notes objectAtIndex:theIndex];
}

- (void)insertObject:(PDFAnnotation *)note inNotesAtIndex:(NSUInteger)theIndex {
    [notes insertObject:note atIndex:theIndex];

    // Start observing the just-inserted notes so that, when they're changed, we can record undo operations.
    [self startObservingNotes:@[note]];
}

- (void)insertNotes:(NSArray *)newNotes atIndexes:(NSIndexSet *)theIndexes {
    [notes insertObjects:newNotes atIndexes:theIndexes];

    // Start observing the just-inserted notes so that, when they're changed, we can record undo operations.
    [self startObservingNotes:newNotes];
}

- (void)removeObjectFromNotesAtIndex:(NSUInteger)theIndex {
    PDFAnnotation *note = [notes objectAtIndex:theIndex];
    
    [[self windowControllerForNote:note] close];
    
    if ([note hasNoteText])
        NSMapRemove(rowHeights, [note noteText]);
    NSMapRemove(rowHeights, note);
    
    // Stop observing the removed notes
    [self stopObservingNotes:@[note]];
    
    [notes removeObjectAtIndex:theIndex];
}

- (void)removeAllObjectsFromNotes {
    if ([notes count]) {
        NSArray *wcs = [[[self document] windowControllers] copy];
        for (NSWindowController *wc in wcs) {
            if ([wc isNoteWindowController])
                [wc close];
        }
        [wcs release];
        
        NSResetMapTable(rowHeights);
        
        [self stopObservingNotes:notes];

        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [notes count])];
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:NOTES_KEY];
        [notes removeAllObjects];
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:NOTES_KEY];
        
        [rightSideController.noteOutlineView reloadData];
    }
}

- (NSArray *)thumbnails {
    return thumbnails;
}

- (void)setThumbnails:(NSArray *)newThumbnails {
    [thumbnails setValue:nil forKey:@"delegate"];
    [thumbnails setArray:newThumbnails];
    [thumbnails setValue:self forKey:@"delegate"];
}

- (NSArray *)snapshots {
    return snapshots;
}

- (NSUInteger)countOfSnapshots {
    return [snapshots count];
}

- (SKSnapshotWindowController *)objectInSnapshotsAtIndex:(NSUInteger)theIndex {
    return [snapshots objectAtIndex:theIndex];
}

- (void)insertObject:(SKSnapshotWindowController *)snapshot inSnapshotsAtIndex:(NSUInteger)theIndex {
    [snapshots insertObject:snapshot atIndex:theIndex];
}

- (void)removeObjectFromSnapshotsAtIndex:(NSUInteger)theIndex {
    [dirtySnapshots removeObject:[snapshots objectAtIndex:theIndex]];
    [snapshots removeObjectAtIndex:theIndex];
}

- (void)removeAllObjectsFromSnapshots {
    if ([snapshots count]) {
        NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [snapshots count])];
        [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:SNAPSHOTS_KEY];
        
        [dirtySnapshots removeAllObjects];
        
        [snapshots removeAllObjects];
        
        [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:indexes forKey:SNAPSHOTS_KEY];
    }
}

- (NSArray *)selectedNotes {
    NSMutableArray *selectedNotes = [NSMutableArray array];
    NSIndexSet *rowIndexes = [rightSideController.noteOutlineView selectedRowIndexes];
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
        id item = [rightSideController.noteOutlineView itemAtRow:row];
        if ([(PDFAnnotation *)item type] == nil)
            item = [(SKNoteText *)item note];
        if ([selectedNotes containsObject:item] == NO)
            [selectedNotes addObject:item];
    }];
    return selectedNotes;
}

- (void)setSelectedNotes:(NSArray *)newSelectedNotes {
    NSMutableIndexSet *rowIndexes = [NSMutableIndexSet indexSet];
    for (PDFAnnotation *note in newSelectedNotes) {
        NSInteger row = [rightSideController.noteOutlineView rowForItem:note];
        if (row != -1)
            [rowIndexes addIndex:row];
    }
    [rightSideController.noteOutlineView selectRowIndexes:rowIndexes byExtendingSelection:NO];
}

- (NSArray *)searchResults {
    return searchResults;
}

- (void)setSearchResults:(NSArray *)newSearchResults {
    [searchResults setArray:newSearchResults];
}

- (NSUInteger)countOfSearchResults {
    return [searchResults count];
}

- (PDFSelection *)objectInSearchResultsAtIndex:(NSUInteger)theIndex {
    return [searchResults objectAtIndex:theIndex];
}

- (void)insertObject:(PDFSelection *)searchResult inSearchResultsAtIndex:(NSUInteger)theIndex {
    [searchResults insertObject:searchResult atIndex:theIndex];
}

- (void)removeObjectFromSearchResultsAtIndex:(NSUInteger)theIndex {
    [searchResults removeObjectAtIndex:theIndex];
}

- (NSArray *)groupedSearchResults {
    return groupedSearchResults;
}

- (void)setGroupedSearchResults:(NSArray *)newGroupedSearchResults {
    [groupedSearchResults setArray:newGroupedSearchResults];
}

- (NSUInteger)countOfGroupedSearchResults {
    return [groupedSearchResults count];
}

- (SKGroupedSearchResult *)objectInGroupedSearchResultsAtIndex:(NSUInteger)theIndex {
    return [groupedSearchResults objectAtIndex:theIndex];
}

- (void)insertObject:(SKGroupedSearchResult *)groupedSearchResult inGroupedSearchResultsAtIndex:(NSUInteger)theIndex {
    [groupedSearchResults insertObject:groupedSearchResult atIndex:theIndex];
}

- (void)removeObjectFromGroupedSearchResultsAtIndex:(NSUInteger)theIndex {
    [groupedSearchResults removeObjectAtIndex:theIndex];
}

- (NSDictionary *)presentationOptions {
    SKTransitionController *transitions = [pdfView transitionController];
    SKTransitionInfo *transition = [transitions transition];
    NSArray *pageTransitions = [transitions pageTransitions];
    NSMutableDictionary *options = nil;
    if ([transition transitionStyle] != SKNoTransition || [pageTransitions count]) {
        options = [NSMutableDictionary dictionaryWithDictionary:[(transition ?: [[[SKTransitionInfo alloc] init] autorelease]) properties]];
        [options setValue:pageTransitions forKey:PAGETRANSITIONS_KEY];
    }
    return options;
}

- (void)setPresentationOptions:(NSDictionary *)dictionary {
    SKTransitionController *transitions = [pdfView transitionController];
    [transitions setTransition:[[[SKTransitionInfo alloc] initWithProperties:dictionary] autorelease]];
    [transitions setPageTransitions:[dictionary objectForKey:PAGETRANSITIONS_KEY]];
}

- (void)setPresentationNotesDocument:(NSDocument *)newDocument {
    [self removePresentationNotesNavigation];
    if (presentationNotesDocument != newDocument) {
        [presentationNotesDocument release];
        presentationNotesDocument = [newDocument retain];
    }
}

- (BOOL)recentInfoNeedsUpdate {
    return mwcFlags.recentInfoNeedsUpdate && [self isWindowLoaded] && [[self window] delegate];
}

- (void)setRecentInfoNeedsUpdate:(BOOL)flag {
    mwcFlags.recentInfoNeedsUpdate = flag;
}

- (NSMenu *)notesMenu {
    return [[rightSideController.noteOutlineView headerView] menu];
}

#pragma mark Swapping tables

- (void)displayTocViewAnimating:(BOOL)animate {
    [leftSideController replaceSideView:leftSideController.tocOutlineView.enclosingScrollView animate:animate];
    [self updateOutlineSelection];
}

- (void)displayThumbnailViewAnimating:(BOOL)animate {
    [leftSideController replaceSideView:leftSideController.thumbnailTableView.enclosingScrollView animate:animate];
    [self updateThumbnailSelection];
}

- (void)displayFindViewAnimating:(BOOL)animate {
    [leftSideController replaceSideView:leftSideController.findTableView.enclosingScrollView animate:animate];
}

- (void)displayGroupedFindViewAnimating:(BOOL)animate {
    [leftSideController replaceSideView:leftSideController.groupedFindTableView.enclosingScrollView animate:animate];
}

- (void)displayNoteViewAnimating:(BOOL)animate {
    [rightSideController replaceSideView:rightSideController.noteOutlineView.enclosingScrollView animate:animate];
}

- (void)displaySnapshotViewAnimating:(BOOL)animate {
    [rightSideController replaceSideView:rightSideController.snapshotTableView.enclosingScrollView animate:animate];
    [self updateSnapshotsIfNeeded];
}

#pragma mark Overview

- (BOOL)hasOverview {
    return [overviewView window] != nil;
}

- (void)hideOverview:(id)sender {
    [self hideOverviewAnimating:YES];
}

- (void)updateOverviewItemSize {
    NSSize size;
    CGFloat width = 0.0;
    CGFloat height = 0.0;
    for (SKThumbnail *thumbnail in [self thumbnails]) {
        size = [thumbnail size];
        if (size.width < size.height) {
            height = 1.0;
            if (width >= 1.0)
                break;
            width = fmax(width, size.width / size.height);
        } else if (size.height < size.width) {
            width = 1.0;
            if (height >= 1.0)
                break;
            height = fmax(height, size.height / size.width);
        } else {
            width = height = 1.0;
            break;
        }
    }
    size = [SKThumbnailView sizeForImageSize:NSMakeSize(ceil(width * roundedThumbnailSize), ceil(height * roundedThumbnailSize))];
    if (RUNNING_BEFORE(10_11)) {
        if (NSEqualSizes(size, [overviewView minItemSize]) == NO) {
            [overviewView setMinItemSize:size];
            [overviewView setMaxItemSize:size];
        }
    } else {
        NSCollectionViewFlowLayout *layout = [overviewView collectionViewLayout];
        if (NSEqualSizes(size, [layout itemSize]) == NO) {
            [layout setItemSize:size];
            [layout invalidateLayout];
        }
    }
}

- (void)showOverviewAnimating:(BOOL)animate {
    if ([overviewView window])
        return;
    
    if ([NSView shouldShowFadeAnimation] == NO)
        animate = NO;
    
    if (overviewView == nil) {
        overviewView  = [[SKOverviewView alloc] init];
        NSScrollView *scrollView = [[NSScrollView alloc] init];
        [scrollView setHasVerticalScroller:YES];
        [scrollView setAutohidesScrollers:YES];
        [scrollView setDocumentView:overviewView];
        [scrollView setDrawsBackground:NO];
        NSVisualEffectView *bgView = [[NSVisualEffectView alloc] init];
        [overviewView setSelectable:YES];
        [overviewView setAllowsMultipleSelection:YES];
        [overviewView setBackgroundColors:@[[NSColor clearColor]]];
        if (RUNNING_BEFORE(10_11)) {
            overviewContentView = bgView;
            [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            [overviewContentView addSubview:scrollView];
            [scrollView release];
            [self updateOverviewItemSize];
            [overviewView setItemPrototype:[[[SKThumbnailItem alloc] init] autorelease]];
            [overviewView setContent:[self thumbnails]];
            NSInteger i, iMax = [[overviewView content] count];
            for (i = 0; i < iMax; i++)
                [(SKThumbnailItem *)[overviewView itemAtIndex:i] setHighlightLevel:[self thumbnailHighlightLevelForRow:i]];
            if (markedPageIndex != NSNotFound)
                [(SKThumbnailItem *)[overviewView itemAtIndex:markedPageIndex] setMarked:YES];
        } else {
            overviewContentView = scrollView;
            [overviewView setBackgroundView:bgView];
            [bgView release];
            NSCollectionViewFlowLayout *layout = [[[NSCollectionViewFlowLayout alloc] init] autorelease];
            [layout setMinimumLineSpacing:8.0];
            [layout setMinimumInteritemSpacing:0.0];
            [overviewView setCollectionViewLayout:layout];
            [self updateOverviewItemSize];
            [overviewView registerClass:[SKThumbnailItem class] forItemWithIdentifier:@"thumbnail"];
            [overviewView setDataSource:(id<NSCollectionViewDataSource>)self];
        }
        [overviewView setSelectionIndexes:[NSIndexSet indexSetWithIndex:[[pdfView currentPage] pageIndex]]];
        [overviewView setTypeSelectHelper:[leftSideController.thumbnailTableView typeSelectHelper]];
        [overviewView setDoubleClickAction:@selector(hideOverview:)];
        [overviewView addObserver:self forKeyPath:RUNNING_BEFORE(10_11) ? @"selectionIndexes" : @"selectionIndexPaths" options:0 context:&SKMainWindowThumbnailSelectionObservationContext];
        [overviewContentView setTranslatesAutoresizingMaskIntoConstraints:NO];
    }
    
    BOOL isPresentation = [self interactionMode] == SKPresentationMode;
    NSView *oldView = isPresentation ? pdfView : splitView;
    NSView *contentView = [oldView superview];
    BOOL hasStatus = isPresentation == NO && [statusBar isVisible];
    NSArray *constraints = @[
        [NSLayoutConstraint constraintWithItem:overviewContentView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:overviewContentView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:overviewContentView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:mwcFlags.fullSizeContent || isPresentation ? contentView : [[self window] contentLayoutGuide] attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:hasStatus ? statusBar : contentView attribute:hasStatus ? NSLayoutAttributeTop : NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:overviewContentView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0]];
    
    [overviewContentView setFrame:[oldView frame]];
    [overviewView scrollRectToVisible:[overviewView frameForItemAtIndex:[[pdfView currentPage] pageIndex]]];
    [overviewView setSelectionIndexes:[NSIndexSet indexSetWithIndex:[[pdfView currentPage] pageIndex]]];
    
    if (RUNNING_BEFORE(10_11)) {
        [(NSVisualEffectView *)overviewContentView setMaterial:isPresentation ? NSVisualEffectMaterialDark : NSVisualEffectMaterialAppearanceBased];
        NSBackgroundStyle style = isPresentation ? NSBackgroundStyleDark : NSBackgroundStyleLight;
        NSUInteger i, iMax = [[overviewView content] count];
        for (i = 0; i < iMax; i++)
            [(SKThumbnailItem *)[overviewView itemAtIndex:i] setBackgroundStyle:style];
    } else if (RUNNING_BEFORE(10_14)) {
        [(NSVisualEffectView *)[overviewView backgroundView] setMaterial:isPresentation ? NSVisualEffectMaterialDark : NSVisualEffectMaterialSidebar];
        [[overviewView visibleItems] setValue:[NSNumber numberWithInteger:isPresentation ? NSBackgroundStyleDark : NSBackgroundStyleLight] forKey:@"backgroundStyle"];
    } else if (isPresentation) {
        SKSetHasDarkAppearance(overviewContentView);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        [(NSVisualEffectView *)[overviewView backgroundView] setMaterial:NSVisualEffectMaterialUnderPageBackground];
#pragma clang diagnostic pop
    } else {
        SKSetHasDefaultAppearance(overviewContentView);
        [(NSVisualEffectView *)[overviewView backgroundView] setMaterial:NSVisualEffectMaterialSidebar];
    }
    [overviewView setSingleClickAction:isPresentation ? @selector(hideOverview:) : NULL];
    
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
    
    if (animate) {
        BOOL hasLayer = [contentView wantsLayer] || [contentView layer] != nil;
        if (hasLayer == NO) {
            [contentView setWantsLayer:YES];
            [contentView displayIfNeeded];
        }
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * context){
                [[contentView animator] replaceSubview:oldView with:overviewContentView];
                [NSLayoutConstraint activateConstraints:constraints];
            }
            completionHandler:^{
                [touchBarController overviewChanged];
                if (hasLayer == NO)
                    [contentView setWantsLayer:NO];
            }];
    } else {
        [contentView replaceSubview:oldView with:overviewContentView];
        [NSLayoutConstraint activateConstraints:constraints];
    }
    [[self window] makeFirstResponder:overviewView];
    if (isPresentation)
        [NSCursor setHiddenUntilMouseMoves:NO];
    [touchBarController overviewChanged];
}

- (void)hideOverviewAnimating:(BOOL)animate completionHandler:(void (^)(void))handler {
    if ([overviewView window] == nil) {
        if (handler)
            handler();
        return;
    }
    
    if ([NSView shouldShowFadeAnimation] == NO)
        animate = NO;
    
    BOOL isMainWindow = [overviewContentView window] == mainWindow;
    NSView *newView = isMainWindow ? splitView : pdfView;
    NSView *contentView = [overviewContentView superview];
    BOOL hasStatus = isMainWindow && [statusBar isVisible];
    NSArray *constraints = @[
        [NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:newView attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:newView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:mwcFlags.fullSizeContent || isMainWindow == NO ? contentView : [mainWindow contentLayoutGuide] attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:hasStatus ? statusBar : contentView attribute:hasStatus ? NSLayoutAttributeTop : NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:newView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0]];
    
    if (animate) {
        BOOL hasLayer = [contentView wantsLayer] || [contentView layer] != nil;
        if (hasLayer == NO) {
            [contentView setWantsLayer:YES];
            [contentView displayIfNeeded];
        }
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [[contentView animator] replaceSubview:overviewContentView with:newView];
                [NSLayoutConstraint activateConstraints:constraints];
            }
            completionHandler:^{
                [touchBarController overviewChanged];
                if ([pdfView window] == [self window])
                    [[self window] makeFirstResponder:pdfView];
                if (hasLayer == NO)
                    [contentView setWantsLayer:NO];
                if (handler)
                    handler();
            }];
    } else {
        [contentView replaceSubview:overviewContentView with:newView];
        [NSLayoutConstraint activateConstraints:constraints];
        [touchBarController overviewChanged];
        if ([pdfView window] == [self window])
            [[self window] makeFirstResponder:pdfView];
        if (handler)
            handler();
    }
}

    
- (void)hideOverviewAnimating:(BOOL)animate {
    [self hideOverviewAnimating:(BOOL)animate completionHandler:NULL];
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    return [[self thumbnails] count];
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    SKThumbnailItem *item = [collectionView makeItemWithIdentifier:@"thumbnail" forIndexPath:indexPath];
    NSUInteger i = [indexPath item];
    [item setRepresentedObject:[[self thumbnails] objectAtIndex:i]];
    [item setHighlightLevel:[self thumbnailHighlightLevelForRow:i]];
    if (markedPageIndex == i)
        [item setMarked:YES];
    if (RUNNING_BEFORE(10_14))
        [item setBackgroundStyle:[self interactionMode] == SKPresentationMode ? NSBackgroundStyleDark : NSBackgroundStyleLight];
    return item;
}

#pragma mark Searching

- (NSString *)searchString {
    return [leftSideController.searchField stringValue];
}

- (BOOL)findString:(NSString *)string forward:(BOOL)forward {
    PDFDocument *pdfDoc = [pdfView document];
    if ([pdfDoc isFinding]) {
        NSBeep();
        return NO;
    }
    
    if ([self hasOverview]) {
        [self hideOverviewAnimating:YES completionHandler:^{
            [self findString:string forward:forward];
        }];
        return YES;
    }
    
    PDFSelection *sel = [pdfView currentSelection];
    NSUInteger pageIndex = [[pdfView currentPage] pageIndex];
    NSInteger options = 0;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKCaseInsensitiveFindKey])
        options |= NSCaseInsensitiveSearch;
    if (forward == NO)
        options |= NSBackwardsSearch;
    while ([sel hasCharacters] == NO && (forward ? pageIndex-- > 0 : ++pageIndex < [pdfDoc pageCount])) {
        PDFPage *page = [pdfDoc pageAtIndex:pageIndex];
        NSUInteger length = [[page string] length];
        if (length > 0)
            sel = [page selectionForRange:NSMakeRange(0, length)];
    }
    PDFSelection *selection = [pdfDoc findString:string fromSelection:sel withOptions:options];
    if ([selection hasCharacters] == NO && [sel hasCharacters])
        selection = [pdfDoc findString:string fromSelection:nil withOptions:options];
    if (selection) {
        PDFPage *page = [selection safeFirstPage];
        [pdfView goToRect:[selection boundsForPage:page] onPage:page];
        [leftSideController.findTableView deselectAll:self];
        [leftSideController.groupedFindTableView deselectAll:self];
        [pdfView setCurrentSelection:selection animate:YES];
        return YES;
	} else {
		NSBeep();
        return NO;
	}
}

- (void)removeFindController:(SKFindController *)aFindController {
    if (mwcFlags.isAnimatingFindBar)
        return;
    
    BOOL animate = [NSView shouldShowSlideAnimation];
    NSView *findBar = [findController view];
    NSView *contentView = [findBar superview];
    NSLayoutConstraint *newTopConstraint = nil;
    CGFloat barHeight = NSHeight([findBar frame]);
    
    if (mwcFlags.fullSizeContent == NO)
        newTopConstraint = [NSLayoutConstraint constraintWithItem:mwcFlags.fullSizeContent ? pdfView : pdfSplitView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
    
    if ([[mainWindow firstResponder] isDescendantOf:findBar])
        [mainWindow makeFirstResponder:pdfView];
    
    if (mwcFlags.fullSizeContent) {
        [[pdfView scrollView] setAutomaticallyAdjustsContentInsets:YES];
        if ([pdfView autoScales] && ([pdfView extendedDisplayMode] & kPDFDisplaySinglePageContinuous) == 0) {
            [pdfView setAutoScales:NO];
            [pdfView setAutoScales:YES];
        }
    }
    
    if (animate) {
        NSLayoutConstraint *topConstraint = [contentView constraintWithFirstItem:findBar firstAttribute:NSLayoutAttributeTop];
        mwcFlags.isAnimatingFindBar = YES;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                [context setDuration:0.5 * [context duration]];
                [[topConstraint animator] setConstant:titleBarHeight - barHeight];
            }
            completionHandler:^{
                [findBar removeFromSuperview];
                [newTopConstraint setActive:YES];
                [mainWindow recalculateKeyViewLoop];
                
                mwcFlags.isAnimatingFindBar = NO;
            }];
    } else {
        [findBar removeFromSuperview];
        [newTopConstraint setActive:YES];
        [contentView layoutSubtreeIfNeeded];
        [mainWindow recalculateKeyViewLoop];
    }
}

- (void)showFindBar {
    if (findController == nil) {
        findController = [[SKFindController alloc] init];
        [findController setDelegate:self];
    }
    
    NSView *findBar = [findController view];
    NSTextField *findField = [findController findField];
    
    if ([findBar window]) {
        [findField selectText:nil];
    } else if (mwcFlags.isAnimatingFindBar == 0) {
        
        BOOL animate = [NSView shouldShowSlideAnimation];
        NSView *contentView = mwcFlags.fullSizeContent ? pdfContentView : centerContentView;
        CGFloat barHeight = NSHeight([findBar frame]);
        NSArray *constraints = nil;
        
        [contentView addSubview:findBar];
        constraints = @[
            [NSLayoutConstraint constraintWithItem:findBar attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:findBar attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0.0],
            [NSLayoutConstraint constraintWithItem:findBar attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeTop multiplier:1.0 constant:animate ? titleBarHeight - barHeight : titleBarHeight]];
        [NSLayoutConstraint activateConstraints:constraints];
        if (mwcFlags.fullSizeContent == NO) {
            [[contentView constraintWithFirstItem:pdfSplitView firstAttribute:NSLayoutAttributeTop] setActive:NO];
            [[NSLayoutConstraint constraintWithItem:pdfSplitView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:findBar attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0] setActive:YES];
        }
        [contentView layoutSubtreeIfNeeded];
        
        [findController didAddFindBar];
        
        if (mwcFlags.fullSizeContent) {
            NSScrollView *scrollView = [pdfView scrollView];
            [scrollView setAutomaticallyAdjustsContentInsets:NO];
            [scrollView setContentInsets:NSEdgeInsetsMake(barHeight + titleBarHeight, 0.0, 0.0, 0.0)];
            if ([pdfView autoScales] && ([pdfView extendedDisplayMode] & kPDFDisplaySinglePageContinuous) == 0) {
                [pdfView setAutoScales:NO];
                [pdfView setAutoScales:YES];
            }
        }
        
        if (animate) {
            mwcFlags.isAnimatingFindBar = YES;
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                    [context setDuration:0.5 * [context duration]];
                    [[[constraints lastObject] animator] setConstant:titleBarHeight];
                }
                completionHandler:^{
                    [mainWindow recalculateKeyViewLoop];
                    [findField selectText:nil];
                    
                    mwcFlags.isAnimatingFindBar = NO;
                }];
        } else {
            [contentView layoutSubtreeIfNeeded];
            [mainWindow recalculateKeyViewLoop];
            [findField selectText:nil];
        }
    }
}

#define FIND_RESULT_MARGIN 50.0

- (void)selectFindResultHighlight:(NSSelectionDirection)direction {
    [self updateFindResultHighlightsForDirection:direction];
    if (direction == NSDirectSelection && [self interactionMode] == SKPresentationMode && [[NSUserDefaults standardUserDefaults] boolForKey:SKAutoHidePresentationContentsKey])
        [self hideSideWindow];
}

- (void)updateFindResultHighlightsForDirection:(NSSelectionDirection)direction {
    NSArray *findResults = nil;
    
    if (mwcFlags.findPaneState == SKFindPaneStateSingular && [leftSideController.findTableView window])
        findResults = [leftSideController.findArrayController selectedObjects];
    else if (mwcFlags.findPaneState == SKFindPaneStateGrouped && [leftSideController.groupedFindTableView window])
        findResults = [[leftSideController.groupedFindArrayController selectedObjects] valueForKeyPath:@"@unionOfArrays.matches"];
    
    if ([findResults count] == 0) {
        
        [pdfView setHighlightedSelections:nil];
        [self updateRightStatus];
        
    } else {
        
        if (direction == NSDirectSelection) {
            searchResultIndex = 0;
        } else if (direction == NSSelectingNext) {
            if (++searchResultIndex >= (NSInteger)[findResults count])
                searchResultIndex = 0;
        } else if (direction == NSSelectingPrevious) {
            if (--searchResultIndex < 0)
                searchResultIndex = [findResults count] - 1;
        }
    
        PDFSelection *currentSel = [findResults objectAtIndex:searchResultIndex];
        
        if ([currentSel hasCharacters]) {
            PDFPage *page = [currentSel safeFirstPage];
            NSRect rect = NSZeroRect;
            
            for (PDFSelection *sel in findResults) {
                if ([[sel pages] containsObject:page])
                    rect = NSUnionRect(rect, [sel boundsForPage:page]);
            }
            rect = NSIntersectionRect(NSInsetRect(rect, -FIND_RESULT_MARGIN, -FIND_RESULT_MARGIN), [page boundsForBox:kPDFDisplayBoxCropBox]);
            [pdfView goToCurrentPage:page];
            [pdfView goToRect:rect onPage:page];
        }
        
        NSArray *highlights = [[NSArray alloc] initWithArray:findResults copyItems:YES];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        [highlights setValue:[NSColor findHighlightColor] forKey:@"color"];
#pragma clang diagnostic pop
        [pdfView setHighlightedSelections:highlights];
        [highlights release];
        
        if ([currentSel hasCharacters]) {
            [pdfView setCurrentSelection:currentSel animate:YES];
            [[statusBar rightField] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Match %lu of %lu", @"Status message"), (unsigned long)[searchResults indexOfObject:currentSel] + 1, (unsigned long)[self countOfSearchResults]]];
        } else {
            [self updateRightStatus];
        }
        if ([pdfView toolMode] == SKMoveToolMode || [pdfView toolMode] == SKMagnifyToolMode || [pdfView toolMode] == SKSelectToolMode)
            [pdfView setCurrentSelection:nil];
    }
}

#pragma mark PDFDocument delegate

- (void)didMatchString:(PDFSelection *)instance {
    if (mwcFlags.wholeWordSearch) {
        PDFSelection *copy = [[instance copy] autorelease];
        NSString *string = [instance string];
        NSUInteger l = [string length];
        [copy extendSelectionAtEnd:1];
        string = [copy string];
        if ([string length] > l && [[NSCharacterSet letterCharacterSet] characterIsMember:[string characterAtIndex:l]])
            return;
        l = [string length];
        [copy extendSelectionAtStart:1];
        string = [copy string];
        if ([string length] > l && [[NSCharacterSet letterCharacterSet] characterIsMember:[string characterAtIndex:0]])
            return;
    }
    
    PDFPage *page = [instance safeFirstPage];
    // this should never happen, but apparently PDFKit sometimes does return empty matches
    if (page == nil)
        return;
    
    NSUInteger pageIndex = [page pageIndex];
    CGFloat order = [instance boundsOrderForPage:page];
    NSInteger i = [searchResults count];
    while (i-- > 0) {
        PDFSelection *prevResult = [searchResults objectAtIndex:i];
        PDFPage *prevPage = [prevResult safeFirstPage];
        NSUInteger prevIndex = [prevPage pageIndex];
        if (pageIndex > prevIndex || (pageIndex == prevIndex && order >= [prevResult boundsOrderForPage:prevPage]))
            break;
    }
    [searchResults insertObject:instance atIndex:i + 1];
    
    SKGroupedSearchResult *result = nil;
    NSUInteger maxCount = [[groupedSearchResults lastObject] maxCount];
    i = [groupedSearchResults count];
    while (i-- > 0) {
        SKGroupedSearchResult *prevResult = [groupedSearchResults objectAtIndex:i];
        NSUInteger prevIndex = [prevResult pageIndex];
        if (pageIndex >= prevIndex) {
            if (pageIndex == prevIndex)
                result = prevResult;
            break;
        }
    }
    if (result == nil) {
        result = [SKGroupedSearchResult groupedSearchResultWithPage:page maxCount:maxCount];
        [groupedSearchResults insertObject:result atIndex:i + 1];
    }
    [result addMatch:instance];
    
    if ([result count] > maxCount) {
        maxCount = [result count];
        for (result in groupedSearchResults)
            [result setMaxCount:maxCount];
    }
}

- (void)documentDidBeginDocumentFind:(NSNotification *)note {
    [leftSideController applySearchTableHeader:[NSLocalizedString(@"Searching", @"Message in search table header") stringByAppendingEllipsis]];
    [self setSearchResults:nil];
    [self setGroupedSearchResults:nil];
    [statusBar setProgressIndicatorStyle:SKProgressIndicatorStyleDeterminate];
    [[statusBar progressIndicator] setMaxValue:[[note object] pageCount]];
    [[statusBar progressIndicator] setDoubleValue:0.0];
    [[statusBar progressIndicator] startAnimation:self];
    [self willChangeValueForKey:SEARCHRESULTS_KEY];
    [self willChangeValueForKey:GROUPEDSEARCHRESULTS_KEY];
}

- (void)documentDidEndDocumentFind:(NSNotification *)note {
    NSString *header = nil;
    if ([searchResults count] == 1)
        header = NSLocalizedString(@"1 Result", @"Message in search table header");
    else
        header = [NSString stringWithFormat:NSLocalizedString(@"%ld Results", @"Message in search table header"), (long)[searchResults count]];
    [leftSideController applySearchTableHeader:header];
    mwcFlags.updatingFindResults = 1;
    [self didChangeValueForKey:GROUPEDSEARCHRESULTS_KEY];
    [self didChangeValueForKey:SEARCHRESULTS_KEY];
    mwcFlags.updatingFindResults = 0;
    [[statusBar progressIndicator] stopAnimation:self];
    [statusBar setProgressIndicatorStyle:SKProgressIndicatorStyleNone];
}

- (void)documentDidEndPageFind:(NSNotification *)note {
    NSNumber *pageIndex = [[note userInfo] objectForKey:@"PDFDocumentPageIndex"];
    [[statusBar progressIndicator] setDoubleValue:[pageIndex doubleValue] + 1.0];
    if ([pageIndex unsignedIntegerValue] % 50 == 0) {
        mwcFlags.updatingFindResults = 1;
        [self didChangeValueForKey:GROUPEDSEARCHRESULTS_KEY];
        [self didChangeValueForKey:SEARCHRESULTS_KEY];
        mwcFlags.updatingFindResults = 0;
        [self willChangeValueForKey:SEARCHRESULTS_KEY];
        [self willChangeValueForKey:GROUPEDSEARCHRESULTS_KEY];
    }
}

- (void)documentDidUnlockDelayed {
    NSDictionary *settings = [self interactionMode] == SKFullScreenMode ? [[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultFullScreenPDFDisplaySettingsKey] : nil;
    if ([settings count] == 0)
        settings = [savedNormalSetup objectForKey:AUTOSCALES_KEY] ? savedNormalSetup : [[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultPDFDisplaySettingsKey];
    [self applyPDFSettings:settings rewind:NO];
    
    NSNumber *pageIndexNumber = [savedNormalSetup objectForKey:PAGEINDEX_KEY];
    NSUInteger pageIndex = pageIndexNumber ? [pageIndexNumber unsignedIntegerValue] : NSNotFound;
    if (pageIndex != NSNotFound) {
        NSString *pointString = [savedNormalSetup objectForKey:SCROLLPOINT_KEY];
        if (pointString)
            [pdfView goToPageAtIndex:pageIndex point:NSPointFromString(pointString)];
        else
            [pdfView goToCurrentPage:[[pdfView document] pageAtIndex:pageIndex]];
        [lastViewedPages setCount:0];
        [lastViewedPages addPointer:(void *)pageIndex];
        [pdfView resetHistory];
    }
    
    [self applyChangedCropBoxes:[savedNormalSetup objectForKey:CROPBOXES_KEY]];
    
    NSArray *snapshotSetups = [savedNormalSetup objectForKey:SNAPSHOTS_KEY];
    if ([snapshotSetups count])
        [self showSnapshotsWithSetups:snapshotSetups];
    
    if ([self interactionMode] == SKNormalMode)
        [savedNormalSetup removeAllObjects];
    
    // somehow the password field remains first responder after it has been removed
    if ([[[self window] firstResponder] isKindOfClass:[NSTextView class]] && [[(NSTextView *)[[self window] firstResponder] delegate] isKindOfClass:[NSSecureTextField class]] )
        [[self window] makeFirstResponder:[self pdfView]];
}

- (void)documentDidUnlock:(NSNotification *)notification {
    if (placeholderPdfDocument && [[self pdfDocument] allowsNotes]) {
        PDFDocument *pdfDoc = [self pdfDocument];
        NSMutableIndexSet *pageIndexes = [NSMutableIndexSet indexSet];
        for (PDFAnnotation *note in [self notes]) {
            PDFPage *page = [note page];
            NSUInteger pageIndex = [page pageIndex];
            if ([page document] != pdfDoc) {
                [page removeAnnotation:note];
                [[pdfDoc pageAtIndex:[page pageIndex]] addAnnotation:note];
                [pageIndexes addIndex:pageIndex];
            }
        }
        SKDESTROY(placeholderPdfDocument);
        [pdfView requiresDisplay];
        [rightSideController.noteArrayController rearrangeObjects];
        if ([[savedNormalSetup objectForKey:LOCKED_KEY] boolValue] == NO) {
            [rightSideController.noteOutlineView reloadData];
            [self updateThumbnailsAtPageIndexes:pageIndexes];
        }
    }
    
    if (widgets == nil)
        [self makeWidgets];
    if (placeholderWidgetProperties) {
        [[[self document] undoManager] disableUndoRegistration];
        [self changeWidgetsFromDictionaries:placeholderWidgetProperties];
        [[[self document] undoManager] enableUndoRegistration];
        SKDESTROY(placeholderWidgetProperties);
    }
    
    if ([[savedNormalSetup objectForKey:LOCKED_KEY] boolValue]) {
        [self updatePageLabelsAndOutlineForExpansionState:nil];
        
        // when the PDF was locked, PDFView resets the display settings, so we need to reapply them, however if we don't delay it's reset again immediately
        if ([self interactionMode] == SKNormalMode || [self interactionMode] == SKFullScreenMode)
            [self performSelector:@selector(documentDidUnlockDelayed) withObject:nil afterDelay:0.0];
    }
}

enum { SKOptionAsk = -1, SKOptionNever = 0, SKOptionAlways = 1 };

- (void)document:(PDFDocument *)aDocument didUnlockWithPassword:(NSString *)password {
    if ([aDocument isLocked])
        return;
    
    NSInteger saveOption = [[NSUserDefaults standardUserDefaults] integerForKey:SKSavePasswordOptionKey];
    if (saveOption == SKOptionAlways) {
        [[self document] savePasswordInKeychain:password];
    } else if (saveOption == SKOptionAsk) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Remember Password?", @"Message in alert dialog"), nil]];
        [alert setInformativeText:NSLocalizedString(@"Do you want to save this password in your Keychain?", @"Informative text in alert dialog")];
        [alert addButtonWithTitle:NSLocalizedString(@"Yes", @"Button title")];
        [alert addButtonWithTitle:NSLocalizedString(@"No", @"Button title")];
        NSWindow *window = [self window];
        if ([window attachedSheet] == nil)
            [alert beginSheetModalForWindow:window completionHandler:^(NSInteger returnCode){
                if (returnCode == NSAlertFirstButtonReturn)
                    [[self document] savePasswordInKeychain:password];
            }];
        else if (NSAlertFirstButtonReturn == [alert runModal])
            [[self document] savePasswordInKeychain:password];
    }
}

#pragma mark PDFDocument notifications

- (void)handlePageBoundsDidChangeNotification:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    PDFPage *page = [info objectForKey:SKPDFPagePageKey];
    BOOL isCrop = [[info objectForKey:SKPDFPageActionKey] isEqualToString:SKPDFPageActionCrop];
    BOOL displayChanged = isCrop == NO || [pdfView displayBox] == kPDFDisplayBoxCropBox;
        
    if (displayChanged)
        [pdfView layoutDocumentView];
    if (page) {
        NSUInteger idx = [page pageIndex];
        for (SKSnapshotWindowController *wc in snapshots) {
            if ([wc isPageVisible:page]) {
                [self snapshotNeedsUpdate:wc];
                [wc redisplay];
            }
        }
        if (displayChanged)
            [self updateThumbnailAtPageIndex:idx];
    } else {
        [snapshots makeObjectsPerformSelector:@selector(redisplay)];
        [self allSnapshotsNeedUpdate];
        if (displayChanged)
            [self allThumbnailsNeedUpdate];
    }
    
    [secondaryPdfView requiresDisplay];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayPageBoundsKey])
        [self updateRightStatus];
    
    if (isCrop)
        mwcFlags.hasCropped = 1;
}

- (void)handleDocumentBeginWrite:(NSNotification *)notification {
    [self beginProgressSheetWithMessage:[NSLocalizedString(@"Exporting PDF", @"Message for progress sheet") stringByAppendingEllipsis] maxValue:[[pdfView document] pageCount]];
}

- (void)handleDocumentEndWrite:(NSNotification *)notification {
    [self dismissProgressSheet];
}

- (void)handleDocumentEndPageWrite:(NSNotification *)notification {
    [self incrementProgressSheet];
}

- (void)registerForDocumentNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    PDFDocument *pdfDoc = [pdfView document];
    [nc addObserver:self selector:@selector(handleDocumentBeginWrite:) 
                             name:PDFDocumentDidBeginWriteNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleDocumentEndWrite:) 
                             name:PDFDocumentDidEndWriteNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handleDocumentEndPageWrite:) 
                             name:PDFDocumentDidEndPageWriteNotification object:pdfDoc];
    [nc addObserver:self selector:@selector(handlePageBoundsDidChangeNotification:) 
                             name:SKPDFPageBoundsDidChangeNotification object:pdfDoc];
}

- (void)unregisterForDocumentNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    PDFDocument *pdfDoc = [pdfView document];
    [nc removeObserver:self name:PDFDocumentDidBeginWriteNotification object:pdfDoc];
    [nc removeObserver:self name:PDFDocumentDidEndWriteNotification object:pdfDoc];
    [nc removeObserver:self name:PDFDocumentDidEndPageWriteNotification object:pdfDoc];
    [nc removeObserver:self name:SKPDFPageBoundsDidChangeNotification object:pdfDoc];
}

#pragma mark Subwindows

- (void)showSnapshotAtPageNumber:(NSInteger)pageNum forRect:(NSRect)rect scaleFactor:(CGFloat)scaleFactor autoFits:(BOOL)autoFits {
    SKSnapshotWindowController *swc = [[SKSnapshotWindowController alloc] init];
    
    [swc setDelegate:self];
    
    [swc setPdfDocument:[pdfView document]
         goToPageNumber:pageNum
                   rect:rect
            scaleFactor:scaleFactor
               autoFits:autoFits];
    
    [swc setForceOnTop:[self interactionMode] != SKNormalMode];
    
    [[self document] addWindowController:swc];
    [swc release];
}

- (void)showSnapshotsWithSetups:(NSArray *)setups {
    NSUInteger i, iMax = [setups count];
    
    for (i = 0; i < iMax; i++) {
        NSDictionary *setup  = [setups objectAtIndex:i];
        
        SKSnapshotWindowController *swc = [[SKSnapshotWindowController alloc] init];
        
        [swc setDelegate:self];
        
        [swc setPdfDocument:[pdfView document] setup:setup];
        
        [swc setForceOnTop:[self interactionMode] != SKNormalMode];
        
        [[self document] addWindowController:swc];
        
        [swc release];
    }
}

- (void)snapshotController:(SKSnapshotWindowController *)controller didFinishSetup:(SKSnapshotOpenType)openType {
    NSImage *image = [controller thumbnailWithSize:snapshotCacheSize];
    
    [image setAccessibilityDescription:[NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), [controller pageLabel]]];
    [controller setThumbnail:image];
    
    if (openType == SKSnapshotOpenFromSetup) {
        [[self mutableArrayValueForKey:SNAPSHOTS_KEY] addObject:controller];
        [rightSideController.snapshotTableView reloadData];
    } else {
        if (openType == SKSnapshotOpenNormal) {
            [rightSideController.snapshotTableView beginUpdates];
            [[self mutableArrayValueForKey:SNAPSHOTS_KEY] addObject:controller];
            NSUInteger row = [[rightSideController.snapshotArrayController arrangedObjects] indexOfObject:controller];
            if (row != NSNotFound) {
                NSTableViewAnimationOptions options = NSTableViewAnimationEffectGap | NSTableViewAnimationSlideDown;
                if ([self rightSidePaneIsOpen] == NO || [self rightSidePaneState] != SKSidePaneStateSnapshot || [NSView shouldShowSlideAnimation] == NO)
                    options = NSTableViewAnimationEffectNone;
                [rightSideController.snapshotTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:options];
            }
            [rightSideController.snapshotTableView endUpdates];
        }
        [self setRecentInfoNeedsUpdate:YES];
    }
}

- (void)snapshotControllerWillClose:(SKSnapshotWindowController *)controller {
    if (controller == presentationPreview) {
        [presentationPreview autorelease];
        presentationPreview = nil;
    } else {
        [rightSideController.snapshotTableView beginUpdates];
        NSUInteger row = [[rightSideController.snapshotArrayController arrangedObjects] indexOfObject:controller];
        if (row != NSNotFound) {
            NSTableViewAnimationOptions options = NSTableViewAnimationEffectGap | NSTableViewAnimationSlideUp;
            if ([self rightSidePaneIsOpen] == NO || [self rightSidePaneState] != SKSidePaneStateSnapshot || [NSView shouldShowSlideAnimation] == NO)
                options = NSTableViewAnimationEffectNone;
            [rightSideController.snapshotTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:options];
        }
        [[self mutableArrayValueForKey:SNAPSHOTS_KEY] removeObject:controller];
        [rightSideController.snapshotTableView endUpdates];
        [self setRecentInfoNeedsUpdate:YES];
    }
}

- (void)snapshotControllerDidChange:(SKSnapshotWindowController *)controller {
    if (controller != presentationPreview) {
        [self snapshotNeedsUpdate:controller];
        [rightSideController.snapshotArrayController rearrangeObjects];
        [rightSideController.snapshotTableView reloadData];
        [self setRecentInfoNeedsUpdate:YES];
    }
}

- (void)snapshotControllerDidMove:(SKSnapshotWindowController *)controller {
    if (controller != presentationPreview) {
        [self setRecentInfoNeedsUpdate:YES];
    }
}

- (NSRect)snapshotController:(SKSnapshotWindowController *)controller miniaturizedRect:(BOOL)isMiniaturize {
    if (controller == presentationPreview)
        return NSZeroRect;
    NSRect rect = NSZeroRect;
    if ([self hasOverview]) {
        rect = [[self window] frame];
        rect.origin.x = NSMaxX(rect) - 1.0;
        rect.origin.y = floor(NSMidY(rect));
        rect.size.width = rect.size.height = 1.0;
    } else {
        NSUInteger row = [[rightSideController.snapshotArrayController arrangedObjects] indexOfObject:controller];
        BOOL shouldReopenRightSidePane = NO;
        if (isMiniaturize && [self interactionMode] != SKPresentationMode) {
            if ([self rightSidePaneIsOpen] == NO) {
                [[self window] disableFlushWindow];
                [self toggleRightSidePane:nil];
                shouldReopenRightSidePane = YES;
            }
            [self setRightSidePaneState:SKSidePaneStateSnapshot];
            if (row != NSNotFound)
                [rightSideController.snapshotTableView scrollRowToVisible:row];
        }
        if (row != NSNotFound) {
            rect = [rightSideController.snapshotTableView frameOfCellAtColumn:0 row:row];
        } else {
            rect.origin = SKBottomLeftPoint([rightSideController.snapshotTableView visibleRect]);
            rect.size.width = rect.size.height = 1.0;
        }
        rect = [rightSideController.snapshotTableView convertRectToScreen:rect];
        if (shouldReopenRightSidePane) {
            [self toggleRightSidePane:nil];
            [[self window] enableFlushWindow];
            [self toggleRightSidePane:self];
        }
    }
    [self setRecentInfoNeedsUpdate:YES];
    return rect;
}

- (void)snapshotController:(SKSnapshotWindowController *)controller goToDestination:(PDFDestination *)destination {
    [pdfView goToDestination:destination];
}

- (void)showNote:(PDFAnnotation *)annotation {
    NSWindowController *wc = [self windowControllerForNote:annotation];
    if (wc == nil) {
        wc = [[SKNoteWindowController alloc] initWithNote:annotation];
        [(SKNoteWindowController *)wc setForceOnTop:[self interactionMode] != SKNormalMode];
        [[self document] addWindowController:wc];
        [wc release];
    }
    [wc showWindow:self];
}

- (NSWindowController *)windowControllerForNote:(PDFAnnotation *)annotation {
    for (id wc in [[self document] windowControllers]) {
        if ([wc isNoteWindowController] && [[wc note] isEqual:annotation])
            return wc;
    }
    return nil;
}

#pragma mark Observer registration

- (void)registerAsObserver {
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeys:
        @[SKBackgroundColorKey, SKFullScreenBackgroundColorKey,
                                  SKDarkBackgroundColorKey, SKDarkFullScreenBackgroundColorKey,
                                  SKThumbnailSizeKey, SKSnapshotThumbnailSizeKey,
                                  SKShouldAntiAliasKey, SKInterpolationQualityKey, SKGreekingThresholdKey,
                                  SKTableFontSizeKey]
        context:&SKMainWindowDefaultsObservationContext];
    if (RUNNING_AFTER(10_13))
        [NSApp addObserver:self forKeyPath:@"effectiveAppearance" options:0 context:&SKMainWindowAppObservationContext];
    if (mwcFlags.fullSizeContent)
        [[self window] addObserver:self forKeyPath:@"contentLayoutRect" options:0 context:&SKMainWindowContentLayoutObservationContext];
}

- (void)unregisterAsObserver {
    @try {
        [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeys:
         @[SKBackgroundColorKey, SKFullScreenBackgroundColorKey,
                                   SKDarkBackgroundColorKey, SKDarkFullScreenBackgroundColorKey,
                                   SKThumbnailSizeKey, SKSnapshotThumbnailSizeKey,
                                   SKShouldAntiAliasKey, SKInterpolationQualityKey, SKGreekingThresholdKey,
          SKTableFontSizeKey] context:&SKMainWindowDefaultsObservationContext];
    }
    @catch (id e) {}
    if (RUNNING_AFTER(10_13)) {
        @try { [NSApp removeObserver:self forKeyPath:@"effectiveAppearance" context:&SKMainWindowAppObservationContext]; }
        @catch (id e) {}
    }
    if (mwcFlags.fullSizeContent) {
        @try { [mainWindow removeObserver:self forKeyPath:@"contentLayoutRect" context:&SKMainWindowContentLayoutObservationContext]; }
        @catch (id e) {}
    }
}

#pragma mark Undo

- (void)startObservingNotes:(NSArray *)newNotes {
    // Each note can have a different set of properties that need to be observed.
    for (PDFAnnotation *note in newNotes) {
        for (NSString *key in [note keysForValuesToObserveForUndo]) {
            // We use NSKeyValueObservingOptionOld because when something changes we want to record the old value, which is what has to be set in the undo operation. We use NSKeyValueObservingOptionNew because we compare the new value against the old value in an attempt to ignore changes that aren't really changes.
            [note addObserver:self forKeyPath:key options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&SKPDFAnnotationPropertiesObservationContext];
        }
    }
}

- (void)stopObservingNotes:(NSArray *)oldNotes {
    // Do the opposite of what's done in -startObservingNotes:.
    for (PDFAnnotation *note in oldNotes) {
        for (NSString *key in [note keysForValuesToObserveForUndo])
            [note removeObserver:self forKeyPath:key context:&SKPDFAnnotationPropertiesObservationContext];
    }
}

- (void)setNoteProperties:(NSMapTable *)propertiesPerNote {
    // The passed-in dictionary is keyed by note...
    for (PDFAnnotation *note in propertiesPerNote) {
        // ...with values that are dictionaries of properties, keyed by key-value coding key.
        NSDictionary *noteProperties = [propertiesPerNote objectForKey:note];
        // Use a relatively unpopular method. Here we're effectively "casting" a key path to a key (see how these dictionaries get built in -observeValueForKeyPath:ofObject:change:context:). It had better really be a key or things will get confused. For example, this is one of the things that would need updating if -[SKTNote keysForValuesToObserveForUndo] someday becomes -[SKTNote keyPathsForValuesToObserveForUndo].
        [note setValuesForKeysWithDictionary:noteProperties];
    }
}

- (void)observeUndoManagerCheckpoint:(NSNotification *)notification {
    // Start the coalescing of note property changes over.
    [undoGroupOldPropertiesPerNote release];
    undoGroupOldPropertiesPerNote = nil;
}

#pragma mark KVO

- (BOOL)notesNeedReloadForKey:(NSString *)key {
    if ([key isEqualToString:SKNPDFAnnotationBoundsKey] ||
        [key isEqualToString:[[[rightSideController.noteArrayController sortDescriptors] firstObject] key]])
        return YES;
    if ([[rightSideController.searchField stringValue] length])
        return [key isEqualToString:SKNPDFAnnotationStringKey] || [key isEqualToString:SKNPDFAnnotationTextKey];
    return NO;
}

- (void)reloadNotesTable {
    [rightSideController.noteArrayController rearrangeObjects];
    [rightSideController.noteOutlineView reloadData];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKMainWindowDefaultsObservationContext) {
        
        // A default value that we are observing has changed
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:SKBackgroundColorKey] || [key isEqualToString:SKDarkBackgroundColorKey]) {
            if ([self interactionMode] == SKNormalMode) {
                NSColor *color = [PDFView defaultBackgroundColor];
                [pdfView setBackgroundColor:color];
                [secondaryPdfView setBackgroundColor:color];
            }
        } else if ([key isEqualToString:SKFullScreenBackgroundColorKey] || [key isEqualToString:SKDarkFullScreenBackgroundColorKey]) {
            if ([self interactionMode] == SKFullScreenMode) {
                NSColor *color = [PDFView defaultFullScreenBackgroundColor];
                [pdfView setBackgroundColor:color];
                [secondaryPdfView setBackgroundColor:color];
            }
        } else if ([key isEqualToString:SKThumbnailSizeKey]) {
            [self resetThumbnailSizeIfNeeded];
            [leftSideController.thumbnailTableView noteHeightOfRowsChangedAnimating:YES];
        } else if ([key isEqualToString:SKSnapshotThumbnailSizeKey]) {
            [self resetSnapshotSizeIfNeeded];
            [rightSideController.snapshotTableView noteHeightOfRowsChangedAnimating:YES];
        } else if ([key isEqualToString:SKShouldAntiAliasKey]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [pdfView setShouldAntiAlias:[[NSUserDefaults standardUserDefaults] boolForKey:SKShouldAntiAliasKey]];
            [secondaryPdfView setShouldAntiAlias:[[NSUserDefaults standardUserDefaults] boolForKey:SKShouldAntiAliasKey]];
#pragma clang diagnostic pop
            [pdfView requiresDisplay];
            [secondaryPdfView requiresDisplay];
        } else if ([key isEqualToString:SKInterpolationQualityKey]) {
            [pdfView setInterpolationQuality:[[NSUserDefaults standardUserDefaults] integerForKey:SKInterpolationQualityKey]];
            [secondaryPdfView setInterpolationQuality:[[NSUserDefaults standardUserDefaults] integerForKey:SKInterpolationQualityKey]];
            [pdfView requiresDisplay];
            [secondaryPdfView requiresDisplay];
            [self allThumbnailsNeedUpdate];
        } else if ([key isEqualToString:SKGreekingThresholdKey] && RUNNING_BEFORE(10_14)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [pdfView setGreekingThreshold:[[NSUserDefaults standardUserDefaults] floatForKey:SKGreekingThresholdKey]];
            [secondaryPdfView setGreekingThreshold:[[NSUserDefaults standardUserDefaults] floatForKey:SKGreekingThresholdKey]];
#pragma clang diagnostic pop
        } else if ([key isEqualToString:SKTableFontSizeKey]) {
            [self updateTableFont];
            [self updatePageColumnWidthForTableViews:[NSArray arrayWithObjects:leftSideController.tocOutlineView, rightSideController.noteOutlineView, leftSideController.findTableView, leftSideController.groupedFindTableView, nil]];
        }
        
    } else if (context == &SKMainWindowAppObservationContext) {
        
        NSColor *backgroundColor = nil;
        switch (interactionMode) {
            case SKNormalMode:
                backgroundColor = [PDFView defaultBackgroundColor];
                break;
            case SKFullScreenMode:
                backgroundColor = [PDFView defaultFullScreenBackgroundColor];
                break;
            default:
                return;
        }
        [pdfView setBackgroundColor:backgroundColor];
        [secondaryPdfView setBackgroundColor:backgroundColor];
        
    } else if (context == &SKMainWindowContentLayoutObservationContext) {
        
        CGFloat titleHeight = NSHeight([mainWindow frame]) - NSHeight([mainWindow contentLayoutRect]);
        if (fabs(titleHeight - titleBarHeight) > 0.0) {
            titleBarHeight = titleHeight;
            [rightSideController setTopInset:titleBarHeight];
            if ([self interactionMode] != SKPresentationMode || [self leftSidePaneIsOpen] == NO)
                [leftSideController setTopInset:titleBarHeight];
            if ([[findController view] window]) {
                [[[[findController view] superview] constraintWithFirstItem:[findController view] firstAttribute:NSLayoutAttributeTop] setConstant:titleBarHeight];
                if ([self interactionMode] != SKPresentationMode)
                    [[pdfView scrollView] setContentInsets:NSEdgeInsetsMake(NSHeight([[findController view] frame]) + titleBarHeight, 0.0, 0.0, 0.0)];
            }
        }
        
    } else if (context == &SKMainWindowThumbnailSelectionObservationContext) {
        
        NSIndexSet *indexes = [overviewView selectionIndexes];
        if ([indexes count] == 1 && mwcFlags.updatingThumbnailSelection == 0) {
            NSUInteger pageIndex = [indexes firstIndex];
            if ([[pdfView currentPage] pageIndex] != pageIndex)
                [pdfView goToCurrentPage:[[pdfView document] pageAtIndex:pageIndex]];
        } else if ([indexes count] == 0) {
            mwcFlags.updatingThumbnailSelection = 1;
            [overviewView setSelectionIndexes:[NSIndexSet indexSetWithIndex:[[pdfView currentPage] pageIndex]]];
            mwcFlags.updatingThumbnailSelection = 0;
        }
        
    } else if (context == &SKPDFAnnotationPropertiesObservationContext) {
        
        // The value of some note's property has changed
        PDFAnnotation *note = (PDFAnnotation *)object;
        // Ignore changes that aren't really changes.
        // How much processor time does this memory optimization cost? We don't know, because we haven't measured it. The use of NSKeyValueObservingOptionNew in -startObservingNotes:, which makes NSKeyValueChangeNewKey entries appear in change dictionaries, definitely costs something when KVO notifications are sent (it costs virtually nothing at observer registration time). Regardless, it's probably a good idea to do simple memory optimizations like this as they're discovered and debug just enough to confirm that they're saving the expected memory (and not introducing bugs). Later on it will be easier to test for good responsiveness and sample to hunt down processor time problems than it will be to figure out where all the darn memory went when your app turns out to be notably RAM-hungry (and therefore slowing down _other_ apps on your user's computers too, if the problem is bad enough to cause paging).
        // Is this a premature optimization? No. Leaving out this very simple check, because we're worried about the processor time cost of using NSKeyValueChangeNewKey, would be a premature optimization.
        // We should be adding undo for nil values also. I'm not sure if KVO does this automatically. Note that -setValuesForKeysWithDictionary: converts NSNull back to nil.
        id newValue = [change objectForKey:NSKeyValueChangeNewKey] ?: [NSNull null];
        id oldValue = [change objectForKey:NSKeyValueChangeOldKey] ?: [NSNull null];
        // All values are suppsed to be true value objects that should be compared with isEqual:
        if ([newValue isEqual:oldValue] == NO) {
            
            // Is this the first observed note change in the current undo group?
            NSUndoManager *undoManager = [[self document] undoManager];
            BOOL isUndoOrRedo = ([undoManager isUndoing] || [undoManager isRedoing]);
            
            if ([undoManager isUndoRegistrationEnabled] == NO)
                return;
            
            if (undoGroupOldPropertiesPerNote == nil) {
                // We haven't recorded changes for any notes at all since the last undo manager checkpoint. Get ready to start collecting them. We don't want to copy the PDFAnnotations though.
                undoGroupOldPropertiesPerNote = [[NSMapTable weakToStrongObjectsMapTable] retain];
                // Register an undo operation for any note property changes that are going to be coalesced between now and the next invocation of -observeUndoManagerCheckpoint:.
                [undoManager registerUndoWithTarget:self selector:@selector(setNoteProperties:) object:undoGroupOldPropertiesPerNote];
                // Don't set the undo action name during undoing and redoing
                if (isUndoOrRedo == NO)
                    [undoManager setActionName:NSLocalizedString(@"Edit Note", @"Undo action name")];
            }

            // Find the dictionary in which we're recording the old values of properties for the changed note
            NSMutableDictionary *oldNoteProperties = [undoGroupOldPropertiesPerNote objectForKey:note];
            if (oldNoteProperties == nil) {
                // We have to create a dictionary to hold old values for the changed note
                oldNoteProperties = [[NSMutableDictionary alloc] init];
                // -setValue:forKey: copies, even if the callback doesn't, so we need to use CF functions
                [undoGroupOldPropertiesPerNote setObject:oldNoteProperties forKey:note];
                [oldNoteProperties release];
                // set the mod date here, need to do that only once for each note for a real user action
                if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisableModificationDateKey] == NO && isUndoOrRedo == NO && [keyPath isEqualToString:SKNPDFAnnotationModificationDateKey] == NO && [note isSkimNote])
                    [note setModificationDate:[NSDate date]];
            }
            
            // Record the old value for the changed property, unless an older value has already been recorded for the current undo group. Here we're "casting" a KVC key path to a dictionary key, but that should be OK. -[NSMutableDictionary setObject:forKey:] doesn't know the difference.
            if ([oldNoteProperties objectForKey:keyPath] == nil)
                [oldNoteProperties setObject:oldValue forKey:keyPath];
            
            if ([note isSkimNote] == NO)
                return;
            
            // Update the UI, we should always do that unless the value did not really change or we're just changing the mod date or user name
            if ([keyPath isEqualToString:SKNPDFAnnotationModificationDateKey] == NO && [keyPath isEqualToString:SKNPDFAnnotationUserNameKey] == NO) {
                PDFPage *page = [note page];
                NSRect oldRect = NSZeroRect;
                if ([keyPath isEqualToString:SKNPDFAnnotationBoundsKey] && [oldValue isEqual:[NSNull null]] == NO) {
                    oldRect = [note displayRectForBounds:[oldValue rectValue] lineWidth:[note lineWidth]];
                } else if ([keyPath isEqualToString:SKNPDFAnnotationBorderKey] && [oldValue isEqual:[NSNull null]] == NO) {
                    if ([oldValue lineWidth] > [note lineWidth])
                        oldRect = [note displayRectForBounds:[note bounds] lineWidth:[oldValue lineWidth]];
                }
                
                [self updateThumbnailAtPageIndex:[note pageIndex]];
                
                for (SKSnapshotWindowController *wc in snapshots) {
                    if ([wc isPageVisible:[note page]]) {
                        [self snapshotNeedsUpdate:wc];
                        [wc setNeedsDisplayForAnnotation:note onPage:page];
                        if (NSIsEmptyRect(oldRect) == NO)
                            [wc setNeedsDisplayInRect:oldRect ofPage:page];
                    }
                }
                
                [pdfView setNeedsDisplayForAnnotation:note];
                [secondaryPdfView setNeedsDisplayForAnnotation:note onPage:page];
                if (NSIsEmptyRect(oldRect) == NO) {
                    if ([note isResizable]) {
                        CGFloat margin = 4.0 / [pdfView scaleFactor];
                        oldRect = NSInsetRect(oldRect, -margin, -margin);
                    }
                    [pdfView setNeedsDisplayInRect:oldRect ofPage:page];
                    [secondaryPdfView setNeedsDisplayInRect:oldRect ofPage:page];
                }
                
                if ([keyPath isEqualToString:SKNPDFAnnotationBoundsKey]) {
                    if ([note isNote]) {
                        [pdfView annotationsChangedOnPage:[note page]];
                        [pdfView resetPDFToolTipRects];
                    }
                    
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKDisplayNoteBoundsKey]) {
                        [self updateRightStatus];
                    }
                }
            }
            
            if (mwcFlags.autoResizeNoteRows) {
                if ([keyPath isEqualToString:SKNPDFAnnotationStringKey])
                    NSMapRemove(rowHeights, note);
                if ([keyPath isEqualToString:SKNPDFAnnotationTextKey])
                    NSMapRemove(rowHeights, [note noteText]);
            }
            if ([self notesNeedReloadForKey:keyPath]) {
                [self performSelectorOnce:@selector(reloadNotesTable) afterDelay:0.0];
            } else if ([keyPath isEqualToString:SKNPDFAnnotationStringKey] ||
                       [keyPath isEqualToString:SKNPDFAnnotationTextKey]) {
                [rightSideController.noteOutlineView reloadTypeSelectStrings];
                if (mwcFlags.autoResizeNoteRows) {
                    NSInteger row = [rightSideController.noteOutlineView rowForItem:[keyPath isEqualToString:SKNPDFAnnotationStringKey] ? note : [note noteText]];
                    if (row != -1)
                        [rightSideController.noteOutlineView noteHeightOfRowChanged:row animating:YES];
                }
            }
            
            // update the various panels if necessary
            if ([[self window] isMainWindow] && [note isEqual:[pdfView currentAnnotation]]) {
                if (mwcFlags.updatingColor == 0 && ([keyPath isEqualToString:SKNPDFAnnotationColorKey] || [keyPath isEqualToString:SKNPDFAnnotationInteriorColorKey])) {
                    mwcFlags.updatingColor = 1;
                    [[NSColorPanel sharedColorPanel] setColor:[note color]];
                    mwcFlags.updatingColor = 0;
                }
                if (mwcFlags.updatingFont == 0 && ([keyPath isEqualToString:SKNPDFAnnotationFontKey])) {
                    mwcFlags.updatingFont = 1;
                    [[NSFontManager sharedFontManager] setSelectedFont:[(PDFAnnotationFreeText *)note font] isMultiple:NO];
                    mwcFlags.updatingFont = 0;
                }
                if (mwcFlags.updatingFontAttributes == 0 && ([keyPath isEqualToString:SKNPDFAnnotationFontColorKey])) {
                    mwcFlags.updatingFontAttributes = 1;
                    [[NSFontManager sharedFontManager] setSelectedAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[(PDFAnnotationFreeText *)note fontColor], NSForegroundColorAttributeName, nil] isMultiple:NO];
                    mwcFlags.updatingFontAttributes = 0;
                }
                if (mwcFlags.updatingLine == 0 && ([keyPath isEqualToString:SKNPDFAnnotationBorderKey] || [keyPath isEqualToString:SKNPDFAnnotationStartLineStyleKey] || [keyPath isEqualToString:SKNPDFAnnotationEndLineStyleKey])) {
                    mwcFlags.updatingLine = 1;
                    [[SKLineInspector sharedLineInspector] setAnnotationStyle:note];
                    mwcFlags.updatingLine = 0;
                }
            }
        }

    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Outline

- (void)updateOutlineSelection{

	// Skip out if this PDF has no outline.
	if ([[pdfView document] outlineRoot] == nil || mwcFlags.updatingOutlineSelection)
		return;
	
	// Get index of current page.
	NSUInteger pageIndex = [[pdfView currentPage] pageIndex];
    
	// Test that the current selection is still valid.
	NSInteger row = [leftSideController.tocOutlineView selectedRow];
    if (row == -1 || [[[leftSideController.tocOutlineView itemAtRow:row] page] pageIndex] != pageIndex) {
        // Get the outline row that contains the current page
        NSInteger numRows = [leftSideController.tocOutlineView numberOfRows];
        for (row = 0; row < numRows; row++) {
            // Get the page for the given row....
            PDFPage *page = [[leftSideController.tocOutlineView itemAtRow:row] page];
            if (page == nil) {
                continue;
            } else if ([page pageIndex] == pageIndex) {
                break;
            } else if ([page pageIndex] > pageIndex) {
                if (row > 0) --row;
                break;	
            }
        }
        if (row == numRows)
            row--;
        if (row != -1) {
            mwcFlags.updatingOutlineSelection = 1;
            [leftSideController.tocOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            mwcFlags.updatingOutlineSelection = 0;
        }
    }
}

- (BOOL)isOutlineExpanded:(PDFOutline *)outline {
    if (-1 == [leftSideController.tocOutlineView rowForItem:outline])
        return NO;
    return [leftSideController.tocOutlineView isItemExpanded:outline];
}

- (void)setExpanded:(BOOL)flag forOutline:(PDFOutline *)outline {
    if ([self isOutlineExpanded:outline] == flag)
        return;
    if (flag) {
        PDFOutline *parent = [outline parent];
        if ([parent parent])
            [self setExpanded:YES forOutline:parent];
        [leftSideController.tocOutlineView expandItem:outline];
    } else {
        [leftSideController.tocOutlineView collapseItem:outline];
    }
}

#pragma mark Thumbnails

- (PDFPage *)pageForThumbnail:(SKThumbnail *)thumbnail {
    return [[pdfView document] pageAtIndex:[thumbnail pageIndex]];
}

- (BOOL)generateImageForThumbnail:(SKThumbnail *)thumbnail {
    if ([[pdfView document] isLocked])
        return NO;
    
    BOOL isScrolling = ([(SKScroller *)[leftSideController.thumbnailTableView.enclosingScrollView verticalScroller] isScrolling] || [[presentationSheetController verticalScroller] isScrolling]);
    
    if (RUNNING_BEFORE(10_12) && isScrolling)
        return NO;
    
    PDFPage *page = [self pageForThumbnail:thumbnail];
    SKReadingBar *readingBar = [[[pdfView readingBar] page] isEqual:page] ? [pdfView readingBar] : nil;
    PDFDisplayBox box = [pdfView displayBox];
    dispatch_queue_t queue = RUNNING_AFTER(10_11) ? dispatch_get_global_queue(isScrolling ? DISPATCH_QUEUE_PRIORITY_LOW : DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) : dispatch_get_main_queue();
    
    dispatch_async(queue, ^{
        NSImage *image = [page thumbnailWithSize:thumbnailCacheSize forBox:box readingBar:readingBar];
        [image setAccessibilityDescription:[NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), [page displayLabel]]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSUInteger pageIndex = [thumbnail pageIndex];
            BOOL sameSize = NSEqualSizes([image size], [thumbnail size]);
            
            [thumbnail setImage:image];
            
            if (sameSize == NO) {
                [leftSideController.thumbnailTableView noteHeightOfRowChanged:pageIndex animating:YES];
                [self updateOverviewItemSize];
            }
        });
    });
    
    return YES;
}

- (void)updateThumbnailSelection {
	// Get index of current page.
	NSUInteger pageIndex = [[pdfView currentPage] pageIndex];
    mwcFlags.updatingThumbnailSelection = 1;
    [leftSideController.thumbnailTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:pageIndex] byExtendingSelection:NO];
    [leftSideController.thumbnailTableView scrollRowToVisible:pageIndex];
    mwcFlags.updatingThumbnailSelection = 0;
}

- (void)resetThumbnails {
    NSMutableArray *newThumbnails = [NSMutableArray array];
    if ([pageLabels count] > 0) {
        BOOL isLocked = [[pdfView document] isLocked];
        PDFPage *firstPage = [[pdfView document] pageAtIndex:0];
        PDFPage *emptyPage = [[[SKPDFPage alloc] init] autorelease];
        [emptyPage setBounds:[firstPage boundsForBox:kPDFDisplayBoxCropBox] forBox:kPDFDisplayBoxCropBox];
        [emptyPage setBounds:[firstPage boundsForBox:kPDFDisplayBoxMediaBox] forBox:kPDFDisplayBoxMediaBox];
        [emptyPage setRotation:[firstPage rotation]];
        NSImage *pageImage = [emptyPage thumbnailWithSize:thumbnailCacheSize forBox:[pdfView displayBox]];
        NSRect rect = NSZeroRect;
        rect.size = [pageImage size];
        CGFloat width = 0.8 * fmin(NSWidth(rect), NSHeight(rect));
        rect = NSInsetRect(rect, 0.5 * (NSWidth(rect) - width), 0.5 * (NSHeight(rect) - width));
        
        NSString *type = [[self document] fileType];
        if ([type isEqualToString:SKPostScriptDocumentType])
            type = @"PS";
        else if ([type isEqualToString:SKEncapsulatedPostScriptDocumentType])
            type = @"EPS";
        else if ([type isEqualToString:SKDVIDocumentType])
            type = @"DVI";
        else if ([type isEqualToString:SKXDVDocumentType])
            type = @"XDV";
        else
            type = @"PDF";

        [pageImage lockFocus];
        [[NSImage stampForType:type] drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
        if (isLocked)
            [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kLockedBadgeIcon)] drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:0.5];
        [pageImage unlockFocus];
        
        [pageLabels enumerateObjectsUsingBlock:^(id label, NSUInteger i, BOOL *stop) {
            SKThumbnail *thumbnail = [[SKThumbnail alloc] initWithImage:pageImage label:label pageIndex:i];
            [thumbnail setDirty:YES];
            [newThumbnails addObject:thumbnail];
            [thumbnail release];
        }];
    }
    // reloadData resets the selection, so we have to ignore its notification and reset it
    mwcFlags.updatingThumbnailSelection = 1;
    [self setThumbnails:newThumbnails];
    [self updateThumbnailSelection];
    if (overviewView) {
        if (RUNNING_BEFORE(10_11))
            [overviewView setContent:newThumbnails];
        else
            [overviewView reloadData];
        [overviewView setSelectionIndexes:[NSIndexSet indexSetWithIndex:[[pdfView currentPage] pageIndex]]];
        [self updateOverviewItemSize];
    }
    mwcFlags.updatingThumbnailSelection = 0;
}

- (void)resetThumbnailSizeIfNeeded {
    roundedThumbnailSize = round([[NSUserDefaults standardUserDefaults] floatForKey:SKThumbnailSizeKey]);

    CGFloat defaultSize = roundedThumbnailSize;
    CGFloat thumbnailSize = (defaultSize < TINY_SIZE + FUDGE_SIZE) ? TINY_SIZE : (defaultSize < SMALL_SIZE + FUDGE_SIZE) ? SMALL_SIZE : (defaultSize < LARGE_SIZE + FUDGE_SIZE) ? LARGE_SIZE : HUGE_SIZE;
    
    if (fabs(thumbnailSize - thumbnailCacheSize) > FUDGE_SIZE) {
        thumbnailCacheSize = thumbnailSize;
        
        if ([[self thumbnails] count])
            [self allThumbnailsNeedUpdate];
    }
    
    if (overviewView)
        [self updateOverviewItemSize];
}

- (void)updateThumbnailAtPageIndex:(NSUInteger)anIndex {
    [[thumbnails objectAtIndex:anIndex] setDirty:YES];
}

- (void)updateThumbnailsAtPageIndexes:(NSIndexSet *)indexSet {
    [[thumbnails objectsAtIndexes:indexSet] setValue:@YES forKey:@"dirty"];
}

- (void)allThumbnailsNeedUpdate {
    [self updateThumbnailsAtPageIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[self thumbnails] count])]];
}

#pragma mark Notes

- (void)updateNoteSelection {
    NSSortDescriptor *sortDesc = [[rightSideController.noteArrayController sortDescriptors] firstObject];
    
    if ([[sortDesc key] isEqualToString:SKNPDFAnnotationPageIndexKey] == NO)
        return;
    
    NSArray *orderedNotes = [rightSideController.noteArrayController arrangedObjects];
    __block PDFAnnotation *selAnnotation = nil;
    NSUInteger pageIndex = [[pdfView currentPage] pageIndex];
    NSMutableIndexSet *selPageIndexes = [NSMutableIndexSet indexSet];
    NSEnumerationOptions options = [sortDesc ascending] ? 0 : NSEnumerationReverse;
    
    for (selAnnotation in [self selectedNotes]) {
        if ([selAnnotation pageIndex] != NSNotFound)
            [selPageIndexes addIndex:[selAnnotation pageIndex]];
    }
    
    if ([orderedNotes count] == 0 || [selPageIndexes containsIndex:pageIndex])
		return;
	
	// Walk outline view looking for best firstpage number match.
    [orderedNotes enumerateObjectsWithOptions:options usingBlock:^(id annotation, NSUInteger i, BOOL *stop) {
		if ([annotation pageIndex] == pageIndex) {
            selAnnotation = annotation;
			*stop = YES;
		} else if ([annotation pageIndex] > pageIndex) {
			if (i == 0)
				selAnnotation = [orderedNotes objectAtIndex:0];
			else if ([selPageIndexes containsIndex:[[orderedNotes objectAtIndex:i - 1] pageIndex]])
                selAnnotation = [orderedNotes objectAtIndex:i - 1];
			*stop = YES;
		}
    }];
    if (selAnnotation) {
        mwcFlags.updatingNoteSelection = 1;
        NSInteger row = [rightSideController.noteOutlineView rowForItem:selAnnotation];
        [rightSideController.noteOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [rightSideController.noteOutlineView scrollRowToVisible:row];
        mwcFlags.updatingNoteSelection = 0;
    }
}

- (void)updateNoteFilterPredicate {
    [rightSideController.noteArrayController setFilterPredicate:[noteTypeSheetController filterPredicateForSearchString:[rightSideController.searchField stringValue] caseInsensitive:mwcFlags.caseInsensitiveFilter]];
    [rightSideController.noteOutlineView reloadData];
}

#pragma mark Snapshots

- (void)resetSnapshotSizeIfNeeded {
    roundedSnapshotThumbnailSize = round([[NSUserDefaults standardUserDefaults] floatForKey:SKSnapshotThumbnailSizeKey]);
    CGFloat defaultSize = roundedSnapshotThumbnailSize;
    CGFloat snapshotSize = (defaultSize < TINY_SIZE + FUDGE_SIZE) ? TINY_SIZE : (defaultSize < SMALL_SIZE + FUDGE_SIZE) ? SMALL_SIZE : (defaultSize < LARGE_SIZE + FUDGE_SIZE) ? LARGE_SIZE : HUGE_SIZE;
    
    if (fabs(snapshotSize - snapshotCacheSize) > FUDGE_SIZE) {
        snapshotCacheSize = snapshotSize;
        
        if (snapshotTimer) {
            [snapshotTimer invalidate];
            SKDESTROY(snapshotTimer);
        }
        
        if ([self countOfSnapshots])
            [self allSnapshotsNeedUpdate];
    }
}

- (void)snapshotNeedsUpdate:(SKSnapshotWindowController *)dirtySnapshot {
    if ([dirtySnapshots containsObject:dirtySnapshot] == NO) {
        [dirtySnapshots addObject:dirtySnapshot];
        [self updateSnapshotsIfNeeded];
    }
}

- (void)allSnapshotsNeedUpdate {
    [dirtySnapshots setArray:[self snapshots]];
    [self updateSnapshotsIfNeeded];
}

- (void)updateSnapshotsIfNeeded {
    if ([rightSideController.snapshotTableView window] != nil && [dirtySnapshots count] > 0 && snapshotTimer == nil)
        snapshotTimer = [[NSTimer scheduledTimerWithTimeInterval:0.03 target:self selector:@selector(updateSnapshot:) userInfo:NULL repeats:YES] retain];
}

- (void)updateSnapshot:(NSTimer *)timer {
    if ([dirtySnapshots count]) {
        SKSnapshotWindowController *controller = [dirtySnapshots objectAtIndex:0];
        NSSize newSize, oldSize = [[controller thumbnail] size];
        NSImage *image = [controller thumbnailWithSize:snapshotCacheSize];
        
        [image setAccessibilityDescription:[NSString stringWithFormat:NSLocalizedString(@"Page %@", @""), [controller pageLabel]]];
        [controller setThumbnail:image];
        [dirtySnapshots removeObject:controller];
        
        newSize = [image size];
        if (fabs(newSize.width - oldSize.width) > 1.0 || fabs(newSize.height - oldSize.height) > 1.0) {
            NSUInteger idx = [[rightSideController.snapshotArrayController arrangedObjects] indexOfObject:controller];
            if (idx != NSNotFound)
                [rightSideController.snapshotTableView noteHeightOfRowChanged:idx animating:YES];
        }
    }
    if ([dirtySnapshots count] == 0) {
        [snapshotTimer invalidate];
        SKDESTROY(snapshotTimer);
    }
}

- (void)updateSnapshotFilterPredicate {
    NSString *searchString = [rightSideController.searchField stringValue];
    NSPredicate *filterPredicate = nil;
    if (mwcFlags.rightSidePaneState == SKSidePaneStateSnapshot && [searchString length] > 0) {
        NSExpression *lhs = [NSExpression expressionForConstantValue:searchString];
        NSExpression *rhs = [NSExpression expressionForKeyPath:@"string"];
        NSUInteger options = NSDiacriticInsensitivePredicateOption;
        if (mwcFlags.caseInsensitiveFilter)
            options |= NSCaseInsensitivePredicateOption;
        filterPredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs modifier:NSDirectPredicateModifier type:NSInPredicateOperatorType options:options];
    }
    [rightSideController.snapshotArrayController setFilterPredicate:filterPredicate];
    [rightSideController.snapshotArrayController rearrangeObjects];
    [rightSideController.snapshotTableView reloadData];
}

#pragma mark Progress sheet

- (void)beginProgressSheetWithMessage:(NSString *)message maxValue:(NSUInteger)maxValue {
    if (progressController == nil)
        progressController = [[SKProgressController alloc] init];
    
    [progressController setMessage:message];
    if (maxValue > 0) {
        [progressController setIndeterminate:NO];
        [progressController setMaxValue:(double)maxValue];
    } else {
        [progressController setIndeterminate:YES];
    }
    [progressController beginSheetModalForWindow:[self window] completionHandler:NULL];
}

- (void)incrementProgressSheet {
    [progressController incrementBy:1.0];
}

- (void)dismissProgressSheet {
    [progressController dismissSheet:nil];
    SKDESTROY(progressController);
}

#pragma mark Remote Control

- (void)remoteButtonPressed:(NSEvent *)theEvent {
    HIDRemoteButtonCode remoteButton = (HIDRemoteButtonCode)[theEvent data1];
    BOOL remoteScrolling = (BOOL)[theEvent data2];
    
    switch (remoteButton) {
        case kHIDRemoteButtonCodeUp:
            if ([self interactionMode] == SKPresentationMode)
                [self doAutoScale:nil];
            else if (remoteScrolling)
                [self scrollUp:nil];
            else
                [self doZoomIn:nil];
            break;
        case kHIDRemoteButtonCodeDown:
            if ([self interactionMode] == SKPresentationMode)
                [self doZoomToActualSize:nil];
            else if (remoteScrolling)
                [self scrollDown:nil];
            else
                [self doZoomOut:nil];
            break;
        case kHIDRemoteButtonCodeRightHold:
        case kHIDRemoteButtonCodeRight:
            if (remoteScrolling && [self interactionMode] != SKPresentationMode)
                [self scrollRight:nil];
            else 
                [self doGoToNextPage:nil];
            break;
        case kHIDRemoteButtonCodeLeftHold:
        case kHIDRemoteButtonCodeLeft:
            if (remoteScrolling && [self interactionMode] != SKPresentationMode)
                [self scrollLeft:nil];
            else 
                [self doGoToPreviousPage:nil];
            break;
        case kHIDRemoteButtonCodeCenter:        
            [self togglePresentation:nil];
            break;
        default:
            break;
    }
}

#pragma mark Touch bar

- (NSTouchBar *)makeTouchBar {
    if (touchBarController == nil) {
        touchBarController = [[SKMainTouchBarController alloc] init];
        [touchBarController setMainController:self];
    }
    return [touchBarController makeTouchBar];
}

@end
