# Xcode Cloud + CloudKit Backup Setup

This project now supports automatic backup of local collection/favorites data to CloudKit and includes an Xcode Cloud bootstrap script.

## 1) Configure CloudKit entitlement

1. Open `ScholarsGallery.xcodeproj` in Xcode.
2. Select target `ScholarsGallery` -> **Signing & Capabilities**.
3. Ensure **iCloud** is enabled.
4. Enable **CloudKit** and add your container (for example `iCloud.<bundle-id>`).
5. Confirm `ScholarsGallery/ScholarsGallery.entitlements` includes the container ID.

## 2) Configure Xcode Cloud workflow

1. In Xcode, open **Product -> Xcode Cloud -> Create Workflow**.
2. Select branch and scheme `ScholarsGallery`.
3. Under workflow scripts, set **Post-clone script** path to:
   - `ci_scripts/ci_post_clone.sh`
4. Keep Build/Test actions enabled for the iOS simulator destination.

## 3) Backup behavior in app

- On first app launch, it attempts to restore the latest CloudKit backup.
- When app moves to background, it uploads collection and favorites backups.
- Backups are stored in the user's **private CloudKit database** and are account-scoped.

## 4) Notes

- If iCloud is unavailable, app continues local-only without failing.
- Backup payload is JSON text for:
  - `collection.records`
  - `favorites.artworkIDs`
