//
//  NSArray_SKExtensions.m
//  Skim
//
//  Created by Christiaan Hofman on 5/26/07.
/*
 This software is Copyright (c) 2007-2023
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

#import "NSArray_SKExtensions.h"
#import "NSValue_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSColor_SKExtensions.h"
#import "PDFAnnotation_SKExtensions.h"
#import <SkimNotes/SkimNotes.h>

@implementation NSArray (SKExtensions)

#pragma mark Templating support

- (NSArray *)arraySortedByPageIndex {
    return [self sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationPageIndexKey ascending:YES]]];
}

- (NSArray *)arraySortedByBounds {
    return [self sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:SKPDFAnnotationBoundsOrderKey ascending:YES selector:@selector(compare:)]]];
}

- (NSArray *)arraySortedByPageIndexAndBounds {
    return [self sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationPageIndexKey ascending:YES], [[NSSortDescriptor alloc] initWithKey:SKPDFAnnotationBoundsOrderKey ascending:YES selector:@selector(compare:)]]];
}

- (NSArray *)arraySortedByType {
    return [self sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationTypeKey ascending:YES selector:@selector(noteTypeCompare:)]]];
}

- (NSArray *)arraySortedByContents {
    return [self sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationStringKey ascending:YES selector:@selector(localizedCaseInsensitiveNumericCompare:)]]];
}

- (NSArray *)arraySortedByTypeAndContents {
    return [self sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationTypeKey ascending:YES selector:@selector(noteTypeCompare:)], [[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationStringKey ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
}

- (NSArray *)arraySortedByTypeAndPageIndex {
    return [self sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationTypeKey ascending:YES selector:@selector(noteTypeCompare:)], [[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationPageIndexKey ascending:YES]]];
}

- (NSArray *)arraySortedByColor {
    return [self sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationColorKey ascending:YES selector:@selector(colorCompare:)]]];
}

- (NSArray *)arraySortedByColorAndPageIndex {
    return [self sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationColorKey ascending:YES selector:@selector(colorCompare:)], [[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationPageIndexKey ascending:YES]]];
}

- (NSArray *)arraySortedByModificationDate {
    return [self sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:SKNPDFAnnotationModificationDateKey ascending:YES]]];
}

@end
