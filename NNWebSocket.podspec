Pod::Spec.new do |s|
  s.name               = "NNWebSocket"
  s.version            = '0.2.0'
  s.summary            = 'WebSocket(RFC 6455) client library.'
  s.homepage           = 'https://github.com/growthfield/NNWebSocket'
  s.authors            = 'growthfield'
  s.license            = 'Apache License, Version 2.0'
  s.source             = { :git => 'https://github.com/growthfield/NNWebSocket.git', :commit => '5ba29c78b2ae6e24d28220d9221a1b77c8532822' }
  s.source_files       = 'NNWebSocket/*.{h,m,c}'
  s.requires_arc       = true
  s.ios.frameworks     = %w{CFNetwork Security}
  s.ios.deployment_target = '5.0'
end
