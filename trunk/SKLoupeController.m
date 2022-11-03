//
//  SKLoupeController.m
//  Skim
//
//  Created by Christiaan Hofman on 03/11/2022.
/*
 This software is Copyright (c) 2022
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

#import "SKLoupeController.h"
#import <Quartz/Quartz.h>
#import "SKAnimatedBorderlessWindow.h"
#import "PDFView_SKExtensions.h"
#import "PDFPage_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"
#import "NSView_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "SKStringConstants.h"

#define LOUPE_RADIUS 16.0
#define LOUPE_BORDER_WIDTH 2.0
#define LOUPE_BORDER_GRAY 0.2

#define SKSmallMagnificationWidthKey @"SKSmallMagnificationWidth"
#define SKSmallMagnificationHeightKey @"SKSmallMagnificationHeight"
#define SKLargeMagnificationWidthKey @"SKLargeMagnificationWidth"
#define SKLargeMagnificationHeightKey @"SKLargeMagnificationHeight"

#if SDK_BEFORE(10_13)
@interface PDFView (SKHighSierraDeclarations)
@property (nonatomic) BOOL displaysRTL;
@end
#endif

@implementation SKLoupeController

@synthesize magnification, level;

- (id)initWithPDFView:(PDFView *)aPdfView {
    self = [super init];
    if (self) {
        pdfView = aPdfView;
        [self makeWindow];
        magnification = 0.0;
        level = 0;
    }
    return self;
}

- (void)dealloc {
    pdfView = nil;
    [layer setDelegate:nil];
    SKDESTROY(layer);
    SKDESTROY(window);
    [super dealloc];
}

- (void)makeWindow {
    layer = [[CALayer alloc] init];
    [layer setCornerRadius:LOUPE_RADIUS];
    [layer setMasksToBounds:YES];
    [layer setActions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNull null], @"contents", nil]];
    [layer setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
    [layer setFrame:NSRectToCGRect([pdfView bounds])];
    if (RUNNING_BEFORE(10_14)) {
        CGColorRef borderColor = CGColorCreateGenericGray(LOUPE_BORDER_GRAY, 1.0);
        [layer setBorderColor:borderColor];
        [layer setBorderWidth:LOUPE_BORDER_WIDTH];
        CGColorRelease(borderColor);
    }
    [layer setDelegate:self];
    
    window = [[SKAnimatedBorderlessWindow alloc] initWithContentRect:[pdfView convertRectToScreen:[pdfView bounds]]];
    [[window contentView] setWantsLayer:YES];
    [[[window contentView] layer] addSublayer:layer];
    [layer setContentsScale:[[[window contentView] layer] contentsScale]];
    [[window contentView] setContentFilters:SKColorEffectFilters()];
    [window setHasShadow:YES];
    [self updateBackgroundColor];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
        SKSetHasLightAppearance(window);
}

- (void)updateBackgroundColor {
    if (RUNNING_AFTER(10_13)) {
        BOOL hasBackgroundView = NO;
        NSView *loupeView = [window contentView];
        if ([[loupeView subviews] count] > 0) {
            hasBackgroundView = YES;
            loupeView = [[loupeView subviews] firstObject];
        }
        NSColor *bgColor = [pdfView backgroundColor];
        NSVisualEffectMaterial material = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        if ([bgColor isEqual:[NSColor windowBackgroundColor]])
            material = NSVisualEffectMaterialWindowBackground;
        else if ([bgColor isEqual:[NSColor controlBackgroundColor]] || [bgColor isEqual:[NSColor textBackgroundColor]])
            material = NSVisualEffectMaterialContentBackground;
        else if ([bgColor isEqual:[NSColor underPageBackgroundColor]])
            material = NSVisualEffectMaterialUnderPageBackground;
#pragma clang diagnostic pop
        if (material == 0) {
            __block CGColorRef cgColor = NULL;
            SKRunWithAppearance([pdfView scrollView], ^{
                if ([bgColor alphaComponent] < 1.0)
                    cgColor = [[[NSColor blackColor] blendedColorWithFraction:[bgColor alphaComponent] ofColor:[bgColor colorWithAlphaComponent:1.0]] CGColor];
                if (cgColor == NULL)
                    cgColor = [bgColor CGColor] ?: CGColorGetConstantColor(kCGColorBlack);
            });
            [layer setBackgroundColor:cgColor];
            if (hasBackgroundView) {
                [window setContentView:loupeView];
                [loupeView setContentFilters:SKColorEffectFilters()];
            }
        } else if (hasBackgroundView) {
            [(NSVisualEffectView *)[window contentView] setMaterial:material];
        } else {
            NSVisualEffectView *view = [[NSVisualEffectView alloc] init];
            [view setMaterial:material];
            [view setState:NSVisualEffectStateActive];
            [loupeView retain];
            [loupeView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
            [window setContentView:view];
            [view addSubview:loupeView];
            [view setContentFilters:SKColorEffectFilters()];
            [loupeView setContentFilters:[NSArray array]];
            [loupeView release];
            if (NSIsEmptyRect([view bounds]) == NO)
                [view setMaskImage:[NSImage maskImageWithSize:[view bounds].size cornerRadius:LOUPE_RADIUS]];
            [view release];
            [layer setBackgroundColor:NULL];
        }
    } else {
        NSColor *bgColor = [pdfView backgroundColor];
        if ([bgColor alphaComponent] < 1.0)
            bgColor = [[NSColor blackColor] blendedColorWithFraction:[bgColor alphaComponent] ofColor:[bgColor colorWithAlphaComponent:1.0]] ?: bgColor;
        [layer setBackgroundColor:[bgColor CGColor]];
    }
}

- (void)updateColorFilters {
    [[window contentView] setContentFilters:SKColorEffectFilters()];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
        SKSetHasLightAppearance(window);
    else
        SKSetHasDefaultAppearance(window);
    [self updateBackgroundColor];
}

- (void)update {
    NSRect visibleRect = [pdfView convertRectToScreen:[pdfView visibleContentRect]];
    NSPoint mouseLoc = [NSEvent mouseLocation];
    
    if (NSPointInRect(mouseLoc, visibleRect)) {
        
        // define rect for magnification in view coordinate
        NSRect magRect;
        if (level > 2) {
            magRect = visibleRect;
        } else {
            NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
            NSSize magSize;
            if (level == 2)
                magSize = NSMakeSize([sud floatForKey:SKLargeMagnificationWidthKey], [sud floatForKey:SKLargeMagnificationHeightKey]);
            else
                magSize = NSMakeSize([sud floatForKey:SKSmallMagnificationWidthKey], [sud floatForKey:SKSmallMagnificationHeightKey]);
            magRect = NSIntegralRect(SKRectFromCenterAndSize(mouseLoc, magSize));
        }
        
        NSView *loupeView = [window contentView];
        if (RUNNING_AFTER(10_13))
            loupeView = [[loupeView subviews] firstObject] ?: loupeView;
        BOOL needsMask = loupeView != [window contentView] && NSEqualSizes([window frame].size, magRect.size) == NO;
        [window setFrame:magRect display:YES];
        if (needsMask)
            [(NSVisualEffectView *)[window contentView] setMaskImage:[NSImage maskImageWithSize:[window frame].size cornerRadius:LOUPE_RADIUS]];
        [layer setNeedsDisplay];
        if ([window parentWindow] == nil) {
            [NSCursor hide];
            [[pdfView window] addChildWindow:window ordered:NSWindowAbove];
        }
        
    } else {
        
        [self hide];
        
    }
}

- (void)updateContents {
    if ([window parentWindow]) {
        if (level > 2 && NSEqualSizes([window frame].size, [pdfView visibleContentRect].size) == NO)
            [self update];
        else
            [layer setNeedsDisplay];
    }
}

- (BOOL)hide {
    if ([window parentWindow] == nil)
        return NO;
    // show cursor
    [NSCursor unhide];
    [[pdfView window] removeChildWindow:window];
    [window orderOut:nil];
    return YES;
}

- (void)displayLayer:(CALayer *)aLayer {
    NSPoint mouseLoc = [pdfView convertPointFromScreen:[NSEvent mouseLocation]];
    
    if (NSPointInRect(mouseLoc, [pdfView visibleContentRect]) == NO)
        return;
    
    NSRect magRect = [pdfView convertRectFromScreen:[window frame]];
    
    NSShadow *aShadow = nil;
    CGFloat scaleFactor = [pdfView scaleFactor];
    if ([pdfView displaysPageBreaks]) {
        aShadow = [[[NSShadow alloc] init] autorelease];
        [aShadow setShadowColor:[NSColor colorWithGenericGamma22White:0.0 alpha:0.3]];
        [aShadow setShadowBlurRadius:4.0 * magnification * scaleFactor];
        [aShadow setShadowOffset:NSMakeSize(0.0, -1.0 * magnification * scaleFactor)];
    }
    
    NSImage *image;
    NSAffineTransform *transform = [NSAffineTransform transform];
    NSImageInterpolation interpolation = [pdfView interpolationQuality] + 1;
    BOOL shouldAntiAlias = [pdfView shouldAntiAlias];
    PDFDisplayBox box = [pdfView displayBox];
    NSRect scaledRect = SKRectFromCenterAndSize(mouseLoc, NSMakeSize(NSWidth(magRect) / magnification, NSHeight(magRect) / magnification));
    CGFloat backingScale = [pdfView backingScale];
    NSRange pageRange;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if (RUNNING_AFTER(10_13) && [pdfView displaysRTL] && ([pdfView displayMode] & kPDFDisplayTwoUp)) {
#pragma clang diagnostic pop
        pageRange.location = [[pdfView pageForPoint:SKTopRightPoint(scaledRect) nearest:YES] pageIndex];
        pageRange.length = [[pdfView pageForPoint:SKBottomLeftPoint(scaledRect) nearest:YES] pageIndex] + 1 - pageRange.location;
    } else {
        pageRange.location = [[pdfView pageForPoint:SKTopLeftPoint(scaledRect) nearest:YES] pageIndex];
        pageRange.length = [[pdfView pageForPoint:SKBottomRightPoint(scaledRect) nearest:YES] pageIndex] + 1 - pageRange.location;
    }
    
    [transform translateXBy:mouseLoc.x - NSMinX(magRect) yBy:mouseLoc.y - NSMinY(magRect)];
    [transform scaleBy:magnification];
    [transform translateXBy:-mouseLoc.x yBy:-mouseLoc.y];
    
    image = [NSImage bitmapImageWithSize:magRect.size scale:backingScale drawingHandler:^(NSRect rect){
        
        NSRect imageRect = rect;
        NSUInteger i;
        CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
        
        if (aShadow)
            imageRect = NSOffsetRect(NSInsetRect(imageRect, -[aShadow shadowBlurRadius], -[aShadow shadowBlurRadius]), -[aShadow shadowOffset].width, -[aShadow shadowOffset].height);
        
        for (i = pageRange.location; i < NSMaxRange(pageRange); i++) {
            PDFPage *page = [[pdfView document] pageAtIndex:i];
            NSRect pageRect = [pdfView convertRect:[page boundsForBox:box] fromPage:page];
            NSPoint pageOrigin = pageRect.origin;
            NSAffineTransform *pageTransform;
            
            pageRect = SKTransformRect(transform, pageRect);
            
            // only draw the page when there is something to draw
            if (NSIntersectsRect(imageRect, pageRect) == NO)
                continue;
            
            // draw page background, simulate the private method -drawPagePre:
            [NSGraphicsContext saveGraphicsState];
            [[NSColor whiteColor] setFill];
            [aShadow set];
            NSRectFill(SKIntegralRect(pageRect, backingScale));
            [NSGraphicsContext restoreGraphicsState];
            if (RUNNING_AFTER(10_13) && aShadow) {
                [NSGraphicsContext saveGraphicsState];
                [[NSColor colorWithGenericGamma22White:0.94 alpha:1.0] setFill];
                NSFrameRectWithWidth(SKIntegralRect(pageRect, backingScale), magnification * scaleFactor);
                [NSGraphicsContext restoreGraphicsState];
            }
            
            // only draw the page when there is something to draw
            if (NSIntersectsRect(rect, pageRect) == NO)
                continue;
            
            // draw page contents
            [NSGraphicsContext saveGraphicsState];
            pageTransform = [transform copy];
            [pageTransform translateXBy:pageOrigin.x yBy:pageOrigin.y];
            [pageTransform scaleBy:scaleFactor];
            [pageTransform concat];
            [pageTransform release];
            [[NSGraphicsContext currentContext] setShouldAntialias:shouldAntiAlias];
            [[NSGraphicsContext currentContext] setImageInterpolation:interpolation];
            if ([PDFView instancesRespondToSelector:@selector(drawPage:toContext:)])
                [pdfView drawPage:page toContext:context];
            else
                [pdfView drawPage:page];
            [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationDefault];
            [NSGraphicsContext restoreGraphicsState];
        }
        
    }];
    
    [aLayer setContents:image];
}

@end
