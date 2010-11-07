//
//  GetCollectionListRequest.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/7/10.
//  Copyright 2010 . All rights reserved.
//

#import "GetCollectionListRequest.h"

@implementation GetCollectionListRequest

- (id) init {
	if ( (self = [super init]) ) {
		self.action = @"http://msqr.us/matte/ws/GetCollectionList";
	}
	return self;
}

- (NSXMLElement *) createMessage {
	NSXMLNode *nsMatte = [NSXMLNode namespaceWithName:@"" stringValue:@"http://msqr.us/xsd/matte"];
    NSXMLElement *getColListMessage = [NSXMLElement elementWithName:@"GetCollectionListRequest" URI:[nsMatte stringValue]];
	[getColListMessage addNamespace:nsMatte];
	return getColListMessage;
	
}

- (NSXMLDocument *) asXml {
	if ( self.message == nil ) {
		self.message = [self createMessage];
	}
	return [super asXml];
}

@end
