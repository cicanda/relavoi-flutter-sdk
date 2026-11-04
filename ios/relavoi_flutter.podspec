#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint relavoi_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'relavoi_flutter'
  # Keep in step with `version:` in ../pubspec.yaml.
  s.version          = '0.3.3'
  s.summary          = 'Privacy-preserving call and SMS masking for Flutter apps.'
  s.description      = <<-DESC
The iOS side of the Relavoi Flutter plugin. Native call detection for the
call-verification banner; everything else in the SDK is pure Dart.
                       DESC
  s.homepage         = 'https://relavoi.com'
  s.license          = { :type => 'Apache-2.0', :file => '../LICENSE' }
  s.author           = { 'CICANDA' => 'support@relavoi.com' }
  s.source           = { :path => '.' }
  s.source_files = 'relavoi_flutter/Sources/relavoi_flutter/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'relavoi_flutter_privacy' => ['relavoi_flutter/Sources/relavoi_flutter/PrivacyInfo.xcprivacy']}
end
