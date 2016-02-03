#
#  Be sure to run `pod spec lint libSub.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "libSub"
  s.version      = "0.0.1"
  s.summary      = "A short description of libSub."

  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  s.description  = <<-DESC
  libSub does fancy audio things.
                   DESC

  s.license      = "MIT"
  s.homepage 	 = "http://isubapp.com"
  s.author             = { "Justin Hill" => "jhill.d@gmail.com" }
  s.source       = { :git => "http://github.com/einsteinx2/libSub.git", :tag => "#{s.version}" }

  s.source_files  = "Sub", "Sub/**/*.{h,m}", "Frameworks", "Frameworks/**/*.{h,m}"
  s.exclude_files = "Frameworks/EX2Kit"
  s.platform	 = :ios, "7.0"

  s.dependency "EX2Kit"
  s.dependency "TBXML"
  s.dependency "SBJson", "~> 3.0"
  s.dependency "ZipKit"
  s.dependency "RaptureXML"
  s.dependency "FMDB"
  s.dependency "MKStoreKit"
  s.dependency "CocoaHTTPServer"
  s.dependency "Flurry-iOS-SDK"
  s.dependency "EX2Kit"

  s.frameworks = "Security"
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2',
                 'GCC_PREPROCESSOR_DEFINITIONS' => '$(GCC_PREPROCESSOR_DEFINITIONS) IOS=1' }
  s.vendored_libraries = "Frameworks/libBASS/*.a"
  s.libraries = "xml2", "bass", "bass_ape", "bass_fx", "bass_mpc", "bassflac", "bassmix", "bassopus", "basswv"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If your library depends on compiler flags you can set them in the xcconfig hash
  #  where they will only apply to your library. If you depend on other Podspecs
  #  you can include multiple dependencies to ensure it works.

  # s.requires_arc = true

  # s.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
  # s.dependency "JSONKit", "~> 1.4"

end
