# DockCheck

DockCheck is a minimal SwiftUI demo for logistics teams reviewing package inspections before shipment. Open any of the five checklist items to see the finding and its timestamped images.

<p align="center">
  <img src="docs/dockcheck-preview.png" alt="DockCheck checklist for lot A-104 with the completion step expanded and an inspection frame at 00:27" width="340">
</p>

*Screen preview rendered from the app’s layout and bundled demo data.*

The sample covers label verification, QR scanning, damage inspection, security sealing, and completion. The damage check is marked **Not evidenced** because the available frames show the top of the package and leave its sides out of view.

The demo runs offline with staged images and predefined findings. It requires no account, server, or API key.

## Run locally

On macOS with Xcode and an iOS 17 or later simulator runtime, run the following from the repository root.

```sh
brew install xcodegen
xcodegen generate
open DockCheck.xcodeproj
```

Select an iPhone simulator in Xcode and press **Run**.

## License

[MIT](LICENSE). The sample images come from the original Visual SOP Proof project.
