//
//  SKSnapshotWindowController.h
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
#import <Quartz/Quartz.h>
#import "SKSnapshotPDFView.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *SKSnapshotCurrentSetupKey;

@class PDFDocument, PDFPage;
@protocol SKSnapshotWindowControllerDelegate;

typedef NS_ENUM(NSInteger, SKSnapshotOpenType) {
    SKSnapshotOpenNormal,
    SKSnapshotOpenFromSetup,
    SKSnapshotOpenPreview
};

@interface SKSnapshotWindowController : NSWindowController <NSWindowDelegate, NSFilePromiseProviderDelegate, SKSnapshotPDFViewDelegate> {
    SKSnapshotPDFView* pdfView;
    NSImage *thumbnail;
    __weak id <SKSnapshotWindowControllerDelegate> delegate;
    NSString *pageLabel;
    NSImage *windowImage;
    NSString *string;
    BOOL hasWindow;
    BOOL forceOnTop;
    BOOL animating;
}

@property (nonatomic, nullable, strong) IBOutlet SKSnapshotPDFView *pdfView;
@property (nonatomic, nullable, weak) id <SKSnapshotWindowControllerDelegate> delegate;
@property (nonatomic, nullable, strong) NSImage *thumbnail;
@property (nonatomic, readonly) NSRect bounds;
@property (nonatomic, readonly) NSUInteger pageIndex;
@property (nonatomic, nullable, readonly, copy) NSString *pageLabel;
@property (nonatomic, nullable, copy) NSString *string;
@property (nonatomic, readonly) BOOL hasWindow;
@property (weak, nonatomic, readonly) NSDictionary<NSString *, id> *currentSetup;
@property (nonatomic) BOOL forceOnTop;

@property (weak, nonatomic, readonly) NSAttributedString *thumbnailAttachment, *thumbnail512Attachment, *thumbnail256Attachment, *thumbnail128Attachment, *thumbnail64Attachment, *thumbnail32Attachment;

- (void)setPdfDocument:(PDFDocument *)pdfDocument goToPageNumber:(NSInteger)pageNum rect:(NSRect)rect scaleFactor:(CGFloat)factor autoFits:(BOOL)autoFits;
- (void)setPdfDocument:(PDFDocument *)pdfDocument setup:(NSDictionary<NSString *, id> *)setup;
- (void)setPdfDocument:(PDFDocument *)pdfDocument previewPageNumber:(NSInteger)pageNum displayOnScreen:(nullable NSScreen *)screen;

- (BOOL)isPageVisible:(PDFPage *)page;

- (void)redisplay;

- (void)updatePageLabel;

- (NSImage *)thumbnailWithSize:(CGFloat)size;

- (NSAttributedString *)thumbnailAttachmentWithSize:(CGFloat)size;

- (void)miniaturize;
- (void)deminiaturize;

- (void)handlePageChangedNotification:(NSNotification *)notification;
- (void)handleDocumentDidUnlockNotification:(NSNotification *)notification;
- (void)handlePDFViewFrameChangedNotification:(NSNotification *)notification;
- (void)handleViewChangedNotification:(NSNotification *)notification;
- (void)handleDidAddAnnotationNotification:(NSNotification *)notification;
- (void)handleDidRemoveAnnotationNotification:(NSNotification *)notification;
- (void)handleDidMoveAnnotationNotification:(NSNotification *)notification;

- (void)setNeedsDisplayInRect:(NSRect)rect ofPage:(PDFPage *)page;
- (void)setNeedsDisplayForAnnotation:(PDFAnnotation *)annotation onPage:(nullable PDFPage *)page;

@end


@protocol SKSnapshotWindowControllerDelegate <NSObject>
@optional

- (void)snapshotController:(SKSnapshotWindowController *)controller didFinishSetup:(SKSnapshotOpenType)opentType;
- (void)snapshotControllerWillClose:(SKSnapshotWindowController *)controller;
- (void)snapshotControllerDidChange:(SKSnapshotWindowController *)controller;
- (void)snapshotControllerDidMove:(SKSnapshotWindowController *)controller;
- (NSRect)snapshotController:(SKSnapshotWindowController *)controller miniaturizedRect:(BOOL)isMiniaturize;
- (void)snapshotController:(SKSnapshotWindowController *)controller goToDestination:(PDFDestination *)destination;

@end

NS_ASSUME_NONNULL_END
