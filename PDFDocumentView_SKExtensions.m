//
//  PDFDocumentView_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 4/22/08.
/*
 This software is Copyright (c) 2008
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

#import "PDFDocumentView_SKExtensions.h"
#import <Quartz/Quartz.h>
#import "SKPDFView.h"
#import "NSAttributedString_SKExtensions.h"
#import "SKRuntime.h"
#import "NSView_SKExtensions.h"
#import <objc/objc-runtime.h>
#import <SkimNotes/SkimNotes.h>

@interface NSView (SKPDFDisplayViewPrivateDeclarations)
- (id)pdfView;
- (id)getPDFView;
- (id)annotation;
@end

#pragma mark -

static NSString *pdfViewIvarKeyPath = @"_private.pdfView";

static id fallback_ivar_getPDFView(id self, SEL _cmd) {
    id pdfView = nil;
    @try { pdfView = [self valueForKeyPath:pdfViewIvarKeyPath]; }
    @catch (id exception) {}
    return pdfView;
}

static id fallback_getPDFView(id self, SEL _cmd) {
    id pdfView = [[self enclosingScrollView] superview];
    return [pdfView isKindOfClass:[PDFView class]] ? pdfView : nil;
}

static id (*original_menuForEvent)(id, SEL, id) = NULL;

static void (*original_updateTrackingAreas)(id, SEL) = NULL;

static BOOL (*original_isAccessibilityAlternateUIVisible)(id, SEL) = NULL;
static BOOL (*original_accessibilityPerformShowAlternateUI)(id, SEL) = NULL;
static BOOL (*original_accessibilityPerformShowDefaultUI)(id, SEL) = NULL;
static BOOL (*original_accessibilityPerformShowMenu)(id, SEL) = NULL;
static BOOL (*original_annotation_accessibilityPerformPress)(id, SEL) = NULL;
static BOOL (*original_annotation_accessibilityPerformPick)(id, SEL) = NULL;
static BOOL (*original_annotation_accessibilityPerformShowMenu)(id, SEL) = NULL;

#pragma mark PDFPageView fix

// On Sierra and later menuForEvent: is forwarded to the PDFView of the PDFPage rather than the actual PDFView,
static NSMenu *replacement_menuForEvent(id self, SEL _cmd, NSEvent *event) {
    id view = [self enclosingScrollView];
    while ((view = [view superview]))
        if ([view isKindOfClass:[PDFView class]])
            break;
    return [view menuForEvent:event];
}

#pragma mark Preskim support

static void replacement_updateTrackingAreas(id self, SEL _cmd) {
	original_updateTrackingAreas(self, _cmd);
    id pdfView = [self pdfView];
    if ([pdfView respondsToSelector:@selector(resetPDFToolTipRects)])
        [pdfView resetPDFToolTipRects];
}

static BOOL replacement_isAccessibilityAlternateUIVisible(id self, SEL _cmd) {
    id pdfView = [self pdfView];
    return [pdfView isAccessibilityAlternateUIVisible];
}

static BOOL replacement_accessibilityPerformShowAlternateUI(id self, SEL _cmd) {
    id pdfView = [self pdfView];
    return [pdfView accessibilityPerformShowAlternateUI];
}

static BOOL replacement_accessibilityPerformShowDefaultUI(id self, SEL _cmd) {
    id pdfView = [self pdfView];
    return [pdfView accessibilityPerformShowDefaultUI];
}

static BOOL replacement_accessibilityPerformShowMenu(id self, SEL _cmd) {
    id pdfView = [self pdfView];
    return [pdfView accessibilityPerformShowMenu];
}

static BOOL replacement_annotation_accessibilityPerformPress(id self, SEL _cmd) {
    id annotation = [self annotation];
    if ([annotation respondsToSelector:@selector(isSkimNote)] && [annotation isSkimNote] && [annotation respondsToSelector:_cmd])
        return [annotation accessibilityPerformPress];
    return original_annotation_accessibilityPerformPress(self, _cmd);
}

static BOOL replacement_annotation_accessibilityPerformPick(id self, SEL _cmd) {
    id annotation = [self annotation];
    if ([annotation respondsToSelector:@selector(isSkimNote)] && [annotation isSkimNote] && [annotation respondsToSelector:_cmd])
        return [annotation accessibilityPerformPick];
    return original_annotation_accessibilityPerformPick(self, _cmd);
}

static BOOL replacement_annotation_accessibilityPerformShowMenu(id self, SEL _cmd) {
    id annotation = [self annotation];
    if ([annotation respondsToSelector:@selector(isSkimNote)] && [annotation isSkimNote] && [annotation respondsToSelector:_cmd])
        return [annotation accessibilityPerformShowMenu];
    return original_accessibilityPerformShowMenu(self, _cmd);
}

#pragma mark SKSwizzlePDFDocumentViewMethods

void SKSwizzlePDFDocumentViewMethods() {
    Class PDFPageViewClass = NSClassFromString(@"PDFPageView");
    if (PDFPageViewClass)
        original_menuForEvent = (id (*)(id, SEL, id))SKReplaceInstanceMethodImplementation(PDFPageViewClass, @selector(menuForEvent:), (IMP)replacement_menuForEvent);
    
    Class PDFDocumentViewClass = NSClassFromString(@"PDFDocumentView");
    if (PDFDocumentViewClass == Nil)
        return;

    if ([PDFDocumentViewClass instancesRespondToSelector:@selector(pdfView)] == NO) {
        if ([PDFDocumentViewClass instancesRespondToSelector:@selector(getPDFView)]) {
            SKAddInstanceMethodImplementationFromSelector(PDFDocumentViewClass, @selector(pdfView), @selector(getPDFView));
        } else if (class_getInstanceVariable(PDFDocumentViewClass, "_private")) {
            SKAddInstanceMethodImplementation(PDFDocumentViewClass, @selector(pdfView), (IMP)fallback_ivar_getPDFView, "@@:");
        } else {
            SKAddInstanceMethodImplementation(PDFDocumentViewClass, @selector(pdfView), (IMP)fallback_getPDFView, "@@:");
        }
    }
    
    original_updateTrackingAreas = (void (*)(id, SEL))SKReplaceInstanceMethodImplementation(PDFDocumentViewClass, @selector(updateTrackingAreas), (IMP)replacement_updateTrackingAreas);
    
    original_isAccessibilityAlternateUIVisible = (BOOL (*)(id, SEL))SKReplaceInstanceMethodImplementation(PDFDocumentViewClass, @selector(isAccessibilityAlternateUIVisible), (IMP)replacement_isAccessibilityAlternateUIVisible);
    original_accessibilityPerformShowAlternateUI = (BOOL (*)(id, SEL))SKReplaceInstanceMethodImplementation(PDFDocumentViewClass, @selector(accessibilityPerformShowAlternateUI), (IMP)replacement_accessibilityPerformShowAlternateUI);
    original_accessibilityPerformShowDefaultUI = (BOOL (*)(id, SEL))SKReplaceInstanceMethodImplementation(PDFDocumentViewClass, @selector(accessibilityPerformShowDefaultUI), (IMP)replacement_accessibilityPerformShowDefaultUI);
    original_accessibilityPerformShowMenu = (BOOL (*)(id, SEL))SKReplaceInstanceMethodImplementation(PDFDocumentViewClass, @selector(accessibilityPerformShowMenu), (IMP)replacement_accessibilityPerformShowMenu);
}

void SKSwizzlePDFAccessibilityNodeAnnotationMethods() {
    Class PDFAccessibilityNodeAnnotationClass = NSClassFromString(@"PDFAccessibilityNodeAnnotation");
    
    if (PDFAccessibilityNodeAnnotationClass == Nil || [PDFAccessibilityNodeAnnotationClass instancesRespondToSelector:@selector(annotation)] == NO)
        return;
    
    original_annotation_accessibilityPerformPress = (BOOL (*)(id, SEL))SKReplaceInstanceMethodImplementation(PDFAccessibilityNodeAnnotationClass, @selector(accessibilityPerformPress), (IMP)replacement_annotation_accessibilityPerformPress);
    original_annotation_accessibilityPerformPick = (BOOL (*)(id, SEL))SKReplaceInstanceMethodImplementation(PDFAccessibilityNodeAnnotationClass, @selector(accessibilityPerformPick), (IMP)replacement_annotation_accessibilityPerformPick);
    original_annotation_accessibilityPerformShowMenu = (BOOL (*)(id, SEL))SKReplaceInstanceMethodImplementation(PDFAccessibilityNodeAnnotationClass, @selector(accessibilityPerformShowMenu), (IMP)replacement_annotation_accessibilityPerformShowMenu);
}
