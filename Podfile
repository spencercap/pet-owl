abstract_target 'Starter' do
  use_frameworks!
  # Pods for all targets
  ## LOCAL
#  pod 'MetaWear', :subspecs => ['Core', 'AsyncUtils', 'UI'], :path => '../'
  ## COCOAPODS
  pod 'MetaWear', :subspecs => ['Core', 'AsyncUtils', 'UI']
  pod 'SwiftWebSocket'

  target 'iOS' do
    platform :ios, '10.0'

    # Pods for iOS
    pod 'MBProgressHUD'
  end

  target 'macOS' do
    platform :osx, '10.14'

    # Pods for macOS
  end

  target 'tvOS' do
    platform :tvos, '10.0'

    # Pods for tvOS
    pod 'MBProgressHUD'
  end
end

