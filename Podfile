#Uncomment the next line to define a global platform for your project
platform :ios, '26.0'

target 'MPlate' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  pod 'GRDB.swift'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
    end
  end
end
