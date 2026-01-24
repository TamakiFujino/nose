platform :ios, '17.0'
use_frameworks!

target 'nose' do
  pod 'MapboxMaps', '~> 11.0'
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
    # 全体を 17.0 に
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end

    # AppAuth 対策として additional: build_settings に強制適用
    if target.name == 'AppAuth'
      puts "✅ Forcing iOS 17.0 on target #{target.name}"
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      end
    end
  end
end
