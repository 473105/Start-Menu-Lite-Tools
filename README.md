## Preface
I realize that this tool covers a very niche use case, but I wanted to restore the stock Windows 10 Start Menu back to a clean, intentional, and useful state. It always felt like over time the menu becomes a disorganized shortcut dumping ground for every app installation - and the only time I end up using it is just to shut down my PC. My app aims to solve this issue. So if a clean Start Menu is something you've been missing in your life, then I'm sure this little program will be a welcome companion on your machine.

# Start Menu Lite Tools (SMLT)
This PowerShell-based tool is a safe editor and organizer for your Start Menu shortcuts in Windows 10. It is built to make edits in the simulated grid first as pending actions, and only commit changes to the real Start Menu with the user’s approval.
This means that every action in this program is staged first, and nothing touches the real Start Menu until the "Apply All Changes" button is pressed.
Start Menu Lite Tools is meant to give you control over renaming, moving, creating new shortcuts, changing icons, and cleaning up folders without the mess of manual file/registry trial-and-error.
<br>Once your Start Menu is customized, the SMLT app can also act as a deployment mediator, packaging your curated layout into a portable backup, allowing for instant cloning of your organized menu across other Windows 10 installations.
<br>This tool was intended for use on the vanilla Start Menu, although it can potentially work on heavily modified menus as well, since the program does not touch the UI structure. Try testing it in a VM first to avoid unpredictable behavior.
- No installation is required, just run the launcher. 
- The SMLT app is not optimized for speed, so it will require a little patience.
- This app is only for the `All Apps` section in the Start Menu, not for `Tiles`.
<div align="center"><img width="535" height="370" alt="SMLT_img 2" src="https://github.com/user-attachments/assets/04fa11ef-3cad-4acd-b5dc-9b0615324e9e" /></div>

<br></br>
## Download and Launch

- Download the zip file and extract anywhere.
- Double-click `Launch SMLT.cmd` to run Start Menu Lite Tools.
- Double-click `Launch IA.cmd` to run Icon Allocator.

Alternatively, run directly from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\Start_Menu_Lite_Tools_vX.X.XX.ps1
```
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\Icon_Allocator_vX.XX.ps1
```
`Replace "X" with version number`
<br></br>
<br></br>

<div align="center">
<h2 align="center">
Support the Project
</h2>
If this project was helpful to you, please consider supporting ongoing development:

[![Donate with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=MEUXL5RKQQ84U)
</div>

<br></br>
## Filesystem Structure

```text
/Start-Menu-Lite-Tools
  README.md
  Start Menu Lite Tools v#.#.##.zip
      Launch SMLT.cmd   . . . . . . . . . . . . . launcher for START MENU LITE TOOLS
      Launch IA.cmd   . . . . . . . . . . . . . . launcher for ICON ALLOCATOR
      Start_Menu_Lite_Tools_v#.#.##.ps1   . . . . main START MENU LITE TOOLS app
      Icon_Allocator_v#.##.ps1  . . . . . . . . . ICON ALLOCATOR companion app for icon category management
         /User Settings
            /Icon Categories  . . . . . . . . . . folder containing icon category profiles
                *user_icon_category.json*
             IconSourceDirectories.json   . . . . saved icon source paths & toggle settings in IA
             user-presets.json  . . . . . . . . . user preferences and UI toggle settings in SMLT
         /Addons  . . . . . . . . . . . . . . . . user added registry file storage
             AddonNodes.json  . . . . . . . . . . notes and color metadata for addon buttons
             *user_regedit.reg*
  LICENSE
```

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
- Addons section is a consolidation of user registry files as buttons

## Addons Panel

- Located under `misc.` tab, and is intended as a collection for user's personal registry edit files.
- Planned action: 
   - Paste registry text and generate a clickable addon button in the Addons panel.
   - Copy registry file directly into `Addons` folder, and a clickable button appears after restarting the app.
   - Personalize buttons by changing their border color.

<br></br>
## Icon Allocator 

This helper app lets you search, categorize, and extract icons stored on your system. 
It was originally created to help me pull system icons for the SMLT interface during the early stages of development, but over time it grew beyond its original purpose and became a standalone tool with some useful features, so I decided to include it as a supporting component of the main program.

<div align="center"><img width="535" height="370" alt="SMLT_Icon_Allocator_img2" src="https://github.com/user-attachments/assets/e8c8cbc8-4f70-43d9-843c-ddfbf1fbaeec" />
</div>
<br></br>

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

## Typical Workflow

1. Open SMLT.
2. Click **Create Backup** (recommended).
3. Make edits in the simulated grid and right panel.
4. Review pending actions.
5. Click **Apply All Changes** when ready.
6. Use **Restore Backup** if you need to roll back.
  - Reference the built-in `Guide` if unsure about something.

## Data and Folders

SMLT will automatically create these folders if they are missing:

- `User Settings` for presets and category/config files
- `Pending Items` for saved pending-state files
- `Start Menu Backups` for backup zip files
- `Addons` for user-provided registry edit files
  
## Notes

- Some Windows system shortcuts and shell entries have special behavior by design.
- On some Windows builds, drag/drop behavior can be affected by elevation context (admin account vs regular).
- If drag/drop is blocked, use the dedicated browse buttons.
- The project is tuned for Windows 10 behavior.
- The program will mimic your Windows theme for a way to preview your work.

## Contributing

Issues and pull requests are welcome. For bug reports, include:

- Windows version/build
- App version
- Reproducible steps
- Screenshot or error text

## Disclaimer

This tool modifies real Start Menu shortcuts and folder structure after user confirmation. Even though the app will create automatic backups, creating a manual backups before making any changes is highly recommended. I have already tested this app on a handful of Windows 10 LTSC installations, and will be testing Pro and Home versions soon.
