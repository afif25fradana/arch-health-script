# Arch Health Script 🩺

Just a little script I made to quickly check the health of my Arch Linux setup (works on EndeavourOS, etc. too). It runs a bunch of checks in parallel to be super fast and spits out a nice report.

---

## 📸 Demo

*(Seriously, put a screenshot or a GIF here. It makes the project look 10x cooler. Use `peek`!)*

![image](https://github.com/afif25fradana/arch-health-script/assets/106969564/67f70b74-ed5d-4f11-9e28-ac7f3d56d787)


---

## ✨ So, what's it do?

Basically, it checks the important stuff:
* **System & Kernel**: What kernel you're running.
* **Hardware**: Basic CPU, RAM, and disk info.
* **Drivers**: Looks for devices without drivers.
* **Packages**: Finds orphaned packages and files missing from packages.
* **Services**: Checks for any `systemd` services that have failed.
* **Logs**: Scans `journalctl` for recent errors or warnings.
* **Scoring**: Gives you a simple 0-100 score based on what it finds.

---

## 🚀 Getting Started

Getting started is easy.

1.  **Clone the repo:**
    ```bash
    git clone https://github.com/afif25fradana/arch-health-script.git
    cd arch-health-script
    ```

2.  **Make it runnable:**
    ```bash
    chmod +x arch_health_check.sh
    ```

3.  **Run it!**
    ```bash
    ./arch_health_check.sh
    ```
    I recommend sending the reports to a dedicated folder:
    ```bash
    ./arch_health_check.sh -o reports/
    ```

---

## 💡 Options

You can use these flags to change how it runs:

| Flag | Long Version | What it Does |
| :--- | :--- | :--- |
| `-f` | `--fast` | Skips the slow checks. |
| `-s` | `--summary` | Only shows a short summary. |
| `-c` | `--no-color` | Turns off the colors. |
| `-o` | `--output-dir` | Tells it where to save reports. |
| `-v` | `--version` | Shows the script version. |
| `-h` | `--help` | Shows the help message. |

---

## 📦 Does it need anything?

For everything to work, it's best if you have these installed:
* `pciutils` (for `lspci`)
* `lm-sensors` (for `sensors`)

If you're missing something, the script will tell you at the end. No stress.

---

## 📜 License

It's under the **MIT License**. Do whatever you want with it.
