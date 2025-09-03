# PowerShell script to pull only the student and resources folders from the hacks containing a devcontainer file

# Define the repository URL
$repoUrl = "https://github.com/Microsoft/WhatTheHack"

# Create a new branch for the changes
try {
    $branchName = "auto-update-$(Get-Date -Format 'yyyy-MM-dd')"
    git config --global user.name "GitHub Actions Codespace Automation"
    git config --global user.email "actions@github.com"
    
   
    # Check if branch exists on remote
    git fetch origin
    $remoteBranchExists = git branch -r --list "origin/$branchName"
    
    if ($remoteBranchExists) {
        Write-Host "Branch $branchName already exists on remote. Checking out and pulling latest changes..."
        git checkout $branchName
        if ($LASTEXITCODE -ne 0) {
            # If local branch doesn't exist, create it tracking the remote
            git checkout -b $branchName origin/$branchName
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to checkout existing branch $branchName"
            }
        } else {
            # Pull latest changes if we successfully checked out the local branch
            git pull origin $branchName
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to pull latest changes for branch $branchName"
            }
        }
    } else {
        Write-Host "Creating new branch $branchName..."
        git checkout -b $branchName
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create branch $branchName"
        }
    }
    Write-Host "Successfully created or checked out branch: $branchName"

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

#Temporarily point to test branch
try {
    Write-Host "Switching to Codespaces-Devcontainer branch..."
    git checkout Codespaces-Devcontainer
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to checkout Codespaces-Devcontainer branch"
    }
} catch {
    Write-Error "Error switching to branch: $_"
    Set-Location ..
    Remove-Item -Recurse -Force tempRepo -ErrorAction SilentlyContinue
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
        
        #If hack folder doesn't exist, create it
        if (!(Test-Path "../$($hack.Name)")) {
            New-Item -ItemType Directory -Path "../$($hack.Name)" -Force
        }

        # Copy everything except the Coaches folder
        Copy-Item "$($hack.Name)\*" -Destination "../$($hack.Name)" -Recurse -Force -Exclude "Coach"

        # Copy the devcontainer file as well
        if (!(Test-Path "../.devcontainer/$($hack.Name)")) {
            New-Item -ItemType Directory -Path "../.devcontainer/$($hack.Name)" -Force
        }

        Copy-Item ".devcontainer/$($hack.Name)/devcontainer.json" -Destination "../.devcontainer/$($hack.Name)/devcontainer.json" -Force
        
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


git commit -m "Daily pull of student and resources folders"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to commit changes"
}

git push origin $branchName
if ($LASTEXITCODE -ne 0) {
    throw "Failed to push branch to origin"
}

Write-Host "Successfully committed and pushed branch: $branchName"

# Create a pull request using GitHub CLI
try {
    if ($env:GH_TOKEN) {
        Write-Host "Creating pull request..."
        gh pr create --title "Daily pull of student and resources folders" --body "Automated pull of student and resources folders from WhatTheHack repository" --base main --head $branchName
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create pull request"
        }
        Write-Host "Successfully created pull request"
    } else {
        Write-Warning "GH_TOKEN environment variable not set. Pull request not created automatically."
        exit 1
    }
} catch {
    Write-Error "Error creating pull request: $_"
    exit 1
}

