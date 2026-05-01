## Preface
I realize that this tool covers a very niche use case, but I wanted to restore the stock Windows 10 Start Menu back to a clean, intentional, and useful state. It always felt like over time the menu becomes a disorganized shortcut dumping ground for every app installation - and the only time I end up using it is just to shut down my PC. My app aims to solve this issue. So if a clean Start Menu is something you've been missing in your life, then I'm sure this little program will be a welcome companion on your machine.

# Start Menu Lite Tools (SMLT)
This PowerShell based tool is a safe editor and organizer for your Start Menu shortcuts in Windows 10. It is built to make edits in the simulated grid first as pending actions, and only commit changes to the real Start Menu with the user’s approval.
This means that every action in this program is staged first, and nothing touches the real Start Menu until the "Apply All Changes" button is pressed.
Start Menu Lite Tools is meant to give you control over renaming, moving, creating new shortcuts, changing icons, and cleaning up folders—without the mess of manual file/registry trial and error.
This is also meant to be used on the vanilla Start Menu, although it can potentially work for heavily modified menus as well, since the program does not touch the UI structure. Try testing it in a VM first to avoid unpredictable behavior.
- No installation is required, just run the launcher. 
- The SMLT app is not optimized for speed, so it will require a little patience.
- This app is only for `All Apps` section in the Start Menu, not for Tiles.
<div align="center"><img width="535" height="370" alt="SMLT_img 2" src="https://github.com/user-attachments/assets/04fa11ef-3cad-4acd-b5dc-9b0615324e9e" /></div>

## Download and Launch

1. Download the zip folder and extract it.
2. Double-click `Launch SMLT.cmd` to run Start Menu Lite Tools.
3. Double-click `Launch IA.cmd` to run Icon Allocator.


<div align="center">
<h2 lign="center">
Support the Project
</h2>
If this project was helpful to you, please consider supporting ongoing development:

[![Donate with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=MEUXL5RKQQ84U)
</div>


## Included Files

- `Start_Menu_Lite_Tools_v#.#.##.ps1`: main START MENU LITE TOOLS app
- `Icon_Allocator_v#.##.ps1`: ICON ALLOCATOR companion app for icon category management
- `Launch SMLT.cmd`: launcher for START MENU LITE TOOLS
- `Launch IA.cmd`: launcher for ICON ALLOCATOR

## Safety Model

SMLT uses a pending-first flow:

1. You make changes in the simulated grid.
2. Edits are marked as pending.
3. Nothing is written to the real Start Menu until you click **Apply All Changes** and confirm.

This makes large edits much easier to review before commit.

## Main Features

- Simulated Start Menu editor with pending-state tracking
- Rename, move, create, delete, and icon editing
- Backup/restore (zip-based snapshots)
- Duplicate shortcut target flagging (optional toggle)
- Broken shortcut target detection
- Light/dark theme support
- Saved user presets (theme and UI options)
- Grid refresh/sync after external filesystem edits
- Built-in guide window
- Addons panel (upcoming): consolidates user registry tweak addons from an `Addons` folder
- 
## Addons Panel (Upcoming)

- Located in `misc.` under `Convert registry edit to Addon` and is intended as a collection for user's personal registry edit files.
- Planned action: 
   - Paste registry text and generate a clickable addon button in the Addons panel.
   - Copy registry file directly into `Addons` folder, and a clickable button appears after restarting the app.
   - 
## Icon Allocator 

This helper app lets you search, categorize, and extract icons stored on your system. 
It was originally created to help me pull system icons for the SMLT interface during the early stages of development, but over time it grew beyond its original purpose and became a standalone tool with some useful features, so I decided to include it as a supporting component of the main program.

<div align="center"><img width="535" height="370" alt="SMLT_Icon_Allocator_img2" src="https://github.com/user-attachments/assets/e8c8cbc8-4f70-43d9-843c-ddfbf1fbaeec" />
</div>
<p

- Create, load, save, and delete icon category JSON files
- Assign and unassign icons per category
- Show/mask category-based results
- Hide duplicates, show uncategorized, search by icon name
- Manage icon source directories
- Extract selected icons as `.ico` or `.png`



## Requirements

- Windows 10
- Windows PowerShell 5.1
- Administrator rights for full functionality

## Quick Start

Run with launchers (recommended):

- `Launch SMLT.cmd`
- `Launch IA.cmd`

Or run directly from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\Start_Menu_Lite_Tools_vX.X.XX.ps1
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\Icon_Allocator_vX.XX.ps1
```
(Replace "X" with version number)

## Typical Workflow

1. Open SMLT.
2. Click **Create Backup** (recommended).
3. Make edits in the simulated grid and right panel.
4. Review pending actions.
5. Click **Apply All Changes** when ready.
6. Use **Restore Backup** if you need to roll back.
  - Reference the built in `Guide` if unsure about something.

## Data and Folders

SMLT automatically creates these folders:

- `User Settings` for presets and category/config files
- `Pending Items` for saved pending-state files
- `Start Menu Backups` for backup zip files
- `Addons` for user-provided registry tweak addon files (upcoming panel integration)

## Notes

- Some Windows system shortcuts and shell entries have special behavior by design.
- On some Windows builds, drag/drop behavior can be affected by elevation context (admin account vs regular).
- If drag/drop is blocked, use the dedicated browse buttons.
- The project is tuned for Windows 10 behavior.
- The program will mimic your Windows theme for a convenient way to visualize your work.

## Repository Layout

```text
/Start-Menu-Lite-Tools
  README.md
  Start Menu Lite Tools v#.#.##.zip
      Launch SMLT.cmd
      Launch IA.cmd
      Start_Menu_Lite_Tools_v#.#.##.ps1
      Icon_Allocator_v#.##.ps1
      /User Settings
  LICENSE
```

## Contributing

Issues and pull requests are welcome. For bug reports, include:

- Windows version/build
- App version
- Reproduceable steps
- Screenshot or error text

## Disclaimer

This tool modifies real Start Menu shortcuts and folder structure after user confirmation. Even though the app wiil create automatic backups, it is best practice to create manual backups before applying changes.

