//
//  SKMainWindowController.h
//  Skim
//
//  Created by Michael McCracken on 12/6/06.
/*
 This software is Copyright (c) 2006
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

#import <Cocoa/Cocoa.h>
#import "SKSnapshotWindowController.h"
#import "SKThumbnail.h"
#import "SKFindController.h"
#import "SKSecondaryToolbarController.h"
#import "NSDocument_SKExtensions.h"
#import "SKPDFView.h"
#import "SKPDFDocument.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SKLeftSidePaneState) {
    SKSidePaneStateThumbnail,
    SKSidePaneStateOutline
};

typedef NS_ENUM(NSInteger, SKRightSidePaneState) {
    SKSidePaneStateNote,
    SKSidePaneStateSnapshot
};

typedef NS_ENUM(NSInteger, SKFindPaneState) {
    SKFindPaneStateSingular,
    SKFindPaneStateGrouped
};

enum {
    SKWindowOptionDefault,
    SKWindowOptionMaximize,
    SKWindowOptionFit
};

@class PDFAnnotation, PDFSelection, SKGroupedSearchResult;
@class SKPDFView, SKSecondaryPDFView, SKStatusBar, SKFindController, SKSplitView, SKFieldEditor, SKOverviewView, SKSideWindow;
@class SKLeftSideViewController, SKRightSideViewController, SKMainToolbarController, SKMainTouchBarController, SKProgressController, SKPresentationOptionsSheetController, SKNoteTypeSheetController, SKSnapshotWindowController, SKSecondaryToolbarController;

@interface SKMainWindowController : NSWindowController <SKSnapshotWindowControllerDelegate, SKThumbnailDelegate, SKFindControllerDelegate, SKPDFViewDelegate, SKPDFDocumentDelegate, NSTouchBarDelegate, SKSecondaryToolbarControllerDelegate> {
    SKSplitView                         *splitView;
    
    SKSplitView                         *centerContentView;
    SKSplitView                         *pdfSplitView;
    NSView                              *pdfContentView;
    SKPDFView                           *pdfView;
    
    SKSecondaryPDFView                  *secondaryPdfView;
    
    SKSecondaryToolbarController        *secondaryToolbarController;
    
    SKLeftSideViewController            *leftSideController;
    SKRightSideViewController           *rightSideController;
    
    SKMainToolbarController             *toolbarController;
    
    SKMainTouchBarController            *touchBarController;
    
    SKOverviewView                      *overviewView;
    NSView                              *overviewContentView;
    
    NSView                              *leftSideContentView;
    NSView                              *rightSideContentView;
    
    SKStatusBar                         *statusBar;
    
    SKFindController                    *findController;
    
    SKFieldEditor                       *fieldEditor;
    
    NSArray<SKThumbnail *>              *thumbnails;
    CGFloat                             roundedThumbnailSize;
    
    NSMutableArray<PDFSelection *>      *searchResults;
    NSInteger                           searchResultIndex;
    
    NSMutableArray<SKGroupedSearchResult *> *groupedSearchResults;
    
    SKNoteTypeSheetController           *noteTypeSheetController;
    NSMutableArray<PDFAnnotation *>     *notes;
    NSMapTable                          *rowHeights;
    
    NSMutableArray<PDFAnnotation *>     *widgets;
    NSMapTable<PDFAnnotation *, id>     *widgetValues;
    
    NSMutableArray<SKSnapshotWindowController *> *snapshots;
    NSMutableArray<SKSnapshotWindowController *> *dirtySnapshots;
    NSTimer                             *snapshotTimer;
    CGFloat                             roundedSnapshotThumbnailSize;
    
    NSArray<NSString *>                 *tags;
    double                              rating;
    
    NSWindow                            *mainWindow;
    SKSideWindow                        *sideWindow;
    NSWindow                            *animationWindow;
    
    SKInteractionMode                   interactionMode;
    
    SKProgressController                *progressController;
    
    NSDocument                          *presentationNotesDocument;
    NSInteger                           presentationNotesOffset;
    SKSnapshotWindowController          *presentationPreview;
    NSButton                            *presentationNotesButton;
    NSTrackingArea                      *presentationNotesTrackingArea;
    
    NSMutableArray<PDFAnnotation *>     *presentationNotes;
    NSUndoManager                       *presentationUndoManager;
    
    NSButton                            *colorAccessoryView;
    NSButton                            *textColorAccessoryView;
    
    NSArray<NSString *>                 *pageLabels;
    
    NSString                            *pageLabel;
    
    NSUInteger                          markedPageIndex;
    NSPoint                             markedPagePoint;
    NSUInteger                          beforeMarkedPageIndex;
    NSPoint                             beforeMarkedPagePoint;
    
    NSPointerArray                      *lastViewedPages;
    
    id                                  activity;
    
    NSMutableDictionary<NSString *, id> *savedNormalSetup;
    
    CGFloat                             lastLeftSidePaneWidth;
    CGFloat                             lastRightSidePaneWidth;
    CGFloat                             lastSplitPDFHeight;
    
    CGFloat                             titleBarHeight;
    
    CGFloat                             thumbnailCacheSize;
    CGFloat                             snapshotCacheSize;
    
    NSMapTable<PDFAnnotation *, NSMutableDictionary *> *undoGroupOldPropertiesPerNote;
    
    PDFDocument                         *placeholderPdfDocument;
    NSArray<NSDictionary<NSString *, id> *> *placeholderWidgetProperties;

    struct _mwcFlags {
        unsigned int leftSidePaneState:1;
        unsigned int rightSidePaneState:1;
        unsigned int savedLeftSidePaneState:1;
        unsigned int findPaneState:1;
        unsigned int caseInsensitiveSearch:1;
        unsigned int wholeWordSearch:1;
        unsigned int caseInsensitiveFilter:1;
        unsigned int autoResizeNoteRows:1;
        unsigned int addOrRemoveNotesInBulk:1;
        unsigned int updatingOutlineSelection:1;
        unsigned int updatingThumbnailSelection:1;
        unsigned int updatingNoteSelection:1;
        unsigned int updatingFindResults:1;
        unsigned int updatingColor:1;
        unsigned int updatingFont:1;
        unsigned int updatingFontAttributes:1;
        unsigned int updatingLine:1;
        unsigned int settingUpWindow:1;
        unsigned int isEditingPDF:1;
        unsigned int isEditingTable:1;
        unsigned int isSwitchingFullScreen:1;
        unsigned int isAnimatingFindBar:1;
        unsigned int isAnimatingSecondaryToolbar:1;
        unsigned int secondaryToolbarShowing:1;
        unsigned int wantsPresentation:1;
        unsigned int recentInfoNeedsUpdate:1;
        unsigned int hasCropped:1;
        unsigned int fullSizeContent:1;
    } mwcFlags;
}

@property (nonatomic, nullable, strong) IBOutlet NSWindow *mainWindow;

@property (nonatomic, nullable, strong) IBOutlet SKSplitView *splitView;
@property (nonatomic, nullable, strong) NSSplitViewController *splitViewController;
    
@property (nonatomic, nullable, strong) IBOutlet NSView *centerContentView;
@property (nonatomic, nullable, strong) IBOutlet SKSplitView *pdfSplitView;
@property (nonatomic, nullable, strong) IBOutlet NSView *pdfContentView;

@property (nonatomic, nullable, strong) IBOutlet NSSplitViewController *pdfViewController;
@property (nonatomic, nullable, strong) IBOutlet SKLeftSideViewController *leftSideController;
@property (nonatomic, nullable, strong) IBOutlet SKRightSideViewController *rightSideController;
    
@property (nonatomic, nullable, strong) IBOutlet SKMainToolbarController *toolbarController;
@property (nonatomic, nullable, strong) IBOutlet SKSecondaryToolbarController *secondaryToolbarController;
    
@property (nonatomic, nullable, strong) IBOutlet NSView *leftSideContentView, *rightSideContentView;

@property (nonatomic, nullable, readonly) NSString *searchString;

- (void)showSnapshotAtPageNumber:(NSInteger)pageNum forRect:(NSRect)rect scaleFactor:(CGFloat)scaleFactor autoFits:(BOOL)autoFits;
- (void)showSnapshotsWithSetups:(NSArray *)setups;
- (void)showNote:(PDFAnnotation *)annotation;

- (nullable NSWindowController *)windowControllerForNote:(PDFAnnotation *)annotation;

@property (nonatomic, nullable, readonly) SKPDFView *pdfView;
@property (nonatomic, nullable, readonly) PDFDocument *pdfDocument;
@property (nonatomic, nullable, readonly) PDFView *secondaryPdfView;

@property (nonatomic, nullable, readonly) PDFDocument *placeholderPdfDocument;

@property (nonatomic, nullable, readonly) NSArray<NSDictionary<NSString *, id> *> *widgetProperties;

@property (nonatomic, readonly) BOOL hasNotes;

@property (nonatomic, readonly) NSArray<PDFAnnotation *> *notes;
- (void)insertObject:(PDFAnnotation *)note inNotesAtIndex:(NSUInteger)theIndex;
- (void)insertNotes:(NSArray *)newNotes atIndexes:(NSIndexSet *)theIndexes;
- (void)removeObjectFromNotesAtIndex:(NSUInteger)theIndex;
- (void)removeAllObjectsFromNotes;

@property (nonatomic, copy) NSArray<SKThumbnail *> *thumbnails;

@property (nonatomic, readonly) NSArray<SKSnapshotWindowController *> *snapshots;
- (void)insertObject:(SKSnapshotWindowController *)snapshot inSnapshotsAtIndex:(NSUInteger)theIndex;
- (void)removeObjectFromSnapshotsAtIndex:(NSUInteger)theIndex;
- (void)removeAllObjectsFromSnapshots;

@property (nonatomic, nullable, copy) NSArray<PDFSelection *> *searchResults;

@property (nonatomic, nullable, copy) NSArray<SKGroupedSearchResult *> *groupedSearchResults;

@property (nonatomic, nullable, copy) NSDictionary<NSString *, id> *presentationOptions;

@property (nonatomic, nullable, strong) NSDocument *presentationNotesDocument;
@property (nonatomic) NSInteger presentationNotesOffset;

@property (nonatomic, nullable, readonly) NSUndoManager *presentationUndoManager;

@property (nonatomic, copy) NSArray<NSString *> *tags;
@property (nonatomic) double rating;

@property (nonatomic, nullable, copy) NSArray<PDFAnnotation *> *selectedNotes;

@property (nonatomic, nullable, copy) NSString *pageLabel;

@property (nonatomic, readonly) SKInteractionMode interactionMode;

@property (nonatomic, readonly) BOOL autoScales;

@property (nonatomic) SKLeftSidePaneState leftSidePaneState;
@property (nonatomic) SKRightSidePaneState rightSidePaneState;
@property (nonatomic) SKFindPaneState findPaneState;

@property (nonatomic, readonly) BOOL leftSidePaneIsOpen, leftSidebarIsOpen, rightSidePaneIsOpen;
@property (nonatomic, readonly) CGFloat leftSideWidth, rightSideWidth;

@property (nonatomic) BOOL recentInfoNeedsUpdate;

@property (nonatomic, nullable, readonly) NSMenu *notesMenu;

@property (nonatomic) BOOL hasOverview;

- (void)showOverviewAnimating:(BOOL)animate;
- (void)hideOverviewAnimating:(BOOL)animate;
- (void)hideOverviewAnimating:(BOOL)animate completionHandler:(nullable void (^)(void))handler;

- (void)displayTocViewAnimating:(BOOL)animate;
- (void)displayThumbnailViewAnimating:(BOOL)animate;
- (void)displayFindViewAnimating:(BOOL)animate;
- (void)displayGroupedFindViewAnimating:(BOOL)animate;
- (void)displayNoteViewAnimating:(BOOL)animate;
- (void)displaySnapshotViewAnimating:(BOOL)animate;

- (void)showFindBar;
- (void)showSecondaryToolbar;

- (void)selectFindResultHighlight:(NSSelectionDirection)direction;

- (void)updateOutlineSelection;

- (void)updateNoteSelection;

- (BOOL)isOutlineExpanded:(PDFOutline *)outline;
- (void)setExpanded:(BOOL)flag forOutline:(PDFOutline *)outline;

- (void)updateThumbnailSelection;
- (void)resetThumbnails;
- (void)resetThumbnailSizeIfNeeded;
- (void)updateThumbnailAtPageIndex:(NSUInteger)index;
- (void)updateThumbnailsAtPageIndexes:(NSIndexSet *)indexSet;
- (void)allThumbnailsNeedUpdate;

- (void)resetSnapshotSizeIfNeeded;
- (void)snapshotNeedsUpdate:(SKSnapshotWindowController *)dirstySnapshot;
- (void)allSnapshotsNeedUpdate;
- (void)updateSnapshotsIfNeeded;
- (void)updateSnapshot:(NSTimer *)timer;

- (void)setPdfDocument:(nullable PDFDocument *)pdfDocument addAnnotationsFromDictionaries:(nullable NSArray<NSDictionary<NSString *, id> *> *)noteDicts;
- (void)addAnnotationsFromDictionaries:(NSArray<NSDictionary<NSString *, id> *> *)noteDicts removeAnnotations:(nullable NSArray<PDFAnnotation *> *)notesToRemove;

- (void)applySetup:(NSDictionary<NSString *, id> *)setup;
- (NSDictionary<NSString *, id> *)currentSetup;
- (void)applyPDFSettings:(NSDictionary<NSString *, id> *)setup rewind:(BOOL)rewind;
- (NSDictionary<NSString *, id> *)currentPDFSettings;
- (void)applyOptions:(NSDictionary<NSString *, id> *)options;

- (void)beginProgressSheetWithMessage:(NSString *)message maxValue:(NSUInteger)maxValue;
- (void)incrementProgressSheet;
- (void)dismissProgressSheet;

@end

NS_ASSUME_NONNULL_END
