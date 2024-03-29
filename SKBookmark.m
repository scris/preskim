//
//  SKBookmark.m
//  Skim
//
//  Created by Christiaan Hofman on 9/15/07.
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

#import "SKBookmark.h"
#import "SKAlias.h"
#import "NSImage_SKExtensions.h"
#import "NSDocument_SKExtensions.h"
#import "SKDocumentController.h"
#import "NSURL_SKExtensions.h"
#import "NSError_SKExtensions.h"
#import "NSShadow_SKExtensions.h"
#import "SKBookmarkController.h"
#import "NSCharacterSet_SKExtensions.h"
#import "NSDate_SKExtensions.h"

#define BOOKMARK_STRING     @"bookmark"
#define SESSION_STRING      @"session"
#define FOLDER_STRING       @"folder"
#define SEPARATOR_STRING    @"separator"

#define PROPERTIES_KEY  @"properties"
#define CHILDREN_KEY    @"children"
#define LABEL_KEY       @"label"
#define PAGEINDEX_KEY   @"pageIndex"
#define ALIASDATA_KEY   @"_BDAlias"
#define BOOKMARK_KEY    @"bookmark"
#define TYPE_KEY        @"type"

@interface SKPlaceholderBookmark : SKBookmark
@end

@interface SKFileBookmark : SKBookmark {
    SKAlias *alias;
    NSString *label;
    NSUInteger pageIndex;
    NSDictionary *setup;
}
@end

@interface SKFolderBookmark : SKBookmark {
    NSString *label;
    NSMutableArray *children;
}
@end

@interface SKRootBookmark : SKFolderBookmark
@end

@interface SKSessionBookmark : SKFolderBookmark
@end

@interface SKSeparatorBookmark : SKBookmark
@end

#pragma mark -

@implementation SKBookmark

@synthesize parent;
@dynamic properties, bookmarkType, label, icon, alternateIcon, fileURL, fileURLToOpen, fileDescription, toolTip, pageIndex, pageNumber, hasSetup, tabs, containingBookmarks, children, countOfChildren, scriptingParent, entireContents, bookmarks, expanded, skimURL;

static Class SKBookmarkClass = Nil;

+ (void)initialize {
    SKINITIALIZE;
    SKBookmarkClass = self;
}

+ (instancetype)allocWithZone:(NSZone *)aZone {
    if (SKBookmarkClass == self) {
        static SKPlaceholderBookmark *placeholderBookmark = nil;
        dispatch_once_t onceToken = 0;
        dispatch_once(&onceToken, ^{
            placeholderBookmark = [SKPlaceholderBookmark alloc];
        });
        return placeholderBookmark;
    } else {
        return [super allocWithZone:aZone];
    }
}

+ (NSArray *)bookmarksForURLs:(NSArray *)urls {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    NSMutableArray *array = [NSMutableArray array];
    
    for (NSURL *url in urls) {
        NSString *fileType = [dc typeForContentsOfURL:url error:NULL];
        Class docClass;
        SKBookmark *bookmark;
        NSString *label = nil;
        [url getResourceValue:&label forKey:NSURLLocalizedNameKey error:NULL];
        if ([[NSWorkspace sharedWorkspace] type:fileType conformsToType:SKFolderDocumentType]) {
            NSArray *children = [self bookmarksForURLs:[fm contentsOfDirectoryAtURL:url includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL]];
            if ([children count] && (bookmark = [[self alloc] initFolderWithChildren:children label:label])) {
                [array addObject:bookmark];
            }
        } else if ((docClass = [dc documentClassForType:fileType])) {
            if ((bookmark = [[self alloc] initWithURL:url pageIndex:([docClass isPDFDocument] ? 0 : NSNotFound) label:label])) {
                [array addObject:bookmark];
            }
        }
    }
    
    return array;
}

- (instancetype)initWithURL:(NSURL *)aURL pageIndex:(NSUInteger)aPageIndex label:(NSString *)aLabel {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithSetup:(NSDictionary *)aSetupDict label:(NSString *)aLabel {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initRootWithChildrenProperties:(NSArray *)childrenProperties {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initSessionWithSetups:(NSArray *)aSetupDicts label:(NSString *)aLabel {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initSeparator {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithProperties:(NSDictionary *)dictionary {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)copyWithZone:(NSZone *)aZone { 	 
    return [[SKBookmark alloc] initWithProperties:[self properties]];
}

- (NSDictionary *)properties { return nil; }

- (SKBookmarkType)bookmarkType { return SKBookmarkTypeSeparator; }

- (NSImage *)icon { return nil; }
- (NSImage *)alternateIcon { return [self icon]; }

- (NSString *)label { return nil; }
- (void)setLabel:(NSString *)newLabel {}

- (NSURL *)fileURL { return nil; }
- (void)setFileURL:(NSURL *)fileURL {}
- (NSURL *)fileURLToOpen { return nil; }
- (NSString *)fileDescription { return nil; }
- (NSString *)toolTip { return nil; }

- (NSUInteger)pageIndex { return NSNotFound; }
- (void)setPageIndex:(NSUInteger)newPageIndex {}
- (NSNumber *)pageNumber { return nil; }
- (void)setPageNumber:(NSNumber *)newPageNumber {}

- (NSURL *)previewItemURL { return [self fileURL]; }
- (NSString *)previewItemTitle { return [self label]; }

- (BOOL)hasSetup { return NO; }

- (NSArray *)containingBookmarks { return @[]; }

- (NSArray *)children { return nil; }
- (NSUInteger)countOfChildren { return 0; }
- (SKBookmark *)objectInChildrenAtIndex:(NSUInteger)anIndex { return nil; }
- (NSArray *)childrenAtIndexes:(NSIndexSet *)indexes { return nil; }
- (void)insertObject:(SKBookmark *)child inChildrenAtIndex:(NSUInteger)anIndex {}
- (void)insertChildren:(NSArray *)newChildren atIndexes:(NSIndexSet *)indexes {}
- (void)removeObjectFromChildrenAtIndex:(NSUInteger)anIndex {}
- (void)removeChildrenAtIndexes:(NSIndexSet *)indexes {}

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSUInteger idx = [[parent children] indexOfObjectIdenticalTo:self];
    if (idx != NSNotFound) {
        NSScriptObjectSpecifier *containerRef = nil;
        NSScriptClassDescription *containerClassDescription = nil;
        if ([parent parent]) {
            containerRef = [parent objectSpecifier];
            containerClassDescription = [containerRef keyClassDescription];
        } else {
            containerClassDescription = [NSScriptClassDescription classDescriptionForClass:[NSApp class]];
        }
        return [[NSIndexSpecifier alloc] initWithContainerClassDescription:containerClassDescription containerSpecifier:containerRef key:@"bookmarks" index:idx];
    } else {
        return nil;
    }
}

- (SKBookmark *)scriptingParent {
    return [parent parent] == nil ? nil : parent;
}

- (NSArray *)entireContents { return nil; }

- (BOOL)isExpanded {
    return [[SKBookmarkController sharedBookmarkController] isBookmarkExpanded:self];
}

- (void)setExpanded:(BOOL)flag {
    [[SKBookmarkController sharedBookmarkController] setExpanded:flag forBookmark:self];
}

- (NSArray *)bookmarks {
    return [self children];
}

- (void)insertObject:(SKBookmark *)bookmark inBookmarksAtIndex:(NSUInteger)anIndex {
    [[SKBookmarkController sharedBookmarkController] insertBookmark:bookmark atIndex:anIndex ofBookmark:self animate:NO];
}

- (void)removeObjectFromBookmarksAtIndex:(NSUInteger)anIndex {
    [[SKBookmarkController sharedBookmarkController] removeBookmarkAtIndex:anIndex ofBookmark:self animate:NO];
}

- (id)newScriptingObjectOfClass:(Class)objectClass forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties {
    if ([key isEqualToString:@"bookmarks"]) {
        [[NSScriptCommand currentCommand] setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [[NSScriptCommand currentCommand] setScriptErrorString:@"Invalid container for new bookmark."];
        return nil;
    }
    return [super newScriptingObjectOfClass:objectClass forValueForKey:key withContentsValue:contentsValue properties:properties];
}

- (BOOL)isDescendantOf:(SKBookmark *)bookmark {
    if (self == bookmark)
        return YES;
    for (SKBookmark *child in [bookmark children]) {
        if ([self isDescendantOf:child])
            return YES;
    }
    return NO;
}

- (BOOL)isDescendantOfArray:(NSArray *)bookmarks {
    for (SKBookmark *bm in bookmarks) {
        if ([self isDescendantOf:bm]) return YES;
    }
    return NO;
}

- (NSURL *)skimURL {
    if ([self bookmarkType] == SKBookmarkTypeSeparator)
        return nil;
    SKBookmark *bookmark = self;
    NSMutableString *path = [NSMutableString string];
    while ([bookmark parent] != nil) {
        NSString *component = [[bookmark label] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLBookmarkNameAllowedCharacterSet]];
        [path replaceCharactersInRange:NSMakeRange(0, 0) withString:component];
        [path replaceCharactersInRange:NSMakeRange(0, 0) withString:@"/"];
        bookmark = [bookmark parent];
    }
    NSURLComponents *components = [[NSURLComponents alloc] init];
    [components setScheme:@"pskn"];
    [components setHost:@"bookmarks"];
    [components setPath:path];
    NSURL *url = [components URL];
    return url;
}

@end

#pragma mark -

@implementation SKPlaceholderBookmark

- (instancetype)init {
    return nil;
}

- (instancetype)initWithURL:(NSURL *)aURL pageIndex:(NSUInteger)aPageIndex label:(NSString *)aLabel {
    return (id)[[SKFileBookmark alloc] initWithURL:aURL pageIndex:aPageIndex label:aLabel];
}

- (instancetype)initWithSetup:(NSDictionary *)aSetupDict label:(NSString *)aLabel {
    return (id)[[SKFileBookmark alloc] initWithSetup:aSetupDict label:aLabel];
}

- (instancetype)initFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    return (id)[[SKFolderBookmark alloc] initFolderWithChildren:aChildren label:aLabel];
}

- (instancetype)initRootWithChildrenProperties:(NSArray *)childrenProperties {
    NSMutableArray *aChildren = [NSMutableArray array];
    SKBookmark *child;
    for (NSDictionary *dict in childrenProperties) {
        if ((child = [[SKBookmark alloc] initWithProperties:dict])) {
            [aChildren addObject:child];
        }
    }
    return (id)[[SKRootBookmark alloc] initFolderWithChildren:aChildren label:NSLocalizedString(@"Bookmarks Menu", @"Menu item title")];
}

- (instancetype)initSessionWithSetups:(NSArray *)aSetupDicts label:(NSString *)aLabel {
    NSMutableArray *aChildren = [NSMutableArray array];
    SKBookmark *child;
    for (NSDictionary *setup in aSetupDicts) {
        if ((child = [[SKBookmark alloc] initWithSetup:setup label:@""])) {
            [aChildren addObject:child];
        }
    }
    return (id)[[SKSessionBookmark alloc] initFolderWithChildren:aChildren label:aLabel];
}

- (instancetype)initSeparator {
    return (id)[[SKSeparatorBookmark alloc] init];
}

- (instancetype)initWithProperties:(NSDictionary *)dictionary {
    NSString *type = [dictionary objectForKey:TYPE_KEY];
    if ([type isEqualToString:SEPARATOR_STRING]) {
        return (id)[[SKSeparatorBookmark alloc] init];
    } else if ([type isEqualToString:FOLDER_STRING] || [type isEqualToString:SESSION_STRING]) {
        Class bookmarkClass = [type isEqualToString:FOLDER_STRING] ? [SKFolderBookmark class] : [SKSessionBookmark class];
        NSMutableArray *newChildren = [NSMutableArray array];
        SKBookmark *child;
        for (NSDictionary *dict in [dictionary objectForKey:CHILDREN_KEY]) {
            if ((child = [[SKBookmark alloc] initWithProperties:dict])) {
                [newChildren addObject:child];
            } else
                NSLog(@"Failed to read child bookmark: %@", dict);
        }
        return (id)[[bookmarkClass alloc] initFolderWithChildren:newChildren label:[dictionary objectForKey:LABEL_KEY]];
    } else {
        return (id)[[SKFileBookmark alloc] initWithSetup:dictionary label:[dictionary objectForKey:LABEL_KEY]];
    }
}

@end

#pragma mark -

@implementation SKFileBookmark

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"pageNumber"])
        keyPaths = [keyPaths setByAddingObjectsFromSet:[NSSet setWithObjects:@"pageIndex", nil]];
    else if ([key isEqualToString:@"fileDescription"] || [key isEqualToString:@"toolTip"] || [key isEqualToString:@"icon"])
        keyPaths = [keyPaths setByAddingObjectsFromSet:[NSSet setWithObjects:@"fileURL", nil]];
    return keyPaths;
}

+ (NSImage *)iconForFileType:(NSString *)type hasSetup:(BOOL)hasSetup {
    NSImage *icon = nil;
    if (hasSetup) {
        static NSMutableDictionary *setupFileTypeIcons = nil;
        icon = [setupFileTypeIcons objectForKey:type ?: @""];
        if (icon == nil) {
            if (setupFileTypeIcons == nil)
                setupFileTypeIcons = [[NSMutableDictionary alloc] init];
            icon = [self iconForFileType:type hasSetup:NO];
            NSImage *badge = [NSImage imageNamed:NSImageNameSmartBadgeTemplate];
            icon = [NSImage imageWithSize:NSMakeSize(16.0, 16.0) flipped:NO drawingHandler:^(NSRect rect) {
                [[NSColor darkGrayColor] setFill];
                [NSBezierPath fillRect:NSMakeRect(8.0, 0.0, 8.0, 8.0)];
                [badge drawInRect:NSMakeRect(8.0, 0.0, 8.0, 8.0) fromRect:NSZeroRect operation:NSCompositingOperationDestinationAtop fraction:1.0];
                [icon drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationDestinationOver fraction:1.0];
                return YES;
            }];
            if (type)
                [icon setAccessibilityDescription:[[NSWorkspace sharedWorkspace] localizedDescriptionForType:type]];
            [setupFileTypeIcons setObject:icon forKey:type ?: @""];
        }
    } else {
        static NSMutableDictionary *fileTypeIcons = nil;
        icon = [fileTypeIcons objectForKey:type ?: @""];
        if (icon == nil) {
            if (fileTypeIcons == nil)
                fileTypeIcons = [[NSMutableDictionary alloc] init];
            if (type) {
                icon = [[NSWorkspace sharedWorkspace] iconForFileType:type];
                [icon setAccessibilityDescription:[[NSWorkspace sharedWorkspace] localizedDescriptionForType:type]];
            }
            if (icon == nil) {
                NSImage *genericDocImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
                NSImage *questionMark = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kQuestionMarkIcon)];
                icon = [NSImage imageWithSize:NSMakeSize(16.0, 16.0) flipped:NO drawingHandler:^(NSRect rect) {
                    [genericDocImage drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:0.7];
                    [questionMark drawInRect:NSMakeRect(3.0, 2.0, 10.0, 10.0) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:0.7];
                    return YES;
                }];
            }
            [fileTypeIcons setObject:icon forKey:type ?: @""];
        }
    }
    return icon;
}

- (instancetype)initWithURL:(NSURL *)aURL pageIndex:(NSUInteger)aPageIndex label:(NSString *)aLabel {
    self = [super init];
    if (self) {
        alias = [[SKAlias alloc] initWithURL:aURL];
        if (alias) {
            pageIndex = aPageIndex;
            label = [aLabel copy];
            setup = nil;
        } else {
            self = nil;
        }
    }
    return self;
}

- (instancetype)initWithSetup:(NSDictionary *)aSetupDict label:(NSString *)aLabel {
    self = [super init];
    if (self) {
        NSData *data;
        if ((data = [aSetupDict objectForKey:ALIASDATA_KEY]))
            alias = [[SKAlias alloc] initWithAliasData:data];
        else if ((data = [aSetupDict objectForKey:BOOKMARK_KEY]))
            alias = [[SKAlias alloc] initWithBookmarkData:data];
        if (alias) {
            NSNumber *pageIndexNumber = [aSetupDict objectForKey:PAGEINDEX_KEY];
            pageIndex = pageIndexNumber ? [pageIndexNumber unsignedIntegerValue] : NSNotFound;
            label = aLabel;
            setup = [aSetupDict objectForKey:SKDocumentSetupWindowFrameKey] ? [aSetupDict copy] : nil;
        } else {
            self = nil;
        }
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: label=%@, path=%@, page=%lu>", [self class], label, [[self fileURL] path], (unsigned long)pageIndex];
}

- (NSDictionary *)properties {
    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithDictionary:setup];
    NSData *data = [alias data];
    NSString *dataKey = [alias isBookmark] ? BOOKMARK_KEY : ALIASDATA_KEY;
    [properties removeObjectForKey:[dataKey isEqualToString:ALIASDATA_KEY] ? BOOKMARK_KEY : ALIASDATA_KEY];
    [properties addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:BOOKMARK_STRING, TYPE_KEY, data, dataKey, [NSNumber numberWithUnsignedInteger:pageIndex], PAGEINDEX_KEY, label, LABEL_KEY, nil]];
    return properties;
}

- (SKBookmarkType)bookmarkType {
    return SKBookmarkTypeBookmark;
}

- (NSURL *)fileURL {
    return [alias fileURLNoUI];
}

- (void)setFileURL:(NSURL *)fileURL {
    SKAlias *newAlias = [[SKAlias alloc] initWithURL:fileURL];
    if (newAlias) {
        alias = newAlias;
    }
}

- (NSURL *)fileURLToOpen {
    NSURL *fileURL = [alias fileURL];
    if (fileURL == nil && setup) {
        NSString *path = [setup objectForKey:SKDocumentSetupFileNameKey];
        if (path)
            fileURL = [NSURL fileURLWithPath:path];
    }
    return fileURL;
}

- (NSString *)fileDescription {
    return [[[self fileURL] path] stringByAbbreviatingWithTildeInPath];
}

- (NSString *)toolTip {
    return [[self fileURL] path];
}

- (NSImage *)icon {
    NSURL *fileURL = [self fileURL];
    NSString *type = fileURL ? [[NSWorkspace  sharedWorkspace] typeOfFile:[fileURL path] error:NULL] : nil;
    return [[self class] iconForFileType:type hasSetup:[self hasSetup]];
}

- (NSUInteger)pageIndex {
    return pageIndex;
}

- (void)setPageIndex:(NSUInteger)newPageIndex { pageIndex = newPageIndex; }

- (NSNumber *)pageNumber {
    return pageIndex == NSNotFound ? nil : [NSNumber numberWithUnsignedInteger:pageIndex + 1];
}

- (void)setPageNumber:(NSNumber *)newPageNumber {
    NSUInteger newNumber = [newPageNumber unsignedIntegerValue];
    if (newNumber > 0 && newNumber != pageIndex)
        [self setPageIndex:newNumber - 1];
}

- (NSString *)label {
    NSString *theLabel = label;
    if ([theLabel length] == 0)
        [[self fileURL] getResourceValue:&theLabel forKey:NSURLLocalizedNameKey error:NULL];
    return theLabel ?: @"";
}

- (void)setLabel:(NSString *)newLabel {
    if (label != newLabel) {
        label = newLabel;
    }
}

- (BOOL)hasSetup {
    return setup != nil;
}

- (NSString *)tabs {
    return [setup objectForKey:SKDocumentSetupTabsKey];
}

- (NSArray *)containingBookmarks {
    return @[self];
}

@end

#pragma mark -

@implementation SKFolderBookmark

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"fileDescription"] || [key isEqualToString:@"toolTip"])
        keyPaths = [keyPaths setByAddingObjectsFromSet:[NSSet setWithObjects:@"children", nil]];
    return keyPaths;
}

- (instancetype)initFolderWithChildren:(NSArray *)aChildren label:(NSString *)aLabel {
    self = [super init];
    if (self) {
        label = [aLabel copy];
        children = [[NSMutableArray alloc] initWithArray:aChildren];
        [children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: label=%@, children=%@>", [self class], label, children];
}

- (NSDictionary *)properties {
    return [NSDictionary dictionaryWithObjectsAndKeys:FOLDER_STRING, TYPE_KEY, [children valueForKey:PROPERTIES_KEY], CHILDREN_KEY, label, LABEL_KEY, nil];
}

- (SKBookmarkType)bookmarkType {
    return SKBookmarkTypeFolder;
}

- (NSImage *)icon {
    return [NSImage imageNamed:NSImageNameFolder];
}

- (NSImage *)alternateIcon {
    return [NSImage imageNamed:NSImageNameMultipleDocuments];
}

- (NSString *)label {
    return label ?: @"";
}

- (void)setLabel:(NSString *)newLabel {
    if (label != newLabel) {
        label = newLabel;
    }
}

- (NSString *)fileDescription {
    NSInteger count = [self countOfChildren];
    return count == 1 ? NSLocalizedString(@"1 item", @"Bookmark folder description") : [NSString stringWithFormat:NSLocalizedString(@"%ld items", @"Bookmark folder description"), (long)count];
}

- (NSString *)toolTip {
    return [self fileDescription];
}

- (NSArray *)containingBookmarks {
    NSMutableArray *contents = [NSMutableArray array];
    for (SKBookmark *bookmark in [self children])
        [contents addObjectsFromArray:[bookmark containingBookmarks]];
    return contents;
}

- (NSArray *)children {
    return children;
}

- (NSUInteger)countOfChildren {
    return [children count];
}

- (SKBookmark *)objectInChildrenAtIndex:(NSUInteger)anIndex {
    return [children objectAtIndex:anIndex];
}

- (NSArray *)childrenAtIndexes:(NSIndexSet *)indexes {
    return [children objectsAtIndexes:indexes];
}

- (void)insertObject:(SKBookmark *)child inChildrenAtIndex:(NSUInteger)anIndex {
    [children insertObject:child atIndex:anIndex];
    [child setParent:self];
}

- (void)insertChildren:(NSArray *)newChildren atIndexes:(NSIndexSet *)indexes {
    [children insertObjects:newChildren atIndexes:indexes];
    [newChildren setValue:self forKey:@"parent"];
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)anIndex {
    [[children objectAtIndex:anIndex] setParent:nil];
    [children removeObjectAtIndex:anIndex];
}

- (void)removeChildrenAtIndexes:(NSIndexSet *)indexes {
    [[children objectsAtIndexes:indexes] setValue:nil forKey:@"parent"];
    [children removeObjectsAtIndexes:indexes];
}

- (NSArray *)entireContents {
    NSMutableArray *contents = [NSMutableArray array];
    for (SKBookmark *bookmark in [self children]) {
        [contents addObject:bookmark];
        [contents addObjectsFromArray:[bookmark entireContents]];
    }
    return contents;
}

- (id)newScriptingObjectOfClass:(Class)objectClass forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties {
    if ([key isEqualToString:@"bookmarks"]) {
        SKBookmark *bookmark = nil;
        NSURL *aURL = [properties objectForKey:@"fileURL"] ?: contentsValue;
        NSString *aLabel = [properties objectForKey:@"label"];
        NSNumber *aType = [properties objectForKey:@"bookmarkType"];
        NSInteger type;
        if ([aType respondsToSelector:@selector(integerValue)])
            type = [aType integerValue];
        else if (aURL == nil)
            type = SKBookmarkTypeSession;
        else if ([[NSWorkspace sharedWorkspace] type:[[NSWorkspace sharedWorkspace] typeOfFile:[aURL path] error:NULL] conformsToType:(__bridge NSString *)kUTTypeFolder])
            type = SKBookmarkTypeFolder;
        else
            type = SKBookmarkTypeBookmark;
        switch (type) {
            case SKBookmarkTypeBookmark:
            {
                Class docClass;
                if (aURL == nil) {
                    [[NSScriptCommand currentCommand] setScriptErrorNumber:NSRequiredArgumentsMissingScriptError];
                    [[NSScriptCommand currentCommand] setScriptErrorString:@"New file bookmark requires a file."];
                } else if ([aURL checkResourceIsReachableAndReturnError:NULL] == NO) {
                    [[NSScriptCommand currentCommand] setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [[NSScriptCommand currentCommand] setScriptErrorString:@"New file bookmark requires an existing file."];
                } else if ((docClass = [[NSDocumentController sharedDocumentController] documentClassForContentsOfURL:aURL])) {
                    NSDocument *doc = nil;
                    NSScriptObjectSpecifier *spec = nil;
                    if (contentsValue) {
                        NSAppleEventDescriptor *desc = [[[NSScriptCommand currentCommand] arguments] objectForKey:@"ObjectData"];
                        if ([desc isKindOfClass:[NSAppleEventDescriptor class]] && [desc descriptorType] == typeObjectSpecifier)
                            spec = [NSScriptObjectSpecifier objectSpecifierWithDescriptor:desc];
                    } else {
                        spec = [[[[NSScriptCommand currentCommand] arguments] objectForKey:@"KeyDictionary"] objectForKey:@"fileURL"];
                    }
                    if ([spec isKindOfClass:[NSScriptObjectSpecifier class]] && [[[spec containerClassDescription] className] isEqualToString:@"document"])
                        doc = [[spec containerSpecifier] objectsByEvaluatingSpecifier];
                    if (aLabel == nil)
                        [aURL getResourceValue:&aLabel forKey:NSURLLocalizedNameKey error:NULL];
                    if ([doc isKindOfClass:[NSDocument class]]) {
                        bookmark = [[SKBookmark alloc] initWithSetup:[doc currentDocumentSetup] label:aLabel ?: @""];
                    } else {
                        NSUInteger aPageNumber = [[properties objectForKey:@"pageNumber"] unsignedIntegerValue];
                        if (aPageNumber > 0)
                            aPageNumber--;
                        else
                            aPageNumber = [docClass isPDFDocument] ? 0 : NSNotFound;
                        if (aLabel == nil)
                            [aURL getResourceValue:&aLabel forKey:NSURLLocalizedNameKey error:NULL];
                        bookmark = [[SKBookmark alloc] initWithURL:aURL pageIndex:aPageNumber label:aLabel ?: @""];
                    }
                } else {
                    [[NSScriptCommand currentCommand] setScriptErrorNumber:NSArgumentsWrongScriptError];
                    [[NSScriptCommand currentCommand] setScriptErrorString:@"Unsupported file type for new bookmark."];
                }
                break;
            }
            case SKBookmarkTypeFolder:
            {
                NSArray *aChildren = nil;
                if (aURL) {
                    aChildren = [SKBookmark bookmarksForURLs:[[NSFileManager defaultManager] contentsOfDirectoryAtURL:aURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL]];
                    if (aLabel == nil)
                        [aURL getResourceValue:&aLabel forKey:NSURLLocalizedNameKey error:NULL];
                }
                bookmark = [[SKBookmark alloc] initFolderWithChildren:aChildren label:aLabel ?: @""];
                break;
            }
            case SKBookmarkTypeSession:
            {
                NSArray *setups = [[NSApp orderedDocuments] valueForKey:@"currentDocumentSetup"];
                if (aLabel == nil) {
                    if ([setups count] == 1)
                        aLabel = [[[NSApp orderedDocuments] firstObject] displayName];
                    else
                        aLabel = [[[NSDate date] shortDateFormat] description];
                }
                bookmark = [[SKBookmark alloc] initSessionWithSetups:setups label:aLabel ?: @""];
                break;
            }
            case SKBookmarkTypeSeparator:
                bookmark = [[SKBookmark alloc] initSeparator];
                break;
            default:
                [[NSScriptCommand currentCommand] setScriptErrorNumber:NSArgumentsWrongScriptError];
                [[NSScriptCommand currentCommand] setScriptErrorString:@"New bookmark requires a supported bookmark type."];
                break;
        }
        return bookmark;
    }
    return [super newScriptingObjectOfClass:objectClass forValueForKey:key withContentsValue:contentsValue properties:properties];
}

@end

#pragma mark -

@implementation SKRootBookmark

- (NSImage *)icon {
    static NSImage *menuIcon = nil;
    if (menuIcon == nil) {
        menuIcon = [NSImage imageWithSize:NSMakeSize(16.0, 16.0) flipped:NO drawingHandler:^(NSRect rect){
            [[NSColor colorWithGenericGamma22White:0.0 alpha:0.2] set];
            [NSBezierPath fillRect:NSMakeRect(1.0, 1.0, 14.0, 13.0)];
            [NSGraphicsContext saveGraphicsState];
            NSBezierPath *path = [NSBezierPath bezierPath];
            [path moveToPoint:NSMakePoint(2.0, 2.0)];
            [path lineToPoint:NSMakePoint(2.0, 15.0)];
            [path lineToPoint:NSMakePoint(7.0, 15.0)];
            [path lineToPoint:NSMakePoint(7.0, 13.0)];
            [path lineToPoint:NSMakePoint(14.0, 13.0)];
            [path lineToPoint:NSMakePoint(14.0, 2.0)];
            [path closePath];
            [[NSColor whiteColor] set];
            [NSShadow setShadowWithWhite:0.0 alpha:0.33333 blurRadius:2.0 yOffset:-1.0];
            [path fill];
            [NSGraphicsContext restoreGraphicsState];
            [[NSColor colorWithSRGBRed:0.210 green:0.398 blue:0.801 alpha:1.0] set];
            NSRectFill(NSMakeRect(2.0, 13.0, 5.0, 2.0));
            [[NSColor colorWithSRGBRed:0.923 green:0.481 blue:0.259 alpha:1.0] set];
            NSRectFill(NSMakeRect(3.0, 4.0, 1.0, 1.0));
            NSRectFill(NSMakeRect(3.0, 7.0, 1.0, 1.0));
            NSRectFill(NSMakeRect(3.0, 10.0, 1.0, 1.0));
            [[NSColor colorWithGenericGamma22White:0.65 alpha:1.0] set];
            NSRectFill(NSMakeRect(5.0, 4.0, 1.0, 1.0));
            NSRectFill(NSMakeRect(5.0, 7.0, 1.0, 1.0));
            NSRectFill(NSMakeRect(5.0, 10.0, 1.0, 1.0));
            NSUInteger i, j;
            for (i = 0; i < 7; i++) {
                for (j = 0; j < 3; j++) {
                    [[NSColor colorWithGenericGamma22White:0.5 + 0.1 * rand() / RAND_MAX alpha:1.0] set];
                    NSRectFill(NSMakeRect(6.0 + i, 4.0 + 3.0 * j, 1.0, 1.0));
                }
            }
            NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithGenericGamma22White:0.0 alpha:0.1] endingColor:[NSColor colorWithGenericGamma22White:0.0 alpha:0.0]];
            [gradient drawInRect:NSMakeRect(2.0, 2.0, 12.0,11.0) angle:90.0];
            return YES;
        }];
    }
    return menuIcon;
}

@end

#pragma mark -

@implementation SKSessionBookmark

- (NSDictionary *)properties {
    return [NSDictionary dictionaryWithObjectsAndKeys:SESSION_STRING, TYPE_KEY, [children valueForKey:PROPERTIES_KEY], CHILDREN_KEY, label, LABEL_KEY, nil];
}

- (SKBookmarkType)bookmarkType {
    return SKBookmarkTypeSession;
}

- (NSImage *)icon {
    return [NSImage imageNamed:NSImageNameMultipleDocuments];
}

- (NSImage *)alternateIcon {
    return [NSImage imageNamed:NSImageNameFolder];
}

- (NSString *)toolTip {
    return [[[self children] valueForKeyPath:@"fileURL.path"] componentsJoinedByString:@"\n"];
}

- (void)insertObject:(SKBookmark *)child inChildrenAtIndex:(NSUInteger)anIndex {}
- (void)removeObjectFromChildrenAtIndex:(NSUInteger)anIndex {}

- (NSArray *)entireContents { return nil; }

- (id)newScriptingObjectOfClass:(Class)objectClass forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties {
    if ([key isEqualToString:@"bookmarks"]) {
        [[NSScriptCommand currentCommand] setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
        [[NSScriptCommand currentCommand] setScriptErrorString:@"Invalid container for new bookmark."];
        return nil;
    }
    return [super newScriptingObjectOfClass:objectClass forValueForKey:key withContentsValue:contentsValue properties:properties];
}

@end

#pragma mark -

@implementation SKSeparatorBookmark

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: separator>", [self class]];
}

- (NSDictionary *)properties {
    return [NSDictionary dictionaryWithObjectsAndKeys:SEPARATOR_STRING, TYPE_KEY, nil];
}

- (SKBookmarkType)bookmarkType {
    return SKBookmarkTypeSeparator;
}

@end
