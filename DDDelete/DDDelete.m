// DDDelete.m
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


#import "DDDelete.h"

static DDDelete *sharedPlugin;


@interface NSObject (IDEKit)
+ (id)workspaceWindowControllers;
- (id)derivedDataLocation;
@end



@interface DDDelete ()
@end

@implementation DDDelete

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

+ (DDDelete *)sharedPlugin {
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin {
    if (self = [super init]) {
        self.bundle = plugin;
        [self createMenuItem];
    }
    return self;
}

#pragma mark - Private

- (void)createMenuItem {
    NSMenuItem *windowMenuItem = [[NSApp mainMenu] itemWithTitle:@"Window"];
    NSMenuItem *pluginManagerItem = [[NSMenuItem alloc] initWithTitle:@"Clear Derived Data"
                                                               action:@selector(clearAllDerivedData)
                                                        keyEquivalent:@"6"];
    pluginManagerItem.keyEquivalentModifierMask = NSCommandKeyMask | NSShiftKeyMask;
    pluginManagerItem.target = self;
    
    [windowMenuItem.submenu insertItem:pluginManagerItem
                               atIndex:[windowMenuItem.submenu indexOfItemWithTitle:@"Bring All to Front"] - 1];
}

- (void)clearAllDerivedData {
    for (NSString *subdirectory in[self derivedDataSubdirectoryPaths]) {
        [self removeDirectoryAtPath:subdirectory];
    }
    
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Derived Data cleared!";
    notification.informativeText = @"The DERIVED DATA folder is cleared from the crab it usualy contains.";
    notification.soundName = NSUserNotificationDefaultSoundName;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

#pragma mark - Private

- (NSString *)derivedDataLocation {
    NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
    if (workspaceWindowControllers.count < 1) return nil;
    
    id workspace = [workspaceWindowControllers[0] valueForKey:@"_workspace"];
    id workspaceArena = [workspace valueForKey:@"_workspaceArena"];
    [workspaceArena derivedDataLocation]; // Initialize custom location
    return [[workspaceArena derivedDataLocation] valueForKey:@"_pathString"];
}

- (NSArray *)derivedDataSubdirectoryPaths {
    NSMutableArray *workspaceDirectories = [NSMutableArray array];
    NSString *derivedDataPath  = [self derivedDataLocation];
    if (derivedDataPath) {
        NSError *error         = nil;
        NSArray *directories   = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:derivedDataPath error:&error];
        if (error) {
            NSLog(@"DD-E: Error while fetching derived data subdirectories: %@", derivedDataPath);
        }
        else {
            for (NSString *subdirectory in directories) {
                NSString *removablePath = [derivedDataPath stringByAppendingPathComponent:subdirectory];
                [workspaceDirectories addObject:removablePath];
            }
        }
    }
    return workspaceDirectories;
}

- (void)removeDirectoryAtPath:(NSString *)path {
    NSLog(@"DD-E: Clearing Derived Data at Path: %@", path);
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    if (error) {
        NSLog(@"DD-E: Failed to remove all Derived Data: %@ Path: %@", [error description], path);
        [self showErrorAlert:error forPath:path];
    }
    else if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        // Retry once
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self showErrorAlert:[NSError errorWithDomain:[NSString stringWithFormat:@"DerivedData Exterminator - removing directory failed after multiple attempts: %@", path] code:668 userInfo:nil] forPath:path];
    }
}

- (void)showErrorAlert:(NSError *)error forPath:(NSString *)path {
    NSString *message = [NSString stringWithFormat:@"An error occurred while removing %@:\n\n %@", path, [error localizedDescription]];
    NSAlert *alert    = [NSAlert alertWithMessageText:message defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
    [alert runModal];
}

@end
