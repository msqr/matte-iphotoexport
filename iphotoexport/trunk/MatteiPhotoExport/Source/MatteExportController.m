//
//  MatteExportController.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/25/07.
//  Copyright 2007 Matt Magoffin.
//

#import "MatteExportController.h"
#import "CollectionExport.h"
#import "smdevp.h"
#import "wsseapi.h"
#import "gsoap/MatteSoapBinding.nsmap"
#import <QuickTime/QuickTime.h>

@implementation MatteExportController

- (void)awakeFromNib
{
	[mExportOriginalsButton setState:NSOffState];
	[mAutoAlbumButton setState:NSOnState];
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

- (void)populateCollectionPopUp
{
	struct soap *soap;
	const char *user;
	const char *pass;
	const char *endpoint;
	int i;
	struct m__get_collection_list_request_type request;
	struct m__get_collection_list_response_type response;
	
	NSLog(@"Populating collection pop up...");
	
	soap = soap_new();
	soap_register_plugin(soap, soap_wsse);
	endpoint = [[[self url] stringByAppendingString:@"/ws/Matte"] UTF8String];
	user = [[self username] UTF8String];
	pass = [[self password] UTF8String];
	
	NSLog(@"Calling WS %s, user: %s, pass: %s", endpoint, user, pass);

	soap_wsse_add_UsernameTokenText(soap, NULL, user, pass);
	
	// call the service
	if ( soap_call___mws__GetCollectionList(soap, endpoint, NULL, &request, &response) ) {
		NSLog(@"Error calling WS %s: %d", endpoint, soap->error);
		soap_print_fault(soap, stderr);
		soap_end(soap);
		soap_done(soap);
		// TODO handle error with dialog warning
		return;
	}
	NSLog(@"Called WS %s OK, # collections: %d", endpoint, response.__sizecollection);
	
	// populate the collections menu
	[mCollectionPopUp removeAllItems];
	for ( i = 0; i < response.__sizecollection; i++ ) {
		NSString *title = [NSString stringWithCString:response.collection[i].name];
		NSString *format = [NSString stringWithFormat:@"%d", i];
		NSMenuItem *item = [[mCollectionPopUp menu] 
							addItemWithTitle:title
							action:nil
							keyEquivalent:format];
		[item setTag:response.collection[i].collection_id];
	}
	soap_end(soap);
	soap_done(soap);
}

- (IBAction)populateCollections:(id)sender 
{
	[self setUsername:[mUsernameText stringValue]];
	[self setPassword:[mPasswordText stringValue]];
	[self setUrl:[mUrlText stringValue]];
	
	NSLog(@"populateCollections action called by %@, user = %@, pass = %@", 
		sender, [self username], [self password]);
	
	if ( [self username] != NULL && [[self username] length] > 0 
		&& [self password] != NULL && [[self password] length] > 0 ) {
		[self populateCollectionPopUp];
	}	
}

- (IBAction)changeExportOriginals:(id)sender 
{
	[self setExportOriginals:([mExportOriginalsButton state] == NSOnState)];
	
	NSLog(@"changeExportOriginals action called by %@, exportOriginals = %@", 
		  sender, ([self exportOriginals] ? @"TRUE" : @"FALSE"));
	
	[mSizePopUp setEnabled:(![self exportOriginals])];
	[mQualityPopUp setEnabled:(![self exportOriginals])];
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

- (int)collectionId
{
	return mCollectionId;
}

- (void)setCollectionId:(int)collectionId
{
	mCollectionId = collectionId;
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

- (BOOL)exportOriginals
{
	return mExportOriginals;
}

- (void)setExportOriginals:(BOOL)exportOriginals
{
	mExportOriginals = exportOriginals;
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
	
	/* TODO enable this logic
	 if ( [mCollectionPopUp numberOfItems] < 1 ) {
		[mExportMgr disableControls];
	} else {
		[mExportMgr enableControls];
	}
	 */
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
	
	NSLog(@"url = %@, user = %@, pass = %@", [self url], [self username], [self password]);
	
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

- (void)setupImageExportOptions:(ImageExportOptions *)imageOptions {
	imageOptions->format = kQTFileTypeJPEG;
	switch ([self quality]) {
		case 0: imageOptions->quality = EQualityLow; break;
		case 1: imageOptions->quality = EQualityMed; break;
		case 2: imageOptions->quality = EQualityHigh; break;
		case 3: imageOptions->quality = EQualityMax; break;
		default: imageOptions->quality = EQualityHigh; break;
	}
	imageOptions->rotation = 0.0;
	switch ([self size]) {
		case 0:
			imageOptions->width = 320;
			imageOptions->height = 320;
			break;
		case 1:
			imageOptions->width = 640;
			imageOptions->height = 640;
			break;
		case 2:
			imageOptions->width = 1280;
			imageOptions->height = 1280;
			break;
		case 3:
			imageOptions->width = 99999;
			imageOptions->height = 99999;
			break;
		default:
			imageOptions->width = 1280;
			imageOptions->height = 1280;
			break;
	}	
	imageOptions->metadata = EMBoth;
}

- (void)performExport:(NSString *)path
{
	NSLog(@"performExport path: %@", path);
	
	int count = [mExportMgr imageCount];
	BOOL succeeded = YES;
	mCancelExport = NO;
	CollectionExport *colExport = [[CollectionExport alloc] init];
	
	// TODO remove
	unsigned albumCount =  [mExportMgr albumCount];
	NSLog(@"albumCount: %d", albumCount);
	unsigned albumIdx;
	for ( albumIdx = 0; albumIdx < albumCount; albumIdx++ ) {
		NSLog(@"Album %d: %@", albumCount, [mExportMgr albumNameAtIndex:albumIdx]);
	}
	// END remove
	
	[self setExportDir:path];
	
	ImageExportOptions imageOptions;
	NSFileManager *fileManager;
	
	if ( ![self exportOriginals] ) {
		// set export options when not exporting originals
		[self setupImageExportOptions:&imageOptions];
	} else {
		fileManager = [NSFileManager defaultManager];
	}
	
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
			
			if ( ![self exportOriginals] ) {
				dest = [[self exportDir] stringByAppendingPathComponent:
					[NSString stringWithFormat:@"sfe-%d.jpg", i]];
			} else {
				dest = [[self exportDir] stringByAppendingPathComponent:
						[mExportMgr imageFileNameAtIndex:i]];
			}
			
			NSLog(@"Exporting image from path: %@", [mExportMgr imagePathAtIndex:i]);
			id albums = [mExportMgr albumsOfImageAtIndex:i];
			NSEnumerator *albumEnum = [albums objectEnumerator];
			NSNumber *albumIndex;
			while ( albumIndex = [albumEnum nextObject] ) {
				NSLog(@"Exporting image from album index: %@", [albumIndex description]);
				
				AlbumExport *album = [colExport findAlbumNamed:
									  [mExportMgr albumNameAtIndex:[albumIndex intValue]]];
				if ( album == nil ) {
					NSLog(@"Creating new album export %@", [mExportMgr albumNameAtIndex:[albumIndex intValue]]);
					album = [colExport addAlbum:[mExportMgr albumNameAtIndex:[albumIndex intValue]]
									   comments:[mExportMgr albumCommentsAtIndex:[albumIndex intValue]]
									   sortMode:@"date"]; // TODO add as option to export UI?
				}
				
				PhotoExport *photo = [album addPhoto:[mExportMgr imageTitleAtIndex:i]
										   comments:[mExportMgr imageCommentsAtIndex:i]];
				
				[photo addKeywords:[mExportMgr imageKeywordsAtIndex:i]];
				[photo setRating:[mExportMgr imageRatingAtIndex:i]];
			}
			if ( ![self exportOriginals] ) {
				succeeded = [mExportMgr exportImageAtIndex:i dest:dest options:&imageOptions];
			} else {
				succeeded = [fileManager copyPath:[mExportMgr imagePathAtIndex:i]
										   toPath:dest
										  handler:nil];
			}
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
	
	// free CollectionExport
	if ( succeeded ) {
		dest = [[self exportDir] stringByAppendingPathComponent:@"metadata.xml"];
		NSLog(@"Writing colExport as XML to %@", dest);
		[colExport saveAsXml:dest];
	}
	[colExport release];
	NSLog(@"released colExport");

	
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
