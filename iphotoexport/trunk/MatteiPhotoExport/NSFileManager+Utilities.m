//
//  NSFileManager+Utilities.m
//  MatteiPhotoExport
//
//  Created by Matt on 3/7/11.
//  Copyright 2011 . All rights reserved.
//

#import "NSFileManager+Utilities.h"

@implementation NSFileManager (Utilities)

+ (unsigned long long) sizeOfFileAtPath:(NSString *)filePath {
	NSFileManager *fileManager = [[NSFileManager alloc] init];
	NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:nil];
	unsigned long long inputLength = [fileAttributes[NSFileSize] unsignedLongLongValue];
	[fileManager release], fileManager = nil;
	return inputLength;
}

@end
