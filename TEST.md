# Testing Artefiles Without Affecting Your System

This guide explains how to test these dotfiles without modifying your actual system configuration.

## Prerequisites

- [chezmoi](https://chezmoi.io/) installed on your system
- [GitHub CLI](https://cli.github.com/) installed and authenticated

## Testing with a Temporary Directory

This method uses a temporary configuration file and environment variables to apply changes to a test directory instead of your home directory.

### Step 1: Create a Temporary Config File

Create a file named `tmp-config.yaml` with the following content:

```yaml
data:
  # The name and email will be automatically fetched from GitHub CLI
  # You can override them here if needed
  name: "test-user"
  email: "test@example.com"
sourceDir: /path/to/artefiles/repo   # Replace with actual path to this repository
destDir: /tmp/chezmoi-test           # Temporary destination directory
```

### Step 2: Initialize chezmoi with the Test Config

```bash
# Create the test directory
mkdir -p /tmp/chezmoi-test

# Initialize chezmoi with the repository
CHEZMOI_CONFIG=/path/to/tmp-config.yaml XDG_CONFIG_HOME=/tmp/test-xdg chezmoi init --source=/path/to/artefiles/repo
```

### Step 3: Run a Dry Run to See Changes

```bash
# See what changes would be made
CHEZMOI_CONFIG=/path/to/tmp-config.yaml XDG_CONFIG_HOME=/tmp/test-xdg chezmoi apply --dry-run --verbose
```

### Step 4: Apply Changes to Test Directory

If the dry run looks good, you can apply the changes to the test directory:

```bash
# Apply changes to the test directory
CHEZMOI_CONFIG=/path/to/tmp-config.yaml XDG_CONFIG_HOME=/tmp/test-xdg chezmoi apply
```

### Step 5: Explore the Test Environment

You can now explore the applied configuration in the test directory:

```bash
# List files in the test directory
ls -la /tmp/chezmoi-test
```

### Cleanup

When you're done testing, simply delete the temporary directories:

```bash
rm -rf /tmp/chezmoi-test /tmp/test-xdg
```

## Notes

- The test environment won't have all your real system's context, so some template functions might behave differently
- Installation scripts won't be executed in dry-run mode
- Remember to replace `/path/to/artefiles/repo` with the actual path to the repository on your system
