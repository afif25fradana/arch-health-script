# Linux Health Check Scripts 🩺

![Maintained](https://img.shields.io/badge/Maintained?-Maybe LOL-green?style=for-the-badge)
![Language](https://img.shields.io/badge/Made%20with-Bash-blue?style=for-the-badge&logo=gnu-bash)
![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)

A collection of health check and diagnostic reporting scripts for major Linux families. This toolkit is designed to be fast, safe, and provide clear, actionable insights into your system's condition.

Currently supported systems:
* **Arch Linux** & derivatives (EndeavourOS, Manjaro, etc.)
* **Debian/Ubuntu** & derivatives (Linux Mint, Pop!_OS, etc.)

---

## ✨ Key Features (Common to All Scripts)

* **Comprehensive Checks**: Analyzes Kernel, Hardware, Drivers, Packages, Services, and system logs.
* **Fast Parallel Execution**: Runs checks simultaneously in a safe, isolated manner to provide reports quickly.
* **Weighted Health Score**: Gives a 0-100 score with intelligent weighting for different types of issues.
* **Multi-Format Reports**: Automatically generates reports in `.log` (colorized), `.md` (Markdown), and `.html` formats.
* **Smart Dependency Handling**: Detects missing tools and suggests an installation command without crashing the script.
* **Safe by Design**: Never runs `sudo` commands automatically, ensuring user control and system security.

---

## 🚀 Getting Started

1.  **Clone this repository:**
    ```bash
    git clone [https://github.com/afif25fradana/health-check.git](https://github.com/afif25fradana/health-check.git)
    cd health-check
    ```

2.  **Make the scripts executable:**
    ```bash
    chmod +x arch-check.sh ubuntu-check.sh
    ```

3.  **Run the script for your system!** See the sections below for details.

---

## Arch Linux Version (`arch-check.sh`)

![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)

A health check script tailored for `pacman`-based systems.

#### ▶️ Usage
```bash
./arch-check.sh [OPTIONS]
```
**Example:** Save reports to a `reports/` directory.
```bash
./arch-check.sh -o reports/
```

#### 📦 Dependencies
For a full report, it's recommended to have these packages installed:
* `pciutils` (for `lspci`)
* `lm-sensors` (for `sensors`)

---

## debianUbuntu / Debian Version (`ubuntu-check.sh`)

![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

A health check script adapted for `apt`-based systems.

#### ▶️ Usage
```bash
./ubuntu-check.sh [OPTIONS]
```
**Example:** Run in summary mode.
```bash
./ubuntu-check.sh -s
```

#### 📦 Dependencies
For the most detailed report, it's recommended to have these packages installed:
* `pciutils` (for `lspci`)
* `lm-sensors` (for `sensors`)
* `deborphan` (for a thorough orphaned package check)
* `debsums` (for checking package file integrity)

---

## 💡 Shared CLI Options

Both scripts accept the same set of command-line options for a consistent experience.

| Flag | Long Version    | Description                                  |
| :--- | :-------------- | :------------------------------------------- |
| `-f` | `--fast`        | Skips slower, more intensive checks.         |
| `-s` | `--summary`     | Displays only a brief summary in the terminal. |
| `-c` | `--no-color`    | Disables colorized output.                   |
| `-o` | `--output-dir`  | Specifies the directory to save report files. |
| `-v` | `--version`     | Shows the script version and exits.          |
| `-h` | `--help`        | Shows the help message.                      |

---

## 📜 License

This project is licensed under the **MIT License**. See the `LICENSE` file for full details.
