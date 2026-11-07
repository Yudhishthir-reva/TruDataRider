# Uncomment the next line to define a global platform for your project
platform :ios, '16.0'

target 'TrudataRider' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for TrudataRider
  pod 'IQKeyboardManagerSwift'
  pod 'FirebaseCore'
  pod 'FirebaseMessaging'
  pod 'FirebaseRemoteConfig'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      deployment_target = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']&.to_f || 0
      if deployment_target < 16.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      end
    end
  end
end
