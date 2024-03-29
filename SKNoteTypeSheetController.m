//
//  SKNoteTypeSheetController.m
//  Skim
//
//  Created by Christiaan Hofman on 3/25/10.
/*
 This software is Copyright (c) 2010
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

#import "SKNoteTypeSheetController.h"
#import "NSWindowController_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSMenu_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>

#define NOTETYPES_COUNT ([noteTypeMenu numberOfItems] - 3)

@interface SKNoteTypeSheetController (Private)
- (void)toggleDisplayNoteType:(id)sender;
- (void)displayAllNoteTypes:(id)sender;
- (void)selectNoteTypes:(id)sender;
@end

@implementation SKNoteTypeSheetController

@synthesize delegate, noteTypeMenu;
@dynamic noteTypes;

- (instancetype)initIncludingWidgets:(BOOL)includeWidgets {
    self = [super initWithWindowNibName:@"NoteTypeSheet"];
    if (self) {
        noteTypeMenu = [[NSMenu alloc] init];
        NSArray *noteTypes = [NSArray arrayWithObjects:SKNFreeTextString, SKNNoteString, SKNCircleString, SKNSquareString, SKNHighlightString, SKNUnderlineString, SKNStrikeOutString, SKNLineString, SKNInkString, includeWidgets ? SKNWidgetString : nil, nil];
        NSMenuItem *menuItem;
        NSInteger tag = 0;
        for (NSString *type in noteTypes) {
            menuItem = [noteTypeMenu addItemWithTitle:[type typeName] action:@selector(toggleDisplayNoteType:) target:self];
            [menuItem setTag:tag++];
            [menuItem setRepresentedObject:type];
            [menuItem setState:NSControlStateValueOn];
        }
        [noteTypeMenu addItem:[NSMenuItem separatorItem]];
        [noteTypeMenu addItemWithTitle:NSLocalizedString(@"Show All", @"Menu item title") action:@selector(displayAllNoteTypes:) target:self];
        [noteTypeMenu addItemWithTitle:[NSLocalizedString(@"Select", @"Menu item title") stringByAppendingEllipsis] action:@selector(selectNoteTypes:) target:self];
    }
    return self;
}

- (instancetype)init {
    return [self initIncludingWidgets:NO];
}

- (NSButton *)switchForTag:(NSInteger)tag {
    for (NSView *view in [[[self window] contentView] subviews]) {
        if ([view isKindOfClass:[NSButton class]] && [(NSButton *)view action] == NULL && [(NSButton *)view tag] == tag)
            return (NSButton *)view;
    }
    return nil;
}

- (void)windowDidLoad {
    NSInteger i;
    for (i = 0; i < NOTETYPES_COUNT; i++) {
        [[self switchForTag:i] setTitle:[[noteTypeMenu itemAtIndex:i] title]];
        [[self switchForTag:i] setHidden:NO];
    }
}

- (NSArray *)noteTypes {
    NSMutableArray *types = [NSMutableArray array];
    NSInteger i;
    for (i = 0; i < NOTETYPES_COUNT; i++) {
        NSMenuItem *item = [noteTypeMenu itemAtIndex:i];
        if ([item state] == NSControlStateValueOn)
            [types addObject:[item representedObject]];
    }
    return types;
}

- (NSPredicate *)filterPredicateForSearchString:(NSString *)searchString caseInsensitive:(BOOL)caseInsensitive {
    NSPredicate *filterPredicate = nil;
    NSPredicate *typePredicate = nil;
    NSPredicate *searchPredicate = nil;
    NSArray *types = [self noteTypes];
    if ((NSInteger)[types count] < NOTETYPES_COUNT) {
        NSExpression *lhs = [NSExpression expressionForKeyPath:@"type"];
        NSExpression *rhs = [NSExpression expressionForConstantValue:types];
        typePredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs modifier:NSDirectPredicateModifier type:NSInPredicateOperatorType options:0];
    }
    if (searchString && [searchString isEqualToString:@""] == NO) {
        NSExpression *lhs = [NSExpression expressionForConstantValue:searchString];
        NSExpression *rhs = [NSExpression expressionForKeyPath:@"string"];
        NSUInteger options = NSDiacriticInsensitivePredicateOption;
        if (caseInsensitive)
            options |= NSCaseInsensitivePredicateOption;
        NSPredicate *stringPredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs modifier:NSDirectPredicateModifier type:NSInPredicateOperatorType options:options];
        rhs = [NSExpression expressionForKeyPath:@"textString"];
        NSPredicate *textPredicate = [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs modifier:NSDirectPredicateModifier type:NSInPredicateOperatorType options:options];
        searchPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[stringPredicate, textPredicate]];
    }
    if (typePredicate) {
        if (searchPredicate)
            filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[typePredicate, searchPredicate]];
        else
            filterPredicate = typePredicate;
    } else if (searchPredicate) {
        filterPredicate = searchPredicate;
    }
    return filterPredicate;
}

- (void)toggleDisplayNoteType:(id)sender {
    NSMenuItem *item = [noteTypeMenu itemWithTag:[sender tag]];
    [item setState:NO == [item state]];
    [delegate noteTypeSheetControllerNoteTypesDidChange];
}

- (void)displayAllNoteTypes:(id)sender {
    NSInteger i;
    for (i = 0; i < NOTETYPES_COUNT; i++)
        [[noteTypeMenu itemAtIndex:i] setState:NSControlStateValueOn];
    [delegate noteTypeSheetControllerNoteTypesDidChange];
}

- (void)selectNoteTypes:(id)sender {
    [self window];
    
    NSInteger i;
    for (i = 0; i < NOTETYPES_COUNT; i++)
        [[self switchForTag:i] setState:[[noteTypeMenu itemAtIndex:i] state]];
	
    [self beginSheetModalForWindow:[delegate windowForNoteTypeSheetController] completionHandler:^(NSModalResponse result) {
            if (result == NSModalResponseOK) {
                NSInteger idx;
                for (idx = 0; idx < NOTETYPES_COUNT; idx++)
                    [[noteTypeMenu itemAtIndex:idx] setState:[[self switchForTag:idx] state]];
                [delegate noteTypeSheetControllerNoteTypesDidChange];
            }
        }];
}

@end
