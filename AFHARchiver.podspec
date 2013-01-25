Pod::Spec.new do |s|
  s.name         = 'AFHARchiver'
  s.version      = '0.0.1'
  s.license		   = {
    :type => 'MIT',
    :file => 'LICENSE'
  }
  s.summary      = 'An AFNetworking extension to automatically generate a HTTP Archive file of all of your network requests'
  s.author       = {
    'Kevin Harwood' => 'kevin.harwood@mutualmobile.com'
  }
  s.source = {
    :git => 'https://github.com/mutualmobile/AFHARchiver.git',
    :commit => 'HEAD'
  }
  s.source_files = 'AFHARchiver'
  s.requires_arc = true
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'
  s.dependency 'AFNetworking', '~> 1.0'

end