//
//  SKTSlideTransition.m
//  SkimTransitions
//
//  Created by Christiaan Hofman on 22/05/2019.
//  Copyright © 2019-2023 Skim. All rights reserved.
//

#import "SKTSlideTransition.h"
#import <ApplicationServices/ApplicationServices.h>

#define kCIInputRectangleKey @"inputRectangle"

@implementation SKTSlideTransition

@synthesize inputImage, inputTargetImage, inputExtent, inputAngle, inputTime;

+ (NSDictionary *)customAttributes
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            
            [NSDictionary dictionaryWithObjectsAndKeys:
                 [CIVector vectorWithX:0.0 Y:0.0 Z:300.0 W:300.0], kCIAttributeDefault,
                 kCIAttributeTypeRectangle,          kCIAttributeType,
                 nil],                               kCIInputExtentKey,
            
            [NSDictionary dictionaryWithObjectsAndKeys:
                 [NSNumber numberWithDouble:  -M_PI], kCIAttributeMin,
                 [NSNumber numberWithDouble:  M_PI], kCIAttributeMax,
                 [NSNumber numberWithDouble:  -M_PI], kCIAttributeSliderMin,
                 [NSNumber numberWithDouble:  M_PI], kCIAttributeSliderMax,
                 [NSNumber numberWithDouble:  0.0], kCIAttributeDefault,
                 [NSNumber numberWithDouble:  0.0], kCIAttributeIdentity,
                 kCIAttributeTypeAngle,             kCIAttributeType,
                 nil],                              kCIInputAngleKey,
            
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
    CGFloat t = [inputTime doubleValue];
    CGFloat angle = [inputAngle doubleValue];
    CGFloat c = cos(angle);
    CGFloat s = sin(angle);
    CGFloat d1 = [inputExtent Z] * t / fmax(fabs(c), fabs(s));
    CGFloat d2 = [inputExtent Z] * (t - 1.0) / fmax(fabs(c), fabs(s));
    CGAffineTransform transform1 = CGAffineTransformTranslate(CGAffineTransformIdentity, -d1*c, -d1*s);
    CGAffineTransform transform2 = CGAffineTransformTranslate(CGAffineTransformIdentity, -d2*c, -d2*s);
    CIImage *image1 = [inputImage imageByApplyingTransform:transform1];
    CIImage *image2 = [inputTargetImage imageByApplyingTransform:transform2];
    
    return [[image1 imageByCompositingOverImage:image2] imageByCroppingToRect:[inputExtent CGRectValue]];
}

@end
