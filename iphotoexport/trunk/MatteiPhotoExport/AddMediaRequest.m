//
//  AddMediaRequest.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/5/10.
//  Copyright 2010 . All rights reserved.
//

#import "AddMediaRequest.h"

#import "CollectionExport.h"

@implementation AddMediaRequest

@synthesize collectionId, mediaCount, mediaFile, metadata;

- (id) init {
	if ( (self = [super init]) ) {
		mediaCount = 0;
		collectionId = -1;
		self.action = @"http://msqr.us/matte/ws/AddMedia";
	}
	return self;
}

- (void) dealloc {
	self.mediaFile = nil;
	self.metadata = nil;
	[super dealloc];
}

- (NSXMLElement *) createMessage {
	NSXMLNode *nsMatte = [NSXMLNode namespaceWithName:@"" stringValue:@"http://msqr.us/xsd/matte"];
	NSXMLNode *nsXmime = [NSXMLNode namespaceWithName:@"xmime" stringValue:@"http://www.w3.org/2005/05/xmlmime"];
    NSXMLElement *addMediaMessage = [NSXMLElement elementWithName:@"AddMediaRequest" URI:[nsMatte stringValue]];
	[addMediaMessage addNamespace:nsMatte];
	[addMediaMessage addNamespace:nsXmime];
	[addMediaMessage addAttribute:[NSXMLNode attributeWithName:@"collection-id" 
												   stringValue:[NSString stringWithFormat:@"%d", collectionId]]];
	
	// add collection import
	NSXMLElement *importElem = [metadata asXml];
	[importElem removeNamespaceForPrefix:@""];
	[addMediaMessage addChild:importElem];
	
	// add media data
	[addMediaMessage addChild:[NSXMLNode commentWithStringValue:[NSString stringWithFormat:
																 @" Archive %@ with %d items and metadata.xml ",
																 [mediaFile lastPathComponent],
																 mediaCount]]];
	NSData *mediaData = [NSData dataWithContentsOfFile:mediaFile];
	NSXMLElement *mediaElement = [NSXMLElement elementWithName:@"media-data" URI:[nsMatte stringValue]];
	
	// we are assuming zip data at this point
	NSXMLNode *mimeAttr = [NSXMLNode attributeWithName:@"xmime:contentType" 
												   URI:[nsXmime stringValue] 
										   stringValue:@"application/zip"];
	[mediaElement addAttribute:mimeAttr];
	[mediaElement setObjectValue:mediaData];
	[addMediaMessage addChild:mediaElement];
	return addMediaMessage;
	
}

- (NSXMLDocument *) asXml {
	if ( self.message == nil ) {
		self.message = [self createMessage];
	}
	return [super asXml];
}

@end
