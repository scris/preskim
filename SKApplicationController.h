//
//  SKApplicationController.h
//  Skim
//
//  Created by Michael McCracken on 12/6/06.
/*
 This software is Copyright (c) 2006
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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
#import "SKApplication.h"
#import "HIDRemote.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *SKPageLabelsChangedNotification;

@class SKBookmark, SKDownload;

@interface SKApplicationController : NSObject <SKApplicationDelegate, HIDRemoteDelegate, NSMenuDelegate> {
    NSMenu *noteColumnsMenu;
    NSMenu *noteTypeMenu;
    NSTimer *currentDocumentsTimer;
    BOOL didCheckReopen;
    BOOL remoteScrolling;
    id activity;
}

- (IBAction)orderFrontLineInspector:(nullable id)sender;
- (IBAction)orderFrontNotesPanel:(nullable id)sender;

- (IBAction)visitWebSite:(nullable id)sender;
- (IBAction)visitWiki:(nullable id)sender;
- (IBAction)showPreferencePanel:(nullable id)sender;
- (IBAction)showReleaseNotes:(nullable id)sender;
- (IBAction)showDownloads:(nullable id)sender;

@property (nonatomic, nullable, strong) IBOutlet NSMenu *noteColumnsMenu, *noteTypeMenu;

@property (nonatomic, copy) NSArray<NSColor *> *favoriteColors;
@property (nonatomic) PDFLineStyle defaultStartLineStyle, defaultEndLineStyle;
@property (nonatomic) NSTextAlignment defaultAlignment;
@property (nonatomic) PDFTextAnnotationIconType defaultIconType;

@property (nonatomic, readonly) NSArray<SKBookmark *> *bookmarks;
- (void)insertObject:(SKBookmark *)bookmark inBookmarksAtIndex:(NSUInteger)anIndex;
- (void)removeObjectFromBookmarksAtIndex:(NSUInteger)anIndex;

@property (nonatomic, readonly) NSArray<SKDownload *> *downloads;
- (void)insertObject:(SKDownload *)download inDownloadsAtIndex:(NSUInteger)anIndex;
- (void)removeObjectFromDownloadsAtIndex:(NSUInteger)anIndex;

@end

NS_ASSUME_NONNULL_END
