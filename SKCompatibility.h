//
//  SKCompatibility.h
//  Skim
//
//  Created by Christiaan Hofman on 9/9/09.
/*
 This software is Copyright (c) 2009-2023
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

#define SDK_BEFORE(_version) (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_VERSION_ ## _version)
#define DEPLOYMENT_BEFORE(_version) (MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_VERSION_ ## _version)

#ifdef MAC_OS_X_VERSION_10_14
    #define MAC_OS_VERSION_10_14 MAC_OS_X_VERSION_10_14
#else
    #define MAC_OS_VERSION_10_14 101400
#endif
#ifdef MAC_OS_X_VERSION_10_15
    #define MAC_OS_VERSION_10_15 MAC_OS_X_VERSION_10_15
#else
    #define MAC_OS_VERSION_10_15 101500
#endif
#ifdef MAC_OS_X_VERSION_10_16
    #define MAC_OS_VERSION_10_16 MAC_OS_X_VERSION_10_16
#else
    #define MAC_OS_VERSION_10_16 101600
#endif
#ifndef MAC_OS_VERSION_11_0
    #define MAC_OS_VERSION_11_0 110000
#endif
#ifndef MAC_OS_VERSION_11_1
    #define MAC_OS_VERSION_11_1 110100
#endif
#ifndef MAC_OS_VERSION_12_0
    #define MAC_OS_VERSION_12_0 120000
#endif
#ifndef MAC_OS_VERSION_13_0
    #define MAC_OS_VERSION_13_0 130000
#endif
#ifndef MAC_OS_VERSION_14_0
    #define MAC_OS_VERSION_14_0 140000
#endif

#if SDK_BEFORE(10_14)

static const NSAppKitVersion NSAppKitVersionNumber10_13 = 1561;
static const NSAppKitVersion NSAppKitVersionNumber10_14 = 1671;
static const NSAppKitVersion NSAppKitVersionNumber10_15 = 1894;
static const NSAppKitVersion NSAppKitVersionNumber11_0 = 2022;
static const NSAppKitVersion NSAppKitVersionNumber12_0 = 2113;
static const NSAppKitVersion NSAppKitVersionNumber13_0 = 2299;

#elif SDK_BEFORE(10_15)

static const NSAppKitVersion NSAppKitVersionNumber10_14 = 1671;
static const NSAppKitVersion NSAppKitVersionNumber10_15 = 1894;
static const NSAppKitVersion NSAppKitVersionNumber11_0 = 2022;
static const NSAppKitVersion NSAppKitVersionNumber12_0 = 2113;
static const NSAppKitVersion NSAppKitVersionNumber13_0 = 2299;

#elif SDK_BEFORE(11_0)

static const NSAppKitVersion NSAppKitVersionNumber10_15 = 1894;
static const NSAppKitVersion NSAppKitVersionNumber11_0 = 2022;
static const NSAppKitVersion NSAppKitVersionNumber12_0 = 2113;
static const NSAppKitVersion NSAppKitVersionNumber13_0 = 2299;

#elif SDK_BEFORE(12_0)

static const NSAppKitVersion NSAppKitVersionNumber11_0 = 2022;
static const NSAppKitVersion NSAppKitVersionNumber12_0 = 2113;
static const NSAppKitVersion NSAppKitVersionNumber13_0 = 2299;

#elif SDK_BEFORE(13_0)

static const NSAppKitVersion NSAppKitVersionNumber12_0 = 2113;
static const NSAppKitVersion NSAppKitVersionNumber13_0 = 2299;

#elif SDK_BEFORE(14_0)

static const NSAppKitVersion NSAppKitVersionNumber13_0 = 2299;

#endif

#if SDK_BEFORE(10_14)

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

#endif

#if SDK_BEFORE(11_0)

typedef NS_ENUM(NSInteger, NSWindowToolbarStyle) {
    NSWindowToolbarStyleAutomatic,
    NSWindowToolbarStyleExpanded,
    NSWindowToolbarStylePreference,
    NSWindowToolbarStyleUnified,
    NSWindowToolbarStyleUnifiedCompact
};

@interface NSWindow (SKBigSurDeclarations)
- (NSWindowToolbarStyle)toolbarStyle;
- (void)setToolbarStyle:(NSWindowToolbarStyle)style;
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
