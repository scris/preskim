//
//  SKReadingBar.h
//  Skim
//
//  Created by Christiaan Hofman on 3/30/07.
/*
 This software is Copyright (c) 2007-2022
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

@protocol SKReadingBarDelegate;

@class SKLine;

@interface SKReadingBar : NSObject {
    PDFPage *page;
    NSUInteger lineCount;
    NSInteger currentLine;
    NSUInteger numberOfLines;
    NSRect currentBounds;
    id <SKReadingBarDelegate> delegate;
}

@property (readonly, retain) PDFPage *page;
@property (nonatomic, readonly) NSInteger currentLine;
@property (nonatomic) NSUInteger numberOfLines;
@property (nonatomic) NSInteger maxLine;
@property (readonly) NSRect currentBounds;
@property (nonatomic, assign) id <SKReadingBarDelegate> delegate;

- (id)initWithPage:(PDFPage *)aPage line:(NSInteger)line delegate:(id <SKReadingBarDelegate>)aDelegate;

- (BOOL)goToNextLine;
- (BOOL)goToPreviousLine;
- (BOOL)goToNextPage;
- (BOOL)goToPreviousPage;

- (void)goToLine:(NSInteger)line onPage:(PDFPage *)page;

- (NSUInteger)countOfLines;
- (SKLine *)objectInLinesAtIndex:(NSUInteger)anIndex;

@property (nonatomic, readonly) NSData *boundsAsQDRect;

- (void)handleGoToScriptCommand:(NSScriptCommand *)command;

+ (NSRect)bounds:(NSRect)rect forBox:(PDFDisplayBox)box onPage:(PDFPage *)aPage;
- (NSRect)currentBoundsForBox:(PDFDisplayBox)box;

- (void)drawForPage:(PDFPage *)pdfPage withBox:(PDFDisplayBox)box inContext:(CGContextRef)context transform:(BOOL)shouldTransform;
- (void)drawForPage:(PDFPage *)pdfPage withBox:(PDFDisplayBox)box active:(BOOL)active;

@end


@protocol SKReadingBarDelegate <NSObject>

- (void)readingBar:(SKReadingBar *)readingBar didChangeBounds:(NSRect)oldBounds onPage:(PDFPage *)oldPage toBounds:(NSRect)newBounds onPage:(PDFPage *)newPage scroll:(BOOL)shouldScroll;

@end
