# C920 Control

Menu bar app for the Logitech HD Pro Webcam C920 on macOS. Exposes every standard UVC control the
camera advertises (focus, zoom, pan/tilt, exposure, gain, backlight, brightness, contrast,
saturation, sharpness, white balance, power line frequency) with a live preview.

## How it talks to the camera

macOS's UVCAssistant holds the camera's VideoControl interface exclusively, so libusb-style
interface claims fail without root. The app instead sends the standard UVC class requests
(GET_CUR/MIN/MAX/RES/DEF/INFO, SET_CUR) through Apple's IOUSBHost framework at the *device*
level (`Sources/UVC/UVCDevice.m`), which works as a normal user.

## Requirements

macOS 13 or later and Xcode command line tools (`xcode-select --install`). No Xcode project needed.

## Build

    ./build.sh            # builds ./build/C920 Control.app
    ./build.sh --run      # build and launch from ./build
    ./build.sh --install  # build, copy to ~/Applications and launch

The app is ad-hoc signed, so macOS asks for camera permission again after each rebuild.

## Notes

- The C920 forgets settings when unplugged or after deep sleep. Use **Save Profile** once you
  are happy and **Apply Profile** to restore.
- Focus, exposure time and gain can only be set while their auto mode is off; the app greys
  them out otherwise.
- Double-click a slider's value to reset that control to its default.

## Other cameras

Any UVC webcam should work with two changes: the vendor/product IDs in `CameraModel.swift`,
and the entity IDs in `Controls.swift` (camera terminal and processing unit; read them from the
descriptor with `system_profiler SPUSBDataType` or `ioreg`). Controls the camera does not
implement simply report as unsettable.

## License

MIT, see [LICENSE](LICENSE).
