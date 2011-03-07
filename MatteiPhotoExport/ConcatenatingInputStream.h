//
//  ConcatenatingInputStream.h
//  MatteiPhotoExport
//
//  Created by Matt on 3/7/11.
//  Copyright 2011 . All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ConcatenatingInputStream : NSInputStream {
	NSMutableArray *streams;
	NSInputStream *current;
}

- (id)initWithFilePaths:(NSArray *)theFilePaths;

@end
