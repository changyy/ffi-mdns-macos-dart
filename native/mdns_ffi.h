#ifndef MDNS_FFI_H
#define MDNS_FFI_H

// Callback 函數型別
typedef void (*DeviceFoundCallback)(const char* ip, int port, const char* name, const char* txt);

// 主要函數
void start_mdns_scan(const char* service_type, DeviceFoundCallback cb);

// 新增：週期性搜尋函數
void start_mdns_periodic_scan(const char* service_type, 
                             int query_interval_ms, 
                             int total_duration_ms, 
                             DeviceFoundCallback cb);

void stop_mdns_scan(void);

// 處理 Run Loop 事件
void process_mdns_events(void);

// 狀態查詢函數
int is_mdns_scanning(void);
int get_found_services_count(void);

#endif // MDNS_FFI_H