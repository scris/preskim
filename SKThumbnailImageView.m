//
//  SKThumbnailImageView.m
//  Skim
//
//  Created by Christiaan Hofman on 01/10/2021.
/*
 This software is Copyright (c) 2021-2023
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

#import "SKThumbnailImageView.h"
#import "SKStringConstants.h"
#import "NSGraphics_SKExtensions.h"
#import "NSUserDefaultsController_SKExtensions.h"

static char SKThumbnailImageViewDefaultsObservationContext;

@implementation SKThumbnailImageView

static inline NSArray *defaultKeysToObserve() {
    if (RUNNING_AFTER(10_13))
        return [NSArray arrayWithObjects:SKInvertColorsInDarkModeKey, SKSepiaToneKey, nil];
    else
        return [NSArray arrayWithObjects:SKSepiaToneKey, nil];
}

- (void)commonInit {
    [self setWantsLayer:YES];
    [self setContentFilters:SKColorEffectFilters()];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeys:defaultKeysToObserve() context:&SKThumbnailImageViewDefaultsObservationContext];
}

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}
- (void)dealloc {
    @try { [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeys:defaultKeysToObserve() context:&SKThumbnailImageViewDefaultsObservationContext]; }
    @catch (id e) {}
    [super dealloc];
}

- (void)viewDidChangeEffectiveAppearance {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    [super viewDidChangeEffectiveAppearance];
#pragma clang diagnostic pop
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SKInvertColorsInDarkModeKey])
        [self setContentFilters:SKColorEffectFilters()];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &SKThumbnailImageViewDefaultsObservationContext)
        [self setContentFilters:SKColorEffectFilters()];
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end
