# Linux Health Check Suite 🩺

A smart, fast, and portable diagnostic toolkit for major Linux families. It runs parallel checks, provides a weighted health score, and gives you clear, actionable insights into your system's condition.

**Supported Systems:**
*   **Arch Linux** & derivatives (EndeavourOS, Manjaro, etc.)
*   **Debian/Ubuntu** & derivatives (Linux Mint, Pop!_OS, etc.)

---

## 🚀 Quick Install & Usage

Get up and running in seconds. The installer will copy the scripts to a standard system location, allowing you to run `health-check` from any directory.

1.  Clone the repository
    ```bash
    git clone https://github.com/afif25fradana/health-check.git
    cd health-check
    ```

2.  Run the installer (it will handle permissions for you)
    ```bash
    chmod +x install.sh  # Grant execute permissions
    ./install.sh         # Recommended: Installs locally for your user
    ```
    OR
    ```bash
    sudo ./install.sh    # Optional: Installs system-wide for all users
    ```

3.  Run it from anywhere!
    ```bash
    health-check --summary
    ```

After installation, you can safely delete the cloned `health-check` folder.

---

## 🗑️ Uninstallation

To remove the health check suite, run the `uninstall.sh` script from the cloned repository directory.

**Note:** If you encounter a "Permission denied" error when running `./uninstall.sh`, you may need to grant execute permissions first.

Then, proceed with uninstallation:
```bash
chmod +x uninstall.sh  # Grant execute permissions
./uninstall.sh       # For local user installations
```
OR
```bash
sudo ./uninstall.sh  # For system-wide installations
```

The uninstaller will automatically detect the installation type and remove all the relevant files. It will also ask if you want to remove the user configuration file.

---

## ✨ Key Features

*   **One Command to Rule Them All**: A single `health-check` command auto-detects the OS (Arch, Debian, etc.) and runs the appropriate script.
*   **Comprehensive Diagnostics**: Covers System, Kernel, Hardware, Drivers, Packages, Services, and Logs.
*   **Fast Parallel Execution**: Runs checks concurrently to deliver reports in seconds.
*   **Weighted Health Score**: Provides a 0-100 score to instantly gauge system health.
*   **Smart Dependency Handling**: Detects missing tools and suggests an installation command without crashing.
*   **Safe by Design**: The script runs without requiring `sudo`, ensuring system safety and user control.
*   **Highly Portable**: Uses POSIX-compliant shell features and `/etc/os-release` for reliable OS detection.
*   **Customizable**: Tweak behavior via a simple configuration file (skip checks, change log directories, adjust scoring).

---

## 📸 Screenshots

<p align="center">
  <img src="https://res.cloudinary.com/dta7ppwxj/image/upload/v1756044002/Screenshot_20250824_204801_bschz6.png" alt="Health Check Install" width="48%">
  &nbsp;&nbsp;
  <img src="https://res.cloudinary.com/dta7ppwxj/image/upload/v1756044009/Screenshot_20250824_204829_cxo6es.png" alt="Health Check Summary 1" width="48%">
</p>
<p align="center">
  <img src="https://res.cloudinary.com/dta7ppwxj/image/upload/v1756046061/Screenshot_20250824_212710_gexycm.png" alt="Health Check Report 1" width="48%">
  &nbsp;&nbsp;
  <img src="https://res.cloudinary.com/dta7ppwxj/image/upload/v1756046059/Screenshot_20250824_212728_v7b9zh.png" alt="Health Check Report 2" width="48%">
</p>
<p align="center">
  <img src="https://res.cloudinary.com/dta7ppwxj/image/upload/v1756044003/Screenshot_20250824_204926_epvfmb.png" alt="Health Check Uninstall" width="48%">
  &nbsp;&nbsp;
  <img src="https://res.cloudinary.com/dta7ppwxj/image/upload/v1756044000/Screenshot_20250824_204909_ykrerc.png" alt="Health Check Help" width="48%">
</p>

---
## 🏗️ Project Structure

The suite is organized into a clean, maintainable structure:

```
.
├── src/
│   ├── health-check.sh          # Main launcher script
│   ├── health-check.conf        # Default configuration
│   ├── common/
│   │   └── functions.sh         # Shared library for logging, colors, etc.
│   └── scripts/
│       ├── arch_health_check.sh # Arch-specific checks
│       └── Ubuntu_health_check.sh # Debian/Ubuntu-specific checks
├── install.sh                   # Installer
├── uninstall.sh                 # Uninstaller
├── README.md                    # Project documentation
└── LICENSE                      # MIT License
```

---

## 💡 Command-Line Options

All options are passed through the main `health-check` command.

| Flag | Long Version    | Description                                  |
| :--- | :-------------- | :------------------------------------------- |
| `-f` | `--fast`        | Skips slower, more intensive checks.         |
| `-s` | `--summary`     | Displays only a brief summary in the terminal. |
| `-c` | `--no-color`    | Disables colorized output.                   |
| `-o` | `--output-dir`  | Specifies where to save report files.        |
| `-h` | `--help`        | Shows the help message.                      |

**Example:**
```bash
health-check --fast --summary
```

---

## ⚙️ Configuration

Upon installation, a default configuration file is created at one of the following locations:
-   **System-wide:** `/etc/health-check/health-check.conf`
-   **User-local:** `~/.config/health-check/health-check.conf`

You can copy the system-wide file to your user-local directory and modify it to override the defaults. The user-local configuration always takes precedence.

**Available Options:**

*   `skip_checks`: A space-separated list of checks to exclude.
    *   Available checks: `system_info`, `hardware`, `drivers`, `packages`, `services`, `logs`.
    *   Example: `skip_checks = hardware drivers`
*   `log_dir`: The directory where report logs are saved.
    *   Example: `log_dir = /home/user/Documents/reports`
*   `warning_score`: The health score threshold below which the result is considered a warning.
    *   Example: `warning_score = 80`
*   `critical_score`: The health score threshold below which the result is considered critical.
    *   Example: `critical_score = 60`
*   `deductions`: A comma-separated list of `issue:points` to customize scoring.
    *   Example: `deductions = failed_services:30,orphans:10`

---

## 📜 License

This project is licensed under the **MIT License**. See the `LICENSE` file for full details.
