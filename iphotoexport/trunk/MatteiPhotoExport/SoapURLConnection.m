//
//  SoapURLConnection.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/5/10.
//  Copyright 2010 . All rights reserved.
//

#import "SoapURLConnection.h"

@implementation SoapURLConnection

@synthesize finished, response;

- (void) dealloc {
	self.response = nil;
    [data release], data = nil;
    [super dealloc];
}

- (NSData *) data {
    return data;
}

- (void) appendData:(NSData *)value {
    if ( !data ) {
        data = [[NSMutableData alloc] init];
    }
    [data appendData:value];
}

@end
