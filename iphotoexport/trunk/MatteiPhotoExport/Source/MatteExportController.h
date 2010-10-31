//
//  MatteExportController.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/25/07.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>
#import "ExportPluginProtocol.h"
#import "MatteExportSettings.h"

@class MatteExportSettings;

@interface MatteExportController : NSObject <ExportPluginProtocol> {
	id <ExportImageProtocol> exportMgr;
	MatteExportSettings *settings;
	
	IBOutlet NSBox <ExportPluginBoxProtocol> *mSettingsBox;
	IBOutlet NSControl *mFirstView;
	IBOutlet NSTextField *mVersionLabel;
	
	IBOutlet NSPopUpButton		*mCollectionPopUp;
	IBOutlet NSPopUpButton		*mSizePopUp;
	IBOutlet NSPopUpButton		*mQualityPopUp;
	
	IBOutlet NSPopUpButton		*mQTComponentPopUp;
	IBOutlet NSButton			*mQTSettingButton;
	
	NSDateFormatter *xsdDateTimeFormat;
	NSArray *qtComponents;
	QTMovie *movie;
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
- (IBAction)populateCollections:(id)sender;
- (IBAction)changeExportOriginals:(id)sender;

- (IBAction)changeExportOriginalMovies:(id)sender;
- (IBAction)changeExportMovieType:(id)sender;
- (IBAction)configureMovieExportSettings:(id)sender;

@end
