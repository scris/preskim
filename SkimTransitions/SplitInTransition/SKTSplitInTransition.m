//
//  SKTSplitInTransition.m
//  SkimTransitions
//
//  Created by Christiaan Hofman on 22/5/2019.
//  Copyright Christiaan Hofman 2019. All rights reserved.
//

#import "SKTSplitInTransition.h"
#import "SKTPluginLoader.h"

@implementation SKTSplitInTransition

@synthesize inputImage, inputTargetImage, inputCenter, inputExtent, inputTime;

static CIKernel *_SKTSplitInTransitionKernel = nil;

- (id)init
{
    if (_SKTSplitInTransitionKernel == nil)
        _SKTSplitInTransitionKernel = [SKTPlugInLoader kernelWithName:@"boxComposition"];
    return [super init];
}

+ (NSDictionary *)customAttributes
{
    return [NSDictionary dictionaryWithObjectsAndKeys:

        [NSDictionary dictionaryWithObjectsAndKeys:
            [CIVector vectorWithX:150.0 Y:150.0], kCIAttributeDefault,
            kCIAttributeTypePosition,          kCIAttributeType,
            nil],                              kCIInputCenterKey,
 
        [NSDictionary dictionaryWithObjectsAndKeys:
            [CIVector vectorWithX:0.0 Y:0.0 Z:300.0 W:300.0], kCIAttributeDefault,
            kCIAttributeTypeRectangle,          kCIAttributeType,
            nil],                               kCIInputExtentKey,
 
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

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
    CISampler *src = [CISampler samplerWithImage:inputImage];
    CISampler *trgt = [CISampler samplerWithImage:inputTargetImage];
    CGFloat x = [inputExtent X];
    CGFloat y = [inputExtent Y];
    CGFloat width = [inputExtent Z];
    CGFloat height = [inputExtent W];
    CGFloat cx = [inputCenter X];
    CGFloat t = [inputTime doubleValue];
    CIVector *rect = [CIVector vectorWithX:t * cx + (1.0 - t) * x Y:y Z:(1.0 - t) * width W:height];
   NSArray *extent = [NSArray arrayWithObjects:[NSNumber numberWithDouble:x], [NSNumber numberWithDouble:y], [NSNumber numberWithDouble:width], [NSNumber numberWithDouble:height], nil];
    NSArray *arguments = [NSArray arrayWithObjects:src, trgt, rect, nil];
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:extent, kCIApplyOptionDefinition, extent, kCIApplyOptionExtent, nil];
    
    return [self apply:_SKTSplitInTransitionKernel arguments:arguments options:options];
}

@end
