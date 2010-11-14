//
//  SoapURLConnection.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/5/10.
//  Copyright 2010 . All rights reserved.
//

#import <Foundation/Foundation.h>

@class SoapMessage;

@interface SoapURLConnection : NSURLConnection {
@private
    NSURLResponse *response;
    NSMutableData *data;
    BOOL finished;
	BOOL updateProgress;
}

@property (nonatomic, assign, getter=isFinished) BOOL finished;
@property (nonatomic, assign, getter=isUpdateProgress) BOOL updateProgress;
@property (nonatomic, retain) NSURLResponse *response;

+ (NSXMLDocument *) request:(NSURL *)url 
					message:(SoapMessage *)message 
				   delegate:(id)delegate
			 updateProgress:(BOOL)shouldUpdateProgress;

+ (NSString *) faultString:(NSXMLDocument *)soapResponse error:(NSError **)error;

- (NSData *) data;
- (void) appendData:(NSData *)value;

@end
