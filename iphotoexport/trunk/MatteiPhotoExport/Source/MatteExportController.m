//
//  MatteExportController.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/25/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MatteExportController.h"
#import <QuickTime/QuickTime.h>

@implementation MatteExportController

- (void)awakeFromNib
{
	[mSizePopUp selectItemWithTag:2];
	[mQualityPopUp selectItemWithTag:2];

	if ( [mExportMgr albumCount] > 0 ) {
		NSLog(@"Hello, album %d: %@", 0, [mExportMgr albumNameAtIndex:0]);
		[mAlbumNameText setStringValue:[mExportMgr albumNameAtIndex:0]];
		[mAlbumCommentsText setStringValue:[mExportMgr albumCommentsAtIndex:0]];
	}
}

- (id)initWithExportImageObj:(id <ExportImageProtocol>)obj
{
	if(self = [super init])
	{
		mExportMgr = obj;
		mProgress.message = nil;
		mProgressLock = [[NSLock alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[mExportDir release];
	[mProgressLock release];
	[mProgress.message release];
	
	[super dealloc];
}

#pragma mark getters/setters

// getters/setters
- (NSString *)exportDir
{
	return mExportDir;
}

- (void)setExportDir:(NSString *)dir
{
	[mExportDir release];
	mExportDir = [dir retain];
}

- (int)size
{
	return mSize;
}

- (void)setSize:(int)size
{
	mSize = size;
}

- (int)quality
{
	return mQuality;
}

- (void)setQuality:(int)quality
{
	mQuality = quality;
}

- (NSString *)url
{
	return mUrl;
}

- (void)setUrl:(NSString *)url
{
	mUrl = url;
}

- (NSString *)username
{
	return mUsername;
}

- (void)setUsername:(NSString *)username
{
	mUsername = username;
}

- (NSString *)password
{
	return mPassword;
}

- (void)setPassword:(NSString *)password
{
	mPassword = password;
}

- (NSString *)albumName
{
	return mAlbumName;
}

- (void)setAlbumName:(NSString *)albumName
{
	mAlbumName = albumName;
}

- (NSString *)albumComments
{
	return mAlbumComments;
}

- (void)setAlbumComments:(NSString *)albumComments
{
	mAlbumComments = albumComments;
}

- (BOOL)autoAlbum
{
	return mAutoAlbum;
}

- (void)setAutoAlbum:(BOOL)autoAlbum
{
	mAutoAlbum = autoAlbum;
}

#pragma mark ExportPluginBoxProtocol

// protocol implementation
- (NSView <ExportPluginBoxProtocol> *)settingsView
{
	return mSettingsBox;
}

- (NSView *)firstView
{
	return mFirstView;
}

- (void)viewWillBeActivated
{
	// set album name/comments to currently selected in iPhoto
	if ( [mExportMgr albumCount] > 0 ) {
		[mAlbumNameText setStringValue:[mExportMgr albumNameAtIndex:0]];
		[mAlbumCommentsText setStringValue:[mExportMgr albumCommentsAtIndex:0]];
	}	
}

- (void)viewWillBeDeactivated
{
	
}

- (NSString *)requiredFileType
{
	if([mExportMgr imageCount] > 1)
		return @"";
	else
		return @"jpg";
}

- (BOOL)wantsDestinationPrompt
{
	return YES;
}

- (NSString*)getDestinationPath
{
	return @"";
}

- (NSString *)defaultFileName
{
	if([mExportMgr imageCount] > 1)
		return @"";
	else
		return @"sfe-0";
}

- (NSString *)defaultDirectory
{
	return @"~/Pictures/";
}

- (BOOL)treatSingleSelectionDifferently
{
	return YES;
}

- (BOOL)handlesMovieFiles
{
	return NO;
}

- (BOOL)validateUserCreatedPath:(NSString*)path
{
	return NO;
}

- (void)clickExport
{
	[mExportMgr clickExport];
}

- (void)startExport:(NSString *)path
{
	NSFileManager *fileMgr = [NSFileManager defaultManager];
	
	[self setSize:[mSizePopUp selectedTag]];
	[self setQuality:[mQualityPopUp selectedTag]];
	
	int count = [mExportMgr imageCount];
	
	// check for conflicting file names
	if(count == 1)
		[mExportMgr startExport];
	else
	{
		int i;
		for(i=0; i<count; i++)
		{
			NSString *fileName = [NSString stringWithFormat:@"sfe-%d.jpg",i];
			if([fileMgr fileExistsAtPath:[path stringByAppendingPathComponent:fileName]])
				break;
		}
		if(i != count)
		{
			if (NSRunCriticalAlertPanel(@"File exists", @"One or more images already exist in directory.", 
										@"Replace", nil, @"Cancel") == NSAlertDefaultReturn)
				[mExportMgr startExport];
			else
				return;
		}
		else
			[mExportMgr startExport];
	}
}

- (void)performExport:(NSString *)path
{
	NSLog(@"performExport path: %@", path);
	
	unsigned albumCount =  [mExportMgr albumCount];
	NSLog(@"albumCount: %d", albumCount);
	unsigned albumIdx;
	for ( albumIdx = 0; albumIdx < albumCount; albumIdx++ ) {
		NSLog(@"Album %d: %@", albumCount, [mExportMgr albumNameAtIndex:albumIdx]);
	}
	
	int count = [mExportMgr imageCount];
	BOOL succeeded = YES;
	mCancelExport = NO;
	
	[self setExportDir:path];
	
	// set export options
	ImageExportOptions imageOptions;
	imageOptions.format = kQTFileTypeJPEG;
	switch([self quality])
	{
		case 0: imageOptions.quality = EQualityLow; break;
		case 1: imageOptions.quality = EQualityMed; break;
		case 2: imageOptions.quality = EQualityHigh; break;
		case 3: imageOptions.quality = EQualityMax; break;
		default: imageOptions.quality = EQualityHigh; break;
	}
	imageOptions.rotation = 0.0;
	switch([self size])
	{
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
	
	// Do the export
	[self lockProgress];
	mProgress.indeterminateProgress = NO;
	mProgress.totalItems = count - 1;
	[mProgress.message autorelease];
	mProgress.message = @"Exporting";
	[self unlockProgress];
	
	NSString *dest;
	
	if(count > 1)
	{
		int i;
		for(i = 0; mCancelExport == NO && succeeded == YES && i < count; i++)
		{
			[self lockProgress];
			mProgress.currentItem = i;
			[mProgress.message autorelease];
			mProgress.message = [[NSString stringWithFormat:@"Image %d of %d",
								  i + 1, count] retain];
			[self unlockProgress];
			
			dest = [[self exportDir] stringByAppendingPathComponent:
					[NSString stringWithFormat:@"sfe-%d.jpg", i]];
			
			NSLog(@"Exporting image from path: %@", [mExportMgr imagePathAtIndex:i]);
			NSLog(@"Exporting image from source path: %@", [mExportMgr sourcePathAtIndex:i]);
			NSArray *albums = [mExportMgr albumsOfImageAtIndex:i];
			NSEnumerator *albumEnum = [albums objectEnumerator];
			id album;
			while ( album = [albumEnum nextObject] ) {
				NSLog(@"Exporting image from album: %@", [album description]);
			}
			succeeded = [mExportMgr exportImageAtIndex:i dest:dest options:&imageOptions];
		}
	}
	else
	{
		[self lockProgress];
		mProgress.currentItem = 0;
		[mProgress.message autorelease];
		mProgress.message = @"Image 1 of 1";
		[self unlockProgress];
		
		dest = [self exportDir];
		succeeded = [mExportMgr exportImageAtIndex:0 dest:dest options:&imageOptions];
	}
	
	// Handle failure
	if (!succeeded) {
		[self lockProgress];
		[mProgress.message autorelease];
		mProgress.message = [[NSString stringWithFormat:@"Unable to create %@", dest] retain];
		[self cancelExport];
		mProgress.shouldCancel = YES;
		[self unlockProgress];
		return;
	}
	
	// close the progress panel when done
	[self lockProgress];
	[mProgress.message autorelease];
	mProgress.message = nil;
	mProgress.shouldStop = YES;
	[self unlockProgress];
}

- (ExportPluginProgress *)progress
{
	return &mProgress;
}

- (void)lockProgress
{
	[mProgressLock lock];
}

- (void)unlockProgress
{
	[mProgressLock unlock];
}

- (void)cancelExport
{
	mCancelExport = YES;
}

- (NSString *)name
{
	return @"Matte Exporter";
}

@end