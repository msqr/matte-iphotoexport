//
//  MatteExportContext.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/1/10.
//  Copyright 2010 . All rights reserved.
//

#import <Foundation/Foundation.h>

@class CollectionExport;

@interface MatteExportContext : NSObject {
	NSString *exportDir;
	NSMutableSet *exportedPaths;
	NSMutableDictionary *outputPaths;
	CollectionExport *metadata;
}

@property (retain) NSString *exportDir;
@property (nonatomic, readonly) CollectionExport *metadata;

// returns YES if the given path has been passed to recordExport:toPath:inArchive: already
- (BOOL) isExported:(NSString *)srcPath;

// record that an item has been exported
- (void) recordExport:(NSString *)srcPath 
			   toPath:(NSString *)outputPath 
			inArchive:(NSString *)archivePath;

@end
