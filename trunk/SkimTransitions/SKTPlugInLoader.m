//
//  SKTPlugInLoader.m
//  SkimTransitions
//
//  Created by Christiaan Hofman on 22/05/2019.
//  Copyright © 2019-2022 Skim. All rights reserved.
//

#import "SKTPlugInLoader.h"

@implementation SKTPlugInLoader

- (BOOL)load:(void *)host {
    return YES;
}

+ (CIKernel *)kernelWithName:(NSString *)name {
    static NSArray *kernels = nil;
    if (kernels == nil) {
        NSBundle *bundle = [NSBundle bundleForClass:self];
        NSString *code = [NSString stringWithContentsOfURL:[bundle URLForResource:@"SKTTransitions" withExtension:@"cikernel"] encoding:NSUTF8StringEncoding error:NULL];
        kernels = [CIKernel kernelsWithString:code];
    }
    for (CIKernel *kernel in kernels) {
        if ([[kernel name] isEqualToString:name])
            return kernel;
    }
    return nil;
}

@end
