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
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    NSData *passwordData = nil;
    NSString *password = nil;
    
    [query setObject:(NSString *)kSecClassGenericPassword forKey:(NSString *)kSecClass];
    [query setObject:(NSString *)kSecMatchLimitOne forKey:(NSString *)kSecMatchLimit];
    if (service)
        [query setObject:service forKey:(NSString *)kSecAttrService];
    if (account)
        [query setObject:account forKey:(NSString *)kSecAttrAccount];
    [query setObject:@YES forKey:(NSString *)kSecReturnData];
    
    OSStatus err = SecItemCopyMatching((CFDictionaryRef)query, password ? (CFTypeRef *)&passwordData : NULL);
    
    if (err == noErr) {
        if (passwordData) {
            password = [[[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding] autorelease];
            [passwordData release];
        }
        if (status) *status = SKPasswordStatusFound;
    } else if (err == errSecItemNotFound) {
        if (status) *status = SKPasswordStatusNotFound;
    } else {
        if (err != errSecUserCanceled)
            NSLog(@"Error %d occurred finding password: %@", (int)err, [(id)SecCopyErrorMessageString(err, NULL) autorelease]);
        if (status) *status = SKPasswordStatusError;
    }
    return password;
}

+ (void)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account label:(NSString *)label comment:(NSString *)comment {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    OSStatus err;
    
    // password not on keychain, so add it
    [attributes setObject:service forKey:(NSString *)kSecAttrService];
    [attributes setObject:account forKey:(NSString *)kSecAttrAccount];
    [attributes setObject:(NSString *)kSecClassGenericPassword forKey:(NSString *)kSecClass];
    if (label)
        [attributes setObject:label forKey:(NSString *)kSecAttrLabel];
    if (comment)
        [attributes setObject:comment forKey:(NSString *)kSecAttrComment];
    if (password)
        [attributes setObject:[password dataUsingEncoding:NSUTF8StringEncoding] forKey:(NSString *)kSecValueData];
    
    err = SecItemAdd((CFDictionaryRef)attributes, NULL);
    if (err != noErr && err != errSecUserCanceled)
        NSLog(@"Error %d occurred adding password: %@", (int)err, [(id)SecCopyErrorMessageString(err, NULL) autorelease]);
}

+ (SKPasswordStatus)updatePassword:(NSString *)password service:(NSString *)service account:(NSString *)account label:(NSString *)label comment:(NSString *)comment forService:(NSString *)itemService account:(NSString *)itemAccount {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    OSStatus err;
    
    [query setObject:(NSString *)kSecClassGenericPassword forKey:(NSString *)kSecClass];
    [query setObject:(NSString *)kSecMatchLimitOne forKey:(NSString *)kSecMatchLimit];
    if (itemService)
        [query setObject:itemService forKey:(NSString *)kSecAttrService];
    if (itemAccount)
        [query setObject:itemAccount forKey:(NSString *)kSecAttrAccount];
    
    if (service && [service isEqualToString:itemService] == NO)
        [attributes setObject:service forKey:(NSString *)kSecAttrService];
    if (account && [account isEqualToString:itemAccount] == NO)
        [attributes setObject:account forKey:(NSString *)kSecAttrAccount];
    if (label)
        [attributes setObject:label forKey:(NSString *)kSecAttrLabel];
    if (comment)
        [attributes setObject:comment forKey:(NSString *)kSecAttrComment];
    if (password)
        [attributes setObject:[password dataUsingEncoding:NSUTF8StringEncoding] forKey:(NSString *)kSecValueData];
    
    // password was on keychain, so modify the keychain
    err = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)attributes);
    if (err == noErr) {
        return SKPasswordStatusFound;
    } else if (err == errSecItemNotFound) {
        return SKPasswordStatusNotFound;
    } else {
        if (err != errSecUserCanceled)
            NSLog(@"Error %d occurred modifying password or attributes: %@", (int)err, [(id)SecCopyErrorMessageString(err, NULL) autorelease]);
        return SKPasswordStatusError;
    }
}

@end
