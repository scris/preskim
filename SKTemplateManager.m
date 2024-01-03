//
//  SKTemplateManager.m
//  Skim
//
//  Created by Christiaan Hofman on 8/19/11.
/*
 This software is Copyright (c) 2011
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

#import "SKTemplateManager.h"
#import "NSFileManager_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "SKDocumentController.h"

#define TEMPLATES_DIRECTORY @"Templates"


@implementation SKTemplateManager

@dynamic customTemplateTypes;

+ (SKTemplateManager *)sharedManager {
    static id sharedManager = nil;
    if (sharedManager == nil)
        sharedManager = [[self alloc] init];
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        templateFileNames = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"notesTemplate.txt", SKNotesTextDocumentType, @"notesTemplate.rtf", SKNotesRTFDocumentType, @"notesTemplate.rtfd", SKNotesRTFDDocumentType, nil];
    }
    return self;
}

- (NSArray *)customTemplateTypes {
    if (customTemplateTypes == nil) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSMutableArray *templates = [NSMutableArray array];
        NSMutableDictionary *types = [NSMutableDictionary dictionary];
                             
        for (NSURL *appSupportURL in [fm applicationSupportDirectoryURLs]) {
            NSURL *templatesURL = [appSupportURL URLByAppendingPathComponent:TEMPLATES_DIRECTORY isDirectory:YES];
            NSNumber *isDir = nil;
            [appSupportURL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
            if ([isDir boolValue]) {
                for (NSURL *url in [fm contentsOfDirectoryAtURL:templatesURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL]) {
                    NSString *file = [url lastPathComponent];
                    if ([[file stringByDeletingPathExtension] isEqualToString:@"notesTemplate"] == NO &&
                        [templates containsObject:file] == NO) {
                        [templates addObject:file];
                        NSString *type = [[templateFileNames allKeysForObject:file] firstObject];
                        if (type == nil) {
                            if (@available(macOS 11.0, *)) {
                                // create a unique but deterministic dynamic UTI that knows the extension
                                CFStringRef baseType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassNSPboardType, (__bridge CFStringRef)file, NULL);
                                type = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[file pathExtension], baseType));
                                CFRelease(baseType);
                            } else {
                                // NSSavePanel on 10.15- cannot handle dynamic UTIs
                                // make sure the type cannot be confused with a UTI
                                type = [NSString stringWithFormat:@"%@_%@", [file stringByDeletingPathExtension], [file pathExtension]];
                            }
                            [templateFileNames setObject:file forKey:type];
                        }
                        [types setObject:type forKey:file];
                    }
                }
            }
        }
        [templates sortUsingSelector:@selector(caseInsensitiveCompare:)];
        customTemplateTypes = [[types objectsForKeys:templates notFoundMarker:@""] copy];
    }
    return customTemplateTypes;
}

- (void)resetCustomTemplateTypes {
    customTemplateTypes = nil;
}

- (NSURL *)URLForTemplateType:(NSString *)typeName {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *url = nil;
    NSString *file = [templateFileNames objectForKey:typeName];
    
    if (file == nil)
        return nil;
    
    for (NSURL *appSupportURL in [[fm applicationSupportDirectoryURLs] arrayByAddingObject:[[NSBundle mainBundle] sharedSupportURL]]) {
        url = [[appSupportURL URLByAppendingPathComponent:TEMPLATES_DIRECTORY isDirectory:YES] URLByAppendingPathComponent:file isDirectory:NO];
        if ([url checkResourceIsReachableAndReturnError:NULL] == NO)
            url = nil;
        else break;
    }
    
    return url;
}

- (NSString *)fileNameExtensionForTemplateType:(NSString *)typeName {
    return [[self customTemplateTypes] containsObject:typeName] ? [[templateFileNames objectForKey:typeName] pathExtension] : nil;
}

- (NSString *)displayNameForTemplateType:(NSString *)typeName {
    return [[self customTemplateTypes] containsObject:typeName] ? [[templateFileNames objectForKey:typeName] stringByDeletingPathExtension] : nil;
}

- (NSString *)templateTypeForDisplayName:(NSString *)name {
    for (NSString *typeName in [self customTemplateTypes]) {
        NSString *fileName = [templateFileNames objectForKey:typeName];
        if ([fileName isEqualToString:name] || [[fileName stringByDeletingPathExtension] isEqualToString:name])
            return typeName;
    }
    return nil;
}

- (BOOL)isRichTextTemplateType:(NSString *)typeName {
    static NSSet *types = nil;
    if (types == nil)
        types = [[NSSet alloc] initWithObjects:@"rtf", @"doc", @"docx", @"odt", @"webarchive", @"rtfd", nil];
    return [types containsObject:[[[templateFileNames objectForKey:typeName] pathExtension] lowercaseString]];
}

- (BOOL)isRichTextBundleTemplateType:(NSString *)typeName {
    return [[[templateFileNames objectForKey:typeName] pathExtension] isCaseInsensitiveEqual:@"rtfd"];
}

@end
