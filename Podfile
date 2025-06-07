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

  target 'noseTests' do
    inherit! :search_paths
  end

  target 'noseUITests' do
    inherit! :search_paths
  end

  plugin 'cocoapods-acknowledgements'
end
