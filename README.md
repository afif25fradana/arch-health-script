# Arch Health Check Script

![Language](https://img.shields.io/badge/Made%20with-Bash-blue?style=for-the-badge&logo=gnu-bash)
![Version](https://img.shields.io/badge/Version-3.1-green?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)

A comprehensive system health check and diagnostic reporting script for Arch Linux and its derivatives (e.g., EndeavourOS, Manjaro). It's built to run quickly using safe parallel execution and generates easy-to-read reports in multiple formats.

---
## 🚀 Installation

1.  Clone this repository to your local machine:
    ```bash
    git clone [https://github.com/afif25fradana/arch-health-script.git](https://github.com/afif25fradana/arch-health-script.git)
    cd arch-health-script
    ```

2.  Make the script executable:
    ```bash
    chmod +x arch_health_check_v3.1.sh
    ```

---

## 📸 Demo

*(**Highly Recommended:** Replace this section with a screenshot or GIF showing the script in action. Use a tool like `peek` or `asciinema` to create a cool terminal demo!)*



---

## ✨ Key Features

* **Comprehensive Checks**: Analyzes the Kernel, Hardware, Drivers, Packages, Services, and system logs.
* **Parallel Execution**: Runs incredibly fast by safely executing multiple checks simultaneously.
* **Health Scoring**: Provides a system health score (0-100) based on warnings and errors found.
* **Flexible CLI Options**: Comes with flags like `--fast`, `--summary`, and `--no-color` for full control.
* **Multi-Format Reporting**: Automatically generates reports in `.log` (colorized), `.md` (Markdown), and `.html` formats.
* **Dependency Checker**: Intelligently detects missing tools and suggests an installation command without crashing.
* **Safe by Design**: Never runs `sudo` commands automatically, respecting user control and system security.

---

## 📦 Dependencies

This script is designed to run on a base Arch Linux installation, but for **full functionality**, these optional packages are recommended:

* `pciutils` (provides the `lspci` command)
* `usbutils` (provides the `lsusb` command)
* `lm-sensors` (provides the `sensors` command for temperature checks)
* `stress-ng` (for the CPU stress test - *not yet implemented in v3.1*)

If any of these packages are missing, the script will notify you in the final report.

---


## 💡 Usage

Run the script directly from your terminal inside the project folder.

#### **Basic Command**
```bash
./arch_health_check_v3.1.sh
```

#### **Saving Reports to a Specific Directory**
It is highly recommended to save reports to a separate directory (e.g., `reports/`) to keep your working directory clean. Ensure this directory is added to your `.gitignore` file.

```bash
./arch_health_check_v3.1.sh -o reports/
```

#### **Available Options**

| Short | Long | Description |
| :--- | :--- | :--- |
| `-f` | `--fast` | Skips slower checks (like `pacman -Qk`). |
| `-s` | `--summary` | Displays only a brief summary in the terminal. |
| `-c` | `--no-color` | Disables colorized output. |
| `-o` | `--output-dir` | Specifies the directory to save report files. |
| `-h` | `--help` | Shows this help message. |

---

## 📄 Example Output

Each run generates three report files in the specified output directory, named `arch-health-check-[TIMESTAMP]`:
* **.log**: The raw, colorized log, perfect for viewing in a terminal.
* **.md**: A Markdown-formatted report, ideal for documentation or Gists.
* **.html**: A self-contained HTML report that can be opened in any web browser.

---

## 📜 License

This project is licensed under the **MIT License**. See the `LICENSE` file for full details.
