//
//  NSFileManager+Utilities.h
//  MatteiPhotoExport
//
//  Created by Matt on 3/7/11.
//  Copyright 2011 . All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSFileManager (Utilities) 

+ (unsigned long long) sizeOfFileAtPath:(NSString *)filePath;

@end
