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

 2. Make the installer executable
```bash
chmod +x install.sh
```

3. Run the installer (choose one)
```bash
./install.sh         # Recommended: Installs locally for your user
```
OR
```bash
sudo ./install.sh    # Optional: Installs system-wide for all users
```

4. Run it from anywhere!
```bash
health-check --summary
```

After installation, you can safely delete the cloned `health-check` folder.

---

## ✨ Key Features

* **One Command to Rule Them All**: The `health-check` launcher automatically detects your OS and runs the correct diagnostic script.
* **Comprehensive Checks**: Analyzes Kernel, Hardware, Drivers, Packages, Services, and system logs.
* **Fast Parallel Execution**: Runs checks simultaneously to provide reports quickly.
* **Weighted Health Score**: Gives a 0-100 score to instantly gauge your system's health.
* **Smart Dependency Handling**: Detects missing tools and suggests an installation command without crashing.
* **Safe by Design**: Never requires `sudo` to run the checks, ensuring user control and system security.

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

## 📜 License

This project is licensed under the **MIT License**. See the `LICENSE` file for full details.
