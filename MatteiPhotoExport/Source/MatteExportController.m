//
//  MatteExportController.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/25/07.
//  Copyright 2007 Matt Magoffin.
//

#import "MatteExportController.h"
#import "CollectionExport.h"
#import "gsoap/MatteSoapBinding.nsmap"
#import "smdevp.h"
#import "wsseapi.h"

@interface MatteExportController (MovieSupport)
- (void)setupQTMovie:(NSDictionary *)attributes;
- (void)exportMovie:(NSString *)dest;
@end

#pragma mark -

@implementation MatteExportController

@synthesize settings;

- (void) awakeFromNib {
	//[mExportOriginalsButton setState:NSOnState];
	//[mAutoAlbumButton setState:NSOnState];
	//[mSizePopUp selectItemWithTag:2];
	//[mQualityPopUp selectItemWithTag:2];
	//[self changeExportOriginals:nil];

	if ( [exportMgr albumCount] > 0 ) {
		DLog(@"Hello, album %d: %@", 0, [exportMgr albumNameAtIndex:0]);
		//[mAlbumNameText setStringValue:[exportMgr albumNameAtIndex:0]];
		//[mAlbumCommentsTextView setString:[exportMgr albumCommentsAtIndex:0]];
	}
}

- (id) initWithExportImageObj:(id <ExportImageProtocol>)obj {
	if ( (self = [super init]) ) {
		settings = [[MatteExportSettings alloc] init];
		exportMgr = obj;
		progress.message = nil;
		progressLock = [[NSLock alloc] init];
		taskCondition = [[NSCondition alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(finishedZip:)
													 name:NSTaskDidTerminateNotification 
												   object:nil];
	}
	return self;
}

- (void) dealloc {
	[settings release];
	[exportDir release];
	[progressLock release];
	[progress.message release];
	[taskCondition release];
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
	endpoint = [[[settings url] stringByAppendingString:@"/ws/Matte"] UTF8String];
	user = [[settings username] UTF8String];
	pass = [[settings password] UTF8String];
	
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
	//[self setUsername:[mUsernameText stringValue]];
	//[self setPassword:[mPasswordText stringValue]];
	//[self setUrl:[mUrlText stringValue]];
	
	DLog(@"populateCollections action called by %@, user = %@, pass = %@", 
		sender, [settings username], [settings password]);
	
	if ( [settings username] != nil && [[settings username] length] > 0 
		&& [settings password] != nil && [[settings password] length] > 0 ) {
		[self populateCollectionPopUp];
	}	
}

- (IBAction)changeExportOriginals:(id)sender 
{
	//[self setExportOriginals:([mExportOriginalsButton state] == NSOnState)];
	
	DLog(@"changeExportOriginals action called by %@, exportOriginals = %@", 
		  sender, ([settings isExportOriginals] ? @"YES" : @"NO"));
	
	[mSizePopUp setEnabled:(![settings isExportOriginals])];
	[mQualityPopUp setEnabled:(![settings isExportOriginals])];
}

#pragma mark Accessors

- (NSString *) exportDir {
	return exportDir;
}

- (void) setExportDir:(NSString *)dir {
	NSString *oldDir;
	if ( exportDir != dir ) {
		oldDir = exportDir;
		exportDir = [dir retain];
		[oldDir autorelease];
	}
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
	/*if ( [exportMgr albumCount] > 0 ) {
		[mAlbumNameText setStringValue:[exportMgr albumNameAtIndex:0]];
		[mAlbumCommentsTextView setString:[exportMgr albumCommentsAtIndex:0]];
	}*/
	
	/* TODO enable this logic
	 if ( [mCollectionPopUp numberOfItems] < 1 ) {
		[exportMgr disableControls];
	} else {
		[exportMgr enableControls];
	}
	 */
}

- (void)viewWillBeDeactivated
{
	
}

- (NSString *)requiredFileType
{
	if([exportMgr imageCount] > 1)
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
	if([exportMgr imageCount] > 1)
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
	[exportMgr clickExport];
}

- (void)startExport:(NSString *)path
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// FIXME: [self setSize:[mSizePopUp selectedTag]];
	// FIXME: [self setQuality:[mQualityPopUp selectedTag]];
	
	DLog(@"url = %@, user = %@, pass = %@", [settings url], 
		 [settings username], [settings password]);
	
	int count = [exportMgr imageCount];
	
	// TODO check for actual Matte file names
	// check for conflicting file names
	if(count == 1)
		[exportMgr startExport];
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
				[exportMgr startExport];
			else
				return;
		}
		else
			[exportMgr startExport];
	}
}

- (void)setupImageExportOptions:(ImageExportOptions *)imageOptions {
	imageOptions->format = kQTFileTypeJPEG;
	switch ( [settings quality] ) {
		case 0: imageOptions->quality = EQualityLow; break;
		case 1: imageOptions->quality = EQualityMed; break;
		case 2: imageOptions->quality = EQualityHigh; break;
		case 3: imageOptions->quality = EQualityMax; break;
		default: imageOptions->quality = EQualityHigh; break;
	}
	imageOptions->rotation = 0.0;
	switch ( [settings size] ) {
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
	
	int count = [exportMgr imageCount];
	BOOL succeeded = YES;
	cancelExport = NO;
	CollectionExport *colExport = [[CollectionExport alloc] init];
	
	[self setExportDir:path];
	
	ImageExportOptions imageOptions;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ( ![settings isExportOriginals] ) {
		// set export options when not exporting originals
		[self setupImageExportOptions:&imageOptions];
	}
	
	// Do the export
	[self lockProgress];
	progress.indeterminateProgress = NO;
	progress.totalItems = count - 1;
	[progress.message autorelease];
	progress.message = @"Exporting";
	[self unlockProgress];
	
	NSDateFormatter *xsdDateTimeFormat = [[NSDateFormatter alloc] init];
	[xsdDateTimeFormat setFormatterBehavior:NSDateFormatterBehavior10_4];
	[xsdDateTimeFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
	[xsdDateTimeFormat setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
	
	NSString *dest;
	
	int i;
	for(i = 0; cancelExport == NO && succeeded == YES && i < count; i++)
	{
		[self lockProgress];
		progress.currentItem = i;
		[progress.message autorelease];
		progress.message = [[NSString stringWithFormat:@"Image %d of %d",
							  i + 1, count] retain];
		[self unlockProgress];
		
		DLog(@"Exporting image from path: %@", [exportMgr imagePathAtIndex:i]);
		id albums = [exportMgr albumsOfImageAtIndex:i];
		NSEnumerator *albumEnum = [albums objectEnumerator];
		NSNumber *albumIndex;
		while ( albumIndex = [albumEnum nextObject] ) {
			DLog(@"Exporting image from album index: %@", [albumIndex description]);
			
			dest = [[self exportDir] 
					 stringByAppendingPathComponent:[exportMgr albumNameAtIndex:[albumIndex intValue]]];
			
			if ( ![fileManager fileExistsAtPath:dest] ) {
				[fileManager createDirectoryAtPath:dest attributes:nil];
			}
			
			NSString *destFileName = nil;
			
			if ( [settings isExportOriginals] && [exportMgr originalIsMovieAtIndex:i] ) {
				NSDictionary *qtAttr = [NSDictionary dictionaryWithObjectsAndKeys:
										[exportMgr sourcePathAtIndex:i], QTMovieFileNameAttribute,
										[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute, 
										nil];
				[self performSelectorOnMainThread:@selector(setupQTMovie:) withObject:qtAttr waitUntilDone:YES];
				
				destFileName = [[[[exportMgr sourcePathAtIndex:i] lastPathComponent] stringByDeletingPathExtension]
								stringByAppendingFormat:@".%@", @"m4v"];
			} else {
				destFileName = [exportMgr imageFileNameAtIndex:i];
			}
			dest = [dest stringByAppendingPathComponent:destFileName];
			
			DLog(@"Exporting image to %@", dest);
			
			AlbumExport *album = [colExport findAlbumNamed:
								  [exportMgr albumNameAtIndex:[albumIndex intValue]]];
			if ( album == nil ) {
				DLog(@"Creating new album export %@", [exportMgr albumNameAtIndex:[albumIndex intValue]]);
				album = [colExport addAlbum:[exportMgr albumNameAtIndex:[albumIndex intValue]]
								   comments:[exportMgr albumCommentsAtIndex:[albumIndex intValue]]
								   sortMode:@"date"]; // TODO add as option to export UI?
			}
			
			NSString *albumPath = [[album name] stringByAppendingPathComponent:destFileName];
			
			PhotoExport *photo = [album addPhoto:[exportMgr imageTitleAtIndex:i]
										comments:[exportMgr imageCommentsAtIndex:i]
											path:albumPath];
			
			if ( [exportMgr originalIsMovieAtIndex:i] ) {
				// copy the date, if available, onto the album because we don't
				// have good way of extracting date from video itself in Matte yet
				NSDate *itemDate = [exportMgr imageDateAtIndex:i];
				NSString *itemDateStr = [xsdDateTimeFormat stringFromDate:itemDate];
				[photo setDate:itemDateStr];
			}
			
			[photo addKeywords:[exportMgr imageKeywordsAtIndex:i]];
			[photo setRating:[exportMgr imageRatingAtIndex:i]];
		}
		if ( ![settings isExportOriginals] ) {
			succeeded = [exportMgr exportImageAtIndex:i dest:dest options:&imageOptions];
		} else {
			// for movie files, we have to get the "sourcePath", because the "imagePath" points
			// to a JPG image extracted from the movie
			NSString *src = ([exportMgr originalIsMovieAtIndex:i] 
							 ? [exportMgr sourcePathAtIndex:i] 
							 : [exportMgr imagePathAtIndex:i]);
			
			if ( movie != nil ) {
				[taskCondition lock];
				taskRunning = YES;
				[NSThread detachNewThreadSelector:@selector(exportMovie:) toTarget:self withObject:dest];
				while ( taskRunning ) {
					[taskCondition wait];
				}
				[taskCondition unlock];
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
		[progress.message autorelease];
		progress.message = [[NSString stringWithFormat:@"Unable to create %@", dest] retain];
		[self cancelExport];
		progress.shouldCancel = YES;
		[self unlockProgress];
		return;
	}
	
	// create zip archive
	zipTask = [[NSTask alloc] init];
	[zipTask setCurrentDirectoryPath:[self exportDir]];
	[zipTask setLaunchPath:@"/usr/bin/zip"]; // TODO make sure this exists, or find it?
	
	// consstruct arguments array
	NSMutableArray *args = [NSMutableArray array];
	[args addObject:@"-r"];
	unsigned albumCount =  [exportMgr albumCount];
	unsigned albumIdx;
	for ( albumIdx = 0; albumIdx < albumCount; albumIdx++ ) {
		if ( albumIdx == 0 ) {
			// add zip name as first album name
			[args addObject:[[exportMgr albumNameAtIndex:albumIdx] stringByAppendingString:@".zip"]];
		}
		[args addObject:[exportMgr albumNameAtIndex:albumIdx]];
	}
	[args addObject:@"metadata.xml"];
	[zipTask setArguments:args];
	
	[self lockProgress];
	[progress.message autorelease];
	progress.message = @"Creating zip archive";
	progress.indeterminateProgress = YES;
	[self unlockProgress];
	
	// iPhoto runs export in own thread, so for notificaiton of task complete to reach us,
	// run the task from the main thread which is the thread that created us in the first place
	[taskCondition lock];
	taskRunning = YES;
	[zipTask performSelectorOnMainThread:@selector(launch) withObject:nil waitUntilDone:NO];
	while ( taskRunning ) {
		[taskCondition wait];
	}
	[taskCondition unlock];
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
	return &progress;
}

- (void)lockProgress
{
	[progressLock lock];
}

- (void)unlockProgress
{
	[progressLock unlock];
}

- (void)cancelExport
{
	cancelExport = YES;
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
	[progress.message autorelease];
	progress.message = nil;
	progress.shouldStop = YES;
	[zipTask release];
	zipTask = nil;
	
	// signal that we've completed
	[taskCondition lock];
	taskRunning = NO;
	[taskCondition signal];
	[taskCondition unlock];
	
	[self unlockProgress];
}

#pragma mark Movie export support

- (void)setupQTMovie:(NSDictionary *)attributes
{
	[movie release];
	movie = [[QTMovie movieWithAttributes:attributes error:nil] retain];
	[movie setDelegate:self];
	[movie detachFromCurrentThread];
}

- (BOOL)movie:(QTMovie *)theMovie shouldContinueOperation:(NSString *)op 
	withPhase:(QTMovieOperationPhase)phase 
	atPercent:(NSNumber *)percent
withAttributes:(NSDictionary *)attributes
{
	[self lockProgress];
	if ( phase == QTMovieOperationBeginPhase ) {
		[progress.message autorelease];
		progress.message = [op retain];
	} else if ( phase == QTMovieOperationUpdatePercentPhase ) {
		unsigned long val = (unsigned long)roundf([percent floatValue] * 100);
		progress.currentItem = val;
	}
	[self unlockProgress];
	return YES;
}

- (void)exportMovie:(NSString *)dest
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self lockProgress];
	unsigned long prevTotal = progress.totalItems;
	unsigned long prevCurr = progress.currentItem;
	progress.totalItems = 100;
	progress.currentItem = 0;
	[self unlockProgress];
	
	[QTMovie enterQTKitOnThreadDisablingThreadSafetyProtection];
	[movie attachToCurrentThread];
	NSDictionary *exportAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
								 [NSNumber numberWithBool:YES], QTMovieExport,
								 [NSNumber numberWithLong:'M4V '], QTMovieExportType,
								 nil];
	[movie writeToFile:dest withAttributes:exportAttrs];
	[movie detachFromCurrentThread];
	[QTMovie exitQTKitOnThread];
	[movie setDelegate:nil];
	[movie release];
	movie = nil;
	
	[self lockProgress];
	progress.totalItems = prevTotal;
	progress.currentItem = prevCurr;
	[self unlockProgress];
	
	// unlock condition
	[taskCondition lock];
	taskRunning = NO;
	[taskCondition signal];
	[taskCondition unlock];
	
	[pool drain];
}


@end
