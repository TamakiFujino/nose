platform :ios, '17.0'
use_frameworks!

target 'nose' do
  pod 'GoogleMaps'
  pod 'GooglePlaces'
  pod 'Firebase/Core'
  pod 'FirebaseAnalytics'
  pod 'Firebase/Auth'
  pod 'GoogleSignIn'
  pod 'Firebase/Firestore'
  pod 'Firebase/Storage'

  plugin 'cocoapods-acknowledgements'
  
  target 'noseTests' do
    inherit! :search_paths
  end

  target 'noseUITests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
