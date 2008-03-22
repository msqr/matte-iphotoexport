//
//  CollectionExport.h
//  MatteiPhotoExport
//
//  Created by Matt on 3/18/08.
//

#import <Foundation/Foundation.h>

@interface ExportObject : NSObject {
@private
	NSString *name;
	NSString *comments;
}

- (NSString *)name;
- (void)setName:(NSString *)theName;

- (NSString *)comments;
- (void)setComments:(NSString *)theComments;

@end

@interface PhotoExport : ExportObject {
@private
	NSString *path;
	NSMutableArray *keywords;
	NSDictionary *metadata;
	int rating;
}

- (NSString *)path;
- (void)setPath:(NSString *)thePath;

- (NSArray *)keywords;
- (void)addKeywords:(NSArray *)theKeywords;

- (int)rating;
- (void)setRating:(int)theRating;

- (NSDictionary *)metadata;

@end

@interface AlbumExport : ExportObject {
@private
	NSString *sortMode;
	NSMutableArray *photos;
}

- (NSArray *)photos;
- (PhotoExport *)addPhoto:(NSString *)theName comments:(NSString *)theComments;

- (NSString *)sortMode;
- (void)setSortMode:(NSString *)theSortMode;

- (void)toXml:(NSXMLElement *)parent;

@end

@interface CollectionExport : ExportObject {
@private
	NSMutableArray *albums;
	long collectionId;
}

- (NSArray *)albums;

- (AlbumExport *)addAlbum:(NSString *)theName comments:(NSString *)theComments sortMode:(NSString *)theSortMode;

- (AlbumExport *)findAlbumNamed:(NSString *)theName;

- (BOOL)saveAsXml:(NSString *)dest;

@end

