//
//  AddMediaRequest.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/5/10.
//  Copyright 2010 . All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SoapMessage.h"

extern NSString * const kFileDataPlaceholder;

@class CollectionExport;

@interface AddMediaRequest : SoapMessage {
	NSString *mediaFile;
	int mediaCount;
	int collectionId;
	CollectionExport *metadata;
}

@property (nonatomic, assign) int collectionId;
@property (nonatomic, assign) int mediaCount;
@property (nonatomic, retain) NSString *mediaFile;
@property (nonatomic, retain) CollectionExport *metadata;

@end
