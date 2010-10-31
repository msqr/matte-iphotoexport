//
//  MatteExportContext.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/1/10.
//  Copyright 2010 . All rights reserved.
//

#import "MatteExportContext.h"

#import "CollectionExport.h"

@implementation MatteExportContext

@synthesize exportDir, metadata;

- (id) init {
	if ( (self = [super init]) ) {
		exportedPaths = [[NSMutableSet alloc] init];
		outputPaths = [[NSMutableDictionary alloc] init];
		metadata = [[CollectionExport alloc] init];
	}
	return self;
}

- (void) dealloc {
	[exportDir release], exportDir = nil;
	[exportedPaths release], exportedPaths = nil;
	[outputPaths release], outputPaths = nil;
	[metadata release], metadata =  nil;
	[super dealloc];
}

// returns YES if the given path has been passed to recordExport:toPath:inArchive: already
- (BOOL) isExported:(NSString *)srcPath {
	return [exportedPaths member:srcPath] != nil;
}

// record that an item has been exported
- (void) recordExport:(NSString *)srcPath 
			   toPath:(NSString *)outputPath 
			inArchive:(NSString *)archivePath {
	[exportedPaths addObject:srcPath];
	[outputPaths setObject:outputPath forKey:archivePath];
}

@end
