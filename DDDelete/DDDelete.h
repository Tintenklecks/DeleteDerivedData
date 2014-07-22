#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@interface DDDelete : NSObject

@property (nonatomic, strong) NSBundle *bundle;

+ (DDDelete *)sharedPlugin;

@end
