//
//  SKTPixelateTransition.h
//  SkimTransitions
//
//  Created by Christiaan Hofman on 22/5/2019.
//  Copyright Christiaan Hofman 2019. All rights reserved.

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>


@interface SKTPixelateTransition : CIFilter
{
    CIImage     *inputImage;
    CIImage     *inputTargetImage;
    NSNumber    *inputScale;
    NSNumber    *inputTime;
}

@property (nonatomic, strong) CIImage *inputImage;
@property (nonatomic, strong) CIImage *inputTargetImage;
@property (nonatomic, strong) NSNumber *inputScale;
@property (nonatomic, strong) NSNumber *inputTime;

@end
