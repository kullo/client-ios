# Uncomment this line to define a global platform for your project
platform :ios, '8.1'
# Uncomment this line if you're using Swift
use_frameworks!

target 'KulloiOSApp' do
    pod 'Firebase/Core'
    pod 'Firebase/Messaging'
    pod 'MLPAutoCompleteTextField', :git => 'https://github.com/EddyBorja/MLPAutoCompleteTextField.git', :branch => 'master'
    pod 'SwiftKeychainWrapper', :git => 'https://github.com/tiwoc/SwiftKeychainWrapper.git', :branch => 'kullo'
    pod 'SwiftyMimeTypes'
    pod 'TCMobileProvision'
    pod 'XCGLogger'
end

# Remove irrelevant build architectures from Pods targets
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ARCHS'] = "arm64 armv7"
        end
    end
end
