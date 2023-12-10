//
//  NSPointerFunctions_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 10/12/2023.
/*
 This software is Copyright (c) 2023
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSPointerFunctions_SKExtensions.h"

static NSUInteger pointSizeFunction(const void *item) { return sizeof(NSPoint); }

static NSUInteger rectSizeFunction(const void *item) { return sizeof(NSRect); }

static NSUInteger rangeSizeFunction(const void *item) { return sizeof(NSRange); }

static NSString *pointDescriptionFunction(const void *item) { return NSStringFromPoint(*(NSPointPointer)item); }

static NSString *rectDescriptionFunction(const void *item) { return NSStringFromRect(*(NSRectPointer)item); }

static NSString *rangeDescriptionFunction(const void *item) { return [NSString stringWithFormat:@"(%lu, %lu)", (unsigned long)(((NSRange *)item)->location), (unsigned long)(((NSRange *)item)->length)]; }

@implementation NSPointerFunctions (SKExtensions)

+ (NSPointerFunctions *)structPointerFunctionsWithSizeFunction:(NSUInteger (*)(const void *))sizeFunction descriptionFunction:(NSString *(*)(const void *))descriptionFunction {
    NSPointerFunctions *pointerFunctions = [self pointerFunctionsWithOptions:NSPointerFunctionsMallocMemory | NSPointerFunctionsCopyIn | NSPointerFunctionsStructPersonality];
    [pointerFunctions setSizeFunction:sizeFunction];
    [pointerFunctions setDescriptionFunction:descriptionFunction];
    return pointerFunctions;
}

+ (NSPointerFunctions *)pointPointerFunctions {
    return [self structPointerFunctionsWithSizeFunction:pointSizeFunction descriptionFunction:pointDescriptionFunction];
}

+ (NSPointerFunctions *)rectPointerFunctions {
    return [self structPointerFunctionsWithSizeFunction:rectSizeFunction descriptionFunction:rectDescriptionFunction];
}

+ (NSPointerFunctions *)rangePointerFunctions {
    return [self structPointerFunctionsWithSizeFunction:rangeSizeFunction descriptionFunction:rangeDescriptionFunction];
}

+ (NSPointerFunctions *)strongPointerFunctions {
    return [self pointerFunctionsWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];
}

+ (NSPointerFunctions *)weakPointerFunctions {
    return [self pointerFunctionsWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPersonality];
}

+ (NSPointerFunctions *)integerPointerFunctions {
    return [self pointerFunctionsWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality];
}

@end
