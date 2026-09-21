# Exact commands from GitHub Actions

Source run: https://github.com/AloneDc/MiDinero/actions/runs/35661791709

```bash
sw_vers # exit=0
uname -m # exit=0
xcode-select -p # exit=0
xcodebuild -version # exit=0
swift --version # exit=0
xcrun --sdk iphonesimulator --show-sdk-version # exit=0
xcrun --sdk iphonesimulator --show-sdk-path # exit=0
xcodebuild -showsdks # exit=0
git rev-parse HEAD # exit=0
xcodebuild -list -project MiDinero.xcodeproj # exit=0
xcrun simctl list --json # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -sdk iphonesimulator -showdestinations # exit=0
xcrun simctl boot 48B2DA2E-AF18-4E36-BB25-B25969A4EBCF # exit=0
xcrun simctl bootstatus 48B2DA2E-AF18-4E36-BB25-B25969A4EBCF -b # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -sdk iphonesimulator -showdestinations # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Debug -destination 'platform=iOS Simulator,id=48B2DA2E-AF18-4E36-BB25-B25969A4EBCF,arch=arm64' -destination-timeout 120 -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete -showBuildSettings # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Debug -destination 'platform=iOS Simulator,id=48B2DA2E-AF18-4E36-BB25-B25969A4EBCF,arch=arm64' -destination-timeout 120 -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete -resultBundlePath /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/Build.xcresult build # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Debug -destination 'platform=iOS Simulator,id=48B2DA2E-AF18-4E36-BB25-B25969A4EBCF,arch=arm64' -destination-timeout 120 -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete -resultBundlePath /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/BuildForTesting.xcresult build-for-testing # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Debug -destination 'platform=iOS Simulator,id=48B2DA2E-AF18-4E36-BB25-B25969A4EBCF,arch=arm64' -destination-timeout 120 -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete test-without-building -enumerate-tests -test-enumeration-style flat -test-enumeration-format text -test-enumeration-output-path /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/discovered-tests.txt # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Debug -destination 'platform=iOS Simulator,id=48B2DA2E-AF18-4E36-BB25-B25969A4EBCF,arch=arm64' -destination-timeout 120 -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -resultBundlePath /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/Tests.xcresult test-without-building # exit=0
xcrun xcresulttool get test-results summary --path /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/Tests.xcresult # exit=0
xcrun xcresulttool get test-results tests --path /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/Tests.xcresult # exit=0
xcrun xcresulttool export attachments --path /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/Tests.xcresult --output-path /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/attachments # exit=0
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete -resultBundlePath /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/Release.xcresult build # exit=0
```
