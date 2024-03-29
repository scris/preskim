//
//  SKMainToolbarController.m
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

#import "SKMainToolbarController.h"
#import "SKMainWindowController.h"
#import "SKMainWindowController_Actions.h"
#import "SKMainWindowController_FullScreen.h"
#import "SKToolbarItem.h"
#import "NSToolbarItem_SKExtensions.h"
#import "NSSegmentedControl_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKPDFView.h"
#import "SKColorSwatch.h"
#import "NSValueTransformer_SKExtensions.h"
#import "SKApplicationController.h"
#import "NSImage_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "SKTextFieldSheetController.h"
#import "NSWindowController_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>
#import "NSEvent_SKExtensions.h"
#import "PDFView_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"
#import "PDFDocument_SKExtensions.h"
#import "SKShareMenuController.h"
#import "SKLeftSideViewController.h"

#define SKRecentsAutosaveName @"SKRecentPDFSearches"

#define SKDocumentToolbarIdentifier @"SKDocumentToolbar"

#define SKDocumentToolbarPreviousItemIdentifier @"SKDocumentToolbarPreviousItemIdentifier"
#define SKDocumentToolbarNextItemIdentifier @"SKDocumentToolbarNextItemIdentifier"
#define SKDocumentToolbarPreviousNextItemIdentifier @"SKDocumentToolbarPreviousNextItemIdentifier"
#define SKDocumentToolbarPreviousNextFirstLastItemIdentifier @"SKDocumentToolbarPreviousNextFirstLastItemIdentifier"
#define SKDocumentToolbarBackForwardItemIdentifier @"SKDocumentToolbarBackForwardItemIdentifier"
#define SKDocumentToolbarPageNumberItemIdentifier @"SKDocumentToolbarPageNumberItemIdentifier"
#define SKDocumentToolbarScaleItemIdentifier @"SKDocumentToolbarScaleItemIdentifier"
#define SKDocumentToolbarZoomActualItemIdentifier @"SKDocumentToolbarZoomActualItemIdentifier"
#define SKDocumentToolbarZoomToSelectionItemIdentifier @"SKDocumentToolbarZoomToSelectionItemIdentifier"
#define SKDocumentToolbarZoomToFitItemIdentifier @"SKDocumentToolbarZoomToFitItemIdentifier"
#define SKDocumentToolbarZoomInOutItemIdentifier @"SKDocumentToolbarZoomInOutItemIdentifier"
#define SKDocumentToolbarZoomInActualOutItemIdentifier @"SKDocumentToolbarZoomInActualOutItemIdentifier"
#define SKDocumentToolbarAutoScalesItemIdentifier @"SKDocumentToolbarAutoScalesItemIdentifier"
#define SKDocumentToolbarRotateRightItemIdentifier @"SKDocumentToolbarRotateRightItemIdentifier"
#define SKDocumentToolbarRotateLeftItemIdentifier @"SKDocumentToolbarRotateLeftItemIdentifier"
#define SKDocumentToolbarRotateLeftRightItemIdentifier @"SKDocumentToolbarRotateLeftRightItemIdentifier"
#define SKDocumentToolbarCropItemIdentifier @"SKDocumentToolbarCropItemIdentifier"
#define SKDocumentToolbarFullScreenItemIdentifier @"SKDocumentToolbarFullScreenItemIdentifier"
#define SKDocumentToolbarPresentationItemIdentifier @"SKDocumentToolbarPresentationItemIdentifier"
#define SKDocumentToolbarNewTextNoteItemIdentifier @"SKDocumentToolbarNewTextNoteItemIdentifier"
#define SKDocumentToolbarNewCircleNoteItemIdentifier @"SKDocumentToolbarNewCircleNoteItemIdentifier"
#define SKDocumentToolbarNewMarkupItemIdentifier @"SKDocumentToolbarNewMarkupItemIdentifier"
#define SKDocumentToolbarNewLineItemIdentifier @"SKDocumentToolbarNewLineItemIdentifier"
#define SKDocumentToolbarNewNoteItemIdentifier @"SKDocumentToolbarNewNoteItemIdentifier"
#define SKDocumentToolbarInfoItemIdentifier @"SKDocumentToolbarInfoItemIdentifier"
#define SKDocumentToolbarToolModeItemIdentifier @"SKDocumentToolbarToolModeItemIdentifier"
#define SKDocumentToolbarHighlightersIdentifier @"SKDocumentToolbarHighlightersIdentifier"
#define SKDocumentToolbarSingleTwoUpItemIdentifier @"SKDocumentToolbarSingleTwoUpItemIdentifier"
#define SKDocumentToolbarContinuousItemIdentifier @"SKDocumentToolbarContinuousItemIdentifier"
#define SKDocumentToolbarDisplayModeItemIdentifier @"SKDocumentToolbarDisplayModeItemIdentifier"
#define SKDocumentToolbarDisplayDirectionItemIdentifier @"SKDocumentToolbarDisplayDirectionItemIdentifier"
#define SKDocumentToolbarDisplaysRTLItemIdentifier @"SKDocumentToolbarDisplaysRTLItemIdentifier"
#define SKDocumentToolbarBookModeItemIdentifier @"SKDocumentToolbarBookModeItemIdentifier"
#define SKDocumentToolbarPageBreaksItemIdentifier @"SKDocumentToolbarPageBreaksItemIdentifier"
#define SKDocumentToolbarDisplayBoxItemIdentifier @"SKDocumentToolbarDisplayBoxItemIdentifier"
#define SKDocumentToolbarColorSwatchItemIdentifier @"SKDocumentToolbarColorSwatchItemIdentifier"
#define SKDocumentToolbarShareItemIdentifier @"SKDocumentToolbarShareItemIdentifier"
#define SKDocumentToolbarPacerItemIdentifier @"SKDocumentToolbarPacerItemIdentifier"
#define SKDocumentToolbarPacerButtonItemIdentifier @"SKDocumentToolbarPacerButtonItemIdentifier"
#define SKDocumentToolbarPacerSpeedFieldItemIdentifier @"SKDocumentToolbarPacerSpeedFieldItemIdentifier"
#define SKDocumentToolbarPacerSpeedStepperItemIdentifier @"SKDocumentToolbarPacerSpeedStepperItemIdentifier"
#define SKDocumentToolbarColorsItemIdentifier @"SKDocumentToolbarColorsItemIdentifier"
#define SKDocumentToolbarFontsItemIdentifier @"SKDocumentToolbarFontsItemIdentifier"
#define SKDocumentToolbarLinesItemIdentifier @"SKDocumentToolbarLinesItemIdentifier"
#define SKDocumentToolbarContentsPaneItemIdentifier @"SKDocumentToolbarContentsPaneItemIdentifier"
#define SKDocumentToolbarNotesPaneItemIdentifier @"SKDocumentToolbarNotesPaneItemIdentifier"
#define SKDocumentToolbarSplitPDFItemIdentifier @"SKDocumentToolbarSplitPDFItemIdentifier"
#define SKDocumentToolbarPrintItemIdentifier @"SKDocumentToolbarPrintItemIdentifier"
#define SKDocumentToolbarCustomizeItemIdentifier @"SKDocumentToolbarCustomizeItemIdentifier"
#define SKDocumentToolbarSearchItemIdentifier @"SKDocumentToolbarSearchItemIdentifier"

static NSString *noteToolImageNames[] = {@"ToolbarTextNoteMenu", @"ToolbarAnchoredNoteMenu", @"ToolbarCircleNoteMenu", @"ToolbarSquareNoteMenu", @"ToolbarHighlightNoteMenu", @"ToolbarUnderlineNoteMenu", @"ToolbarStrikeOutNoteMenu", @"ToolbarLineNoteMenu", @"ToolbarInkNoteMenu"};

static NSString *addNoteToolImageNames[] = {@"ToolbarAddTextNoteMenu", @"ToolbarAddAnchoredNoteMenu", @"ToolbarAddCircleNoteMenu", @"ToolbarAddSquareNoteMenu", @"ToolbarAddHighlightNoteMenu", @"ToolbarAddUnderlineNoteMenu", @"ToolbarAddStrikeOutNoteMenu", @"ToolbarAddLineNoteMenu", @"ToolbarAddInkNoteMenu"};

@interface SKToolbar : NSToolbar
@end

@implementation SKToolbar
- (BOOL)_allowsSizeMode:(NSToolbarSizeMode)sizeMode { return NO; }
@end

#pragma mark -

@interface SKMainToolbarController (SKPrivate)
- (void)handleColorSwatchFrameChangedNotification:(NSNotification *)notification;
- (void)handleColorSwatchColorsChangedNotification:(NSNotification *)notification;
@end


@implementation SKMainToolbarController

@synthesize mainController, backForwardButton, pageNumberField, previousNextPageButton, previousPageButton, nextPageButton, previousNextFirstLastPageButton, zoomInOutButton, zoomInActualOutButton, zoomActualButton, zoomFitButton, zoomSelectionButton, autoScalesButton, rotateLeftButton, rotateRightButton, rotateLeftRightButton, cropButton, fullScreenButton, presentationButton, leftPaneButton, rightPaneButton, splitPDFButton, toolModeButton, highlightersButton, textNoteButton, circleNoteButton, markupNoteButton, lineNoteButton, singleTwoUpButton, continuousButton, displayModeButton, displayDirectionButton, displaysRTLButton, bookModeButton, pageBreaksButton, displayBoxButton, infoButton, colorsButton, fontsButton, linesButton, printButton, customizeButton, scaleField, noteButton, colorSwatch, pacerButton, pacerSpeedField, pacerSpeedStepper, shareButton, searchField;

- (NSString *)nibName {
    return @"MainToolbar";
}

- (void)setMainController:(SKMainWindowController *)newMainController {
    if (mainController != nil && newMainController == nil) {
        [colorSwatch unbind:@"colors"];
        [[NSNotificationCenter defaultCenter] removeObserver: self];
    }
    mainController = newMainController;
}

- (void)setupToolbar {
    // make sure the nib is loaded
    [self view];
    
    // Create a new toolbar instance, and attach it to our document window
    NSToolbar *toolbar = [[SKToolbar alloc] initWithIdentifier:SKDocumentToolbarIdentifier];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
        
    // We are the delegate
    [toolbar setDelegate:self];
    
    // Attach the toolbar to the window
    [[mainController window] setToolbar:toolbar];
    
    [self registerForNotifications];
}

- (NSToolbarItem *)toolbarItemForItemIdentifier:(NSString *)identifier {
    NSToolbarItem *item = [toolbarItems objectForKey:identifier];
    NSMenu *menu;
    NSMenuItem *menuItem;
    
    if (item == nil) {
        
        if (toolbarItems == nil)
            toolbarItems = [[NSMutableDictionary alloc] init];

        item = [[SKToolbarItem alloc] initWithItemIdentifier:identifier];
        [toolbarItems setObject:item forKey:identifier];
    
        if ([identifier isEqualToString:SKDocumentToolbarPreviousNextItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Previous/Next", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Previous", @"Menu item title") action:@selector(doGoToPreviousPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Next", @"Menu item title") action:@selector(doGoToNextPage:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Previous/Next", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Previous/Next", @"Tool tip message")];
            [previousNextPageButton setHelp:NSLocalizedString(@"Go To Previous Page", @"Tool tip message") forSegment:0];
            [previousNextPageButton setHelp:NSLocalizedString(@"Go To Next Page", @"Tool tip message") forSegment:1];
            [previousNextPageButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:previousNextPageButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPreviousItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Previous", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Previous", @"Menu item title") action:@selector(doGoToPreviousPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"First", @"Menu item title") action:@selector(doGoToFirstPage:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Previous", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Go To Previous Page", @"Tool tip message")];
            [previousPageButton setHelp:NSLocalizedString(@"Go To First page", @"Tool tip message") forSegment:0];
            [previousPageButton setHelp:NSLocalizedString(@"Go To Previous Page", @"Tool tip message") forSegment:1];
            [previousPageButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:previousPageButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNextItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Next", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Next", @"Menu item title") action:@selector(doGoToNextPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Last", @"Menu item title") action:@selector(doGoToLastPage:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Next", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Go To Next Page", @"Tool tip message")];
            [nextPageButton setHelp:NSLocalizedString(@"Go To Next Page", @"Tool tip message") forSegment:0];
            [nextPageButton setHelp:NSLocalizedString(@"Go To Last page", @"Tool tip message") forSegment:1];
            [nextPageButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:nextPageButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPreviousNextFirstLastItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Previous/Next", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Previous", @"Menu item title") action:@selector(doGoToPreviousPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Next", @"Menu item title") action:@selector(doGoToNextPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"First", @"Menu item title") action:@selector(doGoToFirstPage:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Last", @"Menu item title") action:@selector(doGoToLastPage:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Previous/Next", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Go To First, Previous, Next or Last Page", @"Tool tip message")];
            [previousNextFirstLastPageButton setHelp:NSLocalizedString(@"Go To First page", @"Tool tip message") forSegment:0];
            [previousNextFirstLastPageButton setHelp:NSLocalizedString(@"Go To Previous Page", @"Tool tip message") forSegment:1];
            [previousNextFirstLastPageButton setHelp:NSLocalizedString(@"Go To Next Page", @"Tool tip message") forSegment:2];
            [previousNextFirstLastPageButton setHelp:NSLocalizedString(@"Go To Last page", @"Tool tip message") forSegment:3];
            [previousNextFirstLastPageButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:previousNextFirstLastPageButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarBackForwardItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Back/Forward", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Back", @"Menu item title") action:@selector(doGoBack:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Forward", @"Menu item title") action:@selector(doGoForward:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Back/Forward", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Back/Forward", @"Tool tip message")];
            [backForwardButton setHelp:NSLocalizedString(@"Go Back", @"Tool tip message") forSegment:0];
            [backForwardButton setHelp:NSLocalizedString(@"Go Forward", @"Tool tip message") forSegment:1];
            [backForwardButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:backForwardButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPageNumberItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Page", @"Menu item title") action:@selector(doGoToPage:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Page", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Go To Page", @"Tool tip message")];
            [item setView:pageNumberField];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarScaleItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Scale", @"Menu item title") action:@selector(chooseScale:) target:self];
            
            [item setLabels:NSLocalizedString(@"Scale", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Scale", @"Tool tip message")];
            [item setView:scaleField];
            [item setMenuFormRepresentation:menuItem];
            
            [(NSNumberFormatter *)[scaleField formatter] setMinimum:[NSNumber numberWithDouble:[mainController.pdfView minScaleFactor]]];
            [(NSNumberFormatter *)[scaleField formatter] setMaximum:[NSNumber numberWithDouble:[mainController.pdfView maxScaleFactor]]];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarZoomActualItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Actual Size", @"Menu item title") action:@selector(zoomActualPhysical:) target:self];
            
            [item setLabels:NSLocalizedString(@"Actual Size", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Zoom To Actual Size", @"Tool tip message")];
            [item setView:zoomActualButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarZoomToFitItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Zoom To Fit", @"Menu item title") action:@selector(doZoomToFit:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Zoom To Fit", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Zoom To Fit", @"Tool tip message")];
            [item setView:zoomFitButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarZoomToSelectionItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Zoom To Selection", @"Menu item title") action:@selector(doZoomToSelection:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Zoom To Selection", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Zoom To Selection", @"Tool tip message")];
            [item setView:zoomSelectionButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarZoomInOutItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Zoom", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Zoom In", @"Menu item title") action:@selector(doZoomIn:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Zoom Out", @"Menu item title") action:@selector(doZoomOut:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Zoom", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Zoom", @"Tool tip message")];
            [zoomInOutButton setHelp:NSLocalizedString(@"Zoom Out", @"Tool tip message") forSegment:0];
            [zoomInOutButton setHelp:NSLocalizedString(@"Zoom In", @"Tool tip message") forSegment:1];
            [zoomInOutButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:zoomInOutButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarZoomInActualOutItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Zoom", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Zoom In", @"Menu item title") action:@selector(doZoomIn:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Zoom Out", @"Menu item title") action:@selector(doZoomOut:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Actual Size", @"Menu item title") action:@selector(zoomActualPhysical:) target:self];
            
            [item setLabels:NSLocalizedString(@"Zoom", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Zoom", @"Tool tip message")];
            [zoomInActualOutButton setHelp:NSLocalizedString(@"Zoom Out", @"Tool tip message") forSegment:0];
            [zoomInActualOutButton setHelp:NSLocalizedString(@"Zoom To Actual Size", @"Tool tip message") forSegment:1];
            [zoomInActualOutButton setHelp:NSLocalizedString(@"Zoom In", @"Tool tip message") forSegment:2];
            [zoomInActualOutButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:zoomInActualOutButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarAutoScalesItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Automatically Resize", @"Menu item title") action:@selector(toggleAutoScale:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Automatically Resize", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Automatically Resize", @"Tool tip message")];
            [autoScalesButton setHelp:NSLocalizedString(@"Automatically Resize", @"Tool tip message") forSegment:0];
            [item setView:autoScalesButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarRotateRightItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Rotate Right", @"Menu item title") action:@selector(rotateAllRight:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Rotate Right", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Rotate Right", @"Tool tip message")];
            [item setView:rotateRightButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarRotateLeftItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Rotate Left", @"Menu item title") action:@selector(rotateAllLeft:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Rotate Left", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Rotate Left", @"Tool tip message")];
            [item setView:rotateLeftButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarRotateLeftRightItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Rotate", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Rotate Right", @"Menu item title") action:@selector(rotateAllRight:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Rotate Left", @"Menu item title") action:@selector(rotateAllLeft:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Rotate", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Rotate Left or Right", @"Tool tip message")];
            [rotateLeftRightButton setHelp:NSLocalizedString(@"Rotate Left", @"Tool tip message") forSegment:0];
            [rotateLeftRightButton setHelp:NSLocalizedString(@"Rotate Right", @"Tool tip message") forSegment:1];
            [rotateLeftRightButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:rotateLeftRightButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarCropItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Crop", @"Menu item title") action:@selector(cropAll:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Crop", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Crop", @"Tool tip message")];
            [item setView:cropButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarFullScreenItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Full Screen", @"Menu item title") action:@selector(toggleFullscreen:) target:self];
            
            [item setLabels:NSLocalizedString(@"Full Screen", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Full Screen", @"Tool tip message")];
            [item setView:fullScreenButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPresentationItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Presentation", @"Menu item title") action:@selector(togglePresentation:) target:self];
            
            [item setLabels:NSLocalizedString(@"Presentation", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Presentation", @"Tool tip message")];
            [item setView:presentationButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNewTextNoteItemIdentifier]) {
            
            menu = [NSMenu menu];
            [menu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") imageNamed:SKImageNameToolbarAddTextNote action:@selector(createNewTextNote:) target:self tag:SKFreeTextNote];
            [menu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") imageNamed:SKImageNameToolbarAddAnchoredNote action:@selector(createNewTextNote:) target:self tag:SKAnchoredNote];
            [textNoteButton setMenu:menu forSegment:0];
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Add Note", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") imageNamed:SKImageNameToolbarAddTextNote action:@selector(createNewNote:) target:mainController tag:SKFreeTextNote];
            [menu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") imageNamed:SKImageNameToolbarAddAnchoredNote action:@selector(createNewNote:) target:mainController tag:SKAnchoredNote];
            
            [item setLabels:NSLocalizedString(@"Add Note", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Add New Note", @"Tool tip message")];
            [item setView:textNoteButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNewCircleNoteItemIdentifier]) {
            
            menu = [NSMenu menu];
            [menu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") imageNamed:SKImageNameToolbarAddCircleNote action:@selector(createNewCircleNote:) target:self tag:SKCircleNote];
            [menu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") imageNamed:SKImageNameToolbarAddSquareNote action:@selector(createNewCircleNote:) target:self tag:SKSquareNote];
            [circleNoteButton setMenu:menu forSegment:0];
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Add Shape", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") imageNamed:SKImageNameToolbarAddCircleNote action:@selector(createNewNote:) target:mainController tag:SKCircleNote];
            [menu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") imageNamed:SKImageNameToolbarAddSquareNote action:@selector(createNewNote:) target:mainController tag:SKSquareNote];
            
            [item setLabels:NSLocalizedString(@"Add Shape", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Add New Circle or Box", @"Tool tip message")];
            [item setView:circleNoteButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNewMarkupItemIdentifier]) {
            
            menu = [NSMenu menu];
            [menu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") imageNamed:SKImageNameToolbarAddHighlightNote action:@selector(createNewMarkupNote:) target:self tag:SKHighlightNote];
            [menu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") imageNamed:SKImageNameToolbarAddUnderlineNote action:@selector(createNewMarkupNote:) target:self tag:SKUnderlineNote];
            [menu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") imageNamed:SKImageNameToolbarAddStrikeOutNote action:@selector(createNewMarkupNote:) target:self tag:SKStrikeOutNote];
            [markupNoteButton setMenu:menu forSegment:0];
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Add Markup", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") imageNamed:SKImageNameToolbarAddHighlightNote action:@selector(createNewNote:) target:mainController tag:SKHighlightNote];
            [menu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") imageNamed:SKImageNameToolbarAddUnderlineNote action:@selector(createNewNote:) target:mainController tag:SKUnderlineNote];
            [menu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") imageNamed:SKImageNameToolbarAddStrikeOutNote action:@selector(createNewNote:) target:mainController tag:SKStrikeOutNote];
            
            [item setLabels:NSLocalizedString(@"Add Markup", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Add New Markup", @"Tool tip message")];
            [item setView:markupNoteButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNewLineItemIdentifier]) {
            
            menu = [NSMenu menu];
            [menu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") imageNamed:SKImageNameToolbarAddLineNote action:@selector(createNewLineNote:) target:self tag:SKLineNote];
            [menu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") imageNamed:SKImageNameToolbarAddInkNote action:@selector(createNewLineNote:) target:self tag:SKInkNote];
            [lineNoteButton setMenu:menu forSegment:0];
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Add Line", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") imageNamed:SKImageNameToolbarAddLineNote action:@selector(createNewNote:) target:mainController tag:SKLineNote];
            [menu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") imageNamed:SKImageNameToolbarAddInkNote action:@selector(createNewNote:) target:mainController tag:SKInkNote];
            
            [item setLabels:NSLocalizedString(@"Add Line", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Add New Line", @"Tool tip message")];
            [item setView:lineNoteButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNewNoteItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Add Note", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") imageNamed:SKImageNameToolbarAddTextNote action:@selector(createNewNote:) target:mainController tag:SKFreeTextNote];
            [menu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") imageNamed:SKImageNameToolbarAddAnchoredNote action:@selector(createNewNote:) target:mainController tag:SKAnchoredNote];
            [menu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") imageNamed:SKImageNameToolbarAddCircleNote action:@selector(createNewNote:) target:mainController tag:SKCircleNote];
            [menu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") imageNamed:SKImageNameToolbarAddSquareNote action:@selector(createNewNote:) target:mainController tag:SKSquareNote];
            [menu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") imageNamed:SKImageNameToolbarAddHighlightNote action:@selector(createNewNote:) target:mainController tag:SKHighlightNote];
            [menu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") imageNamed:SKImageNameToolbarAddUnderlineNote action:@selector(createNewNote:) target:mainController tag:SKUnderlineNote];
            [menu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") imageNamed:SKImageNameToolbarAddStrikeOutNote action:@selector(createNewNote:) target:mainController tag:SKStrikeOutNote];
            [menu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") imageNamed:SKImageNameToolbarAddLineNote action:@selector(createNewNote:) target:mainController tag:SKLineNote];
            [menu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") imageNamed:SKImageNameToolbarAddInkNote action:@selector(createNewNote:) target:mainController tag:SKInkNote];
            
            [item setLabels:NSLocalizedString(@"Add Note", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Add New Note", @"Tool tip message")];
            [noteButton setHelp:NSLocalizedString(@"Add New Text Note", @"Tool tip message") forSegment:SKFreeTextNote];
            [noteButton setHelp:NSLocalizedString(@"Add New Anchored Note", @"Tool tip message") forSegment:SKAnchoredNote];
            [noteButton setHelp:NSLocalizedString(@"Add New Circle", @"Tool tip message") forSegment:SKCircleNote];
            [noteButton setHelp:NSLocalizedString(@"Add New Box", @"Tool tip message") forSegment:SKSquareNote];
            [noteButton setHelp:NSLocalizedString(@"Add New Highlight", @"Tool tip message") forSegment:SKHighlightNote];
            [noteButton setHelp:NSLocalizedString(@"Add New Underline", @"Tool tip message") forSegment:SKUnderlineNote];
            [noteButton setHelp:NSLocalizedString(@"Add New Strike Out", @"Tool tip message") forSegment:SKStrikeOutNote];
            [noteButton setHelp:NSLocalizedString(@"Add New Line", @"Tool tip message") forSegment:SKLineNote];
            [noteButton setHelp:NSLocalizedString(@"Add New Freehand", @"Tool tip message") forSegment:SKInkNote];
            [noteButton setSegmentStyle:NSSegmentStyleSeparated];
            [item setView:noteButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarToolModeItemIdentifier]) {
            
            menu = [NSMenu menu];
            [menu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") imageNamed:SKImageNameTextNote action:@selector(changeAnnotationMode:) target:mainController tag:SKFreeTextNote];
            [menu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") imageNamed:SKImageNameAnchoredNote action:@selector(changeAnnotationMode:) target:mainController tag:SKAnchoredNote];
            [menu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") imageNamed:SKImageNameCircleNote action:@selector(changeAnnotationMode:) target:mainController tag:SKCircleNote];
            [menu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") imageNamed:SKImageNameSquareNote action:@selector(changeAnnotationMode:) target:mainController tag:SKSquareNote];
            [menu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") imageNamed:SKImageNameHighlightNote action:@selector(changeAnnotationMode:) target:mainController tag:SKHighlightNote];
            [menu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") imageNamed:SKImageNameUnderlineNote action:@selector(changeAnnotationMode:) target:mainController tag:SKUnderlineNote];
            [menu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") imageNamed:SKImageNameStrikeOutNote action:@selector(changeAnnotationMode:) target:mainController tag:SKStrikeOutNote];
            [menu addItemWithTitle:NSLocalizedString(@"Line", @"Menu item title") imageNamed:SKImageNameLineNote action:@selector(changeAnnotationMode:) target:mainController tag:SKLineNote];
            [menu addItemWithTitle:NSLocalizedString(@"Freehand", @"Menu item title") imageNamed:SKImageNameInkNote action:@selector(changeAnnotationMode:) target:mainController tag:SKInkNote];
            [toolModeButton setMenu:menu forSegment:SKNoteToolMode];
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Tool Mode", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Text Tool", @"Menu item title") action:@selector(changeToolMode:) target:mainController tag:SKTextToolMode];
            [menu addItemWithTitle:NSLocalizedString(@"Scroll Tool", @"Menu item title") action:@selector(changeToolMode:) target:mainController tag:SKMoveToolMode];
            [menu addItemWithTitle:NSLocalizedString(@"Magnify Tool", @"Menu item title") action:@selector(changeToolMode:) target:mainController tag:SKMagnifyToolMode];
            [menu addItemWithTitle:NSLocalizedString(@"Select Tool", @"Menu item title") action:@selector(changeToolMode:) target:mainController tag:SKSelectToolMode];
            [menu addItem:[NSMenuItem separatorItem]];
            [menu addItemWithTitle:NSLocalizedString(@"Text Note Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKFreeTextNote];
            [menu addItemWithTitle:NSLocalizedString(@"Anchored Note Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKAnchoredNote];
            [menu addItemWithTitle:NSLocalizedString(@"Circle Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKCircleNote];
            [menu addItemWithTitle:NSLocalizedString(@"Box Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKSquareNote];
            [menu addItemWithTitle:NSLocalizedString(@"Highlight Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKHighlightNote];
            [menu addItemWithTitle:NSLocalizedString(@"Underline Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKUnderlineNote];
            [menu addItemWithTitle:NSLocalizedString(@"Strike Out Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKStrikeOutNote];
            [menu addItemWithTitle:NSLocalizedString(@"Line Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKLineNote];
            [menu addItemWithTitle:NSLocalizedString(@"Freehand Tool", @"Menu item title") action:@selector(changeAnnotationMode:) target:mainController tag:SKInkNote];
            
            [item setLabels:NSLocalizedString(@"Tool Mode", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Tool Mode", @"Tool tip message")];
            [toolModeButton setHelp:NSLocalizedString(@"Text Tool", @"Tool tip message") forSegment:SKTextToolMode];
            [toolModeButton setHelp:NSLocalizedString(@"Scroll Tool", @"Tool tip message") forSegment:SKMoveToolMode];
            [toolModeButton setHelp:NSLocalizedString(@"Magnify Tool", @"Tool tip message") forSegment:SKMagnifyToolMode];
            [toolModeButton setHelp:NSLocalizedString(@"Select Tool", @"Tool tip message") forSegment:SKSelectToolMode];
            [toolModeButton setHelp:NSLocalizedString(@"Note Tool", @"Tool tip message") forSegment:SKNoteToolMode];
            [item setView:toolModeButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarHighlightersIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Highlight Tool", @"Menu item title") action:@selector(toggleHighlightersPane:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Highlight Tool", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Highlight Tool", @"Tool tip message")];
            [item setView:highlightersButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarSingleTwoUpItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Single/Two Pages", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Single Page", @"Menu item title") action:@selector(changeDisplaySinglePages:) target:mainController tag:kPDFDisplaySinglePage];
            [menu addItemWithTitle:NSLocalizedString(@"Two Pages", @"Menu item title") action:@selector(changeDisplaySinglePages:) target:mainController tag:kPDFDisplayTwoUp];
            
            [item setLabels:NSLocalizedString(@"Single/Two Pages", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Single/Two Pages", @"Tool tip message")];
            [singleTwoUpButton setHelp:NSLocalizedString(@"Single Page", @"Tool tip message") forSegment:0];
            [singleTwoUpButton setHelp:NSLocalizedString(@"Two Pages", @"Tool tip message") forSegment:1];
            [item setView:singleTwoUpButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarContinuousItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Continuous", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Non Continuous", @"Menu item title") action:@selector(changeDisplayContinuous:) target:mainController tag:kPDFDisplaySinglePage];
            [menu addItemWithTitle:NSLocalizedString(@"Continuous", @"Menu item title") action:@selector(changeDisplayContinuous:) target:mainController tag:kPDFDisplaySinglePageContinuous];
            
            [item setLabels:NSLocalizedString(@"Continuous", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Continuous", @"Tool tip message")];
            [continuousButton setHelp:NSLocalizedString(@"Non Continuous", @"Tool tip message") forSegment:0];
            [continuousButton setHelp:NSLocalizedString(@"Continuous", @"Tool tip message") forSegment:1];
            [item setView:continuousButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarDisplayModeItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Display Mode", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Single Page", @"Menu item title") action:@selector(changeDisplayMode:) target:mainController tag:kPDFDisplaySinglePage];
            [menu addItemWithTitle:NSLocalizedString(@"Single Page Continuous", @"Menu item title") action:@selector(changeDisplayMode:) target:mainController tag:kPDFDisplaySinglePageContinuous];
            [menu addItemWithTitle:NSLocalizedString(@"Two Pages", @"Menu item title") action:@selector(changeDisplayMode:) target:mainController tag:kPDFDisplayTwoUp];
            [menu addItemWithTitle:NSLocalizedString(@"Two Pages Continuous", @"Menu item title") action:@selector(changeDisplayMode:) target:mainController tag:kPDFDisplayTwoUpContinuous];
            [menu addItemWithTitle:NSLocalizedString(@"Horizontal Continuous", @"Menu item title") action:@selector(changeDisplayMode:) target:mainController tag:4];

            [item setLabels:NSLocalizedString(@"Display Mode", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Display Mode", @"Tool tip message")];
            [displayModeButton setHelp:NSLocalizedString(@"Single Page", @"Tool tip message") forSegment:kPDFDisplaySinglePage];
            [displayModeButton setHelp:NSLocalizedString(@"Single Page Continuous", @"Tool tip message") forSegment:kPDFDisplaySinglePageContinuous];
            [displayModeButton setHelp:NSLocalizedString(@"Two Pages", @"Tool tip message") forSegment:kPDFDisplayTwoUp];
            [displayModeButton setHelp:NSLocalizedString(@"Two Pages Continuous", @"Tool tip message") forSegment:kPDFDisplayTwoUpContinuous];
            [displayModeButton setHelp:NSLocalizedString(@"Horizontal Continuous", @"Tool tip message") forSegment:4];
            
            [item setView:displayModeButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarDisplayDirectionItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Direction", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Vertical", @"Menu item title") action:@selector(changeDisplayDirection:) target:mainController tag:0];
            [menu addItemWithTitle:NSLocalizedString(@"Horizontal", @"Menu item title") action:@selector(changeDisplayDirection:) target:mainController tag:1];
            
            [item setLabels:NSLocalizedString(@"Direction", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Direction", @"Tool tip message")];
            [displayDirectionButton setHelp:NSLocalizedString(@"Vertical", @"Tool tip message") forSegment:0];
            [displayDirectionButton setHelp:NSLocalizedString(@"Horizontal", @"Tool tip message") forSegment:1];
            [item setView:displayDirectionButton];
            [item setMenuFormRepresentation:menuItem];
            
            } else if ([identifier isEqualToString:SKDocumentToolbarDisplayDirectionItemIdentifier]) {
                
                menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Direction", @"Toolbar item label")];
                menu = [menuItem submenu];
                [menu addItemWithTitle:NSLocalizedString(@"Vertical", @"Menu item title") action:@selector(changeDisplayDirection:) target:mainController tag:0];
                [menu addItemWithTitle:NSLocalizedString(@"Horizontal", @"Menu item title") action:@selector(changeDisplayDirection:) target:mainController tag:1];
                
                [item setLabels:NSLocalizedString(@"Direction", @"Toolbar item label")];
                [item setToolTip:NSLocalizedString(@"Direction", @"Tool tip message")];
                [displayDirectionButton setHelp:NSLocalizedString(@"Vertical", @"Tool tip message") forSegment:0];
                [displayDirectionButton setHelp:NSLocalizedString(@"Horizontal", @"Tool tip message") forSegment:1];
                [item setView:displayDirectionButton];
                [item setMenuFormRepresentation:menuItem];
                
        } else if ([identifier isEqualToString:SKDocumentToolbarDisplaysRTLItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Right to Left", @"Menu item title") action:@selector(toggleDisplaysRTL:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Right to Left", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Right to Left", @"Tool tip message")];
            [item setView:displaysRTLButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarBookModeItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Book Mode", @"Menu item title") action:@selector(toggleDisplaysAsBook:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Book Mode", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Book Mode", @"Tool tip message")];
            [item setView:bookModeButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPageBreaksItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Page Breaks", @"Menu item title") action:@selector(toggleDisplayPageBreaks:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Page Breaks", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Page Breaks", @"Tool tip message")];
            [item setView:pageBreaksButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarDisplayBoxItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Display Box", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Media Box", @"Menu item title") action:@selector(changeDisplayBox:) target:mainController tag:kPDFDisplayBoxMediaBox];
            [menu addItemWithTitle:NSLocalizedString(@"Crop Box", @"Menu item title") action:@selector(changeDisplayBox:) target:mainController tag:kPDFDisplayBoxCropBox];
            
            [item setLabels:NSLocalizedString(@"Display Box", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Display Box", @"Tool tip message")];
            [item setView:displayBoxButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarColorSwatchItemIdentifier]) {
            
            NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:SKUnarchiveColorArrayTransformerName];
            NSDictionary *options = @{NSValueTransformerBindingOption:transformer};
            [colorSwatch bind:@"colors" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:SKSwatchColorsKey] options:options];
            [colorSwatch sizeToFit];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleColorSwatchColorsChangedNotification:)
                                                         name:SKColorSwatchColorsChangedNotification object:colorSwatch];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleColorSwatchFrameChangedNotification:)
                                                         name:NSViewFrameDidChangeNotification object:colorSwatch];

            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Favorite Colors", @"Toolbar item label")];
            
            [item setLabels:NSLocalizedString(@"Favorite Colors", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Favorite Colors", @"Tool tip message")];
            [item setView:colorSwatch];
            [item setMenuFormRepresentation:menuItem];
            [self handleColorSwatchFrameChangedNotification:nil];
            [self handleColorSwatchColorsChangedNotification:nil];

        } else if ([identifier isEqualToString:SKDocumentToolbarShareItemIdentifier]) {
            
            shareMenuController = [[SKShareMenuController alloc] initForDocument:[[self mainController] document]];
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Share", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu setDelegate:shareMenuController];
            
            menu = [[NSMenu alloc] init];
            [menu setDelegate:shareMenuController];
            [shareButton setMenu:menu forSegment:0];
            
            [item setLabels:NSLocalizedString(@"Share", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Share", @"Toolbar item label")];
            [item setView:shareButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPacerItemIdentifier]) {
            
            NSToolbarItemGroup *group = [[NSToolbarItemGroup alloc] initWithItemIdentifier:identifier];
            [toolbarItems setObject:group forKey:identifier];
            item = (id)group;
            
            [pacerButton sizeToFit];
            NSRect frame;
            frame = [pacerButton frame];
            if (NSHeight(frame) < 25.0) {
                frame.size.height = 25.0;
                [pacerButton setFrame:frame];
            }
            frame = [pacerSpeedField frame];
            frame.size.height = NSHeight([pacerButton frame]);
            [pacerSpeedField setFrame:frame];
            frame = [pacerSpeedStepper frame];
            frame.origin.y = ceil(NSMidY([pacerButton frame]) - 0.5 * NSHeight([pacerSpeedStepper frame]));
            [pacerSpeedStepper setFrame:frame];
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Pacer", @"Toolbar item label")];
            menu = [menuItem submenu];
            [menu addItemWithTitle:NSLocalizedString(@"Start Pacer", @"Menu item title") action:@selector(togglePacer:) target:mainController tag:0];
            [menu addItemWithTitle:NSLocalizedString(@"Pacer Speed", @"Menu item title") action:@selector(choosePacerSpeed:) target:self tag:0];
            [menu addItemWithTitle:NSLocalizedString(@"Faster", @"Menu item title") action:@selector(changePacerSpeed:) target:mainController tag:0];
            [menu addItemWithTitle:NSLocalizedString(@"Slower", @"Menu item title") action:@selector(changePacerSpeed:) target:mainController tag:-1];
            
            [item setLabel:NSLocalizedString(@"Pacer", @"Toolbar item label")];
            [item setPaletteLabel:NSLocalizedString(@"Pacer", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Pacer", @"Tool tip message")];
            [pacerButton setHelp:NSLocalizedString(@"Pacer", @"Tool tip message") forSegment:0];
            [pacerSpeedField setToolTip:NSLocalizedString(@"Pacer Speed", @"Tool tip message")];
            [pacerSpeedStepper setToolTip:NSLocalizedString(@"Pacer Speed", @"Tool tip message")];
            [item setMenuFormRepresentation:menuItem];
            
            NSToolbarItem *item1 = [[SKToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarPacerButtonItemIdentifier];
            [item1 setView:pacerButton];
            NSToolbarItem *item2 = [[SKToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarPacerSpeedFieldItemIdentifier];
            [item2 setView:pacerSpeedField];
            NSToolbarItem *item3 = [[SKToolbarItem alloc] initWithItemIdentifier:SKDocumentToolbarPacerSpeedStepperItemIdentifier];
            [item3 setView:pacerSpeedStepper];
            [group setSubitems:@[item1, item2, item3]];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarColorsItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Colors", @"Menu item title") action:@selector(orderFrontColorPanel:) target:nil];
            
            [item setLabels:NSLocalizedString(@"Colors", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Colors", @"Tool tip message")];
            [item setView:colorsButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarFontsItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Fonts", @"Menu item title") action:@selector(orderFrontFontPanel:) target:nil];
            
            [item setLabels:NSLocalizedString(@"Fonts", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Fonts", @"Tool tip message")];
            [item setView:fontsButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarLinesItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Lines", @"Menu item title") action:@selector(orderFrontLineInspector:) target:nil];
            
            [item setLabels:NSLocalizedString(@"Lines", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Lines", @"Tool tip message")];
            [item setView:linesButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarInfoItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Info", @"Menu item title") action:@selector(getInfo:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Info", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Get Document Info", @"Tool tip message")];
            [item setView:infoButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarContentsPaneItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithSubmenuAndTitle:NSLocalizedString(@"Contents Pane", @"Toolbar item label")];
            
            NSMenu *menu = [[NSMenu alloc] init];
            [menu setAutoenablesItems:FALSE];
            [menu addItemWithTitle:NSLocalizedString(@"Hide Sidebar", @"Menu item title") action:@selector(closeLeftSidebar:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Thumbnails", @"Menu item title") action:@selector(toggleLeftThumbnails:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Table of Contents", @"Menu item title") action:@selector(toggleLeftTableOfContents:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Notes", @"Menu item title") action:@selector(toggleLeftNotes:) target:mainController];
            [menu addItemWithTitle:NSLocalizedString(@"Snapshots", @"Menu item title") action:@selector(toggleLeftSnapshots:) target:mainController];
            [menu.itemArray[0] setEnabled:FALSE];
            
            [item setLabels:NSLocalizedString(@"Contents Pane", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Toggle Contents Pane", @"Tool tip message")];
            [leftPaneButton setMenu:menu forSegment:0];
            [leftPaneButton setShowsMenuIndicator:true forSegment:0];
            [item setView:leftPaneButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarNotesPaneItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Notes Pane", @"Menu item title") action:@selector(toggleRightSidePane:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Notes Pane", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Toggle Notes Pane", @"Tool tip message")];
            [item setView:rightPaneButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarSplitPDFItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Notes Pane", @"Menu item title") action:@selector(toggleSplitPDF:) target:mainController];
            
            [item setLabels:NSLocalizedString(@"Split PDF", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Toggle Split PDF", @"Tool tip message")];
            [item setView:splitPDFButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarPrintItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Print", @"Menu item title") action:@selector(printDocument:) target:nil];
            
            [item setLabels:NSLocalizedString(@"Print", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Print Document", @"Tool tip message")];
            [item setView:printButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:SKDocumentToolbarCustomizeItemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Customize", @"Menu item title") action:@selector(runToolbarCustomizationPalette:) target:nil];
            
            [item setLabels:NSLocalizedString(@"Customize", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Customize Toolbar", @"Tool tip message")];
            [item setView:customizeButton];
            [item setMenuFormRepresentation:menuItem];
            
        } else if ([identifier isEqualToString:searchField.itemIdentifier]) {
            
            menuItem = [NSMenuItem menuItemWithTitle:NSLocalizedString(@"Search", @"Menu item title") action:@selector(runToolbarCustomizationPalette:) target:nil];
            [[searchField searchField] setRecentsAutosaveName:SKRecentsAutosaveName];
            [[searchField searchField] setSearchMenuTemplate:menu];
            [[searchField searchField] setPlaceholderString:NSLocalizedString(@"Search", @"placeholder")];
            
            [searchField setPreferredWidthForSearchField:300.0];
            [searchField setAction:@selector(search:)];
            [searchField setTarget:mainController];
            
            item = searchField;
            [item setLabels:NSLocalizedString(@"Search", @"Toolbar item label")];
            [item setToolTip:NSLocalizedString(@"Search", @"Tool tip message")];
            [item setMenuFormRepresentation:menuItem];
            
        }
    }
    
    return item;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)willBeInserted {

    NSToolbarItem *item = [self toolbarItemForItemIdentifier:itemIdent];
    
    if (willBeInserted == NO) {
        if ([itemIdent isEqualToString:SKDocumentToolbarShareItemIdentifier])
             [[shareButton menuForSegment:0] removeAllItems];
        item = [item copy];
        [item setEnabled:YES];
        if ([[item view] respondsToSelector:@selector(setEnabled:)])
            [(NSControl *)[item view] setEnabled:YES];
        if ([[item view] respondsToSelector:@selector(setEnabledForAllSegments:)])
            [(NSSegmentedControl *)[item view] setEnabledForAllSegments:YES];
    }
    
    return item;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[SKDocumentToolbarContentsPaneItemIdentifier,
        NSToolbarSidebarTrackingSeparatorItemIdentifier,
        SKDocumentToolbarZoomInOutItemIdentifier,
        SKDocumentToolbarHighlightersIdentifier,
        SKDocumentToolbarInfoItemIdentifier,
        searchField.itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[SKDocumentToolbarPreviousNextItemIdentifier,
        SKDocumentToolbarPageNumberItemIdentifier,
        SKDocumentToolbarZoomInOutItemIdentifier,
        SKDocumentToolbarZoomActualItemIdentifier,
        SKDocumentToolbarZoomToFitItemIdentifier,
        SKDocumentToolbarZoomToSelectionItemIdentifier,
        SKDocumentToolbarAutoScalesItemIdentifier,
        SKDocumentToolbarScaleItemIdentifier,
        SKDocumentToolbarHighlightersIdentifier,
        SKDocumentToolbarDisplayModeItemIdentifier,
        SKDocumentToolbarSingleTwoUpItemIdentifier,
        SKDocumentToolbarContinuousItemIdentifier,
        SKDocumentToolbarDisplayDirectionItemIdentifier,
        SKDocumentToolbarBookModeItemIdentifier,
        SKDocumentToolbarDisplaysRTLItemIdentifier,
        SKDocumentToolbarPageBreaksItemIdentifier,
        SKDocumentToolbarDisplayBoxItemIdentifier,
        SKDocumentToolbarFullScreenItemIdentifier,
        SKDocumentToolbarPresentationItemIdentifier,
        SKDocumentToolbarContentsPaneItemIdentifier,
        SKDocumentToolbarSplitPDFItemIdentifier,
        SKDocumentToolbarRotateRightItemIdentifier,
        SKDocumentToolbarRotateLeftItemIdentifier,
        SKDocumentToolbarRotateLeftRightItemIdentifier,
        SKDocumentToolbarCropItemIdentifier,
        SKDocumentToolbarToolModeItemIdentifier,
        SKDocumentToolbarColorSwatchItemIdentifier,
        SKDocumentToolbarShareItemIdentifier,
        SKDocumentToolbarPacerItemIdentifier,
        SKDocumentToolbarInfoItemIdentifier,
        SKDocumentToolbarPrintItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier,
        NSToolbarSpaceItemIdentifier,
        NSToolbarSidebarTrackingSeparatorItemIdentifier,
        SKDocumentToolbarCustomizeItemIdentifier
    ];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem {
    NSString *identifier = [toolbarItem itemIdentifier];
    
    if ([[toolbarItem toolbar] customizationPaletteIsRunning]) {
        return NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarZoomActualItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO && ([mainController.pdfView  autoScales] || fabs([mainController.pdfView scaleFactor] - 1.0) > 0.0);
    } else if ([identifier isEqualToString:SKDocumentToolbarZoomToFitItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO && [mainController.pdfView autoScales] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarZoomToSelectionItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO && (NSIsEmptyRect([mainController.pdfView currentSelectionRect]) == NO || [mainController.pdfView toolMode] != SKSelectToolMode);
    } else if ([identifier isEqualToString:SKDocumentToolbarZoomInOutItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarZoomInActualOutItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarAutoScalesItemIdentifier] ||
               [identifier isEqualToString:SKDocumentToolbarScaleItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarPageNumberItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarDisplayBoxItemIdentifier] || [identifier isEqualToString:SKDocumentToolbarDisplayModeItemIdentifier] || [identifier isEqualToString:SKDocumentToolbarSingleTwoUpItemIdentifier] || [identifier isEqualToString:SKDocumentToolbarContinuousItemIdentifier] || [identifier isEqualToString:SKDocumentToolbarPageBreaksItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarDisplayDirectionItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO && [mainController.pdfView displayMode] == kPDFDisplaySinglePageContinuous;
    } else if ([identifier isEqualToString:SKDocumentToolbarDisplaysRTLItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarBookModeItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarToolModeItemIdentifier]) {
        return [mainController hasOverview] == NO;
    } else if ([identifier isEqualToString:SKDocumentToolbarNewTextNoteItemIdentifier] || [identifier isEqualToString:SKDocumentToolbarNewCircleNoteItemIdentifier] || [identifier isEqualToString:SKDocumentToolbarNewLineItemIdentifier]) {
        return [mainController hasOverview] == NO && [mainController.pdfView canSelectNote];
    } else if ([identifier isEqualToString:SKDocumentToolbarNewMarkupItemIdentifier]) {
        return [mainController hasOverview] == NO && [mainController.pdfView canSelectNote];
    } else if ([identifier isEqualToString:SKDocumentToolbarNewLineItemIdentifier]) {
        return [mainController hasOverview] == NO && [mainController.pdfView canSelectNote];
    } else if ([identifier isEqualToString:SKDocumentToolbarNewNoteItemIdentifier]) {
        return [mainController hasOverview] == NO && [mainController.pdfView canSelectNote];
    } else if ([identifier isEqualToString:SKDocumentToolbarFullScreenItemIdentifier]) {
        return [mainController canEnterFullscreen] || [mainController canExitFullscreen];
    } else if ([identifier isEqualToString:SKDocumentToolbarPresentationItemIdentifier]) {
        return [mainController canEnterPresentation] || [mainController canExitPresentation];
    } else if ([identifier isEqualToString:SKDocumentToolbarRotateRightItemIdentifier] || [identifier isEqualToString:SKDocumentToolbarRotateLeftItemIdentifier] || [identifier isEqualToString:SKDocumentToolbarRotateLeftRightItemIdentifier] || [identifier isEqualToString:SKDocumentToolbarCropItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO;
    } else if ([identifier isEqualToString:NSToolbarPrintItemIdentifier]) {
        return [mainController.pdfView.document isLocked] == NO;
    }
    return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(chooseScale:)) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if (action == @selector(zoomActualPhysical:)) {
        return [mainController.pdfView.document isLocked] == NO && [mainController hasOverview] == NO;
    } else if (action == @selector(createNewTextNote:)) {
        [menuItem setState:[[textNoteButton cell] tagForSegment:0] == [menuItem tag] ? NSControlStateValueOn : NSOffState];
        return [mainController interactionMode] != SKPresentationMode && [mainController hasOverview] == NO && [mainController.pdfView.document allowsNotes] && ([mainController.pdfView toolMode] == SKTextToolMode || [mainController.pdfView toolMode] == SKNoteToolMode) && [mainController.pdfView hideNotes] == NO;
    } else if (action == @selector(createNewCircleNote:)) {
        [menuItem setState:[[circleNoteButton cell] tagForSegment:0] == [menuItem tag] ? NSControlStateValueOn : NSOffState];
        return [mainController hasOverview] == NO && [mainController.pdfView canSelectNote];
    } else if (action == @selector(createNewMarkupNote:)) {
        [menuItem setState:[[markupNoteButton cell] tagForSegment:0] == [menuItem tag] ? NSControlStateValueOn : NSOffState];
        return [mainController hasOverview] == NO && [mainController.pdfView canSelectNote];
    } else if (action == @selector(toggleFullScreen:)) {
        return [mainController canEnterFullscreen] || [mainController canExitFullscreen];
    } else if (action == @selector(togglePresentation:)) {
        return [mainController canEnterPresentation] || [mainController canExitPresentation];
    }
    return YES;
}

- (void)handleColorSwatchColorsChangedNotification:(NSNotification *)notification {
    NSToolbarItem *toolbarItem = [self toolbarItemForItemIdentifier:SKDocumentToolbarColorSwatchItemIdentifier];
    NSMenu *menu = [[toolbarItem menuFormRepresentation] submenu];
    
    NSSize size = NSMakeSize(16.0, 16.0);
    
    [menu removeAllItems];
    
    for (NSColor *color in [colorSwatch colors]) {
        NSMenuItem *item = [menu addItemWithTitle:@"" action:@selector(selectColor:) target:self];
        
        NSImage *image = [NSImage imageWithSize:size flipped:NO drawingHandler:^(NSRect rect){
                [color drawSwatchInRoundedRect:rect];
                return YES;
            }];
        [image setAccessibilityDescription:[color accessibilityValue]];
        [item setRepresentedObject:color];
        [item setImage:image];
    }
}

- (void)handleColorSwatchFrameChangedNotification:(NSNotification *)notification {
    if (@available(macOS 11.0, *))
        return;
    NSToolbarItem *toolbarItem = [self toolbarItemForItemIdentifier:SKDocumentToolbarColorSwatchItemIdentifier];
    NSSize size = [colorSwatch bounds].size;
    [toolbarItem setMinSize:size];
    [toolbarItem setMaxSize:size];
}

- (IBAction)goToPreviousNextFirstLastPage:(id)sender {
    NSInteger tag = [sender selectedTag];
    if (tag == -1)
        [mainController.pdfView goToPreviousPage:sender];
    else if (tag == 1)
        [mainController.pdfView goToNextPage:sender];
    else if (tag == -2)
        [mainController.pdfView goToFirstPage:sender];
    else if (tag == 2)
        [mainController.pdfView goToLastPage:sender];
}

- (IBAction)goBackOrForward:(id)sender {
    if ([sender selectedTag] == 1)
        [mainController.pdfView goForward:sender];
    else
        [mainController.pdfView goBack:sender];
}

- (IBAction)changeScaleFactor:(id)sender {
    [mainController.pdfView setScaleFactor:[sender doubleValue]];
    [mainController.pdfView setAutoScales:NO];
}

- (IBAction)chooseScale:(id)sender {
    SKTextFieldSheetController *scaleSheetController = [[SKTextFieldSheetController alloc] initWithWindowNibName:@"ScaleSheet"];
    
    [(NSNumberFormatter *)[[scaleSheetController textField] formatter] setMinimum:[NSNumber numberWithDouble:[mainController.pdfView minScaleFactor]]];
    [(NSNumberFormatter *)[[scaleSheetController textField] formatter] setMaximum:[NSNumber numberWithDouble:[mainController.pdfView maxScaleFactor]]];
    [[scaleSheetController textField] setDoubleValue:[mainController.pdfView scaleFactor]];
    
    [scaleSheetController beginSheetModalForWindow:[mainController window] completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK)
                [mainController.pdfView setScaleFactor:[[scaleSheetController textField] doubleValue]];
        }];
}

- (IBAction)zoomActualPhysical:(id)sender {
    ([NSEvent standardModifierFlags] & NSEventModifierFlagOption) ? [mainController.pdfView setPhysicalScaleFactor:1.0] : [mainController.pdfView setScaleFactor:1.0];
}

- (IBAction)zoomInActualOut:(id)sender {
    NSInteger tag = [sender selectedTag];
    if (tag == -1)
        [mainController.pdfView zoomOut:sender];
    else if (tag == 0)
        ([NSEvent standardModifierFlags] & NSEventModifierFlagOption) ? [mainController.pdfView setPhysicalScaleFactor:1.0] : [mainController.pdfView setScaleFactor:1.0];
    else if (tag == 1)
        [mainController.pdfView zoomIn:sender];
}

- (IBAction)zoomToFit:(id)sender {
    [mainController doZoomToFit:sender];
}

- (IBAction)zoomToSelection:(id)sender {
    [mainController doZoomToSelection:sender];
}

- (IBAction)changeAutoScales:(id)sender {
    [mainController toggleAutoScale:sender];
}

- (IBAction)rotateAllLeftRight:(id)sender {
    if ([sender selectedTag] == 1)
        [mainController rotateAllRight:sender];
    else
        [mainController rotateAllLeft:sender];
}

- (IBAction)cropAll:(id)sender {
    [mainController cropAll:sender];
}

- (IBAction)toggleFullscreen:(id)sender {
    [mainController toggleFullscreen:sender];
}

- (IBAction)togglePresentation:(id)sender {
    [mainController togglePresentation:sender];
}

- (IBAction)toggleLeftSidebar:(id)sender {
    [mainController toggleLeftSidebar:sender];
}

- (IBAction)toggleLeftSidePane:(id)sender {
    [mainController toggleLeftSidePane:sender];
}

- (IBAction)toggleRightSidePane:(id)sender {
    [mainController toggleRightSidePane:sender];
}

- (IBAction)toggleSplitPDF:(id)sender {
    [mainController toggleSplitPDF:sender];
}

- (IBAction)changeDisplayBox:(id)sender {
    [mainController.pdfView setDisplayBoxAndRewind:[sender selectedTag]];
}

- (IBAction)changeDisplaySinglePages:(id)sender {
    PDFDisplayMode displayMode = ([mainController.pdfView displayMode] & ~kPDFDisplayTwoUp) | [sender selectedTag];
    if ([mainController.pdfView displaysHorizontally] && displayMode == kPDFDisplaySinglePageContinuous)
        displayMode = kPDFDisplayHorizontalContinuous;
    [mainController.pdfView setExtendedDisplayModeAndRewind:displayMode];
}

- (IBAction)changeDisplayContinuous:(id)sender {
    PDFDisplayMode displayMode = ([mainController.pdfView displayMode] & ~kPDFDisplaySinglePageContinuous) | [sender selectedTag];
    if ([mainController.pdfView displaysHorizontally] && displayMode == kPDFDisplaySinglePageContinuous)
        displayMode = kPDFDisplayHorizontalContinuous;
    [mainController.pdfView setExtendedDisplayModeAndRewind:displayMode];
}

- (IBAction)changeDisplayMode:(id)sender {
    PDFDisplayMode displayMode = [sender selectedTag];
    [mainController.pdfView setExtendedDisplayModeAndRewind:displayMode];
}

- (IBAction)changeDisplayDirection:(id)sender {
    BOOL horizontally = [sender selectedTag] == 1;
    [mainController.pdfView setDisplaysHorizontallyAndRewind:horizontally];
}

- (IBAction)changeDisplaysRTL:(id)sender {
    [mainController.pdfView setDisplaysRTLAndRewind:NO == [mainController.pdfView displaysRTL]];
    [mainController.pdfView setExtendedDisplayMode:[mainController.pdfView displayMode] | kPDFDisplayTwoUp];
}

- (IBAction)changeBookMode:(id)sender {
    [mainController.pdfView setDisplaysAsBookAndRewind:NO == [mainController.pdfView displaysAsBook]];
    [mainController.pdfView setExtendedDisplayMode:[mainController.pdfView displayMode] | kPDFDisplayTwoUp];
}

- (IBAction)changePageBreaks:(id)sender {
    [mainController.pdfView setDisplaysPageBreaks:NO == [mainController.pdfView displaysPageBreaks]];
}

- (void)createNewNoteWithType:(NSInteger)type forButton:(NSSegmentedControl *)button {
    if ([mainController.pdfView canSelectNote]) {
        [mainController.pdfView addAnnotationWithType:type];
        if (type != [[button cell] tagForSegment:0]) {
            [[button cell] setTag:type forSegment:0];
            [button setImage:[NSImage imageNamed:addNoteToolImageNames[type]] forSegment:0];
        }
    } else NSBeep();
}

- (void)createNewTextNote:(id)sender {
    [self createNewNoteWithType:[sender tag] forButton:textNoteButton];
}

- (void)createNewCircleNote:(id)sender {
    [self createNewNoteWithType:[sender tag] forButton:circleNoteButton];
}

- (void)createNewMarkupNote:(id)sender {
    [self createNewNoteWithType:[sender tag] forButton:markupNoteButton];
}

- (void)createNewLineNote:(id)sender {
    [self createNewNoteWithType:[sender tag] forButton:lineNoteButton];
}

- (IBAction)createNewNote:(id)sender {
    if ([mainController.pdfView canSelectNote]) {
        NSInteger type = [sender selectedTag];
        [mainController.pdfView addAnnotationWithType:type];
    } else NSBeep();
}

- (IBAction)changeToolMode:(id)sender {
    NSInteger newToolMode = [sender selectedTag];
    [mainController.pdfView setToolMode:newToolMode];
}

- (IBAction)toggleHighlightersPane:(id)sender {
    [mainController toggleHighlightersPane:sender];
}

- (IBAction)selectColor:(id)sender {
    PDFAnnotation *annotation = [mainController.pdfView currentAnnotation];
    NSColor *newColor = [sender respondsToSelector:@selector(color)] ? [sender color] : [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    BOOL isShift = ([NSEvent standardModifierFlags] & NSEventModifierFlagShift) != 0;
    BOOL isAlt = ([NSEvent standardModifierFlags] & NSEventModifierFlagOption) != 0;
    if (isAlt == NO && [sender respondsToSelector:@selector(isAlternate)])
        isAlt = [sender isAlternate];
    if ([annotation isSkimNote]) {
        [annotation setColor:newColor alternate:isAlt updateDefaults:isShift];
    } else {
        NSString *defaultKey = [mainController.pdfView currentColorDefaultKeyForAlternate:isAlt];
        if (defaultKey)
            [[NSUserDefaults standardUserDefaults] setColor:newColor forKey:defaultKey];
    }
}

- (IBAction)togglePacer:(id)sender {
    [mainController togglePacer:sender];
}

- (IBAction)choosePacerSpeed:(id)sender {
    SKTextFieldSheetController *speedSheetController = [[SKTextFieldSheetController alloc] initWithWindowNibName:@"SpeedSheet"];
    
    [[speedSheetController textField] setObjectValue:[NSNumber numberWithDouble:[mainController.pdfView pacerSpeed]]];
    
    [speedSheetController beginSheetModalForWindow:[mainController window] completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK)
                [mainController.pdfView setPacerSpeed:[[speedSheetController textField] doubleValue]];
        }];
}

#pragma mark Notifications

- (void)handleChangedHistoryNotification:(NSNotification *)notification {
    [backForwardButton setEnabled:[mainController.pdfView canGoBack] forSegment:0];
    [backForwardButton setEnabled:[mainController.pdfView canGoForward] forSegment:1];
}

- (void)handlePageChangedNotification:(NSNotification *)notification {
    [previousNextPageButton setEnabled:[mainController.pdfView canGoToPreviousPage] forSegment:0];
    [previousNextPageButton setEnabled:[mainController.pdfView canGoToNextPage] forSegment:1];
    [previousPageButton setEnabled:[mainController.pdfView canGoToFirstPage] forSegment:0];
    [previousPageButton setEnabled:[mainController.pdfView canGoToPreviousPage] forSegment:1];
    [nextPageButton setEnabled:[mainController.pdfView canGoToNextPage] forSegment:0];
    [nextPageButton setEnabled:[mainController.pdfView canGoToLastPage] forSegment:1];
    [previousNextFirstLastPageButton setEnabled:[mainController.pdfView canGoToFirstPage] forSegment:0];
    [previousNextFirstLastPageButton setEnabled:[mainController.pdfView canGoToPreviousPage] forSegment:1];
    [previousNextFirstLastPageButton setEnabled:[mainController.pdfView canGoToNextPage] forSegment:2];
    [previousNextFirstLastPageButton setEnabled:[mainController.pdfView canGoToLastPage] forSegment:3];
}

- (void)handleScaleChangedNotification:(NSNotification *)notification {
    [scaleField setDoubleValue:[mainController.pdfView scaleFactor]];
    
    [zoomInOutButton setEnabled:[mainController.pdfView canZoomOut] forSegment:0];
    [zoomInOutButton setEnabled:[mainController.pdfView canZoomIn] forSegment:1];
    [zoomInActualOutButton setEnabled:[mainController.pdfView canZoomOut] forSegment:0];
    [zoomInActualOutButton setEnabled:[mainController.pdfView.document isLocked] == NO forSegment:1];
    [zoomInActualOutButton setEnabled:[mainController.pdfView canZoomIn] forSegment:2];
    [zoomActualButton setEnabled:[mainController.pdfView.document isLocked] == NO];
    
    [autoScalesButton setSelected:[mainController.pdfView autoScales] forSegment:0];
}

- (void)handleAutoScalesChangedNotification:(NSNotification *)notification {
    [autoScalesButton setSelected:[mainController.pdfView autoScales] forSegment:0];
}

- (void)handleToolModeChangedNotification:(NSNotification *)notification {
    [toolModeButton selectSegmentWithTag:[mainController.pdfView toolMode]];
}

- (void)handleTemporaryToolModeChangedNotification:(NSNotification *)notification {
    SKToolMode toolMode = [mainController.pdfView toolMode];
    NSString *name = nil;
    switch ([mainController.pdfView temporaryToolMode]) {
        case SKZoomToolMode :      name = SKImageNameToolbarZoomToSelection;  break;
        case SKSnapshotToolMode :  name = SKImageNameToolbarSnapshotTool;     break;
        case SKHighlightToolMode : name = SKImageNameToolbarAddHighlightNote; break;
        case SKUnderlineToolMode : name = SKImageNameToolbarAddUnderlineNote; break;
        case SKStrikeOutToolMode : name = SKImageNameToolbarAddStrikeOutNote; break;
        case SKInkToolMode :       name = SKImageNameToolbarAddInkNote;       break;
        case SKNoToolMode:
            switch (toolMode) {
                case SKTextToolMode :    name = SKImageNameToolbarTextTool;    break;
                case SKMoveToolMode :    name = SKImageNameToolbarMoveTool;    break;
                case SKMagnifyToolMode : name = SKImageNameToolbarMagnifyTool; break;
                case SKSelectToolMode :  name = SKImageNameToolbarSelectTool;  break;
                case SKNoteToolMode :    name = noteToolImageNames[mainController.pdfView.annotationMode]; break;
            }
            break;
    }
    [toolModeButton setImage:[NSImage imageNamed:name] forSegment:toolMode];
}

- (void)handleDisplayBoxChangedNotification:(NSNotification *)notification {
    [displayBoxButton selectSegmentWithTag:[mainController.pdfView displayBox]];
}

- (void)handleDisplayModeChangedNotification:(NSNotification *)notification {
    PDFDisplayMode displayMode = [mainController.pdfView displayMode];
    [singleTwoUpButton selectSegmentWithTag:displayMode & kPDFDisplayTwoUp];
    [continuousButton selectSegmentWithTag:displayMode & kPDFDisplaySinglePageContinuous];
    if ([mainController.pdfView displaysHorizontally] && displayMode == kPDFDisplaySinglePageContinuous && [displayModeButton segmentCount] > 4)
        displayMode = kPDFDisplayHorizontalContinuous;
    [displayModeButton selectSegmentWithTag:displayMode];
}

- (void)handleDisplayDirectionChangedNotification:(NSNotification *)notification {
    NSInteger direction = [mainController.pdfView displaysHorizontally] ? 1 : 0;
    [displayDirectionButton selectSegmentWithTag:direction];
    PDFDisplayMode displayMode = [mainController.pdfView displayMode];
    if (direction == 1 && displayMode == kPDFDisplaySinglePageContinuous && [displayModeButton segmentCount] > 4)
        displayMode = kPDFDisplayHorizontalContinuous;
    [displayModeButton selectSegmentWithTag:displayMode];
}

- (void)handleDisplaysRTLChangedNotification:(NSNotification *)notification {
    BOOL displaysRTL = [mainController.pdfView displaysRTL];
    [displaysRTLButton setSelected:displaysRTL forSegment:0];
}

- (void)handleBookModeChangedNotification:(NSNotification *)notification {
    BOOL displaysAsBook = [mainController.pdfView displaysAsBook];
    [bookModeButton setSelected:displaysAsBook forSegment:0];
}

- (void)handlePageBreaksChangedNotification:(NSNotification *)notification {
    BOOL displaysPageBreaks = [mainController.pdfView displaysPageBreaks];
    [pageBreaksButton setSelected:displaysPageBreaks forSegment:0];
}

- (void)handleAnnotationModeChangedNotification:(NSNotification *)notification {
    [toolModeButton setImage:[NSImage imageNamed:noteToolImageNames[[mainController.pdfView annotationMode]]] forSegment:SKNoteToolMode];
}

- (void)handlePacerStartedOrStoppedNotification:(NSNotification *)notification {
    NSString *name = [mainController.pdfView hasPacer] ? SKImageNameToolbarPause : SKImageNameToolbarPlay;
    [pacerButton setImage:[NSImage imageNamed:name] forSegment:0];
}

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(handlePageChangedNotification:) 
                             name:PDFViewPageChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleScaleChangedNotification:) 
                             name:PDFViewScaleChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleBookModeChangedNotification:) 
                             name:SKPDFViewDisplaysAsBookChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handlePageBreaksChangedNotification:)
                             name:SKPDFViewDisplaysPageBreaksChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleAutoScalesChangedNotification:)
                             name:SKPDFViewAutoScalesChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleToolModeChangedNotification:)
                             name:SKPDFViewToolModeChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleAnnotationModeChangedNotification:) 
                             name:SKPDFViewAnnotationModeChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleTemporaryToolModeChangedNotification:)
                             name:SKPDFViewTemporaryToolModeChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handlePacerStartedOrStoppedNotification:)
                             name:SKPDFViewPacerStartedOrStoppedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleDisplayModeChangedNotification:)
                             name:PDFViewDisplayModeChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleDisplayDirectionChangedNotification:)
                             name:SKPDFViewDisplaysHorizontallyChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleDisplaysRTLChangedNotification:)
                             name:SKPDFViewDisplaysRTLChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleDisplayBoxChangedNotification:)
                             name:PDFViewDisplayBoxChangedNotification object:mainController.pdfView];
    [nc addObserver:self selector:@selector(handleChangedHistoryNotification:)
                             name:PDFViewChangedHistoryNotification object:mainController.pdfView];

    [self handleChangedHistoryNotification:nil];
    [self handlePageChangedNotification:nil];
    [self handleScaleChangedNotification:nil];
    [self handleAutoScalesChangedNotification:nil];
    [self handleToolModeChangedNotification:nil];
    [self handleDisplayBoxChangedNotification:nil];
    [self handleDisplayModeChangedNotification:nil];
    [self handleDisplayDirectionChangedNotification:nil];
    [self handleDisplaysRTLChangedNotification:nil];
    [self handleBookModeChangedNotification:nil];
    [self handlePageBreaksChangedNotification:nil];
    [self handleAnnotationModeChangedNotification:nil];
}

@end
