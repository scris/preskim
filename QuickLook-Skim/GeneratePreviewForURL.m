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

#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Cocoa/Cocoa.h>
#import "SKQLConverter.h"


static NSDictionary *imageAttachments(NSSet *imageNames, QLPreviewRequestRef preview)
{
    NSMutableDictionary *attachments = [NSMutableDictionary dictionary];
    CFBundleRef bundle = QLPreviewRequestGetGeneratorBundle(preview);
    NSMutableDictionary *imgProps;
    
    for (NSString *imageName in imageNames) {
        NSURL *imgURL = (NSURL *)CFBridgingRelease(CFBundleCopyResourceURL(bundle, (__bridge CFStringRef)imageName, CFSTR("png"), NULL));
        if (imgURL) {
            NSData *imgData = [NSData dataWithContentsOfURL:imgURL];
            if (imgData) {
                imgProps = [[NSMutableDictionary alloc] init];
                [imgProps setObject:imgData forKey:(NSString *)kQLPreviewPropertyAttachmentDataKey];
                [attachments setObject:imgProps forKey:[imageName stringByAppendingPathExtension:@"png"]];
            }
        }
    }
    return attachments;
}

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    OSStatus err = 2;
    
    @autoreleasepool{
        
        if (UTTypeEqual(CFSTR("scris.ds.preskim.pdfd"), contentTypeUTI)) {
            
            NSString *pdfFile = SKQLPDFPathForPDFBundleURL((__bridge NSURL *)url);
            if (pdfFile) {
                NSData *data = [NSData dataWithContentsOfFile:pdfFile];
                if (data) {
                    QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)data, kUTTypePDF, NULL);
                    err = noErr;
                }
            }
            
        } else if (UTTypeEqual(CFSTR("com.adobe.postscript"), contentTypeUTI)) {
            
            if (floor(NSAppKitVersionNumber) <= 2299.0) {
                bool converted = false;
                CGPSConverterCallbacks converterCallbacks = { 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL };
                CGPSConverterRef converter = CGPSConverterCreate(NULL, &converterCallbacks, NULL);
                CGDataProviderRef provider = CGDataProviderCreateWithURL(url);
                CFMutableDataRef data = CFDataCreateMutable(NULL, 0);
                CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(data);
                if (provider != NULL && consumer != NULL)
                    converted = CGPSConverterConvert(converter, provider, consumer, NULL);
                CGDataProviderRelease(provider);
                CGDataConsumerRelease(consumer);
                CFRelease(converter);
                if (converted) {
                    QLPreviewRequestSetDataRepresentation(preview, data, kUTTypePDF, NULL);
                    err = noErr;
                }
                if (data) CFRelease(data);
            }
            
        } else if (UTTypeEqual(CFSTR("scris.ds.preskim.notes"), contentTypeUTI)) {
            
            NSData *data = [[NSData alloc] initWithContentsOfURL:(__bridge NSURL *)url options:NSUncachedRead error:NULL];
            if (data) {
                NSArray *notes = [SKQLConverter notesWithData:data];
                NSString *htmlString = [SKQLConverter htmlStringWithNotes:notes];
                if ((data = [htmlString dataUsingEncoding:NSUTF8StringEncoding])) {
                    NSSet *types = [NSSet setWithArray:[notes valueForKey:@"type"]];
                    NSDictionary *props = [NSDictionary dictionaryWithObjectsAndKeys:
                                                @"UTF-8", (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey,
                                                @"text/html", (__bridge NSString *)kQLPreviewPropertyMIMETypeKey,
                                                imageAttachments(types, preview), (NSString *)kQLPreviewPropertyAttachmentsKey, nil];
                    QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)data, kUTTypeHTML, (__bridge CFDictionaryRef)props);
                    err = noErr;
                }
            }
            
        }
        
    }
    
    return err;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
