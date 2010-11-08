//
//  KeychainUtils.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/8/10.
//  Copyright 2010 . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeychainUtils : NSObject {

}

+ (NSString *) passwordForURL:(NSURL *)url username:(NSString *)username;
+ (void) storePassword:(NSString *)password forURL:(NSURL *)url username:(NSString *)username;

@end
