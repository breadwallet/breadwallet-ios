# Uncomment the next line to define a global platform for your project
source 'https://github.com/CocoaPods/Specs.git'
workspace 'loafwallet.xcworkspace'
project 'loafwallet.xcodeproj', 'Debug' => :debug,'Release' => :release
use_frameworks!


#Shared Cocopods
def shared_pods
  pod 'Alamofire', '~> 4.7'
  pod 'Mixpanel-swift'  
  pod 'SwiftyJSON', '~> 4.0'
  pod 'CryptoSwift', '~> 1.0'
  pod 'Firebase/Crashlytics'
  pod 'Firebase/Analytics'
  # add after v2.6.0 pod 'SwiftLint'
end

def shared_watchOS_pods
end

target 'loafwallet' do
  platform :ios, '12.0'
  shared_pods
  
  target 'loafwalletTests' do
    inherit! :search_paths
  end
  
  target 'loafwalletUITests' do
    inherit! :search_paths
  end
  
end
 
