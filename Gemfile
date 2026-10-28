source "https://rubygems.org"

# Screenshot capture and framing only. The build and TestFlight upload stay on
# altool in mise/tasks/ci - fastlane is not in the shipping path.
# 2.241.1 is the floor because it is the first deliver that knows APP_IPHONE_DUO. An older one
# matches the Duo's 1398x2034 captures to no display type and refuses the whole upload.
gem "fastlane", "~> 2.241", ">= 2.241.1"
