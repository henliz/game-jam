Dialogue System Summary

### Files Created

|File|Purpose|
|---|---|
|[Data/dialogue.json](vscode-webview://1r0h796a48mnd4fdusntir37g7hq3meh1ant1l8ff3ctd6iao9t1/Data/dialogue.json)|JSON data structure holding all dialogue entries|
|[Scenes/dialogue_manager.gd](vscode-webview://1r0h796a48mnd4fdusntir37g7hq3meh1ant1l8ff3ctd6iao9t1/Scenes/dialogue_manager.gd)|Core DialogueManager singleton script|
|[Scenes/dialogue_manager.tscn](vscode-webview://1r0h796a48mnd4fdusntir37g7hq3meh1ant1l8ff3ctd6iao9t1/Scenes/dialogue_manager.tscn)|Scene wrapper for the autoload|
|[Scenes/dialogue_caption.gd](vscode-webview://1r0h796a48mnd4fdusntir37g7hq3meh1ant1l8ff3ctd6iao9t1/Scenes/dialogue_caption.gd)|Caption UI controller with fade animations|
|[Scenes/dialogue_caption.tscn](vscode-webview://1r0h796a48mnd4fdusntir37g7hq3meh1ant1l8ff3ctd6iao9t1/Scenes/dialogue_caption.tscn)|Caption UI scene (centered bottom of screen)|
|[default_bus_layout.tres](vscode-webview://1r0h796a48mnd4fdusntir37g7hq3meh1ant1l8ff3ctd6iao9t1/default_bus_layout.tres)|Audio bus layout with Music, SFX, and Dialogue buses|

### Folder Structure Created

```
Audio/
├── Dialogue/   # Story dialogue audio files
├── Context/    # Player reaction audio (surprised, success, etc.)
├── Music/      # Background music
└── SFX/        # Sound effects
```

### Usage

**Play specific dialogue by ID:**

```gdscript
DialogueManager.play("intro_welcome")
DialogueManager.play("keeper_first_artifact")
```

**Play random contextual audio:**

```gdscript
DialogueManager.play_random_by_type("context", "surprised")
DialogueManager.play_random_by_type("context", "success")
DialogueManager.play_random_by_type("context", "confused")
```

**Listen for signals:**

```gdscript
DialogueManager.dialogue_started.connect(_on_dialogue_started)
DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
```

### Audio Buses

- **Master** - Main output
- **Music** - Background music (0 dB)
- **SFX** - Sound effects (0 dB)
- **Dialogue** - Voice/captions (+3 dB boost for clarity)

The system gracefully handles missing audio files by displaying captions with a duration based on text length. Just add `.ogg` files to the Audio folders matching the paths in the JSON.
