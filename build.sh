#!/bin/zsh

# Set Project name
PROJECT_NAME="Segment-Package"

# set framework folder name
FRAMEWORK_FOLDER_NAME="${PROJECT_NAME}_XCFramework"

# set framework name or read it from project by this variable
FRAMEWORK_NAME="Segment"

#xcframework path
FRAMEWORK_PATH="${FRAMEWORK_FOLDER_NAME}/${FRAMEWORK_NAME}.xcframework"

# set path for iOS simulator archive
SIMULATOR_ARCHIVE_PATH="${FRAMEWORK_FOLDER_NAME}/simulator.xcarchive"

# set path for iOS device archive
IOS_DEVICE_ARCHIVE_PATH="${FRAMEWORK_FOLDER_NAME}/iOS.xcarchive"

# clean up old releases
rm -rf Segment.xcframework.zip
echo "Deleted the xcframework"

rm -rf "${FRAMEWORK_FOLDER_NAME}"
echo "Deleted ${FRAMEWORK_FOLDER_NAME}"

mkdir "${FRAMEWORK_FOLDER_NAME}"
echo "Created ${FRAMEWORK_FOLDER_NAME}"

echo "Archiving ${FRAMEWORK_NAME}"

xcodebuild archive -scheme ${PROJECT_NAME} -destination="iOS Simulator" -archivePath "${SIMULATOR_ARCHIVE_PATH}" -sdk iphonesimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

xcodebuild archive -scheme ${PROJECT_NAME} -destination="iOS" -archivePath "${IOS_DEVICE_ARCHIVE_PATH}" -sdk iphoneos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

#Creating XCFramework
xcodebuild -create-xcframework -framework ${SIMULATOR_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -framework ${IOS_DEVICE_ARCHIVE_PATH}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework -output "${FRAMEWORK_PATH}"
rm -rf "${SIMULATOR_ARCHIVE_PATH}"
rm -rf "${IOS_DEVICE_ARCHIVE_PATH}"

zip -r Segment.xcframework.zip "${FRAMEWORK_FOLDER_NAME}/Segment.xcframework"
