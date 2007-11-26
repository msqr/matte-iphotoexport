//
//  MatteExportController.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/25/07.
//

#import <Cocoa/Cocoa.h>
#import "ExportPluginProtocol.h"

@interface MatteExportController : NSObject <ExportPluginProtocol> {
	id <ExportImageProtocol> mExportMgr;
	
	IBOutlet NSBox <ExportPluginBoxProtocol> *mSettingsBox;
	IBOutlet NSControl *mFirstView;
	
	IBOutlet NSPopUpButton		*mSizePopUp;
	IBOutlet NSPopUpButton		*mQualityPopUp;
	IBOutlet NSTextField		*mUrlText;
	IBOutlet NSTextField		*mUsernameText;
	IBOutlet NSSecureTextField	*mPasswordText;
	IBOutlet NSButton			*mAutoAlbumButton;
	IBOutlet NSTextField		*mAlbumNameText;
	IBOutlet NSTextField		*mAlbumCommentsText;
	
	NSString *mExportDir;
	int mSize;
	int mQuality;
	NSString *mUrl;
	NSString *mUsername;
	NSString *mPassword;
	BOOL mAutoAlbum;
	NSString *mAlbumName;
	NSString *mAlbumComments;
	
	ExportPluginProgress mProgress;
	NSLock *mProgressLock;
	BOOL mCancelExport;
}

// overrides
- (void)awakeFromNib;
- (void)dealloc;

// getters/setters
- (NSString *)exportDir;
- (void)setExportDir:(NSString *)dir;
- (int)size;
- (void)setSize:(int)size;
- (int)quality;
- (void)setQuality:(int)quality;
- (NSString *)url;
- (void)setUrl:(NSString *)url;
- (NSString *)username;
- (void)setUsername:(NSString *)username;
- (NSString *)password;
- (void)setPassword:(NSString *)password;
- (NSString *)albumName;
- (void)setAlbumName:(NSString *)albumName;
- (NSString *)albumComments;
- (void)setAlbumComments:(NSString *)albumComments;
- (BOOL)autoAlbum;
- (void)setAutoAlbum:(BOOL)autoAlbum;

@end
