//
//  SKPresentationOptionsSheetController.m
//  Skim
//
//  Created by Christiaan Hofman on 9/28/08.
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

#import "SKPresentationOptionsSheetController.h"
#import <Quartz/Quartz.h>
#import "SKMainWindowController.h"
#import "SKDocumentController.h"
#import "SKTransitionInfo.h"
#import "SKThumbnail.h"
#import "SKTableView.h"
#import "SKTypeSelectHelper.h"
#import "SKMainWindowController.h"
#import "SKPDFView.h"
#import "SKImageToolTipWindow.h"
#import "NSWindowController_SKExtensions.h"
#import "NSDocument_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSView_SKExtensions.h"

#define PAGE_COLUMNID @"page"
#define IMAGE_COLUMNID @"image"
#define TOIMAGE_COLUMNID @"toImage"

#define TRANSITIONSTYLE_KEY @"transitionStyle"
#define DURATION_KEY @"duration"
#define SHOULDRESTRICT_KEY @"shouldRestrict"
#define PROPERTIES_KEY @"properties"
#define SEPARATE_KEY @"separate"
#define TRANSITION_KEY @"transition"
#define TRANSITIONS_KEY @"transitions"
#define CURRENTTRANSITIONS_KEY @"currentTransitions"

#define MAX_PAGE_COLUMN_WIDTH 100.0

#define TABLE_OFFSET 8.0
#define BOX_OFFSET 20.0

static char *SKTransitionPropertiesObservationContext;

#define SKTouchBarItemIdentifierOK     @"scris.ds.preskim.touchbar-item.OK"
#define SKTouchBarItemIdentifierCancel @"scris.ds.preskim.touchbar-item.cancel"

#pragma mark -

@implementation SKPresentationOptionsSheetController

@synthesize notesDocumentPopUpButton, tableView, stylePopUpButton, okButton, cancelButton, tableWidthConstraint, boxLeadingConstraint, arrayController, separate, transition, transitions, undoManager;
@dynamic currentTransitions, pageTransitions, notesDocument, notesDocumentOffset;

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:CURRENTTRANSITIONS_KEY])
        keyPaths = [keyPaths setByAddingObjectsFromSet:[NSSet setWithObjects:SEPARATE_KEY, TRANSITIONS_KEY, TRANSITION_KEY, nil]];
    return keyPaths;
}

- (instancetype)initForController:(SKMainWindowController *)aController {
    self = [super init];
    if (self) {
        controller = aController;
        separate = NO;
        transition = [[SKTransitionInfo alloc] init];
        transitions = nil;
    }
    return self;
}

- (void)dealloc {
    SKENSURE_MAIN_THREAD(
        [self stopObservingTransitions:@[transition]];
        [self stopObservingTransitions:transitions];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[self window] setDelegate:nil];
        [tableView setDelegate:nil];
        [tableView setDataSource:nil];
    );
}

- (void)handleDocumentsDidChangeNotification:(NSNotification *)note {
    id currentDoc = [[notesDocumentPopUpButton selectedItem] representedObject];
    
    while ([notesDocumentPopUpButton numberOfItems] > 3)
        [notesDocumentPopUpButton removeItemAtIndex:[notesDocumentPopUpButton numberOfItems] - 1];
    
    NSDocument *doc;
    NSDocument *document = [controller document];
    NSMutableArray *documents = [NSMutableArray array];
    NSUInteger pageCount = [[document pdfDocument] pageCount];
    for (doc in [[NSDocumentController sharedDocumentController] documents]) {
        if ([doc isPDFDocument] && doc != document && [[doc pdfDocument] pageCount] == pageCount)
            [documents addObject:doc];
    }
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
    [documents sortUsingDescriptors:@[sortDescriptor]];
    
    for (doc in documents) {
        [notesDocumentPopUpButton addItemWithTitle:[doc displayName]];
        [[notesDocumentPopUpButton lastItem] setRepresentedObject:doc];
    }
    
    NSInteger docIndex = [notesDocumentPopUpButton indexOfItemWithRepresentedObject:currentDoc];
    [notesDocumentPopUpButton selectItemAtIndex:docIndex == -1 ? 0 : docIndex];
}

- (void)windowDidLoad {
    // add the filter names to the popup
    NSUInteger i, count = [[SKTransitionController transitionNames] count];
    NSMutableSet *titles = [NSMutableSet set];
    [stylePopUpButton removeAllItems];
    for (i = 0; i < count; i++) {
        NSString *title = [SKTransitionController localizedNameForStyle:i];
        while ([titles containsObject:title])
            title = [title stringByAppendingString:@" "];
        [titles addObject:title];
        [stylePopUpButton addItemWithTitle:title];
        [[stylePopUpButton lastItem] setTag:i];
    }
    [stylePopUpButton addItemWithTitle:NSLocalizedString(@"Multiple effects", @"Menu item title")];
    [[stylePopUpButton lastItem] setTag:-1];
    [[stylePopUpButton lastItem] setHidden:YES];
    [[stylePopUpButton lastItem] setEnabled:NO];
    
    [[notesDocumentPopUpButton itemAtIndex:1] setRepresentedObject:[controller document]];
    [[notesDocumentPopUpButton itemAtIndex:2] setRepresentedObject:[controller document]];

    SKTransitionController *transitionController = [[controller pdfView] transitionController];
    SKTransitionInfo *info = [transitionController transition];
    if (info) {
        [transition setTransitionStyle:[info transitionStyle]];
        [transition setDuration:[info duration]];
        [transition setShouldRestrict:[info shouldRestrict]];
    }
    [self startObservingTransitions:@[transition]];
    
    // collapse the table, it is already hidden
    [boxLeadingConstraint setConstant:BOX_OFFSET];
    
    [tableView registerForDraggedTypes:[SKTransitionInfo readableTypesForPasteboard:[NSPasteboard pasteboardWithName:NSPasteboardNameDrag]]];
    
    [tableView setTypeSelectHelper:[SKTypeSelectHelper typeSelectHelperWithMatchOption:SKFullStringMatch]];
    
    [tableView setImageToolTipLayout:SKTableImageToolTipByCell];
    
    if ([transitionController pageTransitions]) {
        [[self undoManager] disableUndoRegistration];
        [self setSeparate:YES];
        [[self undoManager] enableUndoRegistration];
    }
    
    // set the current notes document and observe changes for the popup
    [self handleDocumentsDidChangeNotification:nil];
    NSDocument *currentDoc = [controller presentationNotesDocument];
    NSInteger docIndex = [notesDocumentPopUpButton indexOfItemWithRepresentedObject:currentDoc];
    if (currentDoc == [controller document])
        docIndex = [controller presentationNotesOffset] > 0 ? 2 : 1;
    [notesDocumentPopUpButton selectItemAtIndex:docIndex > 0 ? docIndex : 0];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentsDidChangeNotification:) 
                                                 name:SKDocumentDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDocumentsDidChangeNotification:)
                                                 name:SKDocumentControllerDidRemoveDocumentNotification object:nil];
}

- (void)makeTransitions {
    if (transitions) return;
    
    // determine the table width by getting the largest page label
    NSTableColumn *tableColumn = [tableView tableColumnWithIdentifier:PAGE_COLUMNID];
    id cell = [[tableColumn dataCell] copy];
    CGFloat labelWidth = 0.0;
    
    [cell setFont:[[NSFontManager sharedFontManager] convertFont:[cell font] toHaveTrait:NSBoldFontMask]];
    
    NSMutableArray *array = [NSMutableArray array];
    NSDictionary *dictionary = [transition properties];
    NSEnumerator *ptEnum = [[[[controller pdfView] transitionController] pageTransitions] objectEnumerator];
    SKThumbnail *tn = nil;
    
    for (SKThumbnail *next in [controller thumbnails]) {
        if (tn) {
            SKLabeledTransitionInfo *info = [[SKLabeledTransitionInfo alloc] initWithProperties:([ptEnum nextObject] ?: dictionary)];
            [info setThumbnail:tn];
            [info setToThumbnail:next];
            [array addObject:info];
            [cell setStringValue:[info label] ?: @""];
            labelWidth = fmax(labelWidth, [cell cellSize].width);
        }
        tn = next;
    }
    
    labelWidth = fmin(ceil(labelWidth), MAX_PAGE_COLUMN_WIDTH);
    [tableColumn setMinWidth:labelWidth];
    [tableColumn setMaxWidth:labelWidth];
    [tableColumn setWidth:labelWidth];
    
    [tableView setStyle:NSTableViewStylePlain];
    
    NSScrollView *scrollView = [tableView enclosingScrollView];
    CGFloat width = [[[tableView tableColumns] valueForKeyPath:@"@sum.width"] doubleValue] + NSWidth([scrollView frame]) - [scrollView contentSize].width + 3.0 * [tableView intercellSpacing].width;
    [tableWidthConstraint setConstant:width];
    
    [self setTransitions:array];
}

- (NSString *)windowNibName {
    return @"TransitionSheet";
}

- (void)dismissSheet:(id)sender {
    [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
    if ([sender tag] == NSModalResponseCancel) {
        [super dismissSheet:sender];
    } else if ([arrayController commitEditing]) {
        // don't make changes when nothing was changed
        if ([undoManager canUndo]) {
            SKTransitionController *transitionController = [[controller pdfView] transitionController];
            [transitionController setTransition:transition];
            [transitionController setPageTransitions:[self pageTransitions]];
            [[controller undoManager] setActionName:NSLocalizedString(@"Change Transitions", @"Undo action name")];
        }
        [controller setPresentationNotesDocument:[self notesDocument]];
        [controller setPresentationNotesOffset:[self notesDocumentOffset]];
        [super dismissSheet:sender];
    }
}

- (void)setSeparate:(BOOL)newSeparate {
    if (separate != newSeparate) {
        separate = newSeparate;
        
        [[SKImageToolTipWindow sharedToolTipWindow] orderOut:nil];
        
        NSWindow *window = [self window];
        BOOL isVisible = [window isVisible];
        NSView *scrollView = [tableView enclosingScrollView];
        CGFloat width = BOX_OFFSET;
        BOOL hidden = separate == NO;
        id firstResponder = [window firstResponder];
        NSTextView *editor = nil;
        
        if ([firstResponder isKindOfClass:[NSTextView class]]) {
            editor = firstResponder;
            if ([editor isFieldEditor])
                firstResponder = [firstResponder delegate];
        }
        
        if ([arrayController commitEditing] &&
            editor && [window firstResponder] != editor)
            [window makeFirstResponder:firstResponder]; 
        
        if (separate) {
            [self makeTransitions];
            width += [tableWidthConstraint constant] + TABLE_OFFSET;
        }
        if (isVisible && [NSView shouldShowSlideAnimation]) {
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context){
                    [[boxLeadingConstraint animator] setConstant:width];
                    [[scrollView animator] setHidden:hidden];
                }
                completionHandler:^{
                    NSRect frame = [window frame];
                    [window setFrameOrigin:NSMakePoint(NSMidX([[controller window] frame]) - 0.5 * NSWidth(frame), NSMinY(frame))];
                }];
        } else {
            [boxLeadingConstraint setConstant:width];
            [scrollView setHidden:hidden];
            if (isVisible) {
                NSRect frame = [window frame];
                [window setFrameOrigin:NSMakePoint(NSMidX([[controller window] frame]) - 0.5 * NSWidth(frame), NSMinY(frame))];
            }
        }
        [[[self undoManager] prepareWithInvocationTarget:self] setSeparate:separate == NO];
    }
}

- (void)setTransitions:(NSArray *)newTransitions {
    if (transitions != newTransitions) {
        [[[self undoManager] prepareWithInvocationTarget:self] setTransitions:transitions];
        [self stopObservingTransitions:transitions];
        transitions = [newTransitions copy];
        [self startObservingTransitions:transitions];
    }
}

- (NSArray *)currentTransitions {
    return separate ? transitions : @[transition];
}

- (NSArray *)pageTransitions {
    if (separate && [transitions count])
        return [transitions valueForKey:PROPERTIES_KEY];
    else
        return nil;
}

- (NSDocument *)notesDocument {
    [self window];
    return [[notesDocumentPopUpButton selectedItem] representedObject];
}

- (NSInteger)notesDocumentOffset {
    [self window];
    return [[notesDocumentPopUpButton selectedItem] tag];
}

#pragma mark Undo

- (void)observeUndoManagerCheckpoint:(NSNotification *)notification {
    changedTransitions = nil;
}

- (NSUndoManager *)undoManager {
    if (undoManager == nil) {
        undoManager = [[NSUndoManager alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeUndoManagerCheckpoint:) name:NSUndoManagerCheckpointNotification object:undoManager];
    }
    return undoManager;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender {
    return [self undoManager];
}

- (void)startObservingTransitions:(NSArray *)infos {
    for (SKTransitionInfo *info in infos) {
        [info addObserver:self forKeyPath:TRANSITIONSTYLE_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&SKTransitionPropertiesObservationContext];
        [info addObserver:self forKeyPath:DURATION_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&SKTransitionPropertiesObservationContext];
        [info addObserver:self forKeyPath:SHOULDRESTRICT_KEY options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&SKTransitionPropertiesObservationContext];
    }
}

- (void)stopObservingTransitions:(NSArray *)infos {
    for (SKTransitionInfo *info in infos) {
        [info removeObserver:self forKeyPath:TRANSITIONSTYLE_KEY context:&SKTransitionPropertiesObservationContext];
        [info removeObserver:self forKeyPath:DURATION_KEY context:&SKTransitionPropertiesObservationContext];
        [info removeObserver:self forKeyPath:SHOULDRESTRICT_KEY context:&SKTransitionPropertiesObservationContext];
    }
}

- (void)setValue:(id)value forKey:(NSString *)key ofTransition:(SKTransitionInfo *)info {
    [info setValue:value forKey:key];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKTransitionPropertiesObservationContext) {
        id newValue = [change objectForKey:NSKeyValueChangeNewKey];
        id oldValue = [change objectForKey:NSKeyValueChangeOldKey];
        
        if ([newValue isEqual:[NSNull null]]) newValue = nil;
        if ([oldValue isEqual:[NSNull null]]) oldValue = nil;
        
        if (newValue == oldValue || [newValue isEqual:oldValue])
            return;
            
        if ([keyPath isEqualToString:DURATION_KEY]) {
            if ([changedTransitions containsObject:object])
                return;
            if (changedTransitions == nil)
                changedTransitions = [[NSMutableSet alloc] init];
            [changedTransitions addObject:object];
        }
        
        [[[self undoManager] prepareWithInvocationTarget:self] setValue:oldValue forKey:keyPath ofTransition:object];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark NSTableView dataSource and delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv { return 0; }

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row { return nil; }

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tv pasteboardWriterForRow:(NSInteger)row {
    if ([[tv selectedRowIndexes] count] > 1 && [[tv selectedRowIndexes] containsIndex:row])
        return nil;
    return [transitions objectAtIndex:row];
}

- (void)tableView:(NSTableView *)tv draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes {
    if ([rowIndexes count] != 1)
        return;
    
    NSTableRowView *view = [tv rowViewAtRow:[rowIndexes firstIndex] makeIfNecessary:NO];
    if (view) {
        NSRect frame = [view convertRectToScreen:[view bounds]];
        frame.origin.x -= screenPoint.x - [session draggingLocation].x;
        frame.origin.y -= screenPoint.y - [session draggingLocation].y;
        [session enumerateDraggingItemsWithOptions:0 forView:nil classes:@[[SKTransitionInfo class]] searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop){
            [draggingItem setImageComponentsProvider:^{
                NSMutableArray *components = [NSMutableArray array];
                NSUInteger i, iMax = [view numberOfColumns];
                for (i = 0; i < iMax; i++) {
                    NSTableCellView *cellView = [view viewAtColumn:i];
                    NSDraggingImageComponent *component = [[cellView draggingImageComponents] firstObject];
                    NSRect rect = [component frame];
                    NSPoint offset = [cellView frame].origin;
                    rect.origin.x += offset.x;
                    rect.origin.y += offset.y;
                    [component setFrame:rect];
                    if (i == 1)
                        [component setKey:@"toIcon"];
                    [components addObject:component];
                }
                return components;
            }];
            [draggingItem setDraggingFrame:frame];
        }];
    }
}

- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
    if ([[info draggingPasteboard] canReadObjectForClasses:@[[SKTransitionInfo class]] options:@{}]) {
        if (operation == NSTableViewDropAbove)
            [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
        return NSDragOperationEvery;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id < NSDraggingInfo >)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
    NSPasteboard *pboard = [info draggingPasteboard];
    if (operation == NSTableViewDropOn) {
        NSArray *infos = [pboard readObjectsForClasses:@[[SKTransitionInfo class]] options:@{}];
        if ([infos count] > 0) {
            NSDictionary *properties = [[infos objectAtIndex:0] properties];
            if (row == -1)
                [transitions setValue:properties forKey:PROPERTIES_KEY];
            else
                [(SKTransitionInfo *)[transitions objectAtIndex:row] setProperties:properties];
            return YES;
        }
    }
    return NO;
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [tv makeViewWithIdentifier:[tableColumn identifier] owner:self];
}

- (id <SKImageToolTipContext>)tableView:(NSTableView *)tv imageContextForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row  scale:(CGFloat *)scale {
    if ([[tableColumn identifier] isEqualToString:IMAGE_COLUMNID])
        return [[controller pdfDocument] pageAtIndex:row];
    else if ([[tableColumn identifier] isEqualToString:TOIMAGE_COLUMNID])
        return [[controller pdfDocument] pageAtIndex:row + 1];
    else
        return nil;
}

- (void)tableView:(NSTableView *)tv copyRowsWithIndexes:(NSIndexSet *)rowIndexes {
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard clearContents];
    [pboard writeObjects:@[[transitions objectAtIndex:[rowIndexes firstIndex]]]];
}

- (BOOL)tableView:(NSTableView *)tv canCopyRowsWithIndexes:(NSIndexSet *)rowIndexes {
    return [rowIndexes count] == 1;
}

- (void)tableView:(NSTableView *)tv pasteFromPasteboard:(NSPasteboard *)pboard {
    NSArray *infos = [pboard readObjectsForClasses:@[[SKTransitionInfo class]] options:@{}];
    if ([infos count] > 0)
        [[transitions objectsAtIndexes:[tableView selectedRowIndexes]] setValue:[[infos objectAtIndex:0] properties] forKey:PROPERTIES_KEY];
}

- (BOOL)tableView:(NSTableView *)tv canPasteFromPasteboard:(NSPasteboard *)pboard {
    return ([tableView selectedRow] != -1 && [pboard canReadObjectForClasses:@[[SKTransitionInfo class]] options:@{}]);
}

- (void)tableView:(NSTableView *)tv deleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    NSArray *selTransitions = [transitions objectsAtIndexes:rowIndexes];
    NSDictionary *empty = [[[SKTransitionInfo alloc] init] properties];
    [selTransitions setValue:empty forKey:PROPERTIES_KEY];
}

- (NSArray *)tableViewTypeSelectHelperSelectionStrings:(NSTableView *)tv {
    return [transitions valueForKeyPath:@"thumbnail.label"];
}

#pragma mark Touch Bar

- (NSTouchBar *)makeTouchBar {
    NSTouchBar *touchBar = [[NSTouchBar alloc] init];
    [touchBar setDelegate:self];
    [touchBar setDefaultItemIdentifiers:@[NSTouchBarItemIdentifierFlexibleSpace, SKTouchBarItemIdentifierCancel, SKTouchBarItemIdentifierOK, NSTouchBarItemIdentifierFixedSpaceLarge]];
    return touchBar;
}

- (NSTouchBarItem *)touchBar:(NSTouchBar *)aTouchBar makeItemForIdentifier:(NSString *)identifier {
    NSCustomTouchBarItem *item = nil;
    if ([identifier isEqualToString:SKTouchBarItemIdentifierOK]) {
        NSButton *button = [NSButton buttonWithTitle:[okButton title] target:[okButton target] action:[okButton action]];
        [button setTag:NSModalResponseOK];
        [button setKeyEquivalent:@"\r"];
        item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        [(NSCustomTouchBarItem *)item setView:button];
    } else if ([identifier isEqualToString:SKTouchBarItemIdentifierCancel]) {
        NSButton *button = [NSButton buttonWithTitle:[cancelButton title] target:[cancelButton target] action:[cancelButton action]];
        [button setTag:NSModalResponseCancel];
        item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        [(NSCustomTouchBarItem *)item setView:button];
    }
    return item;
}

@end
