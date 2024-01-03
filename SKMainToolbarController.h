//
//  SKMainToolbarController.h
//  Skim
//
//  Created by Christiaan Hofman on 4/2/08.
/*
 This software is Copyright (c) 2008
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class SKMainWindowController, SKPDFView, SKColorSwatch, SKShareMenuController;

@interface SKMainToolbarController : NSViewController <NSToolbarDelegate> {
    __weak SKMainWindowController *mainController;
    NSSegmentedControl *backForwardButton;
    NSTextField *pageNumberField;
    NSSegmentedControl *previousNextPageButton;
    NSSegmentedControl *previousPageButton;
    NSSegmentedControl *nextPageButton;
    NSSegmentedControl *previousNextFirstLastPageButton;
    NSSegmentedControl *zoomInOutButton;
    NSSegmentedControl *zoomInActualOutButton;
    NSSegmentedControl *zoomActualButton;
    NSSegmentedControl *zoomFitButton;
    NSSegmentedControl *zoomSelectionButton;
    NSSegmentedControl *autoScalesButton;
    NSSegmentedControl *rotateLeftButton;
    NSSegmentedControl *rotateRightButton;
    NSSegmentedControl *rotateLeftRightButton;
    NSSegmentedControl *cropButton;
    NSSegmentedControl *fullScreenButton;
    NSSegmentedControl *presentationButton;
    NSSegmentedControl *leftPaneButton;
    NSSegmentedControl *rightPaneButton;
    NSSegmentedControl *splitPDFButton;
    NSSegmentedControl *toolModeButton;
    NSSegmentedControl *textNoteButton;
    NSSegmentedControl *circleNoteButton;
    NSSegmentedControl *markupNoteButton;
    NSSegmentedControl *lineNoteButton;
    NSSegmentedControl *singleTwoUpButton;
    NSSegmentedControl *continuousButton;
    NSSegmentedControl *displayModeButton;
    NSSegmentedControl *displayDirectionButton;
    NSSegmentedControl *displaysRTLButton;
    NSSegmentedControl *bookModeButton;
    NSSegmentedControl *pageBreaksButton;
    NSSegmentedControl *displayBoxButton;
    NSSegmentedControl *infoButton;
    NSSegmentedControl *colorsButton;
    NSSegmentedControl *fontsButton;
    NSSegmentedControl *linesButton;
    NSSegmentedControl *printButton;
    NSSegmentedControl *customizeButton;
    NSTextField *scaleField;
    NSSegmentedControl *noteButton;
    SKColorSwatch *colorSwatch;
    NSSegmentedControl *pacerButton;
    NSTextField *pacerSpeedField;
    NSStepper *pacerSpeedStepper;
    NSSegmentedControl *shareButton;
    SKShareMenuController *shareMenuController;
    NSMutableDictionary<NSString *, NSToolbarItem *> *toolbarItems;
}

@property (nonatomic, nullable, weak) IBOutlet SKMainWindowController *mainController;
@property (nonatomic, nullable, strong) IBOutlet NSSegmentedControl *backForwardButton, *previousNextPageButton, *previousPageButton, *nextPageButton, *previousNextFirstLastPageButton, *zoomInOutButton, *zoomInActualOutButton, *zoomActualButton, *zoomFitButton, *zoomSelectionButton, *autoScalesButton, *rotateLeftButton, *rotateRightButton, *rotateLeftRightButton, *cropButton, *fullScreenButton, *presentationButton, *leftPaneButton, *rightPaneButton, *splitPDFButton, *toolModeButton, *textNoteButton, *circleNoteButton, *markupNoteButton, *lineNoteButton, *singleTwoUpButton, *continuousButton, *displayModeButton, *displayDirectionButton, *displaysRTLButton, *bookModeButton, *pageBreaksButton, *displayBoxButton, *infoButton, *colorsButton, *fontsButton, *linesButton, *printButton, *customizeButton, *noteButton, *pacerButton, *shareButton;
@property (nonatomic, nullable, strong) IBOutlet NSTextField *pageNumberField, *scaleField, *pacerSpeedField;
@property (nonatomic, nullable, strong) IBOutlet SKColorSwatch *colorSwatch;
@property (nonatomic, nullable, strong) IBOutlet NSStepper *pacerSpeedStepper;

- (void)setupToolbar;

- (void)registerForNotifications;
- (void)handleChangedHistoryNotification:(nullable NSNotification *)notification;
- (void)handlePageChangedNotification:(nullable NSNotification *)notification;

#pragma mark Actions

- (IBAction)goToPreviousNextFirstLastPage:(nullable id)sender;
- (IBAction)goBackOrForward:(nullable id)sender;
- (IBAction)changeScaleFactor:(nullable id)sender;
- (void)chooseScale:(nullable id)sender;
- (void)zoomActualPhysical:(nullable id)sender;
- (IBAction)zoomInActualOut:(nullable id)sender;
- (IBAction)zoomToFit:(nullable id)sender;
- (IBAction)zoomToSelection:(nullable id)sender;
- (IBAction)changeAutoScales:(nullable id)sender;
- (IBAction)rotateAllLeftRight:(nullable id)sender;
- (IBAction)cropAll:(nullable id)sender;
- (IBAction)toggleFullscreen:(nullable id)sender;
- (IBAction)togglePresentation:(nullable id)sender;
- (IBAction)toggleLeftSidePane:(nullable id)sender;
- (IBAction)toggleRightSidePane:(nullable id)sender;
- (IBAction)toggleSplitPDF:(nullable id)sender;
- (IBAction)changeDisplayBox:(nullable id)sender;
- (IBAction)changeDisplaySinglePages:(nullable id)sender;
- (IBAction)changeDisplayContinuous:(nullable id)sender;
- (IBAction)changeDisplayMode:(nullable id)sender;
- (IBAction)changeDisplayDirection:(nullable id)sender;
- (IBAction)changeDisplaysRTL:(nullable id)sender;
- (IBAction)changeBookMode:(nullable id)sender;
- (IBAction)changePageBreaks:(nullable id)sender;
- (void)createNewTextNote:(nullable id)sender;
- (void)createNewCircleNote:(nullable id)sender;
- (void)createNewMarkupNote:(nullable id)sender;
- (void)createNewLineNote:(nullable id)sender;
- (IBAction)createNewNote:(nullable id)sender;
- (IBAction)changeToolMode:(nullable id)sender;
- (IBAction)selectColor:(nullable id)sender;
- (IBAction)togglePacer:(nullable id)sender;
- (IBAction)choosePacerSpeed:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
