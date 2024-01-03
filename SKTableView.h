//
//  SKTableView.h
//  Skim
//
//  Created by Christiaan Hofman on 8/20/07.
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

#import <Cocoa/Cocoa.h>
#import "SKTypeSelectHelper.h"
#import "SKImageToolTipContext.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SKTableViewDelegate <NSTableViewDelegate>
@optional

- (void)tableView:(NSTableView *)aTableView deleteRowsWithIndexes:(NSIndexSet *)rowIndexes;
- (BOOL)tableView:(NSTableView *)aTableView canDeleteRowsWithIndexes:(NSIndexSet *)rowIndexes;

- (void)tableView:(NSTableView *)aTableView copyRowsWithIndexes:(NSIndexSet *)rowIndexes;
- (BOOL)tableView:(NSTableView *)aTableView canCopyRowsWithIndexes:(NSIndexSet *)rowIndexes;

- (void)tableView:(NSTableView *)aTableView pasteFromPasteboard:(NSPasteboard *)pboard;
- (BOOL)tableView:(NSTableView *)aTableView canPasteFromPasteboard:(NSPasteboard *)pboard;

- (void)tableViewMoveLeft:(NSTableView *)aTableView;
- (void)tableViewMoveRight:(NSTableView *)aTableView;

- (BOOL)tableView:(NSTableView *)tableView commandSelectRow:(NSInteger)rowIndex;

- (nullable id <SKImageToolTipContext>)tableView:(NSTableView *)aTableView imageContextForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)rowIndex  scale:(CGFloat *)scale;

- (nullable NSArray *)tableViewTypeSelectHelperSelectionStrings:(NSTableView *)aTableView;
- (void)tableView:(NSTableView *)aTableView typeSelectHelperDidFailToFindMatchForSearchString:(NSString *)searchString;
- (void)tableView:(NSTableView *)aTableView typeSelectHelperUpdateSearchString:(NSString *)searchString;

@end

typedef NS_ENUM(NSInteger, SKTableImageToolTipLayout) {
    SKTableImageToolTipNone,
    SKTableImageToolTipByRow,
    SKTableImageToolTipByCell
};

@interface SKTableView : NSTableView <SKTypeSelectDelegate> {
    SKTypeSelectHelper *typeSelectHelper;
    BOOL supportsQuickLook;
    SKTableImageToolTipLayout imageToolTipLayout;
    NSFont *font;
}

@property (nonatomic, readonly) BOOL canDelete, canCopy, canPaste;
@property (nonatomic) BOOL supportsQuickLook;
@property (nonatomic) SKTableImageToolTipLayout imageToolTipLayout;
@property (nonatomic, nullable, strong) SKTypeSelectHelper *typeSelectHelper;

- (void)delete:(nullable id)sender;
- (void)copy:(nullable id)sender;
- (void)paste:(nullable id)sender;

- (void)scrollToBeginningOfDocument:(nullable id)sender;
- (void)scrollToEndOfDocument:(nullable id)sender;

- (void)moveLeft:(nullable id)sender;
- (void)moveRight:(nullable id)sender;

- (void)reloadTypeSelectStrings;

- (void)noteHeightOfRowsChangedAnimating:(BOOL)animate;
- (void)noteHeightOfRowChanged:(NSInteger)row animating:(BOOL)animate;

@property (nullable, weak) id<SKTableViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
