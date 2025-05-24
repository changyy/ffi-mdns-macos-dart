#import <Foundation/Foundation.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import "mdns_ffi.h"

// Forward declaration
@class MdnsDelegate;

// 搜尋管理結構
typedef struct {
    NSString *serviceType;
    NSNetServiceBrowser *browser;
    NSMutableArray *services;
    MdnsDelegate *delegate;
    NSTimer *queryTimer;
    NSTimer *durationTimer;
    int queryIntervalMs;
    int totalDurationMs;
    int queriesSent;
} SearchContext;

// 改用字典來管理多個搜尋上下文
static NSMutableDictionary *searchContexts = nil;
static DeviceFoundCallback globalCallback = NULL;
static DeviceFoundJsonCallback globalJsonCallback = NULL;
static NSTimer *runLoopTimer = nil;
static int totalActiveSearches = 0;

// 新增 debug mode 全域變數
static int globalDebugMode = 0;
static int g_mdns_silent_mode = 0;

void set_mdns_silent_mode(int silent) {
    g_mdns_silent_mode = silent ? 1 : 0;
}

@interface MdnsDelegate : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@property (nonatomic, strong) NSString *serviceType;
@property (nonatomic, assign) int queriesSent;
@end

@implementation MdnsDelegate

- (instancetype)initWithServiceType:(NSString*)serviceType {
    self = [super init];
    if (self) {
        _serviceType = serviceType;
        _queriesSent = 0;
        if (!g_mdns_silent_mode) NSLog(@"🔧 MdnsDelegate initialized for %@: %p", serviceType, self);
    }
    return self;
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser {
    self.queriesSent++;
    if (!g_mdns_silent_mode) NSLog(@"🔍 Query #%d: Browser searching for %@", self.queriesSent, self.serviceType);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser 
           didFindService:(NSNetService *)service 
               moreComing:(BOOL)moreComing {
    if (!g_mdns_silent_mode) NSLog(@"✅ Found service: %@ (type: %@) via query #%d - moreComing: %@", 
          service.name, service.type, self.queriesSent, moreComing ? @"YES" : @"NO");
    
    // 找到對應的搜尋上下文
    SearchContext *context = NULL;
    for (NSString *key in searchContexts.allKeys) {
        SearchContext *ctx = (SearchContext *)[searchContexts[key] pointerValue];
        if ([ctx->serviceType isEqualToString:self.serviceType]) {
            context = ctx;
            break;
        }
    }
    
    if (context && context->services) {
        // 檢查是否已經存在（避免重複）
        BOOL alreadyExists = NO;
        for (NSNetService *existingService in context->services) {
            if ([existingService.name isEqualToString:service.name] && 
                [existingService.type isEqualToString:service.type]) {
                alreadyExists = YES;
                break;
            }
        }
        
        if (!alreadyExists) {
            [context->services addObject:service];
            if (!g_mdns_silent_mode) NSLog(@"📊 New device added. Total for %@: %lu", 
                  self.serviceType, (unsigned long)context->services.count);
            
            service.delegate = self;
            [service resolveWithTimeout:10.0];
        } else {
            if (!g_mdns_silent_mode) NSLog(@"🔄 Device %@ already known, skipping", service.name);
        }
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser 
         didRemoveService:(NSNetService *)service 
               moreComing:(BOOL)moreComing {
    if (!g_mdns_silent_mode) NSLog(@"❌ Service removed: %@ (type: %@)", service.name, service.type);
    
    // 從對應的服務列表中移除
    for (NSString *key in searchContexts.allKeys) {
        SearchContext *ctx = (SearchContext *)[searchContexts[key] pointerValue];
        if ([ctx->serviceType isEqualToString:self.serviceType]) {
            [ctx->services removeObject:service];
            break;
        }
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser 
             didNotSearch:(NSDictionary<NSString *,NSNumber *> *)errorDict {
    if (!g_mdns_silent_mode) NSLog(@"🚫 Search failed for %@ with error: %@", self.serviceType, errorDict);
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser {
    if (!g_mdns_silent_mode) NSLog(@"🛑 Browser stopped searching for %@", self.serviceType);
}

#pragma mark - NSNetServiceDelegate

- (void)netServiceDidResolveAddress:(NSNetService *)service {
    if (globalDebugMode) NSLog(@"✅ Successfully resolved service: %@ (type: %@)", service.name, service.type);
    
    NSString *ip = nil;
    int port = (int)service.port;
    for (NSUInteger i = 0; i < service.addresses.count; i++) {
        NSData *addrData = service.addresses[i];
        struct sockaddr *addr = (struct sockaddr *)[addrData bytes];
        if (addr->sa_family == AF_INET) {
            struct sockaddr_in *ipv4 = (struct sockaddr_in *)addr;
            char ipStr[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &(ipv4->sin_addr), ipStr, sizeof(ipStr));
            ip = [NSString stringWithUTF8String:ipStr];
            break;
        }
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"type"] = @"device";
    dict[@"ip"] = ip ?: @"";
    dict[@"port"] = @(port);
    dict[@"name"] = service.name ?: @"";
    dict[@"type_name"] = service.type ?: @"";
    dict[@"hostname"] = service.hostName ?: @"";
    // interfaceIndex 與 flags 僅 iOS 支援，macOS 不支援，已移除
    // 收集 TXT record
    if (service.TXTRecordData) {
        NSDictionary *txtDict = [NSNetService dictionaryFromTXTRecordData:service.TXTRecordData];
        NSMutableDictionary *txtDecoded = [NSMutableDictionary dictionary];
        for (NSString *key in txtDict) {
            NSData *valueData = txtDict[key];
            NSString *val = @"";
            if (valueData && valueData.length > 0) {
                val = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding] ?: @"";
            }
            txtDecoded[key] = val;
        }
        dict[@"txt"] = txtDecoded;
    }
    // 其他可用屬性可依需求擴充
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (!error && globalJsonCallback && ip) {
        NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        globalJsonCallback([jsonStr UTF8String]);
    } else if (error) {
        if (globalDebugMode) NSLog(@"❌ JSON encode error: %@", error);
        if (globalJsonCallback) {
            NSDictionary *errDict = @{@"type": @"error", @"message": error.localizedDescription ?: @"JSON encode error"};
            NSData *errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
            NSString *errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
            globalJsonCallback([errStr UTF8String]);
        }
    }
}

- (void)netService:(NSNetService *)sender 
      didNotResolve:(NSDictionary<NSString *,NSNumber *> *)errorDict {
    if (globalDebugMode) NSLog(@"❌ Failed to resolve service %@: %@", sender.name, errorDict);
    if (globalJsonCallback) {
        NSDictionary *errDict = @{@"type": @"error", @"message": [NSString stringWithFormat:@"Failed to resolve service %@: %@", sender.name, errorDict]};
        NSData *errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
        NSString *errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
        globalJsonCallback([errStr UTF8String]);
    }
}

@end

// Run Loop 管理
void startRunLoopProcessing() {
    if (!runLoopTimer && totalActiveSearches > 0) {
        if (!g_mdns_silent_mode) NSLog(@"🔄 Starting Run Loop processing for %d active searches...", totalActiveSearches);
        runLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                       repeats:YES
                                                         block:^(NSTimer * _Nonnull timer) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        }];
    }
}

void stopRunLoopProcessing() {
    if (runLoopTimer && totalActiveSearches == 0) {
        if (!g_mdns_silent_mode) NSLog(@"⏹️ Stopping Run Loop processing...");
        [runLoopTimer invalidate];
        runLoopTimer = nil;
    }
}

// 定期查詢的回調函數
void periodicQueryCallback(SearchContext *context) {
    if (context && context->browser) {
        if (!g_mdns_silent_mode) NSLog(@"🔄 Sending periodic query for %@ (interval: %dms)", 
              context->serviceType, context->queryIntervalMs);
        
        // 停止當前搜尋然後重新開始（這會觸發新的查詢）
        [context->browser stop];
        
        // 短暫延遲後重新開始
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [context->browser searchForServicesOfType:context->serviceType inDomain:@"local."];
        });
    }
}

// 搜尋結束的回調函數
void searchDurationCallback(SearchContext *context) {
    if (context) {
        if (!g_mdns_silent_mode) NSLog(@"⏰ Search duration completed for %@ (sent %d queries)", 
              context->serviceType, context->queriesSent);
        
        // 停止定期查詢定時器
        if (context->queryTimer) {
            [context->queryTimer invalidate];
            context->queryTimer = nil;
        }
        
        // 停止搜尋
        if (context->browser) {
            [context->browser stop];
        }
        
        totalActiveSearches--;
        
        // 清理搜尋上下文
        NSString *key = context->serviceType;
        if (searchContexts[key]) {
            free(context);
            [searchContexts removeObjectForKey:key];
        }
        
        // 如果沒有活動搜尋了，停止 Run Loop
        if (totalActiveSearches == 0) {
            stopRunLoopProcessing();
        }
        
        if (!g_mdns_silent_mode) NSLog(@"🧹 Cleaned up search context for %@ (remaining active: %d)", 
              key, totalActiveSearches);
    }
}

// 新的週期性搜尋函數
void start_mdns_periodic_scan(const char* service_type, 
                             int query_interval_ms, 
                             int total_duration_ms, 
                             DeviceFoundCallback cb) {
    NSString *serviceTypeStr = [NSString stringWithUTF8String:service_type];
    
    if (!g_mdns_silent_mode) {
        NSLog(@"🚀 start_mdns_periodic_scan called:");
        NSLog(@"   Service: %s", service_type);
        NSLog(@"   Query interval: %dms", query_interval_ms);
        NSLog(@"   Total duration: %dms", total_duration_ms);
    }
    
    // 初始化字典
    if (!searchContexts) {
        searchContexts = [[NSMutableDictionary alloc] init];
    }
    
    // 檢查是否已經在搜尋這個服務
    if (searchContexts[serviceTypeStr]) {
        if (!g_mdns_silent_mode) NSLog(@"⏸️ Already scanning for service type: %s", service_type);
        return;
    }
    
    globalCallback = cb;
    
    // 建立新的搜尋上下文
    SearchContext *context = malloc(sizeof(SearchContext));
    context->serviceType = serviceTypeStr;
    context->services = [[NSMutableArray alloc] init];
    context->delegate = [[MdnsDelegate alloc] initWithServiceType:serviceTypeStr];
    context->browser = [[NSNetServiceBrowser alloc] init];
    context->browser.delegate = context->delegate;
    context->queryIntervalMs = query_interval_ms;
    context->totalDurationMs = total_duration_ms;
    context->queriesSent = 0;
    
    // 儲存上下文
    searchContexts[serviceTypeStr] = [NSValue valueWithPointer:context];
    
    totalActiveSearches++;
    
    // 啟動 Run Loop 處理
    startRunLoopProcessing();
    
    // 開始初始搜尋
    if (!g_mdns_silent_mode) NSLog(@"🎬 Starting initial search for: %@", serviceTypeStr);
    [context->browser searchForServicesOfType:serviceTypeStr inDomain:@"local."];
    
    // 設定定期查詢定時器
    if (query_interval_ms > 0) {
        double intervalSeconds = query_interval_ms / 1000.0;
        context->queryTimer = [NSTimer scheduledTimerWithTimeInterval:intervalSeconds
                                                              repeats:YES
                                                                block:^(NSTimer * _Nonnull timer) {
            periodicQueryCallback(context);
        }];
        if (!g_mdns_silent_mode) NSLog(@"⏰ Set up periodic query timer: every %.1fs", intervalSeconds);
    }
    
    // 設定總時間限制定時器
    if (total_duration_ms > 0) {
        double durationSeconds = total_duration_ms / 1000.0;
        context->durationTimer = [NSTimer scheduledTimerWithTimeInterval:durationSeconds
                                                                 repeats:NO
                                                                    block:^(NSTimer * _Nonnull timer) {
            searchDurationCallback(context);
        }];
        if (!g_mdns_silent_mode) NSLog(@"⏰ Set up duration timer: %.1fs total", durationSeconds);
    }
    
    if (!g_mdns_silent_mode) NSLog(@"✅ Periodic search setup complete for: %@", serviceTypeStr);
}

// 原有的簡單搜尋函數（保持向後相容）
void start_mdns_scan(const char* service_type, DeviceFoundCallback cb) {
    // 使用預設值：不定期查詢，無時間限制
    start_mdns_periodic_scan(service_type, 0, 0, cb);
}

// 新的週期性搜尋函數 (JSON)
void start_mdns_periodic_scan_json(const char* service_type, int query_interval_ms, int total_duration_ms, DeviceFoundJsonCallback cb, int debug_mode) {
    NSString *serviceTypeStr = [NSString stringWithUTF8String:service_type];
    if (!searchContexts) {
        searchContexts = [[NSMutableDictionary alloc] init];
    }
    if (searchContexts[serviceTypeStr]) {
        if (debug_mode) NSLog(@"⏸️ Already scanning for service type: %s", service_type);
        if (cb) {
            NSDictionary *errDict = @{@"type": @"error", @"message": @"Already scanning for this service type"};
            NSData *errData = [NSJSONSerialization dataWithJSONObject:errDict options:0 error:nil];
            NSString *errStr = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
            cb([errStr UTF8String]);
        }
        return;
    }
    globalJsonCallback = cb;
    globalDebugMode = debug_mode;
    SearchContext *context = malloc(sizeof(SearchContext));
    context->serviceType = serviceTypeStr;
    context->services = [[NSMutableArray alloc] init];
    context->delegate = [[MdnsDelegate alloc] initWithServiceType:serviceTypeStr];
    context->browser = [[NSNetServiceBrowser alloc] init];
    context->browser.delegate = context->delegate;
    context->queryIntervalMs = query_interval_ms;
    context->totalDurationMs = total_duration_ms;
    context->queriesSent = 0;
    searchContexts[serviceTypeStr] = [NSValue valueWithPointer:context];
    totalActiveSearches++;
    if (debug_mode) NSLog(@"🎬 Starting initial search for: %@", serviceTypeStr);
    startRunLoopProcessing();
    [context->browser searchForServicesOfType:serviceTypeStr inDomain:@"local."];
    if (query_interval_ms > 0) {
        double intervalSeconds = query_interval_ms / 1000.0;
        context->queryTimer = [NSTimer scheduledTimerWithTimeInterval:intervalSeconds repeats:YES block:^(NSTimer * _Nonnull timer) {
            periodicQueryCallback(context);
        }];
        if (debug_mode) NSLog(@"⏰ Set up periodic query timer: every %.1fs", intervalSeconds);
    }
    if (total_duration_ms > 0) {
        double durationSeconds = total_duration_ms / 1000.0;
        context->durationTimer = [NSTimer scheduledTimerWithTimeInterval:durationSeconds repeats:NO block:^(NSTimer * _Nonnull timer) {
            searchDurationCallback(context);
        }];
        if (debug_mode) NSLog(@"⏰ Set up duration timer: %.1fs total", durationSeconds);
    }
    if (debug_mode) NSLog(@"✅ Periodic search setup complete for: %@", serviceTypeStr);
}

void start_mdns_scan_json(const char* service_type, DeviceFoundJsonCallback cb, int debug_mode) {
    start_mdns_periodic_scan_json(service_type, 0, 0, cb, debug_mode);
}

void stop_mdns_scan() {
    if (!g_mdns_silent_mode) NSLog(@"🛑 stop_mdns_scan called - stopping ALL scans");
    
    // 停止所有搜尋上下文
    for (NSString *serviceType in searchContexts.allKeys) {
        SearchContext *context = (SearchContext *)[searchContexts[serviceType] pointerValue];
        
        if (context->queryTimer) {
            [context->queryTimer invalidate];
        }
        if (context->durationTimer) {
            [context->durationTimer invalidate];
        }
        if (context->browser) {
            [context->browser stop];
        }
        
        free(context);
        if (!g_mdns_silent_mode) NSLog(@"🛑 Stopped scan for: %@", serviceType);
    }
    
    [searchContexts removeAllObjects];
    totalActiveSearches = 0;
    
    // 停止 Run Loop 處理
    stopRunLoopProcessing();
    
    if (globalCallback) {
        globalCallback = NULL;
    }
    
    if (!g_mdns_silent_mode) NSLog(@"✅ All periodic scans stopped");
}

void process_mdns_events() {
    if (totalActiveSearches > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

int is_mdns_scanning() {
    return totalActiveSearches > 0 ? 1 : 0;
}

int get_found_services_count() {
    int total = 0;
    for (NSString *serviceType in searchContexts.allKeys) {
        SearchContext *context = (SearchContext *)[searchContexts[serviceType] pointerValue];
        if (context && context->services) {
            total += (int)context->services.count;
        }
    }
    return total;
}