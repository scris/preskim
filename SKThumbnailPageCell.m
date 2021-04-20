//
//  SKthumbnailPageCell.m
//  Skim
//
//  Created by Christiaan Hofman on 20/04/2021.
/*
 This software is Copyright (c) 2021
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

#import "SKThumbnailPageCell.h"
#import "NSImage_SKExtensions.h"

#define MARKIMAGE_OFFSET 4.0

@implementation SKThumbnailPageCell

@synthesize marked;

- (id)copyWithZone:(NSZone *)aZone {
    SKThumbnailPageCell *copy = [super copyWithZone:aZone];
    copy->marked = marked;
    return copy;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    if ([self isMarked]) {
        NSImage *markImage = [NSImage markImage];
        NSRect rect = NSMakeRect(NSMaxX(cellFrame) - markImage.size.width - MARKIMAGE_OFFSET, [controlView isFlipped] ? NSMinY(rect) + MARKIMAGE_OFFSET : NSMaxY(cellFrame) - markImage.size.height - MARKIMAGE_OFFSET, markImage.size.width, markImage.size.height);
        [markImage drawInRect:rect];
    }
    [super drawWithFrame:cellFrame inView:controlView];
}

- (void)drawWithExpansionFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawWithFrame:cellFrame inView:controlView];
}

@end
