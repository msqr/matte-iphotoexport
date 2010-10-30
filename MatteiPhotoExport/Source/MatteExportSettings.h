//
//  MatteExportSettings.h
//  MatteiPhotoExport
//
//  Created by Matt on 10/30/10.
//  Copyright 2010 . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MatteExportSettings : NSObject {
@private
	int collectionId;
	NSString *url;
	NSString *username;
	NSString *password;
	
	// image options
	BOOL exportOriginals;
	BOOL autoAlbum;	
	int size;
	int quality;

	// movie options
	BOOL exportOriginalMovies;
	NSUInteger selectedComponentIndex;
	NSData *exportMovieSettings;
}

@property (assign) int collectionId;
@property (assign) int size;
@property (assign) int quality;
@property (retain) NSString *url;
@property (retain) NSString *username;
@property (retain) NSString *password;
@property (assign,getter=isExportOriginals) BOOL exportOriginals;
@property (assign,getter=isAutoAlbum) BOOL autoAlbum;

@property (assign,getter=isExportOriginalMovies) BOOL exportOriginalMovies;
@property (assign) NSUInteger selectedComponentIndex;
@property (retain) NSData *exportMovieSettings;

@end
