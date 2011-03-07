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
@class ZipArchive;

@interface MatteExportContext : NSObject {
	ImageExportOptions imageOptions;
	NSString *exportDir;
	NSMutableDictionary *inputPathMap;
	CollectionExport *metadata;
	NSString *exportMovieExtension;
	BOOL succeeded;
	ZipArchive *zip;
}

@property (assign) BOOL succeeded;
@property (nonatomic, readonly) ImageExportOptions *imageOptions;
@property (nonatomic, retain) NSString *exportDir;
@property (nonatomic, readonly) CollectionExport *metadata;
@property (nonatomic, retain) NSString *exportMovieExtension;
@property (nonatomic, retain) ZipArchive *zip;

- (id) initWithSettings:(MatteExportSettings *)settings;

// returns YES if the given path has been passed to recordExport:toPath:inArchive: already
- (BOOL) isExported:(NSString *)srcPath;

- (void) export:(NSString *)srcPath atArchivePath:(NSString *)archivePath;

- (NSUInteger) outputCount;
- (NSArray *) archivePaths;
- (NSString *) archivePathForSourcePath:(NSString *)sourcePath;

@end
