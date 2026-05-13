# ScholarsGallery — common tasks (run from this directory).
.PHONY: server smoke sync-promo test test-isolated test-server ios-test ios-ui-test ios-test-all build-server build-server-isolated chmod-scripts

chmod-scripts:
	@chmod +x dev ScholarsGallery/run-vapor-server.sh 2>/dev/null || true
	@find Scripts ci_scripts -maxdepth 1 -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

server: chmod-scripts
	./dev

smoke: chmod-scripts
	./Scripts/smoke_verify_server.sh

sync-promo: chmod-scripts
	./Scripts/sync_wcs_promo_assets.sh

test:
	swift test

# Separate SwiftPM build dir — use when another process holds `.build` (Xcode, hung swift).
test-isolated:
	swift test --build-path .build-isolated

test-server:
	swift test --filter ServerGenerationTests

# iOS unit tests (Xcode; requires Simulator, e.g. iPhone 17).
ios-test:
	xcodebuild -project ScholarsGallery.xcodeproj -scheme ScholarsGallery -configuration Debug \
		-sdk iphonesimulator \
		-destination 'platform=iOS Simulator,name=iPhone 17' \
		-only-testing:ScholarsGalleryTests test

# iOS UI tests — serial by default (see ci_scripts/run_ui_tests.sh).
ios-ui-test: chmod-scripts
	./ci_scripts/run_ui_tests.sh

# Unit tests then UI tests (CI-friendly order).
ios-test-all: ios-test ios-ui-test

build-server:
	swift build --product ScholarsGalleryServer

build-server-isolated:
	swift build --product ScholarsGalleryServer --build-path .build-isolated
