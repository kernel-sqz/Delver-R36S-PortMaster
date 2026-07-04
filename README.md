# Delver for PortMaster

This port uses an open-source version of the Delver engine together with assets from the official Steam release.

> **A legal copy of Delver on Steam is required.**

Steam AppID: **249630**

---

# Installation

Copy the contents of this archive to:

```
/roms/ports/
```

You should end up with:

```
/roms/ports/
├── delver.sh
└── delver/
    └── game.jar
```

---

# Obtaining the game assets

## Option 1 (Recommended)

If Delver is already installed through Steam (Linux version), simply copy:

```
delver.jar
```

into:

```
/roms/ports/delver/
```

Launch the game from PortMaster.

On first launch, the port will automatically:

- extract all required assets
- remove unnecessary files
- prepare the game for future launches

No additional setup is required.

---

## Option 2 (Steam Console)

If you do not have the Linux version installed, you can download the Linux depot directly using the Steam Console.

Enable the Steam console:

```
steam://open/console
```

or launch Steam with:

```
-console
```

Then execute:

```
download_depot 249630 249633 5590742085084855222
```

Steam will download the Linux depot.

The downloaded files will be located in a directory similar to:

### Windows

```
Steam\steamapps\content\app_249630\depot_249633\
```

### Linux

```
~/.steam/steam/steamapps/content/app_249630/depot_249633/
```

### macOS

```
~/Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/MacOS/steamapps/content/app_249630/depot_249633/
```

Copy:

```
delver.jar
```

into:

```
/roms/ports/delver/
```

Then launch the game from PortMaster.

---

# Notes

The original `delver.jar` is only required for the initial asset extraction.

After the first successful launch, it will be automatically removed to save storage space.

## Recommended Settings

For the best experience on handheld devices:

- Set **Graphics Quality** to **Low**.
- Adjust the **gamepad controls** to better suit handheld play. In particular, it is recommended to remap the **Attack** action and assign a dedicated button for **Jump**.

These changes provide noticeably better performance and a more comfortable gameplay experience on PortMaster devices.

---

# Credits

- Original game: Priority Interrupt
- Delver Engine: https://github.com/Interrupt/delverengine
- PortMaster: https://portmaster.games
