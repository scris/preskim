//
//  SKKeychain.m
//  Skim
//
//  Created by Christiaan on 29/01/2018.
/*
 This software is Copyright (c) 2019-2023
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

#import "SKKeychain.h"
#import <Security/Security.h>


@implementation SKKeychain

+ (NSString *)passwordForService:(NSString *)service account:(NSString *)account status:(SKPasswordStatus *)status {
    CFMutableDictionaryRef query = CFDictionaryCreateMutable(NULL, 5, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFTypeRef passwordData = nil;
    NSString *password = nil;
    
    CFDictionarySetValue(query, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(query, kSecMatchLimit, kSecMatchLimitOne);
    if (service)
        CFDictionarySetValue(query, kSecAttrService, (__bridge CFStringRef)service);
    if (account)
        CFDictionarySetValue(query, kSecAttrAccount, (__bridge CFStringRef)account);
    CFDictionarySetValue(query, kSecReturnData, kCFBooleanTrue);
    
    OSStatus err = SecItemCopyMatching(query, &passwordData);
    CFRelease(query);
    
    if (err == noErr) {
        if (passwordData)
            password = [[NSString alloc] initWithData:CFBridgingRelease(passwordData) encoding:NSUTF8StringEncoding];
        if (status) *status = SKPasswordStatusFound;
    } else if (err == errSecItemNotFound) {
        if (status) *status = SKPasswordStatusNotFound;
    } else {
        if (err != errSecUserCanceled)
            NSLog(@"Error %d occurred finding password: %@", (int)err, CFBridgingRelease(SecCopyErrorMessageString(err, NULL)));
        if (status) *status = SKPasswordStatusError;
    }
    return password;
}

+ (void)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account label:(NSString *)label comment:(NSString *)comment {
    CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(NULL, 6, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    OSStatus err;
    
    // password not on keychain, so add it
    CFDictionarySetValue(attributes, kSecAttrService, (__bridge CFStringRef)service);
    CFDictionarySetValue(attributes, kSecAttrAccount, (__bridge CFStringRef)account);
    CFDictionarySetValue(attributes, kSecClass, kSecClassGenericPassword);
    if (label)
        CFDictionarySetValue(attributes, kSecAttrLabel, (__bridge CFStringRef)label);
    if (comment)
        CFDictionarySetValue(attributes, kSecAttrComment, (__bridge CFStringRef)comment);
    if (password)
        CFDictionarySetValue(attributes, kSecValueData, (__bridge CFDataRef)[password dataUsingEncoding:NSUTF8StringEncoding]);
    
    err = SecItemAdd(attributes, NULL);
    CFRelease(attributes);
    
    if (err != noErr && err != errSecUserCanceled)
        NSLog(@"Error %d occurred adding password: %@", (int)err, CFBridgingRelease(SecCopyErrorMessageString(err, NULL)));
}

+ (SKPasswordStatus)updatePassword:(NSString *)password service:(NSString *)service account:(NSString *)account label:(NSString *)label comment:(NSString *)comment forService:(NSString *)itemService account:(NSString *)itemAccount {
    CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(NULL, 5, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef query = CFDictionaryCreateMutable(NULL, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    OSStatus err;
    
    CFDictionarySetValue(query, kSecClass, kSecClassGenericPassword);
    CFDictionarySetValue(query, kSecMatchLimit, kSecMatchLimitOne);
    if (itemService)
        CFDictionarySetValue(query, kSecAttrService, (__bridge CFStringRef)itemService);
    if (itemAccount)
        CFDictionarySetValue(query, kSecAttrAccount, (__bridge CFStringRef)itemAccount);
    
    if (service && [service isEqualToString:itemService] == NO)
        CFDictionarySetValue(attributes, kSecAttrService, (__bridge CFStringRef)service);
    if (account && [account isEqualToString:itemAccount] == NO)
        CFDictionarySetValue(attributes, kSecAttrAccount, (__bridge CFStringRef)account);
    if (label)
        CFDictionarySetValue(attributes, kSecAttrLabel, (__bridge CFStringRef)label);
    if (comment)
        CFDictionarySetValue(attributes, kSecAttrComment, (__bridge CFStringRef)comment);
    if (password)
        CFDictionarySetValue(attributes, kSecValueData, (__bridge CFDataRef)[password dataUsingEncoding:NSUTF8StringEncoding]);
    
    // password was on keychain, so modify the keychain
    err = SecItemUpdate(query, attributes);
    CFRelease(query);
    CFRelease(attributes);
    
    if (err == noErr) {
        return SKPasswordStatusFound;
    } else if (err == errSecItemNotFound) {
        return SKPasswordStatusNotFound;
    } else {
        if (err != errSecUserCanceled)
            NSLog(@"Error %d occurred modifying password or attributes: %@", (int)err, CFBridgingRelease(SecCopyErrorMessageString(err, NULL)));
        return SKPasswordStatusError;
    }
}

@end
