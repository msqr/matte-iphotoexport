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

@interface MatteExportController (MovieSupport)
- (void)setupQTMovie:(NSDictionary *)attributes;
- (void)exportMovie:(NSString *)dest;
@end

#pragma mark -

@implementation MatteExportController

- (void)awakeFromNib
{
	[mExportOriginalsButton setState:NSOnState];
	[mAutoAlbumButton setState:NSOnState];
	[mSizePopUp selectItemWithTag:2];
	[mQualityPopUp selectItemWithTag:2];
	[self changeExportOriginals:nil];

	if ( [mExportMgr albumCount] > 0 ) {
		DLog(@"Hello, album %d: %@", 0, [mExportMgr albumNameAtIndex:0]);
		[mAlbumNameText setStringValue:[mExportMgr albumNameAtIndex:0]];
		[mAlbumCommentsTextView setString:[mExportMgr albumCommentsAtIndex:0]];
	}
}

- (id)initWithExportImageObj:(id <ExportImageProtocol>)obj
{
	if(self = [super init])
	{
		mExportMgr = obj;
		mProgress.message = nil;
		mProgressLock = [[NSLock alloc] init];
		mTaskCondition = [[NSCondition alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(finishedZip:)
													 name:NSTaskDidTerminateNotification 
												   object:nil];
	}
	return self;
}

- (void)dealloc
{
	[mExportDir release];
	[mProgressLock release];
	[mProgress.message release];
	[mTaskCondition release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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
	
	DLog(@"Populating collection pop up...");
	
	soap = soap_new();
	soap_register_plugin(soap, soap_wsse);
	endpoint = [[[self url] stringByAppendingString:@"/ws/Matte"] UTF8String];
	user = [[self username] UTF8String];
	pass = [[self password] UTF8String];
	
	DLog(@"Calling WS %s, user: %s, pass: %s", endpoint, user, pass);

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
	DLog(@"Called WS %s OK, # collections: %d", endpoint, response.__sizecollection);
	
	// populate the collections menu
	[mCollectionPopUp removeAllItems];
	for ( i = 0; i < response.__sizecollection; i++ ) {
		NSString *title = [NSString stringWithCString:response.collection[i].name encoding:NSUTF8StringEncoding];
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
	
	DLog(@"populateCollections action called by %@, user = %@, pass = %@", 
		sender, [self username], [self password]);
	
	if ( [self username] != NULL && [[self username] length] > 0 
		&& [self password] != NULL && [[self password] length] > 0 ) {
		[self populateCollectionPopUp];
	}	
}

- (IBAction)changeExportOriginals:(id)sender 
{
	[self setExportOriginals:([mExportOriginalsButton state] == NSOnState)];
	
	DLog(@"changeExportOriginals action called by %@, exportOriginals = %@", 
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
		[mAlbumCommentsTextView setString:[mExportMgr albumCommentsAtIndex:0]];
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
	return YES;
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
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	[self setSize:[mSizePopUp selectedTag]];
	[self setQuality:[mQualityPopUp selectedTag]];
	
	DLog(@"url = %@, user = %@, pass = %@", [self url], [self username], [self password]);
	
	int count = [mExportMgr imageCount];
	
	// TODO check for actual Matte file names
	// check for conflicting file names
	if(count == 1)
		[mExportMgr startExport];
	else
	{
		int i;
		for(i=0; i<count; i++)
		{
			NSString *fileName = [NSString stringWithFormat:@"sfe-%d.jpg",i];
			if([fileManager fileExistsAtPath:[path stringByAppendingPathComponent:fileName]])
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
	DLog(@"performExport path: %@", path);
	
	int count = [mExportMgr imageCount];
	BOOL succeeded = YES;
	mCancelExport = NO;
	CollectionExport *colExport = [[CollectionExport alloc] init];
	
	[self setExportDir:path];
	
	ImageExportOptions imageOptions;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ( ![self exportOriginals] ) {
		// set export options when not exporting originals
		[self setupImageExportOptions:&imageOptions];
	}
	
	// Do the export
	[self lockProgress];
	mProgress.indeterminateProgress = NO;
	mProgress.totalItems = count - 1;
	[mProgress.message autorelease];
	mProgress.message = @"Exporting";
	[self unlockProgress];
	
	NSDateFormatter *xsdDateTimeFormat = [[NSDateFormatter alloc] init];
	[xsdDateTimeFormat setFormatterBehavior:NSDateFormatterBehavior10_4];
	[xsdDateTimeFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
	[xsdDateTimeFormat setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	
	NSString *dest;
	
	int i;
	for(i = 0; mCancelExport == NO && succeeded == YES && i < count; i++)
	{
		[self lockProgress];
		mProgress.currentItem = i;
		[mProgress.message autorelease];
		mProgress.message = [[NSString stringWithFormat:@"Image %d of %d",
							  i + 1, count] retain];
		[self unlockProgress];
		
		DLog(@"Exporting image from path: %@", [mExportMgr imagePathAtIndex:i]);
		id albums = [mExportMgr albumsOfImageAtIndex:i];
		NSEnumerator *albumEnum = [albums objectEnumerator];
		NSNumber *albumIndex;
		while ( albumIndex = [albumEnum nextObject] ) {
			DLog(@"Exporting image from album index: %@", [albumIndex description]);
			
			dest = [[self exportDir] 
					 stringByAppendingPathComponent:[mExportMgr albumNameAtIndex:[albumIndex intValue]]];
			
			if ( ![fileManager fileExistsAtPath:dest] ) {
				[fileManager createDirectoryAtPath:dest attributes:nil];
			}
			
			NSString *destFileName = nil;
			
			if ( [self exportOriginals] && [mExportMgr originalIsMovieAtIndex:i] ) {
				NSDictionary *qtAttr = [NSDictionary dictionaryWithObjectsAndKeys:
										[mExportMgr sourcePathAtIndex:i], QTMovieFileNameAttribute,
										[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute, 
										nil];
				[self performSelectorOnMainThread:@selector(setupQTMovie:) withObject:qtAttr waitUntilDone:YES];
				
				destFileName = [[[[mExportMgr sourcePathAtIndex:i] lastPathComponent] stringByDeletingPathExtension]
								stringByAppendingFormat:@".%@", @"m4v"];
			} else {
				destFileName = [mExportMgr imageFileNameAtIndex:i];
			}
			dest = [dest stringByAppendingPathComponent:destFileName];
			
			DLog(@"Exporting image to %@", dest);
			
			AlbumExport *album = [colExport findAlbumNamed:
								  [mExportMgr albumNameAtIndex:[albumIndex intValue]]];
			if ( album == nil ) {
				DLog(@"Creating new album export %@", [mExportMgr albumNameAtIndex:[albumIndex intValue]]);
				album = [colExport addAlbum:[mExportMgr albumNameAtIndex:[albumIndex intValue]]
								   comments:[mExportMgr albumCommentsAtIndex:[albumIndex intValue]]
								   sortMode:@"date"]; // TODO add as option to export UI?
			}
			
			NSString *albumPath = [[album name] stringByAppendingPathComponent:destFileName];
			
			PhotoExport *photo = [album addPhoto:[mExportMgr imageTitleAtIndex:i]
										comments:[mExportMgr imageCommentsAtIndex:i]
											path:albumPath];
			
			if ( [mExportMgr originalIsMovieAtIndex:i] ) {
				// copy the date, if available, onto the album because we don't
				// have good way of extracting date from video itself in Matte yet
				NSDate *itemDate = [mExportMgr imageDateAtIndex:i];
				NSString *itemDateStr = [xsdDateTimeFormat stringFromDate:itemDate];
				[photo setDate:itemDateStr];
			}
			
			[photo addKeywords:[mExportMgr imageKeywordsAtIndex:i]];
			[photo setRating:[mExportMgr imageRatingAtIndex:i]];
		}
		if ( ![self exportOriginals] ) {
			succeeded = [mExportMgr exportImageAtIndex:i dest:dest options:&imageOptions];
		} else {
			// for movie files, we have to get the "sourcePath", because the "imagePath" points
			// to a JPG image extracted from the movie
			NSString *src = ([mExportMgr originalIsMovieAtIndex:i] 
							 ? [mExportMgr sourcePathAtIndex:i] 
							 : [mExportMgr imagePathAtIndex:i]);
			
			if ( mMovie != nil ) {
				[mTaskCondition lock];
				taskRunning = YES;
				[NSThread detachNewThreadSelector:@selector(exportMovie:) toTarget:self withObject:dest];
				while ( taskRunning ) {
					[mTaskCondition wait];
				}
				[mTaskCondition unlock];
			} else {
				DLog(@"Exporting original file %@", src);
				succeeded = [fileManager copyPath:src
										   toPath:dest
										  handler:self];
			}
		}
	}
	
	// write CollectionExport as metadata.xml
	if ( succeeded ) {
		dest = [[self exportDir] stringByAppendingPathComponent:@"metadata.xml"];
		DLog(@"Writing colExport as XML to %@", dest);
		[colExport saveAsXml:dest];
	}
	[colExport release];
	[xsdDateTimeFormat release];
	DLog(@"released colExport");

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
	
	// create zip archive
	mZipTask = [[NSTask alloc] init];
	[mZipTask setCurrentDirectoryPath:[self exportDir]];
	[mZipTask setLaunchPath:@"/usr/bin/zip"]; // TODO make sure this exists, or find it?
	
	// consstruct arguments array
	NSMutableArray *args = [NSMutableArray array];
	[args addObject:@"-r"];
	unsigned albumCount =  [mExportMgr albumCount];
	unsigned albumIdx;
	for ( albumIdx = 0; albumIdx < albumCount; albumIdx++ ) {
		if ( albumIdx == 0 ) {
			// add zip name as first album name
			[args addObject:[[mExportMgr albumNameAtIndex:albumIdx] stringByAppendingString:@".zip"]];
		}
		[args addObject:[mExportMgr albumNameAtIndex:albumIdx]];
	}
	[args addObject:@"metadata.xml"];
	[mZipTask setArguments:args];
	
	[self lockProgress];
	[mProgress.message autorelease];
	mProgress.message = @"Creating zip archive";
	mProgress.indeterminateProgress = YES;
	[self unlockProgress];
	
	// iPhoto runs export in own thread, so for notificaiton of task complete to reach us,
	// run the task from the main thread which is the thread that created us in the first place
	[mTaskCondition lock];
	taskRunning = YES;
	[mZipTask performSelectorOnMainThread:@selector(launch) withObject:nil waitUntilDone:NO];
	while ( taskRunning ) {
		[mTaskCondition wait];
	}
	[mTaskCondition unlock];
}
/*
- (void)createZipArchive {
	[mZipTask launch];
	[mZipTaskLock unlockWithCondition:ZIP_TASK_RUNNING];
}*/

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path {
	if ( [manager fileExistsAtPath:path] ) {
		[manager removeFileAtPath:path handler:nil];
	}
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

#pragma mark Zip export support

- (void)finishedZip:(NSNotification *)aNotification {
	DLog(@"Got notification %@", aNotification);
    int status = [[aNotification object] terminationStatus];
#ifdef DEBUG
    if (status) {
        DLog(@"Zip task failed with status %d", status);
    } else {
        DLog(@"Zip task succeeded.");
	}
#endif
	// close the progress panel when done
	[self lockProgress];
	[mProgress.message autorelease];
	mProgress.message = nil;
	mProgress.shouldStop = YES;
	[mZipTask release];
	mZipTask = nil;
	
	// signal that we've completed
	[mTaskCondition lock];
	taskRunning = NO;
	[mTaskCondition signal];
	[mTaskCondition unlock];
	
	[self unlockProgress];
}

#pragma mark Movie export support

- (void)setupQTMovie:(NSDictionary *)attributes
{
	[mMovie release];
	mMovie = [[QTMovie movieWithAttributes:attributes error:nil] retain];
	[mMovie setDelegate:self];
	[mMovie detachFromCurrentThread];
}

- (BOOL)movie:(QTMovie *)movie shouldContinueOperation:(NSString *)op 
	withPhase:(QTMovieOperationPhase)phase 
	atPercent:(NSNumber *)percent
withAttributes:(NSDictionary *)attributes
{
	[self lockProgress];
	if ( phase == QTMovieOperationBeginPhase ) {
		[mProgress.message autorelease];
		mProgress.message = [op retain];
	} else if ( phase == QTMovieOperationUpdatePercentPhase ) {
		unsigned long val = (unsigned long)roundf([percent floatValue] * 100);
		mProgress.currentItem = val;
	}
	[self unlockProgress];
	return YES;
}

- (void)exportMovie:(NSString *)dest
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self lockProgress];
	unsigned long prevTotal = mProgress.totalItems;
	unsigned long prevCurr = mProgress.currentItem;
	mProgress.totalItems = 100;
	mProgress.currentItem = 0;
	[self unlockProgress];
	
	[QTMovie enterQTKitOnThreadDisablingThreadSafetyProtection];
	[mMovie attachToCurrentThread];
	NSDictionary *exportAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
								 [NSNumber numberWithBool:YES], QTMovieExport,
								 [NSNumber numberWithLong:'M4V '], QTMovieExportType,
								 nil];
	[mMovie writeToFile:dest withAttributes:exportAttrs];
	[mMovie detachFromCurrentThread];
	[QTMovie exitQTKitOnThread];
	[mMovie setDelegate:nil];
	[mMovie release];
	mMovie = nil;
	
	[self lockProgress];
	mProgress.totalItems = prevTotal;
	mProgress.currentItem = prevCurr;
	[self unlockProgress];
	
	// unlock condition
	[mTaskCondition lock];
	taskRunning = NO;
	[mTaskCondition signal];
	[mTaskCondition unlock];
	
	[pool drain];
}


@end
