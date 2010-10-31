//
//  MatteExportContext.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/1/10.
//  Copyright 2010 . All rights reserved.
//

#import <QTKit/QTKit.h>

#import "MatteExportContext.h"

#import "CollectionExport.h"
#import "MatteExportSettings.h"

@interface MatteExportContext (Private)
- (void) setupImageExportOptionsFromSettings:(MatteExportSettings *)settings;
@end


#pragma mark -

@implementation MatteExportContext

@synthesize exportDir, exportMovieExtension, metadata;

- (id) initWithSettings:(MatteExportSettings *)settings {
	if ( (self = [super init]) ) {
		inputPathMap = [[NSMutableDictionary alloc] init];
		outputPathMap = [[NSMutableDictionary alloc] init];
		metadata = [[CollectionExport alloc] init];
		if ( ![settings isExportOriginals] ) {
			[self setupImageExportOptionsFromSettings:settings];
		}
	}
	return self;
}

- (void) dealloc {
	[exportDir release], exportDir = nil;
	[exportMovieExtension release], exportMovieExtension = nil;
	[inputPathMap release], inputPathMap = nil;
	[outputPathMap release], outputPathMap = nil;
	[metadata release], metadata =  nil;
	[super dealloc];
}

// returns YES if the given path has been passed to recordExport:toPath:inArchive: already
- (BOOL) isExported:(NSString *)srcPath {
	return [inputPathMap objectForKey:srcPath] != nil;
}

// record that an item has been exported
- (void) recordExport:(NSString *)srcPath 
			   toPath:(NSString *)outputPath 
			inArchive:(NSString *)archivePath {
	if ( srcPath != nil ) {
		[inputPathMap setObject:archivePath forKey:srcPath];
	}
	[outputPathMap setObject:outputPath forKey:archivePath];
}

- (ImageExportOptions *) imageOptions {
	return &imageOptions;
}

- (NSUInteger) outputCount {
	return [outputPathMap count];
}

- (NSArray *) archivePaths {
	return [outputPathMap allKeys];
}

- (NSString *) outputPathForArchivePath:(NSString *)archivePath {
	return [outputPathMap objectForKey:archivePath];
}

- (NSString *) archivePathForSourcePath:(NSString *)sourcePath {
	return [inputPathMap objectForKey:sourcePath];
}

#pragma mark Private

- (void) setupImageExportOptionsFromSettings:(MatteExportSettings *)settings {
	imageOptions.format = kQTFileTypeJPEG;
	switch ( [settings quality] ) {
		case 0: imageOptions.quality = EQualityLow; break;
		case 1: imageOptions.quality = EQualityMed; break;
		case 2: imageOptions.quality = EQualityHigh; break;
		case 3: imageOptions.quality = EQualityMax; break;
		default: imageOptions.quality = EQualityHigh; break;
	}
	imageOptions.rotation = 0.0;
	switch ( [settings size] ) {
		case 0:
			imageOptions.width = 320;
			imageOptions.height = 320;
			break;
		case 1:
			imageOptions.width = 640;
			imageOptions.height = 640;
			break;
		case 2:
			imageOptions.width = 1280;
			imageOptions.height = 1280;
			break;
		case 3:
			imageOptions.width = 99999;
			imageOptions.height = 99999;
			break;
		default:
			imageOptions.width = 1280;
			imageOptions.height = 1280;
			break;
	}	
	imageOptions.metadata = EMBoth;
}

@end
