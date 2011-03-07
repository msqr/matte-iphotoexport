//
//  ConcatenatingInputStream.m
//  MatteiPhotoExport
//
//  Created by Matt on 3/7/11.
//  Copyright 2011 . All rights reserved.
//

#import "ConcatenatingInputStream.h"

@implementation ConcatenatingInputStream

- (id)initWithFilePaths:(NSArray *)theFilePaths {
	if ( (self = [super initWithFileAtPath:[theFilePaths objectAtIndex:0]]) ) {
		NSMutableArray *strs = [[NSMutableArray alloc] init];
		NSUInteger i, len;
		for ( i = 1, len = [theFilePaths count]; i < len; i++ ) {
			[strs addObject:[NSInputStream inputStreamWithFileAtPath:[theFilePaths objectAtIndex:i]]];
		}
		streams = strs;
		current = self;
	}
	return self;
}

- (void)dealloc {
	current = nil;
	[streams release], streams = nil;
	[super dealloc];
}

- (NSInputStream *)currentStream {
	if ( [current hasBytesAvailable] ) {
		return current;
	}
	if ( current != self ) {
		[current release];
	}
	current = nil;
	while ( [streams count] > 0 ) {
		NSInputStream *next = [[streams objectAtIndex:0] retain];
		[streams removeObjectAtIndex:0];
		if ( [next hasBytesAvailable] ) {
			current = next;
			break;
		} else {
			[next release];
		}
	}
	return current;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
	NSInputStream *curr = [self currentStream];
	if ( curr == self ) {
		return [super read:buffer maxLength:len];
	}
	return [curr read:buffer maxLength:len];
}

- (BOOL)hasBytesAvailable {
	NSInputStream *curr = [self currentStream];
	if ( curr == self ) {
		return [super hasBytesAvailable];
	}
	return [curr hasBytesAvailable];
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
	NSInputStream *curr = [self currentStream];
	if ( curr == self ) {
		return [super getBuffer:buffer length:len];
	}
	return [curr getBuffer:buffer length:len];
}

@end
