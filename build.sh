#!/bin/zsh

# Set Project name
# These are the only variables that need to be set per-project, the rest
# is very generic and should work for most things.
PROJECT_NAME="Segment"
SCHEME_NAME="Segment-Package"

# Your PROJECT_NAME.xcodeproj should include schemes for
#   iOS
#   tvOS
#   watchOS
#   macOS
#   Mac Catalyst

XCFRAMEWORK_OUTPUT_PATH="./XCFrameworkOutput"

# clean up old releases
echo "Removing previous ${PROJECT_NAME}.xcframework.zip"
rm -rf ${PROJECT_NAME}.xcframework.zip
rm -rf ${PROJECT_NAME}.xcframework
rm -rf ${XCFRAMEWORK_OUTPUT_PATH}

mkdir "${XCFRAMEWORK_OUTPUT_PATH}"
echo "Created ${XCFRAMEWORK_OUTPUT_PATH}"

# iOS Related Slices
echo "Building iOS Slices ..."
xcodebuild archive \
-scheme "${SCHEME_NAME}" \
-destination "generic/platform=iOS" \
-archivePath "${XCFRAMEWORK_OUTPUT_PATH}/iOS" \
SKIP_INSTALL=NO \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
ONLY_ACTIVE_ARCH=NO \
-scheme "${SCHEME_NAME}" \
-destination "generic/platform=iOS Simulator" \
-archivePath "${XCFRAMEWORK_OUTPUT_PATH}/iOSSimulator" \
SKIP_INSTALL=NO \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# tvOS Related Slices
echo "Building tvOS Slices ..."
xcodebuild archive \
-scheme "${SCHEME_NAME}" \
-destination "generic/platform=tvOS" \
-archivePath "${XCFRAMEWORK_OUTPUT_PATH}/tvOS" \
SKIP_INSTALL=NO \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
ONLY_ACTIVE_ARCH=NO \
-scheme "${SCHEME_NAME}" \
-destination "generic/platform=tvOS Simulator" \
-archivePath "${XCFRAMEWORK_OUTPUT_PATH}/tvOSSimulator" \
SKIP_INSTALL=NO \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# watchOS Related Slices
echo "Building watchOS Slices ..."
xcodebuild archive \
-scheme "${SCHEME_NAME}" \
-destination "generic/platform=watchOS" \
-archivePath "${XCFRAMEWORK_OUTPUT_PATH}/watchOS" \
SKIP_INSTALL=NO \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
ONLY_ACTIVE_ARCH=NO \
-scheme "${SCHEME_NAME}" \
-destination "generic/platform=watchOS Simulator" \
-archivePath "${XCFRAMEWORK_OUTPUT_PATH}/watchOSSimulator" \
SKIP_INSTALL=NO \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# macOS Related Slices
echo "Building macOS Slices ..."

xcodebuild archive \
ONLY_ACTIVE_ARCH=NO \
-scheme "${SCHEME_NAME}" \
-destination "generic/platform=macOS" \
-archivePath "${XCFRAMEWORK_OUTPUT_PATH}/macOS" \
SKIP_INSTALL=NO \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
ONLY_ACTIVE_ARCH=NO \
-scheme "${SCHEME_NAME}" \
-destination "generic/platform=macOS,variant=Mac Catalyst,name=Any Mac" \
-archivePath "${XCFRAMEWORK_OUTPUT_PATH}/macOSCatalyst" \
SKIP_INSTALL=NO \
BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Combine all the slices into XCFramework
echo "Combining Slices into XCFramework ..."
xcodebuild -create-xcframework \
-framework ./${XCFRAMEWORK_OUTPUT_PATH}/iOS.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework \
-framework ./${XCFRAMEWORK_OUTPUT_PATH}/iOSSimulator.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework \
-framework ./${XCFRAMEWORK_OUTPUT_PATH}/tvOS.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework \
-framework ./${XCFRAMEWORK_OUTPUT_PATH}/tvOSSimulator.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework \
-framework ./${XCFRAMEWORK_OUTPUT_PATH}/watchOS.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework \
-framework ./${XCFRAMEWORK_OUTPUT_PATH}/watchOSSimulator.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework \
-framework ./${XCFRAMEWORK_OUTPUT_PATH}/macOS.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework \
-framework ./${XCFRAMEWORK_OUTPUT_PATH}/macOSCatalyst.xcarchive/Products/Library/Frameworks/${PROJECT_NAME}.framework \
-output "./${XCFRAMEWORK_OUTPUT_PATH}/${PROJECT_NAME}.xcframework"

# Zip it up!

echo "Zipping up ${PROJECT_NAME}.xcframework ..."
zip -r ${PROJECT_NAME}.xcframework.zip "./${XCFRAMEWORK_OUTPUT_PATH}/${PROJECT_NAME}.xcframework"

echo "Done."
