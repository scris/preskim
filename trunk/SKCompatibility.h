//
//  SKCompatibility.h
//  Skim
//
//  Created by Christiaan Hofman on 9/9/09.
/*
 This software is Copyright (c) 2009-2020
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

#define SDK_BEFORE(_version) (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_ ## _version)
#define DEPLOYMENT_BEFORE(_version) (MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_ ## _version)

#ifndef MAC_OS_X_VERSION_10_8
    #define MAC_OS_X_VERSION_10_8 100800
#endif
#ifndef MAC_OS_X_VERSION_10_9
    #define MAC_OS_X_VERSION_10_9 100900
#endif
#ifndef MAC_OS_X_VERSION_10_10
    #define MAC_OS_X_VERSION_10_10 101000
#endif
#ifndef MAC_OS_X_VERSION_10_11
    #define MAC_OS_X_VERSION_10_11 101100
#endif
#ifndef MAC_OS_X_VERSION_10_12
    #define MAC_OS_X_VERSION_10_12 101200
#endif
#ifndef MAC_OS_X_VERSION_10_13
    #define MAC_OS_X_VERSION_10_13 101300
#endif
#ifndef MAC_OS_X_VERSION_10_14
    #define MAC_OS_X_VERSION_10_14 101400
#endif
#ifndef MAC_OS_X_VERSION_10_15
    #define MAC_OS_X_VERSION_10_15 101500
#endif
#ifndef MAC_OS_X_VERSION_10_16
    #define MAC_OS_X_VERSION_10_16 101600
#endif

#if SDK_BEFORE(10_13)

#ifndef NSAppKitVersionNumber10_7
    #define NSAppKitVersionNumber10_7 1138
#endif
#ifndef NSAppKitVersionNumber10_8
    #define NSAppKitVersionNumber10_8 1187
#endif
#ifndef NSAppKitVersionNumber10_9
    #define NSAppKitVersionNumber10_9 1265
#endif
#ifndef NSAppKitVersionNumber10_10
    #define NSAppKitVersionNumber10_10 1343
#endif
#ifndef NSAppKitVersionNumber10_10_Max
    #define NSAppKitVersionNumber10_10_Max 1349
#endif
#ifndef NSAppKitVersionNumber10_11
    #define NSAppKitVersionNumber10_11 1404
#endif
#ifndef NSAppKitVersionNumber10_12
    #define NSAppKitVersionNumber10_12 1504
#endif
#ifndef NSAppKitVersionNumber10_13
    #define NSAppKitVersionNumber10_13 1561
#endif
#ifndef NSAppKitVersionNumber10_14
    #define NSAppKitVersionNumber10_14 1671
#endif
#ifndef NSAppKitVersionNumber10_15
    #define NSAppKitVersionNumber10_15 1894
#endif

#elif SDK_BEFORE(10_14)

static const NSAppKitVersion NSAppKitVersionNumber10_13 = 1561;
static const NSAppKitVersion NSAppKitVersionNumber10_14 = 1671;
static const NSAppKitVersion NSAppKitVersionNumber10_15 = 1894;

#elif SDK_BEFORE(10_15)

static const NSAppKitVersion NSAppKitVersionNumber10_14 = 1671;
static const NSAppKitVersion NSAppKitVersionNumber10_15 = 1894;

#elif SDK_BEFORE(10_16)

static const NSAppKitVersion NSAppKitVersionNumber10_15 = 1894;

#endif

#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

#ifndef NS_OPTIONS
#define NS_OPTIONS(_type, _name) enum _name : _type _name; enum _name : _type
#endif

#if SDK_BEFORE(10_10)

enum {
    NSFullSizeContentViewWindowMask = 1 << 15;
};

typedef NS_ENUM(NSInteger, NSWindowTitleVisibility) {
    NSWindowTitleVisible = 0,
    NSWindowTitleHidden = 1,
};

@interface NSWindow (SKYosemiteDeclarations)
- (NSRect)contentLayoutRect;
- (id)contentLayoutGuide;
- (NSWindowTitleVisibility)titleVisibility;
- (void)setTitleVisibility:(NSWindowTitleVisibility)flag;
@end

@interface NSLayoutConstraint (SKYosemiteDeclarations)
@property (getter=isActive) BOOL active;
+ (void)activateConstraints:(NSArray *)constraints;
+ (void)deactivateConstraints:(NSArray *)constraints;
@end

#endif

#if SDK_BEFORE(10_12)

typedef NS_ENUM(NSInteger, NSWindowUserTabbingPreference) {
    NSWindowUserTabbingPreferenceManual,
    NSWindowUserTabbingPreferenceAlways,
    NSWindowUserTabbingPreferenceInFullScreen,
};

typedef NS_ENUM(NSInteger, NSWindowTabbingMode) {
    NSWindowTabbingModeAutomatic,
    NSWindowTabbingModePreferred,
    NSWindowTabbingModeDisallowed
};

@interface NSWindow (SKSierraDeclarations)
+ (NSWindowUserTabbingPreference)userTabbingPreference;
- (NSArray *)tabbedWindows;
- (void)addTabbedWindow:(NSWindow *)window ordered:(NSWindowOrderingMode)ordered;
- (NSWindowTabbingMode)tabbingMode;
- (void)setTabbingMode:(NSWindowTabbingMode)mode;
@property (copy) NSString *tabbingIdentifier;
@end

@interface NSOutlineView (SKSierraDeclarations)
- (BOOL)stronglyReferencesItems;
- (void)setStronglyReferencesItems:(BOOL)flag;
@end

@protocol PDFViewDelegate <NSObject> @end

@protocol NSFilePromiseProviderDelegate <NSObject> @end

@interface NSFilePromiseProvider : NSObject <NSPasteboardWriting>
- (id)initWithFileType:(NSString *)fileType delegate:(id <NSFilePromiseProviderDelegate>)delegate;
@end

@interface NSButton (SKSierraDeclarations)
- (NSButton *)buttonWithTitle:(NSString *)title target:(id)target action:(SEL)action;
- (NSButton *)buttonWithImage:(NSImage *)image target:(id)target action:(SEL)action;
- (NSButton *)buttonWithTitle:(NSString *)title image:(NSImage *)image target:(id)target action:(SEL)action;
@end

@interface NSSegmentedControl (SKSierraDeclarations)
+ (NSSegmentedControl *)segmentedControlWithImages:(NSArray *)images trackingMode:(NSSegmentSwitchTracking)trackingMode target:(id)target action:(SEL)action;
+ (NSSegmentedControl *)segmentedControlWithLabels:(NSArray *)labels trackingMode:(NSSegmentSwitchTracking)trackingMode target:(id)target action:(SEL)action;
@end

#endif
