
# 🧩 Emoji Cheat Sheet for PowerShell Scripts

This guide provides a list of useful emojis that can be used in **PowerShell scripts**, especially in environments like **Visual Studio Code**. Emojis help improve script output readability and add visual cues for status messages.

---

## ✅ How to Use Emojis in PowerShell

You can use emojis in PowerShell in two ways:

### 🔹 Method 1: Copy & Paste Emoji
Simply paste the emoji symbol directly into your script string:
```powershell
Write-Output "✅ Operation completed successfully."
```

### 🔹 Method 2: Use Unicode Hex Code
Use the `[char]` cast with the emoji's Unicode value:
```powershell
$check = [char]0x2705
Write-Output "$check Operation completed successfully."
```

Make sure your file is saved as **UTF-8** and your terminal supports Unicode.

---

## 📋 Emoji Table

| Emoji | Description             | Unicode Hex | PowerShell Example              |
|--------|--------------------------|--------------|----------------------------------|
| ✅     | Check Mark Button        | `0x2705`     | `[char]0x2705`                   |
| ❌     | Cross Mark               | `0x274C`     | `[char]0x274C`                   |
| ⚠️     | Warning Sign             | `0x26A0`     | `[char]0x26A0`                   |
| 🔄     | Refresh / In Progress    | `0x1F504`    | `[char]0x1F504`                  |
| 🔁     | Repeat                   | `0x1F501`    | `[char]0x1F501`                  |
| 🕒     | Clock / Time             | `0x1F552`    | `[char]0x1F552`                  |
| 💾     | Save Icon                | `0x1F4BE`    | `[char]0x1F4BE`                  |
| 📁     | Folder                   | `0x1F4C1`    | `[char]0x1F4C1`                  |
| 📂     | Open Folder              | `0x1F4C2`    | `[char]0x1F4C2`                  |
| 📊     | Bar Chart                | `0x1F4CA`    | `[char]0x1F4CA`                  |
| 📈     | Upward Chart             | `0x1F4C8`    | `[char]0x1F4C8`                  |
| 📉     | Downward Chart           | `0x1F4C9`    | `[char]0x1F4C9`                  |
| 💡     | Lightbulb / Tip          | `0x1F4A1`    | `[char]0x1F4A1`                  |
| 🔒     | Locked                   | `0x1F512`    | `[char]0x1F512`                  |
| 🔓     | Unlocked                 | `0x1F513`    | `[char]0x1F513`                  |
| 🧠     | Brain / Intelligence     | `0x1F9E0`    | `[char]0x1F9E0`                  |
| 🔍     | Search / Inspect         | `0x1F50D`    | `[char]0x1F50D`                  |
| 🧹     | Cleanup / Cleanup Task   | `0x1F9F9`    | `[char]0x1F9F9`                  |
| 🛠️     | Tools / Maintenance      | `0x1F6E0`    | `[char]0x1F6E0`                  |
| 🟢     | Green Circle (Success)         | `0x1F7E2`     | `[char]0x1F7E2`           |
| 🔴     | Red Circle (Error)             | `0x1F534`     | `[char]0x1F534`           |
| 🟡     | Yellow Circle (Warning)        | `0x1F7E1`     | `[char]0x1F7E1`           |
| 🟠     | Orange Circle (In Progress)    | `0x1F7E0`     | `[char]0x1F7E0`           |
| 🔵     | Blue Circle (Info)             | `0x1F535`     | `[char]0x1F535`           |
| ♻️     | Recycling / Reused             | `0x267B`      | `[char]0x267B`            |
| 💥     | Crash / Explosion              | `0x1F4A5`     | `[char]0x1F4A5`           |
| 🚨     | Alert / Incident               | `0x1F6A8`     | `[char]0x1F6A8`           |
| 🔧     | Wrench / Maintenance           | `0x1F527`     | `[char]0x1F527`           |
| 🖥️     | Computer / Server              | `0x1F5A5`     | `[char]0x1F5A5`           |
| 🗂️     | File Index / Organized Files   | `0x1F5C2`     | `[char]0x1F5C2`           |
| 📦     | Package / Artifact             | `0x1F4E6`     | `[char]0x1F4E6`           |
| ⏳     | Hourglass (Running)            | `0x23F3`      | `[char]0x23F3`            |
| ⌛     | Hourglass Done                 | `0x231B`      | `[char]0x231B`            |
| 🧪     | Lab / Test / Experiment        | `0x1F9EA`     | `[char]0x1F9EA`           |
| 🚀     | Deployment / Launch            | `0x1F680`     | `[char]0x1F680`           |
| 📤     | Upload                         | `0x1F4E4`     | `[char]0x1F4E4`           |
| 📥     | Download                       | `0x1F4E5`     | `[char]0x1F4E5`           |
| 🧰     | Toolbox                        | `0x1F9F0`     | `[char]0x1F9F0`           |
| 💣     | Critical / Crash               | `0x1F4A3`     | `[char]0x1F4A3`           |
| 🗑️     | Trash / Deleted                | `0x1F5D1`     | `[char]0x1F5D1`           |
| 📜     | Script / Logs / History        | `0x1F4DC`     | `[char]0x1F4DC`           |
---

## 🧪 Sample Output in PowerShell

```powershell
$check = [char]0x2705
$warn  = [char]0x26A0
$fail  = [char]0x274C

Write-Output "$check Operation completed successfully."
Write-Output "$warn Warning: Low disk space."
Write-Output "$fail Error: Operation failed."
```

---

## 📝 Notes

- Ensure your script file is saved as **UTF-8** encoding.
- Use a font that supports emoji (e.g., **Cascadia Code**, **Segoe UI Emoji**).
- Works in Windows PowerShell 5.1+, PowerShell Core, and VS Code terminal.

---

## 📦 License

This cheat sheet is free to use and share. Emoji characters are sourced from the [Unicode Consortium](https://unicode.org/).
