//
//  SKTBoxInTransition.m
//  SkimTransitions
//
//  Created by Christiaan Hofman on 22/5/19.
//  Copyright Christiaan Hofman 2019-2023. All rights reserved.
//

#import "SKTBoxInTransition.h"
#import <ApplicationServices/ApplicationServices.h>
#import "SKTPluginLoader.h"

@implementation SKTBoxInTransition

@synthesize inputImage, inputTargetImage, inputCenter, inputExtent, inputTime;

static CIKernel *_SKTBoxInTransitionKernel = nil;

- (id)init
{
    if (_SKTBoxInTransitionKernel == nil)
        _SKTBoxInTransitionKernel = [SKTPlugInLoader kernelWithName:@"boxComposition"];
    return [super init];
}

+ (NSDictionary *)customAttributes
{
    return [NSDictionary dictionaryWithObjectsAndKeys:

        [NSDictionary dictionaryWithObjectsAndKeys:
            [CIVector vectorWithX:150.0 Y:150.0],       kCIAttributeDefault,
            kCIAttributeTypePosition,           kCIAttributeType,
            nil],                               kCIInputCenterKey,
 
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
    CGFloat cy = [inputCenter Y];
    CGFloat t = [inputTime doubleValue];
    CIVector *rect = [CIVector vectorWithX:t * cx + (1.0 - t) * x Y:t * cy + (1.0 - t) * y Z:(1.0 - t) * width W:(1.0 - t) * height];
    NSArray *extent = [NSArray arrayWithObjects:[NSNumber numberWithDouble:x], [NSNumber numberWithDouble:y], [NSNumber numberWithDouble:width], [NSNumber numberWithDouble:height], nil];
    NSArray *arguments = [NSArray arrayWithObjects:src, trgt, rect, nil];
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:extent, kCIApplyOptionDefinition, extent, kCIApplyOptionExtent, nil];
    
    return [self apply:_SKTBoxInTransitionKernel arguments:arguments options:options];
}

@end
