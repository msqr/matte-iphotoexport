//
//  CollectionExport.m
//  MatteiPhotoExport
//
//  Created by Matt on 3/18/08.
//

#import "CollectionExport.h"

@implementation ExportObject

- (id)init {
	self = [super init];
	return self;
}

- (void)dealloc {
	[name release];
	[comments release];
	[super dealloc];
}

- (NSString *)name {
	return name;
}

- (void)setName:(NSString *)theName {
	NSString *oldName = nil;
	if ( name != theName ) {
		oldName = name;
		name = [theName retain];
		[oldName release];
	}
}

- (NSString *)comments {
	return comments;
}

- (void)setComments:(NSString *)theComments {
	NSString *oldComments = nil;
	if ( comments != theComments ) {
		oldComments = comments;
		comments = [theComments retain];
		[oldComments release];
	}
}

@end

@implementation PhotoExport

- (id)init {
	self = [super init];
	keywords = [[NSMutableArray array] retain];
	metadata = [[NSMutableDictionary  dictionary] retain];
	return self;
}

- (void)dealloc {
	[path release];
	[keywords release];
	[metadata release];
	[super dealloc];
}

- (void)addKeywords:(NSArray *)theKeywords {
	[keywords addObjectsFromArray:theKeywords];
}

- (NSString *)path {
	return path;
}

- (void)setPath:(NSString *)thePath {
	NSString *oldPath = nil;
	if ( path != thePath ) {
		oldPath = path;
		path = [thePath retain];
		[oldPath release];
	}
}

- (NSArray *)keywords {
	return keywords;
}

- (NSDictionary *)metadata {
	return metadata;
}

@end

@implementation AlbumExport

- (id)init {
	self = [super init];
	photos = [[NSMutableArray array] retain];
	return self;
}

- (PhotoExport *)addPhoto:(NSString *)theName comments:(NSString *)theComments {
	PhotoExport *photo = [[PhotoExport alloc] init];
	[photo setComments:theComments];
	[photos addObject:photo];
	[photo autorelease];
	return photo;
}

- (void)dealloc {
	[photos release];
	[super dealloc];
}

- (NSString *)sortMode {
	return sortMode;
}

- (void)setSortMode:(NSString *)theSortMode {
	NSString *oldSortMode = nil;
	if ( sortMode != theSortMode ) {
		oldSortMode = sortMode;
		sortMode = [theSortMode retain];
		[oldSortMode release];
	}
}

- (NSArray *)photos {
	return photos;
}

@end

@implementation CollectionExport

- (id)init {
	self = [super init];
	albums = [[NSMutableArray array] retain];
	collectionId = -1;
	return self;
}

- (void)dealloc {
	[albums release];
	[super dealloc];
}

- (AlbumExport *)addAlbum:(NSString *)theName comments:(NSString *)theComments sortMode:(NSString *)theSortMode {
	AlbumExport *album = [[AlbumExport alloc] init];
	[album setComments:theComments];
	[album setSortMode:theSortMode];
	[albums addObject:album];
	[album autorelease];
	return album;
}

- (AlbumExport *)findAlbumNamed:(NSString *)theName {
	if ( theName == nil ) {
		return nil;
	}
	NSEnumerator *albumEnum = [albums objectEnumerator];
	AlbumExport *album;
	while ( album = [albumEnum nextObject] ) {
		if ( [theName isEqual:[album name]] ) {
			return album;
		}
	}
	return nil;
}

- (NSArray *)albums {
	return albums;
}

@end
