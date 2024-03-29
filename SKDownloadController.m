//
//  SKDownloadController.m
//  Skim
//
//  Created by Christiaan Hofman on 8/11/07.
/*
 This software is Copyright (c) 2007
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

#import "SKDownloadController.h"
#import "SKDownload.h"
#import "NSURL_SKExtensions.h"
#import "SKStringConstants.h"
#import "SKTableView.h"
#import "SKTypeSelectHelper.h"
#import "NSString_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSWindowController_SKExtensions.h"
#import "SKDownloadPreferenceController.h"
#import "NSError_SKExtensions.h"
#import "NSEvent_SKExtensions.h"
#import "NSFileManager_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "NSImage_SKExtensions.h"

#define SKDownloadsToolbarIdentifier                @"SKDownloadsToolbarIdentifier"
#define SKDownloadsToolbarPreferencesItemIdentifier @"SKDownloadsToolbarPreferencesItemIdentifier"
#define SKDownloadsToolbarClearItemIdentifier       @"SKDownloadsToolbarClearItemIdentifier"

#define SKTouchBarItemIdentifierClear      @"scris.ds.preskim.touchbar-item.clear"
#define SKTouchBarItemIdentifierResume     @"scris.ds.preskim.touchbar-item.resume"
#define SKTouchBarItemIdentifierCancel     @"scris.ds.preskim.touchbar-item.cancel"
#define SKTouchBarItemIdentifierRemove     @"scris.ds.preskim.touchbar-item.remove"

#define PROGRESS_COLUMN 1
#define RESUME_COLUMN   2
#define CANCEL_COLUMN   3

#define ICON_COLUMNID     @"icon"
#define PROGRESS_COLUMNID @"progress"
#define RESUME_COLUMNID   @"resume"
#define CANCEL_COLUMNID   @"cancel"

#define DOWNLOADS_KEY @"downloads"

#define SKDownloadsWindowFrameAutosaveName @"SKDownloadsWindow"

static char SKDownloadPropertiesObservationContext;

static NSString *SKDownloadsIdentifier = nil;

@interface SKDownloadController () <NSURLSessionDelegate>

- (void)setupToolbar;

@property (nonatomic, readonly) NSUInteger countOfDownloads;
- (SKDownload *)objectInDownloadsAtIndex:(NSUInteger)anIndex;
- (void)insertObject:(SKDownload *)download inDownloadsAtIndex:(NSUInteger)anIndex;
- (void)removeDownloadsAtIndexes:(NSIndexSet *)indexes;

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification;
- (void)startObservingDownloads:(NSArray *)newDownloads;
- (void)endObservingDownloads:(NSArray *)oldDownloads;
- (void)updateClearButton;

@end

@implementation SKDownloadController

@synthesize tableView, clearButton, downloads;
@dynamic countOfDownloads;

+ (void)initialize {
    SKINITIALIZE;
    
    SKDownloadsIdentifier = [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@".downloads"];
}

static SKDownloadController *sharedDownloadController = nil;

+ (SKDownloadController *)sharedDownloadController {
    if (sharedDownloadController == nil)
        sharedDownloadController = [[self alloc] init];
    return sharedDownloadController;
}

- (instancetype)init {
    if (sharedDownloadController) NSLog(@"Attempt to allocate second instance of %@", [self class]);
    self = [super initWithWindowNibName:@"DownloadsWindow"];
    if (self) {
        downloads = [[NSMutableArray alloc] init];
        
        NSDictionary *downloadsDictionary = [[NSUserDefaults standardUserDefaults] persistentDomainForName:SKDownloadsIdentifier];
        for (NSDictionary *properties in [downloadsDictionary objectForKey:DOWNLOADS_KEY]) {
            SKDownload *download = [[SKDownload alloc] initWithProperties:properties];
            [downloads addObject:download];
        }
        
        [self startObservingDownloads:downloads];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationWillTerminateNotification:)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:NSApp];
    }
    return self;
}

- (void)dealloc {
    [self endObservingDownloads:downloads];
}

- (void)windowDidLoad {
    [self setupToolbar];
    
    [self updateClearButton];
    
    [self setWindowFrameAutosaveName:SKDownloadsWindowFrameAutosaveName];
    
    [tableView setTypeSelectHelper:[SKTypeSelectHelper typeSelectHelper]];
    
    [tableView registerForDraggedTypes:@[(__bridge NSString *)kUTTypeURL, (__bridge NSString *)kUTTypeFileURL, NSPasteboardTypeURL, NSFilenamesPboardType, NSPasteboardTypeString]];
    
    [tableView setSupportsQuickLook:YES];
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification  {
    [downloads makeObjectsPerformSelector:@selector(cancel) withObject:nil];
    NSDictionary *downloadsDictionary = @{DOWNLOADS_KEY:[downloads valueForKey:@"properties"]};
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:downloadsDictionary forName:SKDownloadsIdentifier];
}

- (void)updateClearButton {
    [clearButton setEnabled:[[self downloads] valueForKeyPath:@"@max.canRemove"]];
    [tbClearButton setEnabled:[[self downloads] valueForKeyPath:@"@max.canRemove"]];
}

- (SKDownload *)addDownloadForURL:(NSURL *)aURL showWindow:(BOOL)flag {
    SKDownload *download = nil;
    if (aURL) {
        download = [[SKDownload alloc] initWithURL:aURL];
        NSInteger row = [self countOfDownloads];
        [self addObjectToDownloads:download];
        if (flag)
            [self showWindow:nil];
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [tableView scrollRowToVisible:row];
    }
    return download;
}

- (SKDownload *)addDownloadForURL:(NSURL *)aURL {
    return [self addDownloadForURL:aURL showWindow:[[NSUserDefaults standardUserDefaults] boolForKey:SKAutoOpenDownloadsWindowKey]];
}

- (BOOL)pasteFromPasteboard:(NSPasteboard *)pboard {
    NSArray *theURLs = [NSURL readURLsFromPasteboard:pboard];
    for (NSURL *theURL in theURLs) {
        if ([theURL isFileURL]) {
            [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:theURL display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error){}];
        } else {
            [self addDownloadForURL:theURL showWindow:NO];
        }
    }
    return [theURLs count] > 0;
}

- (void)openDownload:(SKDownload *)download {
    if ([download status] == SKDownloadStatusFinished) {
        NSURL *URL = [download fileURL];
        NSString *fragment = [[download URL] fragment];
        if ([fragment length] > 0)
            URL = [NSURL URLWithString:[[URL absoluteString] stringByAppendingFormat:@"#%@", fragment]];
        
        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:URL display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error){
            if (document == nil && [error isUserCancelledError] == NO)
                [self presentError:error];
            
            if ([[NSUserDefaults standardUserDefaults] boolForKey:SKAutoRemoveFinishedDownloadsKey]) {
                NSURL *fileURL = [download fileURL];
                [self removeObjectFromDownloads:download];
                // for the document to note that the file has been deleted
                [document setFileURL:fileURL];
                if ([self countOfDownloads] == 0 && [[NSUserDefaults standardUserDefaults] boolForKey:SKAutoCloseDownloadsWindowKey])
                    [[self window] close];
            }
        }];
    }
}

#pragma mark Accessors

- (NSUInteger)countOfDownloads {
    return [downloads count];
}

- (SKDownload *)objectInDownloadsAtIndex:(NSUInteger)anIndex {
    return [downloads objectAtIndex:anIndex];
}

- (void)insertObject:(SKDownload *)download inDownloadsAtIndex:(NSUInteger)anIndex {
    NSTableViewAnimationOptions options = NSTableViewAnimationEffectGap | NSTableViewAnimationSlideDown;
    if ([self isWindowLoaded] == NO || [[self window] isVisible] == NO || [NSView shouldShowSlideAnimation] == NO)
        options = NSTableViewAnimationEffectNone;
    [tableView beginUpdates];
    [tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:anIndex] withAnimation:options];
    [downloads insertObject:download atIndex:anIndex];
    [tableView endUpdates];
    
    [self startObservingDownloads:@[download]];
    [download start];
    
    [self updateClearButton];
}

- (void)removeDownloadsAtIndexes:(NSIndexSet *)indexes {
    NSArray *oldDownloads = [downloads objectsAtIndexes:indexes];
    [self endObservingDownloads:oldDownloads];
    [oldDownloads makeObjectsPerformSelector:@selector(cancel)];
    
    NSTableViewAnimationOptions options = NSTableViewAnimationEffectGap | NSTableViewAnimationSlideUp;
    if ([self isWindowLoaded] == NO || [[self window] isVisible] == NO || [NSView shouldShowSlideAnimation] == NO)
        options = NSTableViewAnimationEffectNone;
    [tableView beginUpdates];
    [tableView removeRowsAtIndexes:indexes withAnimation:options];
    [downloads removeObjectsAtIndexes:indexes];
    [tableView endUpdates];
    
    [self updateClearButton];
}

#pragma mark Adding/Removing Downloads

- (void)addObjectToDownloads:(SKDownload *)download {
    [self insertObject:download inDownloadsAtIndex:[self countOfDownloads]];
}

- (void)removeObjectFromDownloads:(SKDownload *)download {
    NSUInteger idx = [downloads indexOfObject:download];
    if (idx != NSNotFound)
        [self removeDownloadsAtIndexes:[NSIndexSet indexSetWithIndex:idx]];
}

#pragma mark Actions

- (IBAction)showDownloadPreferences:(id)sender {
    SKDownloadPreferenceController *prefController = [[SKDownloadPreferenceController alloc] init];
    [prefController beginSheetModalForWindow:[self window] completionHandler:NULL];
}

- (IBAction)clearDownloads:(id)sender {
    NSInteger i = [self countOfDownloads];
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    
    while (i-- > 0) {
        SKDownload *download = [self objectInDownloadsAtIndex:i];
        if ([download canRemove])
            [indexes addIndex:i];
    }
    if ([indexes count])
        [self removeDownloadsAtIndexes:indexes];
}

- (IBAction)moveToTrash:(id)sender {
    SKDownload *download = nil;
    NSInteger row = [tableView selectedRow];
    if (row != -1)
        download = [self objectInDownloadsAtIndex:row];
    if ([download canRemove]) {
        if ([download status] == SKDownloadStatusFinished)
            [download moveToTrash];
        [self removeObjectFromDownloads:download];
    } else {
        NSBeep();
    }
}

- (void)cancelDownload:(id)sender {
    SKDownload *download = nil;
    if ([sender respondsToSelector:@selector(representedObject)])
        download = [sender representedObject];
    if (download == nil) {
        NSInteger row = [tableView selectedRow];
        if (row != -1)
            download = [self objectInDownloadsAtIndex:row];
    }
    if ([download canCancel])
        [download cancel];
}

- (void)resumeDownload:(id)sender {
    SKDownload *download = nil;
    if ([sender respondsToSelector:@selector(representedObject)])
        download = [sender representedObject];
    if (download == nil) {
        NSInteger row = [tableView selectedRow];
        if (row != -1)
            download = [self objectInDownloadsAtIndex:row];
    }
    if ([download canResume])
        [download resume];
}

- (void)removeDownload:(id)sender {
    SKDownload *download = nil;
    if ([sender respondsToSelector:@selector(representedObject)])
        download = [sender representedObject];
    if (download == nil) {
        NSInteger row = [tableView selectedRow];
        if (row != -1)
            download = [self objectInDownloadsAtIndex:row];
    }
    if (download)
        [self removeObjectFromDownloads:download];
}

- (void)openDownloadedFile:(id)sender {
    SKDownload *download = [sender representedObject];
    
    if (download == nil || [download status] != SKDownloadStatusFinished) {
        NSBeep();
    } else {
        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[download fileURL] display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error){
            if (document == nil && [error isUserCancelledError] == NO)
                [self presentError:error];
        }];
    }
}

- (void)previewDownloadedFile:(id)sender {
    SKDownload *download = [sender representedObject];
    
    if (download == nil || [download status] != SKDownloadStatusFinished) {
        NSBeep();
    } else if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible]) {
        [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
    } else {
        NSUInteger row = [downloads indexOfObject:download];
        if (row != NSNotFound)
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
    }
}

- (void)revealDownloadedFile:(id)sender {
    SKDownload *download = [sender representedObject];
    
    if (download == nil || [download status] != SKDownloadStatusFinished) {
        NSBeep();
    } else {
        [[NSWorkspace sharedWorkspace] selectFile:[[download fileURL] path] inFileViewerRootedAtPath:@""];
    }
}

- (void)trashDownloadedFile:(id)sender {
    SKDownload *download = [sender representedObject];
    
    if (download == nil || [download status] != SKDownloadStatusFinished)
        NSBeep();
    else
        [download moveToTrash];
}

#pragma mark Menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(moveToTrash:)) {
        NSInteger row = [tableView selectedRow];
        return (row != -1 && [[self objectInDownloadsAtIndex:row] canRemove]);
    }
    return YES;
}

#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    return [self countOfDownloads];
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [self objectInDownloadsAtIndex:row];
}

- (void)tableView:(NSTableView*)tv updateDraggingItemsForDrag:(id<NSDraggingInfo>)draggingInfo {
    NSTableCellView *view = [tv makeViewWithIdentifier:ICON_COLUMNID owner:self];
    NSRect frame = NSMakeRect(0.0, 0.0, [[tv tableColumnWithIdentifier:ICON_COLUMNID] width], [tv rowHeight]);
    [view setFrame:frame];
    frame.origin = [draggingInfo draggingLocation];
    __block NSInteger validCount = 0;
    [draggingInfo enumerateDraggingItemsWithOptions:NSDraggingItemEnumerationClearNonenumeratedImages forView:tv classes:@[[NSURL class]] searchOptions:@{} usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop){
        if ([[draggingItem item] isKindOfClass:[NSURL class]]) {
            SKDownload *download = [[SKDownload alloc] initWithURL:[draggingItem item]];
            [draggingItem setImageComponentsProvider:^{
                [view setObjectValue:download];
                return [view draggingImageComponents];
            }];
            [draggingItem setDraggingFrame:frame];
            validCount++;
        } else {
            [draggingItem setImageComponentsProvider:nil];
        }
    }];
    [draggingInfo setNumberOfValidItemsForDrop:validCount];
    [draggingInfo setDraggingFormation:NSDraggingFormationList];
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op {
    NSPasteboard *pboard = [info draggingPasteboard];
    if ([NSURL canReadURLFromPasteboard:pboard]) {
        [tv setDropRow:-1 dropOperation:NSTableViewDropOn];
        return NSDragOperationEvery;
    }
    return NSDragOperationNone;
}
       
- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)op {
    return [self pasteFromPasteboard:[info draggingPasteboard]];
}

#pragma mark NSTableViewDelegate

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [tv makeViewWithIdentifier:[tableColumn identifier] owner:self];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible] && [[QLPreviewPanel sharedPreviewPanel] dataSource] == self)
        [[QLPreviewPanel sharedPreviewPanel] reloadData];
    [self setTouchBar:nil];
}

- (void)tableView:(NSTableView *)aTableView deleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    NSUInteger row = [rowIndexes firstIndex];
    SKDownload *download = [self objectInDownloadsAtIndex:row];
    NSMutableIndexSet *removeIndexes = [NSMutableIndexSet indexSet];
    
    if ([download canCancel])
        [download cancel];
    else if ([download canRemove])
        [removeIndexes addIndex:row];
    if ([removeIndexes count])
        [self removeDownloadsAtIndexes:removeIndexes];
}

- (BOOL)tableView:(NSTableView *)aTableView canDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes {
    return YES;
}

- (void)tableView:(NSTableView *)tv pasteFromPasteboard:(NSPasteboard *)pboard {
    if (NO == [self pasteFromPasteboard:pboard])
        NSBeep();
}

- (BOOL)tableView:(NSTableView *)tv canPasteFromPasteboard:(NSPasteboard *)pboard {
    return [NSURL canReadURLFromPasteboard:pboard];
}

- (NSArray *)tableViewTypeSelectHelperSelectionStrings:(NSTableView *)aTableView {
    return [downloads valueForKey:SKDownloadFileNameKey];
}

#pragma mark Contextual menu

- (void)menuNeedsUpdate:(NSMenu *)menu {
    NSMenuItem *menuItem;
    NSInteger row = [tableView clickedRow];
    [menu removeAllItems];
    if (row != -1) {
        SKDownload *download = [self objectInDownloadsAtIndex:row];
        
        if ([download canCancel]) {
            menuItem = [menu addItemWithTitle:NSLocalizedString(@"Cancel", @"Menu item title") action:@selector(cancelDownload:) target:self];
            [menuItem setRepresentedObject:download];
        } else if ([download canRemove]) {
            menuItem = [menu addItemWithTitle:NSLocalizedString(@"Remove", @"Menu item title") action:@selector(removeDownload:) target:self];
            [menuItem setRepresentedObject:download];
        }
        if ([download canResume]) {
            menuItem = [menu addItemWithTitle:NSLocalizedString(@"Resume", @"Menu item title") action:@selector(resumeDownload:) target:self];
            [menuItem setRepresentedObject:download];
        }
        if ([download status] == SKDownloadStatusFinished && [[download fileURL] checkResourceIsReachableAndReturnError:NULL]) {
            menuItem = [menu addItemWithTitle:[NSLocalizedString(@"Open", @"Menu item title") stringByAppendingEllipsis] action:@selector(openDownloadedFile:) target:self];
            [menuItem setRepresentedObject:download];
            
            menuItem = [menu addItemWithTitle:[NSLocalizedString(@"Quick Look", @"Menu item title") stringByAppendingEllipsis] action:@selector(previewDownloadedFile:) target:self];
            [menuItem setRepresentedObject:download];
            
            menuItem = [menu addItemWithTitle:[NSLocalizedString(@"Reveal", @"Menu item title") stringByAppendingEllipsis] action:@selector(revealDownloadedFile:) target:self];
            [menuItem setRepresentedObject:download];
            
            menuItem = [menu addItemWithTitle:NSLocalizedString(@"Move to Trash", @"Menu item title") action:@selector(trashDownloadedFile:) target:self];
            [menuItem setRepresentedObject:download];
        }
    }
}

#pragma mark KVO

- (void)startObservingDownloads:(NSArray *)newDownloads {
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [newDownloads count])];
    [newDownloads addObserver:self toObjectsAtIndexes:indexes forKeyPath:SKDownloadFileURLKey options:0 context:&SKDownloadPropertiesObservationContext];
    [newDownloads addObserver:self toObjectsAtIndexes:indexes forKeyPath:SKDownloadStatusKey options:0 context:&SKDownloadPropertiesObservationContext];
}

- (void)endObservingDownloads:(NSArray *)oldDownloads {
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [oldDownloads count])];
    [oldDownloads removeObserver:self fromObjectsAtIndexes:indexes forKeyPath:SKDownloadFileURLKey context:&SKDownloadPropertiesObservationContext];
    [oldDownloads removeObserver:self fromObjectsAtIndexes:indexes forKeyPath:SKDownloadStatusKey context:&SKDownloadPropertiesObservationContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKDownloadPropertiesObservationContext) {
        if ([downloads containsObject:object]) {
            if ([keyPath isEqualToString:SKDownloadFileURLKey]) {
                [tableView reloadTypeSelectStrings];
            } else if ([keyPath isEqualToString:SKDownloadStatusKey]) {
                [self updateClearButton];
                [self setTouchBar:nil];
                if ([object status] == SKDownloadStatusFinished) {
                    [self openDownload:object];
                    if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible] && [[QLPreviewPanel sharedPreviewPanel] dataSource] == self && [tableView isRowSelected:[downloads indexOfObject:object]])
                        [[QLPreviewPanel sharedPreviewPanel] reloadData];
                }
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Toolbar

- (void)setupToolbar {
    // Create a new toolbar instance, and attach it to our window
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:SKDownloadsToolbarIdentifier];
    
    [toolbar setAllowsUserCustomization:NO];
    [toolbar setAutosavesConfiguration:NO];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [toolbar setSizeMode:NSToolbarSizeModeSmall];

    // We are the delegate
    [toolbar setDelegate:self];
    
    // Attach the toolbar to the window
    [[self window] setToolbar:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)willBeInserted {
    NSToolbarItem *item = nil;
    if ([itemIdent isEqualToString:SKDownloadsToolbarPreferencesItemIdentifier]) {
        item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDownloadsToolbarPreferencesItemIdentifier];
        [item setToolTip:NSLocalizedString(@"Download preferences", @"Tool tip message")];
        [item setImage:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
        [item setTarget:self];
        [item setAction:@selector(showDownloadPreferences:)];
    } else if ([itemIdent isEqualToString:SKDownloadsToolbarClearItemIdentifier]) {
        item = [[NSToolbarItem alloc] initWithItemIdentifier:SKDownloadsToolbarClearItemIdentifier];
        [item setView:clearButton];
        [item setMinSize:[clearButton bounds].size];
        [item setMaxSize:[clearButton bounds].size];
    }
    return item;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[SKDownloadsToolbarClearItemIdentifier,
            NSToolbarFlexibleSpaceItemIdentifier,
            SKDownloadsToolbarPreferencesItemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return @[SKDownloadsToolbarPreferencesItemIdentifier,
            NSToolbarFlexibleSpaceItemIdentifier,
            SKDownloadsToolbarClearItemIdentifier];
}

#pragma mark Quick Look Panel Support

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel {
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel {
    [panel setDelegate:self];
    [panel setDataSource:self];
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
    NSUInteger row = [[tableView selectedRowIndexes] lastIndex];
    SKDownload *download = nil;
    if (row != NSNotFound) {
        download = [self objectInDownloadsAtIndex:row];
        if ([download status] == SKDownloadStatusFinished && [[download fileURL] checkResourceIsReachableAndReturnError:NULL])
            return 1;
    }
    return 0;
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)anIndex {
    NSUInteger row = [[tableView selectedRowIndexes] lastIndex];
    SKDownload *download = nil;
    if (row != NSNotFound)
        download = [self objectInDownloadsAtIndex:row];
    return download;
}

- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item {
    NSUInteger row = [downloads indexOfObject:item];
    NSRect iconRect = NSZeroRect;
    if (row != NSNotFound) {
        iconRect = [tableView frameOfCellAtColumn:0 row:row];
        if (NSIntersectsRect([tableView visibleRect], iconRect)) {
            iconRect = [tableView convertRectToScreen:iconRect];
        } else {
            iconRect = NSZeroRect;
        }
    }
    return iconRect;
}

- (NSImage *)previewPanel:(QLPreviewPanel *)panel transitionImageForPreviewItem:(id <QLPreviewItem>)item contentRect:(NSRect *)contentRect {
    return [(SKDownload *)item fileIcon];
}

- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event {
    if ([event type] == NSEventTypeKeyDown) {
        [tableView keyDown:event];
        return YES;
    }
    return NO;
}

#pragma mark NSURLSession support

- (NSURLSession *)session {
    if (session == nil) {
        session = [NSURLSession
                    sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                    delegate:self
                    delegateQueue:[NSOperationQueue mainQueue]];
    }
    return session;
}

- (NSURLSessionDownloadTask *)newDownloadTaskForDownload:(SKDownload *)download {
    NSData *resumeData = [download resumeData];
    NSURL *url = [download URL];
    NSURLSessionDownloadTask *task = nil;
    if (resumeData)
        task = [[self session] downloadTaskWithResumeData:resumeData];
    else if (url)
        task = [[self session] downloadTaskWithURL:url];
    else
        return nil;
    if (downloadsForTasks == nil)
        downloadsForTasks = [NSMapTable strongToStrongObjectsMapTable];
    [downloadsForTasks setObject:download forKey:task];
    [task resume];
    return task;
}

- (void)removeDownloadTask:(NSURLSessionDownloadTask *)task {
    [downloadsForTasks removeObjectForKey:task];
}

#pragma mark NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)aSession downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    SKDownload *download = [downloadsForTasks objectForKey:task];
    [download downloadDidWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
}

- (void)URLSession:(NSURLSession *)aSession downloadTask:(NSURLSessionDownloadTask *)task didFinishDownloadingToURL:(NSURL *)location {
    SKDownload *download = [downloadsForTasks objectForKey:task];
    [download downloadDidFinishDownloadingToURL:location];
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)aSession task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && ([[error domain] isEqualToString:NSURLErrorDomain] == NO || [error code] != NSURLErrorCancelled)) {
        SKDownload *download = [downloadsForTasks objectForKey:task];
        NSData *resumeData = [[error userInfo] objectForKey:NSURLSessionDownloadTaskResumeData];
        if (resumeData)
            [download setResumeData:resumeData];
        [download downloadDidFailWithError:error];
    }
    [downloadsForTasks removeObjectForKey:task];
}

#pragma mark Touch Bar

- (NSTouchBar *)makeTouchBar {
    NSTouchBar *touchBar = [[NSTouchBar alloc] init];
    [touchBar setDelegate:self];
    NSInteger selectedRow = [tableView selectedRow];
    SKDownload *download = selectedRow != -1 ? [self objectInDownloadsAtIndex:selectedRow] : nil;
    NSMutableArray *identifiers = [NSMutableArray arrayWithObjects:SKTouchBarItemIdentifierClear, NSTouchBarItemIdentifierFixedSpaceSmall, nil];
    if ([download canResume])
        [identifiers addObject:SKTouchBarItemIdentifierResume];
    if ([download canCancel])
        [identifiers addObject:SKTouchBarItemIdentifierCancel];
    if ([download canRemove])
        [identifiers addObject:SKTouchBarItemIdentifierRemove];
    [touchBar setDefaultItemIdentifiers:identifiers];
    return touchBar;
}

- (NSTouchBarItem *)touchBar:(NSTouchBar *)aTouchBar makeItemForIdentifier:(NSString *)identifier {
    NSCustomTouchBarItem *item = [touchBarItems objectForKey:identifier];
    if (item == nil) {
        if (touchBarItems == nil)
            touchBarItems = [[NSMutableDictionary alloc] init];
        if ([identifier isEqualToString:SKTouchBarItemIdentifierClear]) {
            if (tbClearButton == nil) {
                tbClearButton = [NSButton buttonWithTitle:[clearButton title] target:[clearButton target] action:[clearButton action]];
                [self updateClearButton];
            }
            item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
            [(NSCustomTouchBarItem *)item setView:tbClearButton];
        } else if ([identifier isEqualToString:SKTouchBarItemIdentifierResume]) {
            if (resumeButton == nil) {
                resumeButton = [NSButton buttonWithImage:[NSImage imageNamed:SKImageNameTouchBarRefresh] target:self action:@selector(resumeDownload:)];
            }
            item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
            [(NSCustomTouchBarItem *)item setView:resumeButton];
        } else if ([identifier isEqualToString:SKTouchBarItemIdentifierCancel]) {
            if (cancelButton == nil) {
                cancelButton = [NSButton buttonWithImage:[NSImage imageNamed:SKImageNameTouchBarStopProgress] target:self action:@selector(cancelDownload:)];
            }
            item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
            [(NSCustomTouchBarItem *)item setView:cancelButton];
        } else if ([identifier isEqualToString:SKTouchBarItemIdentifierRemove]) {
            if (removeButton == nil) {
                removeButton = [NSButton buttonWithImage:[NSImage imageNamed:NSImageNameTouchBarDeleteTemplate] target:self action:@selector(removeDownload:)];
            }
            item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
            [(NSCustomTouchBarItem *)item setView:removeButton];
        }
        if (item)
            [touchBarItems setObject:item forKey:identifier];
    }
    return item;
}

@end
