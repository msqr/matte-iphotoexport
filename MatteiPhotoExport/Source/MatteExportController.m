//
//  MatteExportController.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/25/07.
//  Copyright 2007 Matt Magoffin.
//

#import "MatteExportController.h"
#import "CollectionExport.h"
#import "MatteExportContext.h"
#import "MatteExportSettings.h"
#import "ZipArchive.h"
#import "gsoap/MatteSoapBinding.nsmap"
#import "smdevp.h"
#import "wsseapi.h"

NSString * const MatteExportPluginVersion = @"1.0";

@interface MatteExportController (MovieSupport)
- (NSArray *)availableComponents;
- (NSData *)getExportSettings:(NSUInteger)selectedComponentIndex;
- (BOOL)componentSupportsSettingsDialog:(NSUInteger)selectedComponentIndex;
- (void)setupQTMovie:(NSDictionary *)attributes;
- (void)exportMovie:(NSString *)dest;
@end

@interface MatteExportController (Private)
- (void)setupImageExportOptions:(ImageExportOptions *)imageOptions;
@end

#pragma mark -

@implementation MatteExportController

@synthesize settings;

- (void) awakeFromNib {
	if ( [exportMgr albumCount] > 0 ) {
		DLog(@"Hello, album %d: %@", 0, [exportMgr albumNameAtIndex:0]);
	}
	[mQTComponentPopUp removeAllItems];
	qtComponents = [[self availableComponents] retain];
	for ( NSDictionary *component in qtComponents ) {
		NSString *name = [component objectForKey:@"name"];
		unsigned int i;
		for ( i = 2; [mQTComponentPopUp itemWithTitle:name] != nil; ++i) {
			name = [NSString stringWithFormat:@"%@-%u", [component objectForKey:@"name"], i];
		}
		[mQTComponentPopUp addItemWithTitle:name];
	}
	[mQTComponentPopUp selectItemAtIndex:settings.selectedComponentIndex];
	
	[self changeExportOriginals:nil];
	[self changeExportOriginalMovies:nil];
	
	[mVersionLabel setStringValue:[NSString stringWithFormat:@"Version %@", MatteExportPluginVersion]];
}

- (id) initWithExportImageObj:(id <ExportImageProtocol>)obj {
	if ( (self = [super init]) ) {
		settings = [[MatteExportSettings alloc] init];
		[settings restoreFromUserDefaults:[NSUserDefaults standardUserDefaults]];
		exportMgr = obj;
		progress.message = nil;
		progressLock = [[NSLock alloc] init];
		taskCondition = [[NSCondition alloc] init];

		xsdDateTimeFormat = [[NSDateFormatter alloc] init];
		[xsdDateTimeFormat setFormatterBehavior:NSDateFormatterBehavior10_4];
		[xsdDateTimeFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
		[xsdDateTimeFormat setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
		
	}
	return self;
}

- (void) dealloc {
	[settings release];
	[progressLock release];
	[progress.message release];
	[taskCondition release];
	[qtComponents release];
	[xsdDateTimeFormat release];
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

#pragma mark Actions

- (IBAction)populateCollections:(id)sender 
{
	DLog(@"populateCollections action called by %@, user = %@, pass = %@", 
		sender, [settings username], [settings password]);
	
	if ( [settings username] != nil && [[settings username] length] > 0 
		&& [settings password] != nil && [[settings password] length] > 0 ) {
		[self populateCollectionPopUp];
	}	
}

- (IBAction)changeExportOriginals:(id)sender 
{
	DLog(@"changeExportOriginals action called by %@, exportOriginals = %@", 
		  sender, ([settings isExportOriginals] ? @"YES" : @"NO"));
	
	[mSizePopUp setEnabled:(![settings isExportOriginals])];
	[mQualityPopUp setEnabled:(![settings isExportOriginals])];
}

- (IBAction)changeExportOriginalMovies:(id)sender 
{
	BOOL enabled = ![settings isExportOriginalMovies];
	DLog(@"changeExportOriginals action called by %@, exportOriginals = %@", 
		 sender, (enabled ? @"YES" : @"NO"));
	
	[mQTComponentPopUp setEnabled:enabled];
	[mQTSettingButton setEnabled:[self componentSupportsSettingsDialog:settings.selectedComponentIndex]];
}

- (IBAction)changeExportMovieType:(id)sender
{
	[mQTSettingButton setEnabled:[self componentSupportsSettingsDialog:settings.selectedComponentIndex]];
}

- (IBAction)configureMovieExportSettings:(id)sender
{
	NSData *qtSettings = [self getExportSettings:settings.selectedComponentIndex];
	settings.exportMovieSettings = qtSettings;
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
	// persist settings to defaults
	[settings saveToUserDefaults:[NSUserDefaults standardUserDefaults]];
}

- (NSString *)requiredFileType
{
	return @"";
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
	return @"";
}

- (NSString *)defaultDirectory
{
	return @"~/Pictures/";
}

- (BOOL)treatSingleSelectionDifferently
{
	return NO;
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
	[settings saveToUserDefaults:[NSUserDefaults standardUserDefaults]];
	
	// TODO check for conflicting file names?
	[exportMgr startExport];
}

- (BOOL)exportItem:(int)i inAlbum:(NSNumber *)albumIndex context:(MatteExportContext *)context
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSString *albumName = nil;
	NSString *outputDir = context.exportDir;
	
	if ( albumIndex ) {
		albumName = [exportMgr albumNameAtIndex:[albumIndex intValue]];
		outputDir = [outputDir stringByAppendingPathComponent:albumName];
	}
	
	if ( ![fileManager fileExistsAtPath:outputDir] ) {
		[fileManager createDirectoryAtPath:outputDir attributes:nil];
	}
	
	NSString *destFileName = nil;
	NSString *srcFile = nil;
	
	if ( [exportMgr originalIsMovieAtIndex:i] ) {
		srcFile = [exportMgr sourcePathAtIndex:i];
		if ( settings.exportOriginalMovies ) {
			destFileName = [srcFile lastPathComponent];
		} else {
			NSDictionary *qtAttr = [NSDictionary dictionaryWithObjectsAndKeys:
									[exportMgr sourcePathAtIndex:i], QTMovieFileNameAttribute,
									[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute, 
									nil];
			[self performSelectorOnMainThread:@selector(setupQTMovie:) withObject:qtAttr waitUntilDone:YES];
			
			if ( context.exportMovieExtension == nil ) {
				NSNumber *subtype = [[qtComponents objectAtIndex:settings.selectedComponentIndex] objectForKey:@"subtypeLong"];
				OSType exportMovieType = [subtype longValue];
				context.exportMovieExtension = [[exportMgr getExtensionForImageFormat:exportMovieType] retain];
				if ( context.exportMovieExtension == nil ) {
					context.exportMovieExtension = @"mov";
				}
			}
			destFileName = [[[[exportMgr sourcePathAtIndex:i] lastPathComponent] stringByDeletingPathExtension]
							stringByAppendingFormat:@".%@", context.exportMovieExtension];
		}
	} else {
		srcFile = [exportMgr imagePathAtIndex:i];
		destFileName = [exportMgr imageFileNameAtIndex:i];
	}
	
	NSString *outputPath = nil;
	NSString *archivePath = [context archivePathForSourcePath:srcFile];
	if ( archivePath == nil ) {
		if ( albumName != nil ) {
			archivePath = [albumName stringByAppendingPathComponent:destFileName];
		} else {
			archivePath = destFileName;
		}
		outputPath = [context.exportDir stringByAppendingPathComponent:archivePath];
	}
	
	DLog(@"Exporting image to %@", outputPath);
	PhotoExport *photo = nil;
	if ( albumName != nil ) {
		AlbumExport *album = [context.metadata findAlbumNamed:albumName];
		if ( album == nil ) {
			DLog(@"Creating new album export %@", albumName);
			album = [context.metadata addAlbum:albumName
									  comments:[exportMgr albumCommentsAtIndex:[albumIndex intValue]]
									  sortMode:@"date"]; // TODO add as option to export UI?
		}
		
		photo = [album addPhoto:[exportMgr imageTitleAtIndex:i]
					   comments:[exportMgr imageCommentsAtIndex:i]
						   path:archivePath];
	} else {
		photo = [context.metadata addPhoto:[exportMgr imageTitleAtIndex:i]
								  comments:[exportMgr imageCommentsAtIndex:i]
									  path:archivePath];
	}
	
	if ( [exportMgr originalIsMovieAtIndex:i] ) {
		// copy the date, if available, onto the album because we don't
		// have good way of extracting date from video itself in Matte yet
		NSDate *itemDate = [exportMgr imageDateAtIndex:i];
		NSString *itemDateStr = [xsdDateTimeFormat stringFromDate:itemDate];
		[photo setDate:itemDateStr];
	}
	
	[photo addKeywords:[exportMgr imageKeywordsAtIndex:i]];
	[photo setRating:[exportMgr imageRatingAtIndex:i]];

	BOOL succeeded = YES;
	if ( outputPath != nil ) {
		[context recordExport:srcFile toPath:outputPath inArchive:archivePath];
		if ( movie != nil ) {
			[taskCondition lock];
			taskRunning = YES;
			[NSThread detachNewThreadSelector:@selector(exportMovie:) toTarget:self withObject:outputPath];
			while ( taskRunning ) {
				[taskCondition wait];
			}
			[taskCondition unlock];
		} else if ( movie == nil && !settings.exportOriginals ) {
			succeeded = [exportMgr exportImageAtIndex:i dest:outputPath options:context.imageOptions];
		} else {
			// for movie files, we have to get the "sourcePath", because the "imagePath" points
			// to a JPG image extracted from the movie
			
			NSString *src = ([exportMgr originalIsMovieAtIndex:i]
							 ? [exportMgr sourcePathAtIndex:i]
							 : [exportMgr imagePathAtIndex:i]);
			DLog(@"Exporting original file %@", src);
			succeeded = [fileManager copyPath:src
									   toPath:outputPath
									  handler:self];
		}
	}
	return succeeded;
}

- (void)performExport:(NSString *)path
{
	DLog(@"performExport path: %@", path);
	
	int count = [exportMgr imageCount];
	int albumCount =  (settings.autoAlbum ? [exportMgr albumCount] : 0);
	BOOL succeeded = YES;
	cancelExport = NO;
	int i;
	
	if ( settings.exportMovieSettings == nil && !settings.exportOriginalMovies ) {
		// need to recompress movies, but we don't have settings selected for movies.
		// look for a movie in our export, and if we have one, present the settings dialog
		// to choose the movie export settings
		for ( i = 0; i < count; i++ ) {
			if ( [exportMgr originalIsMovieAtIndex:i] ) {
				if ( [self componentSupportsSettingsDialog:settings.selectedComponentIndex] ) {
					[self performSelectorOnMainThread:@selector(configureMovieExportSettings:) withObject:nil waitUntilDone:YES];
					if ( settings.exportMovieSettings == nil ) {
						cancelExport = YES;
						[self lockProgress];
						progress.shouldStop = YES;
						[self unlockProgress];
						return;
					}
				}
				break;
			}
		}
	}
	
	MatteExportContext *context = [[MatteExportContext alloc] initWithSettings:settings];
	context.exportDir = path;
	
	// Do the export
	[self lockProgress];
	progress.indeterminateProgress = NO;
	progress.totalItems = count - 1;
	[progress.message autorelease];
	progress.message = @"Exporting";
	[self unlockProgress];
	
	NSString *dest;
	
	for(i = 0; cancelExport == NO && succeeded == YES && i < count; i++)
	{
		[self lockProgress];
		progress.currentItem = i;
		[progress.message autorelease];
		progress.message = [[NSString stringWithFormat:@"Image %d of %d",
							  i + 1, count] retain];
		[self unlockProgress];
		
		DLog(@"Exporting image %d from path: %@", i, [exportMgr imagePathAtIndex:i]);
		NSArray *albums = (settings.autoAlbum ? [exportMgr albumsOfImageAtIndex:i] : nil);
		if ( albums != nil && [albums count] > 0 ) {
			for ( NSNumber *albumIndex in albums ) {
				succeeded = [self exportItem:i inAlbum:albumIndex context:context];
				if ( !succeeded ) {
					break;
				}
			}
		} else {
			succeeded = [self exportItem:i inAlbum:nil context:context];
		}
	}
	
	// Handle failure
	if (!succeeded) {
		[self lockProgress];
		[progress.message autorelease];
		progress.message = [[NSString stringWithFormat:@"Unable to create %@", dest] retain];
		[self cancelExport];
		progress.shouldCancel = YES;
		[self unlockProgress];
		[context release];
		return;
	}
	
	// write CollectionExport as metadata.xml
	dest = [context.exportDir stringByAppendingPathComponent:@"metadata.xml"];
	DLog(@"Writing colExport as XML to %@", dest);
	[context.metadata saveAsXml:dest];
	
	[self lockProgress];
	[progress.message autorelease];
	progress.totalItems = [context outputCount];
	progress.message = [[NSString stringWithFormat:@"Zipping item 1 of %d", progress.totalItems] retain];
	progress.currentItem = 0;
	[self unlockProgress];
	
	// create zip archive
	ZipArchive *zip = [[ZipArchive alloc] init];
	NSString *zipName;
	if ( albumCount > 0 ) {
		// name zip archive after first album
		zipName = [exportMgr albumNameAtIndex:0];
	} else if ( count == 1 ) {
		// name zip archive after image
		zipName = [[[[context archivePaths] objectAtIndex:0] lastPathComponent] stringByDeletingPathExtension];
	} else {
		// name zip archive generic name
		zipName = @"Matte Export";
	}

	// add metadata.xml to list of files to archive
	[context recordExport:nil toPath:dest inArchive:@"metadata.xml"];
	
	[zip CreateZipFile2:[context.exportDir stringByAppendingPathComponent:[zipName stringByAppendingString:@".zip"]]];
	for ( NSString *archivePath in [context archivePaths] ) {
		[self lockProgress];
		progress.currentItem = progress.currentItem + 1;
		[progress.message autorelease];
		progress.message = [[NSString stringWithFormat:@"Zipping item %d of %d", 
							 progress.currentItem, progress.totalItems] retain];
		[self unlockProgress];
		
		[zip addFileToZip:[context outputPathForArchivePath:archivePath] newname:archivePath];
	}
	[zip CloseZipFile2];
	[zip release];
	
	[self lockProgress];
	[progress.message autorelease];
	progress.message = nil;
	progress.shouldStop = YES;
	[self unlockProgress];
	
	[context release];
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

#pragma mark Movie export support

// QT export code adapted from http://cocoadev.com/index.pl?QTMovieExportSettings

- (BOOL)componentSupportsSettingsDialog:(NSUInteger)selectedComponentIndex
{
	NSDictionary *qtComponent = [qtComponents objectAtIndex:selectedComponentIndex];
	NSString *subtype = [qtComponent objectForKey:@"subtype"];
	if ( [subtype hasPrefix:@"M4V"] || [subtype hasPrefix:@"iph"] ) {
		// these types do not support any settings
		return NO;
	}
	return YES;
}

- (NSArray *)availableComponents
{
	NSMutableArray		*results = nil;
	ComponentDescription	cd = {};
	Component		 c = NULL;
	Handle			 nameHandle = NewHandle(0);
	
	if ( nameHandle == NULL )
		return( nil );
	
	cd.componentType = MovieExportType;
	cd.componentSubType = 0;
	cd.componentManufacturer = 0;
	cd.componentFlags = canMovieExportFiles;
	cd.componentFlagsMask = canMovieExportFiles;
	
	while((c = FindNextComponent(c, &cd)))
	{
		ComponentDescription	exportCD = {};
		
		if ( GetComponentInfo( c, &exportCD, nameHandle, NULL, NULL ) == noErr )
		{
			HLock( nameHandle );
			NSString	*nameStr = [[[NSString alloc] initWithBytes:(*nameHandle)+1 length:(int)**nameHandle encoding:NSMacOSRomanStringEncoding] autorelease];
			HUnlock( nameHandle );
			
			// these numbers are required by QTKit
			NSNumber *typeNum = [NSNumber numberWithLong:exportCD.componentSubType];
			NSNumber *subTypeNum = [NSNumber numberWithLong:exportCD.componentSubType];
			NSNumber *manufacturerNum = [NSNumber numberWithLong:exportCD.componentManufacturer];
			
			// the following string versions are to help with debugging
			exportCD.componentType = CFSwapInt32HostToBig(exportCD.componentType);
			exportCD.componentSubType = CFSwapInt32HostToBig(exportCD.componentSubType);
			exportCD.componentManufacturer = CFSwapInt32HostToBig(exportCD.componentManufacturer);
			
			NSString *type = [[[NSString alloc] initWithBytes:&exportCD.componentType length:sizeof(OSType) encoding:NSMacOSRomanStringEncoding] autorelease];
			NSString *subType = [[[NSString alloc] initWithBytes:&exportCD.componentSubType length:sizeof(OSType) encoding:NSMacOSRomanStringEncoding] autorelease];
			NSString *manufacturer = [[[NSString alloc] initWithBytes:&exportCD.componentManufacturer length:sizeof(OSType) encoding:NSMacOSRomanStringEncoding] autorelease];
			
			NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
										nameStr, @"name", [NSData dataWithBytes:&c length:sizeof(c)], @"component",
										type, @"type", subType, @"subtype", 
										typeNum, @"typeLong", subTypeNum, @"subtypeLong",
										manufacturer, @"manufacturer", manufacturerNum, @"manufacturerLong",
										nil];
			
			if ( results == nil ) {
				results = [NSMutableArray array];
			}
			DLog(@"Found component: %@", dictionary);
			[results addObject:dictionary];
		}
	}
	
	DisposeHandle( nameHandle );
	
	return results;
}

- (NSData *)getExportSettings:(NSUInteger)selectedComponentIndex
{
	Component c;
	memcpy(&c, [[[qtComponents objectAtIndex:selectedComponentIndex] objectForKey:@"component"] bytes], sizeof(c));
	
	MovieExportComponent exporter = OpenComponent(c);
	Boolean canceled;
	ComponentResult err = MovieExportDoUserDialog(exporter, NULL, NULL, 0, 0, &canceled);
	if(err)
	{
		NSLog(@"Got error %d when calling MovieExportDoUserDialog",err);
		CloseComponent(exporter);
		return nil;
	}
	if(canceled)
	{
		CloseComponent(exporter);
		return nil;
	}
	QTAtomContainer qtSettings;
	err = MovieExportGetSettingsAsAtomContainer(exporter, &qtSettings);
	if(err)
	{
		NSLog(@"Got error %d when calling MovieExportGetSettingsAsAtomContainer",err);
		CloseComponent(exporter);
		return nil;
	}
	NSData *data = [NSData dataWithBytes:*qtSettings length:GetHandleSize(qtSettings)];
	DisposeHandle(qtSettings);
	
	CloseComponent(exporter);
	
	return data;
}

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
	NSDictionary *component = [qtComponents objectAtIndex:settings.selectedComponentIndex];
	NSDictionary *exportAttrs;
	if ( [self componentSupportsSettingsDialog:settings.selectedComponentIndex] ) {
		exportAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
					   [NSNumber numberWithBool:YES], QTMovieExport,
					   [component objectForKey:@"subtypeLong"], QTMovieExportType,
					   [component objectForKey:@"manufacturerLong"], QTMovieExportManufacturer,
					   settings.exportMovieSettings, QTMovieExportSettings,
					   nil];
	} else {
		exportAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
					   [NSNumber numberWithBool:YES], QTMovieExport,
					   [component objectForKey:@"subtypeLong"], QTMovieExportType,
					   nil];
	}
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
