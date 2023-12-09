//
//  SKTRadarTransition.h
//  RadarTransition
//
//  Created by Christiaan Hofman on 22/5/2019.
//  Copyright Christiaan Hofman 2019-2023. All rights reserved.

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>


@interface SKTRadarTransition : CIFilter
{
    CIImage     *inputImage;
    CIImage     *inputTargetImage;
    CIVector    *inputCenter;
    NSNumber    *inputAngle;
    NSNumber    *inputWidth;
    NSNumber    *inputTime;
}

@property (nonatomic, strong) CIImage *inputImage;
@property (nonatomic, strong) CIImage *inputTargetImage;
@property (nonatomic, strong) CIVector *inputCenter;
@property (nonatomic, strong) NSNumber *inputAngle;
@property (nonatomic, strong) NSNumber *inputWidth;
@property (nonatomic, strong) NSNumber *inputTime;

@end
