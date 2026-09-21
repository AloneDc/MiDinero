# Exact commands from GitHub Actions

Source run: https://github.com/AloneDc/MiDinero/actions/runs/35661791709

```bash
sw_vers # exit=0
uname -m # exit=0
git rev-parse HEAD # exit=0
xcodebuild -version # exit=0
xcrun swift --version # exit=0
xcrun --sdk iphoneos --show-sdk-version # exit=0
xcodebuild -showsdks # exit=0
xcodebuild -help # exit=0
xcrun altool --help # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Release -destination generic/platform=iOS -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/Device-DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= SWIFT_STRICT_CONCURRENCY=complete -showBuildSettings # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Release -destination generic/platform=iOS -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/Device-DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= SWIFT_STRICT_CONCURRENCY=complete -resultBundlePath /Users/runner/work/MiDinero/MiDinero/build/device-evidence/DeviceBuild.xcresult build # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Release -destination generic/platform=iOS -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/Device-DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= SWIFT_STRICT_CONCURRENCY=complete -archivePath /Users/runner/work/MiDinero/MiDinero/build/device/MiDinero.xcarchive -resultBundlePath /Users/runner/work/MiDinero/MiDinero/build/device-evidence/Archive.xcresult archive # exit=0
xcrun lipo -archs /Users/runner/work/MiDinero/MiDinero/build/device/MiDinero.xcarchive/Products/Applications/MiDinero.app/MiDinero # exit=0
xcrun vtool -show-build /Users/runner/work/MiDinero/MiDinero/build/device/MiDinero.xcarchive/Products/Applications/MiDinero.app/MiDinero # exit=0
xcrun otool -L /Users/runner/work/MiDinero/MiDinero/build/device/MiDinero.xcarchive/Products/Applications/MiDinero.app/MiDinero # exit=0
codesign -dvv /Users/runner/work/MiDinero/MiDinero/build/device/MiDinero.xcarchive/Products/Applications/MiDinero.app # exit=1
xcrun dwarfdump --uuid /Users/runner/work/MiDinero/MiDinero/build/device/MiDinero.xcarchive/Products/Applications/MiDinero.app/MiDinero # exit=0
xcrun dwarfdump --uuid /Users/runner/work/MiDinero/MiDinero/build/device/MiDinero.xcarchive/dSYMs/MiDinero.app.dSYM # exit=0
ditto /Users/runner/work/MiDinero/MiDinero/build/device/MiDinero.xcarchive/Products/Applications/MiDinero.app/Metadata.appintents /Users/runner/work/MiDinero/MiDinero/build/device-evidence/Metadata.appintents # exit=0
tar -czf /Users/runner/work/MiDinero/MiDinero/build/device-evidence/MiDinero-unsigned.xcarchive.tar.gz -C /Users/runner/work/MiDinero/MiDinero/build/device MiDinero.xcarchive # exit=0
```
