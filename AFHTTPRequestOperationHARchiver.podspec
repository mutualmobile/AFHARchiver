Pod::Spec.new do |s|
  s.name         = 'AFHTTPRequestOperationHARchiver'
  s.version      = '0.0.1'
  s.license		   = {
    :type => 'MIT',
    :file => 'LICENSE'
  }
  s.summary      = 'An AFNetworking extension to automatically generate a HTTP Archive file of all of your network request!'
  s.author       = {
    'Kevin Harwood' => 'kevin.harwood@mutualmobile.com'
  }
  s.source = {
    :git => 'https://github.com/mutualmobile/AFHTTPRequestOperationHARchiver.git',
    :commit => 'HEAD'
  }
  s.source_files = 'AFHTTPRequestOperationHARchiver'
  s.requires_arc = true
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'
  s.dependency 'AFNetworking', '~> 1.0'

end