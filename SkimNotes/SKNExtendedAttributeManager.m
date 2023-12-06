//
//  SKNExtendedAttributeManager.m
//  SkimNotes
//
//  Created by Adam R. Maxwell on 05/12/05.
/*
 This software is Copyright (c) 2005-2023
 Adam R. Maxwell. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Adam R. Maxwell nor the names of any
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

#import "SKNExtendedAttributeManager.h"
#import "SKNLocalizations.h"
#include <sys/xattr.h>
#import <bzlib.h>

#define MAX_XATTR_LENGTH        2048
#define MAX_NAME_PREFIX_LENGTH  80
#define MIN_EXTRA_NAME_LENGTH   34
#define PREFIX                  @"net_sourceforge_skim-app"

#define FRAGMENT_NAME_SEPARATOR @"-"
#define NAME_SEPARATOR          @"_"
#define UNIQUE_KEY_SUFFIX       @"_unique_key"
#define WRAPPER_KEY_SUFFIX      @"_has_wrapper"
#define FRAGMENTS_KEY_SUFFIX    @"_number_of_fragments"

#define SYNCABLE_FLAG      @"#S"
#define SYNCABLE_SEPARATOR @"#"

#ifndef NSFoundationVersionNumber10_10
#define NSFoundationVersionNumber10_10 1151.16
#endif

NSString *SKNSkimNotesErrorDomain = @"SKNSkimNotesErrorDomain";

@interface SKNExtendedAttributeManager (SKNPrivate)
// private methods to get a unique attractor name for fragments
- (NSString *)uniqueName;
// private methods to (un)compress data
- (NSData *)bzipData:(NSData *)data;
- (NSData *)bunzipData:(NSData *)data;
- (BOOL)isBzipData:(NSData *)data;
- (BOOL)isPlistData:(NSData *)data;
// private method to print error messages
- (NSError *)xattrError:(NSInteger)err forPath:(NSString *)path;
@end


@implementation SKNExtendedAttributeManager

+ (SKNExtendedAttributeManager *)sharedManager;
{
    static SKNExtendedAttributeManager *sharedManager = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

+ (SKNExtendedAttributeManager *)sharedNoSplitManager;
{
    static SKNExtendedAttributeManager *sharedNoSplitManager = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedNoSplitManager = [[self alloc] initWithPrefix:nil];
    });
    return sharedNoSplitManager;
}

+ (SKNExtendedAttributeManager *)mainManager;
{
    static SKNExtendedAttributeManager *mainManager = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        mainManager = [[self alloc] initWithPrefix:[[NSBundle mainBundle] bundleIdentifier]];
    });
    return mainManager;
}

- (id)init;
{
    return [self initWithPrefix:PREFIX];
}

- (id)initWithPrefix:(NSString *)prefix;
{
    self = [super init];
    if (self) {
        _uniqueKey = [prefix stringByAppendingString:UNIQUE_KEY_SUFFIX];
        _wrapperKey = [prefix stringByAppendingString:WRAPPER_KEY_SUFFIX];
        _fragmentsKey = [prefix stringByAppendingString:FRAGMENTS_KEY_SUFFIX];
        if ([prefix length] > MAX_NAME_PREFIX_LENGTH)
            prefix = [prefix substringToIndex:MAX_NAME_PREFIX_LENGTH];
        _namePrefix = [prefix stringByAppendingString:NAME_SEPARATOR];
    }
    return self;
}

- (NSArray *)extendedAttributeNamesAtPath:(NSString *)path traverseLink:(BOOL)follow includeFragments:(BOOL)fragments error:(NSError **)error;
{
    const char *fsPath = [path fileSystemRepresentation];
    
    int xopts;
    
    if(follow)
        xopts = 0;
    else
        xopts = XATTR_NOFOLLOW;    
    
    size_t bufSize;
    ssize_t status;
    
    // call with NULL as attr name to get the size of the returned buffer
    status = listxattr(fsPath, NULL, 0, xopts);
    
    if(status == -1){
        if(error) *error = [self xattrError:errno forPath:path];
        return nil;
    }
    
    bufSize = status;
    char *namebuf = (char *)malloc(sizeof(char) * bufSize);
    NSAssert(namebuf != NULL, @"unable to allocate memory");
    status = listxattr(fsPath, namebuf, bufSize, xopts);
    
    if(status == -1){
        if(error) *error = [self xattrError:errno forPath:path];
        free(namebuf);
        return nil;
    }
    
    NSUInteger idx, start = 0;

    NSString *attribute = nil;
    NSMutableArray *attrs = [NSMutableArray array];
    
    // the names are separated by NULL characters
    for(idx = 0; idx < bufSize; idx++){
        if(namebuf[idx] != '\0') continue;
        attribute = [[NSString alloc] initWithBytes:&namebuf[start] length:(idx - start) encoding:NSUTF8StringEncoding];
        if(attribute != nil){
            // ignore fragments
            if(fragments || _namePrefix == nil || [attribute hasPrefix:_namePrefix] == NO || [attribute length] < [_namePrefix length] + MIN_EXTRA_NAME_LENGTH)
                [attrs addObject:attribute];
            attribute = nil;
        }
        start = idx + 1;
    }
    
    free(namebuf);
    return attrs;
}

- (NSArray *)extendedAttributeNamesAtPath:(NSString *)path traverseLink:(BOOL)follow error:(NSError **)error;
{
    return [self extendedAttributeNamesAtPath:path traverseLink:follow includeFragments:NO error:error];
}

- (NSDictionary *)allExtendedAttributesAtPath:(NSString *)path traverseLink:(BOOL)follow error:(NSError **)error;
{
    NSError *anError = nil;
    NSArray *attrNames = [self extendedAttributeNamesAtPath:path traverseLink:follow error:&anError];
    if(attrNames == nil){
        if(error) *error = anError;
        return nil;
    }
    
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:[attrNames count]];
    NSData *data = nil;
    
    for (NSString *attrName in attrNames){
        data = [self extendedAttributeNamed:attrName atPath:path traverseLink:follow error:&anError];
        if(data != nil){
            [attributes setObject:data forKey:attrName];
        } else {
            if(error) *error = anError;
            return nil;
        }
    }
    return attributes;
}

- (NSData *)copyRawExtendedAttributeNamed:(NSString *)attr atPath:(NSString *)path traverseLink:(BOOL)follow error:(NSError **)error;
{
    const char *fsPath = [path fileSystemRepresentation];
    const char *attrName = [attr UTF8String];
    
    int xopts;
    
    if(follow)
        xopts = 0;
    else
        xopts = XATTR_NOFOLLOW;
    
    size_t bufSize;
    ssize_t status;
    status = getxattr(fsPath, attrName, NULL, 0, 0, xopts);
    
    if(status == -1){
        if(error) *error = [self xattrError:errno forPath:path];
        return nil;
    }
    
    bufSize = status;
    char *namebuf = (char *)malloc(sizeof(char) * bufSize);
    NSAssert(namebuf != NULL, @"unable to allocate memory");
    status = getxattr(fsPath, attrName, namebuf, bufSize, 0, xopts);
    
    if(status == -1){
        if(error) *error = [self xattrError:errno forPath:path];
        free(namebuf);
        return nil;
    }
    
    // let NSData worry about freeing the buffer
    return [[NSData alloc] initWithBytesNoCopy:namebuf length:bufSize];
}

- (NSData *)extendedAttributeNamed:(NSString *)attr atPath:(NSString *)path traverseLink:(BOOL)follow error:(NSError **)error;
{
    NSError *err = nil;
    NSData *attribute = [self copyRawExtendedAttributeNamed:attr atPath:path traverseLink:follow error:&err];
    
    if (attribute == nil && [err code] == ENOATTR && [attr rangeOfString:SYNCABLE_SEPARATOR].location == NSNotFound) {
        NSString *sattr = [attr stringByAppendingString:SYNCABLE_FLAG];
        attribute = [self copyRawExtendedAttributeNamed:sattr atPath:path traverseLink:follow error:&err];
        if (attribute)
            attr = sattr;
        else if (error)
            *error = err;
    }
    
    if (_namePrefix && [self isPlistData:attribute]) {
        id plist = [NSPropertyListSerialization propertyListWithData:attribute options:NSPropertyListImmutable format:NULL error:NULL];
        
        // even if it's a plist, it may not be a dictionary or have the key we're looking for
        if (plist && [plist respondsToSelector:@selector(objectForKey:)] && [[plist objectForKey:_wrapperKey] boolValue]) {
            
            NSString *uniqueValue = [plist objectForKey:_uniqueKey];
            NSUInteger i, numberOfFragments = [[plist objectForKey:_fragmentsKey] unsignedIntegerValue];

            NSMutableData *buffer = [NSMutableData data];
            BOOL success = (nil != uniqueValue && numberOfFragments > 0);
            
            if (success == NO)
                NSLog(@"failed to read unique key %@ for %lu fragments from property list.", _uniqueKey, (long)numberOfFragments);
            
            NSUInteger j = [attr rangeOfString:SYNCABLE_SEPARATOR].location;
            NSString *suffix = j == NSNotFound || j == [attr length] - 1 ? @"" : [attr substringFromIndex:j];
            
            // reassemble the original data object
            for (i = 0; success && i < numberOfFragments; i++) {
                NSError *tmpError = nil;
                NSString *name = [[NSString alloc] initWithFormat:@"%@%@%lu%@", uniqueValue, FRAGMENT_NAME_SEPARATOR, (long)i, suffix];
                NSData *subdata = [self copyRawExtendedAttributeNamed:name atPath:path traverseLink:follow error:&tmpError];
                if (nil == subdata && i == 0 && [suffix length] > 0 && [tmpError code] == ENOATTR) {
                    NSString *oldName = [[NSString alloc] initWithFormat:@"%@%@%lu", uniqueValue, FRAGMENT_NAME_SEPARATOR, (long)i];
                    subdata = [self copyRawExtendedAttributeNamed:oldName atPath:path traverseLink:follow error:&tmpError];
                    if (subdata)
                        suffix = @"";
                }
                if (nil == subdata) {
                    NSLog(@"failed to find subattribute %@ of %lu for attribute named %@. %@", name, (long)numberOfFragments, attr, [tmpError localizedDescription]);
                    success = NO;
                } else {
                    [buffer appendData:subdata];
                }
            }
            
            attribute = success ? [self bunzipData:buffer] : nil;
            
            if (success == NO && NULL != error)
                *error = [NSError errorWithDomain:SKNSkimNotesErrorDomain code:SKNReassembleAttributeFailedError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:path, NSFilePathErrorKey, SKNLocalizedString(@"Failed to reassemble attribute value.", @"Error description"), NSLocalizedDescriptionKey, nil]];
            else if (attribute == nil && NULL != error)
                *error = [NSError errorWithDomain:SKNSkimNotesErrorDomain code:SKNInvalidDataError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:SKNLocalizedString(@"Invalid data.", @"Error description"), NSLocalizedDescriptionKey, nil]];

        }
    }
    return attribute;
}

- (id)propertyListFromExtendedAttributeNamed:(NSString *)attr atPath:(NSString *)path traverseLink:(BOOL)traverse error:(NSError **)error;
{
    NSError *anError = nil;
    NSData *data = [self extendedAttributeNamed:attr atPath:path traverseLink:traverse error:&anError];
    id plist = nil;
    if (nil == data) {
        if (error) *error = anError;
    } else {
        // decompress the data if necessary, we may have compressed when setting
        if ([self isBzipData:data]) 
            data = [self bunzipData:data];
        
        if (nil == data) {
            if (error) *error = [NSError errorWithDomain:SKNSkimNotesErrorDomain code:SKNInvalidDataError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:SKNLocalizedString(@"Invalid data.", @"Error description"), NSLocalizedDescriptionKey, nil]];

        } else {
            plist = [NSPropertyListSerialization propertyListWithData:data
                                                              options:NSPropertyListImmutable
                                                               format:NULL
                                                                error:&anError];
            if (nil == plist) {
                if (error) *error = [NSError errorWithDomain:SKNSkimNotesErrorDomain code:SKNPlistDeserializationFailedError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:path, NSFilePathErrorKey, [anError localizedDescription], NSLocalizedDescriptionKey, nil]];
            }
        }
    }
    return plist;
}

- (BOOL)setExtendedAttributeNamed:(NSString *)attr toValue:(NSData *)value atPath:(NSString *)path options:(SKNXattrFlags)options error:(NSError **)error;
{
    
    if((options & kSKNXattrSyncable) && NSFoundationVersionNumber >= NSFoundationVersionNumber10_10 && [attr rangeOfString:SYNCABLE_SEPARATOR].location == NSNotFound){
        attr = [attr stringByAppendingString:SYNCABLE_FLAG];
    }

    const char *fsPath = [path fileSystemRepresentation];
    const char *attrName = [attr UTF8String];
        
    // options passed to xattr functions
    int xopts = 0;
    if(options & kSKNXattrNoFollow)
        xopts = XATTR_NOFOLLOW;
    if(options & kSKNXattrCreateOnly)
        xopts |= XATTR_CREATE;
    if(options & kSKNXattrReplaceOnly)
        xopts |= XATTR_REPLACE;
    
    BOOL success;

    if ((options & kSKNXattrNoSplitData) == 0 && _namePrefix && [value length] > MAX_XATTR_LENGTH) {
                    
        // compress to save space, and so we don't identify this as a plist when reading it (in case it really is plist data)
        value = [self bzipData:value];
        
        // this will be a unique identifier for the set of keys we're about to write (appending a counter to the UUID)
        NSString *uniqueValue = [self uniqueName];
        NSUInteger numberOfFragments = ([value length] / MAX_XATTR_LENGTH) + ([value length] % MAX_XATTR_LENGTH ? 1 : 0);
        NSDictionary *wrapper = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], _wrapperKey, uniqueValue, _uniqueKey, [NSNumber numberWithUnsignedInteger:numberOfFragments], _fragmentsKey, nil];
        NSData *wrapperData = [NSPropertyListSerialization dataWithPropertyList:wrapper format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
        NSParameterAssert([wrapperData length] < MAX_XATTR_LENGTH && [wrapperData length] > 0);
        
        // we don't want to split this dictionary (or compress it)
        if (setxattr(fsPath, attrName, [wrapperData bytes], [wrapperData length], 0, xopts))
            success = NO;
        else
            success = YES;
        
        // now split the original data value into multiple segments
        NSString *name;
        NSUInteger i;
        const char *valuePtr = [value bytes];
        
        NSUInteger j = [attr rangeOfString:SYNCABLE_SEPARATOR].location;
        NSString *suffix = j == NSNotFound || j == [attr length] - 1 ? @"" : [attr substringFromIndex:j];
        
        for (i = 0; success && i < numberOfFragments; i++) {
            name = [[NSString alloc] initWithFormat:@"%@%@%lu%@", uniqueValue, FRAGMENT_NAME_SEPARATOR, (long)i, suffix];
            
            char *subdataPtr = (char *)&valuePtr[i * MAX_XATTR_LENGTH];
            size_t subdataLen = i == numberOfFragments - 1 ? ([value length] - i * MAX_XATTR_LENGTH) : MAX_XATTR_LENGTH;
            
            // could recurse here, but it's more efficient to use the variables we already have
            if (setxattr(fsPath, [name UTF8String], subdataPtr, subdataLen, 0, xopts)) {
                NSLog(@"full data length of note named %@ was %lu, subdata length was %lu (failed on pass %lu)", name, (long)[value length], (long)subdataLen, (long)i);
            }
        }
        
    } else {
        int status = setxattr(fsPath, attrName, [value bytes], [value length], 0, xopts);
        if(status == -1){
            if(error) *error = [self xattrError:errno forPath:path];
            success = NO;
        } else {
            success = YES;
        }
    }
    return success;
}

- (BOOL)setExtendedAttributeNamed:(NSString *)attr toPropertyListValue:(id)plist atPath:(NSString *)path options:(SKNXattrFlags)options error:(NSError **)error;
{
    NSError *anError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:&anError];
    BOOL success;
    if (nil == data) {
        if (error) *error = [NSError errorWithDomain:SKNSkimNotesErrorDomain code:SKNPlistSerializationFailedError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:path, NSFilePathErrorKey, [anError localizedDescription], NSLocalizedDescriptionKey, nil]];
        success = NO;
    } else {
        // if we don't split and the data is too long, compress the data using bzip to save space
        if (((options & kSKNXattrNoSplitData) != 0 || _namePrefix == nil) && (options & kSKNXattrNoCompress) == 0 && [data length] > MAX_XATTR_LENGTH)
            data = [self bzipData:data];
        
        success = [self setExtendedAttributeNamed:attr toValue:data atPath:path options:options error:error];
    }
    return success;
}

- (BOOL)removeExtendedAttributeNamed:(NSString *)attr atPath:(NSString *)path traverseLink:(BOOL)follow error:(NSError **)error;
{
    NSParameterAssert(path != nil);
    const char *fsPath = [path fileSystemRepresentation];
    const char *attrName = [attr UTF8String];
    
    int xopts;
    
    if(follow)
        xopts = 0;
    else
        xopts = XATTR_NOFOLLOW;
    
    size_t bufSize;
    ssize_t status;
    status = getxattr(fsPath, attrName, NULL, 0, 0, xopts);
    
    if (status == -1 && errno == ENOATTR && [attr rangeOfString:SYNCABLE_SEPARATOR].location == NSNotFound){
        NSString *sattr = [attr stringByAppendingString:SYNCABLE_FLAG];
        const char *sattrName = [sattr UTF8String];
        status = getxattr(fsPath, sattrName, NULL, 0, 0, xopts);
        if (status != -1){
            attr = sattr;
            attrName = sattrName;
        }
    }

    if(status != -1){
        bufSize = status;
        char *namebuf = (char *)malloc(sizeof(char) * bufSize);
        NSAssert(namebuf != NULL, @"unable to allocate memory");
        status = getxattr(fsPath, attrName, namebuf, bufSize, 0, xopts);
        
        if(status == -1){
            
            free(namebuf);
            
        } else {
            
            // let NSData worry about freeing the buffer
            NSData *attribute = [[NSData alloc] initWithBytesNoCopy:namebuf length:bufSize];
            
            id plist = nil;
            
            if (_namePrefix && [self isPlistData:attribute])
                plist = [NSPropertyListSerialization propertyListWithData:attribute options:NSPropertyListImmutable format:NULL error:NULL];
            
            // even if it's a plist, it may not be a dictionary or have the key we're looking for
            if (plist && [plist respondsToSelector:@selector(objectForKey:)] && [[plist objectForKey:_wrapperKey] boolValue]) {
                
                NSString *uniqueValue = [plist objectForKey:_uniqueKey];
                NSUInteger i, numberOfFragments = [[plist objectForKey:_fragmentsKey] unsignedIntegerValue];
                NSString *name;
                
                NSUInteger j = [attr rangeOfString:SYNCABLE_SEPARATOR].location;
                NSString *suffix = j == NSNotFound || j == [attr length] - 1 ? @"" : [attr substringFromIndex:j];
                
                // remove the sub attributes
                for (i = 0; i < numberOfFragments; i++) {
                    name = [[NSString alloc] initWithFormat:@"%@%@%lu%@", uniqueValue, FRAGMENT_NAME_SEPARATOR, (long)i, suffix];
                    const char *subAttrName = [name UTF8String];
                    status = removexattr(fsPath, subAttrName, xopts);
                    if (status == -1 && i == 0 && errno == ENOATTR && [suffix length] > 0) {
                        NSString *oldName = [[NSString alloc] initWithFormat:@"%@%@%lu", uniqueValue, FRAGMENT_NAME_SEPARATOR, (long)i];
                        subAttrName = [oldName UTF8String];
                        status = removexattr(fsPath, subAttrName, xopts);
                        if (status != -1)
                            suffix = @"";
                    }
                    if (status == -1) {
                        NSLog(@"failed to remove subattribute %@ of attribute named %@", name, attr);
                    }
                }
            }
        }
    }
    
    status = removexattr(fsPath, attrName, xopts);
    
    if(status == -1){
        if(error) *error = [self xattrError:errno forPath:path];
        return NO;
    } else {
        if ([attr rangeOfString:SYNCABLE_SEPARATOR].location == NSNotFound){
            attr = [attr stringByAppendingString:SYNCABLE_FLAG];
            [self removeExtendedAttributeNamed:attr atPath:path traverseLink:follow error:NULL];
        }
        return YES;
    }
}

- (BOOL)removeAllExtendedAttributesAtPath:(NSString *)path traverseLink:(BOOL)follow error:(NSError **)error;
{
    NSArray *allAttributes = [self extendedAttributeNamesAtPath:path traverseLink:follow includeFragments:YES error:error];
    if  (nil == allAttributes)
        return NO;
    
    const char *fsPath = [path fileSystemRepresentation];
    ssize_t status;
    int xopts;
    
    if(follow)
        xopts = 0;
    else
        xopts = XATTR_NOFOLLOW;
    
    for (NSString *attrName in allAttributes) {
        
        status = removexattr(fsPath, [attrName UTF8String], xopts);
        
        // return NO as soon as any single removal fails
        if (status == -1){
            if(error) *error = [self xattrError:errno forPath:path];
            return NO;
        }
    }
    return YES;
}

- (NSString *)uniqueName;
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuidString = CFUUIDCreateString(NULL, uuid);
    NSString *uniqueName = [_namePrefix stringByAppendingString:(__bridge NSString *)uuidString];
    CFRelease(uuid);
    CFRelease(uuidString);
    return uniqueName;
}

// guaranteed to return non-nil
- (NSError *)xattrError:(NSInteger)err forPath:(NSString *)path;
{
    NSString *errMsg = nil;
    switch (err)
    {
        case ENOTSUP:
            errMsg = SKNLocalizedString(@"File system does not support extended attributes or they are disabled.", @"Error description");
            break;
        case ERANGE:
            errMsg = SKNLocalizedString(@"Buffer too small for attribute names.", @"Error description");
            break;
        case EPERM:
            errMsg = SKNLocalizedString(@"This file system object does not support extended attributes.", @"Error description");
            break;
        case ENOTDIR:
            errMsg = SKNLocalizedString(@"A component of the path is not a directory.", @"Error description");
            break;
        case ENAMETOOLONG:
            errMsg = SKNLocalizedString(@"File name too long.", @"Error description");
            break;
        case EACCES:
            errMsg = SKNLocalizedString(@"Search permission denied for this path.", @"Error description");
            break;
        case ELOOP:
            errMsg = SKNLocalizedString(@"Too many symlinks encountered resolving path.", @"Error description");
            break;
        case EIO:
            errMsg = SKNLocalizedString(@"I/O error occurred.", @"Error description");
            break;
        case EINVAL:
            errMsg = SKNLocalizedString(@"Options not recognized.", @"Error description");
            break;
        case EEXIST:
            errMsg = SKNLocalizedString(@"Options contained XATTR_CREATE but the named attribute exists.", @"Error description");
            break;
        case ENOATTR:
            errMsg = SKNLocalizedString(@"The named attribute does not exist.", @"Error description");
            break;
        case EROFS:
            errMsg = SKNLocalizedString(@"Read-only file system.  Unable to change attributes.", @"Error description");
            break;
        case EFAULT:
            errMsg = SKNLocalizedString(@"Path or name points to an invalid address.", @"Error description");
            break;
        case E2BIG:
            errMsg = SKNLocalizedString(@"The data size of the extended attribute is too large.", @"Error description");
            break;
        case ENOSPC:
            errMsg = SKNLocalizedString(@"No space left on file system.", @"Error description");
            break;
        default:
            errMsg = SKNLocalizedString(@"Unknown error occurred.", @"Error description");
            break;
    }
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:[NSDictionary dictionaryWithObjectsAndKeys:path, NSFilePathErrorKey, errMsg, NSLocalizedDescriptionKey, nil]];
}

// 
// implementation modified after http://www.cocoadev.com/index.pl?NSDataPlusBzip (removed exceptions)
//

#define BZIP_BUFFER_SIZE 16 * 1024

- (NSData *)bzipData:(NSData *)data;
{
    int compression = 5;
    int bzret;
    bz_stream stream = { 0 };
    stream.next_in = (char *)[data bytes];
    stream.avail_in = (unsigned int)[data length];
    
    NSMutableData *buffer = [[NSMutableData alloc] initWithLength:BZIP_BUFFER_SIZE];
    stream.next_out = [buffer mutableBytes];
    stream.avail_out = BZIP_BUFFER_SIZE;
    
    NSMutableData *compressed = [NSMutableData dataWithCapacity:[data length]];
    
    BZ2_bzCompressInit(&stream, compression, 0, 0);
    BOOL hadError = NO;
    do {
        bzret = BZ2_bzCompress(&stream, (stream.avail_in) ? BZ_RUN : BZ_FINISH);
        if (bzret < BZ_OK) {
            hadError = YES;
            compressed = nil;
        } else {
            [compressed appendBytes:[buffer bytes] length:(BZIP_BUFFER_SIZE - stream.avail_out)];
            stream.next_out = [buffer mutableBytes];
            stream.avail_out = BZIP_BUFFER_SIZE;
        }
    } while(bzret != BZ_STREAM_END && NO == hadError);
    
    BZ2_bzCompressEnd(&stream);
    
    return compressed;
}

- (NSData *)bunzipData:(NSData *)data;
{
    int bzret;
    bz_stream stream = { 0 };
    stream.next_in = (char *)[data bytes];
    stream.avail_in = (unsigned int)[data length];
    
    NSMutableData *buffer = [[NSMutableData alloc] initWithLength:BZIP_BUFFER_SIZE];
    stream.next_out = [buffer mutableBytes];
    stream.avail_out = BZIP_BUFFER_SIZE;
    
    NSMutableData *decompressed = [NSMutableData dataWithCapacity:[data length]];
    
    BZ2_bzDecompressInit(&stream, 0, NO);
    BOOL hadError = NO;
    NSInteger hangCount = 0;
    const NSInteger maxHangCount = 100;
    do {
        bzret = BZ2_bzDecompress(&stream);
        if (bzret < BZ_OK || (BZIP_BUFFER_SIZE == stream.avail_out && ++hangCount > maxHangCount)) {
            hadError = YES;
            decompressed = nil;
        } else {
            [decompressed appendBytes:[buffer bytes] length:(BZIP_BUFFER_SIZE - stream.avail_out)];
            stream.next_out = [buffer mutableBytes];
            stream.avail_out = BZIP_BUFFER_SIZE;
        }
    } while(bzret != BZ_STREAM_END && NO == hadError);
    
    BZ2_bzDecompressEnd(&stream);
    
    return decompressed;
}

- (BOOL)isBzipData:(NSData *)data;
{
    static NSData *bzipHeaderData = nil;
    static NSUInteger bzipHeaderDataLength = 0;
    if (nil == bzipHeaderData) {
        char *h = "BZh";
        bzipHeaderData = [[NSData alloc] initWithBytes:h length:strlen(h)];
        bzipHeaderDataLength = [bzipHeaderData length];
    }

    return [data length] >= bzipHeaderDataLength && [bzipHeaderData isEqual:[data subdataWithRange:NSMakeRange(0, bzipHeaderDataLength)]];
}

- (BOOL)isPlistData:(NSData *)data;
{
    static NSData *plistHeaderData = nil;
    static NSUInteger plistHeaderDataLength = 0;
    if (nil == plistHeaderData) {
        char *h = "bplist00";
        plistHeaderData = [[NSData alloc] initWithBytes:h length:strlen(h)];
        plistHeaderDataLength = [plistHeaderData length];
    }

    return [data length] >= plistHeaderDataLength && [plistHeaderData isEqual:[data subdataWithRange:NSMakeRange(0, plistHeaderDataLength)]];
}

@end
