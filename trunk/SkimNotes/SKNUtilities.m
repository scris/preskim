//
//  SKNUtilities.m
//  SkimNotes
//
//  Created by Christiaan Hofman on 7/17/08.
/*
 This software is Copyright (c) 2008-2023
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

#import "SKNUtilities.h"

#if (defined(TARGET_OS_SIMULATOR) && TARGET_OS_SIMULATOR) || (defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE)

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

#define SKIMNOTES_PLATFORM_IOS

#define SKNColor    UIColor
#define SKNFont     UIFont
#define SKNImage    UIImage

#else

#import <AppKit/AppKit.h>

#define SKIMNOTES_PLATFORM_OSX

#define SKNColor    NSColor
#define SKNFont     NSFont
#define SKNImage    NSImage

#endif

#define NOTE_PAGE_INDEX_KEY @"pageIndex"
#define NOTE_TYPE_KEY @"type"
#define NOTE_CONTENTS_KEY @"contents"
#define NOTE_COLOR_KEY @"color"
#define NOTE_INTERIOR_COLOR_KEY @"interiorColor"
#define NOTE_FONT_COLOR_KEY @"fontColor"
#define NOTE_FONT_KEY @"font"
#define NOTE_FONT_NAME_KEY @"fontName"
#define NOTE_FONT_SIZE_KEY @"fontSize"
#define NOTE_TEXT_KEY @"text"
#define NOTE_IMAGE_KEY @"image"

#define NOTE_WIDGET_TYPE @"Widget"

NSString *SKNSkimTextNotes(NSArray *noteDicts) {
    NSMutableString *textString = [NSMutableString string];
    NSEnumerator *dictEnum = [noteDicts objectEnumerator];
    NSDictionary *dict;
    
    while (dict = [dictEnum nextObject]) {
        NSString *type = [dict objectForKey:NOTE_TYPE_KEY];
        
        if ([type isEqualToString:NOTE_WIDGET_TYPE])
            continue;
        
        NSUInteger pageIndex = [[dict objectForKey:NOTE_PAGE_INDEX_KEY] unsignedIntegerValue];
        NSString *string = [dict objectForKey:NOTE_CONTENTS_KEY];
        NSAttributedString *text = [dict objectForKey:NOTE_TEXT_KEY];
        
        if (pageIndex == NSNotFound || pageIndex == INT_MAX)
            pageIndex = 0;
        
        if ([text isKindOfClass:[NSData class]])
            text = [[[NSAttributedString alloc] initWithData:(NSData *)text options:[NSDictionary dictionary] documentAttributes:NULL error:NULL] autorelease];
        
        [textString appendFormat:@"* %@, page %lu\n\n", type, (long)pageIndex + 1];
        if ([string length]) {
            [textString appendString:string];
            [textString appendString:@" \n\n"];
        }
        if ([text length]) {
            [textString appendString:[text string]];
            [textString appendString:@" \n\n"];
        }
    }
    return textString;
}

NSData *SKNSkimRTFNotes(NSArray *noteDicts) {
    NSMutableAttributedString *attrString = [[[NSMutableAttributedString alloc] init] autorelease];
    NSEnumerator *dictEnum = [noteDicts objectEnumerator];
    NSDictionary *dict;
    
    while (dict = [dictEnum nextObject]) {
        NSString *type = [dict objectForKey:NOTE_TYPE_KEY];
        
        if ([type isEqualToString:NOTE_WIDGET_TYPE])
            continue;
        
        NSUInteger pageIndex = [[dict objectForKey:NOTE_PAGE_INDEX_KEY] unsignedIntegerValue];
        NSString *string = [dict objectForKey:NOTE_CONTENTS_KEY];
        NSAttributedString *text = [dict objectForKey:NOTE_TEXT_KEY];
        
        if (pageIndex == NSNotFound || pageIndex == INT_MAX)
            pageIndex = 0;
        
        if ([text isKindOfClass:[NSData class]])
            text = [[[NSAttributedString alloc] initWithData:(NSData *)text options:[NSDictionary dictionary] documentAttributes:NULL error:NULL] autorelease];
        
        [attrString replaceCharactersInRange:NSMakeRange([attrString length], 0) withString:[NSString stringWithFormat:@"* %@, page %lu\n\n", type, (long)pageIndex + 1]];
        if ([string length]) {
            [attrString replaceCharactersInRange:NSMakeRange([attrString length], 0) withString:string];
            [attrString replaceCharactersInRange:NSMakeRange([attrString length], 0) withString:@" \n\n"];
        }
        if ([text length]) {
            [attrString appendAttributedString:text];
            [attrString replaceCharactersInRange:NSMakeRange([attrString length], 0) withString:@" \n\n"];
            
        }
    }
    [attrString fixAttributesInRange:NSMakeRange(0, [attrString length])];
    return [attrString dataFromRange:NSMakeRange(0, [attrString length]) documentAttributes:[NSDictionary dictionaryWithObjectsAndKeys:NSRTFTextDocumentType, NSDocumentTypeDocumentAttribute, nil] error:NULL];
}

#pragma mark -

static inline BOOL SKNIsNumberArray(id array) {
    if ([array isKindOfClass:[NSArray class]] == NO)
        return NO;
    for (id object in array) {
        if ([object isKindOfClass:[NSNumber class]] == NO)
            return NO;
    }
    return YES;
}

static NSArray *SKNCreateArrayFromColor(SKNColor *color, NSMapTable **colors, NSMutableSet **arrays) {
    if ([color isKindOfClass:[SKNColor class]]) {
        NSArray *array = [*colors objectForKey:color];
        if (array == nil) {
#if defined(SKIMNOTES_PLATFORM_IOS)
            if (CGColorSpaceGetModel(CGColorGetColorSpace([color CGColor])) == kCGColorSpaceModelMonochrome) {
                CGFloat w = 0.0, a = 1.0;
                [color getWhite:&w alpha:&a];
                array = [[NSArray alloc] initWithObjects:[NSNumber numberWithDouble:w], [NSNumber numberWithDouble:a], nil];
            } else {
                CGFloat r = 0.0, g = 0.0, b = 0.0, a = 1.0;
                [color getRed:&r green:&g blue:&b alpha:&a];
                array = [[NSArray alloc] initWithObjects:[NSNumber numberWithDouble:r], [NSNumber numberWithDouble:g], [NSNumber numberWithDouble:b], [NSNumber numberWithDouble:a], nil];
            }
#else
            if ([[color colorSpace] colorSpaceModel] == NSGrayColorSpaceModel) {
                CGFloat w = 0.0, a = 1.0;
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_6
                if ([NSColorSpace respondsToSelector:@selector(genericGamma22GrayColorSpace)] == NO)
                    [[color colorUsingColorSpace:[NSColorSpace genericGrayColorSpace]] getWhite:&w alpha:&a];
                else
#endif
                [[color colorUsingColorSpace:[NSColorSpace genericGamma22GrayColorSpace]] getWhite:&w alpha:&a];
                array = [[NSArray alloc] initWithObjects:[NSNumber numberWithDouble:w], [NSNumber numberWithDouble:a], nil];
            } else {
                CGFloat r = 0.0, g = 0.0, b = 0.0, a = 1.0;
                [[color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]] getRed:&r green:&g blue:&b alpha:&a];
                array = [[NSArray alloc] initWithObjects:[NSNumber numberWithDouble:r], [NSNumber numberWithDouble:g], [NSNumber numberWithDouble:b], [NSNumber numberWithDouble:a], nil];
            }
#endif
            if (colors == NULL)
                *colors = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality capacity:0];
            [*colors setObject:array forKey:color];
        } else {
            [array retain];
        }
        return array;
    } else if (SKNIsNumberArray(color)) {
        NSArray *array = [*arrays member:color];
        if (array == nil) {
            if (*arrays == nil)
                *arrays = [[NSMutableSet alloc] init];
            [*arrays addObject:color];
            array = (NSArray *)color;
        }
        return [array retain];
    } else {
        return nil;
    }
}

static SKNColor *SKNColorFromArray(NSArray *array) {
    if (SKNIsNumberArray(array)) {
        if ([array count] > 2) {
            CGFloat c[4] = {0.0, 0.0, 0.0, 1.0};
            NSUInteger i;
            for (i = 0; i < MAX([array count], 4); i++)
                c[i] = [[array objectAtIndex:i] doubleValue];
#if defined(SKIMNOTES_PLATFORM_IOS)
            return [UIColor colorWithRed:c[0] green:c[1] blue:c[2] alpha:c[3]];
#else
            return [NSColor colorWithColorSpace:[NSColorSpace sRGBColorSpace] components:c count:4];
#endif
        } else if ([array count] > 0) {
            CGFloat c[2] = {0.0, 1.0};
            c[0] = [[array objectAtIndex:0] doubleValue];
            if ([array count] == 2)
                c[1] = [[array objectAtIndex:1] doubleValue];
#if defined(SKIMNOTES_PLATFORM_IOS)
            return [UIColor colorWithWhite:c[0] alpha:c[1]];
#else
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_6
            if ([NSColorSpace respondsToSelector:@selector(genericGamma22GrayColorSpace)] == NO)
                return [NSColor colorWithColorSpace:[NSColorSpace genericGrayColorSpace] components:c count:2];
            else
#endif
                return [NSColor colorWithColorSpace:[NSColorSpace genericGamma22GrayColorSpace] components:c count:2];
#endif
        } else {
            return [SKNColor clearColor];
        }
    } else if ([array isKindOfClass:[SKNColor class]]) {
        return (SKNColor *)array;
    } else {
        return nil;
    }
}

NSArray *SKNSkimNotesFromData(NSData *data) {
    NSArray *noteDicts = nil;
    
    if ([data length] > 0) {
        unsigned char ch = 0;
        if ([data length] > 8)
            [data getBytes:&ch range:NSMakeRange(8, 1)];
        ch >>= 4;
        if (ch == 0xD) {
            @try { noteDicts = [NSKeyedUnarchiver unarchiveObjectWithData:data]; }
            @catch (id e) {}
        } else {
            noteDicts = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainers format:NULL error:NULL];
            if ([noteDicts isKindOfClass:[NSArray class]]) {
                for (NSMutableDictionary *dict in noteDicts) {
                    id value;
                    if ((value = [dict objectForKey:NOTE_COLOR_KEY])) {
                        value = SKNColorFromArray(value);
                        [dict setObject:value forKey:NOTE_COLOR_KEY];
                    }
                    if ((value = [dict objectForKey:NOTE_INTERIOR_COLOR_KEY])) {
                        value = SKNColorFromArray(value);
                        [dict setObject:value forKey:NOTE_INTERIOR_COLOR_KEY];
                    }
                    if ((value = [dict objectForKey:NOTE_FONT_COLOR_KEY])) {
                        value = SKNColorFromArray(value);
                        [dict setObject:value forKey:NOTE_FONT_COLOR_KEY];
                    }
                    if ((value = [dict objectForKey:NOTE_FONT_NAME_KEY])) {
                        NSNumber *fontSize = [dict objectForKey:NOTE_FONT_SIZE_KEY];
                        if ([value isKindOfClass:[NSString class]]) {
                            CGFloat pointSize = [fontSize isKindOfClass:[NSNumber class]] ? [fontSize doubleValue] : 0.0;
                            value = [SKNFont fontWithName:value size:pointSize] ?: [SKNFont fontWithName:@"Helvetica" size:pointSize];
                            [dict setObject:value forKey:NOTE_FONT_KEY];
                        }
                        [dict removeObjectForKey:NOTE_FONT_NAME_KEY];
                        [dict removeObjectForKey:NOTE_FONT_SIZE_KEY];
                    }
                    if ((value = [dict objectForKey:NOTE_TEXT_KEY])) {
                        if ([value isKindOfClass:[NSData class]]) {
                            value = [[NSAttributedString alloc] initWithData:value options:[NSDictionary dictionary] documentAttributes:NULL error:NULL];
                            if (value) {
                                [dict setObject:value forKey:NOTE_TEXT_KEY];
                                [value release];
                            } else {
                                [dict removeObjectForKey:NOTE_TEXT_KEY];
                            }
                        } else if ([value isKindOfClass:[NSAttributedString class]] == NO) {
                            [dict removeObjectForKey:NOTE_TEXT_KEY];
                        }
                    }
                    if ((value = [dict objectForKey:NOTE_IMAGE_KEY])) {
                        if ([value isKindOfClass:[NSData class]]) {
                            value = [[SKNImage alloc] initWithData:value];
                            [dict setObject:value forKey:NOTE_IMAGE_KEY];
                            [value release];
                        } else if ([value isKindOfClass:[SKNImage class]] == NO) {
                            [dict removeObjectForKey:NOTE_IMAGE_KEY];
                        }
                    }
                }
            }
        }
        if ([noteDicts isKindOfClass:[NSArray class]] == NO) {
            noteDicts = nil;
        }
    } else if (data) {
        noteDicts = [NSArray array];
    }
    return noteDicts;
}

NSData *SKNDataFromSkimNotes(NSArray *noteDicts, BOOL asPlist) {
    NSData *data = nil;
    if (noteDicts) {
#if defined(PDFKIT_PLATFORM_IOS)
        asPlist = YES;
#endif
        if (asPlist) {
            NSMutableArray *array = [[NSMutableArray alloc] init];
            NSMapTable *colors = nil;
            NSMutableSet *arrays = nil;
            for (NSDictionary *noteDict in noteDicts) {
                NSMutableDictionary *dict = [noteDict mutableCopy];
                id value;
                if ((value = [dict objectForKey:NOTE_COLOR_KEY])) {
                    value = SKNCreateArrayFromColor(value, &colors, &arrays);
                    [dict setObject:value forKey:NOTE_COLOR_KEY];
                    [value release];
                }
                if ((value = [dict objectForKey:NOTE_INTERIOR_COLOR_KEY])) {
                    value = SKNCreateArrayFromColor(value, &colors, &arrays);
                    [dict setObject:value forKey:NOTE_INTERIOR_COLOR_KEY];
                    [value release];
                }
                if ((value = [dict objectForKey:NOTE_FONT_COLOR_KEY])) {
                    value = SKNCreateArrayFromColor(value, &colors, &arrays);
                    [dict setObject:value forKey:NOTE_FONT_COLOR_KEY];
                    [value release];
                }
                if ((value = [dict objectForKey:NOTE_FONT_KEY])) {
                    if ([value isKindOfClass:[SKNFont class]]) {
                        [dict setObject:[value fontName] forKey:NOTE_FONT_NAME_KEY];
                        [dict setObject:[NSNumber numberWithDouble:[value pointSize]] forKey:NOTE_FONT_SIZE_KEY];
                    }
                    [dict removeObjectForKey:NOTE_FONT_KEY];
                }
                if ((value = [dict objectForKey:NOTE_TEXT_KEY])) {
                    if ([value isKindOfClass:[NSAttributedString class]]) {
#if !defined(PDFKIT_PLATFORM_IOS) && (!defined(MAC_OS_X_VERSION_10_11) || MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_11)
                        if ([value containsAttachments]) {
#else
                        if ([value containsAttachmentsInRange:NSMakeRange(0, [value length])]) {
#endif
                            value = [value dataFromRange:NSMakeRange(0, [value length]) documentAttributes:[NSDictionary dictionaryWithObjectsAndKeys:NSRTFDTextDocumentType, NSDocumentTypeDocumentAttribute, nil] error:NULL];
                        } else {
                            value = [value dataFromRange:NSMakeRange(0, [value length]) documentAttributes:[NSDictionary dictionaryWithObjectsAndKeys:NSRTFTextDocumentType, NSDocumentTypeDocumentAttribute, nil] error:NULL];
                        }
                        [dict setObject:value forKey:NOTE_TEXT_KEY];
                    } else if ([value isKindOfClass:[NSData class]] == NO) {
                        [dict removeObjectForKey:NOTE_TEXT_KEY];
                    }
                }
                if ((value = [dict objectForKey:NOTE_IMAGE_KEY])) {
                    if ([value isKindOfClass:[SKNImage class]]) {
#if defined(SKIMNOTES_PLATFORM_IOS)
                        value = UIImagePNGRepresentation(value);
#else
                        id imageRep = [[value representations] count] == 1 ? [[value representations] objectAtIndex:0] : nil;
                        if ([imageRep isKindOfClass:[NSPDFImageRep class]]) {
                            value = [imageRep PDFRepresentation];
                        } else if ([imageRep isKindOfClass:[NSEPSImageRep class]]) {
                            value = [imageRep EPSRepresentation];
                        } else {
                            value = [value TIFFRepresentation];
                        }
#endif
                        [dict setObject:value forKey:NOTE_IMAGE_KEY];
                    } else if ([value isKindOfClass:[NSData class]] == NO) {
                        [dict removeObjectForKey:NOTE_IMAGE_KEY];
                    }
                }
                [array addObject:dict];
                [dict release];
            }
            data = [NSPropertyListSerialization dataWithPropertyList:array format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
            [array release];
            [colors release];
            [arrays release];
        } else {
            data = [NSKeyedArchiver archivedDataWithRootObject:noteDicts];
        }
    }
    return data;
}
