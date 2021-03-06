//
//  MatteExportController.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/25/07.
//  Copyright 2007 Matt Magoffin.
//

#import "MatteExportController.h"

#import <AVFoundation/AVFoundation.h>
#import <Security/Security.h>

#import "AddMediaRequest.h"
#import "CollectionExport.h"
#import "GetCollectionListRequest.h"
#import "KeychainUtils.h"
#import "MatteExportContext.h"
#import "MatteExportSettings.h"
#import "PreformattedMessage.h"
#import "SoapURLConnection.h"
#import "ZipArchive.h"

NSString * const MatteExportPluginVersion = @"1.2";
NSString * const MatteWebServiceUrlPath = @"/ws/Matte";

@implementation MatteExportController

@synthesize settings;

- (void) awakeFromNib {
	if ( [exportMgr albumCount] > 0 ) {
		DLog(@"Hello, album %d: %@", 0, [exportMgr albumNameAtIndex:0]);
	}
	[moviePresetPopUp removeAllItems];
	moviePresets = [[self availablePresets] retain];
	for ( NSString *preset in moviePresets ) {
		NSString *labelKey = [NSString stringWithFormat:@"preset.%@", preset];
		NSString *labelValue = NSLocalizedStringWithDefaultValue(labelKey,
														  @"Localizable",
														  [NSBundle bundleForClass:[MatteExportController class]],
														  preset,
														  nil);
		[moviePresetPopUp addItemWithTitle:labelValue];
	}
	[moviePresetPopUp selectItemAtIndex:settings.selectedPresetIndex];
	
	[self changeExportOriginals:nil];
	[self changeExportOriginalMovies:nil];
	
	if ( settings.url != nil && settings.username != nil ) {
		NSString *keychainPass = [KeychainUtils passwordForURL:[NSURL URLWithString:settings.url] username:settings.username];
		if ( keychainPass != nil ) {
			[mPasswordField setStringValue:keychainPass];
			settings.password = keychainPass;
			[self populateCollectionPopUp];
		}
	}
	
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
	[moviePresets release];
	[xsdDateTimeFormat release];
	[super dealloc];
}

#pragma mark Actions

- (IBAction)changeServerDetails:(id)sender;
{
	DLog(@"changeServerDetails action called by %@, url = %@, user = %@, pass = %@", 
		sender, settings.url, settings.username, [settings.password md5hex]);
	
	if ( [settings.url length] > 0 && [settings.username length] > 0 && [settings.password length] > 0 ) {
		[self populateCollectionPopUp];

		NSURL *url = [NSURL URLWithString:settings.url];
		NSString *keychainPass = [KeychainUtils passwordForURL:url username:settings.username];
		if ( ![settings.password isEqualToString:keychainPass] ) {
			[KeychainUtils storePassword:settings.password forURL:url username:settings.username];
		}
	}
}

- (IBAction)changeExportOriginals:(id)sender {
	const BOOL enabled = ![settings isExportOriginals];
	[mSizePopUp setEnabled:enabled];
	[mQualityPopUp setEnabled:enabled];
}

- (IBAction)changeExportOriginalMovies:(id)sender  {
	const BOOL enabled = ![settings isExportOriginalMovies];
	[moviePresetPopUp setEnabled:enabled];
}

- (IBAction)refreshCollections:(id)sender {
	[self populateCollectionPopUp];
}

#pragma mark NSFileManager delegate

- (BOOL)fileManager:(NSFileManager *)fileManager shouldRemoveItemAtPath:(NSString *)path {
	return YES;
}

- (BOOL)fileManager:(NSFileManager *)fileManager shouldCopyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath {
	if ( [fileManager fileExistsAtPath:dstPath] ) {
		[fileManager removeItemAtPath:dstPath error:nil];
	}
	return YES;
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
	return NO;
}

- (NSString*)getDestinationPath
{
	// adapted from http://cocoawithlove.com/2009/07/temporary-files-and-folders-in-cocoa.html
	
	NSString *tempDirectoryTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"matte-iphoto-export.XXXXXX"];
	const char *tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
	char *tempDirectoryNameCString = (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
	strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
	
	char *result = mkdtemp(tempDirectoryNameCString);
	NSString *tempDirectoryPath = nil;
	if ( result ) {
		tempDirectoryPath = [[NSFileManager defaultManager]
									   stringWithFileSystemRepresentation:tempDirectoryNameCString
									   length:strlen(result)];
	}
	free(tempDirectoryNameCString);
	return tempDirectoryPath;
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
	NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
	fileManager.delegate = self;
	
	NSString *albumName = nil;
	NSString *outputDir = context.exportDir;
	
	if ( albumIndex ) {
		albumName = [exportMgr albumNameAtIndex:[albumIndex intValue]];
		outputDir = [outputDir stringByAppendingPathComponent:albumName];
	}
	
	if ( ![fileManager fileExistsAtPath:outputDir] ) {
		[fileManager createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:nil];
	}
	
	NSString *destFileName = nil;
	NSString *srcFile = nil;
	const BOOL movie = [exportMgr originalIsMovieAtIndex:i];
	if ( movie ) {
		srcFile = [exportMgr sourcePathAtIndex:i];
		if ( settings.exportOriginalMovies ) {
			destFileName = [srcFile lastPathComponent];
		} else {
			if ( context.exportMovieExtension == nil ) {
				context.exportMovieExtension = @"m4v";
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
	} else {
		// skip, we've already exported this
		return YES;
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
		if ( movie && !settings.exportOriginalMovies ) {
			[self exportMovie:[exportMgr sourcePathAtIndex:i] toFile:outputPath context:context];
			[context export:outputPath atArchivePath:archivePath];
			succeeded = context.succeeded;
		} else if ( !movie && !settings.exportOriginals ) {
			succeeded = [exportMgr exportImageAtIndex:i dest:outputPath options:context.imageOptions];
			[context export:outputPath atArchivePath:archivePath];
		} else {
			// for movie files, we have to get the "sourcePath", because the "imagePath" points
			// to a JPG image extracted from the movie
			
			NSString *src = (movie
							 ? [exportMgr sourcePathAtIndex:i]
							 : [exportMgr imagePathAtIndex:i]);
			DLog(@"Exporting original file %@", src);
			[context export:src atArchivePath:archivePath];
			succeeded = YES;
		}
	}
	return succeeded;
}

- (void)performExport:(NSString *)path
{
	DLog(@"performExport path: %@", path);
	
	int count = [exportMgr imageCount];
	//int albumCount =  (settings.autoAlbum ? [exportMgr albumCount] : 0);
	cancelExport = NO;
	int i;
	
	MatteExportContext *context = [[MatteExportContext alloc] initWithSettings:settings];
	context.exportDir = path;
	context.zip = [[[ZipArchive alloc] init] autorelease];
	NSString *zipPath = [context.exportDir stringByAppendingPathComponent:@"data.zip"];
	[context.zip CreateZipFile2:zipPath];
	
	// Do the export
	[self lockProgress];
	progress.indeterminateProgress = NO;
	progress.totalItems = count - 1;
	[progress.message autorelease];
	progress.message = @"Exporting";
	[self unlockProgress];
	
	for(i = 0; cancelExport == NO && context.succeeded == YES && i < count; i++)
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
				context.succeeded = [self exportItem:i inAlbum:albumIndex context:context];
				if ( !context.succeeded ) {
					break;
				}
			}
		} else {
			context.succeeded = [self exportItem:i inAlbum:nil context:context];
		}
	}
	
	// Handle failure
	if (!context.succeeded) {
		[self lockProgress];
		//[progress.message autorelease];
		//progress.message = @"Unable to complete export";
		[self cancelExport];
		progress.shouldCancel = YES;
		[self unlockProgress];
		[context release];
		return;
	}
	
	// write CollectionExport as metadata.xml
	NSString *metadataFile = [context.exportDir stringByAppendingPathComponent:@"metadata.xml"];
	DLog(@"Writing colExport as XML to %@", metadataFile);
	[context.metadata saveAsXml:metadataFile];
	
	// add metadata.xml to archive
	[context export:metadataFile atArchivePath:[metadataFile lastPathComponent]];
	
	[context.zip CloseZipFile2];
	context.zip = nil;
	
	[self postToServer:context zipFile:zipPath];
	
	// clean up our temp dir now
	[[NSFileManager defaultManager] removeItemAtPath:context.exportDir error:nil];
	
	[context release];
}

- (void) updateProgress:(NSString *)message 
			   currItem:(unsigned long)currItem
			 totalItems:(unsigned long)totalItems
			 shouldStop:(BOOL)stop
		  indeterminate:(BOOL)indeterminate
{
	[self lockProgress];
	[progress.message autorelease];
	progress.message = [message retain];
	progress.currentItem = currItem;
	progress.totalItems = totalItems;
	progress.shouldStop = stop;
	progress.indeterminateProgress = indeterminate;
	[self unlockProgress];
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

#pragma mark Web service calls

- (void) populateCollectionPopUp
{
	GetCollectionListRequest *request = [[[GetCollectionListRequest alloc] init] autorelease];
	request.username = settings.username;
	request.password = settings.password;

	NSURL *url = [NSURL URLWithString:[settings.url stringByAppendingPathComponent:MatteWebServiceUrlPath]];
	NSXMLDocument *response = [SoapURLConnection request:url
												 message:request
												delegate:self
										  updateProgress:NO];
	
	if ( !response ) {
		return;
	}
	
	// check for error
	NSError *error;
	NSString *faultMsg = [SoapURLConnection faultString:response error:&error];
	if ( error ) {
		NSLog(@"Could not check for SOAP fault: %@", error);
		return;
	}
	if ( faultMsg != nil ) {
		// oops, error on server
		NSLog(@"Error calling GetCollectionListRequest: %@", faultMsg);
	} else {
		// <GetCollectionListResponse xmlns="http://msqr.us/xsd/matte"><collection collection-id="1" name="Foo"/></GetCollectionListResponse>
		// NSXML XPath doesn't support namespaces properly... have to use convoluted work-around
		NSArray *nodes = [response nodesForXPath:@"//*[local-name() = 'collection']" error:&error];
		NSUInteger i = 0;
		NSUInteger len = [nodes count];
		[mCollectionPopUp removeAllItems];
		if ( len > 0 ) {
			NSXMLElement *collectionElement;
			for ( ; i < len; i++ ) {
				collectionElement = nodes[i];
				NSString *name = [[collectionElement attributeForName:@"name"] stringValue];
				NSInteger collectionId = [[[collectionElement attributeForName:@"collection-id"] stringValue] integerValue];
				NSMenuItem *item = [[mCollectionPopUp menu] 
									addItemWithTitle:name
									action:nil
									keyEquivalent:[NSString stringWithFormat:@"%lu", (unsigned long)i]];
				[item setTag:collectionId];
			}
		}
	}
}

/*
- (void) populateCollectionPopUp
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
	endpoint = [[[settings url] stringByAppendingString:MatteWebServiceUrlPath] UTF8String];
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
	int numCollections = response.__sizecollection;
	for ( i = 0; i < numCollections; i++ ) {
		NSString *title = [NSString stringWithCString:response.collection[i].name encoding:NSUTF8StringEncoding];
		NSString *format = [NSString stringWithFormat:@"%d", i];
		NSMenuItem *item = [[mCollectionPopUp menu] 
							addItemWithTitle:title
							action:nil
							keyEquivalent:format];
		[item setTag:response.collection[i].collection_id];
	}
	
	if ( ![mCollectionPopUp selectItemWithTag:settings.collectionId] && numCollections > 0 ) {
		[mCollectionPopUp selectItemAtIndex:0];
		settings.collectionId = [mCollectionPopUp itemAtIndex:0].tag;
	}
	soap_end(soap);
	soap_done(soap);
}
*/

- (void)encodeBase64:(NSString *)inPath appendingToDestination:(NSString *)b64FilePath {
	// remember previous progress so we can track encoding progress
	[self lockProgress];
	[progress.message autorelease];
	progress.message = [@"Encoding media archive..." retain];
	unsigned long prevTotal = progress.totalItems;
	unsigned long prevCurr = progress.currentItem;
	progress.totalItems = 100;
	progress.currentItem = 0;
	[self unlockProgress];
	
	const unsigned long long inputLength = [NSFileManager sizeOfFileAtPath:inPath];
	__block unsigned long long bytesEncoded = 0;

	DLog(@"Base64 encoding %@ to %@", inPath, [b64FilePath lastPathComponent]);
	NSURL *inURL = [NSURL fileURLWithPath:inPath];
	CFErrorRef error = NULL;
	CFReadStreamRef readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, (CFURLRef)inURL);
	SecTransformRef readTransform = SecTransformCreateReadTransformWithReadStream(readStream);
	SecGroupTransformRef group = SecTransformCreateGroupTransform();
	SecTransformRef encoder = SecEncodeTransformCreate(kSecBase64Encoding, &error);
	SecTransformConnectTransforms(readTransform, kSecTransformOutputAttributeName, encoder, kSecTransformInputAttributeName, group, &error);
	NSOutputStream *writeStream = [[NSOutputStream alloc] initToFileAtPath:b64FilePath append:YES];
	
	dispatch_queue_t serialQueue = dispatch_queue_create("magoffin.matte.b64encode", DISPATCH_QUEUE_SERIAL);
	
	__block BOOL finished = NO;
	NSCondition *condition = [NSCondition new];
	[condition lock];
	[writeStream open];
	SecTransformExecuteAsync(group, serialQueue, ^(CFTypeRef message, CFErrorRef error, Boolean isFinal) {
		if ( message != NULL ) {
			NSData *data = (NSData *)message;
			[writeStream write:[data bytes] maxLength:[data length]];
			bytesEncoded += [data length];
			[self lockProgress];
			progress.currentItem = (unsigned long)(((double)bytesEncoded / (double)inputLength) * 100);
			[self unlockProgress];
		}
		if ( isFinal || error != NULL ) {
			if ( error != NULL ) {
				DLog(@"Error encoding Base64 data: %@", [(NSError *)error localizedDescription]);
				CFRelease(error);
			}
			[condition lock];
			finished = YES;
			[condition signal];
			[condition unlock];
		}
	});
	[condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:600]];
	[condition unlock];

	dispatch_release(serialQueue);
	[writeStream close];
	[writeStream release];
	if ( encoder != NULL ) {
		CFRelease(encoder);
	}
	if ( group != NULL ) {
		CFRelease(group);
	}
	if ( readTransform != NULL ) {
		CFRelease(readTransform);
	}
	if ( readStream != NULL ) {
		CFRelease(readStream);
	}
	
	// restore previous progress now
 	[self lockProgress];
	progress.totalItems = prevTotal;
	progress.currentItem = prevCurr;
	[self unlockProgress];
	
	// unlock condition
	[taskCondition lock];
	taskRunning = NO;
	[taskCondition signal];
	[taskCondition unlock];
}

- (void) postToServer:(MatteExportContext *)context zipFile:(NSString *)zipPath
{
	AddMediaRequest *request = [[[AddMediaRequest alloc] init] autorelease];
	request.username = settings.username;
	request.password = settings.password;
	request.collectionId = settings.collectionId;
	request.mediaCount = [context outputCount] - 1;
	request.mediaFile = zipPath;
	request.metadata = context.metadata;
	
	NSString *mergedRequestFilePath = [[zipPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"add-media-request.xml"];
	[@"" writeToFile:mergedRequestFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil]; // create empty file for NSFileHandle
	NSFileHandle *mergedOutput = [NSFileHandle fileHandleForWritingAtPath:mergedRequestFilePath];
	
	SoapMessage *message = request;
	
	// now copy SOAP request XML to temp file, merging Base64-encoded content into middle
	NSData *xmlData = [request asData];
	NSData *placeholderData = [kFileDataPlaceholder dataUsingEncoding:NSUTF8StringEncoding];
	NSRange placeholderRange = [xmlData rangeOfData:placeholderData options:0 range:NSMakeRange(0, [xmlData length])];
	if ( placeholderRange.location != NSNotFound ) {
		[mergedOutput writeData:[xmlData subdataWithRange:NSMakeRange(0, placeholderRange.location)]];
		[mergedOutput synchronizeFile];
		
		// encode zip archive manually as Base64 because NSXML will load entire file in memory
		[taskCondition lock];
		taskRunning = YES;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[self encodeBase64:zipPath appendingToDestination:mergedRequestFilePath];
		});
		while ( taskRunning ) {
			[taskCondition wait];
		}
		[taskCondition unlock];
		
		NSRange tailRange = NSMakeRange(placeholderRange.location+placeholderRange.length, 
										[xmlData length] - placeholderRange.location - placeholderRange.length);
		[mergedOutput seekToEndOfFile];
		[mergedOutput writeData:[xmlData subdataWithRange:tailRange]];
		[mergedOutput synchronizeFile];
		[mergedOutput closeFile];
		
		message = [[[PreformattedMessage alloc] initWithSoapMessage:request withContentsOfFile:mergedRequestFilePath] autorelease];
	}
		
	[self updateProgress:@"Posting data to Matte" currItem:0 totalItems:100 shouldStop:NO indeterminate:NO];
	
	NSXMLDocument *response = [SoapURLConnection request:[NSURL URLWithString:[settings.url stringByAppendingPathComponent:MatteWebServiceUrlPath]]
												 message:message
												delegate:self
										  updateProgress:YES];
	
	if ( !response ) {
		return;
	}
	
	// check for error
	NSError *error;
	NSString *faultMsg = [SoapURLConnection faultString:response error:&error];
	if ( error ) {
		NSLog(@"Could not check for SOAP fault: %@", error);
		return;
	}
	if ( faultMsg != nil ) {
		// oops, error on server
		[self updateProgress:faultMsg currItem:-1 totalItems:-1 shouldStop:NO indeterminate:NO];
	} else {
		// <m:AddMediaResponse xmlns:m="http://msqr.us/xsd/matte" success="true" ticket="1" />
		// NSXML XPath doesn't support namespaces properly... have to use convoluted work-around
		NSArray *nodes = [response nodesForXPath:@"(//*[local-name() = 'AddMediaResponse'])[1]" error:&error];
		BOOL success = YES;
		if ( [nodes count] > 0 ) {
			success = [[[nodes[0] attributeForName:@"success"] stringValue] isEqualToString:@"true"];
			DLog(@"Import successful: %@ work ticket: %lld", (success ? @"YES" : @"NO"),
				 [[[nodes[0] attributeForName:@"ticket"] stringValue] longLongValue]);
		}
		// wait for work ticket to complete? for now just finish up
		[self updateProgress:(success ? nil : @"Import did not succeed on server, no message returned.") 
					currItem:-1
				  totalItems:-1
				  shouldStop:success
			   indeterminate:NO];
	}
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(SoapURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    connection.response = response;
}

- (void)connection:(SoapURLConnection *)connection didReceiveData:(NSData *)data {
    [connection appendData:data];
}

- (void)connectionDidFinishLoading:(SoapURLConnection *)connection {
    [connection setFinished:YES];
}

- (void)connection:(SoapURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten 
 totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
	if ( !connection.updateProgress ) {
		return;
	}
	int percent = (int)round(((double)totalBytesWritten / (double)totalBytesExpectedToWrite) * 100);
	[self lockProgress];
	progress.currentItem = percent;
	[self unlockProgress];
}

- (void)connection:(SoapURLConnection *)connection didFailWithError:(NSError *)error {
	DLog(@"Error with connection: %@", [error localizedDescription]);
	// TODO handle error
    [connection setFinished:YES];
}

#pragma mark Movie export support

// return an array of suitable export preset names
- (NSArray *)availablePresets {
	// this is hard-coded for just movies
	NSSet *availablePresets = [NSSet setWithArray:[AVAssetExportSession allExportPresets]];
	DLog(@"Available movie presets: %@", availablePresets);
	NSArray *allowedPresets = @[AVAssetExportPresetAppleM4VCellular,
								AVAssetExportPresetAppleM4ViPod,
								AVAssetExportPresetAppleM4V480pSD,
								AVAssetExportPresetAppleM4VAppleTV,
								AVAssetExportPresetAppleM4VWiFi,
								AVAssetExportPresetAppleM4V720pHD,
								AVAssetExportPresetAppleProRes422LPCM];
	NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:[allowedPresets count]];
	for ( NSString *preset in allowedPresets ) {
		if ( [availablePresets containsObject:preset] ) {
			[filtered addObject:preset];
		}
	}
	return filtered;
}

static dispatch_time_t getDispatchTimeFromSeconds(float seconds) {
	long long milliseconds = seconds * 1000.0;
	dispatch_time_t waitTime = dispatch_time( DISPATCH_TIME_NOW, 1000000LL * milliseconds );
	return waitTime;
}

- (void)exportMovie:(NSString *)srcPath toFile:(NSString *)destPath context:(MatteExportContext *)context {
	[self lockProgress];
	[progress.message autorelease];
	progress.message = [[NSString stringWithFormat:@"Exporting movie %@...", [srcPath lastPathComponent]] retain];
	unsigned long prevTotal = progress.totalItems;
	unsigned long prevCurr = progress.currentItem;
	progress.totalItems = 100;
	progress.currentItem = 0;
	[self unlockProgress];

	AVURLAsset *movie = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:srcPath] options:nil];
	NSString *presetName = moviePresets[settings.selectedPresetIndex];
	AVAssetExportSession *session = [AVAssetExportSession exportSessionWithAsset:movie presetName:presetName];
	session.outputURL = [NSURL fileURLWithPath:destPath];
	session.outputFileType = [session supportedFileTypes][0];
	session.shouldOptimizeForNetworkUse = YES;

	dispatch_semaphore_t sessionWaitSemaphore = dispatch_semaphore_create(0);

	[session exportAsynchronouslyWithCompletionHandler:^{
		dispatch_semaphore_signal(sessionWaitSemaphore);
	}];
	
	do {
		if ( cancelExport ) {
			[session cancelExport];
		} else {
			dispatch_time_t dispatchTime = DISPATCH_TIME_FOREVER;
			dispatchTime = getDispatchTimeFromSeconds(1.0f);
			[self lockProgress];
			unsigned long val = (unsigned long)roundf([session progress] * 100);
			progress.currentItem = val;
			[self unlockProgress];
			dispatch_semaphore_wait(sessionWaitSemaphore, dispatchTime);
		}
	} while ( [session status] < AVAssetExportSessionStatusCompleted );

	if ( [session status] != AVAssetExportSessionStatusCompleted ) {
		NSLog(@"Failed to export movie: %@", [session error]);
		context.succeeded = NO;
		[self lockProgress];
		[progress.message autorelease];
		progress.message = [[NSString stringWithFormat:@"Error exporting movie: %@", [[session error] localizedDescription]] retain];
		[self unlockProgress];
	}
	
	[self lockProgress];
	[progress.message autorelease];
	progress.message = nil;
	progress.totalItems = prevTotal;
	progress.currentItem = prevCurr;
	[self unlockProgress];
}

@end
