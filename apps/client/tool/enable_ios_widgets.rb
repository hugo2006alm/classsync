# Enables one WidgetKit configuration in the local checkout.
# Run from apps/client. This intentionally changes the local Xcode project.
require 'xcodeproj'

mode = ARGV.fetch(0, 'app-group')
abort 'Expected demo, app-group, or app-group-test' unless
  ARGV.length <= 1 && %w[demo app-group app-group-test].include?(mode)
uses_group = mode != 'demo'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |target| target.name == 'Runner' }
abort 'Widget target already configured' if project.targets.any? { |target| target.name == 'ClassSyncWidget' }

widget = project.new_target(:app_extension, 'ClassSyncWidget', :ios, '17.0')
group = project.main_group.new_group('ClassSyncWidget', 'ClassSyncWidget')
widget.add_file_references([
  group.new_file('ClassSyncTimetableWidget.swift'),
  group.new_file('TimetableWidgetSchedule.swift')
])
group.new_file('Info.plist')
if uses_group
  group.new_file('AppGroup.entitlements')
  container = group.new_file('TimetableWidgetStorage.swift')
  widget.add_file_references([container])
  runner.add_file_references([container])
end

flutter_config = project.files.find { |file| file.path == 'Flutter/Generated.xcconfig' }
abort 'Flutter/Generated.xcconfig reference is missing' unless flutter_config

widget.build_configurations.each do |configuration|
  configuration.base_configuration_reference = flutter_config
  configuration.build_settings.merge!(
    'PRODUCT_NAME' => 'ClassSyncWidget',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'app.classsync.classsync.widgets',
    'INFOPLIST_FILE' => 'ClassSyncWidget/Info.plist',
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)',
    'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
    'SWIFT_VERSION' => '5.0',
    'SKIP_INSTALL' => 'YES',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES'
  )
  if uses_group
    configuration.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'ClassSyncWidget/AppGroup.entitlements'
  else
    configuration.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) CLASSSYNC_WIDGET_DEMO'
  end
end

runner.build_configurations.each do |configuration|
  next unless uses_group
  configuration.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'ClassSyncWidget/AppGroup.entitlements'
  configuration.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = [
    '$(inherited)', 'CLASSSYNC_WIDGETS', ('CLASSSYNC_WIDGET_GROUP_TEST' if mode == 'app-group-test')
  ].compact.join(' ')
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
