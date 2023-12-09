//
//  SKTPageTurnTransition.h
//  SkimTransitions
//
//  Created by Christiaan Hofman on 22/05/2019.
//  Copyright © 2019-2023 Skim. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

@interface SKTPageTurnTransition : CIFilter {
    CIImage      *inputImage;
    CIImage      *inputTargetImage;
    CIVector     *inputExtent;
    NSNumber     *inputAngle;
    NSNumber     *inputTime;
}

@property (nonatomic, strong) CIImage *inputImage;
@property (nonatomic, strong) CIImage *inputTargetImage;
@property (nonatomic, strong) CIVector *inputExtent;
@property (nonatomic, strong) NSNumber *inputAngle;
@property (nonatomic, strong) NSNumber *inputTime;

@end
