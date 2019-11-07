# Uncomment the next line to define a global platform for your project
source 'https://github.com/CocoaPods/Specs.git'
workspace 'loafwallet.xcworkspace'
project 'loafwallet.xcodeproj', 'Development' => :debug,'Release' => :release
use_frameworks!


#Shared Cocopods
def shared_pods
  pod 'Alamofire', '~> 4.7'
  pod 'Mixpanel-swift' 
end

def shared_watchOS_pods
end

target 'loafwallet' do
  platform :ios, '10.0'
  shared_pods  
end

target 'loafwallet-dev' do
  platform :ios, '10.0'
  shared_pods
  
  target 'loafwalletTests' do
    inherit! :search_paths
  end
  
  target 'loafwalletUITests' do
    inherit! :search_paths
  end
  
end

