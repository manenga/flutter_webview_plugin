#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_webview_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webview_plugin'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter plugin that allows you to use native webview in your app.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/manenga/flutter_webview_plugin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Maneenga Mungandi' => '' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
