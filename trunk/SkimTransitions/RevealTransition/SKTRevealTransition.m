//
//  SKTRevealTransition.m
//  SkimTransitions
//
//  Created by Christiaan Hofman on 22/5/2019.
//  Copyright Christiaan Hofman 2019-2023. All rights reserved.
//

#import "SKTRevealTransition.h"

@implementation SKTRevealTransition

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

- (CGRect)regionOf:(int)sampler destRect:(CGRect)R userInfo:(CIVector *)offset {
    if (sampler == 0) {
        R = CGRectOffset(R, [offset X], [offset Y]);
    }
    return R;
}

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
    CGFloat t = [inputTime doubleValue];
    CGFloat angle = [inputAngle doubleValue];
    CGFloat c = cos(angle);
    CGFloat s = sin(angle);
    CGFloat d = [inputExtent Z] * t / fmax(fabs(c), fabs(s));
    CGAffineTransform transform = CGAffineTransformTranslate(CGAffineTransformIdentity, -d*c, -d*s);
    CIImage *image = [inputImage imageByApplyingTransform:transform];
    CIFilter *darkenFilter = [CIFilter filterWithName:@"CIExposureAdjust"];
    [darkenFilter setValue:[NSNumber numberWithDouble:-0.4 * (1.0 - t)] forKey:@"inputEV"];
    [darkenFilter setValue:inputTargetImage forKey:kCIInputImageKey];
    
    return [[image imageByCompositingOverImage:[darkenFilter valueForKey:kCIOutputImageKey]] imageByCroppingToRect:[inputExtent CGRectValue]];
}

@end
