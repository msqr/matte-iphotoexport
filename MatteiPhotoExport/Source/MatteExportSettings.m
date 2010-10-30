//
//  MatteExportSettings.m
//  MatteiPhotoExport
//
//  Created by Matt on 10/30/10.
//  Copyright 2010 . All rights reserved.
//

#import "MatteExportSettings.h"

@implementation MatteExportSettings

@synthesize collectionId, size,quality,url,username,password,exportOriginals,autoAlbum;
@synthesize exportOriginalMovies, selectedComponentIndex, exportMovieSettings;

- (id) init {
	if ( (self = [super init]) ) {
		autoAlbum = YES;
		exportOriginals = YES;
		exportOriginalMovies = NO;
	}
	return self;
}

- (void) dealloc {
	self.url = nil;
	self.username = nil;
	self.password = nil;
	self.exportMovieSettings = nil;
	[super dealloc];
}

@end
