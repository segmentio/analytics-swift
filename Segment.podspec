Pod::Spec.new do |s|
  s.name             = 'Segment'
  s.module_name      = 'Segment'
  s.version          = '1.4.8'
  s.summary          = 'analytics-swift Cocoapods support.'
  s.homepage         = 'https://github.com/flocasts/analytics-swift'
  s.license          = { :type => 'MIT', :file => './LICENSE' }
  s.author           = { "Segment" => "friends@segment.com" }
  s.source           = { :git => 'https://github.com/flocasts/analytics-swift.git', :tag => s.version.to_s }
  s.ios.deployment_target = '14.0'
  s.tvos.deployment_target = '14.0'
  s.swift_version = '5.0'
  s.source_files = 'Sources/Segment/**/*'
  s.dependency 'Sovran', '~> 1.0.2'
end
