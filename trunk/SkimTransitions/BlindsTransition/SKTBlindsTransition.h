//
//  SKTBlindsTransition.h
//  SkimTransitions
//
//  Created by Christiaan Hofman on 22/5/2019.
//  Copyright Christiaan Hofman 2019-2023. All rights reserved.

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>


@interface SKTBlindsTransition : CIFilter
{
    CIImage     *inputImage;
    CIImage     *inputTargetImage;
    NSNumber    *inputWidth;
    NSNumber    *inputTime;
}

@property (nonatomic, retain) CIImage *inputImage;
@property (nonatomic, retain) CIImage *inputTargetImage;
@property (nonatomic, retain) NSNumber *inputWidth;
@property (nonatomic, retain) NSNumber *inputTime;

@end
