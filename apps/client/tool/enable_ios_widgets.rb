# Enables the App Group configuration in a checkout used for the signed build.
# Run from apps/client. This intentionally changes the local Xcode project.
require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |target| target.name == 'Runner' }
abort 'Widget target already configured' if project.targets.any? { |target| target.name == 'ClassSyncWidget' }

widget = project.new_target(:app_extension, 'ClassSyncWidget', :ios, '17.0')
group = project.main_group.new_group('ClassSyncWidget', 'ClassSyncWidget')
widget.add_file_references([group.new_file('ClassSyncTimetableWidget.swift')])
group.new_file('Info.plist')
group.new_file('AppGroup.entitlements')

widget.build_configurations.each do |configuration|
  configuration.base_configuration_reference =
    project.files.find { |file| file.path == 'Flutter/Generated.xcconfig' }
  configuration.build_settings.merge!(
    'PRODUCT_NAME' => 'ClassSyncWidget',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'app.classsync.classsync.widgets',
    'INFOPLIST_FILE' => 'ClassSyncWidget/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'CODE_SIGN_ENTITLEMENTS' => 'ClassSyncWidget/AppGroup.entitlements',
    'SWIFT_VERSION' => '5.0',
    'SKIP_INSTALL' => 'YES',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES'
  )
end

runner.build_configurations.each do |configuration|
  configuration.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'ClassSyncWidget/AppGroup.entitlements'
  configuration.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) CLASSSYNC_WIDGETS'
end
runner.add_dependency(widget)
embed = runner.new_copy_files_build_phase('Embed App Extensions')
embed.dst_subfolder_spec = '13'
embed.add_file_reference(widget.product_reference).settings = {
  'ATTRIBUTES' => ['RemoveHeadersOnCopy']
}
runner.build_phases.delete(embed)
runner.build_phases.insert(runner.build_phases.index { |phase| phase.display_name == 'Thin Binary' }, embed)
project.save
