#  WHAT AM I:
#  ----------------------------------------------------------------------------------------
#  BLSIC: BITCOIN LOTTERY SWARM INTELLIGENCE CONSOLE (Windows 11 Edition)
#  Requires - Version 7.5.4 Powershell
#  Recommend FONT SIZE 10 or 12 in PowerShell (Adjust through PS settings) in Portrait mode 1080 x 1920  
#  This release Version: Beta v0.8.4 [cite: 2026-02-15]
#  Author:  Chip Whitemore
#  GitHub:  https://github.com/[Your-Username]/[Your-Repo-Name]

#  ACKNOWLEDGMENTS:
#  ----------------------------------------------------------------------------------------
#  - Optimized for Bitaxe/NerdMiner/NerdQaxe hardware using AxeOS/ESP-Miner APIs.
#  - Developed for the solo-mining community. 
#==========================================================================================

#  SUPPORT THE PROJECT:
#  - If you found this useful, feel free to send me a coffee!
#  - Donate Bitcoin address: 34Q2ySpjcUGnEkxe7JfPxKCh2BYNPgMyYu
#==========================================================================================

#  QUICK START & FUNCTIONS:
#  ----------------------------------------------------------------------------------------
#  [N]EXT / [P]REV : Cycle through hardware pages.
#  [L]OCK          : Toggle Page-Lock (Prevents auto-cycling).
#  [H]UNT          : Force a network scan to discover new miners.
#  [X]REMOVE       : Enter removal mode to prune the swarm.
#  [A]DD           : Manually add a miner by IP address.
#  [R]EFRESH       : Hard-reset the UI. Fixes "Screen Tearing" or ANSI artifacts.
#  [Q]UIT          : Safely save the 'Brain' (swarm_config.json) and exit.
#
#  BETA NOTES & REGIONAL SETTINGS:
#  - REGIONAL ORIGIN: Developed in the UK. All financial calculations are in GBP (£).
#  - METRIC SYSTEM: Probabilities are weighted against the UK National Lottery odds.
#  - FIRST LAUNCH BUG: Press [R]EFRESH after the first scan to clear the buffer.
#  - DYNAMIC TARGETING: Calculated automatically as miners are added/removed.
#  - PAGING (EXPERIMENTAL): Tested to 4 nodes; feedback for larger swarms welcome.
#  - CONSOLE SYNC: Uses "Coordinate Lock" logic. Requires a Monospaced font.
#******************************************************************************************

#  LICENSE & TERMS:
#  ----------------------------------------------------------------------------------------
#  - This script is provided "As-Is" without any express or implied warranty.
#  - Permission is granted to use, copy, and modify for personal/non-commercial use.
#  - Attribution to the original author is required in all forks or redistributions.

#==========================================================================================
#  BLSIC: BITCOIN LOTTERY SWARM INTELLIGENCE CONSOLE (Windows 11 Edition)
#  MASTER ARCHITECTURAL MAP | PWSH v7.5.4 | Regional: UK (GBP/GMT) 
#==========================================================================================
#
#  GROUP A: THE FOUNDATION (Core & Hunt)
#  - Purpose: Environmental setup, subnet discovery, and hardware initialization.
#
#    [0.0 - 0.1] Infrastructure: UTF-8, High-Priority, and UK UI helpers (£/GMT).
#    [0.2]       The Brain: Loading swarm_config.json and data healing/migration.
#    [1.0]       The Hunt: Network discovery logic. (Critical: Must use .Name property).
#    [2.0]       Asset Entry: Captures Purchase Price for the CapEx model (GBP).
#
#------------------------------------------------------------------------------------------
#
#  GROUP B: THE HEARTBEAT (Data Engine)
#  - Purpose: Polls hardware APIs and synchronizes live data to script variables.
#
#    [3.0 - 4.0] Sync & Start: Maps JSON settings to RAM and triggers the main loop.
#    [4.1]       Polling Engine: Raw API calls (REST) for Hash, Power, and Pool Difficulty.
#    [4.2]       Share Tracker: Aggregates totals and monitors for All-Time Best (ATB).
#    [4.4]       The Header: Renders the primary dashboard (Live Swarm vs Calculated Target).
#
#------------------------------------------------------------------------------------------
#
#  GROUP C: MINING BRAIN (Logic & Shares)
#  - Purpose: Contextualizes data into block probability and performance metrics.
#
#    [4.5]       Net Health: Latency/Ping tests for Stratum pool stability.
#    [5.0]       Hardware Grid: Real-time J/T Efficiency, Thermals, and Amp safety.
#    [5.1]       Paging System: Logic for [N]EXT, [P]REV, and [L]OCK (Tested to 4 nodes).
#    [7.0]       Share Table: Renders CURR DIFF (Cyan) vs BEST DIFF (Magenta) ladder.
#    [10.0]      Ticket Office: UK Lottery-based probability comparison logic.
#
#------------------------------------------------------------------------------------------
#
#  GROUP D: THE DISPLAY (UI & Finance)
#  - Purpose: Management dashboard, ROI economics, and history persistence.
#
#    [8.0]       Trend Graph: ASCII history (Capped at 100-ticks).
#    [9.0]       Swarm Peaks: Tracking session records vs. global ATB performance.
#    [11.0]      The Ledger: Financial P&L, UK GMT formatting, and Daily GBP yield.
#    [11.1]      Asset Analytics: Investment summary (CapEx) and Swarm Avg £/TH.
#    [12.0]      Command Input: Interactive key-listener [N,P,L,H,X,A,R,Q].
#    [13.0]      Persistence: Saves the Brain (UTF-8) and updates the Windows Title Bar.
#
#==========================================================================================

#================================================================================
# ----------CODE STARTS----------------------------------------------------------
#================================================================================

Set-StrictMode -Version Latest

#===============================================================================
# ----- 0.0 RUNTIME & ENV PREP --------------------------------------------------
#===============================================================================
if ($IsWindows) {
    try {
        # Explicitly importing the module to ensure Get-NetIPAddress is available
        Import-Module NetTCPIP -ErrorAction Stop
    } catch {
        Write-Warning "NetTCPIP module is missing. Network discovery will use .NET fallback."
    }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
#===============================================================================
# ----- 0.1 HELPER SECTION --------------------------------------------------
#===============================================================================

# --- UI CONSTANTS & ESCAPE SEQUENCES ---
$esc = [char]27
$sep = "-" * 100
$gbp = "Â£"

# Logging Helper
function Write-Log {
    param([string]$Message)
    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Stamp] $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

# Helper: Friendly Pool Naming
function Get-PoolLabel {
    param($url)
    $u = "$url".ToLower()
    if ($u -match "solohash") { return "SOLOHASH" }
    if ($u -match "ckpool")   { return "CKPOOL" }
    if ($u -match "ocean")    { return "OCEAN" }
    if ($u -match "kano")     { return "KANO" }
    return "OTHER"
}

# Helper: Force-Sync JSON to Memory and Trigger UI Re-render
function Sync-SwarmState {
    param($NewBrain)
    
    # 1. Update the Global Brain in memory
    $global:brain = $NewBrain
    
    # 2. Update the active miner list used by the dashboard
    $global:miners = $global:brain.MinerManifest
    
    # 3. Clear the cached results from the last poll
    # This prevents the table from showing old rows for deleted miners
    $global:minerData = @()
    
    # 4. Wipe the screen and signal a loop restart
    Clear-Host
    Write-Host "`n [!] SWARM RECONFIGURED. RE-POLLING HARDWARE..." -ForegroundColor Cyan
    
    # We return $true to tell the Heartbeat Loop to break ($i=0)
    return $true
}


# Helper: Robust JSON Save with Retry Logic (Handles File-Locks/OneDrive)
function Save-Brain {
    param($Data, $Path)
    $maxRetries = 5; $retryCount = 0; $saved = $false
    while (-not $saved -and $retryCount -lt $maxRetries) {
        try {
            $Data | ConvertTo-Json -Depth 5 | Out-File $Path -Encoding UTF8 -ErrorAction Stop
            $saved = $true
        } catch {
            $retryCount++
            Start-Sleep -Milliseconds 250 
        }
    }
}

# Helper: Force-Sync JSON to Memory and Trigger UI Re-render
function Sync-SwarmState {
    param($NewBrain)
    
    # 1. Update the Global Brain (The master configuration)
    $global:brain = $NewBrain
    
    # 2. Update the active miner list (The target IPs)
    $global:miners = $global:brain.MinerManifest
    
    # 3. CRITICAL: Wipe the cached API results
    # Section 7.0 loops through $minerData. By wiping this, 
    # we ensure no 'ghost miners' remain on the ladder.
    $global:minerData = @()
    
    # 4. Wipe the physical screen
    Clear-Host
    Write-Host "`n [!] SWARM RECONFIGURED. REDRAWING TABLES..." -ForegroundColor Cyan
    
    return $true
}

# Helper: Format Diff values for UI (e.g., 35460000 -> 35.46M)
function Format-Diff {
    param([double]$diff)
    if ($diff -ge 1e12) { return "$([math]::Round($diff/1e12, 2))T" }
    if ($diff -ge 1e9)  { return "$([math]::Round($diff/1e9, 2))G" }
    if ($diff -ge 1e6)  { return "$([math]::Round($diff/1e6, 1))M" }
    if ($diff -ge 1e3)  { return "$([math]::Round($diff/1e3, 1))K" }
    return [math]::Round($diff, 0).ToString()
}

# Helper: Detect Coin Type via Stratum Port or Wallet Address
function Get-CoinType {
    param($url, $user)
    $u = "$url".ToLower(); $s = "$user".ToLower()
    # BCH: SoloHash ports 3337/3338 OR CashAddr prefixes (q, p, bitcoincash)
    if ($u -match ':333[78]' -or $u -match 'bch' -or $s -match '^(q|p|bitcoincash)') { return "BCH" }
    # BTC: SoloHash ports 3333/3334 OR Legacy/SegWit prefixes (1, 3, bc1)
    if ($u -match ':333[34]' -or $u -match 'btc' -or $s -match '^(1|3|bc1)') { return "BTC" }
    return "BTC" # Default fallback
}

# Helper: Manually Add a Miner with Auto-Target Calibration
function Add-ManualMiner {
    Write-Host "`n --- [ ADD MANUAL MINER ] ---" -ForegroundColor Yellow
    $mIP   = Read-Host " >> Enter Miner IP Address"
    $mName = Read-Host " >> Enter Friendly Name"
    
    if ($mIP -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
        try {
            # 1. Verify miner and get live hashrate for calibration
            $d = Invoke-RestMethod -Uri "http://$mIP/api/system/info" -TimeoutSec 2 -ErrorAction Stop
            $rawH = if ($d.psobject.Properties['hashRate']) { $d.hashRate } else { 0 }
            $thActual = [math]::Round($rawH/1000, 2)
            
            # 2. Assign internal category based on performance
            $mCat = if ($thActual -gt 5) { "MAX" } elseif ($thActual -gt 2) { "MID" } else { "MIN" }

            $newMiner = [PSCustomObject]@{ 
                IP=$mIP; 
                Name=$mName; 
                Category=$mCat; 
                Type=(Get-CoinType -url $d.stratumURL -user $d.stratumUser) 
            }

            # 3. Load Brain and perform "Healing" check
            $currentConfig = Get-Content $configPath -Encoding UTF8 | ConvertFrom-Json
            
            if (-not $currentConfig.Records) { $currentConfig | Add-Member -NotePropertyName "Records" -NotePropertyValue @{} }
            if (-not $currentConfig.Records.SessionBestShare) { $currentConfig.Records.SessionBestShare = 0 }
            if (-not $currentConfig.Records.AllTimeBestShare) { $currentConfig.Records.AllTimeBestShare = 0 }

            $manifest = @($currentConfig.MinerManifest)
            
            # 4. Prevent duplicates and Save
            if ($manifest.IP -contains $mIP) {
                Write-Host " [!] Miner with IP $mIP already exists in manifest." -ForegroundColor Yellow
            } else {
                $manifest += $newMiner
                $currentConfig.MinerManifest = $manifest
                $currentConfig | ConvertTo-Json -Depth 5 | Out-File $configPath -Encoding UTF8
                Write-Host " [+] Successfully added $mName ($thActual TH/s detected) at $mIP" -ForegroundColor Green
            }
            Start-Sleep -Seconds 2
        } catch {
            Write-Host " [!] Error: Could not verify miner at $mIP. Check connectivity." -ForegroundColor Red
            Start-Sleep -Seconds 3
        }
    }
}


#===============================================================================
# ----- 0.2 PARAMETERS & CONFIG LOADING -----------------------------------------
#===============================================================================
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -LiteralPath $PSCommandPath -Parent }
$configPath = Join-Path $ScriptRoot 'swarm_config.json'
$LogFile    = Join-Path $ScriptRoot 'swarm.log'

# --- PRE-FLIGHT INITIALIZATION  ---
# These variables MUST exist globally before the main loop starts 
# to prevent "Variable not set" errors in Section 4.4 Header.
$global:netHealth    = "INITIALIZING..."
$global:refreshTimer = 10
$global:poolString   = "SOLO"
$global:netDiffRaw   = 146e12  # Fallback difficulty
# --------------------------------------------

$thisProcess  = [System.Diagnostics.Process]::GetCurrentProcess()
if ($IsWindows) { $thisProcess.PriorityClass = 'High' }
$sessionStart = $thisProcess.StartTime
$gbp = [char]163   # £
$createNew   = $false
$isFirstRun  = $false  

if (Test-Path $configPath) {
    try {
        $rawJson = Get-Content $configPath -Raw | ConvertFrom-Json -ErrorAction Stop
        $brain = $rawJson
        if ($brain -is [Array]) { $brain = $brain[0] }

        # --- THE MIGRATION (Economics -> Settings) ---
        if ($null -eq $brain.Settings) {
            if ($null -ne $brain.Economics) {
                $brain | Add-Member -NotePropertyName "Settings" -NoteValue ([PSCustomObject]$brain.Economics) -Force
            } else {
                $brain | Add-Member -NotePropertyName "Settings" -NoteValue ([PSCustomObject]@{ElecRate=0.22; HardwareCost=463.00; TargetTH=10.9}) -Force
            }
        }
        $brain.Settings = [PSCustomObject]$brain.Settings

        if ($null -ne $brain.Records) {
            $brain.Records = [PSCustomObject]$brain.Records
        } else {
            $brain | Add-Member -NotePropertyName "Records" -NoteValue ([PSCustomObject]@{AllTimeBestShare=0})
        }
        
        if ($null -eq $brain.Records.SessionBestShare) {
            $brain.Records | Add-Member -MemberType NoteProperty -Name "SessionBestShare" -Value 0 -Force
        }
        $brain.Records.SessionBestShare = 0

        # --- THE 100-POINT SYNC FIX (STRICT WIDESCREEN ENFORCEMENT) ---
        if ($null -eq $brain.GraphHistory) { 
            $brain | Add-Member -NotePropertyName "GraphHistory" -NoteValue (@(0.0)*100) 
        }
        
        # Ensure exactly 100 points: Trim if too long, Pad with 0.0 if too short
        $currentHistory = @($brain.GraphHistory)
        if ($currentHistory.Count -gt 100) { 
            $brain.GraphHistory = @($currentHistory | Select-Object -Last 100) 
        } elseif ($currentHistory.Count -lt 100) {
            $paddingCount = 100 - $currentHistory.Count
            $brain.GraphHistory = (@(0.0) * $paddingCount) + $currentHistory
        }

        # Save healed version 
        $brain | ConvertTo-Json -Depth 5 | Out-File $configPath -Encoding UTF8 -Force

    } catch { $createNew = $true; $isFirstRun = $true }
} else { 
    $createNew  = $true 
    $isFirstRun = $true 
}

if ($createNew) {
    $brain = [PSCustomObject]@{
        # Initialized with your current 10.9 TH/s milestone as default target
        Settings = [PSCustomObject]@{ ElecRate = 0.22; HardwareCost = 463.00; TargetTH = 10.9 }
        Records  = [PSCustomObject]@{ AllTimeBestShare = 0; SessionBestShare = 0; FirstLaunchDate = (Get-Date -Format "yyyy-MM-dd") }
        # Initialize with 100 empty points for 100-width widescreen graph
        GraphHistory = @(0.0)*100 
        MinerManifest = @()
    }
}

#================================================================================
# ----- 1.0 DISCOVERY ------------------------------------------------------------
#================================================================================

function Get-SwarmDiscovery {
    Clear-Host
    Write-Host "`n[ HUNTING FOR MINERS (Windows Optimized) ]" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

    # Improved Local IP Detection for Windows
    $localIP = $null
    try {
        $bestRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Select-Object -First 1
        $localIP = (Get-NetIPAddress -InterfaceIndex $bestRoute.InterfaceIndex -AddressFamily IPv4).IPAddress
    } catch {
        $localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127\.' -and $_.IPAddress -notmatch '^169\.' } | Select-Object -First 1).IPAddress
    }

    if ($null -ne $localIP -and $localIP.Contains('.')) {
        $networkBase = $localIP.Substring(0, $localIP.LastIndexOf('.'))
        Write-Host " [+] Local IP Detected: $localIP" -ForegroundColor Gray
        Write-Host " [+] Target Subnet: $networkBase.0/24" -ForegroundColor Gray
    }
    else {
        $networkBase = '192.168.1'
        Write-Host " [!] Network unreachable. Using fallback subnet: $networkBase.0/24" -ForegroundColor Red
    }

    $foundList = New-Object System.Collections.Generic.List[PSCustomObject]
    $icmp      = New-Object System.Net.NetworkInformation.Ping

    1..254 | ForEach-Object {
        $ip = "$networkBase.$_"
        Write-Progress -Activity "Swarm Discovery" -Status "Probing $ip" -PercentComplete (($_/254)*100)

        $reply = $icmp.Send($ip, 150)
        if ($reply.Status -eq 'Success') {
            try {
                $d = Invoke-RestMethod -Uri "http://$ip/api/system/info" -TimeoutSec 1 -ErrorAction SilentlyContinue
                if ($null -ne $d) {
                    
                    # STRICT-SAFE PROPERTY CHECK FOR HASHRATE
                    $rawH = 0.0
                    if ($d.psobject.Properties['hashRate']) { $rawH = [double]$d.hashRate }
                    elseif ($d.psobject.Properties['hashrate']) { $rawH = [double]$d.hashrate }

                    if ($rawH -gt 0) {
                        $cleanName = if ($d.psobject.Properties['hostname']) { $d.hostname -replace '^Found-', '' } else { "Bitaxe-$ip" }
                        $thActual  = [math]::Round($rawH/1000, 2)
                        
                        # Assign Target based on hardware capability
                        $target = if ($thActual -gt 5) { 5.8 }
                                     elseif ($thActual -gt 2) { 2.5 }
                                     else { 1.3 }

                        Write-Host " [+] Found: $cleanName at $ip ($thActual TH/s)" -ForegroundColor Green

                        $foundList.Add([PSCustomObject]@{
                            IP=$ip; Name=$cleanName; Target=$target; Type='BTC'
                        }) | Out-Null
                    }
                }
            } catch {}
        }
    }

    Write-Progress -Activity "Swarm Discovery" -Completed
    Write-Host "`n [ HUNT COMPLETE ] Found $($foundList.Count) miners." -ForegroundColor Yellow
    return $foundList
}

# ============================================================================
# ---- 1.1 ASSET BUILDER & COMMIT LOGIC (NEW REUSABLE FUNCTION) --------------
# ============================================================================
function Update-SwarmInventory {
    param($discoveredNodes)

    foreach ($m in $discoveredNodes) {
        # Check if IP is already in our saved manifest
        $existing = $brain.MinerManifest | Where-Object { $_.IP -eq $m.IP }
        
        if (-not $existing) {
            Write-Host "`n [NEW ASSET DISCOVERED] $($m.Name) @ $($m.IP)" -ForegroundColor Green
            Write-Host " >> Enter purchase price (£/$) for ROI tracking: " -NoNewline -ForegroundColor White
            $entry = Read-Host
            $cleanEntry = $entry -replace '[^0-9.]', ''
            if (!($cleanEntry -as [double])) { $cleanEntry = 0.0 }
            
            # Attach the cost to the miner object (Preserving your Section 2.0 logic)
            $m | Add-Member -NotePropertyName "PurchaseCost" -NotePropertyValue ([double]$cleanEntry) -Force
            $m | Add-Member -NotePropertyName "DateAdded" -NotePropertyValue (Get-Date -Format "dd/MM/yyyy") -Force

            # Commit to the Brain and save to disk
            $brain.MinerManifest += $m
            $global:miners = $brain.MinerManifest 
            
            # Sync the Global Settings Total Cost
            $brain.Settings.HardwareCost = ($brain.MinerManifest.PurchaseCost | Measure-Object -Sum).Sum
            
            # Robust Save
            $brain | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
            Write-Host " [+] $($m.Name) permanently added to swarm_config.json" -ForegroundColor Green
        }
    }
}

# ============================================================================
# ---- 2.0 FIRST-RUN SETUP / BRAIN (UK LEDGER EDITION) -----------------------
# ============================================================================
if (-not (Test-Path -LiteralPath $configPath)) {
    Clear-Host
    Write-Host " [ SWARM INTELLIGENCE: INITIAL CALIBRATION ]" -ForegroundColor Yellow

    # 1. Global Settings
    $userElec = Read-Host " >> Electricity Rate per kWh (Andover Avg: 0.28)"
    $fElec = if ($userElec -as [double]) { [double]$userElec } else { 0.28 }

    # 2. Build Skeleton Brain (Matches your existing structure)
    $brain = [PSCustomObject]@{
        Settings = [PSCustomObject]@{ ElecRate = $fElec; HardwareCost = 0.0; TargetTH = 10.9 }
        Records  = [PSCustomObject]@{ 
            AllTimeBestShare = 0; SessionBestShare = 0; 
            FirstLaunchDate = (Get-Date).ToString('dd/MM/yyyy');
            PeakLuck24h = 0.0; PeakLuckTimestamp = (Get-Date).AddDays(-1).ToString('dd/MM/yyyy HH:mm:ss')
        }
        MinerManifest = @()
        GraphHistory  = @(0.0)*100
    }

    # 3. Trigger Discovery & Asset Builder
    $discovered = Get-SwarmDiscovery
    Update-SwarmInventory -discoveredNodes $discovered
    
    Write-Host "`n [!] FIRST-RUN CALIBRATION COMPLETE." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
}

# ============================================================================================
# 3.0 BRAIN LOAD & VARIABLE SYNC (UI & LEDGER ALIGNED)
# ============================================================================================
if (Test-Path $configPath) {
    $brain = Get-Content $configPath -Encoding UTF8 | ConvertFrom-Json
} else {
    Write-Host " [!] No config found. Run script again to trigger Calibration." -ForegroundColor Red
    exit
}

# --- AUTO-CYCLE & UI CONSTANTS ---
$autoCycle     = $true
$cycleInterval = 6
$cycleCounter  = 0
$fullWidth     = 100
$sepLine       = "=" * $fullWidth
$sep           = "-" * $fullWidth
$gbp           = [char]163  # Prevents encoding shifts for £
$currentPage   = 1    
$minersPerPage = 5    

# --- INITIALIZE UI ANCHORS (Fixes Initial Disappearance & Red Errors) ---
$global:refreshTimer = 0
$netHealth           = "INITIALIZING..."
$pingResults         = [System.Collections.Generic.List[string]]::new()
$pingResults.Add("WAIT")

# 2. FORCE PROPERTIES & CAPEX ENGINE
if (-not $brain.psobject.Properties['GraphHistory'])  { $brain | Add-Member -NotePropertyName GraphHistory  -NotePropertyValue (@(0.0)*50) -Force }
if (-not $brain.psobject.Properties['MinerManifest']) { $brain | Add-Member -NotePropertyName MinerManifest -NotePropertyValue @()         -Force }

$calculatedHwCost = 0.0
foreach ($m in $brain.MinerManifest) {
    $cost = if ($m.psobject.Properties['PurchaseCost']) { $m.PurchaseCost } else { $m.HardwareCost }
    if ($cost) { $calculatedHwCost += [double]$cost }
}

# --- VARIABLE SYNC ---
$miners      = @($brain.MinerManifest)
$elecRate    = $brain.Settings.ElecRate
$allTimeBest = $brain.Records.AllTimeBestShare
$targetHash  = if ($miners.Count -gt 0) { ($miners | Measure-Object -Property Target -Sum).Sum } else { 1.0 }
$hwCapEx     = if ($calculatedHwCost -gt 0) { $calculatedHwCost } else { $brain.Settings.HardwareCost }

# --- SYNC HISTORY (Strict 100-point cap) ---
$hashHistory = @([double[]]$brain.GraphHistory)
if ($hashHistory.Count -gt 100) { 
    $hashHistory = @($hashHistory | Select-Object -Last 100) 
} elseif ($hashHistory.Count -lt 100) {
    $hashHistory = (@(0.0) * (100 - $hashHistory.Count)) + $hashHistory
}

# --- PRE-FLIGHT CHECKS ---
$currentLoc = "[ PENDING... ]"

try {
    # Detect Location
    $geo = Invoke-RestMethod -Uri "http://ip-api.com/json/" -TimeoutSec 3 -ErrorAction SilentlyContinue
    if ($geo.status -eq "success") { $currentLoc = "$($geo.city), $($geo.countryCode)" }

    # Initial Network Probe for Startup UI
    $netProbe = Test-Connection -TargetName "solo.solohash.co.uk" -Count 1 -ErrorAction SilentlyContinue
    if ($netProbe) {
        $ms = $netProbe | Select-Object -First 1 -ExpandProperty Latency
        $netHealth = "PING: ${ms}ms (STARTUP)"
    }
} catch {
    $netHealth = "PING: OFFLINE"
}

# --- LOOP CONTROLS ---
$loopCount               = 0
$internetRefreshInterval = 30
$cacheFailCount          = 0
$dataSource              = "[ STARTING ]"

# Proceed to Section 4: MAIN LOOP...

# ============================================================================================
# 4.0 MAIN LOOP (ANTI-FLICKER VERSION)
# ============================================================================================

while ($true) {

    # --- THE SELECTIVE OVERWRITE (WIINDOWS OPTIMIZED) ---
    # We no longer wipe the screen [2J or [0J. We simply move the cursor to 0,0.
    # This prevents the "black flash" while still updating your 10.9 TH/s stats.
    [Console]::SetCursorPosition(0,0)
    
    # Hide cursor to prevent the blinking 'ghost' cursor during updates
    Write-Host "$([char]27)[?25l" -NoNewline

    $uptime = New-TimeSpan -Start $sessionStart -End (Get-Date)
    $upStr  = "{0:00}d {1:00}h {2:00}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes

    if ($loopCount % $internetRefreshInterval -eq 0) {
        try {
            $btcTicker   = Invoke-RestMethod -Uri "https://blockchain.info/ticker" -TimeoutSec 5 -ErrorAction Stop
            $btcPrice    = [double]$btcTicker.GBP.last
            $bchData     = Invoke-RestMethod -Uri "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin-cash&vs_currencies=gbp" -TimeoutSec 5 -ErrorAction Stop
            $bchPrice    = [double]$bchData.'bitcoin-cash'.gbp
            $netDiffRaw  = Invoke-RestMethod -Uri "https://blockchain.info/q/getdifficulty" -TimeoutSec 5 -ErrorAction Stop
            $dataSource  = "[ LIVE ]"
        } catch {
            $dataSource  = "[ CACHE ]"
            $cacheFailCount++
            if (!$btcPrice)   { $btcPrice  = 68000 }
            if (!$bchPrice)   { $bchPrice  = 450 }
            if (!$netDiffRaw) { $netDiffRaw = 146e12 }
        }
    }

# ... [Keep Sections 4.1 through 11.2 exactly as they are in your file] ...

#====================================================================
# --- 4.1 MINER POLLING (AxeOS & PORT-AWARE) ------------------------
#====================================================================
    # SimulationMode is now globally controlled in Section 3.0
    $minerData = @()
    $totalH    = 0.0
    $totalW    = 0.0
    $totalAmps = 0.0
    $totalSharesSubmitted = 0

    foreach ($m in $miners) {
        $targetIP = if ($m.IP -is [string]) { $m.IP } else { $m.IP.ToString() }
        
        # --- REAL MINER: PROCEED WITH NETWORK POLLING ---
        $uri = "http://$targetIP/api/system/info"
        try {
            # Silence miner API errors to prevent UI overlap
            $d = Invoke-RestMethod -Uri $uri -TimeoutSec 2 -ErrorAction Stop -Headers @{"Accept"="application/json"}
            
            if ($null -ne $d) {
                # 1. Extraction of AxeOS session data
                $rawH = 0.0
                if ($d.psobject.Properties['hashRate']) { $rawH = [double]$d.hashRate }
                elseif ($d.psobject.Properties['hashrate']) { $rawH = [double]$d.hashrate }

                $pVal = if ($d.psobject.Properties['power']) { [math]::Round([double]$d.power, 1) } else { 0.0 }
                $aVal = if ($d.psobject.Properties['currentA']) { [double]$d.currentA } else { 0.0 }
                $vVal = if ($d.psobject.Properties['voltage']) { [math]::Round([double]$d.voltage/1000, 1) } else { 5.0 }
                
                # 2. THE AxeOS COIN DETECTOR
                $sUrl  = if ($d.psobject.Properties['stratumURL']) { $d.stratumURL } else { "" }
                $sUser = if ($d.psobject.Properties['stratumUser']) { $d.stratumUser } else { "" }
                $sPort = if ($d.psobject.Properties['stratumPort']) { $d.stratumPort } else { 0 }
                
                $idString = "$sUrl $sUser".ToLower()
                $detectedType = "BTC" 
                
                if ($sPort -eq 3337 -or $idString -match "bch|bitcoin-cash|bitcoincash" -or $sUrl -like "*bch*") {
                    $detectedType = "BCH"
                }

                # 3. Unit Normalization (TH/s)
                $hVal = if ($rawH -gt 500) { [math]::Round($rawH/1000, 2) } else { [math]::Round($rawH, 2) }

                # 4. Best Difficulty
                $bestVal = if ($d.psobject.Properties['bestDiff']) { [double]$d.bestDiff } else { 0.0 }
                if ($d.psobject.Properties['stratum'] -and $d.stratum.totalBestDiff -gt $bestVal) {
                    $bestVal = [double]$d.stratum.totalBestDiff
                }

                $mObj = [PSCustomObject]@{
                    Name       = $m.Name
                    IP         = $targetIP
                    Hash       = $hVal
                    Power      = $pVal
                    Temp       = if ($d.psobject.Properties['temp'])  { [double]$d.temp }   else { 0 }
                    VRM        = if ($d.psobject.Properties['vrTemp']) { $d.vrTemp } else { 0 }
                    Up         = if ($d.psobject.Properties['uptimeSeconds']) { [math]::Round($d.uptimeSeconds/3600,1) } else { 0 }
                    Best       = $bestVal
                    Session    = if ($d.psobject.Properties['bestSessionDiff']) { $d.bestSessionDiff } else { 0 }
                    Pool       = if ($sUrl) { ($sUrl -replace 'stratum\+tcp://','').ToUpper() } else { "OFFLINE" }
                    WiFi       = if ($d.psobject.Properties['wifiRSSI']) { $d.wifiRSSI } else { 0 }
                    Voltage    = $vVal
                    Efficiency = if ($hVal -gt 0) { [math]::Round($pVal/$hVal,1) } else { 0 }
                    Type       = $detectedType
                    Health     = if ($m.psobject.Properties['Target'] -and $m.Target -gt 0) { [math]::Min(100,[math]::Round(($hVal/$m.Target)*100,0)) } else { 100 }
                    Shares     = if ($d.psobject.Properties['sharesAccepted']) { [long]$d.sharesAccepted } else { 0 }
                }

                $minerData += $mObj
                $totalH    += $hVal
                $totalW    += $pVal
                $totalAmps += if ($aVal -gt 0) { $aVal } elseif ($vVal -gt 0.1) { ($pVal / $vVal) } else { 0 }
                $totalSharesSubmitted += $mObj.Shares
            }
        } catch {
            $TimeStamp = Get-Date -Format "HH:mm:ss"
            # Silently log network fails to the file so they don't corrupt the UI
            "[!] $TimeStamp FAIL: $($m.Name) ($targetIP) - $($_.Exception.Message)" | Out-File -FilePath $LogFile -Append
        }
    }

    # ###########################################################################
    # ### START: HIERARCHY SORT (REAL FIRST, THEN HIGHEST HASH) #################
    # ###########################################################################
    if ($minerData.Count -gt 0) {
        $minerData = $minerData | Sort-Object `
            @{Expression={$_.Name -like "Mock*"}; Ascending=$true}, `
            @{Expression={$_.Hash}; Descending=$true}
    }
    # ###########################################################################
    # ### END: HIERARCHY SORT ###################################################
    # ###########################################################################

#===========================================================================
# --- 4.2 SHARES & PEAK CALCULATION (DYNAMIC COIN AWARE) -------------------
#===========================================================================

    # Ensure price variables exist (Market Approx)
    if ($null -eq $btcPrice) { $btcPrice = 95000 } 
    if ($null -eq $bchPrice) { $bchPrice = 400 }   
    
    # Current Block Rewards (Post-Halving)
    $btcBlockVal = 3.125 * $btcPrice
    $bchBlockVal = 3.125 * $bchPrice

    $totalSharesCount = 0
    $swarmPeakRaw     = 0.0
    $peakCoinType     = "BTC" # Default tracking

if (-not $brain.Records.SessionBestShare) { $brain.Records.SessionBestShare = 0 }
    foreach ($m in $minerData) {
        # 1. Capture Highest Share in current loop
        $currB = if ($m.psobject.Properties['Best']) { [double]$m.Best } else { 0.0 }
        
        if ($currB -gt $swarmPeakRaw) { 
            $swarmPeakRaw = $currB 
            $peakCoinType = $m.Type # Track which coin found the peak
        }

        if ($currB -gt [double]$brain.Records.SessionBestShare) { $brain.Records.SessionBestShare = $currB }
# 2. Update Global Record if this share beats All-Time Best
        if ($currB -gt $allTimeBest) { 
            $allTimeBest = $currB 
        }

        # 3. Sum total shares across swarm
        $s = if ($m.psobject.Properties['Shares']) { [long]$m.Shares } else { 0 }
        $totalSharesCount += $s
    }

#==========================================================
# --- 4.3 UI VARIABLE INITIALIZATION ----------------------
#==========================================================
$displayShares = $totalSharesCount

# --- NEW: CALCULATE MIXED-MODE SPLIT BEFORE UI RENDERS ---
$bchMiners = $minerData | Where-Object { $_.Type -eq 'BCH' }
$bchH = 0.0
if ($null -ne $bchMiners) {
    $measureBCH = $bchMiners | Measure-Object -Property Hash -Sum
    if ($null -ne $measureBCH.Sum) { $bchH = [double]$measureBCH.Sum }
}
$btcH = [double]$totalH - $bchH

# ===========================================================================
# --- 4.4 HEADER/UI FUNCTION (STRICT WIDESCREEN ALIGNMENT) ------------------
# ===========================================================================
function Redraw-SwarmHeader {
    # 1. THE WIPER BLADE
    try { 
        [Console]::SetCursorPosition(0,0) 
    } catch {}

    $upStr      = "{0:00}d {1:00}h {2:00}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    $fullWidth  = 100
    $sepLine    = "=" * $fullWidth

    # 1. TOP BORDER
    Write-Host "$([char]27)[2K$sepLine" -ForegroundColor Cyan

    # 2. TITLE LINE
    $line1 = " BLSIC: BITCOIN LOTTERY SWARM INTELLIGENCE CONSOLE (Windows 11 Edition)  UPTIME: {0}" -f $upStr
    Write-Host ("$([char]27)[2K" + $line1.Trim().PadRight($fullWidth)) -ForegroundColor Magenta

    # 3. SECOND BORDER
    Write-Host "$([char]27)[2K$sepLine" -ForegroundColor Cyan

    # --- ANCHORED NETWORK & POOL HEALTH HUD ---
    $displayHealth = if (![string]::IsNullOrWhiteSpace($global:netHealth)) { $global:netHealth } else { "INITIALIZING..." }
    $leftZone      = " [ NETWORK/POOL ]: $displayHealth ".PadRight(70)

    # FORCE SYNC: Pull the latest tick from global scope
    $currentTick   = if ($global:refreshTimer -gt 0) { $global:refreshTimer } else { 10 }
    $timerStr      = " [ REFRESH ]: {0:00}s " -f $currentTick
    $rightZone     = $timerStr.PadLeft(30)

    # Render the Unified HUD Row
    Write-Host "$([char]27)[2K$($leftZone + $rightZone)" -ForegroundColor DarkCyan
    Write-Host "$([char]27)[2K$sepLine" -ForegroundColor Cyan

    # 4. B-STATUS & HYBRID PATHS (Preserving your 10.9 TH/s Green/Yellow Logic)
    $hashColor = if ($totalH -ge 10.0) { 'Green' } else { 'Yellow' }

    Write-Host "$([char]27)[2K /X\ [ B STATUS ] " -NoNewline -ForegroundColor Cyan
    Write-Host "TOTAL: " -NoNewline -ForegroundColor Gray
    Write-Host ("{0:N2}TH " -f $totalH).PadRight(8) -NoNewline -ForegroundColor $hashColor

    if ($bchH -gt 0 -and $btcH -gt 0) {
        $splitStr = "({0:N1} BCH/{1:N1} BTC) " -f $bchH, $btcH
        Write-Host $splitStr -NoNewline -ForegroundColor Gray
    }
    Write-Host "  POOLS: CKPOOL (BTC) + SOLOHASH (BCH)".PadRight(35) -ForegroundColor White

    # Row B: Paths - FIX: Added null-checks to prevent PropertyNotFoundException
    $btcMiner = $minerData | Where-Object { $_.Type -eq 'BTC' } | Select-Object -First 1
    $btcPath  = if ($null -ne $btcMiner -and $btcMiner.Pool) { $btcMiner.Pool } else { "solo.ckpool.org" }

    $bchMiner = $minerData | Where-Object { $_.Type -eq 'BCH' } | Select-Object -First 1
    $bchPath  = if ($null -ne $bchMiner -and $bchMiner.Pool) { $bchMiner.Pool } else { "solo.solohash.co.uk" }

    Write-Host "$([char]27)[2K [ PATH ] " -NoNewline -ForegroundColor Yellow
    Write-Host "BTC: $($btcPath.ToLower())".PadRight(35) -NoNewline -ForegroundColor Cyan
    Write-Host "BCH: $($bchPath.ToLower())".PadRight(35) -ForegroundColor Green
    Write-Host "$([char]27)[2K$sepLine" -ForegroundColor Cyan
}

# INITIAL TRIGGER: Draw it once before the loop starts
Redraw-SwarmHeader


# ===========================================================================
# --- 4.5 POOL HEALTH (LOGIC ONLY - NO RENDER) ------------------------------
# ===========================================================================
$activePools = @($minerData | 
    ForEach-Object { $_.Pool } | 
    Where-Object { $_ -and $_ -ne 'Solo' -and $_ -ne 'offline' } | 
    Sort-Object -Unique)

# Globalize poolString to prevent crashes in other sections
$global:poolString = if ($activePools.Count -gt 0) { ($activePools[0] -replace '^.+?:\/\/','') } else { 'SOLO/INTERNAL' }

$footerPings = [System.Collections.Generic.List[string]]::new() 

if ($activePools.Count -gt 0) {
    foreach ($pTarget in $activePools) {
        $pHost = ($pTarget -replace '^.+?:\/\/','' -split ':')[0]
        $short = if ($pHost -match 'ckpool') { 'CK' } elseif ($pHost -match 'solohash') { 'SH' } else { 'POOL' }
        $ok = $false
        $latency = 0
        try {
            $pingObj = Test-Connection -ComputerName $pHost -Count 1 -ErrorAction SilentlyContinue -TimeoutSeconds 1
            if ($pingObj) { 
                $ok = $true 
                $latency = $pingObj.Latency
            }
        } catch { $ok = $false }
        
        if ($ok) { 
            $footerPings.Add("${latency}ms ($short): OK")
        } else { 
            $footerPings.Add("TIMEOUT ($short)")
        }
    }
    # Store in Global for Section 4.4 HUD visibility
    $global:netHealth = $footerPings -join " | "
} else {
    $global:netHealth = "OFFLINE"
}

# Final data prep for Section 5.0 grid
$safePath = if ($global:poolString.Length -gt 42) { $global:poolString.Substring(0,39) + '...' } else { $global:poolString.PadRight(42) }

# ===========================================================================
# --- 5.0 GRID (PAGED & UNIVERSAL) -----------------------------------------
# ===========================================================================

# 1. PAGING CALCULATION
$totalMiners = $miners.Count
$maxPages = [Math]::Max(1, [Math]::Ceiling($totalMiners / $minersPerPage))
if ($currentPage -gt $maxPages) { $currentPage = $maxPages }
$displayList = $miners | Select-Object -Skip (($currentPage - 1) * $minersPerPage) -First $minersPerPage

# 2. UI HEADER (Recalibrated Tight Blueprint)
Write-Host " [ HARDWARE STATUS ]" -NoNewline -ForegroundColor Cyan
Write-Host " (Page $currentPage of $maxPages) " -ForegroundColor White

# TIGHTENED TEMPLATE: Reduced HASH from 9 to 8, EFF from 10 to 9, TEMP from 11 to 10.
$gridTemplate = " {0,-18} {1,-5} {2,-5} {3,-8} {4,-9} {5,-10} {6,-7} {7,-12} {8,-7} {9}"
$headerLine = $gridTemplate -f "ID", "TYPE", "STAB", "HASH", "EFF(J/T)", "CORE/VRM", "PWR", "VOLTS/AMPS", "UP", "WiFi"

Write-Host $headerLine -ForegroundColor Gray
Write-Host (" " + "-" * ($headerLine.Length)) -ForegroundColor DarkGray

# 3. RENDER LOOP
foreach ($m in $displayList) {
    $out = $null 
    $out = $minerData | Where-Object { $_.IP -eq $m.IP -or $_.Name -eq $m.Name } | Select-Object -First 1
    
    # ID Column: Locked to 18
    $c1 = ("[{0}]" -f $m.Name).PadRight(18).Substring(0,18)

    if ($null -ne $out) {
        $hVal  = $out.Health; $haVal = $out.Hash; $eVal = $out.Efficiency; $pVal = $out.Power
        $vVal  = $out.Voltage; $uVal = $out.Up; $wVal = $out.WiFi; $cType = $out.Type 
        $realAmps = if ($vVal -gt 0.5) { [math]::Round($pVal/$vVal,2) } else { 0 }

        # --- DATA PREP (Tightened to match template) ---
        $c_Type = "$cType"
        $c_Stab = "{0,3}%" -f $hVal
        $c_Hash = "{0,5}T" -f $haVal   # Squeezed from 6 to 5
        $c_Eff  = "{0,5}J/T" -f $eVal # Squeezed from 6 to 5
        $c_Temp = "{0,3}C/{1,3}C" -f [int]$out.Temp, [int]$out.VRM
        $c_Pwr  = "{0,4}W" -f $pVal
        $c_VA   = "{0,4}V/{1,5}A" -f $vVal.ToString('N1'), $realAmps.ToString('N2')
        $c_Up   = "{0,6}h" -f $uVal
        $c_WiFi = "{0,4}dBm" -f $wVal

        # --- THE RENDER (Strict Coordinate Lock) ---
        Write-Host " $c1" -NoNewline -ForegroundColor White
        
        $typeColor = if ($cType -eq 'BCH') { 'Green' } else { 'Yellow' }
        Write-Host (" " + $c_Type.PadRight(5)) -NoNewline -ForegroundColor $typeColor
        
        $stabColor = if ($hVal -ge 95) {'Green'} elseif ($hVal -ge 80) {'Yellow'} else {'Red'}
        Write-Host (" " + $c_Stab.PadRight(5)) -NoNewline -ForegroundColor $stabColor
        
        Write-Host (" " + $c_Hash.PadRight(8)) -NoNewline -ForegroundColor Green
        Write-Host (" " + $c_Eff.PadRight(9)) -NoNewline -ForegroundColor Cyan
        
        $tempColor = if ([int]$out.VRM -gt 80) { 'Red' } elseif ([int]$out.VRM -gt 70) { 'Yellow' } else { 'Gray' }
        Write-Host (" " + $c_Temp.PadRight(10)) -NoNewline -ForegroundColor $tempColor
        
        Write-Host (" " + $c_Pwr.PadRight(7)) -NoNewline -ForegroundColor Magenta
        Write-Host (" " + $c_VA.PadRight(12)) -NoNewline -ForegroundColor Gray
        Write-Host (" " + $c_Up.PadRight(7)) -NoNewline -ForegroundColor White
        
        $wCol = if ($wVal -gt -65) { 'Green' } elseif ($wVal -gt -80) { 'Yellow' } else { 'Red' }
        Write-Host (" " + $c_WiFi.PadRight(6)) -ForegroundColor $wCol

    } else {
        Write-Host " $c1" -NoNewline -ForegroundColor DarkGray
        Write-Host " [ STANDBY / OFFLINE ] ".PadRight(65,'.') -ForegroundColor Red
    }
}

#============================================================================
# ---- 6.0 SWARM HEALTH, LOAD & ECON (UNIFIED MATH) -------------------------
#============================================================================
    # 1. Fleet Health
    $expectedCount = $brain.MinerManifest.Count
    $onlineCount   = $minerData.Count
    $offlineCount  = $expectedCount - $onlineCount
    $healthColor   = if ($offlineCount -eq 0) { 'Green' } elseif ($onlineCount -gt 0) { 'Yellow' } else { 'Red' }

    # 2. Burn Rate & Efficiency + TOTAL AMPS Calculation
    $avgEff    = if ($totalH -gt 0) { [math]::Round($totalW / [double]$totalH, 1) } else { 0 }
    $dailyKwh  = ($totalW * 24) / 1000
    $dailyCost = $dailyKwh * $elecRate
    
    # Summing Amps from all active units for the Load row
    $totalAmps = 0
    foreach ($m in $minerData) {
        if ($m.Voltage -gt 0.5) { $totalAmps += ($m.Power / $m.Voltage) }
    }

    # 3. Ticket Value Engine
    $lottoOdds  = 45057474
    $lottoPrice = 2.00
    
    $probBTC = if ($btcH -gt 0 -and $global:calcBTC) { ($btcH * 1e12 * 86400) / ($global:calcBTC * [math]::Pow(2,32)) } else { 0 }
    $probBCH = if ($bchH -gt 0 -and $global:calcBCH) { ($bchH * 1e12 * 86400) / ($global:calcBCH * [math]::Pow(2,32)) } else { 0 }
    
    $tixBCH = if ($probBCH -gt 0) { $probBCH * $lottoOdds } else { 0 }
    $tixBTC = if ($probBTC -gt 0) { $probBTC * $lottoOdds } else { 0 }
    $dailyRetailVal = ($tixBCH + $tixBTC) * $lottoPrice

    # --- RENDER ROW 1: STATUS ---
    Write-Host $sep -ForegroundColor DarkGray
    Write-Host " [ SWARM STATUS ] " -NoNewline -ForegroundColor Cyan
    Write-Host "FLEET: " -NoNewline -ForegroundColor Gray
    Write-Host "$onlineCount/$expectedCount Online " -NoNewline -ForegroundColor $healthColor
    Write-Host "| TOTAL HASH: " -NoNewline -ForegroundColor Gray
    Write-Host ("{0:N2} TH/s " -f $totalH) -NoNewline -ForegroundColor Yellow
    
    if ($bchH -gt 0 -and $btcH -gt 0) {
        Write-Host "(" -NoNewline -ForegroundColor Gray
        Write-Host "$([math]::Round($bchH,1)) BCH / $([math]::Round($btcH,1)) BTC" -NoNewline -ForegroundColor Gray
        Write-Host ")" -ForegroundColor Gray
    } else { Write-Host "" }

    # --- RENDER ROW 2: LOAD (With Total Amps) ---
    Write-Host " [ SWARM LOAD   ] " -NoNewline -ForegroundColor Cyan
    Write-Host "EFF: " -NoNewline -ForegroundColor Gray
    Write-Host ("{0:N1} J/T " -f $avgEff) -NoNewline -ForegroundColor Cyan
    Write-Host "| DRAW: " -NoNewline -ForegroundColor Gray
    Write-Host ("{0}W " -f [int]$totalW) -NoNewline -ForegroundColor Magenta
    Write-Host "| AMPS: " -NoNewline -ForegroundColor Gray
    Write-Host ("{0:N2}A " -f $totalAmps) -NoNewline -ForegroundColor White
    Write-Host "| ENERGY COST/DAY: " -NoNewline -ForegroundColor Gray
    Write-Host ("$gbp{0:N2}" -f $dailyCost) -ForegroundColor Yellow
    Write-Host $sep -ForegroundColor DarkGray

# ===========================================================================
# --- 7.0 LUCKY LADDER & SHARE CAPTURE -------------------------------------
# ===========================================================================
Write-Host "`n [ LUCKY LADDER & SHARE CAPTURE ]" -ForegroundColor Yellow

# Initialize for Section 8 use
$highestLadderRatio = 0.0

$ladderTemplate = " {0,-18} {1,-20} {2,-7} {3,-11} {4,-11} {5}"
$ladderHeader = $ladderTemplate -f "ID (LINK)","POOL","TYPE","BEST DIFF","CURR DIFF","LUCKY LADDER"
Write-Host $ladderHeader -ForegroundColor Gray
Write-Host (" " + "-" * ($ladderHeader.Length + 5)) -ForegroundColor DarkGray

$twoPow32 = [math]::Pow(2,32)
if (-not (Test-Path "variable:global:calcBTC")) { $global:calcBTC = 125e12 }
if (-not (Test-Path "variable:global:calcBCH")) { $global:calcBCH = 0.95e12 }

$sessionMaxVal = ($minerData | Measure-Object -Property Best -Maximum).Maximum

foreach ($m in $minerData) {
    $bestVal = if ($m.Best) { [double]$m.Best } else { 0.0 }
    $sessVal = if ($m.Session) { [double]$m.Session } else { 0.0 }
    
    # --- 1. ID ALIGNMENT ---
    $esc = [char]27
    $url = "http://$($m.IP)"
    $rawName = "[{0}]" -f $m.Name
    if ($rawName.Length -gt 18) { $rawName = $rawName.Substring(0,18) }
    $padSpace = " " * ([math]::Max(0, 18 - $rawName.Length))
    
    $isKing = ($bestVal -gt 0 -and $bestVal -eq $sessionMaxVal)
    $nameColor = if ($isKing) { 'Yellow' } else { 'White' }
    $idLink = "$esc]8;;$url$esc\$rawName$esc]8;;$esc\"

    # --- 2. DATA PREP ---
    $pClean = ($m.Pool -replace '^.+?:\/\/','').ToUpper()
    $c_pool = $pClean.PadRight(20).Substring(0,20)
    $c_type = "$($m.Type)".PadRight(7)
    $c_best = (Format-Diff $bestVal).PadRight(11)
    $c_curr = (Format-Diff $sessVal).PadRight(11)

    # --- 3. LADDER MATH & GLOBAL TRACKING ---
    $netDiff = if ($m.Type -eq 'BCH') { $global:calcBCH } else { $global:calcBTC }
    $shareToBlockRatio = ($bestVal / ($netDiff * $twoPow32))
    
    # Capture highest ratio for Section 8
    if ($shareToBlockRatio -gt $highestLadderRatio) { $highestLadderRatio = $shareToBlockRatio }

    $mLog = 0
    if ($shareToBlockRatio -gt 0) { 
        $calcLog = [math]::Log10($shareToBlockRatio * 1e16) 
        $mLog = [math]::Max(0, $calcLog)
    }
    $barLimit = 18
    $barCount = [math]::Min($barLimit, [math]::Round($mLog * 1.5))

    # --- 4. RENDER LINE ---
    Write-Host " " -NoNewline
    Write-Host $idLink -NoNewline -ForegroundColor $nameColor
    Write-Host $padSpace -NoNewline 
    Write-Host " $c_pool" -NoNewline -ForegroundColor DarkGray
    
    $tColor = if ($m.Type -eq 'BCH') { 'Green' } else { 'Yellow' }
    Write-Host " $c_type" -NoNewline -ForegroundColor $tColor
    Write-Host " $c_best" -NoNewline -ForegroundColor Cyan
    Write-Host " $c_curr" -NoNewline -ForegroundColor Gray

    Write-Host " [" -NoNewline -ForegroundColor DarkGray
    for ($i=1; $i -le $barLimit; $i++) {
        if ($i -le $barCount) {
            $bColor = if ($i -le 6) { 'Red' } elseif ($i -le 12) { 'Yellow' } else { 'Green' }
            Write-Host "#" -NoNewline -ForegroundColor $bColor
        } else {
            Write-Host "-" -NoNewline -ForegroundColor DarkGray
        }
    }
    Write-Host "]" -NoNewline -ForegroundColor DarkGray
    
    if ($isKing) { Write-Host " <KING>" -NoNewline -ForegroundColor Yellow }
    Write-Host ""
}
Write-Host (" " + "-" * 105) -ForegroundColor DarkGray


# ===========================================================================
# --- 8.0 LUCK / WINNING CHANCES & SWARM LUCK ------------------------------
# ===========================================================================
$bchMiners = $minerData | Where-Object { $_.Type -eq 'BCH' }
$bchH = 0.0
if ($null -ne $bchMiners) {
    $measureBCH = $bchMiners | Measure-Object -Property Hash -Sum
    if ($null -ne $measureBCH.Sum) { $bchH = [double]$measureBCH.Sum }
}
$btcH = [double]$totalH - $bchH

$probBTC = if ($btcH -gt 0) { ($btcH * 1e12 * 86400) / ($global:calcBTC * $twoPow32) } else { 0 }
$probBCH = if ($bchH -gt 0) { ($bchH * 1e12 * 86400) / ($global:calcBCH * $twoPow32) } else { 0 }

function Get-SmartTime($prob) {
    if ($prob -le 0) { return "---" }
    $days = 1 / $prob
    if ($days -lt 1) { return "$([math]::Round($days * 24, 1)) hrs" }
    if ($days -gt 365) { return "$([math]::Round($days / 365, 1)) yrs" }
    return "$([math]::Round($days, 1)) days"
}

$expBTC = Get-SmartTime $probBTC
$expBCH = Get-SmartTime $probBCH

# Final Swarm Luck Bar Calculation
$sLog = 0
if ($highestLadderRatio -gt 0) { 
    $sCalc = [math]::Log10($highestLadderRatio * 1e16)
    if ($sCalc -gt 0) { $sLog = $sCalc }
}
$barProgress = [math]::Min(20, [math]::Round($sLog * 1.2))
$swarmBar = ("#" * $barProgress).PadRight(20, ".")

$luckStatus = "GRINDING"
$luckColor = "Cyan"
if ($highestLadderRatio -ge 0.1)       { $luckStatus = "GODLIKE"; $luckColor = "Magenta" } 
elseif ($highestLadderRatio -ge 0.01)  { $luckStatus = "INSANE";  $luckColor = "Red" }  
elseif ($highestLadderRatio -ge 0.001) { $luckStatus = "BLESSED"; $luckColor = "Yellow" } 
elseif ($highestLadderRatio -ge 0.0001){ $luckStatus = "SOLID";   $luckColor = "Green" }

# --- RENDER CHANCES ---
Write-Host " [ LIVE CHANCES ] DAILY: " -NoNewline -ForegroundColor Yellow
Write-Host "BTC " -NoNewline -ForegroundColor Gray
Write-Host ("{0:P6}" -f $probBTC) -NoNewline -ForegroundColor Yellow
Write-Host " | " -NoNewline -ForegroundColor Gray
Write-Host "BCH " -NoNewline -ForegroundColor Gray
Write-Host ("{0:P4}" -f $probBCH) -ForegroundColor Green

# --- RENDER EXPECTATION ---
Write-Host " >> EXPECTATION: 1 Block every " -NoNewline -ForegroundColor Gray
if ($btcH -gt 0 -and $bchH -gt 0) {
    Write-Host "$expBTC " -NoNewline -ForegroundColor Yellow
    Write-Host "(BTC) / " -NoNewline -ForegroundColor Gray
    Write-Host "$expBCH " -NoNewline -ForegroundColor Green
    Write-Host "(BCH)" -ForegroundColor DarkGreen
} elseif ($btcH -gt 0) {
    Write-Host "$expBTC " -NoNewline -ForegroundColor Yellow
    Write-Host "(BTC)" -ForegroundColor DarkYellow
} else {
    Write-Host "$expBCH " -NoNewline -ForegroundColor Green
    Write-Host "(BCH)" -ForegroundColor DarkGreen
}

Write-Host " [ SWARM LUCK ]    [$swarmBar] STATUS: [$luckStatus]" -ForegroundColor $luckColor
Write-Host ("-" * 105) -ForegroundColor DarkGray

# ===========================================================================
# --- 9.0 PERFORMANCE TREND (HIGH-GRANULARITY WIDESCREEN) -------------------
# ===========================================================================
# 1. Update History & Average
$hashHistory = $hashHistory[1..99] + $totalH
$avgHash = ($hashHistory | Where-Object { $_ -gt 0 } | Measure-Object -Average).Average
if ($null -eq $avgHash) { $avgHash = $totalH }

# 2. Performance Scaling Logic
$graphHeight = 5 
$validHistory = $hashHistory | Where-Object { $_ -gt 0 }
$minH = if ($validHistory) { ($validHistory | Measure-Object -Minimum).Minimum * 0.99 } else { $totalH * 0.99 }
$maxH = if ($validHistory) { ($validHistory | Measure-Object -Maximum).Maximum * 1.01 } else { $totalH * 1.01 }
if ($maxH -le $minH) { $maxH = $minH + 0.1 }
$rangeSize = $maxH - $minH

Write-Host " [ SWARM PERFORMANCE TREND ($([math]::Round($minH,1)) - $([math]::Round($maxH,1)) TH/s) ]" -ForegroundColor Yellow
Write-Host " AVG (Last 100): $([math]::Round($avgHash,2)) TH/s" -ForegroundColor Gray

# 3. Render Loop (Thin-Line Logic)
# Changed block to a thinner character for high-density look
$thinBlock = "|" 
for ($h=$graphHeight; $h -gt 0; $h--) {
    Write-Host " " -NoNewline
    foreach ($val in $hashHistory) {
        $level = if ($rangeSize -gt 0) { (($val-$minH)/$rangeSize)*$graphHeight } else { 0 }
        if ($level -ge ($h-0.5)) {
            $color = if ($val -ge ($targetHash * 0.98)) {'Green'}
                     elseif ($val -ge ($targetHash * 0.90)) {'Yellow'}
                     else {'Red'}
            Write-Host $thinBlock -NoNewline -ForegroundColor $color
        } else { Write-Host " " -NoNewline }
    }
    if ($h -eq $graphHeight) { Write-Host " HI" -ForegroundColor DarkGray }
    elseif ($h -eq 1) { Write-Host " LO" -ForegroundColor DarkGray }
    else { Write-Host "" }
}

Write-Host " +$("-" * 100)+" -ForegroundColor DarkGray
$midHaxis = [math]::Round(($minH + $maxH)/2, 1)
Write-Host ("  {0,-33} {1,-33} {2,32} TH" -f "$([math]::Round($minH,1))T", "$([math]::Round($midHaxis,1))T", "$([math]::Round($maxH,1))T") -ForegroundColor Gray
Write-Host $sep -ForegroundColor DarkGray


# ===========================================================================
# --- 10.0 & 10.1 SWARM LOTTERY TICKET OFFICE (SIDE-BY-SIDE) ---------------
# ===========================================================================
    # --- LIVE NETWORK DATA REFRESH ---
    $targetLottoOdds = 45057474
    $ticketPriceGBP  = 2.00
    
    # Probability math using LIVE $global variables (Pulled from Internet)
    $tixBCH = if ($probBCH -gt 0) { $probBCH * $targetLottoOdds } else { 0 }
    $tixBTC = if ($probBTC -gt 0) { $probBTC * $targetLottoOdds } else { 0 }
    $virtualTicketsDay   = $tixBCH + $tixBTC
    $virtualTicketsMonth = $virtualTicketsDay * 30.44
    $dailyRetailVal      = $virtualTicketsDay * $ticketPriceGBP
    
    # Live Frequency & Network Barrier
    $secondsInDay = 86400
    $tixPerSecond = $virtualTicketsDay / $secondsInDay
    $timeToTicket = if ($tixPerSecond -gt 0) { 1 / $tixPerSecond } else { 0 }
    $timeStr      = if ($timeToTicket -ge 60) { "{0:N1}m" -f ($timeToTicket / 60) } else { "{0:N1}s" -f $timeToTicket }
    
    # Financial Alpha (Market Comparison)
    $safeBurn = if (Test-Path "variable:dailyBurn") { [double]$dailyBurn } else { 0.01 }
    if ($safeBurn -le 0) { $safeBurn = 0.01 }
    $alphaMult = $dailyRetailVal / $safeBurn

    # --- SIDE-BY-SIDE DISPLAY ---
    Write-Host " [ SWARM LOTTERY TICKET OFFICE ] ".PadRight(45) + " [ NETWORK & BYPASS ]" -ForegroundColor Cyan
    
    $activeCoins = if ($btcH -gt 0 -and $bchH -gt 0) { "BTC+BCH" } elseif ($bchH -gt 0) { "BCH" } else { "BTC" }
    Write-Host " STRATEGY: HYBRID (@ $activeCoins | $([math]::Round($totalH,2)) TH/s)".PadRight(45) + " Frequency: 1 Tix / $timeStr" -ForegroundColor White

    # Row 1: Production vs PRIMARY Difficulty (Live Pulls)
    $col1 = (" - Daily Production: {0:N0} tix" -f $virtualTicketsDay).PadRight(45)
    if ($btcH -gt 0 -and $bchH -gt 0) {
        $col2 = " - BTC Diff : {0:N0}" -f $global:calcBTC
    } elseif ($bchH -gt 0) {
        $col2 = " - BCH Diff : {0:N0}" -f $global:calcBCH
    } else {
        $col2 = " - BTC Diff : {0:N0}" -f $global:calcBTC
    }
    Write-Host $col1 -NoNewline -ForegroundColor Yellow; Write-Host $col2 -ForegroundColor DarkGray

    # Row 2: Monthly Capacity vs SECONDARY Difficulty (Hybrid Awareness)
    $col1 = (" - Monthly Cap    : {0:N0} tix" -f $virtualTicketsMonth).PadRight(45)
    if ($btcH -gt 0 -and $bchH -gt 0) {
        $col2 = " - BCH Diff : {0:N0}" -f $global:calcBCH
    } else {
        $col2 = " - ROI Alpha: {0:N1}x cheaper" -f $alphaMult
    }
    Write-Host $col1 -NoNewline -ForegroundColor Gray; Write-Host $col2 -ForegroundColor Magenta

    # Row 3: Retail Value vs Win Window
    $monthsToJackpot = if ($virtualTicketsMonth -gt 0) { $targetLottoOdds / $virtualTicketsMonth } else { 0 }
    $col1 = (" - Retail Value   : $gbp {0:N2}" -f $dailyRetailVal).PadRight(45)
    if ($btcH -gt 0 -and $bchH -gt 0) {
        $col2 = " - ROI Alpha : {0:N1}x" -f $alphaMult
    } else {
        $col2 = " - Win Window: {0:N1} Months" -f $monthsToJackpot
    }
    Write-Host $col1 -NoNewline -ForegroundColor Green; Write-Host $col2 -ForegroundColor Cyan

    # Hybrid Footer (Ensures no logic is lost when both Diffs are shown)
    if ($btcH -gt 0 -and $bchH -gt 0) {
        Write-Host ("".PadRight(45) + " - Win Window: {0:N1} Months" -f $monthsToJackpot) -ForegroundColor Cyan
    }

    Write-Host $sep -ForegroundColor DarkGray

# ===========================================================================
# --- 10.2 INVESTMENT PODIUM (HYBRID UNIT-ACCOUNTING) -----------------------
# ===========================================================================
# (Podium maintains "Best Deal" Cost/TH and Live Hybrid Ticket Math)

Write-Host " [ INVESTMENT PODIUM - Ranking Your Best Hardware Deals ]" -ForegroundColor Cyan
Write-Host " Rank | Miner Name          | Buy Price  | Cost/TH    | Daily Tix" -ForegroundColor Gray
Write-Host $sep -ForegroundColor DarkGray

$podiumData = foreach ($m in $minerData) {
    $cfg = $brain.MinerManifest | Where-Object { $_.IP -eq $m.IP -or $_.Name -eq $m.Name } | Select-Object -First 1
    $pCost = if ($null -ne $cfg -and $cfg.psobject.Properties['PurchaseCost']) { [double]$cfg.PurchaseCost } else { 0.0 }
    $stableTarget = if ($null -ne $cfg -and $cfg.psobject.Properties['Target']) { [double]$cfg.Target } else { 1.3 }
    
    $costPerTH = if ($stableTarget -gt 0) { $pCost / $stableTarget } else { 0 }

    # USES LIVE GLOBAL DIFF: Ensures unit tickets match the live network state
    $unitBtcProb = ($m.Hash * 1e12 * 86400) / ($global:calcBTC * [math]::Pow(2,32))
    $unitBchProb = ($m.Hash * 1e12 * 86400) / ($global:calcBCH * [math]::Pow(2,32))
    $unitTotalHybridTickets = ($unitBtcProb + $unitBchProb) * $targetLottoOdds

    [PSCustomObject]@{
        Name     = $m.Name
        RawCost  = $pCost
        RankCost = $costPerTH
        Tickets  = $unitTotalHybridTickets
    }
}

$rankedList = $podiumData | Where-Object { $_.RankCost -gt 0 } | Sort-Object RankCost | Select-Object -First 3
$rank = 1
foreach ($p in $rankedList) {
    $rCol = switch($rank) { 1 {"Yellow"}; 2 {"White"}; 3 {"DarkYellow"} }
    $c_name = ($p.Name).PadRight(19).Substring(0,19); $c_buy = ("$gbp{0:N0}" -f $p.RawCost).PadRight(10); $c_rank = ("$gbp{0:N2}" -f $p.RankCost).PadRight(10); $c_tix = ("{0:N0}" -f $p.Tickets).PadLeft(6)
    Write-Host "  #$rank  " -NoNewline -ForegroundColor $rCol
    Write-Host "| $c_name | $c_buy | $c_rank | $c_tix Tix" -ForegroundColor White
    $rank++
}
Write-Host $sep -ForegroundColor DarkGray

# ===========================================================================
# --- 11.2 SUPPORT & DONATIONS ---
# ===========================================================================
    Write-Host " [ SUPPORT THE PROJECT ]" -ForegroundColor DarkGray
    Write-Host " If you find the Swarm Monitor useful, consider fueling Chip's coffee:" -ForegroundColor Gray
    Write-Host " BTC: 34Q2ySpjcUGnEkxe7JfPxKCh2BYNPgMyYu" -ForegroundColor Yellow
    Write-Host $sep -ForegroundColor DarkGray

# ===========================================================================
# --- 11.3 & 12.0 UNIFIED HEARTBEAT & COMMAND ENGINE (STABILIZED) -----------
# ===========================================================================
    # 1. PRE-CALCULATE DISPLAY VALUES
    $displayPool = if ($null -ne $global:poolString) { $global:poolString } else { "SOLO" }
    $shortLoc = if ($displayPool -match '\.') { ($displayPool -split '\.')[-2].ToUpper() } else { "SOLO" }
    
    $liveInfo = if ($btcH -gt 0 -and $bchH -gt 0) { 
        "$([math]::Round($bchH,1))BCH/$([math]::Round($btcH,1))BTC" 
    } else { 
        "$([math]::Round($totalH,1)) TH/s" 
    }

    $footerRow = 60 # Anchor point for portrait 1080x1920 layout

    # 2. DRAW MENU LINE (Clean Wipe with ESC[2K)
    [Console]::SetCursorPosition(0, $footerRow - 1)
    $menuLine = " FUNCTIONS: [N]EXT [P]REV [L]OCK [H]UNT [X]REMOVE [A]DD [R]EFRESH [Q]UIT"
    Write-Host ("$([char]27)[2K" + $menuLine.PadRight(100)) -ForegroundColor Cyan

    $statusTemplate = " {0} | {1,-8} | {2,-15} | {3,-10} | {4}"
    
    # 3. MAIN COUNTDOWN & POLLING LOOP (10 Seconds)
    for ($i=10; $i -gt 0; $i--) {
        $global:refreshTimer = $i 
        Redraw-SwarmHeader # Keeps the top stats ticking

        [Console]::SetCursorPosition(0, $footerRow)

        if ($autoCycle) {
            $cycleCounter++
            if ($cycleCounter -ge ($cycleInterval * 10)) {
                $currentPage++; if ($currentPage -gt $maxPages) { $currentPage = 1 }
                $cycleCounter = 0; $loopCount = 0; $i=0; break 
            }
        }

        $heartbeat = if ($i % 2 -eq 0) { " " } else { "!" }
        $progress  = if ($autoCycle) { ("#" * (($cycleCounter % 5) + 1)) } else { "-----" }
        $cycleStat = if ($autoCycle) { "AUTO" } else { "LOCK" }
        $timeNow   = Get-Date -Format 'HH:mm:ss'
        $fullLine  = $statusTemplate -f $timeNow, $shortLoc, $liveInfo, "          ", "$cycleStat $progress"
        
        Write-Host -NoNewline "`r$([char]27)[2K$($fullLine.PadRight(95)) | $heartbeat $($i)s " -ForegroundColor Gray

        # 4. SUB-SECOND KEYBOARD POLLING
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt 1000) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true).Key.ToString().ToUpper()
                [Console]::SetCursorPosition(0, $footerRow + 1)
                Write-Host "$([char]27)[2K" -NoNewline
                
                switch ($key) {
                    'L' { 
                        $autoCycle = !($autoCycle); $cycleCounter = 0
                        $msg = if ($autoCycle) { "RESUMING AUTO-CYCLE" } else { "SCROLL LOCKED" }
                        Write-Host " [!] $msg" -ForegroundColor Cyan
                        Start-Sleep -Seconds 1; $i=0; break
                    }
                    'N' { if ($maxPages -gt 1) { $currentPage++; if ($currentPage -gt $maxPages) { $currentPage = 1 }; $cycleCounter = 0; Clear-Host; $i=0; break } }
                    'P' { if ($maxPages -gt 1) { $currentPage--; if ($currentPage -lt 1) { $currentPage = $maxPages }; $cycleCounter = 0; Clear-Host; $i=0; break } }
                    'R' { Write-Host " [!] HARD REFRESH..." -ForegroundColor Yellow; $minerData = @(); Clear-Host; $loopCount = 0; $i=0; break }
                    'Q' { 
                        Write-Host " [!] EXITING..." -ForegroundColor Red
                        $brain.GraphHistory = @($hashHistory | Select-Object -Last 100)
                        Save-Brain -Data $brain -Path $configPath
                        exit 
                    }
                    'A' { 
                        Add-ManualMiner
                        # --- SYNC & REFRESH LADDER ---
                        $global:miners = $brain.MinerManifest
                        $global:minerData = @() # Force Section 7.0 to wipe
                        Clear-Host
                        Write-Host " [!] MINER ADDED. RE-SCANNING SWARM..." -ForegroundColor Cyan
                        Start-Sleep -Milliseconds 800
                        $i=0; break 
                    }
                    'H' { 
                        Write-Host " [!] STARTING NETWORK DISCOVERY..." -ForegroundColor Yellow
                        $discovered = Get-SwarmDiscovery
                        if ($null -ne $discovered -and $discovered.Count -gt 0) {
                            Update-SwarmInventory -discoveredNodes $discovered
                            $global:miners = $brain.MinerManifest 
                        }
                        # --- SYNC & REFRESH LADDER ---
                        $global:minerData = @()
                        Clear-Host
                        Write-Host " [!] DISCOVERY COMPLETE. REDRAWING DASHBOARD..." -ForegroundColor Cyan
                        Start-Sleep -Milliseconds 800
                        $i=0; break
                    }
                    'X' { 
                        Write-Host " [ REMOVE MINER ]" -ForegroundColor Red
                        if ($brain.MinerManifest.Count -gt 0) {
                            for ($idx=0; $idx -lt $brain.MinerManifest.Count; $idx++) {
                                Write-Host "  [$idx] $($brain.MinerManifest[$idx].Name) ($($brain.MinerManifest[$idx].IP))"
                            }
                            $choice = Read-Host " Enter ID to remove (or 'C' to cancel)"
                            if ($choice -match '^\d+$') {
                                $index = [int]$choice
                                if ($index -lt $brain.MinerManifest.Count) {
                                    $tempList = [System.Collections.Generic.List[PSCustomObject]]($brain.MinerManifest)
                                    $tempList.RemoveAt($index); $brain.MinerManifest = @($tempList)
                                    
                                    # RE-CALCULATE UK LEDGER AND SYNC
                                    $brain.Settings.HardwareCost = ($brain.MinerManifest.PurchaseCost | Measure-Object -Sum).Sum
                                    $global:miners = $brain.MinerManifest 
                                    
                                    Save-Brain -Data $brain -Path $configPath
                                    
                                    # --- SYNC & REFRESH LADDER ---
                                    $global:minerData = @() # Clear old Lucky Ladder data
                                    Clear-Host
                                    Write-Host " [!] REMOVED. SYNCING VIEW..." -ForegroundColor Green
                                    Start-Sleep -Milliseconds 800
                                    $i=0; break 
                                }
                            }
                        }
                    }
                }
            }
            Start-Sleep -Milliseconds 20
        }
    }

# ===========================================================================
# --- 13.0 PERSISTENCE & DATA SYNC ------------------------------------------
# ===========================================================================
    # 1. Update JSON Graph History
    $hashHistory += [double]$totalH
    if ($hashHistory.Count -gt 100) { $hashHistory = $hashHistory | Select-Object -Last 100 }
    $brain.GraphHistory = $hashHistory | ForEach-Object { [math]::Round($_, 2) }

    # 2. Update Window Title
    $titleSplit = if ($btcH -gt 0 -and $bchH -gt 0) { 
        "($([math]::Round($bchH,1)) BCH / $([math]::Round($btcH,1)) BTC)" 
    } else { 
        "($([math]::Round($totalH,1)) TH/s)" 
    }
    $Host.UI.RawUI.WindowTitle = "SWARM: $(Get-Date -Format 'HH:mm:ss') | $currentLoc | $titleSplit"

    # 3. Robust Save (Periodic Auto-Save)
    if ($loopCount % 5 -eq 0 -or $i -eq 0) {
        # Keep HardwareCost accurate to the current manifest
        $brain.Settings.HardwareCost = ($brain.MinerManifest.PurchaseCost | Measure-Object -Sum).Sum
        Save-Brain -Data $brain -Path $configPath
    }

    # 4. Mandatory Loop Reset
    Write-Host -NoNewline "`r$([char]27)[2K"
    $loopCount++


} # --- END OF MAIN WHILE($TRUE) LOOP
