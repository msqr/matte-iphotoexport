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
@synthesize exportOriginalMovies, selectedPresetIndex;

- (id)init {
	if ( (self = [super init]) ) {
		collectionId = -1;
		autoAlbum = YES;
		exportOriginals = YES;
		exportOriginalMovies = NO;
	}
	return self;
}

- (void)dealloc {
	self.url = nil;
	self.username = nil;
	self.password = nil;
	[super dealloc];
}

- (void)restoreFromUserDefaults:(NSUserDefaults *)defaults {
	self.url = [defaults stringForKey:@"settings.url"];
	self.username = [defaults stringForKey:@"settings.username"];
	collectionId = [defaults integerForKey:@"settings.collectionId"];
	
	
	autoAlbum = [defaults boolForKey:@"settings.autoAlbum"];
	
	exportOriginals = [defaults boolForKey:@"settings.exportOriginals"];
	size = [defaults integerForKey:@"settings.size"];
	quality = [defaults integerForKey:@"settings.quality"];
	
	exportOriginalMovies = [defaults boolForKey:@"settings.exportOriginalMovies"];
	selectedPresetIndex = [defaults integerForKey:@"settings.selectedPresetIndex"];
}

- (void)saveToUserDefaults:(NSUserDefaults *)defaults {
	[defaults setObject:url forKey:@"settings.url"];
	[defaults setObject:username forKey:@"settings.username"];
	[defaults setInteger:collectionId forKey:@"settings.collectionId"];
	
	[defaults setBool:autoAlbum forKey:@"settings.autoAlbum"];
	
	[defaults setBool:exportOriginals forKey:@"settings.exportOriginals"];
	[defaults setInteger:size forKey:@"settings.size"];
	[defaults setInteger:quality forKey:@"settings.quality"];
	
	[defaults setBool:exportOriginalMovies forKey:@"settings.exportOriginalMovies"];
	[defaults setInteger:selectedPresetIndex forKey:@"settings.selectedPresetIndex"];
}

@end
