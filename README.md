# DockCheck

DockCheck is a SwiftUI app for reviewing outbound package inspections. Open a checklist item to inspect timestamped frames, record a decision, and add notes before handing the inspection off to the next shift. Filter for follow-up items or export the full inspection as a PDF with its supporting images.

<p align="center">
  <img src="docs/dockcheck-preview.png" alt="DockCheck checklist for lot A-104 with the package label step expanded and PDF export visible" width="340">
</p>

*Screen preview based on the app layout and bundled inspection for lot A-104.*

## Review an inspection

- Check the supporting frames for the package label, QR scan, surface inspection, security seal, and completion.
- Use **Edit review** to mark a step **Accepted** or **Follow-up required** and record any observations. Decisions and notes are saved on the device.
- Turn on **Show only follow-up items** to focus on checks that need another look.
- Use **Review summary** to track progress and share a text handoff with the decisions, notes, and frame timestamps. **Export PDF** saves the full inspection with evidence images, even when the checklist is filtered.

In the included inspection, the surface check is marked **Not evidenced** because the available frames show only the top of the package. A reviewer can flag it for follow-up and specify which views to request.

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
