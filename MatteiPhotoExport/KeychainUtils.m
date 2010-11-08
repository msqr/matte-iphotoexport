//
//  KeychainUtils.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/8/10.
//  Copyright 2010 . All rights reserved.
//

#import "KeychainUtils.h"

#include <Security/Security.h>
#include <CoreServices/CoreServices.h>

static char * const kServiceName = "MatteiPhotoExport";
static int const kServiceNameLength = 17;

@implementation KeychainUtils

+ (NSString *) passwordForURL:(NSURL *)url username:(NSString *)username {
	OSStatus status;
	url = [url standardizedURL];
	UInt32 passwordLength = 0;
	void *passwordData = nil;
	const char *user = [username UTF8String];
	NSString *result = nil;
	status = SecKeychainFindInternetPassword(NULL,
											 strlen([[url host] UTF8String]), 
											 [[url host] UTF8String], 
											 0,
											 NULL, 
											 strlen(user),
											 user, 
											 strlen([[url path] UTF8String]), 
											 [[url path] UTF8String], 
											 [[url port] unsignedIntValue], 
											 ([[url scheme] caseInsensitiveCompare:@"https"] == NSOrderedSame ? kSecProtocolTypeHTTPS : kSecProtocolTypeHTTP),
											 kSecAuthenticationTypeDefault,
											 &passwordLength,
											 &passwordData,
											 NULL);
	if ( status == noErr ) {
		if ( passwordLength > 1024 ) {
			passwordLength = 1024;
		}
		char pwd[passwordLength];
		strncpy(pwd, passwordData, passwordLength);
		pwd[passwordLength] = '\0';
		result = [NSString stringWithCString:pwd encoding:NSUTF8StringEncoding];
	} else if ( status == errSecItemNotFound ) {
		// not found, this is not an error
	} else {
		NSLog(@"Error looking up password in keychain: %d", status);
	}
	// free password memory allocated by SecKeychainFindGenericPassword
	SecKeychainItemFreeContent(NULL, passwordData);
	return result;
}

+ (void) storePassword:(NSString *)password forURL:(NSURL *)url username:(NSString *)username {
	url = [url standardizedURL];
	OSStatus status;
	const char *pwd = [password UTF8String];
	const char *user = [username UTF8String];
	SecKeychainItemRef itemRef = nil;
	status = SecKeychainFindInternetPassword(NULL,
											 strlen([[url host] UTF8String]), 
											 [[url host] UTF8String], 
											 0,
											 NULL, 
											 strlen(user),
											 user, 
											 strlen([[url path] UTF8String]), 
											 [[url path] UTF8String], 
											 [[url port] unsignedIntValue], 
											 ([[url scheme] caseInsensitiveCompare:@"https"] == NSOrderedSame ? kSecProtocolTypeHTTPS : kSecProtocolTypeHTTP),
											 kSecAuthenticationTypeDefault,
											 NULL,
											 NULL,
											 &itemRef);
	if ( status == errSecItemNotFound ) {
		status = SecKeychainAddInternetPassword(NULL, 
												strlen([[url host] UTF8String]), 
												[[url host] UTF8String], 
												0,
												NULL, 
												strlen(user),
												user,
												strlen([[url path] UTF8String]), 
												[[url path] UTF8String], 
												[[url port] unsignedIntValue], 
												([[url scheme] caseInsensitiveCompare:@"https"] == NSOrderedSame ? kSecProtocolTypeHTTPS : kSecProtocolTypeHTTP),
												kSecAuthenticationTypeDefault,
												strlen(pwd),
												pwd,
												NULL);
	} else if ( itemRef != nil ) {
		// modify existing password
		status = SecKeychainItemModifyAttributesAndData(itemRef,
														NULL,
														strlen(pwd),
														pwd);
	}
	if ( itemRef != nil ) {
		CFRelease(itemRef);
	}
}

@end
