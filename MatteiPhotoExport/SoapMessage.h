//
//  SoapMessage.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/5/10.
//  Copyright 2010 . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SoapMessage : NSObject {
	NSString *username;
	NSString *password;
	NSXMLNode *message;
	NSString *action;
}

@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSString *action;
@property (nonatomic, retain) NSXMLNode *message;

- (NSXMLDocument *) asXml;
- (NSData *) asData;
- (NSInputStream *) asStream;
- (NSUInteger) streamLength;

@end
