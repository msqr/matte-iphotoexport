//
//  PreformattedMessage.m
//  MatteiPhotoExport
//
//  Created by Matt on 3/7/11.
//  Copyright 2011 . All rights reserved.
//

#import "PreformattedMessage.h"

@implementation PreformattedMessage

- (id) initWithSoapMessage:(SoapMessage *)theMessage withContentsOfFile:(NSString *)theFile {
	if ( (self = [super init]) ) {
		self.username = theMessage.username;
		self.password = theMessage.password;
		self.action = theMessage.action;
		filePath = [theFile retain];
		streamLength = [NSFileManager sizeOfFileAtPath:theFile];
	}
	return self;
}

- (id) initWithSoapMessage:(SoapMessage *)theMessage
		   withInputStream:(NSInputStream *)theStream
			  streamLength:(NSUInteger)theStreamLength {
	if ( (self = [super init]) ) {
		self.username = theMessage.username;
		self.password = theMessage.password;
		self.action = theMessage.action;
		stream = [theStream retain];
		streamLength = theStreamLength;
	}
	return self;
}

- (void) dealloc {
	[filePath release], filePath = nil;
	[stream release], stream = nil;
	[super dealloc];
}

- (NSData *) asData {
	return nil;
}

- (NSXMLDocument *) asXml {
	return nil;
}

- (NSInputStream *) asStream {
	return (stream != nil ? stream : [NSInputStream inputStreamWithFileAtPath:filePath]);
}

- (NSUInteger) streamLength {
	return streamLength;
}

@end
