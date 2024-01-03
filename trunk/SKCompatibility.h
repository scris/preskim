//
//  SKCompatibility.h
//  Skim
//
//  Created by Christiaan Hofman on 9/9/09.
/*
 This software is Copyright (c) 2009
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

#define SDK_BEFORE_10_14 (MAC_OS_X_VERSION_MAX_ALLOWED < 101400)
#define SDK_BEFORE_10_15 (MAC_OS_X_VERSION_MAX_ALLOWED < 101500)
#define SDK_BEFORE_11_0  (MAC_OS_X_VERSION_MAX_ALLOWED < 110000)
#define SDK_BEFORE_12_0  (MAC_OS_X_VERSION_MAX_ALLOWED < 120000)
#define SDK_BEFORE_13_0  (MAC_OS_X_VERSION_MAX_ALLOWED < 130000)
#define SDK_BEFORE_14_0  (MAC_OS_X_VERSION_MAX_ALLOWED < 140000)

#if SDK_BEFORE_10_14

enum {
    NSVisualEffectMaterialHeaderView = 10,
    NSVisualEffectMaterialSheet = 11,
    NSVisualEffectMaterialWindowBackground = 12,
    NSVisualEffectMaterialHUDWindow = 13,
    NSVisualEffectMaterialFullScreenUI = 15,
    NSVisualEffectMaterialToolTip = 17,
    NSVisualEffectMaterialContentBackground = 18,
    NSVisualEffectMaterialUnderWindowBackground = 21,
    NSVisualEffectMaterialUnderPageBackground = 22
};

@interface NSView (SKMojaveExtensions)
- (void)viewDidChangeEffectiveAppearance;
@end

#define NSAppearanceNameDarkAqua @"NSAppearanceNameDarkAqua"

#define NSBackgroundStyleNormal NSBackgroundStyleLight
#define NSBackgroundStyleEmphasized NSBackgroundStyleDark

#endif

#if SDK_BEFORE_11_0

typedef NS_ENUM(NSInteger, NSWindowToolbarStyle) {
    NSWindowToolbarStyleAutomatic,
    NSWindowToolbarStyleExpanded,
    NSWindowToolbarStylePreference,
    NSWindowToolbarStyleUnified,
    NSWindowToolbarStyleUnifiedCompact
};

@interface NSWindow (SKBigSurDeclarations)
@property NSWindowToolbarStyle toolbarStyle;
@end

typedef NS_ENUM(NSInteger, NSTableViewStyle) {
    NSTableViewStyleAutomatic,
    NSTableViewStyleFullWidth,
    NSTableViewStyleInset,
    NSTableViewStyleSourceList,
    NSTableViewStylePlain
};

@interface NSTableView (SKBigSurDeclarations)
@property NSTableViewStyle style;
@end

#endif
