require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == 'Runner' }
abort 'Runner target not found' unless runner

def file_reference(group, path)
  group.files.find { |file| file.path == path } || group.new_file(path)
end

runner_group = project.main_group.find_subpath('Runner', true)
attributes_ref = file_reference(runner_group, 'ResonaActivityAttributes.swift')
manager_ref = file_reference(runner_group, 'ResonaLiveActivityManager.swift')

[attributes_ref, manager_ref].each do |reference|
  unless runner.source_build_phase.files_references.include?(reference)
    runner.source_build_phase.add_file_reference(reference)
  end
end

extension_target = project.targets.find { |target| target.name == 'ResonaLiveActivity' }
unless extension_target
  extension_target = project.new_target(
    :app_extension,
    'ResonaLiveActivity',
    :ios,
    '16.2'
  )
end

extension_group = project.main_group.find_subpath('ResonaLiveActivity', true)
extension_group.path = 'ResonaLiveActivity'
extension_group.name = nil
widget_ref = file_reference(extension_group, 'ResonaLiveActivityWidget.swift')
info_ref = file_reference(extension_group, 'Info.plist')

[widget_ref, attributes_ref].each do |reference|
  unless extension_target.source_build_phase.files_references.include?(reference)
    extension_target.source_build_phase.add_file_reference(reference)
  end
end

extension_target.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['CURRENT_PROJECT_VERSION'] = '1'
  development_team = ENV['DEVELOPMENT_TEAM']
  settings['DEVELOPMENT_TEAM'] = development_team unless development_team.to_s.empty?
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['INFOPLIST_FILE'] = 'ResonaLiveActivity/Info.plist'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.2'
  settings['MARKETING_VERSION'] = '1.0'
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'ai.synheart.resona.ResonaLiveActivity'
  settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  settings['SKIP_INSTALL'] = 'YES'
  settings['SWIFT_VERSION'] = '5.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
end

unless runner.dependencies.any? { |dependency| dependency.target == extension_target }
  runner.add_dependency(extension_target)
end

embed_phase = runner.copy_files_build_phases.find do |phase|
  phase.name == 'Embed Foundation Extensions'
end
embed_phase ||= runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.dst_subfolder_spec = '13'
unless embed_phase.files_references.include?(extension_target.product_reference)
  build_file = embed_phase.add_file_reference(extension_target.product_reference, true)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# Flutter's Thin Binary phase reads the completed app bundle. Embed the
# extension first to avoid an Xcode dependency cycle through Runner.app.
runner.build_phases.delete(embed_phase)
thin_index = runner.build_phases.index { |phase| phase.display_name == 'Thin Binary' }
runner.build_phases.insert(thin_index || runner.build_phases.length, embed_phase)

project.targets.each do |target|
  target.build_configurations.each do |configuration|
    if ['16.0', '16.1'].include?(configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'])
      configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.2'
    end
  end
end

project.save
