//
//  MatteExportController.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/25/07.
//

#import <Cocoa/Cocoa.h>
#import "ExportPluginProtocol.h"
#import "MatteExportSettings.h"

@class MatteExportSettings;

@interface MatteExportController : NSObject <ExportPluginProtocol> {
	id <ExportImageProtocol> exportMgr;
	MatteExportSettings *settings;
	
	IBOutlet NSBox <ExportPluginBoxProtocol> *mSettingsBox;
	IBOutlet NSControl *mFirstView;
	IBOutlet NSTextField *mVersionLabel;
	
	IBOutlet NSSecureTextField	*mPasswordField;
	IBOutlet NSPopUpButton		*mCollectionPopUp;
	IBOutlet NSPopUpButton		*mSizePopUp;
	IBOutlet NSPopUpButton		*mQualityPopUp;
	
	IBOutlet NSPopUpButton		*moviePresetPopUp;
	
	NSDateFormatter *xsdDateTimeFormat;
	NSArray *moviePresets;
	BOOL taskRunning;
	NSCondition *taskCondition;
	
	ExportPluginProgress progress;
	NSLock *progressLock;
	BOOL cancelExport;
}

@property (readonly) MatteExportSettings *settings;

// overrides
- (void)awakeFromNib;
- (void)dealloc;

// internal
- (IBAction)changeServerDetails:(id)sender;
- (IBAction)changeExportOriginals:(id)sender;
- (IBAction)changeExportOriginalMovies:(id)sender;
- (IBAction)refreshCollections:(id)sender;

@end
