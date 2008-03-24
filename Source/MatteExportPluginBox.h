//
//  MatteExportPluginBox.h
//  MatteiPhotoExport
//
//  Created by Matt on 11/25/07.
//

#import <Cocoa/Cocoa.h>
#import "ExportPluginProtocol.h"
#import "ExportPluginBoxProtocol.h"

@interface MatteExportPluginBox : NSBox <ExportPluginBoxProtocol> {
	IBOutlet id <ExportPluginProtocol> mPlugin;
}

- (BOOL)performKeyEquivalent:(NSEvent *)anEvent;

@end
