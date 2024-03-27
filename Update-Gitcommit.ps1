# Commit Git function
function Commitgit {
    param(
        [string]$message = "Updating changes."        
        )
    git add .
    git commit -m $message
    git push
}