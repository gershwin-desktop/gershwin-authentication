#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <unistd.h>
#import <pwd.h>
#import <sys/types.h>

@interface GSAuthWindow : NSObject
{
    NSWindow *window;
    NSTextField *usernameField;
    NSSecureTextField *passwordField;
    NSTextField *messageLabel;
    NSTextField *statusLabel;
    NSButton *authenticateButton;
    NSButton *cancelButton;
    NSString *requestingApp;
    NSString *requestedAction;
    NSString *commandToRun;
    NSArray *commandArguments;
    BOOL authenticated;
    NSString *userPassword;
}

- (id)initWithApp:(NSString *)app action:(NSString *)action command:(NSString *)cmd arguments:(NSArray *)args;
- (void)createWindow;
- (void)show;
- (void)authenticate:(id)sender;
- (void)cancel:(id)sender;
- (BOOL)verifyPassword:(NSString *)password forUser:(NSString *)username;
- (int)executeCommandWithSudo;
- (void)setStatus:(NSString *)status isError:(BOOL)isError;
- (BOOL)isAuthenticated;

@end

@implementation GSAuthWindow

- (id)initWithApp:(NSString *)app action:(NSString *)action command:(NSString *)cmd arguments:(NSArray *)args
{
    self = [super init];
    if (self) {
        requestingApp = [app retain];
        requestedAction = [action retain];
        commandToRun = [cmd retain];
        commandArguments = [args retain];
        authenticated = NO;
        userPassword = nil;
    }
    return self;
}

- (void)dealloc
{
    [requestingApp release];
    [requestedAction release];
    [commandToRun release];
    [commandArguments release];
    [userPassword release];
    [window release];
    [super dealloc];
}

- (void)createWindow
{
    NSRect contentRect = NSMakeRect(0, 0, 450, 280);
    
    window = [[NSWindow alloc] initWithContentRect:contentRect
                                         styleMask:NSTitledWindowMask | NSClosableWindowMask
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setTitle:@"Authentication Required"];
    [window center];
    [window setLevel:NSModalPanelWindowLevel];
    [window setReleasedWhenClosed:NO];
    
    NSView *contentView = [window contentView];
    
    // Lock icon - use text emoji
    NSTextField *lockText = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 180, 64, 64)];
    [lockText setStringValue:@""];
    [lockText setFont:[NSFont systemFontOfSize:48]];
    [lockText setBezeled:NO];
    [lockText setDrawsBackground:NO];
    [lockText setEditable:NO];
    [lockText setSelectable:NO];
    [lockText setAlignment:NSCenterTextAlignment];
    [contentView addSubview:lockText];
    [lockText release];
    
    // Main message
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 210, 330, 24)];
    [titleLabel setStringValue:@"Authentication is required"];
    [titleLabel setBezeled:NO];
    [titleLabel setDrawsBackground:NO];
    [titleLabel setEditable:NO];
    [titleLabel setSelectable:NO];
    [titleLabel setFont:[NSFont boldSystemFontOfSize:14]];
    [contentView addSubview:titleLabel];
    [titleLabel release];
    
    // Description message
    messageLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 170, 330, 40)];
    NSString *message = [NSString stringWithFormat:@"%@ wants to %@", 
                         requestingApp ? requestingApp : @"An application",
                         requestedAction ? requestedAction : @"perform a privileged operation"];
    [messageLabel setStringValue:message];
    [messageLabel setBezeled:NO];
    [messageLabel setDrawsBackground:NO];
    [messageLabel setEditable:NO];
    [messageLabel setSelectable:NO];
    [contentView addSubview:messageLabel];
    
    // Username label
    NSTextField *userLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 130, 80, 20)];
    [userLabel setStringValue:@"Username:"];
    [userLabel setBezeled:NO];
    [userLabel setDrawsBackground:NO];
    [userLabel setEditable:NO];
    [userLabel setSelectable:NO];
    [contentView addSubview:userLabel];
    [userLabel release];
    
    // Username field
    usernameField = [[NSTextField alloc] initWithFrame:NSMakeRect(190, 130, 240, 22)];
    struct passwd *pw = getpwuid(getuid());
    if (pw) {
        [usernameField setStringValue:[NSString stringWithUTF8String:pw->pw_name]];
    }
    [usernameField setEditable:NO];  // Username is fixed to current user
    [contentView addSubview:usernameField];
    
    // Password label
    NSTextField *passLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 95, 80, 20)];
    [passLabel setStringValue:@"Password:"];
    [passLabel setBezeled:NO];
    [passLabel setDrawsBackground:NO];
    [passLabel setEditable:NO];
    [passLabel setSelectable:NO];
    [contentView addSubview:passLabel];
    [passLabel release];
    
    // Password field
    passwordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(190, 95, 240, 22)];
    [passwordField setTarget:self];
    [passwordField setAction:@selector(authenticate:)];
    [contentView addSubview:passwordField];
    
    // Status label
    statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(100, 65, 330, 20)];
    [statusLabel setStringValue:@""];
    [statusLabel setBezeled:NO];
    [statusLabel setDrawsBackground:NO];
    [statusLabel setEditable:NO];
    [statusLabel setSelectable:NO];
    [statusLabel setFont:[NSFont systemFontOfSize:10]];
    [statusLabel setTextColor:[NSColor grayColor]];
    [contentView addSubview:statusLabel];
    
    // Cancel button
    cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(250, 20, 90, 32)];
    [cancelButton setTitle:@"Cancel"];
    [cancelButton setBezelStyle:NSRoundedBezelStyle];
    [cancelButton setTarget:self];
    [cancelButton setAction:@selector(cancel:)];
    [contentView addSubview:cancelButton];
    
    // Authenticate button
    authenticateButton = [[NSButton alloc] initWithFrame:NSMakeRect(345, 20, 90, 32)];
    [authenticateButton setTitle:@"OK"];
    [authenticateButton setBezelStyle:NSRoundedBezelStyle];
    [authenticateButton setTarget:self];
    [authenticateButton setAction:@selector(authenticate:)];
    [authenticateButton setKeyEquivalent:@"\r"];
    [contentView addSubview:authenticateButton];
}

- (void)show
{
    [window makeKeyAndOrderFront:nil];
    [window makeFirstResponder:passwordField];
}

- (void)setStatus:(NSString *)status isError:(BOOL)isError
{
    [statusLabel setStringValue:status];
    [statusLabel setTextColor:isError ? [NSColor redColor] : [NSColor grayColor]];
}

- (BOOL)verifyPassword:(NSString *)password forUser:(NSString *)username
{
    // Clear any existing sudo timestamp to force password prompt
    NSTask *clearTask = [[NSTask alloc] init];
    [clearTask setLaunchPath:@"sudo"];
    [clearTask setArguments:@[@"-k"]];
    
    @try {
        [clearTask launch];
        [clearTask waitUntilExit];
    }
    @catch (NSException *exception) {
        NSLog(@"Failed to clear sudo timestamp: %@", exception);
    }
    [clearTask release];
    
    // Attempt authentication with password
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"sudo"];
    [task setArguments:@[@"-S", @"-v", @"-p", @""]];
    
    NSPipe *inputPipe = [NSPipe pipe];
    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    
    [task setStandardInput:inputPipe];
    [task setStandardOutput:outputPipe];
    [task setStandardError:errorPipe];
    
    BOOL success = NO;
    
    @try {
        [task launch];
        
        NSFileHandle *writeHandle = [inputPipe fileHandleForWriting];
        NSString *passwordWithNewline = [password stringByAppendingString:@"\n"];
        [writeHandle writeData:[passwordWithNewline dataUsingEncoding:NSUTF8StringEncoding]];
        [writeHandle closeFile];
        
        [task waitUntilExit];
        success = ([task terminationStatus] == 0);
        
        if (!success) {
            NSFileHandle *errorHandle = [errorPipe fileHandleForReading];
            NSData *errorData = [errorHandle readDataToEndOfFile];
            NSString *errorString = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
            NSLog(@"Authentication failed: %@", errorString);
            [errorString release];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception during authentication: %@", exception);
        success = NO;
    }
    
    [task release];
    
    return success;
}

- (int)executeCommandWithSudo
{
    if (!commandToRun || !userPassword) {
        return 1;
    }
    
    // Build the sudo command
    NSMutableArray *sudoArgs = [NSMutableArray arrayWithObjects:@"-S", commandToRun, nil];
    if (commandArguments) {
        [sudoArgs addObjectsFromArray:commandArguments];
    }
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"sudo"];
    [task setArguments:sudoArgs];
    
    NSPipe *inputPipe = [NSPipe pipe];
    [task setStandardInput:inputPipe];
    
    int returnCode = 1;
    
    @try {
        [task launch];
        
        // Provide password to sudo
        NSFileHandle *writeHandle = [inputPipe fileHandleForWriting];
        NSString *passwordWithNewline = [userPassword stringByAppendingString:@"\n"];
        [writeHandle writeData:[passwordWithNewline dataUsingEncoding:NSUTF8StringEncoding]];
        [writeHandle closeFile];
        
        [task waitUntilExit];
        returnCode = [task terminationStatus];
    }
    @catch (NSException *exception) {
        NSLog(@"Exception during command execution: %@", exception);
        returnCode = 1;
    }
    
    [task release];
    
    // Clear sudo timestamp for security
    NSTask *clearTask = [[NSTask alloc] init];
    [clearTask setLaunchPath:@"sudo"];
    [clearTask setArguments:@[@"-k"]];
    
    @try {
        [clearTask launch];
        [clearTask waitUntilExit];
    }
    @catch (NSException *exception) {}
    [clearTask release];
    
    return returnCode;
}

- (void)authenticate:(id)sender
{
    NSString *username = [usernameField stringValue];
    NSString *password = [passwordField stringValue];
    
    if ([password length] == 0) {
        [self setStatus:@"Please enter your password" isError:YES];
        return;
    }
    
    [authenticateButton setEnabled:NO];
    [cancelButton setEnabled:NO];
    [self setStatus:@"Authenticating..." isError:NO];
    
    if ([self verifyPassword:password forUser:username]) {
        authenticated = YES;
        userPassword = [password retain];
        [window close];
        [NSApp stop:nil];
    } else {
        [authenticateButton setEnabled:YES];
        [cancelButton setEnabled:YES];
        [passwordField setStringValue:@""];
        
        // Simple shake effect
        NSRect frame = [window frame];
        CGFloat offset = 5.0;
        NSRect f1 = NSMakeRect(frame.origin.x - offset, frame.origin.y, 
                               frame.size.width, frame.size.height);
        NSRect f2 = NSMakeRect(frame.origin.x + offset, frame.origin.y, 
                               frame.size.width, frame.size.height);
        
        [window setFrame:f1 display:YES];
        [NSThread sleepForTimeInterval:0.05];
        [window setFrame:f2 display:YES];
        [NSThread sleepForTimeInterval:0.05];
        [window setFrame:frame display:YES];
        
        [self setStatus:@"Authentication failed - incorrect password" isError:YES];
        [window makeFirstResponder:passwordField];
    }
}

- (void)cancel:(id)sender
{
    authenticated = NO;
    [window close];
    [NSApp stop:nil];
}

- (BOOL)isAuthenticated
{
    return authenticated;
}

@end

int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // Initialize the application
    [NSApplication sharedApplication];
    
    const char *appName = "Application";
    const char *action = "perform administrative tasks";
    NSString *commandToRun = nil;
    NSMutableArray *commandArgs = nil;
    
    // Parse command line arguments
    // gsauth [app_name] [action] [--exec command [args...]]
    int i = 1;
    if (argc > i && strncmp(argv[i], "--", 2) != 0) {
        appName = argv[i++];
    }
    if (argc > i && strncmp(argv[i], "--", 2) != 0) {
        action = argv[i++];
    }
    
    // Check for --exec flag
    if (argc > i && strcmp(argv[i], "--exec") == 0) {
        i++;
        if (argc > i) {
            commandToRun = [NSString stringWithUTF8String:argv[i++]];
            commandArgs = [NSMutableArray array];
            while (i < argc) {
                [commandArgs addObject:[NSString stringWithUTF8String:argv[i++]]];
            }
        }
    }
    
    // Create and show the authentication window
    GSAuthWindow *authWindow = [[GSAuthWindow alloc] 
        initWithApp:[NSString stringWithUTF8String:appName]
        action:[NSString stringWithUTF8String:action]
        command:commandToRun
        arguments:commandArgs];
    
    [authWindow createWindow];
    [authWindow show];
    
    // Run the event loop
    [NSApp run];
    
    // Get the result
    BOOL authenticated = [authWindow isAuthenticated];
    int returnCode = 1;
    
    if (authenticated) {
        if (commandToRun) {
            // Execute the command with sudo if provided
            returnCode = [authWindow executeCommandWithSudo];
        } else {
            // Just return success for authentication
            returnCode = 0;
        }
    }
    
    // Clean up
    [authWindow release];
    [pool release];
    
    return returnCode;
}
