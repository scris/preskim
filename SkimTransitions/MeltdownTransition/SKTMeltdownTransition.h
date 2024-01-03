//
//  SKTMeltdownTransition.h
//  MeltdownTransition
//
//  Created by Christiaan Hofman on 22/5/2019.
//  Copyright Christiaan Hofman 2019. All rights reserved.

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>


@interface SKTMeltdownTransition : CIFilter
{
    CIImage     *inputImage;
    CIImage     *inputTargetImage;
    CIImage     *inputMaskImage;
    CIVector    *inputExtent;
    NSNumber    *inputAmount;
    NSNumber    *inputTime;
}

@property (nonatomic, strong) CIImage *inputImage;
@property (nonatomic, strong) CIImage *inputTargetImage;
@property (nonatomic, strong) CIImage *inputMaskImage;
@property (nonatomic, strong) CIVector *inputExtent;
@property (nonatomic, strong) NSNumber *inputAmount;
@property (nonatomic, strong) NSNumber *inputTime;

@end
