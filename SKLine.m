//
//  SKLine.m
//  Skim
//
//  Created by Christiaan Hofman on 26/06/2022.
/*
 This software is Copyright (c) 2022-2023
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

#import "SKLine.h"
#import <Quartz/Quartz.h>
#import "PDFPage_SKExtensions.h"
#import "PDFSelection_SKExtensions.h"
#import "NSPointerArray_SKExtensions.h"
#import "NSData_SKExtensions.h"

@implementation SKLine

@synthesize page, index;
@dynamic bounds, scriptingIndex, boundsAsQDRect, selectionSpecifier;

- (id)initWithPage:(PDFPage *)aPage index:(NSInteger)anIndex {
    self = [super init];
    if (self) {
        page = [aPage retain];
        index = anIndex;
    }
    return self;
}

- (void)dealloc {
    SKDESTROY(page);
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: line=%ld, page=%@>", [self class], (long)index, page];
}

- (NSRect)bounds {
    return [[page lineRects] rectAtIndex:index];
}

- (NSInteger)scriptingIndex {
    return index + 1;
}

- (NSData *)boundsAsQDRect {
    return [NSData dataWithRectAsQDRect:[self bounds]];
}

- (id)selectionSpecifier {
    PDFSelection *sel = [page selectionForRect:NSInsetRect([self bounds], -1.0, -1.0)];
    return [sel hasCharacters] ? [sel objectSpecifiers] : @[];
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSScriptObjectSpecifier *containerRef = [page objectSpecifier];
    return [[[NSIndexSpecifier alloc] initWithContainerClassDescription:[containerRef keyClassDescription] containerSpecifier:containerRef key:@"lines" index:index] autorelease];
}

@end
