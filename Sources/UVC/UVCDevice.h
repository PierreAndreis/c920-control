#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Thin wrapper over IOUSBHostDevice that issues UVC class requests on endpoint 0.
/// Device-level requests work without root even while macOS's UVCAssistant owns the interfaces.
@interface UVCDevice : NSObject
- (nullable instancetype)initWithVendorID:(uint16_t)vid productID:(uint16_t)pid error:(NSError **)error;
/// bRequest: GET_CUR 0x81, GET_MIN 0x82, GET_MAX 0x83, GET_RES 0x84, GET_INFO 0x86, GET_DEF 0x87
- (nullable NSData *)getRequest:(uint8_t)request entity:(uint8_t)entity selector:(uint8_t)selector length:(uint16_t)length error:(NSError **)error;
- (BOOL)setEntity:(uint8_t)entity selector:(uint8_t)selector data:(NSData *)data error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
