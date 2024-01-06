//
//  NSURL_SKExtensions.h
//  Skim
//
//  Created by Christiaan Hofman on 8/13/07.
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

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (SKExtensions)

+ (BOOL)canReadURLFromPasteboard:(NSPasteboard *)pboard;
+ (nullable NSArray<NSURL *> *)readURLsFromPasteboard:(NSPasteboard *)pboard;
+ (BOOL)canReadFileURLFromPasteboard:(NSPasteboard *)pboard;
+ (nullable NSArray<NSURL *> *)readFileURLsFromPasteboard:(NSPasteboard *)pboard;

- (NSURL *)URLReplacingPathExtension:(NSString *)ext;
- (NSString *)lastPathComponentReplacingPathExtension:(NSString *)ext;

@property (nonatomic, readonly) NSURL *uniqueFileURL;

@property (nonatomic, readonly, getter=isTrashedFileURL) BOOL trashedFileURL;

@property (nonatomic, readonly, getter=isPreskimURL) BOOL skimURL;
@property (nonatomic, readonly, getter=isPreskimFileURL) BOOL skimFileURL;
@property (nonatomic, readonly, getter=isPreskimBookmarkURL) BOOL skimBookmarkURL;
@property (nonatomic, nullable, readonly) NSURL *associatedFileURL;

@property (nonatomic, nullable, readonly) NSAttributedString *icon;
@property (nonatomic, nullable, readonly) NSAttributedString *smallIcon;
@property (nonatomic, nullable, readonly) NSAttributedString *linkedIcon;
@property (nonatomic, nullable, readonly) NSAttributedString *linkedSmallIcon;
@property (nonatomic, nullable, readonly) NSAttributedString *linkedText;
@property (nonatomic, nullable, readonly) NSAttributedString *linkedFileName;

@end

NS_ASSUME_NONNULL_END
