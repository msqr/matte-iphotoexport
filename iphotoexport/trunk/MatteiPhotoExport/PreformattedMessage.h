//
//  PreformattedMessage.h
//  MatteiPhotoExport
//
//  Created by Matt on 3/7/11.
//  Copyright 2011 . All rights reserved.
//

#import "SoapMessage.h"

@interface PreformattedMessage : SoapMessage {
	NSString *filePath;
	NSInputStream *stream;
	NSUInteger streamLength;
}

- (id) initWithSoapMessage:(SoapMessage *)theMessage withContentsOfFile:(NSString *)theFile;
- (id) initWithSoapMessage:(SoapMessage *)theMessage
		   withInputStream:(NSInputStream *)theStream
			  streamLength:(NSUInteger)theStreamLength;

@end
