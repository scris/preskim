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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <QuickLook/QuickLook.h>
#import "SKQLConverter.h"

// Same size as [[NSPrintInfo sharedPrintInfo] paperSize] on my system
// NSPrintInfo must not be used in a non-main thread (and it's hellishly slow in some circumstances)
static const NSSize _paperSize = (NSSize) { 612, 792 };

// page margins 20 pt on all edges
static const CGFloat _horizontalMargin = 20;
static const CGFloat _verticalMargin = 20;
static const NSSize _containerSize = (NSSize) { 572, 752 };
static const NSRect _iconRect = (NSRect) { { 50, 140 }, { 512, 512 } };

// wash the app icon over a white page background
static void drawBackgroundAndApplicationIconInCurrentContext(QLThumbnailRequestRef thumbnail)
{
    [[NSColor whiteColor] setFill];
    NSRect pageRect = { NSZeroPoint, _paperSize };
    NSRectFillUsingOperation(pageRect, NSCompositingOperationSourceOver);
    
    NSURL *iconURL = (NSURL *)CFBridgingRelease(CFBundleCopyResourceURL(QLThumbnailRequestGetGeneratorBundle(thumbnail), CFSTR("Preskim"), CFSTR("icns"), NULL));
    NSImage *appIcon = [[NSImage alloc] initWithContentsOfFile:[iconURL path]];
    
    [appIcon drawInRect:_iconRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:0.3];
}

// creates a new NSTextStorage/NSLayoutManager/NSTextContainer system suitable for drawing in a thread
static NSTextStorage *createTextStorage()
{
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    NSTextContainer *tc = [[NSTextContainer alloc] init];
    [tc setContainerSize:_containerSize];
    [lm addTextContainer:tc];
    // don't let the layout manager use its threaded layout (see header)
    [lm setBackgroundLayoutEnabled:NO];
    [textStorage addLayoutManager:lm];
    // see header; the CircleView example sets it to NO
    //[lm setUsesScreenFonts:YES];

    return textStorage;
}

// assumes that the current NSGraphicsContext is the destination
static void drawAttributedStringInCurrentContext(NSAttributedString *attrString)
{
    CGContextRef ctxt = [[NSGraphicsContext currentContext] CGContext];
    
    NSTextStorage *textStorage = createTextStorage();
    [textStorage beginEditing];
    [textStorage setAttributedString:attrString];
    
    [textStorage endEditing];
    NSRect stringRect = NSZeroRect;
    stringRect.size = _paperSize;
    
    CGContextSaveGState(ctxt);
    
    CGAffineTransform t1 = CGAffineTransformMakeTranslation(_horizontalMargin, _paperSize.height - _verticalMargin);
    CGAffineTransform t2 = CGAffineTransformMakeScale(1, -1);
    CGAffineTransform pageTransform = CGAffineTransformConcat(t2, t1);
    CGContextConcatCTM(ctxt, pageTransform);
    
    // objectAtIndex:0 is safe, since we added these to the text storage (so there's at least one)
    NSLayoutManager *lm = [[textStorage layoutManagers] objectAtIndex:0];
    NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
    
    NSRange glyphRange;
    
    // we now have a properly flipped graphics context, so force layout and then draw the text
    glyphRange = [lm glyphRangeForBoundingRect:stringRect inTextContainer:tc];
    NSRect usedRect = [lm usedRectForTextContainer:tc];
    
    // NSRunStorage raises if we try drawing a zero length range (happens if you have an empty text file)
    if (glyphRange.length > 0) {
        [lm drawBackgroundForGlyphRange:glyphRange atPoint:usedRect.origin];
        [lm drawGlyphsForGlyphRange:glyphRange atPoint:usedRect.origin];
    }        
    CGContextRestoreGState(ctxt);
}

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maximumSize)
{
    @autoreleasepool{
        bool didGenerate = false;
        
        if (UTTypeEqual(CFSTR("scris.ds.preskim.pdfd"), contentTypeUTI)) {
            
            NSString *pdfFile = SKQLPDFPathForPDFBundleURL((__bridge NSURL *)url);
            
            if (pdfFile) {
                // sadly, we can't use the system's QL generator from inside quicklookd, so we don't get the fancy binder on the left edge
                CGPDFDocumentRef pdfDoc = CGPDFDocumentCreateWithURL((CFURLRef)[NSURL fileURLWithPath:pdfFile]);
                CGPDFPageRef pdfPage = NULL;
                if (pdfDoc && CGPDFDocumentGetNumberOfPages(pdfDoc) > 0)
                    pdfPage = CGPDFDocumentGetPage(pdfDoc, 1);
                
                if (pdfPage) {
                    CGRect pageRect = CGPDFPageGetBoxRect(pdfPage, kCGPDFCropBox);
                    CGRect thumbRect = {{0.0, 0.0}, {CGRectGetWidth(pageRect), CGRectGetHeight(pageRect)}};
                    CGFloat color[4] = {1.0, 1.0, 1.0, 1.0};
                    CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, thumbRect.size, FALSE, NULL);
                    CGAffineTransform t = CGPDFPageGetDrawingTransform(pdfPage, kCGPDFCropBox, thumbRect, 0, true);
                    CGContextConcatCTM(ctxt, t);
                    CGContextClipToRect(ctxt, pageRect);
                    CGContextSetFillColor(ctxt, color);
                    CGContextFillRect(ctxt, pageRect);
                    CGContextDrawPDFPage(ctxt, pdfPage);
                    QLThumbnailRequestFlushContext(thumbnail, ctxt);
                    CGContextRelease(ctxt);
                    didGenerate = true;
                }
                CGPDFDocumentRelease(pdfDoc);
            }
            
        } else if (UTTypeEqual(CFSTR("com.adobe.postscript"), contentTypeUTI)) {
            
            if (floor(NSAppKitVersionNumber) <= 2299.0) {
                bool converted = false;
                CGPSConverterCallbacks converterCallbacks = { 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL };
                CGPSConverterRef converter = CGPSConverterCreate(NULL, &converterCallbacks, NULL);
                CGDataProviderRef provider = CGDataProviderCreateWithURL(url);
                CFMutableDataRef pdfData = CFDataCreateMutable(NULL, 0);
                CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(pdfData);
                if (provider != NULL && consumer != NULL)
                    converted = CGPSConverterConvert(converter, provider, consumer, NULL);
                CGDataProviderRelease(provider);
                CGDataConsumerRelease(consumer);
                CFRelease(converter);
                if (converted) {
                    // sadly, we can't use the system's QL generator from inside quicklookd, so we don't get the fancy binder on the left edge
                    provider = CGDataProviderCreateWithCFData(pdfData);
                    CGPDFDocumentRef pdfDoc = CGPDFDocumentCreateWithProvider(provider);
                    CGPDFPageRef pdfPage = NULL;
                    if (pdfDoc && CGPDFDocumentGetNumberOfPages(pdfDoc) > 0)
                        pdfPage = CGPDFDocumentGetPage(pdfDoc, 1);
                    
                    if (pdfPage) {
                        CGRect pageRect = CGPDFPageGetBoxRect(pdfPage, kCGPDFCropBox);
                        CGRect thumbRect = {{0.0, 0.0}, {CGRectGetWidth(pageRect), CGRectGetHeight(pageRect)}};
                        CGFloat color[4] = {1.0, 1.0, 1.0, 1.0};
                        CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, thumbRect.size, FALSE, NULL);
                        CGAffineTransform t = CGPDFPageGetDrawingTransform(pdfPage, kCGPDFCropBox, thumbRect, 0, true);
                        CGContextConcatCTM(ctxt, t);
                        CGContextClipToRect(ctxt, pageRect);
                        CGContextSetFillColor(ctxt, color);
                        CGContextFillRect(ctxt, pageRect);
                        CGContextDrawPDFPage(ctxt, pdfPage);
                        QLThumbnailRequestFlushContext(thumbnail, ctxt);
                        CGContextRelease(ctxt);
                        didGenerate = true;
                    }
                    CGPDFDocumentRelease(pdfDoc);
                    CGDataProviderRelease(provider);
                }
                if (pdfData) CFRelease(pdfData);
            }
            
        } else if (UTTypeEqual(CFSTR("scris.ds.preskim.notes"), contentTypeUTI)) {
            
            NSData *data = [[NSData alloc] initWithContentsOfURL:(__bridge NSURL *)url options:NSUncachedRead error:NULL];
            
            if (data) {
                NSArray *notes = [SKQLConverter notesWithData:data];
                NSAttributedString *attrString = [SKQLConverter attributedStringWithNotes:notes bundle:QLThumbnailRequestGetGeneratorBundle(thumbnail)];
                
                if (attrString) {
                    CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, *(CGSize *)&_paperSize, FALSE, NULL);
                    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:ctxt flipped:YES];
                    [NSGraphicsContext saveGraphicsState];
                    [NSGraphicsContext setCurrentContext:nsContext];
                    
                    drawBackgroundAndApplicationIconInCurrentContext(thumbnail);
                    drawAttributedStringInCurrentContext(attrString);
                    
                    QLThumbnailRequestFlushContext(thumbnail, ctxt);
                    CGContextRelease(ctxt);
                    
                    [NSGraphicsContext restoreGraphicsState];
                    didGenerate = true;
                }
            }
            
        }
        
        /* fallback case: draw the file icon using Icon Services */
        if (false == didGenerate) {
            
            NSString *path = (NSString *)CFBridgingRelease(CFURLCopyPath(url));
            NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
            
            if (icon) {
                CGFloat side = MIN(maximumSize.width, maximumSize.height);
                NSRect rect = NSMakeRect(0.0, 0.0, side, side);
                CGContextRef ctxt = QLThumbnailRequestCreateContext(thumbnail, rect.size, FALSE, NULL);
                NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:ctxt flipped:NO];
                [NSGraphicsContext saveGraphicsState];
                [NSGraphicsContext setCurrentContext:nsContext];
                
                [icon drawInRect:rect];
                
                QLThumbnailRequestFlushContext(thumbnail, ctxt);
                CGContextRelease(ctxt);
                
                [NSGraphicsContext restoreGraphicsState];
            }
        }
    }
    return noErr;
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}
