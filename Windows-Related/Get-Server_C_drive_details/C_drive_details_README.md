# Server Disk & Uptime Checker (PowerShell)

## 📌 Overview
This PowerShell script checks multiple remote servers for:
- **Connectivity status** (Online / Unreachable / Error Code description)
- **C: drive details** (Total GB, Used GB, Free GB, Free %)
- **Uptime in days**

The script reads server names from a `servers.txt` file and outputs results in the console and a CSV file.

---

## ⚙️ Features
- ✅ Reads server list from a text file
- ✅ Displays **progress bar** while scanning servers
- ✅ Uses `Get-CimInstance` for faster & more reliable WMI queries
- ✅ Provides **disk usage** and **uptime**
- ✅ Exports results to CSV for reporting

---

## 📂 File Structure
```
📁 Project Folder
 ├─ ServerDiskReport.ps1   # Main script
 ├─ servers.txt            # List of server names (one per line)
 └─ ServerDiskReport.csv   # Output CSV file (generated after running script)
```

---

## 📝 Prerequisites
- **PowerShell 5.1** or **PowerShell 7+**
- Network connectivity to target servers
- Permissions to query WMI/CIM data remotely  
  (Ensure **Remote Management** and **Firewall** rules allow WMI/WinRM)
- `servers.txt` file in the same folder as the script

---

## 📄 servers.txt Example
```
server01
server02
server03.domain.local
```

---

## 🚀 Usage
1. **Place the script and `servers.txt` in the same folder.**
2. Open PowerShell as Administrator.
3. Navigate to the script folder:
   ```powershell
   cd "C:\Path\To\Script"
   ```
4. Run the script:
   ```powershell
   .\ServerDiskReport.ps1
   ```
5. View results:
   - In **console output** (formatted table)
   - In **`ServerDiskReport.csv`** (for Excel or reporting tools)

---

## 📊 Example Output (Console)
```
ComputerName   Status   TotalGB  UsedGB  FreeGB  FreePercent  UptimeDays
------------   ------   -------  ------  ------  -----------  ----------
server01       Online     100.00   65.20   34.80         35           12
server02       Online     250.00  100.50  149.50         60           45
server03       Unreachable N/A     N/A     N/A           N/A          N/A
```

---

## 🛠 How It Works
1. **Ping Check** – Uses `Test-Connection` to check if the server is reachable.
2. **Disk Info** – Queries `Win32_LogicalDisk` for C: drive stats.
3. **Uptime** – Queries `Win32_OperatingSystem` for `LastBootUpTime`.
4. **Progress Bar** – Shows scanning progress in real time.
5. **Export** – Saves all results to CSV.

---

## ⚠️ Notes
- If **Uptime** shows `N/A`, it usually means WMI/WinRM is blocked or permissions are insufficient.
- If disk info shows `N/A`, check firewall/WMI permissions for the target server.
- For large server lists, consider running from a **management server** close to your targets for faster results.

---

## 📄 License
This script is provided **as-is** without warranty.  
You may modify and use it freely in your environment.

---
