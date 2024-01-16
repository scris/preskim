//
//  SKMainWindowController_Actions.h
//  Skim
//
//  Created by Christiaan Hofman on 2/14/09.
/*
 This software is Copyright (c) 2009
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
#import "SKMainWindowController.h"

NS_ASSUME_NONNULL_BEGIN

@interface SKMainWindowController (Actions)

- (IBAction)changeColor:(nullable id)sender;
- (IBAction)changeFont:(nullable id)sender;
- (IBAction)changeAttributes:(nullable id)sender;
- (IBAction)alignLeft:(nullable id)sender;
- (IBAction)alignRight:(nullable id)sender;
- (IBAction)alignCenter:(nullable id)sender;
- (IBAction)createNewNote:(nullable id)sender;
- (IBAction)editNote:(nullable id)sender;
- (IBAction)autoSizeNote:(nullable id)sender;
- (IBAction)toggleHideNotes:(nullable id)sender;
- (IBAction)takeSnapshot:(nullable id)sender;
- (IBAction)changeDisplaySinglePages:(nullable id)sender;
- (IBAction)changeDisplayContinuous:(nullable id)sender;
- (IBAction)changeDisplayMode:(nullable id)sender;
- (IBAction)changeDisplayDirection:(nullable id)sender;
- (IBAction)toggleDisplaysRTL:(nullable id)sender;
- (IBAction)toggleDisplaysAsBook:(nullable id)sender;
- (IBAction)toggleDisplayPageBreaks:(nullable id)sender;
- (IBAction)changeDisplayBox:(nullable id)sender;
- (IBAction)doGoToNextPage:(nullable id)sender;
- (IBAction)doGoToPreviousPage:(nullable id)sender;
- (IBAction)doGoToFirstPage:(nullable id)sender;
- (IBAction)doGoToLastPage:(nullable id)sender;
- (IBAction)allGoToNextPage:(nullable id)sender;
- (IBAction)allGoToPreviousPage:(nullable id)sender;
- (IBAction)allGoToFirstPage:(nullable id)sender;
- (IBAction)allGoToLastPage:(nullable id)sender;
- (IBAction)doGoToPage:(nullable id)sender;
- (IBAction)doGoBack:(nullable id)sender;
- (IBAction)doGoForward:(nullable id)sender;
- (IBAction)goToMarkedPage:(nullable id)sender;
- (IBAction)markPage:(nullable id)sender;
- (IBAction)doZoomIn:(nullable id)sender;
- (IBAction)doZoomOut:(nullable id)sender;
- (IBAction)doZoomToActualSize:(nullable id)sender;
- (IBAction)doZoomToPhysicalSize:(nullable id)sender;
- (IBAction)doZoomToFit:(nullable id)sender;
- (IBAction)alternateZoomToFit:(nullable id)sender;
- (IBAction)doZoomToSelection:(nullable id)sender;
- (IBAction)doAutoScale:(nullable id)sender;
- (IBAction)toggleAutoScale:(nullable id)sender;
- (IBAction)rotateRight:(nullable id)sender;
- (IBAction)rotateLeft:(nullable id)sender;
- (IBAction)rotateAllRight:(nullable id)sender;
- (IBAction)rotateAllLeft:(nullable id)sender;
- (IBAction)crop:(nullable id)sender;
- (IBAction)cropAll:(nullable id)sender;
- (IBAction)autoCropAll:(nullable id)sender;
- (IBAction)smartAutoCropAll:(nullable id)sender;
- (IBAction)resetCrop:(nullable id)sender;
- (IBAction)autoSelectContent:(nullable id)sender;
- (IBAction)getInfo:(nullable id)sender;
- (IBAction)delete:(nullable id)sender;
- (IBAction)paste:(nullable id)sender;
- (IBAction)alternatePaste:(nullable id)sender;
- (IBAction)pasteAsPlainText:(nullable id)sender;
- (IBAction)copy:(nullable id)sender;
- (IBAction)cut:(nullable id)sender;
- (IBAction)deselectAll:(nullable id)sender;
- (IBAction)changeToolMode:(nullable id)sender;
- (IBAction)changeAnnotationMode:(nullable id)sender;
- (IBAction)toggleLeftSidebar:(nullable id)sender;
- (IBAction)toggleLeftSidePane:(nullable id)sender;
- (IBAction)toggleRightSidePane:(nullable id)sender;
- (IBAction)changeLeftSidePaneState:(nullable id)sender;
- (IBAction)changeRightSidePaneState:(nullable id)sender;
- (IBAction)changeFindPaneState:(nullable id)sender;
- (IBAction)toggleStatusBar:(nullable id)sender;
- (IBAction)toggleSplitPDF:(nullable id)sender;
- (IBAction)toggleOverview:(nullable id)sender;
- (IBAction)toggleReadingBar:(nullable id)sender;
- (IBAction)togglePacer:(nullable id)sender;
- (IBAction)toggleToolModesPane:(nullable id)sender;
- (IBAction)changePacerSpeed:(nullable id)sender;
- (IBAction)searchPDF:(nullable id)sender;
- (IBAction)filterNotes:(nullable id)sender;
- (IBAction)search:(nullable id)sender;
- (IBAction)searchNotes:(nullable id)sender;
- (IBAction)toggleFullscreen:(nullable id)sender;
- (IBAction)togglePresentation:(nullable id)sender;
- (IBAction)performFit:(nullable id)sender;
- (IBAction)password:(nullable id)sender;
- (IBAction)savePDFSettingToDefaults:(nullable id)sender;
- (IBAction)chooseTransition:(nullable id)sender;
- (IBAction)toggleCaseInsensitiveSearch:(nullable id)sender;
- (IBAction)toggleWholeWordSearch:(nullable id)sender;
- (IBAction)toggleCaseInsensitiveFilter:(nullable id)sender;
- (IBAction)performFindPanelAction:(nullable id)sender;
- (IBAction)centerSelectionInVisibleArea:(nullable id)sender;
- (void)scrollUp:(nullable id)sender;
- (void)scrollDown:(nullable id)sender;
- (void)scrollRight:(nullable id)sender;
- (void)scrollLeft:(nullable id)sender;
- (void)selectSelectedNote:(nullable id)sender;
- (void)goToSelectedOutlineItem:(nullable id)sender;
- (void)goToSelectedFindResults:(nullable id)sender;
- (void)toggleSelectedSnapshots:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
