//
//  BDSKFileMatcher.m
//  Bibdesk
//
//  Created by Adam Maxwell on 02/09/07.
/*
 This software is Copyright (c) 2007
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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

#import "BDSKFileMatcher.h"
#import "BibItem.h"
#import "BDSKTreeNode.h"
#import "BDSKTextWithIconCell.h"
#import "BDSKDocumentController.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BibDocument_Actions.h"
#import "NSImage+Toolbox.h"
#import "BibAuthor.h"
#import <libkern/OSAtomic.h>

static CFIndex MAX_SEARCHKIT_RESULTS = 10;

@interface BDSKFileMatcher (Private)

- (NSArray *)currentPublications;
- (void)setCurrentPublications:(NSArray *)pubs;
- (NSArray *)treeNodesWithCurrentPublications;
- (void)doSearch;
- (void)makeNewIndex;

// only use from main thread
- (void)updateProgressIndicatorWithNumber:(NSNumber *)val;

// entry point to the searching/matching; acquire indexingLock first
- (void)indexFiles:(NSArray *)absoluteURLs;

@end

@implementation BDSKFileMatcher

+ (id)sharedInstance;
{
    static id sharedInstance = nil;
    if (nil == sharedInstance)
        sharedInstance = [[self alloc] init];
    return sharedInstance;
}

- (id)init
{
    self = [super initWithWindowNibName:[self windowNibName]];
    if (self) {
        matches = [[NSMutableArray alloc] init];
        searchIndex = NULL;
        indexingLock = [[NSLock alloc] init];
        currentPublications = nil;
        _matchFlags.shouldAbortThread = 0;
    }
    return self;
}

- (NSString *)windowNibName { return @"FileMatcher"; }

- (void)dealloc
{
    [matches release];
    [indexingLock release];
    if (searchIndex)
        SKIndexClose(searchIndex);
    [super dealloc];
}

- (void)awakeFromNib
{
    [outlineView setAutosaveExpandedItems:YES];
    BDSKTextWithIconCell *cell = [[BDSKTextWithIconCell alloc] initTextCell:@""];
    [cell setDrawsHighlight:NO];
    [cell setImagePosition:NSImageLeft];
    [[[outlineView tableColumns] lastObject] setDataCell:cell];
    [cell release];
    
    [outlineView setDoubleAction:@selector(openAction:)];
    [outlineView setTarget:self];
    [outlineView registerForDraggedTypes:[NSArray arrayWithObject:NSURLPboardType]];
    [progressIndicator setUsesThreadedAnimation:YES];
    [abortButton setEnabled:NO];
}

// API: try to match these files with the front document
- (void)matchFiles:(NSArray *)absoluteURLs;
{
    [matches removeAllObjects];
    BibDocument *doc = [[NSDocumentController sharedDocumentController] mainDocument];
    if (nil == doc) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"No front document", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"You need to open a document in order to match publications.", @"")];
        [alert runModal];
    } else {        
        // for the progress indicator
        [[self window] makeKeyAndOrderFront:self];
        [abortButton setEnabled:YES];

        OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&_matchFlags.shouldAbortThread);
        
        // block if necessary until the thread aborts
        [indexingLock lock];
        
        // okay to set pubs here, since we have the lock
        [self setCurrentPublications:(id)[doc publications]];
        OSAtomicCompareAndSwap32Barrier(1, 0, (int32_t *)&_matchFlags.shouldAbortThread);
        [NSThread detachNewThreadSelector:@selector(indexFiles:) toTarget:self withObject:absoluteURLs];
        
        // the first thing the thread will do is block until it acquires the lock, so let it go
        [indexingLock unlock];
    }
}

- (IBAction)openAction:(id)sender;
{
    id clickedItem = [outlineView itemAtRow:[outlineView clickedRow]];
    id obj = [clickedItem valueForKey:@"pub"];
    if (obj && [[obj owner] respondsToSelector:@selector(editPub:)])
        [[obj owner] editPub:obj];
    else if ((obj = [clickedItem valueForKey:@"fileURL"]))
        [[NSWorkspace sharedWorkspace] openURL:obj withSearchString:[clickedItem valueForKey:@"searchString"]];
    else NSBeep();
}

- (IBAction)abort:(id)sender;
{
    if (false == OSAtomicCompareAndSwap32Barrier(0, 1, (int32_t *)&_matchFlags.shouldAbortThread))
        NSBeep();
    [abortButton setEnabled:NO];
}

#pragma mark Outline view drag-and-drop

- (BOOL)outlineView:(NSOutlineView *)olv writeItems:(NSArray*)items toPasteboard:(NSPasteboard*)pboard;
{
    id item = [items lastObject];
    if ([item isLeaf]) {
        [pboard declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
        [[item valueForKey:@"fileURL"] writeToPasteboard:pboard];
        return YES;
    }
    return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView*)olv validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index;
{
    if ([[info draggingSource] isEqual:outlineView] && [item isLeaf] == NO) {
        [olv setDropItem:item dropChildIndex:NSOutlineViewDropOnItemIndex];
        return NSDragOperationLink;
    }
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView*)olv acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index;
{
    NSURL *fileURL = [NSURL URLFromPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]];
    if (nil == fileURL)
        return NO;
    
    BibItem *pub = [item valueForKey:@"pub"];
    if ([pub localURL]) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:NSLocalizedString(@"Publication already has a file", @"")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
        [alert addButtonWithTitle:NSLocalizedString(@"Overwrite", @"")];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"The publication's file is", @""), [[[pub localURL] path] stringByAbbreviatingWithTildeInPath]]];
        int rv = [alert runModal];
        if (NSAlertSecondButtonReturn == rv)
            [pub setField:BDSKLocalUrlString toValue:[fileURL absoluteString]];
    } else {
        [pub setField:BDSKLocalUrlString toValue:[fileURL absoluteString]];
    }
    return YES;
}

// return a larger row height for the items; tried using a spotlight controller image, but row size is too large to be practical
- (float)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    return [item isLeaf] ? 17.0f : 48.0f;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item;
{
    return [item isLeaf];
}

#pragma mark Outline view datasource

- (id)outlineView:(NSOutlineView *)ov child:(int)index ofItem:(id)item;
{
    return nil == item ? [matches objectAtIndex:index] : [[item children] objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item;
{
    return item ? (NO == [item isLeaf]) : YES;
}

- (int)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item;
{
    return item ? [item numberOfChildren] : [matches count];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;
{
    return item;
}

- (id)outlineView:(NSOutlineView *)ov itemForPersistentObject:(id)object
{
    return [NSKeyedUnarchiver unarchiveObjectWithData:object];
}

// return archived item
- (id)outlineView:(NSOutlineView *)ov persistentObjectForItem:(id)item
{
    return [NSKeyedArchiver archivedDataWithRootObject:item];
}

@end

@implementation BDSKFileMatcher (Private)

- (NSArray *)currentPublications { return currentPublications; }
- (void)setCurrentPublications:(NSArray *)pubs;
{
    if (pubs != currentPublications) {
        [currentPublications release];
        currentPublications = [pubs copy];
    }
}

static NSString *searchStringWithPub(BibItem *pub)
{
    // may be better ways to do this, but we'll try a phrase search and then append the first author's last name (if available)
    NSMutableString *searchString = [NSMutableString stringWithFormat:@"\"%@\"", [pub title]];
    NSString *name = [[pub firstAuthor] lastName];
    if (name)
        [searchString appendFormat:@" AND %@", [[pub firstAuthor] lastName]];
    return searchString;
}

static NSString *titleStringWithPub(BibItem *pub)
{
    return [NSString stringWithFormat:@"%@ (%@)", [pub displayTitle], [pub pubAuthorsForDisplay]];
}

- (NSArray *)treeNodesWithCurrentPublications;
{
    NSAssert([NSThread inMainThread], @"method must be called from the main thread");
    NSEnumerator *pubE = [[self currentPublications] objectEnumerator];
    BibItem *pub;
    NSMutableArray *nodes = [NSMutableArray arrayWithCapacity:[[self currentPublications] count]];
    while (pub = [pubE nextObject]) {
        BDSKTreeNode *theNode = [[BDSKTreeNode alloc] init];

        // we add the pub to the tree so it's retained, but don't touch it in the thread!
        [theNode setValue:pub forKey:@"pub"];
        
        // grab these strings on the main thread, since we need them in the worker thread
        [theNode setValue:titleStringWithPub(pub)  forKey:OATextWithIconCellStringKey];
        [theNode setValue:searchStringWithPub(pub) forKey:@"searchString"];

        [theNode setValue:[NSImage imageNamed:@"cacheDoc"] forKey:OATextWithIconCellImageKey];

        [nodes addObject:theNode];
        [theNode release];
    }
    return nodes;
}

// this method iterates available publications, trying to match them up with a file
- (void)doSearch;
{
    // get the root nodes array on the main thread, since it uses BibItem methods
    NSArray *treeNodes = nil;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(treeNodesWithCurrentPublications)]];
    [invocation setTarget:self];
    [invocation setSelector:@selector(treeNodesWithCurrentPublications)];
    [invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
    [invocation getReturnValue:&treeNodes];
    
    OBPOSTCONDITION([treeNodes count]);
        
    NSParameterAssert(NULL != searchIndex);
    SKIndexFlush(searchIndex);

    [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(1.0)] waitUntilDone:NO];
    [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:[NSLocalizedString(@"Searching document", @"") stringByAppendingEllipsis] waitUntilDone:NO];

    double val = 0;
    double max = [treeNodes count];
    
    NSEnumerator *e = [treeNodes objectEnumerator];
    BDSKTreeNode *node;
    
    while (0 == _matchFlags.shouldAbortThread && (node = [e nextObject])) {
        
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        
        NSString *searchString = [node valueForKey:@"searchString"];
        
        // we're not using rankings, so don't bother computing them
        SKSearchRef search = SKSearchCreate(searchIndex, (CFStringRef)searchString, kSKSearchOptionNoRelevanceScores);
        
        // if we get more than 10 matches back per pub, the results will be pretty useless anyway
        SKDocumentID docID[MAX_SEARCHKIT_RESULTS];
        CFIndex numFound;
        
        // could loop here if we need to, or increase search time
        SKSearchFindMatches(search, MAX_SEARCHKIT_RESULTS, docID, NULL, 1, &numFound);
        
        if (numFound) {
            
            CFURLRef urls[MAX_SEARCHKIT_RESULTS];
            SKIndexCopyDocumentURLsForDocumentIDs(searchIndex, numFound, docID, urls);
            
            int i, iMax = numFound;
            
            // now we have a matching file; we could remove it from the index, but multiple matches are reasonable
            for (i =  0; i < iMax; i++) {
                BDSKTreeNode *child = [[BDSKTreeNode alloc] init];
                [child setValue:(id)urls[i] forKey:@"fileURL"];
                [child setValue:[[(id)urls[i] path] stringByAbbreviatingWithTildeInPath] forKey:OATextWithIconCellStringKey];
                [child setValue:[[NSWorkspace sharedWorkspace] iconForFileURL:(NSURL *)urls[i]] forKey:OATextWithIconCellImageKey];
                [child setValue:searchString forKey:@"searchString"];
                [node addChild:child];
                [child release];
            }
            [matches addObject:node];
        }
        SKSearchCancel(search);
        CFRelease(search);
        
        val++;
        [outlineView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
        [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(val/max)] waitUntilDone:NO];
        [pool release];
    }
    
    if (0 == _matchFlags.shouldAbortThread) {
        [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(1.0)] waitUntilDone:NO];
        [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:NSLocalizedString(@"Search complete!", @"") waitUntilDone:NO];
    } else {
        [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:NSLocalizedString(@"Search aborted.", @"") waitUntilDone:NO];
    }
}

- (void)makeNewIndex;
{
    if (searchIndex)
        SKIndexClose(searchIndex);
    CFMutableDataRef indexData = CFDataCreateMutable(CFAllocatorGetDefault(), 0);
    
    CFMutableDictionaryRef opts = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    // we generally shouldn't need to index the (default) first 2000 terms just to get title and author
    CFDictionaryAddValue(opts, kSKMaximumTerms, (CFNumberRef)[NSNumber numberWithInt:200]);
    
    // kSKProximityIndexing is unused for now, since it slows things down and caused a crash on one of my files rdar://problem/4988691
    // CFDictionaryAddValue(opts, kSKProximityIndexing, kCFBooleanTrue);
    searchIndex = SKIndexCreateWithMutableData(indexData, NULL, kSKIndexInverted, opts);
    CFRelease(opts);
    CFRelease(indexData);
}   

- (void)updateProgressIndicatorWithNumber:(NSNumber *)val;
{
    [progressIndicator setDoubleValue:[val doubleValue]];
}

- (void)indexFiles:(NSArray *)absoluteURLs;
{    
    NSAutoreleasePool *threadPool = [NSAutoreleasePool new];
    
    [indexingLock lock];
    
    // empty out a previous index (if any)
    [self makeNewIndex];
    
    double val = 0;
    double max = [absoluteURLs count];
    NSEnumerator *e = [absoluteURLs objectEnumerator];
    NSURL *url;
    
    [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(0.0)] waitUntilDone:NO];
    [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:[NSLocalizedString(@"Indexing files", @"") stringByAppendingEllipsis] waitUntilDone:NO];
    
    // some HTML files cause a deadlock or crash in -[NSHTMLReader _loadUsingLibXML2] rdar://problem/4988303
    BOOL shouldLog = [[NSUserDefaults standardUserDefaults] boolForKey:@"BDSKShouldLogFilesAddedToMatchingSearchIndex"];
    
    while (0 == _matchFlags.shouldAbortThread && (url = [e nextObject])) {
        SKDocumentRef doc = SKDocumentCreateWithURL((CFURLRef)url);
        
        if (shouldLog)
            NSLog(@"%@", url);
        
        if (doc) {
            SKIndexAddDocument(searchIndex, doc, NULL, TRUE);
            CFRelease(doc);
        }
        // forcing a redisplay at every step is ok since adding documents to the index is pretty slow
        val++;      
        [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(val/max)] waitUntilDone:NO];
    }
    
    if (0 == _matchFlags.shouldAbortThread) {
        [self performSelectorOnMainThread:@selector(updateProgressIndicatorWithNumber:) withObject:[NSNumber numberWithDouble:(1.0)] waitUntilDone:NO];
        [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:NSLocalizedString(@"Indexing complete!", @"") waitUntilDone:NO];
        [self doSearch];
    } else {
        [statusField performSelectorOnMainThread:@selector(setStringValue:) withObject:NSLocalizedString(@"Indexing aborted.", @"") waitUntilDone:NO];
    }

    [indexingLock unlock];
    [threadPool release];
}

@end

