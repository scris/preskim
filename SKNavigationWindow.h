//
//  SKNavigationWindow.h
//  Skim
//
//  Created by Christiaan Hofman on 12/19/06.
/*
 This software is Copyright (c) 2006
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
#import "SKAnimatedBorderlessWindow.h"

NS_ASSUME_NONNULL_BEGIN

@class SKPDFView, SKNavigationToolTipView, SKNavigationButton;

@interface SKHUDWindow : SKAnimatedBorderlessWindow
- (instancetype)initWithPDFView:(SKPDFView *)pdfView;
- (void)showForWindow:(NSWindow *)window;
- (void)handleParentWindowDidResizeNotification:(NSNotification *)notification;
@end
    

@interface SKNavigationWindow : SKHUDWindow {
    SKNavigationButton *previousButton;
    SKNavigationButton *nextButton;
    SKNavigationButton *zoomButton;
    SKNavigationButton *cursorButton;
    SKNavigationButton *closeButton;
}
- (void)handleScaleChangedNotification:(NSNotification *)notification;
- (void)handlePageChangedNotification:(NSNotification *)notification;
@end


@interface SKCursorStyleWindow : SKHUDWindow {
    NSSegmentedControl *styleButton;
    NSSegmentedControl *removeShadowButton;
    NSSegmentedControl *drawButton;
    NSSegmentedControl *closeButton;
}
- (void)selectCursorStyle:(NSInteger)style;
- (void)removeShadow:(BOOL)removeShadow;
@end


@interface SKNavigationToolTipWindow : NSPanel {
    NSView *view;
}
@property (class, nonatomic, readonly) SKNavigationToolTipWindow *sharedToolTipWindow;
- (void)showToolTip:(NSString *)toolTip forView:(NSView *)aView;
@property (nonatomic, nullable, readonly) NSView *view;
@end

@interface SKNavigationToolTipView : NSView {
    NSString *stringValue;
}
@property (nonatomic, nullable, strong) NSString *stringValue;
@property (nonatomic, nullable, readonly) NSAttributedString *attributedStringValue;
@property (nonatomic, readonly) NSSize fitSize;
@end


@interface SKNavigationButton : NSButton

@property (nonatomic, nullable, strong) NSBezierPath *path, *alternatePath;
@property (nullable, copy) NSString *toolTip;
@property (nullable, copy) NSString *alternateToolTip;

@end


@interface SKNavigationButtonCell : NSButtonCell {
    NSString *toolTip;
    NSString *alternateToolTip;
    NSBezierPath *path;
    NSBezierPath *alternatePath;
}

@property (nonatomic, nullable, strong) NSBezierPath *path, *alternatePath;
@property (nonatomic, nullable, strong) NSString *toolTip, *alternateToolTip;

@end


@interface SKNavigationSeparator : NSView
@end


@interface SKHUDSegmentedControl : NSSegmentedControl
@end


@interface SKHUDSegmentedCell : NSSegmentedCell
@end

NS_ASSUME_NONNULL_END
