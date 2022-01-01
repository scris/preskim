//
//  SKDisplayPrefs.m
//  Skim
//
//  Created by Christiaan Hofman on 04/12/2021.
/*
 This software is Copyright (c) 2021-2022
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

#import "SKDisplayPrefs.h"
#import "SKStringConstants.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSGraphics_SKExtensions.h"


@implementation SKDisplayPrefs

@dynamic name, pdfViewSettings, backgroundColor, sepiaTone;

- (id)initForFullScreen:(BOOL)isFullScreen {
    self = [super init];
    if (self) {
        fullScreen = isFullScreen;
    }
    return self;
}

- (id)initWithName:(NSString *)name {
    if ([name isEqualToString:@"Normal"] || [name isEqualToString:@"normal mode"])
        self =  [self initForFullScreen:NO];
    else if ([name isEqualToString:@"FullScreen"] || [name isEqualToString:@"full screen mode"])
        self = [self initForFullScreen:YES];
    else
        SKDESTROY(self);
    return self;
}

- (NSString *)name {
    return fullScreen ? @"FullScreen" : @"Normal";
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptClassDescription *containerClassDescription = [NSScriptClassDescription classDescriptionForClass:[NSApp class]];
    return [[[NSNameSpecifier alloc] initWithContainerClassDescription:containerClassDescription containerSpecifier:nil key:@"displayPreferences" name:[self name]] autorelease];
}

- (NSDictionary *)pdfViewSettings {
    return [[NSUserDefaults standardUserDefaults] dictionaryForKey:fullScreen ? SKDefaultFullScreenPDFDisplaySettingsKey : SKDefaultPDFDisplaySettingsKey];
}

- (void)setPdfViewSettings:(NSDictionary *)settings {
    if (settings == nil)
        settings = [NSDictionary dictionary];
    NSMutableDictionary *setup = [NSMutableDictionary dictionary];
    if (fullScreen == NO || [settings count] > 0) {
        [setup addEntriesFromDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultPDFDisplaySettingsKey]];
        if (fullScreen)
            [setup addEntriesFromDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:SKDefaultFullScreenPDFDisplaySettingsKey]];
        [setup addEntriesFromDictionary:settings];
    }
    [[NSUserDefaults standardUserDefaults] setObject:setup forKey:fullScreen ? SKDefaultFullScreenPDFDisplaySettingsKey : SKDefaultPDFDisplaySettingsKey];
}

- (NSColor *)backgroundColor {
    NSColor *backgroundColor = nil;
    if (SKHasDarkAppearance(NSApp))
        backgroundColor = [[NSUserDefaults standardUserDefaults] colorForKey:fullScreen ? SKDarkFullScreenBackgroundColorKey : SKDarkBackgroundColorKey];
    if (backgroundColor == nil)
        backgroundColor = [[NSUserDefaults standardUserDefaults] colorForKey:fullScreen ? SKFullScreenBackgroundColorKey : SKBackgroundColorKey];
    return backgroundColor;
}

- (void)setBackgroundColor:(NSColor *)color {
    if (SKHasDarkAppearance(NSApp))
        [[NSUserDefaults standardUserDefaults] setColor:color forKey:fullScreen ? SKDarkFullScreenBackgroundColorKey : SKDarkBackgroundColorKey];
    else
        [[NSUserDefaults standardUserDefaults] setColor:color forKey:fullScreen ? SKFullScreenBackgroundColorKey : SKBackgroundColorKey];
}

- (CGFloat)sepiaTone {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:SKSepiaToneKey];
}

- (void)setSepiaTone:(CGFloat)sepiaTone {
    if (sepiaTone <= 0.0)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:SKSepiaToneKey];
    else
        [[NSUserDefaults standardUserDefaults] setDouble:fmin(sepiaTone, 1.0) forKey:SKSepiaToneKey];
}

@end
