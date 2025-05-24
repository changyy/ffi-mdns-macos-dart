#ifndef MDNS_FFI_H
#define MDNS_FFI_H

// Callback 函數型別
typedef void (*DeviceFoundCallback)(const char* ip, int port, const char* name, const char* txt);

// 裝置資訊 struct
typedef struct {
    const char* ip;
    int port;
    const char* name;
    const char* txt;
    const char* type;
    const char* hostname;
    const char* interface;
    int flags;
    // 可依需求擴充欄位
} DeviceInfo;

// JSON callback 型別
typedef void (*DeviceFoundJsonCallback)(const char* device_json);

// 主要函數
void start_mdns_scan(const char* service_type, DeviceFoundCallback cb);

// 新版：以 JSON 傳遞裝置資訊
void start_mdns_scan_json(const char* service_type, DeviceFoundJsonCallback cb, int debug_mode);

// 新增：週期性搜尋函數
void start_mdns_periodic_scan(const char* service_type, 
                             int query_interval_ms, 
                             int total_duration_ms, 
                             DeviceFoundCallback cb);
void start_mdns_periodic_scan_json(const char* service_type,
                                   int query_interval_ms,
                                   int total_duration_ms,
                                   DeviceFoundJsonCallback cb,
                                   int debug_mode);

void stop_mdns_scan(void);

// 處理 Run Loop 事件
void process_mdns_events(void);

// 狀態查詢函數
int is_mdns_scanning(void);
int get_found_services_count(void);

void set_mdns_silent_mode(int silent);

#endif // MDNS_FFI_H