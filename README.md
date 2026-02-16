# BLSIC
# BLSIC: Bitcoin Lottery Swarm Intelligence Console
**Version:** Beta v0.8.4  
**Author:** Geoff Whitemore (Chip)  
**Platform:** Windows 11 (PowerShell 7.5.4+)  
**Hardware:** Designed for Bitaxe and NerdQaxe miner APIs  
**Regional Focus:** United Kingdom (£ GBP / GMT)

---

## 1. ⚡ Critical Requirement: PowerShell 7
**BLSIC will not function on standard "Windows PowerShell" (v5.1).** The console relies on the modern rendering engine and high-speed JSON handling found only in PowerShell 7.

### Installation:
1.  **Search your Start Menu** for **"PowerShell 7"**. Look for the **Black Icon**.
2.  If not installed, run this in your current blue PowerShell window:
    ```powershell
    iex "& { $(irm [https://aka.ms/install-powershell.ps1](https://aka.ms/install-powershell.ps1)) } -UseMSI"
    ```

---

## 🚀 2. How to Run (The Unlock)
Windows blocks scripts by default for security. To bypass the "lock" and launch the console in one go, open **PowerShell 7** in your project folder and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\BLSIC_MONITOR_Beta_0.8.4.ps1
Note: Using -ExecutionPolicy Bypass only unlocks the script for this specific session. It does not permanently lower your system security.

Pro Tip: For the best visual experience and ASCII graph rendering, run the command inside the Windows Terminal app.

🏗️ 3. Master Architectural Map
The script is organized into functional logic groups to ensure real-time performance and data persistence.

Group A: The Foundation (Core & Hunt)
[0.2] The Brain: Manages swarm_config.json. It stores your ROI data, hardware manifest, and All-Time Best (ATB) shares.

[1.0] The Hunt: A dynamic discovery engine. It sweeps your network for Bitaxe and NerdQaxe miner APIs and determines a Target Performance Baseline.

Group B: The Heartbeat (Data Engine)
[4.1] Polling Engine: Connects to hardware every 10 seconds. Includes a Coin Detector to automatically distinguish between BTC and BCH mining ports.

[4.4] The Header: Renders the primary HUD, displaying your live Swarm hashrate vs. your 10.9 TH/s target.

Group C: The Ticket Office (Lottery & Luck)
[7.0] The Share Table: A high-contrast ladder comparing Current Difficulty vs. your All-Time Best share.

[10.0] Ticket Office: The core probability engine. It translates live hashrate into real-time odds, compared against the UK National Lottery.

Group D: The Display (UI & Finance)
[8.0] Trend Graph: An ASCII history chart visualizing your 10.9 TH/s journey over a 100-tick rolling buffer.

[11.0] The Ledger: A live P&L financial model that calculates your "Daily Burn" and ROI based on UK energy tariffs.

🔄 The First Run Experience
Currency: Everything is tracked in GBP (£).

Electricity Rate: Enter your cost per kWh on first launch for accurate ROI tracking.

Alignment: During the initial hunt, the UI may look scrambled. Press [R]EFRESH once the scan finishes to lock the grid.

🛠️ Troubleshooting & Commands
[H]UNT: Force a network scan to discover new hardware.

[A]DD: Manually add a specific miner IP to your swarm manifest.

[D]ELETE: Remove a specific miner IP from your active manifest.

[R]EFRESH: Hard-reset the UI. Use after first discovery or window resize.

[N]EXT / [P]REV: Cycle through pages for larger swarms.

[Q]UIT: Safely saves all ROI data and "All-Time Best" shares to the Brain.

📄 Legal & Contributions
License: This project is licensed under the BSD 3-Clause License - see the LICENSE file for details.

Contributions: We welcome help! Please read CONTRIBUTING.md before submitting Pull Requests.

Support the Project: BTC: 34Q2ySpjcUGnEkxe7JfPxKCh2BYNPgMyYu
