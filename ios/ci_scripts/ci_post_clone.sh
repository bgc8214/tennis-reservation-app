#!/bin/sh

# Xcode Cloud가 저장소를 클론한 후 실행되는 스크립트
# CocoaPods 의존성을 설치합니다

set -e

echo "Installing CocoaPods dependencies..."
cd "$CI_WORKSPACE/ios"
pod install

echo "✅ CocoaPods installation completed"
