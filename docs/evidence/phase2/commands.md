# Actual Xcode commands

Source: https://github.com/AloneDc/MiDinero/actions/runs/35658862995

Working directory: `/Users/runner/work/MiDinero/MiDinero`

## targets-and-schemes

Exit code: 0

```bash
xcodebuild -list -project MiDinero.xcodeproj
```

## build

Exit code: 0

```bash
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Debug -destination 'platform=iOS Simulator,id=22A3039C-6A45-47F4-82D4-80C58CA94379,arch=arm64' -destination-timeout 120 -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete -resultBundlePath /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/Build.xcresult build
```

## build-for-testing

Exit code: 0

```bash
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Debug -destination 'platform=iOS Simulator,id=22A3039C-6A45-47F4-82D4-80C58CA94379,arch=arm64' -destination-timeout 120 -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete -resultBundlePath /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/BuildForTesting.xcresult build-for-testing
```

## enumerate-tests

Exit code: 0

```bash
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Debug -destination 'platform=iOS Simulator,id=22A3039C-6A45-47F4-82D4-80C58CA94379,arch=arm64' -destination-timeout 120 -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete test-without-building -enumerate-tests -test-enumeration-style flat -test-enumeration-format text -test-enumeration-output-path /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/discovered-tests.txt
```

## tests

Exit code: 0

```bash
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Debug -destination 'platform=iOS Simulator,id=22A3039C-6A45-47F4-82D4-80C58CA94379,arch=arm64' -destination-timeout 120 -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -resultBundlePath /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/Tests.xcresult test-without-building
```

## test-summary

Exit code: 0

```bash
xcrun xcresulttool get test-results summary --path /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/Tests.xcresult
```

## release-build

Exit code: 0

```bash
xcodebuild -project MiDinero.xcodeproj -scheme MiDinero -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /Users/runner/work/MiDinero/MiDinero/build/CI-DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_STRICT_CONCURRENCY=complete -resultBundlePath /Users/runner/work/MiDinero/MiDinero/build/ci-evidence/Release.xcresult build
```
