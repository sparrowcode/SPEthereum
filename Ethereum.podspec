Pod::Spec.new do |s|

  s.name = 'Ethereum'
  s.version = '1.0.0'
  s.summary = ''
  s.homepage = 'https://github.com/sparrowcode/swift-ethereum'
  s.source = { :git => 'https://github.com/sparrowcode/swift-ethereum.git', :tag => s.version }
  s.license = { :type => 'MIT', :file => "LICENSE" }
  s.author = { 'Ivan Vorobei' => 'hello@sparrowcode.io' }
  
  s.swift_version = '5.1'
  s.ios.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'

  s.source_files  = 'Sources/Ethereum/**/*.swift'

end
