# Commit Git function
function Commitgit {
    param(
        [string]$message = "Updating changes."        
        )
    git add .
    git commit -m $message
    git push
}

Function gitstatus {
    Write-Host "Checking Git Repo status" -ForegroundColor Yellow
Set-Location 'P:\Git_asp777\Public\PowerShell_Scripts\'
git status 
}
