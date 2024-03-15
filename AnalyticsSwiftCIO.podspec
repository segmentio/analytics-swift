Pod::Spec.new do |s|
    s.name = "AnalyticsSwiftCIO"
    s.version = "1.5.5-cio.1"
    s.license = { :type => 'MIT', :file => './LICENSE' }
    s.summary = "Customer.io Data Pipelines analytics client for Swift app (iOS/tvOS/watchOS/macOS/Linux)."
    s.homepage = "https://github.com/customerio/cdp-analytics-swift"
    s.authors = "Customer.io"

    # The version is a git commit hash. Make sure the commit is the same as what SPM customers are using.
    s.source = { :git => 'https://github.com/customerio/cdp-analytics-swift.git', :commit => 'b2f8f5b68dd0d8796b4bacdec39aacb5b6387a41' }

    s.ios.deployment_target = "13.0"
    s.requires_arc = true

    s.swift_version = '5.3'
    s.cocoapods_version = '>= 1.11.0'
    s.module_name = "Segment"

    s.source_files = "Sources/**/*.swift"

    s.dependency 'Sovran', '~> 1.1.1'
    s.dependency 'JSONSafeEncoder', '~> 1.0.2'
end
