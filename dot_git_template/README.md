# Git Template Directory

This directory contains templates that will be copied to any new Git repository initialized using `git init`.

## What's included

- **hooks/**: Pre-commit hooks automatically installed by pre-commit
- **pre-commit-config.yaml**: A sample pre-commit configuration file that can be copied to your projects

## Usage

When you run `git init` in a new directory, the pre-commit hooks will be automatically set up in your repository.

### Setting up pre-commit in a new repository

1. Copy the sample pre-commit config to your project:

   ```sh
   cp ~/.git_template/pre-commit-config.yaml .pre-commit-config.yaml
   ```

1. Customize the config as needed for your project

1. The pre-commit hooks are already installed in the local `.git/hooks` directory thanks to the template, so you're ready to go!

This setup ensures consistent code quality across all your repositories.
