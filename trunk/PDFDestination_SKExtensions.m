//
//  PDFDestination_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 01/04/2023.
/*
 This software is Copyright (c) 2023
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

#import "PDFDestination_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "PDFView_SKExtensions.h"

@implementation PDFDestination (SKExtensions)

- (PDFDestination *)effectiveDestinationForView:(PDFView *)pdfView {
    NSPoint point = [self point];
    if (point.x >= kPDFDestinationUnspecifiedValue || point.y >= kPDFDestinationUnspecifiedValue) {
        PDFPage *page = [self page];
        NSRect bounds = NSZeroRect;
        NSSize size = pdfView ? [pdfView visibleContentRect].size : NSZeroSize;
        CGFloat zoomX = kPDFDestinationUnspecifiedValue, zoomY = kPDFDestinationUnspecifiedValue;
        BOOL override = YES;
        NSInteger type = 0;
        // the -type property always returns 0, and not the value from the ivar
        @try { type = [[self valueForKeyPath:RUNNING_BEFORE(10_12) ? @"_pdfPriv.type" : @"_private.type"] integerValue]; }
        @catch (id e) {}
        switch (type) {
            case 0:
                override = NO;
                break;
            case 1: // Fit
                bounds = pdfView ? [pdfView layoutBoundsForPage:page] : [page boundsForBox:kPDFDisplayBoxCropBox];
                if (pdfView && NSIsEmptyRect(bounds) == NO) {
                    zoomX = size.width / NSWidth(bounds);
                    zoomY = size.height / NSHeight(bounds);
                }
                break;
            case 2: // FitH
                bounds = pdfView ? [pdfView layoutBoundsForPage:page] : [page boundsForBox:kPDFDisplayBoxCropBox];
                @try { point.y = [[self valueForKeyPath:RUNNING_BEFORE(10_12) ? @"_pdfPriv.top" : @"_private.top"] doubleValue]; }
                @catch (id e) { override = NO; }
                if (override && pdfView && NSIsEmptyRect(bounds) == NO)
                    zoomX = zoomY = size.width / NSWidth(bounds);
                if (override && pdfView && point.y >= kPDFDestinationUnspecifiedValue) {
                    PDFDestination *d = [pdfView currentDestination];
                    if ([d page] == page)
                        point.y = [d point].y;
                }
                break;
            case 3: // FitV
                bounds = pdfView ? [pdfView layoutBoundsForPage:page] : [page boundsForBox:kPDFDisplayBoxCropBox];
                @try { point.x = [[self valueForKeyPath:RUNNING_BEFORE(10_12) ? @"_pdfPriv.left" : @"_private.left"] doubleValue]; }
                @catch (id e) { override = NO; }
                if (override && pdfView && NSIsEmptyRect(bounds) == NO)
                    zoomX = zoomY = size.height / NSHeight(bounds);
                if (override && pdfView && point.x >= kPDFDestinationUnspecifiedValue) {
                    PDFDestination *d = [pdfView currentDestination];
                    if ([d page] == page)
                        point.x = [d point].x;
                }
                break;
            case 4: // FitR
            {
                @try { bounds.origin.x = [[self valueForKeyPath:RUNNING_BEFORE(10_12) ? @"_pdfPriv.left" : @"_private.left"] doubleValue]; }
                @catch (id e) { override = NO; }
                @try { bounds.origin.y = [[self valueForKeyPath:RUNNING_BEFORE(10_12) ? @"_pdfPriv.bottom" : @"_private.bottom"] doubleValue]; }
                @catch (id e) { override = NO; }
                @try { bounds.size.width = [[self valueForKeyPath:RUNNING_BEFORE(10_12) ? @"_pdfPriv.right" : @"_private.right"] doubleValue] - NSMinX(bounds); }
                @catch (id e) { override = NO; }
                @try { bounds.size.height = [[self valueForKeyPath:RUNNING_BEFORE(10_12) ? @"_pdfPriv.top" : @"_private.top"] doubleValue] - NSMinY(bounds); }
                @catch (id e) { override = NO; }
                if (override && pdfView && NSIsEmptyRect(bounds) == NO) {
                    zoomX = size.width / NSWidth(bounds);
                    zoomY = size.height / NSHeight(bounds);
                }
                break;
            }
            case 5: // FitB
                bounds = [page foregroundRect];
                if (pdfView && NSIsEmptyRect(bounds) == NO) {
                    zoomX = size.width / NSWidth(bounds);
                    zoomY = size.height / NSHeight(bounds);
                }
                break;
            case 6: // FitBH
                bounds = [page foregroundRect];
                @try { point.y = [[self valueForKeyPath:RUNNING_BEFORE(10_12) ? @"_pdfPriv.top" : @"_private.top"] doubleValue]; }
                @catch (id e) { override = NO; }
                if (override && pdfView && NSIsEmptyRect(bounds) == NO)
                    zoomX = zoomY = size.width / NSWidth(bounds);
                if (override && pdfView && point.y >= kPDFDestinationUnspecifiedValue) {
                    PDFDestination *d = [pdfView currentDestination];
                    if ([d page] == page)
                        point.y = [d point].y;
                }
                break;
            case 7: // FitBV
                bounds = [page foregroundRect];
                @try { point.x = [[self valueForKeyPath:RUNNING_BEFORE(10_12) ? @"_pdfPriv.left" : @"_private.left"] doubleValue]; }
                @catch (id e) { override = NO; }
                if (override && pdfView && NSIsEmptyRect(bounds) == NO)
                    zoomX = zoomY = size.height / NSHeight(bounds);
                if (override && pdfView && point.x >= kPDFDestinationUnspecifiedValue) {
                    PDFDestination *d = [pdfView currentDestination];
                    if ([d page] == page)
                        point.x = [d point].x;
                }
                break;
            default:
                override = NO;
                break;
        }
        if (override) {
            if (point.x >= kPDFDestinationUnspecifiedValue)
                point.x = NSMinX(bounds);
            if (point.y >= kPDFDestinationUnspecifiedValue)
                point.y = NSMaxY(bounds);
            if (zoomX < zoomY)
                point.y += 0.5 * (zoomY / zoomX - 1.0) * NSHeight(bounds);
            else if (zoomX > zoomY)
                point.x -= 0.5 * (zoomX / zoomY - 1.0) * NSWidth(bounds);
            PDFDestination *destination = [[[PDFDestination alloc] initWithPage:page atPoint:point] autorelease];
            if (zoomX < kPDFDestinationUnspecifiedValue)
                [destination setZoom:fmin(zoomX, zoomY)];
            return destination;
        }
    }
    return self;
}

@end
