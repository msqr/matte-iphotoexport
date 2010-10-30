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

@interface MatteExportController : NSObject <ExportPluginProtocol> {
	id <ExportImageProtocol> exportMgr;
	MatteExportSettings *settings;
	
	IBOutlet NSBox <ExportPluginBoxProtocol> *mSettingsBox;
	IBOutlet NSControl *mFirstView;
	
	IBOutlet NSPopUpButton		*mCollectionPopUp;
	IBOutlet NSPopUpButton		*mSizePopUp;
	IBOutlet NSPopUpButton		*mQualityPopUp;
	
	NSString *exportDir;
	QTMovie *movie;
	
	NSTask *zipTask;
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
- (void)setupImageExportOptions:(ImageExportOptions *)imageOptions;

// getters/setters
- (NSString *)exportDir;
- (void)setExportDir:(NSString *)dir;

@end
