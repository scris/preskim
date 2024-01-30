//
//  SKObtainCommand.m
//  Skim
//
//  Created by Christiaan Hofman on 16/12/2021.
/*
 This software is Copyright (c) 2021
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

#import "SKObtainCommand.h"
#import <Quartz/Quartz.h>
#import "PDFSelection_SKExtensions.h"
#import "NSAttributedString_SKExtensions.h"
#import "NSGeometry_SKExtensions.h"

#define typeRichText 'ricT'
#define typeRTF      'RTF '
#define typePage     'Page'

@implementation SKObtainCommand

- (id)performDefaultImplementation {
    NSDictionary *args = [self evaluatedArguments];
    NSData *data = [args objectForKey:@"Object"];
    PDFSelection *selection = nil;
    NSAppleEventDescriptor *desc = nil;
    PDFPage *page = [args objectForKey:@"Page"];
    id typeNumber = [self directParameter];
    FourCharCode type = [typeNumber respondsToSelector:@selector(unsignedIntValue)] ? [typeNumber unsignedIntValue] : typeRichText;
    
    if (type == cText || type == typeText || type == typeUnicodeText || type == typeUTF8Text || type == typeCString || type == typeChar) {
        type = cText;
    } else if (type == typeRichText || type == 'cha ' || type == 'cpar' || type == 'cwor' || type == 'catr' || type == typeStyledText) {
        type = typeRichText;
    } else if (type == typeSInt32 || type == typeUInt32 || type == typeSInt16 || type == typeUInt16 || type == typeSInt64 || type == typeUInt64 || type == 'nmbr') {
        type = typeSInt32;
    } else if (type == typeQDRectangle || type == typeRectangle) {
        type = typeQDRectangle;
    } else if (type != typePage && type != typeRTF) {
        [self setScriptErrorNumber:NSOperationNotSupportedForKeyScriptError];
        return nil;
    }
    
    if ([data isKindOfClass:[NSData class]] == NO) {
        data = nil;
        selection = [PDFSelection selectionWithSpecifier:[[self arguments] objectForKey:@"Object"] onPage:page];
    } else if (type == typeSInt32 || type == typeQDRectangle || type == typePage) {
        [self setScriptErrorNumber:NSOperationNotSupportedForKeyScriptError];
        return nil;
    }
    
    if (type == cText || type == typeRichText || type == typeRTF) {
        NSAttributedString *attrString = [selection attributedString];
        if (data)
            attrString = [[NSAttributedString alloc] initWithData:data options:@{} documentAttributes:NULL error:NULL];
        if (type == cText)
            desc = [NSAppleEventDescriptor descriptorWithString:[attrString string]];
        else if (type == typeRTF)
            desc = [NSAppleEventDescriptor descriptorWithDescriptorType:type data:[attrString RTFRepresentation]];
        else
            desc = [[attrString richTextSpecifier] descriptor];
    } else if (type == typeQDRectangle) {
        NSRect bounds = [selection hasCharacters] ? [selection boundsForPage:page ?: [selection safeFirstPage]] : NSZeroRect;
        Rect qdBounds = SKQDRectFromNSRect(bounds);
        desc = [NSAppleEventDescriptor descriptorWithDescriptorType:type bytes:&qdBounds length:sizeof(Rect)];
    } else if (type == typeSInt32) {
        NSUInteger first = NSNotFound, last = NSNotFound;
        if ((page = [selection safeFirstPage]))
            first = [selection safeIndexOfFirstCharacterOnPage:page];
        if ((page = [selection safeLastPage]))
            last = [selection safeIndexOfLastCharacterOnPage:page];
        desc = [NSAppleEventDescriptor listDescriptor];
        [desc insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:first == NSNotFound ? 0 : (int)first + 1] atIndex:1];
        [desc insertDescriptor:[NSAppleEventDescriptor descriptorWithInt32:last == NSNotFound ? 0 : (int)last + 1] atIndex:2];
    } else if (type == typePage) {
        NSArray *pages = [selection pages];
        if ([pages count] == 1) {
            desc = [[[pages firstObject] objectSpecifier] descriptor];
        } else {
            desc = [NSAppleEventDescriptor listDescriptor];
            NSInteger i = 0;
            for (page in pages)
                [desc insertDescriptor:[[page objectSpecifier] descriptor] atIndex:++i];
        }
    }
    return desc;
}

@end
