//
//  CollectionExport.m
//  MatteiPhotoExport
//
//  Created by Matt on 3/18/08.
//

#import "CollectionExport.h"

#import "Constants.h"

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
	rating = 0;
	date = nil;
	return self;
}

- (void)dealloc {
	[path release];
	[keywords release];
	[metadata release];
	[date release];
	[super dealloc];
}

- (void)addKeywords:(NSArray *)theKeywords {
	[keywords addObjectsFromArray:theKeywords];
}

- (void)toXml:(NSXMLElement *)parent {
	NSXMLElement *item = [[NSXMLElement alloc] initWithName:@"item"];
	[item addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:[self name]]];
	if ( [self rating] > 0 ) {
		[item addAttribute:[NSXMLNode attributeWithName:@"rating" 
			stringValue:[NSString stringWithFormat:@"%d", [self rating]]]];
	}
	if ( [self path] != nil ) {
		[item addAttribute:[NSXMLNode attributeWithName:@"archive-path" stringValue:[self path]]];
	}
	if ( [self date] != nil ) {
		[item addAttribute:[NSXMLNode attributeWithName:@"item-date" stringValue:[self date]]];
	}
	
	if ( [self comments] != nil ) {
		[item addChild:[NSXMLElement elementWithName:@"comment" stringValue:[self comments]]];
	}
	
	if ( [self keywords] != nil && [[self keywords] count] > 0 ) {
		[item addChild:[NSXMLElement elementWithName:@"keywords" 
			stringValue:[[self keywords] componentsJoinedByString:@","]]];
	}
	 
	[parent addChild:item];
	[item release];
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

- (NSString *)date {
	return date;
}

- (void)setDate:(NSString *)theDate {
	NSString *oldDate = nil;
	if ( date != theDate ) {
		oldDate = date;
		date = [theDate retain];
		[oldDate release];
	}
}

- (int)rating {
	return rating;
}

- (void)setRating:(int)theRating {
	rating = theRating;
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

- (PhotoExport *)addPhoto:(NSString *)theName comments:(NSString *)theComments path:(NSString *)thePath {
	PhotoExport *photo = [[PhotoExport alloc] init];
	[photo setName:theName];
	[photo setPath:thePath];
	if ( theComments != nil && [theComments length] > 0 ) {
		[photo setComments:theComments];
	}
	[photos addObject:photo];
	[photo autorelease];
	return photo;
}

- (void)toXml:(NSXMLElement *)parent {
	NSXMLElement *album = [[NSXMLElement alloc] initWithName:@"album"];
	[album addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:[self name]]];
	if ( [self sortMode] != nil ) {
		[album addAttribute:[NSXMLNode attributeWithName:@"sort" stringValue:[self sortMode]]];
	}
	if ( [self comments] != nil ) {
		[album addChild:[NSXMLElement elementWithName:@"comment" stringValue:[self comments]]];
	}
	
	// export child photos...
	NSEnumerator *photoEnum = [photos objectEnumerator];
	PhotoExport *photo;
	while ( photo = [photoEnum nextObject] ) {
		[photo toXml:album];
	}
	
	[parent addChild:album];
	[album release];
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
	photos = [[NSMutableArray array] retain];
	collectionId = -1;
	return self;
}

- (void)dealloc {
	[albums release];
	[photos release];
	[super dealloc];
}

- (AlbumExport *)addAlbum:(NSString *)theName comments:(NSString *)theComments sortMode:(NSString *)theSortMode {
	AlbumExport *album = [[AlbumExport alloc] init];
	[album setName:theName];
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

- (PhotoExport *)addPhoto:(NSString *)theName comments:(NSString *)theComments path:(NSString *)thePath {
	PhotoExport *photo = [[PhotoExport alloc] init];
	[photo setName:theName];
	[photo setPath:thePath];
	if ( theComments != nil && [theComments length] > 0 ) {
		[photo setComments:theComments];
	}
	[photos addObject:photo];
	[photo autorelease];
	return photo;
}

- (NSXMLElement *) asXml {
	NSXMLNode *ns = [NSXMLNode namespaceWithName:@"" stringValue:@"http://msqr.us/xsd/matte"];
    NSXMLElement *root = [NSXMLNode elementWithName:@"collection-import"];
	[root addNamespace:ns];
	[root addChild:[NSXMLNode commentWithStringValue:[NSString stringWithFormat:
													  @" Generated by Matte iPhoto Export Plugin %@ ", 
													  MatteExportPluginVersion]]];
	// export direct photos
	for ( PhotoExport *photo in photos ) {
		[photo toXml:root];
	}
	
	// export child albums...
	NSEnumerator *albumEnum = [albums objectEnumerator];
	AlbumExport *album;
	while ( album = [albumEnum nextObject] ) {
		[album toXml:root];
	}
	
	return root;
}

- (BOOL)saveAsXml:(NSString *)dest {
    NSXMLElement *root = [self asXml];
	NSXMLDocument *xmlDoc = [NSXMLDocument document];
	[xmlDoc addChild:root];
	[xmlDoc setVersion:@"1.0"];
	[xmlDoc setCharacterEncoding:@"UTF-8"];
	
	NSData *xmlData = [xmlDoc XMLDataWithOptions:NSXMLNodePrettyPrint];
	if ( ![xmlData writeToFile:dest atomically:YES] ) {
        NSLog(@"Could not write document out...");
        return NO;
    }
    return YES;
}

- (NSArray *)albums {
	return albums;
}

- (NSArray *)photos {
	return photos;
}

@end
