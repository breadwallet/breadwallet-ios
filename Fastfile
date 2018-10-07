# fastlane/Fastfile
default_platform :ios

platform :ios do
  before_all do
    setup_circle_ci
  end

  desc "Runs all the tests"
  lane :test do
    scan
  end

  desc "Devbuild"
  lane :dev do
    match(type: "dev")
    gym(export_method: "dev")
  end
end
