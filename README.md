# Linux Health Check Suite 🩺

A smart, fast, and safe diagnostic toolkit for major Linux families. It runs parallel checks, provides a weighted health score, and gives you clear, actionable insights into your system's condition.

**Supported Systems:**
* **Arch Linux** & derivatives (EndeavourOS, Manjaro, etc.)
* **Debian/Ubuntu** & derivatives (Linux Mint, Pop!_OS, etc.)

---

## 🚀 Quick Install & Usage

Get up and running in seconds. The installer will copy the scripts to a standard system location, allowing you to run `health-check` from any directory.

1. Clone the repository
```bash
git clone https://github.com/afif25fradana/health-check.git
cd health-check
```

2. Run the installer (it will handle permissions for you)
```bash
./install.sh         # Recommended: Installs locally for your user
```
OR
```bash
sudo ./install.sh    # Optional: Installs system-wide for all users
```

3. Run it from anywhere!
```bash
health-check --summary
```

After installation, you can safely delete the cloned `health-check` folder.

---

## 🗑️ Uninstallation

To remove the health check suite, run the `uninstall.sh` script from the cloned repository directory.

```bash
./uninstall.sh       # For local user installations
sudo ./uninstall.sh  # For system-wide installations
```

The uninstaller will automatically detect the installation type and remove all the relevant files. It will also ask if you want to remove the user configuration file.

---

## ✨ Key Features

* **One Command to Rule Them All**: The `health-check` launcher automatically detects your OS and runs the correct diagnostic script.
* **Comprehensive Checks**: Analyzes Kernel, Hardware, Drivers, Packages, Services, and system logs.
* **Fast Parallel Execution**: Runs checks simultaneously to provide reports quickly.
* **Weighted Health Score**: Gives a 0-100 score to instantly gauge your system's health.
* **Smart Dependency Handling**: Detects missing tools and suggests an installation command without crashing.
* **Customizable Configuration**: Tweak script behavior via a simple configuration file (e.g., skip certain checks, change log directories).
* **Safe by Design**: Never requires `sudo` to run the checks, ensuring user control and system security.
* **Robust and Portable**: Scripts are designed to be run from anywhere on the system, with no hardcoded paths.

---

## 💡 Command-Line Options

All options are passed through the main `health-check` command.

| Flag | Long Version    | Description                                  |
| :--- | :-------------- | :------------------------------------------- |
| `-f` | `--fast`        | Skips slower, more intensive checks.         |
| `-s` | `--summary`     | Displays only a brief summary in the terminal. |
| `-c` | `--no-color`    | Disables colorized output.                   |
| `-o` | `--output-dir`  | Specifies where to save report files.        |
| `-v` | `--version`     | Shows the script version and exits.          |
| `-h` | `--help`        | Shows the help message.                      |

**Example:**
```bash
health-check --fast --summary
```

---

## ⚙️ Configuration

Upon installation, a default configuration file is created at one of the following locations:
- **System-wide:** `/etc/health-check/health-check.conf`
- **User-local:** `~/.config/health-check/health-check.conf`

You can copy the system-wide file to your user-local directory and modify it to override the defaults. The user-local configuration always takes precedence.

**Available Options:**

*   `skip_checks`: A space-separated list of checks to exclude.
    *   Example: `skip_checks = hardware drivers`
*   `log_dir`: The directory where report logs are saved.
    *   Example: `log_dir = /home/user/Documents/reports`
*   `warning_score`: The health score threshold below which the result is considered a warning.
    *   Example: `warning_score = 80`
*   `critical_score`: The health score threshold below which the result is considered critical.
    *   Example: `critical_score = 60`

---

## 📜 License

This project is licensed under the **MIT License**. See the `LICENSE` file for full details.
