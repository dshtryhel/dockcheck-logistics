# DockCheck

DockCheck is a small SwiftUI example for logistics teams reviewing an outbound package inspection. Expand a checklist item to see the recorded finding and the timestamped frames behind it.

The bundled example covers the package label, QR scan, damage inspection, security seal, and completion. The available frames show the top of the package during the damage check, so the checklist marks that step **Not evidenced**.

This offline demo uses staged images and predefined findings. It runs without a server, account, or API key.

## Run on an iPhone Simulator

On macOS with Xcode and an iOS 17 or newer simulator runtime:

```sh
brew install xcodegen
xcodegen generate
open DockCheck.xcodeproj
```

Select an iPhone Simulator and press **Run**.

## License

[MIT](LICENSE). The sample frames come from the original Visual SOP Proof project.
