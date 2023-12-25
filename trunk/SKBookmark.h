//
//  SKBookmark.h
//  Skim
//
//  Created by Christiaan Hofman on 9/15/07.
/*
 This software is Copyright (c) 2007-2023
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
#import <Quartz/Quartz.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SKBookmarkType) {
    SKBookmarkTypeBookmark,
    SKBookmarkTypeFolder,
    SKBookmarkTypeSession,
    SKBookmarkTypeSeparator
};

@interface SKBookmark : NSObject <NSCopying, QLPreviewItem> {
    __weak SKBookmark *parent;
}

+ (NSArray *)bookmarksForURLs:(NSArray<NSURL *> *)urls;

- (nullable instancetype)initWithURL:(NSURL *)aURL pageIndex:(NSUInteger)aPageIndex label:(NSString *)aLabel;
- (nullable instancetype)initWithSetup:(NSDictionary<NSString *, id> *)aSetupDict label:(NSString *)aLabel;
- (nullable instancetype)initFolderWithChildren:(nullable NSArray<SKBookmark *> *)aChildren label:(NSString *)aLabel;
- (nullable instancetype)initRootWithChildrenProperties:(nullable NSArray<NSDictionary<NSString *, id> *> *)childrenProperties;
- (nullable instancetype)initSessionWithSetups:(NSArray<NSDictionary<NSString *, id> *> *)aSetupDicts label:(NSString *)aLabel;
- (nullable instancetype)initSeparator;
- (nullable instancetype)initWithProperties:(NSDictionary<NSString *, id> *)dictionary;

@property (nonatomic, readonly) NSDictionary<NSString *, id> *properties;
@property (nonatomic, readonly) SKBookmarkType bookmarkType;
@property (nonatomic, nullable, strong) NSString *label;
@property (nonatomic, nullable, readonly) NSImage *icon, *alternateIcon;
@property (nonatomic, nullable, copy) NSURL *fileURL;
@property (nonatomic, nullable, readonly) NSURL *fileURLToOpen;
@property (nonatomic, nullable, readonly) NSString *fileDescription;
@property (nonatomic, nullable, readonly) NSString *toolTip;
@property (nonatomic) NSUInteger pageIndex;
@property (nonatomic, nullable, strong) NSNumber *pageNumber;
@property (nonatomic, readonly) BOOL hasSetup;
@property (nonatomic, nullable, readonly) NSString *tabs;
@property (nonatomic, nullable, weak) SKBookmark *parent;
@property (nonatomic, readonly) NSArray<SKBookmark *> *containingBookmarks;

@property (nonatomic, readonly) NSArray<SKBookmark *> *children;
@property (nonatomic, readonly) NSUInteger countOfChildren;
- (SKBookmark *)objectInChildrenAtIndex:(NSUInteger)anIndex;
- (NSArray<SKBookmark *> *)childrenAtIndexes:(NSIndexSet *)indexes;
- (void)insertObject:(SKBookmark *)child inChildrenAtIndex:(NSUInteger)anIndex;
- (void)insertChildren:(NSArray<SKBookmark *> *)newChildren atIndexes:(NSIndexSet *)indexes;
- (void)removeObjectFromChildrenAtIndex:(NSUInteger)anIndex;
- (void)removeChildrenAtIndexes:(NSIndexSet *)indexes;

@property (nonatomic, nullable, readonly) SKBookmark *scriptingParent;
@property (nonatomic, nullable, readonly) NSArray<SKBookmark *> *entireContents;

@property (nonatomic, readonly) NSArray<SKBookmark *> *bookmarks;
- (void)insertObject:(SKBookmark *)bookmark inBookmarksAtIndex:(NSUInteger)anIndex;
- (void)removeObjectFromBookmarksAtIndex:(NSUInteger)anIndex;

@property (nonatomic, getter=isExpanded) BOOL expanded;

- (BOOL)isDescendantOf:(SKBookmark *)bookmark;
- (BOOL)isDescendantOfArray:(NSArray<SKBookmark *> *)bookmarks;

@property (nonatomic, nullable, readonly) NSURL *skimURL;

@end

NS_ASSUME_NONNULL_END
