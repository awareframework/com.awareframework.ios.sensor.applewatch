#
# Be sure to run `pod lib lint com.awareframework.ios.sensor.applewatch.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'com.awareframework.ios.sensor.applewatch'
  s.version          = '0.1.0'
  s.summary          = 'A short description of com.awareframework.ios.sensor.applewatch.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/1227623/com.awareframework.ios.sensor.applewatch'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '1227623' => 'yuukin@iis.u-tokyo.ac.jp' }
  s.source           = { :git => 'https://github.com/1227623/com.awareframework.ios.sensor.applewatch.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'
  s.watchos.deployment_target = '8.0'

  s.swift_version = '4.0'
    
  s.dependency 'DataCompression', '~> 3.8.0'

  # watchos
#  s.subspec 'watchos' do |sp|
  s.watchos.frameworks = 'WatchConnectivity','WatchKit', 'HealthKit','CoreMotion','CoreLocation'  # ,'UIKit','Fundation',
  s.watchos.source_files = ['com.awareframework.ios.sensor.applewatch/Classes/watchos/**/*.swift']
# end
  
  # ios
  s.ios.dependency 'com.awareframework.ios.sensor.core', '~> 0.5.0'
  s.ios.frameworks = 'WatchConnectivity'
  s.ios.source_files = ['com.awareframework.ios.sensor.applewatch/Classes/ios/**/*.swift']
 
  # subpod for a phone
#  s.subspec 'ios' do |sp|
#    sp.dependency 'com.awareframework.ios.sensor.core', '~> 0.5.0'
#    sp.ios.frameworks = 'WatchConnectivity'
#    sp.ios.source_files = ['com.awareframework.ios.sensor.applewatch/Classes/ios/**/*.swift']
#  end
  
#  s.default_subspec = 'ios'
  
  # s.resource_bundles = {
  #   'com.awareframework.ios.sensor.applewatch' => ['com.awareframework.ios.sensor.applewatch/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
