Pod::Spec.new do |s|
  s.name             = 'video_thumbnail_flutter'
  s.version          = '1.0.0'
  s.summary          = 'Creates a thumbnail from a local video file or a video URL.'
  s.description      = <<-DESC
Creates a JPEG, PNG or WebP thumbnail from a local video file or a video URL.
                       DESC
  s.homepage         = 'https://github.com/toyaji/video_thumbnail_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'toyaji' => 'https://github.com/toyaji' }
  s.source           = { :path => '.' }
  s.source_files = 'video_thumbnail_flutter/Sources/video_thumbnail_flutter/**/*.{h,m}'
  s.public_header_files = 'video_thumbnail_flutter/Sources/video_thumbnail_flutter/include/**/*.h'
  s.resource_bundles = { 'video_thumbnail_flutter_privacy' => ['video_thumbnail_flutter/Sources/video_thumbnail_flutter/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.dependency 'libwebp'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
