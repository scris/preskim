//
//  SKTStripsTransition.m
//  SkimTransitions
//
//  Created by Christiaan Hofman on 22/5/2019.
//  Copyright Christiaan Hofman 2019-2023. All rights reserved.
//

#import "SKTStripsTransition.h"
#import <ApplicationServices/ApplicationServices.h>
#import "SKTPluginLoader.h"

@implementation SKTStripsTransition

@synthesize inputImage, inputTargetImage, inputExtent, inputWidth, inputTime;

static CIKernel *_SKTStripsTransitionKernel = nil;

- (id)init
{
    if (_SKTStripsTransitionKernel == nil)
        _SKTStripsTransitionKernel = [SKTPlugInLoader kernelWithName:@"stripsTransition"];
    return [super init];
}

+ (NSDictionary *)customAttributes
{
    return [NSDictionary dictionaryWithObjectsAndKeys:

        [NSDictionary dictionaryWithObjectsAndKeys:
            [CIVector vectorWithX:0.0 Y:0.0 Z:300.0 W:300.0], kCIAttributeDefault,
            kCIAttributeTypeRectangle,          kCIAttributeType,
            nil],                               kCIInputExtentKey,
 
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithDouble:  0.0], kCIAttributeMin,
            [NSNumber numberWithDouble:  100.0], kCIAttributeMax,
            [NSNumber numberWithDouble:  0.0], kCIAttributeSliderMin,
            [NSNumber numberWithDouble:  100.0], kCIAttributeSliderMax,
            [NSNumber numberWithDouble:  50.0], kCIAttributeDefault,
            [NSNumber numberWithDouble:  0.0], kCIAttributeIdentity,
            kCIAttributeTypeScalar,            kCIAttributeType,
            nil],                              kCIInputWidthKey,
 
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithDouble:  0.0], kCIAttributeMin,
            [NSNumber numberWithDouble:  1.0], kCIAttributeMax,
            [NSNumber numberWithDouble:  0.0], kCIAttributeSliderMin,
            [NSNumber numberWithDouble:  1.0], kCIAttributeSliderMax,
            [NSNumber numberWithDouble:  0.0], kCIAttributeDefault,
            [NSNumber numberWithDouble:  0.0], kCIAttributeIdentity,
            kCIAttributeTypeTime,              kCIAttributeType,
            nil],                              kCIInputTimeKey,

        nil];
}

- (NSDictionary *)customAttributes
{
    return [[self class] customAttributes];
}

- (CGRect)regionOf:(int)sampler destRect:(CGRect)R userInfo:(NSNumber *)offset {
    if (sampler == 0) {
        R = CGRectInset(R, -[offset doubleValue], 0.0);
    }
    return R;
}

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
    CISampler *src = [CISampler samplerWithImage:inputImage];
    CISampler *trgt = [CISampler samplerWithImage:inputTargetImage];
    NSNumber *offset = [NSNumber numberWithDouble:[inputExtent Z] * [inputTime doubleValue]];
    NSArray *extent = [NSArray arrayWithObjects:[NSNumber numberWithDouble:[inputExtent X]], [NSNumber numberWithDouble:[inputExtent Y]], [NSNumber numberWithDouble:[inputExtent Z]], [NSNumber numberWithDouble:[inputExtent W]], nil];
    NSArray *arguments = [NSArray arrayWithObjects:src, trgt, inputExtent, inputWidth, inputTime, nil];
    NSDictionary *options  = [NSDictionary dictionaryWithObjectsAndKeys:extent, kCIApplyOptionDefinition, extent, kCIApplyOptionExtent, offset, kCIApplyOptionUserInfo, nil];
    
    [_SKTStripsTransitionKernel setROISelector:@selector(regionOf:destRect:userInfo:)];
    
    return [self apply:_SKTStripsTransitionKernel arguments:arguments options:options];
}

@end
