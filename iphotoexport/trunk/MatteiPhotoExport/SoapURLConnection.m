//
//  SoapURLConnection.m
//  MatteiPhotoExport
//
//  Created by Matt on 11/5/10.
//  Copyright 2010 . All rights reserved.
//

#import "SoapURLConnection.h"

#import "SoapMessage.h"

@implementation SoapURLConnection

@synthesize finished, response, updateProgress;

- (void) dealloc {
	self.response = nil;
    [data release], data = nil;
    [super dealloc];
}

- (NSData *) data {
    return data;
}

- (void) appendData:(NSData *)value {
    if ( !data ) {
        data = [[NSMutableData alloc] init];
    }
    [data appendData:value];
}

#pragma mark Class methods

+ (NSXMLDocument *) request:(NSURL *)url 
					message:(SoapMessage *)message 
				   delegate:(id)delegate {
	NSData *xmlData = [[message asXml] XMLDataWithOptions:NSXMLNodeOptionsNone];
#ifdef DEBUG
	DLog(@"Creating import.xml file in %@", NSTemporaryDirectory());
	if ( ![xmlData writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"import.xml"] atomically:YES] ) {
        NSLog(@"Could not write document out...");
    }
#endif
	
	// execute ws call
	NSMutableURLRequest *httpRequest = [[[NSMutableURLRequest alloc] initWithURL:url
																	 cachePolicy:NSURLRequestReloadIgnoringCacheData 
																 timeoutInterval:60.0] autorelease];
    [httpRequest setHTTPMethod:@"POST"];
	[httpRequest setHTTPBody:xmlData];
	[httpRequest setValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [httpRequest setValue:[NSString stringWithFormat:@"%d", [xmlData length]] forHTTPHeaderField:@"Content-Length"];
    [httpRequest setValue:message.action forHTTPHeaderField:@"SOAPAction"];
    SoapURLConnection *conn = [[[SoapURLConnection alloc] initWithRequest:httpRequest delegate:delegate] autorelease];
	
    NSXMLDocument *response = nil;
	while ( !conn.finished ) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
	DLog(@"%@ response: %@", message.action, [[[NSString alloc] initWithData:[conn data] encoding:NSUTF8StringEncoding] autorelease]);
	NSError *error = nil;
	response = [[[NSXMLDocument alloc] initWithData:[conn data] options:NSXMLNodeOptionsNone error:&error] autorelease];
	if ( error ) {
		NSLog(@"Could not complete SOAP AddMediaRequest: %@", error);
		return nil;
	}
	return response;
}

+ (NSString *) faultString:(NSXMLDocument *)soapResponse error:(NSError **)error {
	NSArray *nodes = [soapResponse nodesForXPath:@"(//faultstring)[1]/text()" error:error];
	if ( *error ) {
		return nil;
	}
	if ( [nodes count] > 0 ) {
		// oops, error on server
		return [[nodes objectAtIndex:0] stringValue];
	}
	return nil;
}

@end
