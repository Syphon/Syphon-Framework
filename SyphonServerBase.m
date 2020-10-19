//
//  SyphonIOSurfaceServer.m
//  Syphon
//
//  Created by Tom Butterworth on 26/04/2019.
//

#import "SyphonServerBase.h"
#import "SyphonServerConnectionManager.h"
#import "SyphonPrivate.h"

@interface SyphonServerBase (Private)
+ (void)retireRemainingServers;
@end

__attribute__((destructor))
static void finalizer()
{
    [SyphonServerBase retireRemainingServers];
}

@implementation SyphonServerBase
{
    // Once our minimum version reaches 10.12, replace
    // this with os_unfair_lock
    OSSpinLock _mdLock;

    NSString *_name;
    NSString *_uuid;
    BOOL _broadcasts;

    SyphonServerConnectionManager *_connectionManager;
    id<NSObject> _activityToken;

    IOSurfaceRef _surface;
    BOOL _pushPending;
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    if ([key isEqualToString:@"serverDescription"])
    {
        return [NSSet setWithObject:@"name"];
    }
    else
    {
        return [super keyPathsForValuesAffectingValueForKey:key];
    }
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey
{
    BOOL automatic;
    if ([theKey isEqualToString:@"hasClients"])
    {
        automatic=NO;
    }
    else
    {
        automatic=[super automaticallyNotifiesObserversForKey:theKey];
    }
    return automatic;
}

- (id)init
{
    return [self initWithName:@"" options:nil];
}

- (instancetype)initWithName:(NSString *)serverName options:(NSDictionary *)options
{
    self = [super init];
    if (self)
    {
        if (serverName == nil)
        {
            serverName = @"";
        }
        _name = [serverName copy];
        _uuid = SyphonCreateUUIDString();

        NSNumber *isPrivate = [options objectForKey:SyphonServerOptionIsPrivate];
        if ([isPrivate respondsToSelector:@selector(boolValue)]
            && [isPrivate boolValue] == YES)
        {
            _broadcasts = NO;
        }
        else
        {
            _broadcasts = YES;
        }

        _mdLock = OS_SPINLOCK_INIT;

        _connectionManager = [[SyphonServerConnectionManager alloc] initWithUUID:_uuid options:options];

        [_connectionManager addObserver:self forKeyPath:@"hasClients" options:NSKeyValueObservingOptionPrior context:nil];

        if (![_connectionManager start])
        {
            [self release];
            return nil;
        }

        if (_broadcasts)
        {
            [[self class] addServerToRetireList:_uuid];
            [self startBroadcasts];
        }

        // Prevent this app from being suspended or terminated eg if it goes off-screen (MacOS 10.9+ only)
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        if ([processInfo respondsToSelector:@selector(beginActivityWithOptions:reason:)])
        {
            NSActivityOptions options = NSActivityAutomaticTerminationDisabled | NSActivityBackground;
            _activityToken = [[processInfo beginActivityWithOptions:options reason:_uuid] retain];
        }
    }
    return self;
}

- (void)dealloc
{
    SYPHONLOG(@"Server deallocing, name: %@, UUID: %@", self.name, [self.serverDescription objectForKey:SyphonServerDescriptionUUIDKey]);
    // Don't call anything in the subclass, it has already been dealloc'd
    [self destroyBaseResources];
    [_name release];
    [_uuid release];
    [super dealloc];
}

- (NSString*)name
{
    OSSpinLockLock(&_mdLock);
    NSString *result = [_name retain];
    OSSpinLockUnlock(&_mdLock);
    return [result autorelease];
}

- (void)setName:(NSString *)newName
{
    if (newName == nil)
    {
        newName = @"";
    }
    [newName copy];
    [newName retain];
    OSSpinLockLock(&_mdLock);
    [_name release];
    _name = newName;
    OSSpinLockUnlock(&_mdLock);
    [(SyphonServerConnectionManager *)_connectionManager setName:newName];
    if (_broadcasts)
    {
        [self broadcastServerUpdate];
    }
}

- (NSDictionary *)serverDescription
{
    NSDictionary *surface = ((SyphonServerConnectionManager *)_connectionManager).surfaceDescription;
    if (!surface) surface = [NSDictionary dictionary];
    /*
     Getting the app name: helper tasks, command-line tools, etc, don't have a NSRunningApplication instance,
     so fall back to NSProcessInfo in those cases, then use an empty string as a last resort.

     http://developer.apple.com/library/mac/qa/qa1544/_index.html

     */
    NSString *appName = [[NSRunningApplication currentApplication] localizedName];
    if (!appName) appName = [[NSProcessInfo processInfo] processName];
    if (!appName) appName = [NSString string];

    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInt:kSyphonDictionaryVersion], SyphonServerDescriptionDictionaryVersionKey,
            self.name, SyphonServerDescriptionNameKey,
            _uuid, SyphonServerDescriptionUUIDKey,
            appName, SyphonServerDescriptionAppNameKey,
            [NSArray arrayWithObject:surface], SyphonServerDescriptionSurfacesKey,
            nil];
}

- (BOOL)hasClients
{
    return ((SyphonServerConnectionManager *)_connectionManager).hasClients;
}

- (void)stop
{
    [self destroyBaseResources];
}

- (void)destroyBaseResources
{
    if (_connectionManager)
    {
        [(SyphonServerConnectionManager *)_connectionManager removeObserver:self forKeyPath:@"hasClients"];
        [(SyphonServerConnectionManager *)_connectionManager stop];
        [(SyphonServerConnectionManager *)_connectionManager release];
        _connectionManager = nil;
    }
    if (_broadcasts)
    {
        [self stopBroadcasts];
        [[self class] removeServerFromRetireList:_uuid];
    }
    if (_activityToken)
    {
        [[NSProcessInfo processInfo] endActivity:_activityToken];
        [_activityToken release];
        _activityToken = nil;
    }
    if (_surface != NULL)
    {
        CFRelease(_surface);
        _surface = NULL;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"hasClients"])
    {
        if ([[change objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue] == YES)
        {
            [self willChangeValueForKey:keyPath];
        }
        else
        {
            [self didChangeValueForKey:keyPath];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)destroySurface
{
    // TODO: are we locking here?
    if (_surface)
    {
        CFRelease(_surface);
        _surface = NULL;
    }
}

- (IOSurfaceRef)copySurfaceForWidth:(size_t)width height:(size_t)height options:(NSDictionary<NSString *, id> *)options
{
    // TODO: are we locking here?
    if (!_surface || IOSurfaceGetWidth(_surface) != width || IOSurfaceGetHeight(_surface) != height)
    {
        if (_surface)
        {
            CFRelease(_surface);
        }
        // init our texture and IOSurface
        NSDictionary<NSString *, id> *surfaceAttributes = @{(NSString*)kIOSurfaceIsGlobal: @(YES),
                                                            (NSString*)kIOSurfaceWidth: @(width),
                                                            (NSString*)kIOSurfaceHeight: @(height),
                                                            (NSString*)kIOSurfaceBytesPerElement: @(4U)};

        _surface =  IOSurfaceCreate((CFDictionaryRef) surfaceAttributes);

        _pushPending = YES;
    }
    if (_surface)
    {
        // Return retained (caller releases)
        CFRetain(_surface);
    }
    return _surface;
}

- (void)publish
{
    if (_pushPending)
    {
        // Push the new surface ID to clients
        [(SyphonServerConnectionManager *)_connectionManager setSurfaceID:IOSurfaceGetID(_surface)];
        _pushPending = NO;
    }
    [(SyphonServerConnectionManager *)_connectionManager publishNewFrame];
}
#pragma mark Notification Handling for Server Presence
/*
 Broadcast and discovery is done via NSDistributedNotificationCenter. Servers notify announce, change (currently only affects name) and retirement.
 Discovery is done by a discovery-request notification, to which servers respond with an announce.

 If this gets unweildy we could move it into a SyphonBroadcaster class

 */

/*
 We track all instances and send a retirement broadcast for any which haven't been stopped when the code is unloaded.
 */

static OSSpinLock mRetireListLock = OS_SPINLOCK_INIT;
static NSMutableSet *mRetireList = nil;

+ (void)addServerToRetireList:(NSString *)serverUUID
{
    OSSpinLockLock(&mRetireListLock);
    if (mRetireList == nil)
    {
        mRetireList = [[NSMutableSet alloc] initWithCapacity:1U];
    }
    [mRetireList addObject:serverUUID];
    OSSpinLockUnlock(&mRetireListLock);
}

+ (void)removeServerFromRetireList:(NSString *)serverUUID
{
    OSSpinLockLock(&mRetireListLock);
    [mRetireList removeObject:serverUUID];
    if ([mRetireList count] == 0)
    {
        [mRetireList release];
        mRetireList = nil;
    }
    OSSpinLockUnlock(&mRetireListLock);
}

+ (void)retireRemainingServers
{
    // take the set out of the global so we don't hold the spin-lock while we send the notifications
    // even though there should never be contention for this
    NSMutableSet *mySet = nil;
    OSSpinLockLock(&mRetireListLock);
    mySet = mRetireList;
    mRetireList = nil;
    OSSpinLockUnlock(&mRetireListLock);
    for (NSString *uuid in mySet) {
        SYPHONLOG(@"Retiring a server at code unload time because it was not properly stopped");
        NSDictionary *fakeServerDescription = [NSDictionary dictionaryWithObject:uuid forKey:SyphonServerDescriptionUUIDKey];
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SyphonServerRetire
                                                                       object:SyphonServerDescriptionUUIDKey
                                                                     userInfo:fakeServerDescription
                                                           deliverImmediately:YES];
    }
    [mySet release];
}

- (void)startBroadcasts
{
    // Register for any Announcement Requests.
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDiscoveryRequest:) name:SyphonServerAnnounceRequest object:nil];

    [self broadcastServerAnnounce];
}

- (void) handleDiscoveryRequest:(NSNotification*) aNotification
{
    SYPHONLOG(@"Got Discovery Request");

    [self broadcastServerAnnounce];
}

- (void)broadcastServerAnnounce
{
    if (_broadcasts)
    {
        NSDictionary *description = self.serverDescription;
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SyphonServerAnnounce
                                                                       object:[description objectForKey:SyphonServerDescriptionUUIDKey]
                                                                     userInfo:description
                                                           deliverImmediately:YES];
    }
}

- (void)broadcastServerUpdate
{
    NSDictionary *description = self.serverDescription;
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SyphonServerUpdate
                                                                   object:[description objectForKey:SyphonServerDescriptionUUIDKey]
                                                                 userInfo:description
                                                       deliverImmediately:YES];
}

- (void)stopBroadcasts
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    NSDictionary *description = self.serverDescription;
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SyphonServerRetire
                                                                   object:[description objectForKey:SyphonServerDescriptionUUIDKey]
                                                                 userInfo:description
                                                       deliverImmediately:YES];
}

@end
