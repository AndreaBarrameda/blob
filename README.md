# Virtual Assistant - macOS App

A floating virtual assistant inspired by Clippy that monitors your system and helps with tasks.

## Features

✨ **Floating Window** - Always accessible, movable assistant window
🔋 **System Monitoring** - Displays battery level, charging status, and running apps
🔊 **Volume Control** - Adjust system volume autonomously
💬 **Chat Interface** - Natural conversation with your assistant
📝 **Tasks & Reminders** - Manage reminders and tasks
🎵 **Now Playing** - See what's currently playing

## Building

### Requirements
- macOS 13+
- Swift 5.9+
- Xcode 14+

### Build from command line
```bash
cd VirtualAssistant
swift build
```

### Run
```bash
swift run VirtualAssistant
```

Or build and run with Xcode:
```bash
open -a Xcode .
# Then build and run from Xcode
```

## Permissions

The app will need these permissions:
- **System Events** - To monitor battery, apps, and system info
- **Audio** - To control volume

When the app first runs, you may see permission dialogs. Grant the necessary permissions for full functionality.

## Project Structure

```
Sources/VirtualAssistant/
├── VirtualAssistantApp.swift    # Main app entry point
├── AssistantView.swift          # Main UI and chat interface
├── SystemMonitor.swift          # System info and control
└── SystemInfoView.swift         # System information display
```

## Roadmap

- [ ] Claude API integration for better AI responses
- [ ] Persistent chat history
- [ ] Custom reminders with notifications
- [ ] Voice input/output
- [ ] Custom assistant appearance
- [ ] System automation tasks
- [ ] Music player controls
- [ ] Calendar integration

## Notes

- The app runs as an accessory app (doesn't appear in dock)
- Window stays on top and is always accessible
- Requires accessibility permissions for some features
