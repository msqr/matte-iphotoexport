//
//  MatteExportContext.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/1/10.
//  Copyright 2010 . All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ExportImageProtocol.h"

@class CollectionExport;
@class MatteExportSettings;

@interface MatteExportContext : NSObject {
	ImageExportOptions imageOptions;
	NSString *exportDir;
	NSMutableSet *exportedPaths;
	NSMutableDictionary *outputPathMap;
	CollectionExport *metadata;
}

@property (nonatomic, readonly) ImageExportOptions *imageOptions;
@property (nonatomic, retain) NSString *exportDir;
@property (nonatomic, readonly) CollectionExport *metadata;

- (id) initWithSettings:(MatteExportSettings *)settings;

// returns YES if the given path has been passed to recordExport:toPath:inArchive: already
- (BOOL) isExported:(NSString *)srcPath;

// record that an item has been exported
- (void) recordExport:(NSString *)srcPath 
			   toPath:(NSString *)outputPath 
			inArchive:(NSString *)archivePath;

- (NSUInteger) outputCount;
- (NSArray *) archivePaths;
- (NSString *) outputPathForArchivePath:(NSString *)archivePath;

@end
