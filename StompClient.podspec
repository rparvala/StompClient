Pod::Spec.new do |s|

  s.name         = "StompClient"
  s.version      = "0.3.0"
  s.summary      = "Simple STOMP client."
  s.description  = "This project is a simple STOMP client, and we use Starscream as a websocket dependency."
  s.homepage     = "https://github.com/Thinktiv/StompClient"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "ShengHua Wu" => "fantasy0404@gmail.com" }
  s.social_media_url   = "https://twitter.com/ShengHuaWu"
  s.platform     = :ios, "9.0"
  s.source       = { :git => "https://github.com/Thinktiv/StompClient.git", :tag => s.version.to_s }
  s.source_files  = "Sources/StompClient/*.swift"
  s.requires_arc     = true
  s.dependency "Starscream", "~> 3.0.0"

end
