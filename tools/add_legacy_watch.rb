#!/usr/bin/env ruby
# Generate the watchOS 6 dual-target companion without modifying phone builds
# until a compatible watch deployment environment is available.
require 'xcodeproj'
require 'fileutils'
root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'ios/Runner.xcodeproj'))
if project.targets.any? { |t| t.name == 'LegacyWatch' }
  runner = project.targets.find { |t| t.name == 'Runner' }
  watch = project.targets.find { |t| t.name == 'LegacyWatch' }
  runner.dependencies.select { |d| d.target == watch }.each(&:remove_from_project)
  runner.copy_files_build_phases.select { |p| p.name == 'Embed Watch Content' }.each(&:remove_from_project)
  if ARGV.include?('--embed')
    runner.add_dependency(watch)
    phase = runner.new_copy_files_build_phase('Embed Watch Content')
    phase.dst_subfolder_spec = '16'
    phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
    phase.add_file_reference(watch.product_reference).settings = {'ATTRIBUTES' => ['RemoveHeadersOnCopy']}
  end
  project.save
  puts ARGV.include?('--embed') ? 'Watch embedded in Runner.' : 'Phone builds do not embed the legacy watch.'
  exit
end
runner = project.targets.find { |t| t.name == 'Runner' }
base = runner.build_configurations.first.build_settings.fetch('PRODUCT_BUNDLE_IDENTIFIER')
watch = project.new_target(:watch2_app, 'LegacyWatch', :watchos, '6.0')
ext = project.new_target(:watch2_extension, 'LegacyWatchExtension', :watchos, '6.0')
group = project.main_group.new_group('LegacyWatch', 'LegacyWatch')
source = group.new_file('HostingController.swift')
ext.source_build_phase.add_file_reference(source)
watch.resources_build_phase.add_file_reference(group.new_file('Interface.storyboard'))
[[watch, 'Watch-Info.plist', "#{base}.watchkitapp"],
 [ext, 'Extension-Info.plist', "#{base}.watchkitapp.watchkitextension"]].each do |target, plist, bundle|
  target.build_configurations.each do |config|
    config.build_settings.merge!({
      'INFOPLIST_FILE' => "LegacyWatch/#{plist}", 'PRODUCT_BUNDLE_IDENTIFIER' => bundle,
      'PRODUCT_NAME' => '$(TARGET_NAME)', 'SDKROOT' => 'watchos',
      'SUPPORTED_PLATFORMS' => 'watchos watchsimulator', 'SWIFT_VERSION' => '5.0', 'WATCHOS_DEPLOYMENT_TARGET' => '6.0',
      'TARGETED_DEVICE_FAMILY' => '4', 'SKIP_INSTALL' => 'YES',
      'CURRENT_PROJECT_VERSION' => '6', 'MARKETING_VERSION' => '1.1.0',
      'CODE_SIGN_STYLE' => 'Automatic', 'ARCHS' => '$(ARCHS_STANDARD)',
      'ARCHS[sdk=watchos*]' => 'armv7k arm64_32',
    })
    team = runner.build_configurations.first.build_settings['DEVELOPMENT_TEAM']
    config.build_settings['DEVELOPMENT_TEAM'] = team if team
  end
end
watch.add_dependency(ext)
phase = watch.new_copy_files_build_phase('Embed App Extensions')
phase.dst_subfolder_spec = '13'
phase.add_file_reference(ext.product_reference).settings = {'ATTRIBUTES' => ['RemoveHeadersOnCopy']}
common = {'CFBundleDevelopmentRegion' => 'en', 'CFBundleExecutable' => '$(EXECUTABLE_NAME)',
 'CFBundleIdentifier' => '$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleInfoDictionaryVersion' => '6.0',
 'CFBundleName' => '$(PRODUCT_NAME)', 'CFBundleShortVersionString' => '1.1.0', 'CFBundleVersion' => '6'}
Xcodeproj::Plist.write_to_path(common.merge({'CFBundlePackageType' => 'APPL', 'CFBundleDisplayName' => 'eScive',
 'WKWatchKitApp' => true, 'WKCompanionAppBundleIdentifier' => base}), File.join(root, 'ios/LegacyWatch/Watch-Info.plist'))
Xcodeproj::Plist.write_to_path(common.merge({'CFBundlePackageType' => 'XPC!',
 'NSExtension' => {'NSExtensionPointIdentifier' => 'com.apple.watchkit',
 'NSExtensionAttributes' => {'WKAppBundleIdentifier' => "#{base}.watchkitapp"}},
 'WKExtensionDelegateClassName' => '$(PRODUCT_MODULE_NAME).ExtensionDelegate'}), File.join(root, 'ios/LegacyWatch/Extension-Info.plist'))
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(watch)
scheme.set_launch_target(watch)
scheme.save_as(project.path, 'LegacyWatch')
project.save
puts 'LegacyWatch targets added. Select signing teams and a compatible paired watch.'
