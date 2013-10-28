//
//  MatteExportController.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/25/07.
//  Copyright 2007 Matt Magoffin.
//

#import "MatteExportController.h"

#include <openssl/bio.h>
#include <openssl/evp.h>

#import "AddMediaRequest.h"
#import "CollectionExport.h"
#import "GetCollectionListRequest.h"
#import "KeychainUtils.h"
#import "MatteExportContext.h"
#import "MatteExportSettings.h"
#import "PreformattedMessage.h"
#import "SoapURLConnection.h"
#import "ZipArchive.h"

NSString * const MatteExportPluginVersion = @"1.1";
NSString * const MatteWebServiceUrlPath = @"/ws/Matte";

@interface MatteExportController (MovieSupport)
- (NSArray *)availableComponents;
- (NSData *)getExportSettings:(NSUInteger)selectedComponentIndex;
- (BOOL)componentSupportsSettingsDialog:(NSUInteger)selectedComponentIndex;
- (void)setupQTMovie:(NSDictionary *)attributes;
- (void)exportMovie:(NSDictionary *)dest;
@end

@interface MatteExportController (Private)
- (void) updateProgress:(NSString *)message 
			   currItem:(unsigned long)currItem
			 totalItems:(unsigned long)totalItems
			 shouldStop:(BOOL)stop
		  indeterminate:(BOOL)indeterminate;
- (void) setupImageExportOptions:(ImageExportOptions *)imageOptions;
- (void) populateCollectionPopUp;
- (void) postToServer:(MatteExportContext *)context zipFile:(NSString *)zipPath;
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
		NSString *name = component[@"name"];
		unsigned int i;
		for ( i = 2; [mQTComponentPopUp itemWithTitle:name] != nil; ++i) {
			name = [NSString stringWithFormat:@"%@-%u", component[@"name"], i];
		}
		[mQTComponentPopUp addItemWithTitle:name];
	}
	[mQTComponentPopUp selectItemAtIndex:settings.selectedComponentIndex];
	
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
	[qtComponents release];
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

#pragma mark NSFileManager delegate

- (BOOL)fileManager:(NSFileManager *)fileManager shouldRemoveItemAtPath:(NSString *)path
{
	return YES;
}

- (BOOL)fileManager:(NSFileManager *)fileManager shouldCopyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath
{
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
	if ( !result )
	{
		// handle directory creation failure
		return nil;
	}
	
	NSString *tempDirectoryPath = [[NSFileManager defaultManager]
								   stringWithFileSystemRepresentation:tempDirectoryNameCString
								   length:strlen(result)];
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
	
	if ( [exportMgr originalIsMovieAtIndex:i] ) {
		srcFile = [exportMgr sourcePathAtIndex:i];
		if ( settings.exportOriginalMovies ) {
			destFileName = [srcFile lastPathComponent];
		} else {
			NSDictionary *qtAttr = @{QTMovieFileNameAttribute: [exportMgr sourcePathAtIndex:i],
									QTMovieOpenAsyncOKAttribute: @NO};
			[self performSelectorOnMainThread:@selector(setupQTMovie:) withObject:qtAttr waitUntilDone:YES];
			
			if ( context.exportMovieExtension == nil ) {
				NSNumber *subtype = qtComponents[settings.selectedComponentIndex][@"subtypeLong"];
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
		if ( movie != nil ) {
			[taskCondition lock];
			taskRunning = YES;
			NSDictionary *params = @{@"outputPath": outputPath,
									@"context": context};
			[NSThread detachNewThreadSelector:@selector(exportMovie:) toTarget:self withObject:params];
			while ( taskRunning ) {
				[taskCondition wait];
			}
			[taskCondition unlock];
			[context export:outputPath atArchivePath:archivePath];
			succeeded = context.succeeded;
		} else if ( movie == nil && !settings.exportOriginals ) {
			succeeded = [exportMgr exportImageAtIndex:i dest:outputPath options:context.imageOptions];
			[context export:outputPath atArchivePath:archivePath];
		} else {
			// for movie files, we have to get the "sourcePath", because the "imagePath" points
			// to a JPG image extracted from the movie
			
			NSString *src = ([exportMgr originalIsMovieAtIndex:i]
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

static NSString * const kBase64FileExtension = @"b64";

- (void) encodeBase64:(NSDictionary *)params
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSString *inPath = params[@"src"];
	NSString *b64FilePath = params[@"dest"];
	
	// remember previous progress so we can track encoding progress
	[self lockProgress];
	[progress.message autorelease];
	progress.message = [@"Encoding media archive..." retain];
	unsigned long prevTotal = progress.totalItems;
	unsigned long prevCurr = progress.currentItem;
	progress.totalItems = 100;
	progress.currentItem = 0;
	[self unlockProgress];
	
	unsigned long long inputLength = [NSFileManager sizeOfFileAtPath:inPath];
	
	DLog(@"Base64 encoding %@ to %@", inPath, [b64FilePath lastPathComponent]);
	BIO * output = BIO_new_file([b64FilePath cStringUsingEncoding:NSUTF8StringEncoding], "a");
	if ( !output ) {
		// TODO handle error
		DLog(@"Error creating Base64 output stream %@", b64FilePath);
	} else {
	
		// Push on a Base64 filter so that writing to the buffer encodes the data
		BIO * b64 = BIO_new(BIO_f_base64());
		output = BIO_push(b64, output);
		
		// Encode all the data
		unsigned long long bytesEncoded = 0;
		NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:inPath];
		while ( YES ) {
			NSAutoreleasePool *bufferPool = [[NSAutoreleasePool alloc] init];
			NSData *memBuffer = [fh readDataOfLength:4096];
			if ( [memBuffer length] < 1 ) {
				break;
			}
			BIO_write(output, [memBuffer bytes], [memBuffer length]);
			bytesEncoded += [memBuffer length];
			[self lockProgress];
			progress.currentItem = (unsigned long)(((double)bytesEncoded / (double)inputLength) * 100);
			[self unlockProgress];
			[bufferPool drain];
		}
		
		BIO_flush(output);
		BIO_free_all(output);
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
	
	[pool drain];
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
		NSDictionary *encodeParams = @{@"src": zipPath, @"dest": mergedRequestFilePath};
		[NSThread detachNewThreadSelector:@selector(encodeBase64:) toTarget:self withObject:encodeParams];
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

// QT export code adapted from http://cocoadev.com/index.pl?QTMovieExportSettings

- (BOOL)componentSupportsSettingsDialog:(NSUInteger)selectedComponentIndex
{
	NSDictionary *qtComponent = qtComponents[selectedComponentIndex];
	NSString *subtype = qtComponent[@"subtype"];
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
	
	cd.componentType = QTMovieExportType;
	cd.componentSubType = 0;
	cd.componentManufacturer = 0;
	//cd.componentFlags = canMovieExportFiles;
	//cd.componentFlagsMask = canMovieExportFiles;
	
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
			
			NSDictionary *dictionary = @{@"name": nameStr, @"component": [NSData dataWithBytes:&c length:sizeof(c)],
										@"type": type, @"subtype": subType, 
										@"typeLong": typeNum, @"subtypeLong": subTypeNum,
										@"manufacturer": manufacturer, @"manufacturerLong": manufacturerNum};
			
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
	return nil;
	/* FIXME
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
	*/
}

- (void)setupQTMovie:(NSDictionary *)attributes
{
	[QTMovie enterQTKitOnThread];
	[movie release], movie = nil;
	NSError *error = nil;
	DLog(@"Setting up QTMovie %@", attributes);
	movie = [[QTMovie movieWithAttributes:attributes error:&error] retain];
	if ( error ) {
		NSLog(@"Unable to open movie: %@", error);
	} else {
		[movie setDelegate:self];
		[movie detachFromCurrentThread];
	}
	[QTMovie exitQTKitOnThread];
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

- (void)exportMovie:(NSDictionary *)params
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *dest = params[@"outputPath"];
	MatteExportContext *context = params[@"context"];
	
	[self lockProgress];
	unsigned long prevTotal = progress.totalItems;
	unsigned long prevCurr = progress.currentItem;
	progress.totalItems = 100;
	progress.currentItem = 0;
	[self unlockProgress];
	[QTMovie enterQTKitOnThread];
	[movie attachToCurrentThread];
	NSDictionary *component = qtComponents[settings.selectedComponentIndex];
	NSDictionary *exportAttrs;
	if ( [self componentSupportsSettingsDialog:settings.selectedComponentIndex] ) {
		exportAttrs = @{QTMovieExport: @YES,
					   QTMovieExportType: component[@"subtypeLong"],
					   QTMovieExportManufacturer: component[@"manufacturerLong"],
					   QTMovieExportSettings: settings.exportMovieSettings};
	} else {
		exportAttrs = @{QTMovieExport: @YES,
					   QTMovieExportType: component[@"subtypeLong"]};
	}
	NSError *error = nil;
	if ( ![movie writeToFile:dest withAttributes:exportAttrs error:&error] ) {
		NSLog(@"Failed to export movie: %@", error);
		context.succeeded = NO;
		[self lockProgress];
		[progress.message autorelease];
		progress.message = [[NSString stringWithFormat:@"Error exporting movie: %@", [error localizedDescription]] retain];
		[self unlockProgress];
	}
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
