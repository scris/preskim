//
//  SKTemplateParser.h
//  Skim
//
//  Created by Christiaan Hofman on 5/26/07.
/*
 This software is Copyright (c) 2007
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

#import <Cocoa/Cocoa.h>


@protocol SKTemplateParserDelegate

- (void)templateParserWillParseTemplate:(id)template usingObject:(id)object isAttributed:(BOOL)flag;
- (void)templateParserDidParseTemplate:(id)template usingObject:(id)object isAttributed:(BOOL)flag;

@end


@interface SKTemplateParser : NSObject

+ (NSString *)stringByParsingTemplate:(NSString *)template usingObject:(id)object;
+ (NSString *)stringByParsingTemplate:(NSString *)template usingObject:(id)object delegate:(id <SKTemplateParserDelegate>)delegate;
+ (NSAttributedString *)attributedStringByParsingTemplate:(NSAttributedString *)template usingObject:(id)object;
+ (NSAttributedString *)attributedStringByParsingTemplate:(NSAttributedString *)template usingObject:(id)object delegate:(id <SKTemplateParserDelegate>)delegate;

@end


@interface NSObject (SKTemplateParser)
- (NSString *)stringDescription;
- (BOOL)isNotEmpty;
@end


@interface NSScanner (SKTemplateParser)
- (BOOL)scanEmptyLine;
@end


@interface NSAttributedString (SKTemplateParser)
- (id)initWithAttributedString:(NSAttributedString *)attributedString attributes:(NSDictionary *)attributes;
- (NSString *)xmlString;
- (NSData *)RTFRepresentation;
@end

@interface NSString (SKTemplateParser)
- (NSString *)xmlString;
@end


@interface NSData (SKTemplateParser)
- (NSString *)xmlString;
- (NSString *)utf8String;
@end
