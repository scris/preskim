//
//  SKNDocument.m
//  SkimNotes
//
//  Created by Christiaan Hofman on 7/16/08.
/*
 This software is Copyright (c) 2008
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

#import "SKNDocument.h"
#import <SkimNotesBase/SkimNotesBase.h>
#import "SKNSkimReader.h"
#import "SKNXPCSkimReader.h"

#define SKNPDFDocumentType @"com.adobe.pdf"
#define SKNPDFBundleDocumentType @"scris.ds.preskim.pdfd"
#define SKNSkimNotesDocumentType @"scris.ds.preskim.notes"

#define SKNDocumentErrorDomain @"SKNDocumentErrorDomain"

@implementation SKNDocument

@synthesize notes = _notes;

+ (void)initialize {
    [NSValueTransformer setValueTransformer:[[SKNPlusOneTransformer alloc] init] forName:@"SKNPlusOne"];
}

+ (BOOL)autosavesInPlace {
    return NO;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _notes = [[NSArray alloc] init];
    }
    return self;
}

- (NSString *)windowNibName {
    return @"SKNDocument";
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)docType error:(NSError **)outError {
    
#if defined(FrameworkSample)
    
    if ([[NSWorkspace sharedWorkspace] type:SKNSkimNotesDocumentType conformsToType:docType]) {
        return [[NSFileManager defaultManager] writeSkimNotes:_notes toPreskimFileAtURL:absoluteURL error:outError];
    } else {
        if (outError)
            *outError = [NSError errorWithDomain:SKNDocumentErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to save notes", @""), NSLocalizedDescriptionKey, nil]];
        return NO;
    }
    
#else
    
    return [super writeToURL:absoluteURL ofType:docType error:outError];
    
#endif
    
}

- (NSData *)dataOfType:(NSString *)docType error:(NSError **)outError {
    NSData *data = nil;
    if ([[NSWorkspace sharedWorkspace] type:SKNSkimNotesDocumentType conformsToType:docType]) {
        data = [NSKeyedArchiver archivedDataWithRootObject:_notes];
    }
    if (data == nil && outError)
        *outError = [NSError errorWithDomain:SKNDocumentErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to save notes", @""), NSLocalizedDescriptionKey, nil]];
    return data;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)docType error:(NSError **)outError {
    NSArray *array = nil;
    NSError *error = nil;
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    
#if defined(FrameworkSample)
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([ws type:docType conformsToType:SKNPDFDocumentType]) {
        array = [fm readSkimNotesFromExtendedAttributesAtURL:absoluteURL error:&error];
    } else if ([ws type:docType conformsToType:SKNPDFBundleDocumentType]) {
        array = [fm readSkimNotesFromPDFBundleAtURL:absoluteURL error:&error];
    } else if ([ws type:docType conformsToType:SKNSkimNotesDocumentType]) {
        array = [fm readSkimNotesFromPreskimFileAtURL:absoluteURL error:&error];
    }
    
#elif defined(AgentSample)
    
    NSData *data = nil;
    
    if ([ws type:docType conformsToType:SKNPDFDocumentType] ||
        [ws type:docType conformsToType:SKNPDFBundleDocumentType] ||
        [ws type:docType conformsToType:SKNSkimNotesDocumentType]) {
        data = [[SKNPreskimReader sharedReader] SkimNotesAtURL:absoluteURL];
        if (data) {
            @try { array = [NSKeyedUnarchiver unarchiveObjectWithData:data]; }
            @catch (id e) {}
            if (array == nil)
                array = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
        }
    }

#elif defined(XPCAgentSample)
    
    NSData *data = nil;
    
    if ([ws type:docType conformsToType:SKNPDFDocumentType] ||
        [ws type:docType conformsToType:SKNPDFBundleDocumentType] ||
        [ws type:docType conformsToType:SKNSkimNotesDocumentType]) {
        data = [[SKNXPCPreskimReader sharedReader] SkimNotesAtURL:absoluteURL];
        if (data) {
            @try { array = [NSKeyedUnarchiver unarchiveObjectWithData:data]; }
            @catch (id e) {}
            if (array == nil)
                array = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
        }
    }

#elif defined(AsyncXPCAgentSample)
    
    if ([ws type:docType conformsToType:SKNPDFDocumentType] ||
        [ws type:docType conformsToType:SKNPDFBundleDocumentType] ||
        [ws type:docType conformsToType:SKNSkimNotesDocumentType]) {
        [[SKNXPCPreskimReader sharedReader] readSkimNotesAtURL:absoluteURL reply:(NSData *data){
            if (data) {
                NSArray *arr = nil;
                @try { arr = [NSKeyedUnarchiver unarchiveObjectWithData:data]; }
                @catch (id e) {}
                if (arr == nil)
                    arr = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
                if (arr)
                    [self setNotes:arr];
            }
        }];
        array = @[];
    }

#elif defined(ToolSample)
    
    NSData *data = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([ws type:docType conformsToType:SKNPDFDocumentType]) {
        NSString *path = [absoluteURL path];
        NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
        NSString *tmpPath = [tmpDir stringByAppendingPathComponent:[[[path lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pskn"]];
        NSString *binPath = [[NSBundle mainBundle] pathForResource:@"skimnotes" ofType:nil];
        NSArray *arguments = [NSArray arrayWithObjects:@"get", path, tmpPath, nil];
        
        [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:NULL];
        
        NSTask *task = [[NSTask alloc] init];
        [task setCurrentDirectoryPath:tmpDir];
        [task setLaunchPath:binPath];
        [task setArguments:arguments];
        [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
        [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
            
        BOOL success = YES;
        
        @try {
            [task launch];
            [task waitUntilExit];
            data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:tmpPath] options:0 error:NULL];
        }
        @catch(id exception) {
            if([task isRunning])
                [task terminate];
            NSLog(@"%@ %@ failed", [task description], [task launchPath]);
            success = NO;
        }
        
        if (success && [task terminationStatus] == 0 && data == nil)
            data = [NSData data];
        
        task = nil;
        [fm removeItemAtPath:tmpDir error:NULL];
    } else if ([ws type:docType conformsToType:SKNPDFBundleDocumentType]) {
        NSString *bundlePath = [absoluteURL path];
        NSString *filename = [[[bundlePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathComponent:@"pskn"];
        NSString *skimPath = [bundlePath stringByAppendingPathComponent:filename];
        if ([fm fileExistsAtPath:skimPath] == NO && [fm fileExistsAtPath:bundlePath]) {
            NSArray *filenames = [fm subpathsAtPath:bundlePath];
            NSUInteger idx = [[filenames valueForKey:@"pathExtension"] indexOfObject:@"pskn"];
            if (idx != NSNotFound) {
                filename = [filenames objectAtIndex:idx];
                skimPath = [bundlePath stringByAppendingPathComponent:filename];
            }
        }
        data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:skimPath] options:0 error:NULL];
    } else if ([ws type:docType conformsToType:SKNSkimNotesDocumentType]) {
        data = [NSData dataWithContentsOfURL:absoluteURL options:0 error:NULL];
    }
    if (data) {
        if ([data length]) {
            @try { array = [NSKeyedUnarchiver unarchiveObjectWithData:data]; }
            @catch (id e) {}
            if (array == nil)
                array = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
        } else {
            array = @[];
        }
    }
    
#endif
    
    if (array) {
        [self setNotes:array];
    } else if (outError) {
        *outError = error ? error : [NSError errorWithDomain:SKNDocumentErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Unable to read notes", @""), NSLocalizedDescriptionKey, nil]];
    }
    
    return array != nil;
}

@end


@implementation SKNPlusOneTransformer

+ (Class)transformedValueClass {
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
	return value == nil ? nil : [NSNumber numberWithUnsignedInteger:[value unsignedIntegerValue] + 1];
}

@end
