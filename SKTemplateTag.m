//
//  SKTemplateTag.m
//  Skim
//
//  Created by Christiaan Hofman on 10/12/07.
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

#import "SKTemplateTag.h"
#import "SKTemplateParser.h"

static inline SKAttributeTemplate *copyTemplateForLink(id aLink, NSRange range) {
    SKAttributeTemplate *linkTemplate = nil;
    Class aClass = [aLink class];
    if ([aLink isKindOfClass:[NSURL class]])
        aLink = [[aLink absoluteString] stringByRemovingPercentEncoding];
    if ([aLink isKindOfClass:[NSString class]]) {
        NSArray *template = [SKTemplateParser arrayByParsingTemplateString:aLink isSubtemplate:NO];
        if ([template count] > 1 || ([template count] == 1 && [(SKTemplateTag *)[template lastObject] type] != SKTemplateTagText))
            linkTemplate = [[SKAttributeTemplate alloc] initWithTemplate:template range:range attributeClass:aClass];
    }
    return linkTemplate;
}

static inline NSArray *copyTemplatesForLinksFromAttributedString(NSAttributedString *attrString) {
    NSMutableArray *templates = [[NSMutableArray alloc] init];
    
    [attrString enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, [attrString length]) options:0 usingBlock:^(id aLink, NSRange range, BOOL *stop) {
        SKAttributeTemplate *linkTemplate = copyTemplateForLink(aLink, range);
        if (linkTemplate) {
            [templates addObject:linkTemplate];
        }
    }];
    if ([templates count] == 0)
        templates = nil;
    return templates;
}

@implementation SKTemplateTag

@dynamic type;

- (SKTemplateTagType)type { return -1; }

@end

#pragma mark -

@implementation SKValueTemplateTag

@synthesize keyPath;

- (instancetype)initWithKeyPath:(NSString *)aKeyPath {
    self = [super init];
    if (self) {
        keyPath = [aKeyPath copy];
    }
    return self;
}

- (SKTemplateTagType)type { return SKTemplateTagValue; }

@end

#pragma mark -

@implementation SKRichValueTemplateTag

@synthesize attributes;

- (instancetype)initWithKeyPath:(NSString *)aKeyPath attributes:(NSDictionary *)anAttributes {
    self = [super initWithKeyPath:aKeyPath];
    if (self) {
        attributes = [anAttributes copy];
    }
    return self;
}

- (SKAttributeTemplate *)linkTemplate {
    if (linkTemplate == nil)
        linkTemplate = copyTemplateForLink([attributes objectForKey:NSLinkAttributeName], NSMakeRange(0, 0)) ?: [[SKAttributeTemplate alloc] init];
    return [linkTemplate template] ? linkTemplate : nil;
}

@end

#pragma mark -

@implementation SKCollectionTemplateTag

@dynamic itemTemplate, separatorTemplate;

- (instancetype)initWithKeyPath:(NSString *)aKeyPath itemTemplateString:(NSString *)anItemTemplateString separatorTemplateString:(NSString *)aSeparatorTemplateString {
    self = [super initWithKeyPath:aKeyPath];
    if (self) {
        itemTemplateString = anItemTemplateString;
        separatorTemplateString = aSeparatorTemplateString;
        itemTemplate = nil;
        separatorTemplate = nil;
    }
    return self;
}

- (SKTemplateTagType)type { return SKTemplateTagCollection; }

- (NSArray *)itemTemplate {
    if (itemTemplate == nil && itemTemplateString)
        itemTemplate = [SKTemplateParser arrayByParsingTemplateString:itemTemplateString isSubtemplate:YES];
    return itemTemplate;
}

- (NSArray *)separatorTemplate {
    if (separatorTemplate == nil && separatorTemplateString)
        separatorTemplate = [SKTemplateParser arrayByParsingTemplateString:separatorTemplateString isSubtemplate:YES];
    return separatorTemplate;
}

@end

#pragma mark -

@implementation SKRichCollectionTemplateTag

@dynamic itemTemplate, separatorTemplate;

- (instancetype)initWithKeyPath:(NSString *)aKeyPath itemTemplateAttributedString:(NSAttributedString *)anItemTemplateAttributedString separatorTemplateAttributedString:(NSAttributedString *)aSeparatorTemplateAttributedString {
    self = [super initWithKeyPath:aKeyPath];
    if (self) {
        itemTemplateAttributedString = anItemTemplateAttributedString;
        separatorTemplateAttributedString = aSeparatorTemplateAttributedString;
        itemTemplate = nil;
        separatorTemplate = nil;
    }
    return self;
}

- (SKTemplateTagType)type { return SKTemplateTagCollection; }

- (NSArray *)itemTemplate {
    if (itemTemplate == nil && itemTemplateAttributedString)
        itemTemplate = [SKTemplateParser arrayByParsingTemplateAttributedString:itemTemplateAttributedString isSubtemplate:YES];
    return itemTemplate;
}

- (NSArray *)separatorTemplate {
    if (separatorTemplate == nil && separatorTemplateAttributedString)
        separatorTemplate = [SKTemplateParser arrayByParsingTemplateAttributedString:separatorTemplateAttributedString isSubtemplate:YES];
    return separatorTemplate;
}

@end

#pragma mark -

@implementation SKConditionTemplateTag

@synthesize matchType, matchStrings;

- (instancetype)initWithKeyPath:(NSString *)aKeyPath matchType:(SKTemplateTagMatchType)aMatchType matchStrings:(NSArray *)aMatchStrings subtemplates:(NSArray *)aSubtemplates {
    self = [super initWithKeyPath:aKeyPath];
    if (self) {
        matchType = aMatchType;
        matchStrings = [aMatchStrings copy];
        subtemplates = [aSubtemplates mutableCopy];
    }
    return self;
}

- (SKTemplateTagType)type { return SKTemplateTagCondition; }

- (NSUInteger)countOfSubtemplates {
    return [subtemplates count];
}

- (NSArray *)objectInSubtemplatesAtIndex:(NSUInteger)anIndex {
    id subtemplate = [subtemplates objectAtIndex:anIndex];
    if ([subtemplate isKindOfClass:[NSArray class]] == NO) {
        subtemplate = [SKTemplateParser arrayByParsingTemplateString:subtemplate isSubtemplate:YES];
        [subtemplates replaceObjectAtIndex:anIndex withObject:subtemplate];
    }
    return subtemplate;
}

@end

#pragma mark -

@implementation SKRichConditionTemplateTag

- (NSArray *)objectInSubtemplatesAtIndex:(NSUInteger)anIndex {
    id subtemplate = [subtemplates objectAtIndex:anIndex];
    if ([subtemplate isKindOfClass:[NSArray class]] == NO) {
        subtemplate = [SKTemplateParser arrayByParsingTemplateAttributedString:subtemplate isSubtemplate:YES];
        [subtemplates replaceObjectAtIndex:anIndex withObject:subtemplate];
    }
    return subtemplate;
}

@end

#pragma mark -

@implementation SKTextTemplateTag

@synthesize text;

- (instancetype)initWithText:(NSString *)aText {
    self = [super init];
    if (self) {
        text = aText;
    }
    return self;
}

- (SKTemplateTagType)type { return SKTemplateTagText; }

- (void)appendText:(NSString *)newText {
    [self setText:[text stringByAppendingString:newText]];
}

@end

#pragma mark -

@implementation SKRichTextTemplateTag

@synthesize attributedText;
@dynamic linkTemplates;

- (instancetype)initWithAttributedText:(NSAttributedString *)anAttributedText {
    self = [super init];
    if (self) {
        attributedText = anAttributedText;
    }
    return self;
}

- (SKTemplateTagType)type { return SKTemplateTagText; }

- (NSArray *)linkTemplates {
    if (linkTemplates == nil)
        linkTemplates = copyTemplatesForLinksFromAttributedString(attributedText) ?: [[NSArray alloc] init];
    return [linkTemplates count] ? linkTemplates : nil;
}

- (void)appendAttributedText:(NSAttributedString *)newAttributedText {
    NSMutableAttributedString *newAttrText = [attributedText mutableCopy];
    [newAttrText appendAttributedString:newAttributedText];
    [newAttrText fixAttributesInRange:NSMakeRange(0, [newAttrText length])];
    [self setAttributedText:newAttrText];
}

@end

#pragma mark -

@implementation SKAttributeTemplate

@synthesize range, template, attributeClass;

- (instancetype)initWithTemplate:(NSArray *)aTemplate range:(NSRange)aRange attributeClass:(Class)aClass {
    self = [super init];
    if (self) {
        template = [aTemplate copy];
        range = aRange;
        attributeClass = aClass;
    }
    return self;
}

- (instancetype)init {
    return [self initWithTemplate:nil range:NSMakeRange(0, 0) attributeClass:[NSString class]];
}

@end
