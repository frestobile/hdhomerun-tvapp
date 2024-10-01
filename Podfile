# Uncomment the next line to define a global platform for your project
# platform :tvos, '14.0'

target 'LiveTV' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for LiveTV
  #pod 'TVVLCKit', '~>3.3.0'
  #pod 'ffmpeg-kit-tvos-full', '~> 6.0'
  pod 'GCDWebServer'

  target 'LiveTVTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'LiveTVUITests' do
    # Pods for testing
  end

end
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_APP_SANDBOX'] = 'NO'
    end
  end
end

