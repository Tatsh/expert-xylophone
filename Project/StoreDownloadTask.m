#import "StoreDownloadTask.h"

@implementation StoreDownloadTask

- (instancetype)initWithURL:(NSString *)url path:(NSString *)path AddObject:(id)addObject {
    self = [super init];
    if (self) {
        self.fileURL = [[NSString alloc] initWithString:url];
        self.filePath = [[NSString alloc] initWithString:path];
        self.addObject = addObject;
    }
    return self;
}

@end
