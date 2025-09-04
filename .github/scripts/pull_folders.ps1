# PowerShell script to pull only the student and resources folders from the hacks containing a devcontainer file

# Define the repository URL
$repoUrl = "https://github.com/Microsoft/WhatTheHack"

# Configure git user and ensure we're on main branch
try {
    git config --global user.name "GitHub Actions Codespace Automation"
    git config --global user.email "actions@github.com"
    
} catch {
    Write-Error "Error with git operations: $_"
    exit 1
}

# Clone the repository to a temporary directory
try {
    Write-Host "Cloning repository from $repoUrl..."
    git clone $repoUrl tempRepo
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone repository"
    }
} catch {
    Write-Error "Error cloning repository: $_"
    exit 1
}

# Change to the repository directory
try {
    Set-Location tempRepo
} catch {
    Write-Error "Error changing to repository directory: $_"
    exit 1
}

# Iterate through the hacks from the devcontainer directory
try {
    $hacks = Get-ChildItem -Path .devcontainer -Directory
    Write-Host "Found $($hacks.Count) hack directories"
} catch {
    Write-Error "Error reading .devcontainer directory: $_"
    Set-Location ..
    Remove-Item -Recurse -Force tempRepo -ErrorAction SilentlyContinue
    exit 1
}

foreach ($hack in $hacks) {
    try {
        Write-Host "Processing hack: $($hack.Name)"
        
        $sourceResourcesPath = "$($hack.Name)/Student/Resources"
        $destHackPath = "../$($hack.Name)"
        $destResourcesPath = "$destHackPath/Student/Resources"
        
        # Create destination directory structure if it doesn't exist
        if (!(Test-Path $destResourcesPath)) {
            New-Item -ItemType Directory -Path $destResourcesPath -Force
        }
        
        # Use rsync to sync directories with deletion of extra files
        # -a = archive mode (preserves permissions, timestamps, etc.)
        # -v = verbose
        # --delete = delete files in destination that don't exist in source
        
        Write-Host "Syncing Student/Resources for: $($hack.Name) using rsync"
        rsync -av --delete "$sourceResourcesPath/" "$destResourcesPath/"
        
        if ($LASTEXITCODE -ne 0) {
            throw "rsync failed with exit code: $LASTEXITCODE"
        }
        
        Write-Host "Successfully synced Student/Resources for: $($hack.Name)"

        # Handle devcontainer file sync
        $destDevcontainerPath = "../.devcontainer/$($hack.Name)"
        
        if (!(Test-Path $destDevcontainerPath)) {
            New-Item -ItemType Directory -Path $destDevcontainerPath -Force
        }
        
        # Use rsync for devcontainer file too
        $sourceDevcontainerDir = ".devcontainer/$($hack.Name)/"
        Write-Host "Syncing devcontainer for: $($hack.Name) using rsync"
        rsync -av --delete "$sourceDevcontainerDir" "$destDevcontainerPath/"
        
        if ($LASTEXITCODE -ne 0) {
            throw "rsync failed for devcontainer $($hack.Name) with exit code: $LASTEXITCODE"
        }
        
        Write-Host "Successfully synced devcontainer for: $($hack.Name)"
        Write-Host "Successfully processed hack: $($hack.Name)"
    } catch {
        Write-Warning "Error processing hack $($hack.Name): $_"
        # Continue with other hacks instead of failing completely
    }
}

# Change back to the original directory
Set-Location ..

# Clean up the temporary repository
Remove-Item -Recurse -Force tempRepo

git add .
if ($LASTEXITCODE -ne 0) {
    throw "Failed to add files to git"
}

# Check if there are any changes to commit
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Host "Changes detected, committing..."
    git commit -m "Daily pull of student and resources folders"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to commit changes"
    }

    git push origin main
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to push changes to main"
    }

    Write-Host "Successfully committed and pushed changes to main branch"
} else {
    Write-Host "No changes detected, skipping commit"
}
