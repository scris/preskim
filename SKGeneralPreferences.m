//
//  SKGeneralPreferences.m
//  Skim
//
//  Created by Christiaan Hofman on 3/14/10.
/*
 This software is Copyright (c) 2010
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

#import "SKGeneralPreferences.h"
#import "SKPreferenceController.h"
#import "SKStringConstants.h"
#import "NSUserDefaultsController_SKExtensions.h"
#import <Sparkle/Sparkle.h>
#import "NSGraphics_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "SKViewSettingsController.h"
#import "NSWindowController_SKExtensions.h"
#import "SKApplication.h"

#define UPDATEINTERVAL_KEY @"updateInterval"
#define AUTOMATICALLYCHECKSFORUPDATES_KEY @"automaticallyChecksForUpdates"
#define UPDATECHECKINTERVAL_KEY @"updateCheckInterval"

#define SUScheduledCheckIntervalKey @"SUScheduledCheckInterval"

@interface SKGeneralPreferences ()
@property (nonatomic, readonly) SPUUpdater *updater;
- (void)synchronizeUpdateInterval;
@end

@implementation SKGeneralPreferences

@synthesize updateIntervalPopUpButton, updateInterval, systemSymbol;
@dynamic updater;

- (NSString *)nibName {
    return @"GeneralPreferences";
}

- (NSString *)systemSymbol {
    return @"slider.horizontal.3";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self synchronizeUpdateInterval];
}

#pragma mark Accessors

- (NSString *)title { return NSLocalizedString(@"General", @"Preference pane label"); }

- (void)setUpdateInterval:(NSInteger)interval {
    if (interval > 0)
        [[self updater] setUpdateCheckInterval:interval];
    [[self updater] setAutomaticallyChecksForUpdates:interval > 0];
    [self willChangeValueForKey:UPDATEINTERVAL_KEY];
    updateInterval = interval;
    [self didChangeValueForKey:UPDATEINTERVAL_KEY];
}

- (SPUUpdater *)updater {
    return [[NSApp updaterController] updater];
}

#pragma mark Actions

- (IBAction)changePDFViewSettings:(id)sender {
    BOOL fullScreen = [sender tag];
    NSString *key = fullScreen ? SKDefaultFullScreenPDFDisplaySettingsKey : SKDefaultPDFDisplaySettingsKey;
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    NSDictionary *settings = [sud dictionaryForKey:key];
    NSDictionary *defaultSettings = fullScreen ? [sud dictionaryForKey:SKDefaultPDFDisplaySettingsKey] : nil;
    SKViewSettingsController *viewSettings = [[SKViewSettingsController alloc] initWithSettings:settings defaultSettings:defaultSettings];
    
    [viewSettings beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse result){
        if (result == NSModalResponseOK) {
            [sud setObject:[viewSettings settings] forKey:key];
            if (fullScreen == NO)
                [sud setBool:[viewSettings useSettingsFromPDF] forKey:SKUseSettingsFromPDFKey];
        }
    }];
}

#pragma mark Private

- (void)synchronizeUpdateInterval {
    [self willChangeValueForKey:UPDATEINTERVAL_KEY];
    updateInterval = [[self updater] automaticallyChecksForUpdates] ? (NSInteger)[[self updater] updateCheckInterval] : 0;
    [self didChangeValueForKey:UPDATEINTERVAL_KEY];
}

#pragma mark Hooks

- (void)defaultsDidRevert {
    NSTimeInterval interval = [[[NSBundle mainBundle] objectForInfoDictionaryKey:SUScheduledCheckIntervalKey] doubleValue];
    [[self updater] setUpdateCheckInterval:interval];
    [[self updater] setAutomaticallyChecksForUpdates:interval > 0.0];
    [self synchronizeUpdateInterval];
}

@end
