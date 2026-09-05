#import "UVCDevice.h"
#import <IOKit/IOKitLib.h>
#import <IOUSBHost/IOUSBHost.h>

static const uint8_t kVideoControlInterface = 0;

@implementation UVCDevice {
  IOUSBHostDevice *_device;
}

- (instancetype)initWithVendorID:(uint16_t)vid productID:(uint16_t)pid error:(NSError **)error {
  self = [super init];
  if (!self) return nil;
  NSMutableDictionary *matching = (__bridge_transfer NSMutableDictionary *)IOServiceMatching("IOUSBHostDevice");
  matching[@"idVendor"] = @(vid);
  matching[@"idProduct"] = @(pid);
  io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, (__bridge_retained CFDictionaryRef)matching);
  if (!service) {
    if (error) *error = [NSError errorWithDomain:@"UVCDevice" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Camera not connected"}];
    return nil;
  }
  _device = [[IOUSBHostDevice alloc] initWithIOService:service options:0 queue:nil error:error interestHandler:nil];
  IOObjectRelease(service);
  return _device ? self : nil;
}

- (NSData *)getRequest:(uint8_t)request entity:(uint8_t)entity selector:(uint8_t)selector length:(uint16_t)length error:(NSError **)error {
  IOUSBDeviceRequest req = {
    .bmRequestType = 0xA1, .bRequest = request,
    .wValue = (uint16_t)(selector << 8), .wIndex = (uint16_t)((entity << 8) | kVideoControlInterface), .wLength = length,
  };
  NSMutableData *buf = [NSMutableData dataWithLength:length];
  NSUInteger transferred = 0;
  if (![_device sendDeviceRequest:req data:buf bytesTransferred:&transferred completionTimeout:1.0 error:error]) return nil;
  return buf;
}

- (BOOL)setEntity:(uint8_t)entity selector:(uint8_t)selector data:(NSData *)data error:(NSError **)error {
  IOUSBDeviceRequest req = {
    .bmRequestType = 0x21, .bRequest = 0x01,
    .wValue = (uint16_t)(selector << 8), .wIndex = (uint16_t)((entity << 8) | kVideoControlInterface), .wLength = (uint16_t)data.length,
  };
  NSUInteger transferred = 0;
  return [_device sendDeviceRequest:req data:[data mutableCopy] bytesTransferred:&transferred completionTimeout:1.0 error:error];
}

@end
