//
//  SoapURLConnection.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/5/10.
//  Copyright 2010 . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SoapURLConnection : NSURLConnection {
@private
    NSURLResponse *response;
    NSMutableData *data;
    BOOL finished;
}

@property (nonatomic, assign, getter=isFinished) BOOL finished;
@property (nonatomic, retain) NSURLResponse *response;

- (NSData *) data;
- (void) appendData:(NSData *)value;

@end
