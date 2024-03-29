//
//  SKDisplayPreferences.m
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

#import "SKDisplayPreferences.h"
#import "SKPreferenceController.h"
#import "SKStringConstants.h"
#import "NSGraphics_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSUserDefaults_SKExtensions.h"
#import "NSUserDefaultsController_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "NSValueTransformer_SKExtensions.h"
#import "SKColorSwatch.h"
#import "PDFView_SKExtensions.h"

static CGFloat SKDefaultFontSizes[] = {8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0, 48.0, 64.0};

static char SKDisplayPreferencesDefaultsObservationContext;
static char SKDisplayPreferencesColorSwatchObservationContext;

@interface SKDisplayPreferences (Private)
- (void)updateBackgroundColors;
@end
    
@implementation SKDisplayPreferences

@synthesize normalColorWell, fullScreenColorWell, colorSwatch, addRemoveColorButton, systemSymbol;
@dynamic allowsDarkMode, countOfSizes;

- (void)dealloc {
    if (@available(macOS 10.14, *)) {
        @try {
            [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeys:@[SKBackgroundColorKey, SKFullScreenBackgroundColorKey, SKDarkBackgroundColorKey, SKDarkFullScreenBackgroundColorKey,] context:&SKDisplayPreferencesDefaultsObservationContext];
        }
        @catch(id e) {}
    }
    @try {
        [colorSwatch unbind:@"colors"];
        [colorSwatch removeObserver:self forKeyPath:@"selectedColorIndex" context:&SKDisplayPreferencesColorSwatchObservationContext];
        [colorSwatch removeObserver:self forKeyPath:@"colors" context:&SKDisplayPreferencesColorSwatchObservationContext];
    }
    @catch(id e) {}
}

- (NSString *)nibName {
    return @"DisplayPreferences";
}

- (NSString *)systemSymbol {
    return @"eye";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:SKUnarchiveColorArrayTransformerName];
    [colorSwatch bind:@"colors" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:[@"values." stringByAppendingString:SKSwatchColorsKey] options:@{NSValueTransformerBindingOption:transformer}];
    [colorSwatch sizeToFit];
    [colorSwatch setSelects:YES];
    [colorSwatch setFrame:NSOffsetRect([colorSwatch frame], 0.0, 1.0)];
    [colorSwatch addObserver:self forKeyPath:@"selectedColorIndex" options:0 context:&SKDisplayPreferencesColorSwatchObservationContext];
    [colorSwatch addObserver:self forKeyPath:@"colors" options:0 context:&SKDisplayPreferencesColorSwatchObservationContext];
    
    if (@available(macOS 10.14, *)) {
        [normalColorWell unbind:NSValueBinding];
        [normalColorWell setAction:@selector(changeBackgroundColor:)];
        [normalColorWell setTarget:self];
        [fullScreenColorWell unbind:NSValueBinding];
        [fullScreenColorWell setAction:@selector(changeFullScreenBackgroundColor:)];
        [fullScreenColorWell setTarget:self];
        
        [self updateBackgroundColors];
        
        [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeys:@[SKBackgroundColorKey, SKFullScreenBackgroundColorKey, SKDarkBackgroundColorKey, SKDarkFullScreenBackgroundColorKey] context:&SKDisplayPreferencesDefaultsObservationContext];
        [NSApp addObserver:self forKeyPath:@"effectiveAppearance" options:0 context:&SKDisplayPreferencesDefaultsObservationContext];
    }
}

#pragma mark Accessors

- (NSString *)title { return NSLocalizedString(@"Display", @"Preference pane label"); }

- (NSUInteger)countOfSizes {
    return sizeof(SKDefaultFontSizes) / sizeof(CGFloat);
}

- (NSNumber *)objectInSizesAtIndex:(NSUInteger)anIndex {
    return [NSNumber numberWithDouble:SKDefaultFontSizes[anIndex]];
}

- (BOOL)allowsDarkMode {
    if (@available(macOS 10.14, *))
        return YES;
    else
        return NO;
}

#pragma mark Actions

- (IBAction)changeBackgroundColor:(id)sender {
    NSString *key = SKHasDarkAppearance() ? SKDarkBackgroundColorKey : SKBackgroundColorKey;
    changingColors = YES;
    [[NSUserDefaults standardUserDefaults] setColor:[sender color] forKey:key];
    changingColors = YES;
}

- (IBAction)changeFullScreenBackgroundColor:(id)sender{
    NSString *key = SKHasDarkAppearance() ? SKDarkFullScreenBackgroundColorKey : SKFullScreenBackgroundColorKey;
    changingColors = YES;
    [[NSUserDefaults standardUserDefaults] setColor:[sender color] forKey:key];
    changingColors = NO;
}

- (IBAction)addRemoveColor:(id)sender {
    NSInteger i = [colorSwatch selectedColorIndex];
    if ([sender selectedTag] == 0) {
        if (i == -1)
            i = [[colorSwatch colors] count];
        NSColor *color = [NSColor colorWithSRGBRed:1.0 green:1.0 blue:0.5 alpha:1.0];
        [colorSwatch insertColor:color atIndex:i];
        [colorSwatch selectColorAtIndex:i];
    } else {
        if (i != -1)
            [colorSwatch removeColorAtIndex:i];
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKDisplayPreferencesDefaultsObservationContext) {
        if (changingColors == NO)
            [self updateBackgroundColors];
    } else if (context == &SKDisplayPreferencesColorSwatchObservationContext) {
        [addRemoveColorButton setEnabled:([colorSwatch selectedColorIndex] != -1 && [[colorSwatch colors] count] > 1) forSegment:1];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Private

- (void)updateBackgroundColors {
    NSColor *color = nil;
    NSColor *fsColor = nil;
    NSUserDefaults *sud = [NSUserDefaults standardUserDefaults];
    if (SKHasDarkAppearance()) {
        color = [sud colorForKey:SKDarkBackgroundColorKey];
        fsColor = [sud colorForKey:SKDarkFullScreenBackgroundColorKey];
    }
    if (color == nil)
        color = [sud colorForKey:SKBackgroundColorKey];
    if (fsColor == nil)
        fsColor = [sud colorForKey:SKFullScreenBackgroundColorKey];
    [normalColorWell setColor:color];
    [fullScreenColorWell setColor:fsColor];
}

@end
