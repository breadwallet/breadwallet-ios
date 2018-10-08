# Uncomment the next line to define a global platform for your project
use_frameworks!

workspace 'loafwallet.xcworkspace'
project 'loafwallet.xcodeproj', 'Development' => :debug


#Shared Cocopods
def shared_pods
  #Add when they debug for iOS v12: pod 'Mixpanel-swift' | KCW Oct 4,2018
 pod 'Crashlytics', '~>  3.10'
 pod 'Alamofire'
end

def shared_watchOS_pods

end

target 'loafwallet' do
  platform :ios, '10.0'
  shared_pods
end

target 'loafwallet WatchKit App' do
  platform :watchos, '4.0'
  inherit! :search_paths
  shared_watchOS_pods
  
  target 'loafwallet WatchKit Extension' do
    inherit! :search_paths
  end

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
