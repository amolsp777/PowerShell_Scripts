# Microsoft Security Updates Filter Script

This PowerShell script helps you retrieve and filter Microsoft Patch Tuesday updates using the `MsrcSecurityUpdates` module. It allows you to exclude specific products and view the remaining updates in a searchable HTML table.

## 📦 Prerequisites

- PowerShell 5.1 or later
- Internet access
- [MSRC Security Updates PowerShell Module](https://www.powershellgallery.com/packages/MsrcSecurityUpdates)

## 🛠️ Installation

```powershell
Install-Module -Name MsrcSecurityUpdates -Force -SkipPublisherCheck
Import-Module MsrcSecurityUpdates
```

## 📅 Usage

1. **Set the Patch Tuesday Document ID**  
   Replace the `$docId` with the desired Patch Tuesday release ID (e.g., `"2025-Sep"`).

   ```powershell
   $docId = "2025-Sep"
   ```

2. **Fetch and Parse the Update Data**

   ```powershell
   $msTuePatches = Get-MsrcCvrfDocument -ID $docId | Get-MsrcCvrfAffectedSoftware
   ```

3. **Preview the First Entry (Optional)**

   ```powershell
   $msTuePatches | Select -First 1
   ```

4. **Exclude Specific Products**

   Define a list of product names or patterns to exclude:

   ```powershell
   $excludeProducts = @(
       "Windows Server 2012",
       "Office 2013",
       "Windows Server 2008*",
       "Azure*",
       "azl*",
       "cbl2*",
       "Xbox Gaming Services*",
       "Microsoft * 2016 *"
   )
   ```

5. **Filter and Display the Updates**

   This section filters out excluded products and displays the rest in an interactive HTML table:

   ```powershell
   $msTuePatches |
   Where-Object {
       $fullNames = @($_.FullProductName)
       -not ($fullNames | Where-Object { $name = $_; $excludeProducts | Where-Object { $name -like $_ } })
   } |
   Select-Object `
       CVE,
       Severity,
       Weakness,
       Impact,
       @{Name='CustomerActionRequired';Expression={ ($_.'Customer Action Required' -join ', ') }},
       @{Name='RestartRequired';Expression={ ($_.RestartRequired -join ', ') }},
       @{Name = 'KBArticleID'; Expression = { $_.KBArticle.ID }},
       @{Name = 'KBArticleURL'; Expression = { $_.KBArticle.URL }},
       @{Name = 'KBArticleSubType'; Expression = { $_.KBArticle.SubType }},
       @{Name='FullProductName';Expression={ ($_.FullProductName -join '; ') }},
       @{Name='Supercedence';Expression={ ($_.Supercedence -join ', ') }} |
   Out-HtmlView -SearchPane -SearchPaneLocation bottom -Filtering
   ```

## 🔍 Output

The script generates a searchable and filterable HTML table with the following columns:

- CVE
- Severity
- Weakness
- Impact
- Customer Action Required
- Restart Required
- KB Article ID, URL, and SubType
- Full Product Name
- Supercedence

## ✅ Example Use Case

Filter out legacy or unsupported products from the monthly security updates to focus only on relevant patches for your environment.

## 📄 License

This script is provided as-is under the MIT License.

---

**Author:** Amol   
**Last Updated:** September 2025
