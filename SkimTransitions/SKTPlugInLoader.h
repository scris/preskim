//
//  SKTPlugInLoader.h
//  SkimTransitions
//
//  Created by Christiaan Hofman on 22/05/2019.
//  Copyright © 2019 Skim. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

@interface SKTPlugInLoader : NSObject <CIPlugInRegistration>

- (BOOL)load:(void *)host;

+ (CIKernel *)kernelWithName:(NSString *)name;

@end
