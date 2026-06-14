# =====================================================================================
# If you like this helper tool for SMLT app, please consider a donation if youre in a position to do so. 
# Any amount is greatly appreciated!
# Plese give credit if you are modyfying or sharing outside of the offical GitHub page:
# https://github.com/473105/Start-Menu-Lite-Tools
# Thanks!
# =====================================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Drawing,System.Windows.Forms

# ==============================================================================
# Single-instance guard (same script version)
# ==============================================================================
$script:SingleInstanceMutex = $null
$script:SingleInstanceMutexName = ''
try {
  $scriptBase = ''
  try { $scriptBase = [System.IO.Path]::GetFileNameWithoutExtension([string]$PSCommandPath) } catch { $scriptBase = '' }
  if ([string]::IsNullOrWhiteSpace($scriptBase)) { $scriptBase = 'Icon_Allocator' }
  $scriptBase = ($scriptBase -replace '[^A-Za-z0-9_.-]', '_')
  $script:SingleInstanceMutexName = ('Local\{0}' -f $scriptBase)
  $createdNew = $false
  $script:SingleInstanceMutex = New-Object System.Threading.Mutex($true, $script:SingleInstanceMutexName, [ref]$createdNew)
  if (-not $createdNew) { exit }
  try {
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
      try {
        if ($script:SingleInstanceMutex) {
          try { $script:SingleInstanceMutex.ReleaseMutex() } catch {}
          try { $script:SingleInstanceMutex.Dispose() } catch {}
        }
      } catch {}
    } | Out-Null
  } catch {}
} catch {}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class IconNativeSorter {
  [DllImport("Shell32.dll", CharSet=CharSet.Unicode)]
  public static extern uint ExtractIconEx(string lpszFile, int nIconIndex, IntPtr[] phiconLarge, IntPtr[] phiconSmall, uint nIcons);
  [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern uint PrivateExtractIcons(string szFileName, int nIconIndex, int cxIcon, int cyIcon, IntPtr[] phicon, uint[] piconid, uint nIcons, uint flags);
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool DestroyIcon(IntPtr hIcon);
}
"@

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class HostWindowNativeSorter {
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern IntPtr GetConsoleWindow();
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class DwmTitleBarNativeSorter {
  [DllImport("dwmapi.dll", PreserveSig=true)]
  public static extern int DwmSetWindowAttribute(IntPtr hwnd, int dwAttribute, ref int pvAttribute, int cbAttribute);
}
"@

function Hide-HostConsoleWindow {
  try {
    $h = [HostWindowNativeSorter]::GetConsoleWindow()
    if ($h -ne [IntPtr]::Zero) { [void][HostWindowNativeSorter]::ShowWindow($h, 0) }
  } catch {}
}
Hide-HostConsoleWindow

function Get-WpfWindowHandle {
  param([System.Windows.Window]$Window)
  try {
    if ($Window) {
      return (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
    }
  } catch {}
  return [IntPtr]::Zero
}

function Get-IsWindowsBuildAtLeast19044Runtime {
  try {
    $b = 0
    try { $b = [int](Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'CurrentBuildNumber' -ErrorAction Stop) } catch { $b = 0 }
    if ($b -gt 0) { return ($b -ge 19044) }
    try { return ([Environment]::OSVersion.Version.Build -ge 19044) } catch {}
  } catch {}
  return $false
}

function Enable-SoftWindowShadow {
  param(
    [Parameter(Mandatory=$false)][System.Windows.Window]$Window = $script:window
  )
  try {
    if (-not $Window) { return }
    try {
      $wc = [System.Windows.Shell.WindowChrome]::GetWindowChrome($Window)
      if ($wc) {
        $frameThicknessPx = 1.0
        try { if (Get-IsWindowsBuildAtLeast19044Runtime) { $frameThicknessPx = 0.0 } } catch {}
        $wc.GlassFrameThickness = New-Object System.Windows.Thickness($frameThicknessPx)
        $wc.ResizeBorderThickness = New-Object System.Windows.Thickness 6
      }
    } catch {}
    try {
      if ("DwmTitleBarNativeSorter" -as [type]) {
        $hwnd = Get-WpfWindowHandle -Window $Window
        if ($hwnd -ne [IntPtr]::Zero) {
          $ncrpEnabled = 2  # DWMNCRP_ENABLED
          $cb = 4
          try { [void][DwmTitleBarNativeSorter]::DwmSetWindowAttribute($hwnd, 2, [ref]$ncrpEnabled, $cb) } catch {}
        }
      }
    } catch {}
  } catch {}
}

function Update-WindowShadowByState {
  param(
    [Parameter(Mandatory=$false)][System.Windows.Window]$Window = $script:window
  )
  try {
    if (-not $Window) { return }
    $wc = $null
    try { $wc = [System.Windows.Shell.WindowChrome]::GetWindowChrome($Window) } catch { $wc = $null }
    if (-not $wc) { return }
    $isMax = $false
    try { $isMax = ($Window.WindowState -eq [System.Windows.WindowState]::Maximized) } catch { $isMax = $false }
    if ($isMax) {
      try { $wc.GlassFrameThickness = New-Object System.Windows.Thickness 0 } catch {}
      try { $wc.ResizeBorderThickness = New-Object System.Windows.Thickness(6,0,6,6) } catch {}
      try {
        if ("DwmTitleBarNativeSorter" -as [type]) {
          $hwnd = Get-WpfWindowHandle -Window $Window
          if ($hwnd -ne [IntPtr]::Zero) {
            $ncrpDisabled = 1  # DWMNCRP_DISABLED
            $cb = 4
            try { [void][DwmTitleBarNativeSorter]::DwmSetWindowAttribute($hwnd, 2, [ref]$ncrpDisabled, $cb) } catch {}
          }
        }
      } catch {}
    } else {
      $frameThicknessPx = 1.0
      try { if (Get-IsWindowsBuildAtLeast19044Runtime) { $frameThicknessPx = 0.0 } } catch {}
      try { $wc.GlassFrameThickness = New-Object System.Windows.Thickness($frameThicknessPx) } catch {}
      try { $wc.ResizeBorderThickness = New-Object System.Windows.Thickness 6 } catch {}
      try {
        if ("DwmTitleBarNativeSorter" -as [type]) {
          $hwnd = Get-WpfWindowHandle -Window $Window
          if ($hwnd -ne [IntPtr]::Zero) {
            $ncrpEnabled = 2  # DWMNCRP_ENABLED
            $cb = 4
            try { [void][DwmTitleBarNativeSorter]::DwmSetWindowAttribute($hwnd, 2, [ref]$ncrpEnabled, $cb) } catch {}
          }
        }
      } catch {}
    }
  } catch {}
}

function Normalize-Path {
  param([string]$Path)
  try {
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $p = [Environment]::ExpandEnvironmentVariables([string]$Path)
    try { $p = [System.IO.Path]::GetFullPath($p) } catch {}
    return [string]$p
  } catch { return '' }
}

function Normalize-SourcePathForDisplay {
  param([string]$Path)
  try {
    $p = [string]$Path
    if ([string]::IsNullOrWhiteSpace($p)) { return '' }
    $p = $p.Trim()
    $p = $p -replace '/', '\'
    if ($p -match '^%[^%]+%(\\.*)?$') { return $p }

    $full = Normalize-Path $p
    if ([string]::IsNullOrWhiteSpace($full)) { return $p }
    $full = [string]$full

    function _GetEnvVal {
      param([string]$Name)
      $v = ''
      try { $v = [string](Get-Item -Path ("Env:\" + $Name) -ErrorAction SilentlyContinue).Value } catch { $v = '' }
      if ([string]::IsNullOrWhiteSpace($v)) { try { $v = [string][Environment]::GetEnvironmentVariable($Name, 'Process') } catch { $v = '' } }
      if ([string]::IsNullOrWhiteSpace($v)) { try { $v = [string][Environment]::GetEnvironmentVariable($Name, 'User') } catch { $v = '' } }
      if ([string]::IsNullOrWhiteSpace($v)) { try { $v = [string][Environment]::GetEnvironmentVariable($Name, 'Machine') } catch { $v = '' } }
      return [string]$v
    }

    $envPairs = @(
      @('SystemRoot','SystemRoot'),
      @('WINDIR','WINDIR'),
      @('ProgramFiles','ProgramFiles'),
      @('ProgramFiles(x86)','ProgramFiles(x86)'),
      @('ProgramData','ProgramData'),
      @('APPDATA','APPDATA'),
      @('LOCALAPPDATA','LOCALAPPDATA'),
      @('USERPROFILE','USERPROFILE'),
      @('PUBLIC','PUBLIC'),
      @('SystemDrive','SystemDrive'),
      @('HOMEDRIVE','HOMEDRIVE')
    )

    $roots = @()
    foreach ($pair in @($envPairs)) {
      $name = ''
      $envName = ''
      try { $name = [string]$pair[0] } catch { $name = '' }
      try { $envName = [string]$pair[1] } catch { $envName = '' }
      if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($envName)) { continue }
      $raw = _GetEnvVal $envName
      if ([string]::IsNullOrWhiteSpace($raw)) { continue }
      # Convert "C:" drive shorthand into stable root.
      if ($raw -match '^[A-Za-z]:$') { $raw = ($raw + '\') }
      $root = Normalize-Path $raw
      if ([string]::IsNullOrWhiteSpace($root)) { continue }
      $roots += [pscustomobject]@{ Name = $name; Root = [string]$root }
    }

    # Longest root wins.
    $roots = @($roots | Sort-Object { try { ([string]$_.Root).TrimEnd('\').Length } catch { 0 } } -Descending)
    foreach ($r in @($roots)) {
      $name = ''
      $root = ''
      try { $name = [string]$r.Name } catch { $name = '' }
      try { $root = [string]$r.Root } catch { $root = '' }
      if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($root)) { continue }
      $rootCmp = $root.TrimEnd('\')
      if ([string]::IsNullOrWhiteSpace($rootCmp)) { continue }
      $match = $false
      if ($full.Length -eq $rootCmp.Length -and $full.Equals($rootCmp, [System.StringComparison]::OrdinalIgnoreCase)) {
        $match = $true
      } elseif ($full.Length -gt $rootCmp.Length -and $full.StartsWith(($rootCmp + '\'), [System.StringComparison]::OrdinalIgnoreCase)) {
        $match = $true
      }
      if (-not $match) { continue }
      $suffix = ''
      if ($full.Length -gt $rootCmp.Length) { $suffix = $full.Substring($rootCmp.Length) }
      if ($suffix.StartsWith('\')) { $suffix = $suffix.Substring(1) }
      if ([string]::IsNullOrWhiteSpace($suffix)) { return ('%{0}%' -f $name) }
      return ('%{0}%\{1}' -f $name, [string]$suffix)
    }

    # Generic drive fallback.
    if ($full -match '^[A-Za-z]:\\') {
      $sysDrive = _GetEnvVal 'SystemDrive'
      if (-not [string]::IsNullOrWhiteSpace($sysDrive)) {
        if ($sysDrive -match '^[A-Za-z]:$') { $sysDrive = ($sysDrive + '\') }
        $drvRoot = Normalize-Path $sysDrive
        if (-not [string]::IsNullOrWhiteSpace($drvRoot)) {
          $drvCmp = $drvRoot.TrimEnd('\')
          if ($full.Length -eq $drvCmp.Length -and $full.Equals($drvCmp, [System.StringComparison]::OrdinalIgnoreCase)) {
            return '%SystemDrive%'
          }
          if ($full.Length -gt $drvCmp.Length -and $full.StartsWith(($drvCmp + '\'), [System.StringComparison]::OrdinalIgnoreCase)) {
            $tail = $full.Substring($drvCmp.Length)
            if ($tail.StartsWith('\')) { $tail = $tail.Substring(1) }
            if ([string]::IsNullOrWhiteSpace($tail)) { return '%SystemDrive%' }
            return ('%SystemDrive%\{0}' -f [string]$tail)
          }
        }
      }
    }

    return $full
  } catch {
    try { return ([string]$Path).Trim() } catch { return '' }
  }
}

function Get-SourcePathKey {
  param([string]$Path)
  try {
    $raw = ''
    try { $raw = [string]$Path } catch { $raw = '' }
    if ([string]::IsNullOrWhiteSpace($raw)) { return '' }
    $raw = $raw.Trim().Trim('"')
    $raw = $raw -replace '/', '\'
    $n = Normalize-Path $raw
    if ([string]::IsNullOrWhiteSpace($n)) { return '' }
    try {
      if ($n.Length -gt 3 -and $n.EndsWith('\')) {
        $n = $n.TrimEnd('\')
      }
    } catch {}
    return $n.ToLowerInvariant()
  } catch { return '' }
}

function Get-SourcePathVisibility {
  param([string]$Path)
  try {
    $k = Get-SourcePathKey ([string]$Path)
    if ([string]::IsNullOrWhiteSpace($k)) { return $true }
    if ($script:IconSourceVisibilityByKey -and $script:IconSourceVisibilityByKey.ContainsKey($k)) {
      return [bool]$script:IconSourceVisibilityByKey[$k]
    }
    return $true
  } catch { return $true }
}

function Is-DefaultSourcePathKey {
  param([string]$Key)
  try {
    if ([string]::IsNullOrWhiteSpace($Key)) { return $false }
    foreach ($d in @(Get-EffectiveBuiltInSourceEntries)) {
      $dk = ''
      try { $dk = Get-SourcePathKey ([string]$d) } catch { $dk = '' }
      if ([string]::IsNullOrWhiteSpace($dk)) { continue }
      if ($dk -eq [string]$Key) { return $true }
    }
    return $false
  } catch { return $false }
}

function Set-SourcePathVisibility {
  param(
    [string]$Path,
    [bool]$Visible
  )
  try {
    $k = Get-SourcePathKey ([string]$Path)
    if ([string]::IsNullOrWhiteSpace($k)) { return }
    if (-not $script:IconSourceVisibilityByKey) { $script:IconSourceVisibilityByKey = @{} }
    $script:IconSourceVisibilityByKey[$k] = [bool]$Visible
  } catch {}
}

function Update-ToggleAllSourcePathsCheckState {
  try {
    if (-not $toggleAllSourcePathsBox -or -not $iconSourceDirList) { return }
    $rows = @()
    try { $rows = @($iconSourceDirList.ItemsSource) } catch { $rows = @() }
    if (@($rows).Count -le 0) {
      try { $script:SuppressSourcePathUiEvents = $true; $toggleAllSourcePathsBox.IsChecked = $true } finally { $script:SuppressSourcePathUiEvents = $false }
      return
    }
    $allChecked = $true
    foreach ($r in @($rows)) {
      if (-not $r) { continue }
      $chk = $false
      try { $chk = [bool]$r.ShowChecked } catch { $chk = $false }
      if (-not $chk) { $allChecked = $false; break }
    }
    try { $script:SuppressSourcePathUiEvents = $true; $toggleAllSourcePathsBox.IsChecked = $allChecked } finally { $script:SuppressSourcePathUiEvents = $false }
  } catch {}
}

function Set-AllSourcePathsShown {
  param([bool]$Selected)
  try {
    $allSources = @()
    try { $allSources = @((Get-EffectiveBuiltInSourceEntries) + @($script:CustomIconSourceDirs.ToArray())) } catch { $allSources = @() }
    if (@($allSources).Count -eq 0) {
      try { $statusText.Text = 'No source paths available.' } catch {}
      return
    }

    $keysTouched = New-Object 'System.Collections.Generic.HashSet[string]'
    try { $script:SuppressSourcePathUiEvents = $true } catch {}
    $changed = $false
    foreach ($src in @($allSources)) {
      $p = ''
      try { $p = Normalize-SourcePathForDisplay ([string]$src) } catch { $p = '' }
      if ([string]::IsNullOrWhiteSpace($p)) { continue }
      $pk = ''
      try { $pk = Get-SourcePathKey $p } catch { $pk = '' }
      if ([string]::IsNullOrWhiteSpace($pk)) { continue }
      if ($keysTouched.Contains($pk)) { continue }
      [void]$keysTouched.Add($pk)
      $current = $true
      try { $current = [bool](Get-SourcePathVisibility -Path $p) } catch { $current = $true }
      if ($current -ne [bool]$Selected) { $changed = $true }
      try { Set-SourcePathVisibility -Path $p -Visible:$Selected } catch {}
    }
    if ($changed) {
      try { Refresh-IconSourceDirectoryList } catch {}
      try { Save-CustomIconSourceDirectories } catch {}
      try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
      try { $script:IconCurrentPage = 1 } catch {}
      try { Refresh-IconListPage } catch {}
    } else {
      try { Refresh-IconSourceDirectoryList } catch {}
    }

    try { Update-ToggleAllSourcePathsCheckState } catch {}
    try {
      if ($window -and $window.Dispatcher) {
        $null = $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
      }
    } catch {}
    try { $script:SuppressSourcePathUiEvents = $false } catch {}
    if ($Selected) {
      try { $statusText.Text = 'All source paths set to Show.' } catch {}
    } else {
      try { $statusText.Text = 'All source paths removed from Show.' } catch {}
    }
  } catch {
    try { $script:SuppressSourcePathUiEvents = $false } catch {}
    try { $statusText.Text = ("Source path toggle failed: " + [string]$_.Exception.Message) } catch {}
  }
}

function Queue-SourcePathFilterRefresh {
  try {
    if (-not $script:SourcePathRefreshTimer) {
      $script:SourcePathRefreshTimer = New-Object System.Windows.Threading.DispatcherTimer
      $script:SourcePathRefreshTimer.Interval = [TimeSpan]::FromMilliseconds(80)
      $script:SourcePathRefreshTimer.Add_Tick({
        try { $script:SourcePathRefreshTimer.Stop() } catch {}
        $pending = $false
        try { $pending = [bool]$script:SourcePathRefreshPending } catch { $pending = $false }
        if (-not $pending) { return }
        try { $script:SourcePathRefreshPending = $false } catch {}
        try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
        try { $script:IconCurrentPage = 1 } catch {}
        try { Refresh-IconListPage } catch {}
      })
    }
    try { $script:SourcePathRefreshPending = $true } catch {}
    try { $script:SourcePathRefreshTimer.Stop() } catch {}
    try { $script:SourcePathRefreshTimer.Start() } catch {}
  } catch {
    try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
    try { $script:IconCurrentPage = 1 } catch {}
    try { Refresh-IconListPage } catch {}
  }
}

function Get-IconImageSource {
  param(
    [Parameter(Mandatory=$true)][string]$IconPath,
    [Parameter(Mandatory=$true)][int]$IconIndex
  )
  try {
    if ([string]::IsNullOrWhiteSpace($IconPath)) { return $null }
    if (-not (Test-Path -LiteralPath $IconPath -PathType Leaf)) { return $null }
    $large = New-Object IntPtr[] 1
    $small = New-Object IntPtr[] 1
    [void][IconNativeSorter]::ExtractIconEx($IconPath, $IconIndex, $large, $small, 1)
    $h = [IntPtr]::Zero
    if ($large[0] -ne [IntPtr]::Zero) { $h = $large[0] } elseif ($small[0] -ne [IntPtr]::Zero) { $h = $small[0] }
    if ($h -eq [IntPtr]::Zero) { return $null }
    try {
      $src = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
        $h,
        [System.Windows.Int32Rect]::Empty,
        [System.Windows.Media.Imaging.BitmapSizeOptions]::FromWidthAndHeight(40,40)
      )
      try { $src.Freeze() } catch {}
      return $src
    } finally {
      if ($small[0] -ne [IntPtr]::Zero) { [void][IconNativeSorter]::DestroyIcon($small[0]) }
      if ($large[0] -ne [IntPtr]::Zero) { [void][IconNativeSorter]::DestroyIcon($large[0]) }
    }
  } catch { return $null }
}

function Show-SaveCompletedDialog {
  param(
    [string]$Message = 'Save completed.',
    [string]$Title = 'Icon Allocator (v1.77)'
  )
  try {
    $dlg = New-Object System.Windows.Window
    $dlg.Title = $Title
    $dlg.Width = 380
    $dlg.MinHeight = 150
    $dlg.SizeToContent = [System.Windows.SizeToContent]::Height
    $dlg.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $dlg.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $dlg.ShowInTaskbar = $false
    try { if ($window) { $dlg.Owner = $window } } catch {}

    try {
      $icoPath = [Environment]::ExpandEnvironmentVariables('%systemroot%\\system32\\shell32.dll')
      $ico = Get-IconImageSource -IconPath $icoPath -IconIndex 296
      if ($ico) { $dlg.Icon = $ico }
    } catch {}

    $root = New-Object System.Windows.Controls.Grid
    $root.Margin = '12,12,12,14'
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::Auto
    $r2 = New-Object System.Windows.Controls.RowDefinition; $r2.Height = [System.Windows.GridLength]::Auto
    [void]$root.RowDefinitions.Add($r1)
    [void]$root.RowDefinitions.Add($r2)

    $top = New-Object System.Windows.Controls.StackPanel
    $top.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    [System.Windows.Controls.Grid]::SetRow($top,0)

    $img = New-Object System.Windows.Controls.Image
    $img.Width = 28
    $img.Height = 28
    $img.Margin = '0,0,10,0'
    try {
      $imgSrcPath = [Environment]::ExpandEnvironmentVariables('%systemroot%\\system32\\shell32.dll')
      $imgSrc = Get-IconImageSource -IconPath $imgSrcPath -IconIndex 296
      if ($imgSrc) { $img.Source = $imgSrc }
    } catch {}
    [void]$top.Children.Add($img)

    $txt = New-Object System.Windows.Controls.TextBlock
    $txt.Text = $Message
    $txt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $txt.TextWrapping = [System.Windows.TextWrapping]::Wrap
    [void]$top.Children.Add($txt)
    [void]$root.Children.Add($top)

    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $btnRow.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $btnRow.Margin = '0,14,0,2'
    [System.Windows.Controls.Grid]::SetRow($btnRow,1)
    $ok = New-Object System.Windows.Controls.Button
    $ok.Content = 'OK'
    $ok.Width = 86
    $ok.Height = 28
    $ok.IsDefault = $true
    $ok.Add_Click({ try { $dlg.DialogResult = $true } catch { $dlg.Close() } })
    [void]$btnRow.Children.Add($ok)
    [void]$root.Children.Add($btnRow)

    $dlg.Content = $root
    $null = $dlg.ShowDialog()
  } catch {}
}

if (-not (Test-Path variable:script:StartupSplashWindow)) { $script:StartupSplashWindow = $null }
if (-not (Test-Path variable:script:StartupSplashStatusText)) { $script:StartupSplashStatusText = $null }
if (-not (Test-Path variable:script:StartupSplashProgressBar)) { $script:StartupSplashProgressBar = $null }
if (-not (Test-Path variable:script:StartupMainReady)) { $script:StartupMainReady = $false }
if (-not (Test-Path variable:script:StartupMainCloseRequested)) { $script:StartupMainCloseRequested = $false }

function Test-StartupMainAbortRequested {
  try {
    return ((-not [bool]$script:StartupMainReady) -and [bool]$script:StartupMainCloseRequested)
  } catch { return $false }
}

function Show-StartupSplash {
  param([string]$Status = "Loading...")
  try {
    if ($script:StartupSplashWindow) { return }
    [xml]$sxaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="430" Height="100"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        ShowInTaskbar="False"
        Topmost="True"
        Title="Starting...">
  <Border CornerRadius="10"
          Background="#D9303030"
          BorderBrush="#80444444"
          BorderThickness="1"
          Padding="14">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="10"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="8"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <TextBlock Grid.Row="0"
                 Text="Icon Allocator"
                 Foreground="White"
                 FontWeight="SemiBold"
                 FontSize="14"/>
      <TextBlock Grid.Row="0"
                 HorizontalAlignment="Right"
                 VerticalAlignment="Center"
                 Text="v1.77"
                 Foreground="#CCFFFFFF"
                 FontWeight="SemiBold"
                 FontSize="12"/>
      <ProgressBar Name="SplashProgressBar"
                   Grid.Row="2"
                   Height="14"
                   Minimum="0"
                   Maximum="100"
                   Value="3"
                   Foreground="#2E8CF8"
                   Background="#55222222"
                   BorderBrush="#66444444"
                   BorderThickness="1"/>
      <TextBlock Name="SplashStatusText"
                 Grid.Row="4"
                 TextWrapping="Wrap"
                 Foreground="#F2FFFFFF"
                 Opacity="1"
                 FontSize="12"
                 MinHeight="34"
                 Margin="0,2,0,0"/>
    </Grid>
  </Border>
</Window>
"@
    $sreader = New-Object System.Xml.XmlNodeReader $sxaml
    $sw = [Windows.Markup.XamlReader]::Load($sreader)
    $script:StartupSplashWindow = $sw
    try { $script:StartupSplashStatusText = $sw.FindName("SplashStatusText") } catch { $script:StartupSplashStatusText = $null }
    try { $script:StartupSplashProgressBar = $sw.FindName("SplashProgressBar") } catch { $script:StartupSplashProgressBar = $null }
    if ($script:StartupSplashStatusText) { $script:StartupSplashStatusText.Text = [string]$Status }
    $sw.Show()
    try { $sw.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render) } catch {}
  } catch {}
}

function Set-StartupSplashStatus {
  param(
    [string]$Status = "",
    [double]$Value = -1
  )
  try {
    if ($script:StartupSplashStatusText) { $script:StartupSplashStatusText.Text = [string]$Status }
    if ($script:StartupSplashProgressBar -and $Value -ge 0) {
      $v = [Math]::Max(0.0, [Math]::Min(100.0, [double]$Value))
      $script:StartupSplashProgressBar.Value = $v
    }
    if ($script:StartupSplashWindow) {
      try { $script:StartupSplashWindow.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render) } catch {}
    }
  } catch {}
}

function Close-StartupSplash {
  try {
    if ($script:StartupSplashWindow) {
      try { $script:StartupSplashWindow.Close() } catch {}
    }
  } catch {}
  $script:StartupSplashWindow = $null
  $script:StartupSplashStatusText = $null
  $script:StartupSplashProgressBar = $null
}

function Save-BitmapSourceAsPngIco {
  param(
    [Parameter(Mandatory=$true)][System.Windows.Media.Imaging.BitmapSource]$Bitmap,
    [Parameter(Mandatory=$true)][string]$DestinationPath
  )
  $ok = $false
  $pngMs = $null
  $fs = $null
  $bw = $null
  try {
    if (-not $Bitmap) { return $false }
    try {
      $destDir = [System.IO.Path]::GetDirectoryName([string]$DestinationPath)
      if (-not [string]::IsNullOrWhiteSpace($destDir)) { [void][System.IO.Directory]::CreateDirectory($destDir) }
    } catch {}

    $pngMs = New-Object System.IO.MemoryStream
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    [void]$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($Bitmap))
    $enc.Save($pngMs)
    $pngBytes = $pngMs.ToArray()

    $w = 0; $h = 0
    try { $w = [int]$Bitmap.PixelWidth } catch { $w = 0 }
    try { $h = [int]$Bitmap.PixelHeight } catch { $h = 0 }
    if ($w -le 0 -or $h -le 0) { return $false }

    $wByte = if ($w -ge 256) { [byte]0 } else { [byte]$w }
    $hByte = if ($h -ge 256) { [byte]0 } else { [byte]$h }

    $fs = [System.IO.File]::Open($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $bw = New-Object System.IO.BinaryWriter($fs)

    # ICONDIR
    $bw.Write([UInt16]0)  # reserved
    $bw.Write([UInt16]1)  # type = icon
    $bw.Write([UInt16]1)  # count

    # ICONDIRENTRY (single PNG image)
    $bw.Write([byte]$wByte)
    $bw.Write([byte]$hByte)
    $bw.Write([byte]0)            # color count
    $bw.Write([byte]0)            # reserved
    $bw.Write([UInt16]1)          # planes
    $bw.Write([UInt16]32)         # bit count
    $bw.Write([UInt32]$pngBytes.Length)
    $bw.Write([UInt32]22)         # image offset (6 + 16)
    $bw.Write($pngBytes)

    $ok = $true
  } catch {
    $ok = $false
  } finally {
    try { if ($bw) { $bw.Close() } } catch {}
    try { if ($fs) { $fs.Close() } } catch {}
    try { if ($pngMs) { $pngMs.Close() } } catch {}
  }
  return [bool]$ok
}

function Save-IconRowToIco {
  param(
    [Parameter(Mandatory=$true)][object]$IconRow,
    [Parameter(Mandatory=$true)][string]$DestinationPath
  )
  $iconPath = ''
  $iconIndex = 0
  try { $iconPath = [string]$IconRow.IconPath } catch { $iconPath = '' }
  try { $iconIndex = [int]$IconRow.IconIndex } catch { $iconIndex = 0 }
  if ([string]::IsNullOrWhiteSpace($iconPath)) { return $false }
  if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) { return $false }

  $allHandles = New-Object 'System.Collections.Generic.List[System.IntPtr]'
  $h = [IntPtr]::Zero

  # Prefer high-quality icon variants first to preserve color depth.
  foreach ($sz in @(256,128,96,64,48,32)) {
    $tmp = New-Object IntPtr[] 1
    $ids = New-Object UInt32[] 1
    $count = 0
    try {
      $count = [uint][IconNativeSorter]::PrivateExtractIcons($iconPath, $iconIndex, $sz, $sz, $tmp, $ids, 1, 0)
    } catch {
      $count = 0
    }
    if ($tmp[0] -ne [IntPtr]::Zero) { [void]$allHandles.Add($tmp[0]) }
    if ($count -gt 0 -and $tmp[0] -ne [IntPtr]::Zero) {
      $h = $tmp[0]
      break
    }
  }

  # Fallback for files that don't provide icons through PrivateExtractIcons.
  $large = $null
  $small = $null
  if ($h -eq [IntPtr]::Zero) {
    $large = New-Object IntPtr[] 1
    $small = New-Object IntPtr[] 1
    [void][IconNativeSorter]::ExtractIconEx($iconPath, $iconIndex, $large, $small, 1)
    if ($large[0] -ne [IntPtr]::Zero) { [void]$allHandles.Add($large[0]) }
    if ($small[0] -ne [IntPtr]::Zero) { [void]$allHandles.Add($small[0]) }
    if ($large[0] -ne [IntPtr]::Zero) { $h = $large[0] } elseif ($small[0] -ne [IntPtr]::Zero) { $h = $small[0] }
  }

  if ($h -eq [IntPtr]::Zero) { return $false }
  $ok = $false
  $bmp = $null
  $ico = $null
  $clone = $null
  $fs = $null
  try {
    try {
      $bmp = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
        $h,
        [System.Windows.Int32Rect]::Empty,
        [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions()
      )
      try { if ($bmp) { $bmp.Freeze() } } catch {}
    } catch { $bmp = $null }

    if ($bmp) {
      $ok = [bool](Save-BitmapSourceAsPngIco -Bitmap $bmp -DestinationPath $DestinationPath)
    }

    # Fallback path for environments where WPF HICON conversion fails.
    if (-not $ok) {
      $ico = [System.Drawing.Icon]::FromHandle($h)
      $clone = [System.Drawing.Icon]$ico.Clone()
      try {
        $destDir = [System.IO.Path]::GetDirectoryName([string]$DestinationPath)
        if (-not [string]::IsNullOrWhiteSpace($destDir)) { [void][System.IO.Directory]::CreateDirectory($destDir) }
      } catch {}
      $fs = [System.IO.File]::Open($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
      $clone.Save($fs)
      $ok = $true
    }
  } catch {
    $ok = $false
  } finally {
    try { if ($fs) { $fs.Close() } } catch {}
    try { if ($clone) { $clone.Dispose() } } catch {}
    try { if ($ico) { $ico.Dispose() } } catch {}
    $destroyed = @{}
    foreach ($ih in @($allHandles.ToArray())) {
      try {
        if ($ih -ne [IntPtr]::Zero) {
          $k = $ih.ToInt64()
          if (-not $destroyed.ContainsKey($k)) {
            [void][IconNativeSorter]::DestroyIcon($ih)
            $destroyed[$k] = $true
          }
        }
      } catch {}
    }
  }
  return [bool]$ok
}

function Get-IconCountForFile {
  param([Parameter(Mandatory=$true)][string]$Path)
  try {
    $p = Normalize-Path $Path
    if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { return 0 }
    return [int][IconNativeSorter]::ExtractIconEx($p, -1, $null, $null, 0)
  } catch { return 0 }
}

function Get-CreateShortcutSystemIconSources {
  $raw = @(
    Get-EffectiveBuiltInSourceEntries
  )
  try {
    $raw = @($raw | Where-Object { $_ })
  } catch {}
  try {
    foreach ($d in @($script:CustomIconSourceDirs.ToArray())) {
      $dn = Normalize-Path ([string]$d)
      if ([string]::IsNullOrWhiteSpace($dn)) { continue }
      if (-not (Test-Path -LiteralPath $dn)) { continue }
      $raw += $dn
    }
  } catch {}
  $out = New-Object System.Collections.Generic.List[string]
  $seen = @{}
  $extSet = @('.dll','.exe','.cpl','.icl')
  foreach ($r in $raw) {
    $p = Normalize-Path ([Environment]::ExpandEnvironmentVariables([string]$r))
    if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path -LiteralPath $p)) { continue }
    $isDir = $false
    try { $isDir = Test-Path -LiteralPath $p -PathType Container } catch { $isDir = $false }
    if ($isDir) {
      Get-ChildItem -LiteralPath $p -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { try { $extSet -contains ([string]$_.Extension).ToLowerInvariant() } catch { $false } } |
        ForEach-Object {
          $fp = Normalize-Path ([string]$_.FullName)
          if ([string]::IsNullOrWhiteSpace($fp)) { return }
          $k = $fp.ToLowerInvariant()
          if ($seen.ContainsKey($k)) { return }
          $seen[$k] = $true
          [void]$out.Add($fp)
        }
      continue
    }
    $k = $p.ToLowerInvariant()
    if ($seen.ContainsKey($k)) { continue }
    $seen[$k] = $true
    [void]$out.Add($p)
  }
  return @($out.ToArray())
}

function Get-EffectiveBuiltInSourceEntries {
  try {
    $raw = @()
    try { $raw = @($script:BuiltInIconSourceDirs.ToArray()) } catch { $raw = @() }
    $out = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($d in @($raw)) {
      $n = ''
      try { $n = Normalize-SourcePathForDisplay ([string]$d) } catch { $n = '' }
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $k = ''
      try { $k = Get-SourcePathKey $n } catch { $k = '' }
      if ([string]::IsNullOrWhiteSpace($k)) { continue }
      if ($seen.ContainsKey($k)) { continue }
      $seen[$k] = $true
      [void]$out.Add($n)
    }
    return @($out.ToArray())
  } catch {
    return @()
  }
}

function Get-CategoryAssignmentKeyIndex {
  try {
    if (-not [bool]$script:CategoryAssignmentIndexDirty -and $script:CategoryAssignmentIndex) {
      return $script:CategoryAssignmentIndex
    }
  } catch {}
  $index = @{}
  try {
    foreach ($k in @($script:AssignmentsByKey.Keys)) {
      if ([string]::IsNullOrWhiteSpace([string]$k)) { continue }
      if (-not $script:AssignmentsByKey.ContainsKey($k)) { continue }
      $entry = $script:AssignmentsByKey[$k]
      if (-not $entry) { continue }
      foreach ($cat in @($entry.Categories)) {
        $n = ''
        try { $n = [string]$cat } catch { $n = '' }
        $n = $n.Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        if (-not $index.ContainsKey($n)) {
          $index[$n] = New-Object 'System.Collections.Generic.HashSet[string]'
        }
        try { [void]$index[$n].Add([string]$k) } catch {}
      }
    }
  } catch {}
  try {
    $script:CategoryAssignmentIndex = $index
    $script:CategoryAssignmentIndexDirty = $false
  } catch {}
  return $index
}

function Get-FilteredRowsByCategorySelection {
  param(
    [string[]]$ShowCategories,
    [string[]]$HideCategories
  )
  try {
    $showSet = @{}
    foreach ($cn in @($ShowCategories)) {
      $n = ''
      try { $n = [string]$cn } catch { $n = '' }
      $n = $n.Trim().ToLowerInvariant()
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $showSet[$n] = $true
    }
    $hideSet = @{}
    foreach ($cn in @($HideCategories)) {
      $n = ''
      try { $n = [string]$cn } catch { $n = '' }
      $n = $n.Trim().ToLowerInvariant()
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $hideSet[$n] = $true
    }

    $idx = Get-CategoryAssignmentKeyIndex
    $candidateKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    if ($showSet.Count -gt 0) {
      foreach ($sn in @($showSet.Keys)) {
        if (-not $idx.ContainsKey($sn)) { continue }
        foreach ($k in @($idx[$sn])) {
          try { [void]$candidateKeys.Add([string]$k) } catch {}
        }
      }
    } else {
      foreach ($k in @($script:IconsByKey.Keys)) {
        if ([string]::IsNullOrWhiteSpace([string]$k)) { continue }
        try { [void]$candidateKeys.Add([string]$k) } catch {}
      }
    }

    if ($hideSet.Count -gt 0) {
      foreach ($hn in @($hideSet.Keys)) {
        if (-not $idx.ContainsKey($hn)) { continue }
        foreach ($k in @($idx[$hn])) {
          try { [void]$candidateKeys.Remove([string]$k) } catch {}
        }
      }
    }

    # Preserve stable visual order by iterating AllIcons once (linear) instead of sorting candidates each time.
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($r in @($script:AllIcons.ToArray())) {
      if (-not $r) { continue }
      $k = ''
      try { $k = [string]$r.Key } catch { $k = '' }
      if ([string]::IsNullOrWhiteSpace($k)) { continue }
      if (-not $candidateKeys.Contains($k)) { continue }
      [void]$rows.Add($r)
    }
    return @($rows.ToArray())
  } catch {
    return @()
  }
}

function Get-IconKey {
  param([string]$Path,[int]$Index)
  $p = Normalize-Path $Path
  if ([string]::IsNullOrWhiteSpace($p)) { return '' }
  return ("{0},{1}" -f $p.Trim().ToLowerInvariant(), [int]$Index)
}

function Get-DefaultJsonPath {
  try {
    $base = Split-Path -Parent $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($base)) { $base = (Get-Location).Path }
    $catDir = Join-Path (Join-Path $base 'User Settings') 'Icon Categories'
    if (-not (Test-Path -LiteralPath $catDir)) {
      New-Item -ItemType Directory -Path $catDir -Force | Out-Null
    }
    return (Join-Path $catDir 'IconCategoryAssignments.json')
  } catch { return 'IconCategoryAssignments.json' }
}

function Get-IconCategoryProfilesRoot {
  try {
    $base = Split-Path -Parent $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($base)) { $base = (Get-Location).Path }
    $catDir = Join-Path (Join-Path $base 'User Settings') 'Icon Categories'
    if (-not (Test-Path -LiteralPath $catDir)) {
      New-Item -ItemType Directory -Path $catDir -Force | Out-Null
    }
    return $catDir
  } catch { return '' }
}

function Get-StartMenuBackupsRoot {
  try {
    $base = Split-Path -Parent $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($base)) { $base = (Get-Location).Path }
    $dir = Join-Path $base 'Start Menu Backups'
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return [string]$dir
  } catch { return '' }
}

function Get-FileStateSignature {
  param([string]$Path)
  try {
    $p = Normalize-Path ([string]$Path)
    if ([string]::IsNullOrWhiteSpace($p)) { return '<none>' }
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return '<missing>' }
    $fi = Get-Item -LiteralPath $p -ErrorAction Stop
    return ("{0}|{1}|{2}" -f [string]$fi.Name, [int64]$fi.Length, [int64]$fi.LastWriteTimeUtc.Ticks)
  } catch { return '<error>' }
}

function Get-CategoryProfilesStateSignature {
  try {
    $dir = Get-IconCategoryProfilesRoot
    if ([string]::IsNullOrWhiteSpace($dir) -or -not (Test-Path -LiteralPath $dir -PathType Container)) { return '<missing>' }
    $parts = New-Object System.Collections.Generic.List[string]
    $files = @()
    try { $files = @(Get-ChildItem -LiteralPath $dir -File -Filter *.json -ErrorAction SilentlyContinue | Sort-Object Name) } catch { $files = @() }
    foreach ($f in @($files)) {
      if (-not $f) { continue }
      $n = ''
      try { $n = [string]$f.Name } catch { $n = '' }
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      if ($n.Trim().ToLowerInvariant() -eq 'iconsourcedirectories.json') { continue }
      [void]$parts.Add(("{0}|{1}|{2}" -f [string]$f.Name, [int64]$f.Length, [int64]$f.LastWriteTimeUtc.Ticks))
    }
    if (@($parts.ToArray()).Count -eq 0) { return '<empty>' }
    return ([string]::Join(';', @($parts.ToArray())))
  } catch { return '<error>' }
}

function Capture-ExternalConfigSignatures {
  try { $script:IconSourceDirectoriesFileSignature = [string](Get-FileStateSignature -Path (Get-IconSourceDirectoriesStatePath)) } catch {}
  try { $script:CategoryProfilesSignature = [string](Get-CategoryProfilesStateSignature) } catch {}
}

function Get-SafeFileNameSegment {
  param([string]$Name)
  try {
    $n = ''
    try { $n = [string]$Name } catch { $n = '' }
    $n = $n.Trim()
    if ([string]::IsNullOrWhiteSpace($n)) { return '' }
    $bad = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($ch in @($bad)) {
      try { $n = $n.Replace([string]$ch, '_') } catch {}
    }
    $n = $n.Trim(' ','.','_')
    return $n
  } catch { return '' }
}

function Get-PrimaryCategoryNameForSave {
  try {
    $checked = @(Get-CheckedCategories)
    if (@($checked).Count -gt 0) {
      return [string]$checked[0]
    }
  } catch {}
  try {
    if ($categoryList -and $categoryList.SelectedItem) {
      $n = [string]$categoryList.SelectedItem.Name
      if (-not [string]::IsNullOrWhiteSpace($n)) { return $n }
    }
  } catch {}
  return ''
}

try { Show-StartupSplash -Status "Initializing..." } catch {}
try { Set-StartupSplashStatus -Status "Building main window..." -Value 12 } catch {}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Icon Allocator (v1.77)"
        Width="1245" Height="832"
        MinWidth="800" MinHeight="600"
        Background="#a8a8a8"
        WindowStyle="None"
        ResizeMode="CanResize"
        WindowStartupLocation="CenterScreen">
  <shell:WindowChrome.WindowChrome>
    <shell:WindowChrome CaptionHeight="0"
                        ResizeBorderThickness="6"
                        CornerRadius="0"
                        GlassFrameThickness="0"
                        UseAeroCaptionButtons="False"/>
  </shell:WindowChrome.WindowChrome>
  <Window.Resources>
    <SolidColorBrush x:Key="AppBgBrush" Color="#E1E1E1"/>
    <SolidColorBrush x:Key="UiTopSeparatorBrush" Color="#C8C8C8"/>
    <SolidColorBrush x:Key="UiTextBrush" Color="#2E2E2E"/>
    <SolidColorBrush x:Key="UiTabIdleBrush" Color="#D8D8D8"/>
    <SolidColorBrush x:Key="UiTabActiveBrush" Color="#ECECEC"/>
    <SolidColorBrush x:Key="UiBorderBrush" Color="#BDBDBD"/>
    <SolidColorBrush x:Key="UiTitleBarBrush" Color="#E1E1E1"/>
    <SolidColorBrush x:Key="UiTitleBarTextBrush" Color="#202020"/>
    <SolidColorBrush x:Key="UiTitleBarButtonHoverBrush" Color="#5A5A5A"/>
    <SolidColorBrush x:Key="UiTitleBarButtonPressedBrush" Color="#474747"/>
    <Style x:Key="AppTitleBarButtonStyle" TargetType="{x:Type Button}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="{DynamicResource UiTitleBarTextBrush}"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="0"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Button}">
            <Border x:Name="TitleBtnBorder"
                    Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}">
              <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
                                RecognizesAccessKey="True"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="TitleBtnBorder" Property="Background" Value="{DynamicResource UiTitleBarButtonHoverBrush}"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="TitleBtnBorder" Property="Background" Value="{DynamicResource UiTitleBarButtonPressedBrush}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="UiPanelTabItemStyle" TargetType="{x:Type TabItem}">
      <Setter Property="Foreground" Value="{StaticResource UiTextBrush}"/>
      <Setter Property="Background" Value="{StaticResource UiTabIdleBrush}"/>
      <Setter Property="BorderBrush" Value="{StaticResource UiBorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="12,3,12,3"/>
      <Setter Property="Margin" Value="0,0,0,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type TabItem}">
            <Border x:Name="TabHeaderBorder"
                    Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="4,4,0,0"
                    Padding="{TemplateBinding Padding}"
                    SnapsToDevicePixels="True">
              <ContentPresenter ContentSource="Header"
                                RecognizesAccessKey="True"
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"
                                Margin="2,0,2,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="TabHeaderBorder" Property="Background" Value="{StaticResource UiTabActiveBrush}"/>
                <Setter Property="Foreground" Value="{StaticResource UiTextBrush}"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
                <Setter Property="Panel.ZIndex" Value="5"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="False">
                <Setter TargetName="TabHeaderBorder" Property="Background" Value="{StaticResource UiTabIdleBrush}"/>
                <Setter Property="FontWeight" Value="Normal"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="TopUiActionLabelStyle" TargetType="{x:Type TextBlock}">
      <Setter Property="TextAlignment" Value="Center"/>
      <Setter Property="TextWrapping" Value="NoWrap"/>
      <Setter Property="LineStackingStrategy" Value="BlockLineHeight"/>
      <Setter Property="LineHeight" Value="10"/>
      <Setter Property="FontSize" Value="10"/>
      <Setter Property="Margin" Value="0"/>
    </Style>
    <Style x:Key="TopUiFlatButtonStyle" TargetType="{x:Type Button}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="2,1,2,1"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Button}">
            <Border x:Name="TopUiBtnBorder"
                    Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    SnapsToDevicePixels="True">
              <ContentPresenter Margin="{TemplateBinding Padding}"
                                HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
                                RecognizesAccessKey="True"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="TopUiBtnBorder" Property="Background" Value="#FFC2C2C2"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="TopUiBtnBorder" Property="Background" Value="#FFB0B0B0"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.6"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="{x:Type GroupBox}">
      <Setter Property="Background" Value="{StaticResource AppBgBrush}"/>
    </Style>
    <Style TargetType="{x:Type ListBox}">
      <Setter Property="Background" Value="{StaticResource AppBgBrush}"/>
    </Style>
    <Style TargetType="{x:Type TextBox}">
      <Setter Property="Background" Value="{StaticResource AppBgBrush}"/>
    </Style>
    <Style TargetType="{x:Type Button}">
      <Setter Property="Background" Value="{StaticResource AppBgBrush}"/>
    </Style>
    <Style TargetType="{x:Type CheckBox}">
      <Setter Property="Background" Value="{StaticResource AppBgBrush}"/>
    </Style>
    <Style TargetType="{x:Type Border}">
      <Setter Property="Background" Value="{StaticResource AppBgBrush}"/>
    </Style>
  </Window.Resources>
  <Border Name="AppWindowFrame" Margin="0" BorderBrush="#D3D3D3" BorderThickness="1" Background="#E1E1E1" SnapsToDevicePixels="True">
  <Grid Name="RootGrid" Margin="0" Background="#E1E1E1">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Name="LeftPanelColumn" Width="274" MinWidth="180"/>
      <ColumnDefinition Name="LeftSplitterColumn" Width="6"/>
      <ColumnDefinition Name="CenterPanelColumn" Width="*"/>
      <ColumnDefinition Name="RightSplitterColumn" Width="10"/>
      <ColumnDefinition Name="RightPanelColumn" Width="280" MinWidth="220"/>
    </Grid.ColumnDefinitions>

    <Border Name="AppTitleBar"
            Grid.Row="0"
            Grid.ColumnSpan="5"
            Height="30"
            VerticalAlignment="Top"
            Background="{DynamicResource UiTitleBarBrush}"
            BorderBrush="Transparent"
            BorderThickness="0"
            Panel.ZIndex="120">
      <Grid Name="AppTitleBarLayoutGrid">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="46"/>
          <ColumnDefinition Width="46"/>
          <ColumnDefinition Width="46"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="10,0,0,0">
          <Image Name="AppTitleBarIcon" Width="16" Height="16" Margin="0,0,8,0" Stretch="Uniform"/>
          <TextBlock Name="AppTitleBarText"
                     Text="Icon Allocator (v1.77)"
                     VerticalAlignment="Center"
                     Foreground="{DynamicResource UiTitleBarTextBrush}"
                     FontSize="12"
                     FontWeight="SemiBold"/>
        </StackPanel>
        <Button Name="AppMinBtn" Grid.Column="1" Style="{StaticResource AppTitleBarButtonStyle}">
          <TextBlock Name="AppMinGlyphText" Text="&#x2796;" Foreground="{DynamicResource UiTitleBarTextBrush}" FontFamily="Segoe UI Symbol" FontSize="14"/>
        </Button>
        <Button Name="AppMaxBtn" Grid.Column="2" Style="{StaticResource AppTitleBarButtonStyle}">
          <TextBlock Name="AppMaxGlyphText" Text="&#x2610;" Foreground="{DynamicResource UiTitleBarTextBrush}" FontFamily="Segoe UI Symbol" FontSize="14"/>
        </Button>
        <Button Name="AppCloseBtn" Grid.Column="3" Style="{StaticResource AppTitleBarButtonStyle}">
          <TextBlock Name="AppCloseGlyphText" Text="&#x274C;" Foreground="{DynamicResource UiTitleBarTextBrush}" FontFamily="Segoe UI Symbol" FontSize="14"/>
        </Button>
      </Grid>
    </Border>

    <Grid Grid.Row="0" Grid.ColumnSpan="5" Margin="0,30,0,8">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Top">
        <Button Name="ExportJsonBtn" Width="Auto" MinWidth="45" Height="64" Margin="5,0,6,0" Style="{StaticResource TopUiFlatButtonStyle}">Save category</Button>
        <Button Name="LoadJsonBtn" Width="Auto" MinWidth="45" Height="64" Margin="-5,0,10,0" Style="{StaticResource TopUiFlatButtonStyle}">Load category</Button>
        <Border Name="TopUiSep1" Width="1" Height="74" Background="{DynamicResource UiTopSeparatorBrush}" Margin="0,0,8,0" VerticalAlignment="Center" Panel.ZIndex="50" SnapsToDevicePixels="True"/>
        <Button Name="DeleteSelectedCategoryBtn" Width="Auto" MinWidth="45" Height="64" Margin="5,0,10,0" Style="{StaticResource TopUiFlatButtonStyle}">Delete Selected Catgory</Button>
        <Border Name="TopUiSep2" Width="1" Height="74" Background="{DynamicResource UiTopSeparatorBrush}" Margin="0,0,8,0" VerticalAlignment="Center" Panel.ZIndex="50" SnapsToDevicePixels="True"/>
        <Button Name="BackupIconPackDirBtn" Width="Auto" MinWidth="45" Height="64" Margin="5,0,6,0" Style="{StaticResource TopUiFlatButtonStyle}">Backup Icon Pack Directory</Button>
        <Border Name="TopUiSep2B" Width="1" Height="74" Background="{DynamicResource UiTopSeparatorBrush}" Margin="0,0,8,0" VerticalAlignment="Center" Panel.ZIndex="50" SnapsToDevicePixels="True"/>
        <Button Name="RefreshExternalBtn" Width="Auto" MinWidth="45" Height="64" Margin="-5,0,10,0" Style="{StaticResource TopUiFlatButtonStyle}">Refresh</Button>
        <Button Name="ClearSelectionBtn" Width="Auto" MinWidth="45" Height="64" Margin="-5,0,10,0" Style="{StaticResource TopUiFlatButtonStyle}">Clear Selection</Button>
        <Border Name="TopUiSep2C" Width="1" Height="74" Background="{DynamicResource UiTopSeparatorBrush}" Margin="0,0,8,0" VerticalAlignment="Center" Panel.ZIndex="50" SnapsToDevicePixels="True"/>
      </StackPanel>
      <Grid Grid.Column="3" Margin="10,-10,10,0" Width="0" MinWidth="0" MaxWidth="0" Height="70" MinHeight="70" MaxHeight="70" ClipToBounds="True" HorizontalAlignment="Left" Visibility="Collapsed">
        <Border Name="StatusMarqueeHost"
                BorderThickness="1"
                BorderBrush="#e1e1e1"
                Background="#e1e1e1"
                CornerRadius="2"/>
        <TextBlock Name="StatusMarqueeText"
                   Margin="4,4,4,4"
                   HorizontalAlignment="Stretch"
                   TextAlignment="Right"
                   VerticalAlignment="Top"
                   FontSize="9"
                   Foreground="#606060"
                   TextWrapping="Wrap"
                   TextTrimming="None">
          <TextBlock.RenderTransform>
            <TranslateTransform X="0"/>
          </TextBlock.RenderTransform>
        </TextBlock>
        <TextBox Name="StatusText"
                 Visibility="Collapsed"
                 IsReadOnly="True"
                 BorderThickness="0"
                 Background="Transparent"/>
      </Grid>
      <Border Name="TopUiSep3" Grid.Column="1" Width="1" Height="74" Background="{DynamicResource UiTopSeparatorBrush}" VerticalAlignment="Center" HorizontalAlignment="Left" Margin="0,0,8,0" Panel.ZIndex="50" SnapsToDevicePixels="True" Visibility="Collapsed"/>
      <StackPanel Grid.Column="1" Orientation="Vertical" VerticalAlignment="Top" Margin="10,0,0,0">
        <CheckBox Name="ExtractIconsModeBox" Content="Select icons to extract" VerticalAlignment="Center" Margin="0,4,0,4" FontSize="13"/>
        <Button Name="ExtractIconsBtn" Width="55" Height="50" Margin="0,-5,0,-5" IsEnabled="False" Style="{StaticResource TopUiFlatButtonStyle}">Extract</Button>
      </StackPanel>
      <Border Name="TopUiSep4" Grid.Column="2" Width="1" Height="74" Background="{DynamicResource UiTopSeparatorBrush}" VerticalAlignment="Center" HorizontalAlignment="Left" Margin="14,0,8,0" Panel.ZIndex="50" SnapsToDevicePixels="True"/>
    </Grid>

    <Border Name="MainPanelsCrossSeparator"
            Grid.Row="0"
            Grid.RowSpan="3"
            Grid.ColumnSpan="5"
            Height="1"
            Margin="0,137,0,0"
            VerticalAlignment="Top"
            Background="#70727272"
            IsHitTestVisible="False"
            Panel.ZIndex="12"/>

    <GroupBox Grid.Row="2" Grid.Column="0" Margin="0,9,0,0" BorderThickness="0" BorderBrush="Transparent" Panel.ZIndex="4">
      <GroupBox.Header>
        <TextBlock Text="Manage categories" Margin="0,-5,0,0"/>
      </GroupBox.Header>
      <Grid Margin="6">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Margin="0,0,0,6">
          <TextBlock Text="New Category:" VerticalAlignment="Center" Margin="0,5,0,3" FontSize="11"/>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="6"/>
              <ColumnDefinition Width="66"/>
            </Grid.ColumnDefinitions>
            <TextBox Grid.Column="0" Name="CategoryNameBox" Height="24" Margin="0,0,0,0"/>
            <Button Grid.Column="2" Name="CreateCategoryBtn" Width="50" Height="24" Margin="-10,0,-15,0">Create</Button>
          </Grid>
        </StackPanel>
        <Grid Grid.Row="1" Margin="0,0,0,4">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="30"/>
            <ColumnDefinition Width="30"/>
            <ColumnDefinition Width="30"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <CheckBox Grid.Row="0"
                    Grid.Column="0"
                    Name="ToggleAllSelectBox"
                    Width="17"
                    Height="17"
                    Margin="0,0,0,1"
                    HorizontalAlignment="Center"
                    VerticalAlignment="Center"
                    IsChecked="False"/>
          <CheckBox Grid.Row="0"
                    Grid.Column="1"
                    Name="ToggleAllCategoriesBox"
                    Width="17"
                    Height="17"
                    Margin="0,0,0,1"
                    HorizontalAlignment="Center"
                    VerticalAlignment="Center"
                    IsChecked="False"/>
          <CheckBox Grid.Row="0"
                    Grid.Column="2"
                    Name="ToggleAllMaskBox"
                    Width="17"
                    Height="17"
                    Margin="0,0,0,1"
                    HorizontalAlignment="Center"
                    VerticalAlignment="Center"
                    IsChecked="False"/>
          <StackPanel Grid.Row="0"
                      Grid.Column="3"
                      Orientation="Horizontal"
                      Margin="20,1,0,2"
                      HorizontalAlignment="Left"
                      VerticalAlignment="Center">
            <CheckBox Name="UnmaskSharedIconsBox"
                      Width="11"
                      Height="11"
                      Margin="0,-1,0,0"
                      VerticalAlignment="Center"
                      IsChecked="True"
                      Foreground="#424242">
              <CheckBox.Template>
                <ControlTemplate TargetType="CheckBox">
                  <Grid Width="{TemplateBinding Width}" Height="{TemplateBinding Height}" Background="Transparent">
                    <Ellipse x:Name="TinyRing"
                             Stroke="#283fc0"
                             StrokeThickness="1"
                             Fill="#00000000"/>
                    <Ellipse x:Name="TinyDot"
                             Width="4"
                             Height="4"
                             Fill="#494949"
                             HorizontalAlignment="Center"
                             VerticalAlignment="Center"
                             Visibility="Collapsed"/>
                  </Grid>
                  <ControlTemplate.Triggers>
                    <Trigger Property="IsChecked" Value="True">
                      <Setter TargetName="TinyDot" Property="Visibility" Value="Visible"/>
                    </Trigger>
                    <Trigger Property="IsEnabled" Value="False">
                      <Setter TargetName="TinyRing" Property="Opacity" Value="0.45"/>
                      <Setter TargetName="TinyDot" Property="Opacity" Value="0.45"/>
                    </Trigger>
                  </ControlTemplate.Triggers>
                </ControlTemplate>
              </CheckBox.Template>
            </CheckBox>
            <TextBlock Text="Un-Mask shared icons"
                       FontSize="9"
                       Foreground="#8700b1"
                       VerticalAlignment="Center"
                       Margin="3,0,0,0"/>
          </StackPanel>
          <TextBlock Grid.Row="1" Grid.Column="0" Text="Select" FontSize="9" HorizontalAlignment="Center" VerticalAlignment="Center" Width="23" Foreground="#018f41"/>
          <TextBlock Grid.Row="1" Grid.Column="1" Text="Show" FontSize="9" HorizontalAlignment="Center" VerticalAlignment="Center" Width="23" Foreground="#0051ff"/>
          <TextBlock Grid.Row="1" Grid.Column="2" Text="Mask" FontSize="9" HorizontalAlignment="Center" VerticalAlignment="Center" Width="23" Foreground="#ac1818"/>
          <TextBlock Grid.Row="1" Grid.Column="3" Text="Categories" FontSize="10" VerticalAlignment="Center" Margin="55,0,0,-17" Foreground="#666666"/>
        </Grid>
        <ListBox Grid.Row="2" Margin="0,5,0,0" Name="CategoryList" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled" ScrollViewer.VerticalScrollBarVisibility="Auto"/>
      </Grid>
    </GroupBox>

    <GridSplitter Grid.Row="2" Grid.Column="1"
                  Width="6"
                  HorizontalAlignment="Stretch"
                  VerticalAlignment="Stretch"
                  ResizeBehavior="PreviousAndNext"
                  ResizeDirection="Columns"
                  ShowsPreview="False"
                  Background="Transparent"/>

    <GroupBox Grid.Row="2" Grid.Column="2" Margin="0,-7,10,20" BorderThickness="0" BorderBrush="Transparent" Background="{StaticResource AppBgBrush}" Panel.ZIndex="20">
      <GroupBox.Effect>
        <DropShadowEffect Color="#7A000000" BlurRadius="14" ShadowDepth="1" Opacity="0.30"/>
      </GroupBox.Effect>
      <Grid Margin="6">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Grid Grid.Row="0" Margin="0,0,0,6">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <StackPanel Grid.Row="0" Grid.Column="0" Orientation="Horizontal" HorizontalAlignment="Left">
            <Button Name="IconUndoBtn" Width="0" Height="0" Margin="0,0,0,0" Visibility="Collapsed">Undo</Button>
            <Button Name="IconRedoBtn" Width="0" Height="0" Margin="0,0,0,0" Visibility="Collapsed">Redo</Button>
            <TextBlock Text="icons/page:" VerticalAlignment="Center" Margin="5,0,6,0"/>
            <ComboBox Name="IconPageSizeBox" Width="55" Height="24" SelectedIndex="2">
              <ComboBoxItem Content="200"/>
              <ComboBoxItem Content="400"/>
              <ComboBoxItem Content="600"/>
              <ComboBoxItem Content="800"/>
              <ComboBoxItem Content="1000"/>
              <ComboBoxItem Content="1500"/>
              <ComboBoxItem Content="2000"/>
            </ComboBox>
          </StackPanel>

          <StackPanel Grid.Row="1" Grid.Column="0" Orientation="Horizontal" HorizontalAlignment="Left" Margin="0,6,0,0">
            <CheckBox Name="ShowAllIconsBox" Content="Show all" IsChecked="True" VerticalAlignment="Center" Margin="0,0,10,0"/>
            <CheckBox Name="HidePixelDuplicatesBox" Content="Hide duplicates" IsChecked="True" VerticalAlignment="Center" Margin="0,0,10,0"/>
            <CheckBox Name="ShowUncategorizedBox" Content="Uncategorized only" IsChecked="False" VerticalAlignment="Center" Margin="0,0,0,0"/>
          </StackPanel>

          <StackPanel Grid.Row="0" Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right">
            <TextBlock Text="Search icon by name:" VerticalAlignment="Center" Margin="0,0,6,0"/>
            <TextBox Name="IconSearchBox" Width="160" Height="24"/>
          </StackPanel>

          <Grid Grid.Row="1" Grid.Column="1" Margin="0,6,0,0">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Name="IconCountText" Grid.Column="0" VerticalAlignment="Center" HorizontalAlignment="Right" Margin="0,0,8,0"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right">
              <Button Name="IconPrevPageBtn" Width="54" Height="24" Margin="0,0,6,0">Back</Button>
              <TextBlock Name="IconPageText" VerticalAlignment="Center" Margin="0,0,6,0"/>
              <Button Name="IconNextPageBtn" Width="54" Height="24">Next</Button>
            </StackPanel>
          </Grid>
        </Grid>
        <TextBlock Grid.Row="1"
                   Text="Select icons to assign them to a category, or to unbind them from one."
                   Margin="0,0,0,6"
                   Foreground="#666666"/>
        <ListBox Name="IconList"
                 Grid.Row="2"
                 SelectionMode="Extended"
                 BorderThickness="0"
                 ScrollViewer.CanContentScroll="False"
                 ScrollViewer.VerticalScrollBarVisibility="Auto"
                 ScrollViewer.HorizontalScrollBarVisibility="Disabled">
          <ListBox.ItemsPanel>
            <ItemsPanelTemplate>
              <WrapPanel IsItemsHost="True"/>
            </ItemsPanelTemplate>
          </ListBox.ItemsPanel>
          <ListBox.ItemContainerStyle>
            <Style TargetType="ListBoxItem">
              <Setter Property="Width" Value="50"/>
              <Setter Property="Height" Value="50"/>
              <Setter Property="Margin" Value="2"/>
              <Setter Property="Padding" Value="0"/>
              <Setter Property="HorizontalContentAlignment" Value="Center"/>
              <Setter Property="VerticalContentAlignment" Value="Center"/>
              <Setter Property="Background" Value="Transparent"/>
              <Setter Property="BorderBrush" Value="Transparent"/>
              <Setter Property="BorderThickness" Value="0"/>
              <Setter Property="ToolTip" Value="{Binding Label}"/>
              <Setter Property="Template">
                <Setter.Value>
                  <ControlTemplate TargetType="ListBoxItem">
                    <Border x:Name="TileBorder"
                            Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="3"
                            Padding="{TemplateBinding Padding}"
                            SnapsToDevicePixels="True">
                      <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                        VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
                                        SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}"/>
                    </Border>
                  </ControlTemplate>
                </Setter.Value>
              </Setter>
              <Style.Triggers>
                <MultiDataTrigger>
                  <MultiDataTrigger.Conditions>
                    <Condition Binding="{Binding IsAssignedActive}" Value="True"/>
                    <Condition Binding="{Binding IsPendingExport}" Value="False"/>
                  </MultiDataTrigger.Conditions>
                  <Setter Property="Background" Value="#b6b5b5"/>
                </MultiDataTrigger>
                <DataTrigger Binding="{Binding IsCategorized}" Value="True">
                  <Setter Property="BorderBrush" Value="#7a7a7a"/>
                  <Setter Property="BorderThickness" Value="1"/>
                </DataTrigger>
                <DataTrigger Binding="{Binding IsPendingExport}" Value="True">
                  <Setter Property="BorderBrush" Value="#3a46e4"/>
                  <Setter Property="BorderThickness" Value="3"/>
                  <Setter Property="Background" Value="Transparent"/>
                </DataTrigger>
                <MultiDataTrigger>
                  <MultiDataTrigger.Conditions>
                    <Condition Binding="{Binding RelativeSource={RelativeSource Self}, Path=IsSelected}" Value="True"/>
                    <Condition Binding="{Binding HasSelectTargets}" Value="False"/>
                  </MultiDataTrigger.Conditions>
                  <Setter Property="BorderBrush" Value="#b4b2b2"/>
                  <Setter Property="BorderThickness" Value="2"/>
                  <Setter Property="Background" Value="Transparent"/>
                </MultiDataTrigger>
                <MultiDataTrigger>
                  <MultiDataTrigger.Conditions>
                    <Condition Binding="{Binding RelativeSource={RelativeSource Self}, Path=IsSelected}" Value="True"/>
                    <Condition Binding="{Binding HasSelectTargets}" Value="True"/>
                  </MultiDataTrigger.Conditions>
                  <Setter Property="BorderBrush" Value="#3a46e4"/>
                  <Setter Property="BorderThickness" Value="3"/>
                  <Setter Property="Background" Value="Transparent"/>
                </MultiDataTrigger>
                <DataTrigger Binding="{Binding SelectDeltaKind}" Value="Remove">
                  <Setter Property="BorderBrush" Value="#d84a4a"/>
                  <Setter Property="BorderThickness" Value="3"/>
                  <Setter Property="Background" Value="Transparent"/>
                </DataTrigger>
                <DataTrigger Binding="{Binding IsExtractSelected}" Value="True">
                  <Setter Property="BorderBrush" Value="#ff8a00"/>
                  <Setter Property="BorderThickness" Value="3"/>
                  <Setter Property="Background" Value="Transparent"/>
                </DataTrigger>
              </Style.Triggers>
            </Style>
          </ListBox.ItemContainerStyle>
          <ListBox.ItemTemplate>
            <DataTemplate>
              <Grid HorizontalAlignment="Center" VerticalAlignment="Center">
                <Image Source="{Binding Icon}" Width="34" Height="34" Stretch="Uniform" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Grid>
            </DataTemplate>
          </ListBox.ItemTemplate>
        </ListBox>
      </Grid>
    </GroupBox>

    <GridSplitter Name="RightPanelSplitter"
                  Grid.Row="2"
                  Grid.Column="3"
                  Width="10"
                  HorizontalAlignment="Left"
                  VerticalAlignment="Stretch"
                  ResizeBehavior="PreviousAndNext"
                  ResizeDirection="Columns"
                  ShowsPreview="False"
                  Background="Transparent"/>
    <Button Name="RightPanelToggleBtn"
            Grid.Row="2"
            Grid.Column="3"
            Width="14"
            Height="25"
            HorizontalAlignment="Right"
            VerticalAlignment="Center"
            HorizontalContentAlignment="Stretch"
            VerticalContentAlignment="Center"
            Padding="0"
            BorderThickness="0"
            ToolTip="Hide right panel"
            Background="#E1E1E1"
            Panel.ZIndex="5"/>

    <TabControl Name="RightPanelGroup" Grid.Row="2" Grid.Column="4" Margin="0,0,0,0" Background="{StaticResource AppBgBrush}" BorderBrush="{StaticResource AppBgBrush}" BorderThickness="0" Padding="0" ItemContainerStyle="{StaticResource UiPanelTabItemStyle}" SelectedIndex="0" Panel.ZIndex="4">
      <TabItem Header="Icon pack directory" Style="{StaticResource UiPanelTabItemStyle}">
        <Grid Margin="6" Background="{StaticResource AppBgBrush}">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <TextBlock Grid.Row="0" Text="Search for icon source path:" VerticalAlignment="Center" Margin="0,0,0,4"/>
          <Grid Grid.Row="1" Margin="0,0,0,6">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="6"/>
              <ColumnDefinition Width="60"/>
            </Grid.ColumnDefinitions>
            <TextBox Grid.Column="0" Name="CustomSourceDirBox" Height="24"/>
            <Button Grid.Column="2" Name="BrowseSourceDirBtn" Width="50" Height="24">Browse</Button>
          </Grid>
          <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Left" Margin="0,0,0,6">
            <Button Name="AddSourceDirBtn" Width="45" Height="24" Margin="0,0,7,0">Add</Button>
            <Button Name="RemoveSourceDirBtn" Width="45" Height="24" Margin="7,0,0,0">Del</Button>
            <TextBlock Text="(shift+mouse for bulk path select)" FontSize="9" Margin="10,5,0,0" VerticalAlignment="Center" Foreground="#747474"/>
          </StackPanel>
          <StackPanel Grid.Row="3" Orientation="Vertical" HorizontalAlignment="Left" Margin="9,10,0,0">
            <CheckBox Name="ToggleAllSourcePathsBox" IsChecked="True" Style="{DynamicResource UiCheckBoxStyle}" HorizontalAlignment="Left"/>
            <TextBlock Text="Show/Hide" FontSize="10" Margin="-15,2,0,0" Foreground="#747474"/>
          </StackPanel>
          <Border Grid.Row="4" Height="1" Background="#BDBDBD" Margin="0,4,0,6" VerticalAlignment="Center"/>
          <ListBox Grid.Row="5" Name="IconSourceDirList" BorderThickness="0" SelectionMode="Extended" Background="{StaticResource AppBgBrush}" VirtualizingPanel.IsVirtualizing="True" VirtualizingPanel.VirtualizationMode="Recycling" ScrollViewer.CanContentScroll="True" ScrollViewer.IsDeferredScrollingEnabled="True" ScrollViewer.HorizontalScrollBarVisibility="Disabled" ScrollViewer.VerticalScrollBarVisibility="Auto">
            <ListBox.Resources>
              <Style x:Key="SourcePathColumnCheckStyle" TargetType="{x:Type CheckBox}">
                <Setter Property="Width" Value="22"/>
                <Setter Property="Height" Value="22"/>
                <Setter Property="Margin" Value="0"/>
                <Setter Property="HorizontalAlignment" Value="Center"/>
                <Setter Property="VerticalAlignment" Value="Center"/>
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="BorderBrush" Value="#7A7A7A"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="Template">
                  <Setter.Value>
                    <ControlTemplate TargetType="{x:Type CheckBox}">
                      <Grid Width="{TemplateBinding Width}" Height="{TemplateBinding Height}" Background="Transparent">
                        <Border x:Name="box"
                                Width="18"
                                Height="18"
                                CornerRadius="2"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                Background="Transparent"
                                HorizontalAlignment="Center"
                                VerticalAlignment="Center"/>
                        <Path x:Name="mark"
                              Data="M 2,8 L 6,12 L 14,4"
                              Width="16"
                              Height="16"
                              Stretch="Uniform"
                              Stroke="#2F2F2F"
                              StrokeThickness="2"
                              StrokeStartLineCap="Square"
                              StrokeEndLineCap="Square"
                              StrokeLineJoin="Miter"
                              HorizontalAlignment="Center"
                              VerticalAlignment="Center"
                              SnapsToDevicePixels="True"
                              Visibility="Collapsed"/>
                      </Grid>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsChecked" Value="True">
                          <Setter TargetName="box" Property="Background" Value="#DADADA"/>
                          <Setter TargetName="box" Property="BorderBrush" Value="#666666"/>
                          <Setter TargetName="mark" Property="Visibility" Value="Visible"/>
                        </Trigger>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter TargetName="box" Property="BorderBrush" Value="#595959"/>
                        </Trigger>
                        <Trigger Property="IsEnabled" Value="False">
                          <Setter TargetName="box" Property="Opacity" Value="0.55"/>
                          <Setter TargetName="mark" Property="Opacity" Value="0.55"/>
                        </Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Setter.Value>
                </Setter>
              </Style>
            </ListBox.Resources>
            <ListBox.ItemTemplate>
              <DataTemplate>
                <Grid Margin="0,0,0,2">
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                  </Grid.ColumnDefinitions>
                  <CheckBox Grid.Column="0"
                            IsChecked="{Binding ShowChecked, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}"
                            VerticalAlignment="Center"
                            Margin="0,0,6,0"
                            Style="{StaticResource SourcePathColumnCheckStyle}"/>
                  <TextBlock Grid.Column="1"
                             Text="{Binding Path}"
                             VerticalAlignment="Center"
                             TextTrimming="CharacterEllipsis"/>
                </Grid>
              </DataTemplate>
            </ListBox.ItemTemplate>
          </ListBox>
        </Grid>
      </TabItem>
      <TabItem Header="Categorised icons" Style="{StaticResource UiPanelTabItemStyle}">
        <Grid Margin="6" Background="{StaticResource AppBgBrush}">
          <ListBox Name="SelectedNamesList" BorderThickness="0" Background="{StaticResource AppBgBrush}" ScrollViewer.HorizontalScrollBarVisibility="Disabled" ScrollViewer.VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>
    </TabControl>
    <Border Name="ExtractLeftOverlay"
            Grid.Row="2"
            Grid.Column="0"
            Background="#85e0e0e0"
            Visibility="Collapsed"
            IsHitTestVisible="False"
            Panel.ZIndex="200"/>
    <Border Name="ExtractRightOverlay"
            Grid.Row="2"
            Grid.Column="4"
            Background="#85e0e0e0"
            Visibility="Collapsed"
            IsHitTestVisible="False"
            Panel.ZIndex="200"/>
  </Grid>
  </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
try { Set-StartupSplashStatus -Status "Loading window XAML..." -Value 24 } catch {}
$window = [Windows.Markup.XamlReader]::Load($reader)
try { Set-StartupSplashStatus -Status "Initializing controls..." -Value 34 } catch {}
try {
  $window.Add_SourceInitialized({
    try { Enable-SoftWindowShadow -Window $window } catch {}
    try { Update-WindowShadowByState -Window $window } catch {}
  })
} catch {}
try {
  $window.Add_Closing({
    try {
      if (-not [bool]$script:StartupMainReady) {
        $script:StartupMainCloseRequested = $true
      }
    } catch {}
    try {
      foreach ($r in @($iconSourceDirList.ItemsSource)) {
        if (-not $r) { continue }
        $rp = ''
        $rv = $true
        try { $rp = [string]$r.Path } catch { $rp = '' }
        try { $rv = [bool]$r.ShowChecked } catch { $rv = $true }
        if ([string]::IsNullOrWhiteSpace($rp)) { continue }
        try { Set-SourcePathVisibility -Path $rp -Visible:$rv } catch {}
      }
    } catch {}
    try { Save-CategoryPanelState } catch {}
    try { Save-CustomIconSourceDirectories | Out-Null } catch {}
    try { Close-StartupSplash } catch {}
  })
} catch {}
try {
  $titleIconPath = [Environment]::ExpandEnvironmentVariables('%systemroot%\\system32\\wmploc.dll')
  $titleIcon = Get-IconImageSource -IconPath $titleIconPath -IconIndex 156
  if ($titleIcon) { $window.Icon = $titleIcon }
} catch {}

$rootGrid = $window.FindName('RootGrid')
$leftPanelColumn = $window.FindName('LeftPanelColumn')
$leftSplitterColumn = $window.FindName('LeftSplitterColumn')
$rightPanelColumn = $window.FindName('RightPanelColumn')
$rightSplitterColumn = $window.FindName('RightSplitterColumn')
$categoryNameBox = $window.FindName('CategoryNameBox')
$createCategoryBtn = $window.FindName('CreateCategoryBtn')
$loadJsonBtn = $window.FindName('LoadJsonBtn')
$exportJsonBtn = $window.FindName('ExportJsonBtn')
$deleteSelectedCategoryBtn = $window.FindName('DeleteSelectedCategoryBtn')
$backupIconPackDirBtn = $window.FindName('BackupIconPackDirBtn')
$refreshExternalBtn = $window.FindName('RefreshExternalBtn')
$clearSelectionBtn = $window.FindName('ClearSelectionBtn')
$extractIconsModeBox = $window.FindName('ExtractIconsModeBox')
$extractIconsBtn = $window.FindName('ExtractIconsBtn')
$toggleAllSelectBox = $window.FindName('ToggleAllSelectBox')
$toggleAllCategoriesBox = $window.FindName('ToggleAllCategoriesBox')
$toggleAllMaskBox = $window.FindName('ToggleAllMaskBox')
$unmaskSharedIconsBox = $window.FindName('UnmaskSharedIconsBox')
$statusText = $window.FindName('StatusText')
$extractLeftOverlay = $window.FindName('ExtractLeftOverlay')
$extractRightOverlay = $window.FindName('ExtractRightOverlay')
$customSourceDirBox = $window.FindName('CustomSourceDirBox')
$browseSourceDirBtn = $window.FindName('BrowseSourceDirBtn')
$addSourceDirBtn = $window.FindName('AddSourceDirBtn')
$removeSourceDirBtn = $window.FindName('RemoveSourceDirBtn')
$toggleAllSourcePathsBox = $window.FindName('ToggleAllSourcePathsBox')
$iconSourceDirList = $window.FindName('IconSourceDirList')
$categoryList = $window.FindName('CategoryList')
$iconPageSizeBox = $window.FindName('IconPageSizeBox')
$iconSearchBox = $window.FindName('IconSearchBox')
$showAllIconsBox = $window.FindName('ShowAllIconsBox')
$hidePixelDuplicatesBox = $window.FindName('HidePixelDuplicatesBox')
$showUncategorizedBox = $window.FindName('ShowUncategorizedBox')
$iconPrevPageBtn = $window.FindName('IconPrevPageBtn')
$iconNextPageBtn = $window.FindName('IconNextPageBtn')
$iconCountText = $window.FindName('IconCountText')
$iconPageText = $window.FindName('IconPageText')
$iconList = $window.FindName('IconList')
$rightPanelGroup = $window.FindName('RightPanelGroup')
$rightPanelSplitter = $window.FindName('RightPanelSplitter')
$rightPanelToggleBtn = $window.FindName('RightPanelToggleBtn')
$selectedNamesList = $window.FindName('SelectedNamesList')
$appTitleBar = $window.FindName('AppTitleBar')
$appTitleBarText = $window.FindName('AppTitleBarText')
$appTitleBarIcon = $window.FindName('AppTitleBarIcon')
$appMinBtn = $window.FindName('AppMinBtn')
$appMaxBtn = $window.FindName('AppMaxBtn')
$appCloseBtn = $window.FindName('AppCloseBtn')
$appMaxGlyphText = $window.FindName('AppMaxGlyphText')

$script:CategoryRows = New-Object System.Collections.Generic.List[object]
$script:AllIcons = New-Object System.Collections.Generic.List[object]
$script:IconsByKey = @{}
$script:AssignmentsByKey = @{}
$script:IconPageSize = 600
$script:IconCurrentPage = 1
$script:IconFilterCacheQuery = $null
$script:IconFilterCacheItems = @()
$script:IconSearchTextByKey = @{}
$script:IconSearchDebounceMs = 180.0
$script:IconSearchDebounceTimer = $null
$script:ShowAllIcons = $true
$script:HidePixelDuplicates = $true
$script:ShowUncategorizedOnly = $false
$script:UnmaskSharedIcons = $false
$script:IconPixelHashByKey = @{}
$script:SelectedNamesRefreshTimer = $null
$script:IconSelectionSyncTimer = $null
$script:SuppressCategoryCheckEvents = $false
$script:IconScrollTimer = $null
$script:CustomIconSourceDirs = New-Object System.Collections.Generic.List[string]
$script:BuiltInIconSourceDirs = New-Object System.Collections.Generic.List[string]
$script:BuiltInSourcesInitialized = $false
$script:IconSourceVisibilityByKey = @{}
$script:SuppressSourcePathUiEvents = $false
$script:RightPanelVisible = $true
$script:RightPanelLastWidth = 280.0
try {
  if ($rightPanelColumn) {
    $xamlWidth = 0.0
    try {
      if ($rightPanelColumn.Width.IsAbsolute) { $xamlWidth = [double]$rightPanelColumn.Width.Value }
    } catch {}
    if ($xamlWidth -gt 0.0) { $script:RightPanelLastWidth = $xamlWidth }
  }
} catch {}
$script:BaselineAssignmentSignaturesByKey = @{}
$script:ExtractIconsMode = $false
$script:ExtractSelectedKeys = @{}
$script:BaselineAssignmentCategoriesByKey = @{}
$script:IconRowOrdinal = 0
$script:CategoryAssignmentIndex = @{}
$script:CategoryAssignmentIndexDirty = $true
$script:AssignmentVersion = 0
$script:IconSourceDirectoriesFileSignature = ''
$script:CategoryProfilesSignature = ''
$script:IconCopyContextMenu = $null
$script:IconCopyContextName = ''
$script:IconCopyContextPath = ''
$script:SourcePathRefreshTimer = $null
$script:SourcePathRefreshPending = $false
$script:LastSourcePathRow = $null
$script:SourcePathTogglePickKeys = New-Object System.Collections.Generic.List[string]
$script:SessionHiddenSourcePathKeys = @{}
$script:CategoryPanelStateRows = @()
try { if ($showUncategorizedBox) { $script:ShowUncategorizedOnly = [bool]$showUncategorizedBox.IsChecked } } catch {}
try { if ($unmaskSharedIconsBox) { $script:UnmaskSharedIcons = [bool]$unmaskSharedIconsBox.IsChecked } } catch {}
try { if ($appTitleBarText -and $window) { $appTitleBarText.Text = [string]$window.Title } } catch {}
try { if ($appTitleBarIcon -and $window -and $window.Icon) { $appTitleBarIcon.Source = $window.Icon } } catch {}
if (-not (Test-Path variable:script:TitleBarDragPending)) { $script:TitleBarDragPending = $false }
if (-not (Test-Path variable:script:TitleBarDragStartXRatio)) { $script:TitleBarDragStartXRatio = 0.5 }

function Update-AllocatorTitleBarMaxGlyph {
  try {
    if (-not $appMaxGlyphText -or -not $window) { return }
    if ([System.Windows.WindowState]$window.WindowState -eq [System.Windows.WindowState]::Maximized) {
      $appMaxGlyphText.Text = [string][char]0x25F1
    } else {
      $appMaxGlyphText.Text = [string][char]0x2610
    }
  } catch {}
}

try {
  if ($appMinBtn -and $window) {
    $appMinBtn.Add_Click({ try { $window.WindowState = [System.Windows.WindowState]::Minimized } catch {} })
  }
  if ($appMaxBtn -and $window) {
    $appMaxBtn.Add_Click({
      try {
        if ([System.Windows.WindowState]$window.WindowState -eq [System.Windows.WindowState]::Maximized) {
          $window.WindowState = [System.Windows.WindowState]::Normal
        } else {
          $window.WindowState = [System.Windows.WindowState]::Maximized
        }
      } catch {}
      try { Update-AllocatorTitleBarMaxGlyph } catch {}
    })
  }
  if ($appCloseBtn -and $window) {
    $appCloseBtn.Add_Click({ try { $window.Close() } catch {} })
  }
  if ($appTitleBar -and $window) {
    $appTitleBar.Add_MouseLeftButtonDown({
      param($sender,$e)
      try {
        if ($e.ChangedButton -ne [System.Windows.Input.MouseButton]::Left) { return }
      } catch {}
      try {
        if ($e.ClickCount -ge 2) {
          if ([System.Windows.WindowState]$window.WindowState -eq [System.Windows.WindowState]::Maximized) {
            $window.WindowState = [System.Windows.WindowState]::Normal
          } else {
            $window.WindowState = [System.Windows.WindowState]::Maximized
          }
          try { $script:TitleBarDragPending = $false } catch {}
          try { Update-AllocatorTitleBarMaxGlyph } catch {}
          $e.Handled = $true
          return
        }
      } catch {}
      try {
        $script:TitleBarDragPending = $true
        $pos = $e.GetPosition($appTitleBar)
        $aw = [double]$appTitleBar.ActualWidth
        if ($aw -lt 1.0) { $aw = 1.0 }
        $ratio = [double]$pos.X / $aw
        if ($ratio -lt 0.0) { $ratio = 0.0 }
        if ($ratio -gt 1.0) { $ratio = 1.0 }
        $script:TitleBarDragStartXRatio = $ratio
        try { $appTitleBar.CaptureMouse() | Out-Null } catch {}
        $e.Handled = $true
      } catch {}
    })

    $appTitleBar.Add_MouseMove({
      param($sender,$e)
      try {
        if (-not [bool]$script:TitleBarDragPending) { return }
        if ($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed) { return }
      } catch { return }

      try { $script:TitleBarDragPending = $false } catch {}
      try { $appTitleBar.ReleaseMouseCapture() } catch {}

      try {
        if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
          $mp = [System.Windows.Forms.Control]::MousePosition
          $rb = $window.RestoreBounds
          $rw = 0.0
          try { $rw = [double]$rb.Width } catch { $rw = 0.0 }
          if ($rw -lt 300.0) { try { $rw = [double]$window.Width } catch { $rw = 900.0 } }
          if ($rw -lt 300.0) { $rw = 900.0 }
          $ratio = 0.5
          try { $ratio = [double]$script:TitleBarDragStartXRatio } catch { $ratio = 0.5 }
          if ($ratio -lt 0.0) { $ratio = 0.0 }
          if ($ratio -gt 1.0) { $ratio = 1.0 }
          $newLeft = [double]$mp.X - ($rw * $ratio)
          $newTop = [double]$mp.Y - 10.0
          if ($newTop -lt 0.0) { $newTop = 0.0 }
          $window.WindowState = [System.Windows.WindowState]::Normal
          $window.Left = $newLeft
          $window.Top = $newTop
          try { Update-AllocatorTitleBarMaxGlyph } catch {}
        }
      } catch {}

      try { $window.DragMove() } catch {}
    })

    $appTitleBar.Add_MouseLeftButtonUp({
      try { $script:TitleBarDragPending = $false } catch {}
      try { $appTitleBar.ReleaseMouseCapture() } catch {}
    })
  }
  if ($window) {
    $window.Add_StateChanged({
      try { Update-AllocatorTitleBarMaxGlyph } catch {}
      try { Update-WindowShadowByState -Window $window } catch {}
    })
  }
  try { Update-AllocatorTitleBarMaxGlyph } catch {}
} catch {}

try {
  if ($addSourceDirBtn) {
    $addSourceDirBtn.Background = (New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#88b688')))
    $addSourceDirBtn.Foreground = (New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#494949')))
    $addSourceDirBtn.BorderBrush = (New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#444444')))
  }
  if ($removeSourceDirBtn) {
    $removeSourceDirBtn.Background = (New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#c49292')))
    $removeSourceDirBtn.Foreground = (New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#494949')))
    $removeSourceDirBtn.BorderBrush = (New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString('#444444')))
  }
} catch {}

function Set-TopActionButtonVisual {
  param(
    [Parameter(Mandatory=$false)][System.Windows.Controls.Button]$Button,
    [Parameter(Mandatory=$false)][string]$Line1 = '',
    [Parameter(Mandatory=$false)][string]$Line2 = '',
    [Parameter(Mandatory=$false)][int]$IconIndex = 2,
    [Parameter(Mandatory=$false)][string]$IconPath = ''
  )
  try {
    if (-not $Button) { return }
    $iconPath = ''
    try { $iconPath = [string]$IconPath } catch { $iconPath = '' }
    if ([string]::IsNullOrWhiteSpace($iconPath)) {
      try { $iconPath = [Environment]::ExpandEnvironmentVariables('%systemroot%\\system32\\shell32.dll') } catch { $iconPath = '' }
    }
    try { $iconPath = [Environment]::ExpandEnvironmentVariables($iconPath) } catch {}
    $imgSrc = $null
    try { if (-not [string]::IsNullOrWhiteSpace($iconPath)) { $imgSrc = Get-IconImageSource -IconPath $iconPath -IconIndex $IconIndex } } catch { $imgSrc = $null }

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = [System.Windows.Controls.Orientation]::Vertical
    $sp.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $sp.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    if ($imgSrc) {
      $img = New-Object System.Windows.Controls.Image
      $img.Source = $imgSrc
      $img.Width = 30
      $img.Height = 30
      $img.Stretch = [System.Windows.Media.Stretch]::Uniform
      $img.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
      $img.Margin = '0,0,0,2'
      [void]$sp.Children.Add($img)
    }

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = ([string]$Line1 + [Environment]::NewLine + [string]$Line2)
    try {
      $topLabelStyle = $window.FindResource('TopUiActionLabelStyle')
      if ($topLabelStyle) { $tb.Style = $topLabelStyle }
    } catch {}
    $tb.TextAlignment = [System.Windows.TextAlignment]::Center
    $tb.TextWrapping = [System.Windows.TextWrapping]::NoWrap
    $tb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    [void]$sp.Children.Add($tb)

    $Button.Content = $sp
    try { $Button.BorderThickness = New-Object System.Windows.Thickness(0) } catch {}
    try { $Button.Padding = New-Object System.Windows.Thickness(2,1,2,1) } catch {}
    try { $Button.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center } catch {}
    try { $Button.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center } catch {}
    try { $Button.FocusVisualStyle = $null } catch {}
  } catch {}
}

function Set-TopSingleActionButtonVisual {
  param(
    [Parameter(Mandatory=$false)][System.Windows.Controls.Button]$Button,
    [Parameter(Mandatory=$false)][string]$Text = '',
    [Parameter(Mandatory=$false)][string]$IconPath = '',
    [Parameter(Mandatory=$false)][int]$IconIndex = 0
  )
  try {
    if (-not $Button) { return }
    $resolvedIconPath = ''
    try { $resolvedIconPath = [string]$IconPath } catch { $resolvedIconPath = '' }
    if ([string]::IsNullOrWhiteSpace($resolvedIconPath)) {
      try { $resolvedIconPath = [Environment]::ExpandEnvironmentVariables('%systemroot%\\system32\\shell32.dll') } catch { $resolvedIconPath = '' }
    }
    try { $resolvedIconPath = [Environment]::ExpandEnvironmentVariables($resolvedIconPath) } catch {}
    $imgSrc = $null
    try { if (-not [string]::IsNullOrWhiteSpace($resolvedIconPath)) { $imgSrc = Get-IconImageSource -IconPath $resolvedIconPath -IconIndex $IconIndex } } catch { $imgSrc = $null }

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = [System.Windows.Controls.Orientation]::Vertical
    $sp.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $sp.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    if ($imgSrc) {
      $img = New-Object System.Windows.Controls.Image
      $img.Source = $imgSrc
      $img.Width = 34
      $img.Height = 34
      $img.Stretch = [System.Windows.Media.Stretch]::Uniform
      $img.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
      $img.Margin = '0,-2,0,-5'
      [void]$sp.Children.Add($img)
    }

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = [string]$Text
    $tb.FontSize = 9
    $tb.TextAlignment = [System.Windows.TextAlignment]::Center
    $tb.TextWrapping = [System.Windows.TextWrapping]::NoWrap
    $tb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    [void]$sp.Children.Add($tb)

    $Button.Content = $sp
    try { $Button.BorderThickness = New-Object System.Windows.Thickness(0) } catch {}
    try { $Button.Padding = New-Object System.Windows.Thickness(2,1,2,1) } catch {}
    try { $Button.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center } catch {}
    try { $Button.VerticalContentAlignment = [System.Windows.VerticalAlignment]::Center } catch {}
    try { $Button.FocusVisualStyle = $null } catch {}
  } catch {}
}

try { Set-TopActionButtonVisual -Button $loadJsonBtn -Line1 'Load' -Line2 'Category' -IconIndex 68 } catch {}
try { Set-TopActionButtonVisual -Button $exportJsonBtn -Line1 'Save' -Line2 'Category' -IconIndex 295 } catch {}
try { Set-TopActionButtonVisual -Button $deleteSelectedCategoryBtn -Line1 'Delete Selected' -Line2 'Catgory' -IconIndex 152 } catch {}
try { Set-TopActionButtonVisual -Button $backupIconPackDirBtn -Line1 'Backup Icon' -Line2 'Pack Directory' -IconIndex 5 } catch {}
try { Set-TopActionButtonVisual -Button $refreshExternalBtn -Line1 'Refresh' -Line2 '' -IconIndex 238 } catch {}
try { Set-TopActionButtonVisual -Button $clearSelectionBtn -Line1 'Clear' -Line2 'Selection' -IconPath ([Environment]::ExpandEnvironmentVariables('%systemroot%\system32\shell32.dll')) -IconIndex 100 } catch {}
try { Set-TopSingleActionButtonVisual -Button $extractIconsBtn -Text 'Extract' -IconPath '%systemroot%\\system32\\imageres.dll' -IconIndex 288 } catch {}

function Invalidate-AssignmentDerivedCaches {
  param([switch]$BumpVersion)
  try { $script:CategoryAssignmentIndexDirty = $true } catch {}
  try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
  if ($BumpVersion) {
    try { $script:AssignmentVersion = [int]$script:AssignmentVersion + 1 } catch { $script:AssignmentVersion = 1 }
  }
}

function Get-NormalizedCategorySignature {
  param([string[]]$Categories)
  try {
    $vals = @(
      @($Categories) |
      ForEach-Object { try { ([string]$_).Trim().ToLowerInvariant() } catch { '' } } |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      Sort-Object -Unique
    )
    return ([string]($vals -join '|'))
  } catch { return '' }
}

function Get-IconSourceDirectoriesStatePath {
  try {
    $base = Split-Path -Parent $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($base)) { $base = (Get-Location).Path }
    $userSettings = Join-Path $base 'User Settings'
    if (-not (Test-Path -LiteralPath $userSettings -PathType Container)) {
      New-Item -ItemType Directory -Path $userSettings -Force | Out-Null
    }
    return (Join-Path $userSettings 'IconSourceDirectories.json')
  } catch { return '' }
}

function Get-CurrentCategoryPanelStateRows {
  $rows = New-Object System.Collections.Generic.List[object]
  try {
    foreach ($r in @($script:CategoryRows.ToArray())) {
      if (-not $r) { continue }
      $nm = ''
      $sel = $false
      $show = $false
      $mask = $false
      try { $nm = [string]$r.Name } catch { $nm = '' }
      $nm = $nm.Trim()
      if ([string]::IsNullOrWhiteSpace($nm)) { continue }
      try { $sel = [bool]$r.SelectChecked } catch { $sel = $false }
      try { $show = [bool]$r.ShowChecked } catch { $show = $false }
      try { $mask = [bool]$r.HideChecked } catch { $mask = $false }
      [void]$rows.Add([pscustomobject]@{
        Name = [string]$nm
        Select = [bool]$sel
        Show = [bool]$show
        Mask = [bool]$mask
      })
    }
  } catch {}
  return @($rows.ToArray())
}

function Save-CategoryPanelState {
  try {
    $script:CategoryPanelStateRows = @(Get-CurrentCategoryPanelStateRows)
  } catch {}
}

function Save-CategoryPanelStateToStateFile {
  try {
    $path = Get-IconSourceDirectoriesStatePath
    if ([string]::IsNullOrWhiteSpace($path)) {
      return [pscustomobject]@{ Ok = $false; Path = ''; Error = 'IconSourceDirectories path is unavailable.' }
    }
    $rows = @()
    try { $rows = @(Get-CurrentCategoryPanelStateRows) } catch { $rows = @() }

    $iconSources = @()
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      try {
        $obj = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($obj -and (-not ($obj -is [System.Array])) -and $obj.PSObject.Properties.Match('IconSources').Count -gt 0) {
          $iconSources = @($obj.IconSources)
        }
      } catch {}
    }

    $out = [pscustomobject]@{
      IconSources = @($iconSources)
      CategoryPanelState = [pscustomobject]@{
        Rows = @($rows)
      }
    }
    $json = $out | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $path -Value $json -Encoding UTF8
    return [pscustomobject]@{ Ok = $true; Path = [string]$path; Error = '' }
  } catch {
    return [pscustomobject]@{ Ok = $false; Path = ''; Error = [string]$_.Exception.Message }
  }
}

function Apply-SavedCategoryPanelState {
  try {
    $rows = @()
    try {
      if (@($script:CategoryPanelStateRows).Count -gt 0) {
        $rows = @($script:CategoryPanelStateRows)
      }
    } catch { $rows = @() }
    if (@($rows).Count -eq 0) {
      $path = Get-IconSourceDirectoriesStatePath
      if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
        try {
          $obj = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
          if ($obj -and $obj.PSObject.Properties.Match('CategoryPanelState').Count -gt 0) {
            $stateObj = $obj.CategoryPanelState
            if ($stateObj -is [System.Array]) { $rows = @($stateObj) }
            elseif ($stateObj -and $stateObj.PSObject.Properties.Match('Rows').Count -gt 0) { $rows = @($stateObj.Rows) }
          }
        } catch {}
      }
    }
    if (@($rows).Count -eq 0) { return }
    $map = @{}
    foreach ($it in @($rows)) {
      if (-not $it) { continue }
      $nm = ''
      try { $nm = [string]$it.Name } catch { $nm = '' }
      $nm = $nm.Trim().ToLowerInvariant()
      if ([string]::IsNullOrWhiteSpace($nm)) { continue }
      $map[$nm] = $it
    }
    if ($map.Count -eq 0) { return }
    foreach ($r in @($script:CategoryRows.ToArray())) {
      if (-not $r) { continue }
      $nm = ''
      try { $nm = [string]$r.Name } catch { $nm = '' }
      $nm = $nm.Trim().ToLowerInvariant()
      if ([string]::IsNullOrWhiteSpace($nm)) { continue }
      if (-not $map.ContainsKey($nm)) { continue }
      $src = $map[$nm]
      try { $r.SelectChecked = [bool]$src.Select } catch {}
      try { $r.ShowChecked = [bool]$src.Show } catch {}
      try { $r.HideChecked = [bool]$src.Mask } catch {}
      try { Enforce-CategoryRowExclusivity -Row $r -Prefer 'Show' } catch {}
    }
    try { Refresh-CategoryList } catch {}
    try { Update-ToggleAllSelectCheckState } catch {}
    try { Update-ToggleAllCategoriesCheckState } catch {}
    try { Update-ToggleAllMaskCheckState } catch {}
    try { Refresh-AssignedVisual -ForceRebind } catch { try { Refresh-AssignedVisual } catch {} }
  } catch {}
}

function Get-IconSourceDirectoriesLegacyBinStatePath {
  try {
    $root = Get-IconCategoryProfilesRoot
    if ([string]::IsNullOrWhiteSpace($root)) { return '' }
    return (Join-Path $root 'IconSourceDirectories.bin')
  } catch { return '' }
}

function Save-CustomIconSourceDirectories {
  try {
    $path = Get-IconSourceDirectoriesStatePath
    if ([string]::IsNullOrWhiteSpace($path)) {
      return [pscustomobject]@{ Ok = $false; Path = ''; Error = 'IconSourceDirectories path is unavailable.' }
    }
    $rows = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($d in @($script:CustomIconSourceDirs.ToArray())) {
      $disp = Normalize-SourcePathForDisplay ([string]$d)
      if ([string]::IsNullOrWhiteSpace($disp)) { continue }
      $k = Get-SourcePathKey $disp
      if ([string]::IsNullOrWhiteSpace($k)) { continue }
      if ($seen.ContainsKey($k)) { continue }
      $seen[$k] = $true
      [void]$rows.Add($disp)
    }
    $builtRows = New-Object System.Collections.Generic.List[string]
    $builtSeen = @{}
    foreach ($b in @(Get-EffectiveBuiltInSourceEntries)) {
      $dispB = Normalize-SourcePathForDisplay ([string]$b)
      if ([string]::IsNullOrWhiteSpace($dispB)) { continue }
      $kb = Get-SourcePathKey $dispB
      if ([string]::IsNullOrWhiteSpace($kb)) { continue }
      if ($builtSeen.ContainsKey($kb)) { continue }
      $builtSeen[$kb] = $true
      [void]$builtRows.Add($dispB)
    }
    $iconSourceRows = New-Object System.Collections.Generic.List[object]
    $sourceSeen = @{}
    foreach ($src in @($builtRows.ToArray())) {
      $dispSrc = Normalize-SourcePathForDisplay ([string]$src)
      if ([string]::IsNullOrWhiteSpace($dispSrc)) { continue }
      $keySrc = Get-SourcePathKey $dispSrc
      if ([string]::IsNullOrWhiteSpace($keySrc)) { continue }
      if ($sourceSeen.ContainsKey($keySrc)) { continue }
      $sourceSeen[$keySrc] = $true
      $show = $true
      try { $show = [bool](Get-SourcePathVisibility -Path $dispSrc) } catch { $show = $true }
      [void]$iconSourceRows.Add([pscustomobject]@{
        Path = [string]$dispSrc
        Kind = 'BuiltIn'
        Show = [bool]$show
      })
    }
    foreach ($src in @($rows.ToArray())) {
      $dispSrc = Normalize-SourcePathForDisplay ([string]$src)
      if ([string]::IsNullOrWhiteSpace($dispSrc)) { continue }
      $keySrc = Get-SourcePathKey $dispSrc
      if ([string]::IsNullOrWhiteSpace($keySrc)) { continue }
      if ($sourceSeen.ContainsKey($keySrc)) { continue }
      $sourceSeen[$keySrc] = $true
      $show = $true
      try { $show = [bool](Get-SourcePathVisibility -Path $dispSrc) } catch { $show = $true }
      [void]$iconSourceRows.Add([pscustomobject]@{
        Path = [string]$dispSrc
        Kind = 'Custom'
        Show = [bool]$show
      })
    }
    $catPanelRows = @()
    try { $catPanelRows = @(Get-CurrentCategoryPanelStateRows) } catch { $catPanelRows = @() }
    if (@($catPanelRows).Count -eq 0) {
      try {
        if (@($script:CategoryPanelStateRows).Count -gt 0) {
          $catPanelRows = @($script:CategoryPanelStateRows)
        }
      } catch {}
    }
    try { $script:CategoryPanelStateRows = @($catPanelRows) } catch {}
    $obj = [pscustomobject]@{
      IconSources = @($iconSourceRows.ToArray())
      CategoryPanelState = [pscustomobject]@{
        Rows = @($catPanelRows)
      }
    }
    $json = $obj | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $path -Value $json -Encoding UTF8
    try {
      $legacyBin = Get-IconSourceDirectoriesLegacyBinStatePath
      if (-not [string]::IsNullOrWhiteSpace($legacyBin) -and (Test-Path -LiteralPath $legacyBin -PathType Leaf)) {
        Remove-Item -LiteralPath $legacyBin -Force -ErrorAction SilentlyContinue
      }
    } catch {}
    return [pscustomobject]@{ Ok = $true; Path = [string]$path; Error = '' }
  } catch {
    return [pscustomobject]@{ Ok = $false; Path = ''; Error = [string]$_.Exception.Message }
  }
}

function Load-CustomIconSourceDirectories {
  try {
    $path = Get-IconSourceDirectoriesStatePath
    $items = @()
    $builtInItems = @()
    $visItems = @()
    $catPanelStateRows = @()
    $needsCanonicalRewrite = $false
    $shouldPersistAfterLoad = $false
    if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
      try {
        $obj = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($obj -is [System.Array]) {
          $items = @($obj)
          $shouldPersistAfterLoad = $true
        } elseif ($null -ne $obj) {
          if ($obj.PSObject.Properties.Match('IconSources').Count -gt 0) {
            $srcRows = @($obj.IconSources)
            foreach ($sr in @($srcRows)) {
              $sp = ''
              $sk = 'Custom'
              $ss = $true
              if ($sr -is [string]) {
                try { $sp = [string]$sr } catch { $sp = '' }
              } else {
                try { $sp = [string]$sr.Path } catch { $sp = '' }
                try { $sk = [string]$sr.Kind } catch { $sk = 'Custom' }
                try { $ss = [bool]$sr.Show } catch { $ss = $true }
              }
              $sp = Normalize-SourcePathForDisplay $sp
              if ([string]::IsNullOrWhiteSpace($sp)) { continue }
              if ($sk -eq 'BuiltIn') {
                $builtInItems += $sp
              } else {
                $items += $sp
              }
              $visItems += [pscustomobject]@{ Path = [string]$sp; Show = [bool]$ss }
            }
          } else {
            $shouldPersistAfterLoad = $true
            if ($obj.PSObject.Properties.Match('BuiltInSources').Count -gt 0) {
              $builtInItems = @($obj.BuiltInSources)
            }
            if ($obj.PSObject.Properties.Match('CustomSources').Count -gt 0) {
              $items = @($obj.CustomSources)
            } else {
              $items = @($obj)
            }
            if ($obj.PSObject.Properties.Match('SourceVisibility').Count -gt 0) {
              $visItems = @($obj.SourceVisibility)
            }
          }
          if ($obj.PSObject.Properties.Match('CategoryPanelState').Count -gt 0) {
            $cps = $obj.CategoryPanelState
            if ($cps -is [System.Array]) { $catPanelStateRows = @($cps) }
            elseif ($cps -and $cps.PSObject.Properties.Match('Rows').Count -gt 0) { $catPanelStateRows = @($cps.Rows) }
          }
        }
        try {
          foreach ($bi in @($builtInItems)) {
            $sbi = ''
            try { $sbi = [string]$bi } catch { $sbi = '' }
            if ([string]::IsNullOrWhiteSpace($sbi)) { continue }
            if ($sbi -match '^[A-Za-z]:\\') { $needsCanonicalRewrite = $true; break }
          }
          if (-not $needsCanonicalRewrite) {
            foreach ($ci in @($items)) {
              $sci = ''
              try { $sci = [string]$ci } catch { $sci = '' }
              if ([string]::IsNullOrWhiteSpace($sci)) { continue }
              if ($sci -match '^[A-Za-z]:\\') { $needsCanonicalRewrite = $true; break }
            }
          }
          if (-not $needsCanonicalRewrite) {
            foreach ($vi in @($visItems)) {
              $svp = ''
              if ($vi -is [string]) {
                try { $svp = [string]$vi } catch { $svp = '' }
              } else {
                try { $svp = [string]$vi.Path } catch { $svp = '' }
              }
              if ([string]::IsNullOrWhiteSpace($svp)) { continue }
              if ($svp -match '^[A-Za-z]:\\') { $needsCanonicalRewrite = $true; break }
            }
          }
        } catch {}
      } catch { $items = @() }
    } else {
      # One-time migration from legacy bin in Icon Categories.
      $shouldPersistAfterLoad = $true
      $legacyBin = Get-IconSourceDirectoriesLegacyBinStatePath
      if (-not [string]::IsNullOrWhiteSpace($legacyBin) -and (Test-Path -LiteralPath $legacyBin -PathType Leaf)) {
        $fs = $null
        $br = $null
        try {
          $fs = [System.IO.File]::Open($legacyBin, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
          $br = New-Object System.IO.BinaryReader($fs, [System.Text.Encoding]::UTF8)
          $ver = [int]$br.ReadInt32()
          if ($ver -eq 1) {
            $count = [int]$br.ReadInt32()
            if ($count -lt 0) { $count = 0 }
            for ($i = 0; $i -lt $count; $i++) { $items += [string]$br.ReadString() }
          }
        } catch {} finally {
          try { if ($br) { $br.Close() } } catch {}
          try { if ($fs) { $fs.Close() } } catch {}
        }
        try { Remove-Item -LiteralPath $legacyBin -Force -ErrorAction SilentlyContinue } catch {}
      }
    }
    try {
      $script:BuiltInIconSourceDirs = New-Object System.Collections.Generic.List[string]
      if (@($builtInItems).Count -gt 0) {
        foreach ($bi in @($builtInItems)) {
          $nb = Normalize-SourcePathForDisplay ([string]$bi)
          if ([string]::IsNullOrWhiteSpace($nb)) { continue }
          [void]$script:BuiltInIconSourceDirs.Add($nb)
        }
      }
      $script:BuiltInSourcesInitialized = $true
    } catch {}
    try { $script:CategoryPanelStateRows = @($catPanelStateRows) } catch { $script:CategoryPanelStateRows = @() }
    try { $script:IconSourceVisibilityByKey = @{} } catch {}
    foreach ($vi in @($visItems)) {
      try {
        $vp = ''
        $vs = $true
        if ($vi -is [string]) {
          $vp = [string]$vi
        } else {
          try { $vp = [string]$vi.Path } catch { $vp = '' }
          try { $vs = [bool]$vi.Show } catch { $vs = $true }
        }
        $vp = Normalize-SourcePathForDisplay $vp
        if ([string]::IsNullOrWhiteSpace($vp)) { continue }
        Set-SourcePathVisibility -Path $vp -Visible:$vs
      } catch {}
    }

    foreach ($it in @($items)) {
      $disp = Normalize-SourcePathForDisplay ([string]$it)
      if ([string]::IsNullOrWhiteSpace($disp)) { continue }
      $p = Normalize-Path $disp
      if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path -LiteralPath $p)) { continue }
      $k = Get-SourcePathKey $disp
      if ([string]::IsNullOrWhiteSpace($k)) { continue }
      $exists = $false
      foreach ($d in @($script:CustomIconSourceDirs.ToArray())) {
        try { if ((Get-SourcePathKey ([string]$d)) -eq $k) { $exists = $true; break } } catch {}
      }
      if (-not $exists) { [void]$script:CustomIconSourceDirs.Add($disp) }
      try {
        if (-not ($script:IconSourceVisibilityByKey.ContainsKey($k))) {
          Set-SourcePathVisibility -Path $disp -Visible:$true
        }
      } catch {}
    }
    if ($shouldPersistAfterLoad -or $needsCanonicalRewrite) {
      try { Save-CustomIconSourceDirectories } catch {}
    }
    try {
      # Cleanup retired standalone category-state file after successful merged load.
      $legacyCategoryStatePath = Join-Path (Split-Path -Parent $path) 'IconAllocatorCategoryPanelState.json'
      if (Test-Path -LiteralPath $legacyCategoryStatePath -PathType Leaf) {
        Remove-Item -LiteralPath $legacyCategoryStatePath -Force -ErrorAction SilentlyContinue
      }
    } catch {}
  } catch {}
}

function Refresh-IconSourceDirectoryList {
  try {
    if (-not $iconSourceDirList) { return }
    try { if ($script:SourcePathTogglePickKeys) { $script:SourcePathTogglePickKeys.Clear() } } catch {}
    $rows = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    foreach ($d in @(Get-EffectiveBuiltInSourceEntries)) {
      $n = ''
      try { $n = [string]$d } catch { $n = '' }
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $n = Normalize-SourcePathForDisplay $n
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $k = (Get-SourcePathKey $n)
      if ([string]::IsNullOrWhiteSpace($k)) { $k = $n.Trim().ToLowerInvariant() }
      try { if ($script:SessionHiddenSourcePathKeys -and $script:SessionHiddenSourcePathKeys.ContainsKey([string]$k)) { continue } } catch {}
      if ($seen.ContainsKey($k)) { continue }
      $seen[$k] = $true
      $show = $true
      try { $show = [bool](Get-SourcePathVisibility -Path $n) } catch { $show = $true }
      [void]$rows.Add([pscustomobject]@{
        Path = [string]$n.Trim()
        PathKey = [string]$k
        ShowChecked = [bool]$show
        IsBuiltIn = $true
      })
    }
    foreach ($d in @($script:CustomIconSourceDirs.ToArray())) {
      $n = ''
      try { $n = [string]$d } catch { $n = '' }
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $n = Normalize-SourcePathForDisplay $n
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $k = (Get-SourcePathKey $n)
      if ([string]::IsNullOrWhiteSpace($k)) { $k = $n.Trim().ToLowerInvariant() }
      try { if ($script:SessionHiddenSourcePathKeys -and $script:SessionHiddenSourcePathKeys.ContainsKey([string]$k)) { continue } } catch {}
      if ($seen.ContainsKey($k)) { continue }
      $seen[$k] = $true
      $show = $true
      try { $show = [bool](Get-SourcePathVisibility -Path $n) } catch { $show = $true }
      [void]$rows.Add([pscustomobject]@{
        Path = [string]$n.Trim()
        PathKey = [string]$k
        ShowChecked = [bool]$show
        IsBuiltIn = $false
      })
    }
    try { $script:SuppressSourcePathUiEvents = $true } catch {}
    $iconSourceDirList.ItemsSource = @($rows.ToArray())
    try {
      if ($window -and $window.Dispatcher) {
        $null = $window.Dispatcher.BeginInvoke([Action]{
          try { $script:SuppressSourcePathUiEvents = $false } catch {}
          try { Update-ToggleAllSourcePathsCheckState } catch {}
        }, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
      } else {
        try { $script:SuppressSourcePathUiEvents = $false } catch {}
        try { Update-ToggleAllSourcePathsCheckState } catch {}
      }
    } catch {
      try { $script:SuppressSourcePathUiEvents = $false } catch {}
      try { Update-ToggleAllSourcePathsCheckState } catch {}
    }
  } catch {}
}

function Update-RightPanelToggleIcon {
  param([bool]$PanelVisible)
  try {
    if (-not $rightPanelToggleBtn) { return }
    $explorerPath = Normalize-Path ([System.IO.Path]::Combine($env:WINDIR, 'explorer.exe'))
    $iconIndex = if ($PanelVisible) { 10 } else { 9 }
    $src = $null
    try { $src = Get-IconImageSource -IconPath $explorerPath -IconIndex $iconIndex } catch { $src = $null }
    if ($src) {
      $img = New-Object System.Windows.Controls.Image
      $img.Source = $src
      $img.Stretch = [System.Windows.Media.Stretch]::Fill
      $img.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch
      $img.VerticalAlignment = [System.Windows.VerticalAlignment]::Stretch
      $rightPanelToggleBtn.Content = $img
    } else {
      $rightPanelToggleBtn.Content = $(if ($PanelVisible) { '<' } else { '>' })
    }
    $rightPanelToggleBtn.ToolTip = $(if ($PanelVisible) { 'Hide right panel' } else { 'Show right panel' })
  } catch {}
}

function Set-RightPanelVisibility {
  param([bool]$Visible)
  try {
    if ($Visible) {
      $w = 290.0
      try { $w = [double]$script:RightPanelLastWidth } catch { $w = 290.0 }
      if ($w -lt 220.0) { $w = 220.0 }
      if ($rightPanelColumn) {
        try { $rightPanelColumn.MinWidth = 220.0 } catch {}
        try { $rightPanelColumn.Width = New-Object System.Windows.GridLength($w, [System.Windows.GridUnitType]::Pixel) } catch {}
      }
      if ($rightSplitterColumn) {
        try { $rightSplitterColumn.Width = New-Object System.Windows.GridLength(20.0, [System.Windows.GridUnitType]::Pixel) } catch {}
      }
      try { if ($rightPanelGroup) { $rightPanelGroup.Visibility = [System.Windows.Visibility]::Visible } } catch {}
      try { if ($rightPanelSplitter) { $rightPanelSplitter.Visibility = [System.Windows.Visibility]::Visible } } catch {}
      $script:RightPanelVisible = $true
      Update-RightPanelToggleIcon -PanelVisible:$true
      return
    }

    if ($rightPanelColumn) {
      $aw = 0.0
      try { $aw = [double]$rightPanelColumn.ActualWidth } catch { $aw = 0.0 }
      if ($aw -ge 50.0) { $script:RightPanelLastWidth = $aw }
      try { $rightPanelColumn.MinWidth = 0.0 } catch {}
      try { $rightPanelColumn.Width = New-Object System.Windows.GridLength(0.0, [System.Windows.GridUnitType]::Pixel) } catch {}
    }
    if ($rightSplitterColumn) {
      try { $rightSplitterColumn.Width = New-Object System.Windows.GridLength(20.0, [System.Windows.GridUnitType]::Pixel) } catch {}
    }
    try { if ($rightPanelGroup) { $rightPanelGroup.Visibility = [System.Windows.Visibility]::Collapsed } } catch {}
    try { if ($rightPanelSplitter) { $rightPanelSplitter.Visibility = [System.Windows.Visibility]::Collapsed } } catch {}
    $script:RightPanelVisible = $false
    Update-RightPanelToggleIcon -PanelVisible:$false
  } catch {}
}

try { Set-RightPanelVisibility -Visible:$true } catch {}
try { Update-ToggleAllSelectCheckState } catch {}
try { Update-ToggleAllCategoriesCheckState } catch {}
try { Update-ToggleAllMaskCheckState } catch {}

function Get-CheckedCategories {
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($c in @($script:CategoryRows.ToArray())) {
    if (-not $c) { continue }
    $sel = $false
    try { $sel = [bool]$c.SelectChecked } catch { $sel = $false }
    if (-not $sel) { continue }
    $n = ''
    try { $n = [string]$c.Name } catch { $n = '' }
    $n = $n.Trim()
    if ([string]::IsNullOrWhiteSpace($n)) { continue }
    [void]$out.Add($n)
  }
  return @($out.ToArray())
}

function Get-ShownCategories {
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($c in @($script:CategoryRows.ToArray())) {
    if (-not $c) { continue }
    $sel = $false
    try { $sel = [bool]$c.ShowChecked } catch { $sel = $false }
    if (-not $sel) { continue }
    $n = ''
    try { $n = [string]$c.Name } catch { $n = '' }
    $n = $n.Trim()
    if ([string]::IsNullOrWhiteSpace($n)) { continue }
    [void]$out.Add($n)
  }
  return @($out.ToArray())
}

function Get-HiddenCategories {
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($c in @($script:CategoryRows.ToArray())) {
    if (-not $c) { continue }
    $sel = $false
    try { $sel = [bool]$c.HideChecked } catch { $sel = $false }
    if (-not $sel) { continue }
    $n = ''
    try { $n = [string]$c.Name } catch { $n = '' }
    $n = $n.Trim()
    if ([string]::IsNullOrWhiteSpace($n)) { continue }
    [void]$out.Add($n)
  }
  return @($out.ToArray())
}

function Get-CheckedCategorySet {
  $set = @{}
  try {
    foreach ($n in @(Get-CheckedCategories)) {
      $cn = ''
      try { $cn = [string]$n } catch { $cn = '' }
      $cn = $cn.Trim()
      if ([string]::IsNullOrWhiteSpace($cn)) { continue }
      $set[$cn.ToLowerInvariant()] = $true
    }
  } catch {}
  return $set
}

function Get-ShownCategorySet {
  $set = @{}
  try {
    foreach ($n in @(Get-ShownCategories)) {
      $cn = ''
      try { $cn = [string]$n } catch { $cn = '' }
      $cn = $cn.Trim()
      if ([string]::IsNullOrWhiteSpace($cn)) { continue }
      $set[$cn.ToLowerInvariant()] = $true
    }
  } catch {}
  return $set
}

function Test-EntryMatchesCheckedSet {
  param(
    [Parameter(Mandatory=$false)][object]$Entry,
    [Parameter(Mandatory=$false)][hashtable]$CheckedSet
  )
  try {
    if (-not $Entry) { return $false }
    if (-not $CheckedSet -or $CheckedSet.Count -eq 0) { return $false }
    foreach ($cat in @($Entry.Categories)) {
      $n = ''
      try { $n = [string]$cat } catch { $n = '' }
      $n = $n.Trim()
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      if ($CheckedSet.ContainsKey($n.ToLowerInvariant())) { return $true }
    }
    return $false
  } catch { return $false }
}

function Test-CategoryListHasAllOfCheckedSet {
  param(
    [Parameter(Mandatory=$false)][string[]]$Categories,
    [Parameter(Mandatory=$false)][hashtable]$CheckedSet
  )
  try {
    if (-not $CheckedSet -or $CheckedSet.Count -eq 0) { return $false }
    $have = @{}
    foreach ($cat in @($Categories)) {
      $n = ''
      try { $n = [string]$cat } catch { $n = '' }
      $n = $n.Trim()
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $have[$n.ToLowerInvariant()] = $true
    }
    foreach ($k in @($CheckedSet.Keys)) {
      if (-not $have.ContainsKey([string]$k)) { return $false }
    }
    return $true
  } catch { return $false }
}

function Get-SelectDeltaKindByKey {
  param(
    [Parameter(Mandatory=$false)][string]$Key,
    [Parameter(Mandatory=$false)][hashtable]$CheckedSet
  )
  try {
    if ([string]::IsNullOrWhiteSpace($Key)) { return 'None' }
    if (-not $CheckedSet -or $CheckedSet.Count -eq 0) { return 'None' }

    $curCats = @()
    try {
      if ($script:AssignmentsByKey.ContainsKey($Key)) {
        $entry = $script:AssignmentsByKey[$Key]
        if ($entry) { $curCats = @($entry.Categories) }
      }
    } catch { $curCats = @() }

    $baseCats = @()
    try {
      if ($script:BaselineAssignmentCategoriesByKey -and $script:BaselineAssignmentCategoriesByKey.ContainsKey($Key)) {
        $baseCats = @($script:BaselineAssignmentCategoriesByKey[$Key])
      }
    } catch { $baseCats = @() }

    $baseAll = [bool](Test-CategoryListHasAllOfCheckedSet -Categories @($baseCats) -CheckedSet $CheckedSet)
    $curAll  = [bool](Test-CategoryListHasAllOfCheckedSet -Categories @($curCats)  -CheckedSet $CheckedSet)

    if ($baseAll -and -not $curAll) { return 'Remove' }
    if ((-not $baseAll) -and $curAll) { return 'Add' }
    return 'None'
  } catch { return 'None' }
}

function Refresh-CategoryList {
  try {
    try { Normalize-CategoryRowFlags } catch {}
    $categoryList.ItemsSource = $null
    $categoryList.ItemsSource = @($script:CategoryRows.ToArray())
  } catch {}
}

function Get-AssignmentCategorySignature {
  param([object]$Entry)
  try {
    if (-not $Entry) { return '' }
    $vals = New-Object System.Collections.Generic.List[string]
    foreach ($c in @($Entry.Categories)) {
      $n = ''
      try { $n = [string]$c } catch { $n = '' }
      $n = $n.Trim().ToLowerInvariant()
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      [void]$vals.Add($n)
    }
    if (@($vals).Count -eq 0) { return '' }
    $uniq = @($vals.ToArray() | Sort-Object -Unique)
    return [string]($uniq -join ';')
  } catch { return '' }
}

function Capture-AssignmentBaseline {
  try {
    $script:BaselineAssignmentSignaturesByKey = @{}
    $script:BaselineAssignmentCategoriesByKey = @{}
    foreach ($k in @($script:AssignmentsByKey.Keys)) {
      if ([string]::IsNullOrWhiteSpace([string]$k)) { continue }
      if (-not $script:AssignmentsByKey.ContainsKey($k)) { continue }
      $entry = $script:AssignmentsByKey[$k]
      $sig = [string](Get-AssignmentCategorySignature -Entry $entry)
      $cats = New-Object System.Collections.Generic.List[string]
      foreach ($c in @($entry.Categories)) {
        $n = ''
        try { $n = [string]$c } catch { $n = '' }
        $n = $n.Trim()
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        [void]$cats.Add($n)
      }
      $script:BaselineAssignmentSignaturesByKey[[string]$k] = $sig
      $script:BaselineAssignmentCategoriesByKey[[string]$k] = @($cats.ToArray())
    }
  } catch {}
}

function Test-AssignmentPendingByKey {
  param([string]$Key)
  try {
    $k = ''
    try { $k = [string]$Key } catch { $k = '' }
    $k = $k.Trim()
    if ([string]::IsNullOrWhiteSpace($k)) { return $false }
    $currentSig = ''
    if ($script:AssignmentsByKey.ContainsKey($k)) {
      $entry = $script:AssignmentsByKey[$k]
      $currentSig = [string](Get-AssignmentCategorySignature -Entry $entry)
    }
    $baseSig = ''
    if ($script:BaselineAssignmentSignaturesByKey -and $script:BaselineAssignmentSignaturesByKey.ContainsKey($k)) {
      $baseSig = [string]$script:BaselineAssignmentSignaturesByKey[$k]
    }
    return ($currentSig -ne $baseSig)
  } catch { return $false }
}

function Enforce-CategoryRowExclusivity {
  param(
    [Parameter(Mandatory=$true)][object]$Row,
    [ValidateSet('Show','Hide')]
    [string]$Prefer = 'Show'
  )
  try {
    if (-not $Row) { return }
    $s = $false
    $h = $false
    try { $s = [bool]$Row.ShowChecked } catch { $s = $false }
    try { $h = [bool]$Row.HideChecked } catch { $h = $false }
    if ($s -and $h) {
      if ($Prefer -eq 'Hide') {
        try { $Row.ShowChecked = $false } catch {}
      } else {
        try { $Row.HideChecked = $false } catch {}
      }
    }
  } catch {}
}

function Normalize-CategoryRowFlags {
  param(
    [ValidateSet('Show','Hide')]
    [string]$Prefer = 'Show'
  )
  try {
    foreach ($r in @($script:CategoryRows.ToArray())) {
      if (-not $r) { continue }
      try { if ($r.PSObject.Properties.Match('SelectChecked').Count -eq 0) { $r | Add-Member -NotePropertyName SelectChecked -NotePropertyValue $false -Force } } catch {}
      try { if ($r.PSObject.Properties.Match('ShowChecked').Count -eq 0) { $r | Add-Member -NotePropertyName ShowChecked -NotePropertyValue $false -Force } } catch {}
      try { if ($r.PSObject.Properties.Match('HideChecked').Count -eq 0) { $r | Add-Member -NotePropertyName HideChecked -NotePropertyValue $false -Force } } catch {}
      Enforce-CategoryRowExclusivity -Row $r -Prefer $Prefer
    }
  } catch {}
}

function Update-ToggleAllSelectCheckState {
  try {
    if (-not $toggleAllSelectBox) { return }
    $rows = @($script:CategoryRows.ToArray())
    $allSelected = $true
    foreach ($r in @($rows)) {
      if (-not $r) { continue }
      $sel = $false
      try { $sel = [bool]$r.SelectChecked } catch { $sel = $false }
      if (-not $sel) { $allSelected = $false; break }
    }
    $script:SuppressCategoryCheckEvents = $true
    try { $toggleAllSelectBox.IsChecked = [bool]$allSelected } catch {}
    $script:SuppressCategoryCheckEvents = $false
  } catch {
    try { $script:SuppressCategoryCheckEvents = $false } catch {}
  }
}

function Update-ToggleAllCategoriesCheckState {
  try {
    if (-not $toggleAllCategoriesBox) { return }
    $rows = @($script:CategoryRows.ToArray())
    $allSelected = $true
    foreach ($r in @($rows)) {
      if (-not $r) { continue }
      $sel = $false
      try { $sel = [bool]$r.ShowChecked } catch { $sel = $false }
      if (-not $sel) { $allSelected = $false; break }
    }
    $script:SuppressCategoryCheckEvents = $true
    try { $toggleAllCategoriesBox.IsChecked = [bool]$allSelected } catch {}
    $script:SuppressCategoryCheckEvents = $false
  } catch {
    try { $script:SuppressCategoryCheckEvents = $false } catch {}
  }
}

function Update-ToggleAllMaskCheckState {
  try {
    if (-not $toggleAllMaskBox) { return }
    $rows = @($script:CategoryRows.ToArray())
    $allMasked = $true
    foreach ($r in @($rows)) {
      if (-not $r) { continue }
      $sel = $false
      try { $sel = [bool]$r.HideChecked } catch { $sel = $false }
      if (-not $sel) { $allMasked = $false; break }
    }
    $script:SuppressCategoryCheckEvents = $true
    try { $toggleAllMaskBox.IsChecked = [bool]$allMasked } catch {}
    $script:SuppressCategoryCheckEvents = $false
  } catch {
    try { $script:SuppressCategoryCheckEvents = $false } catch {}
  }
}

function Set-AllCategoriesSelected {
  param([bool]$Selected)
  try {
    $rows = @($script:CategoryRows.ToArray())
    if (@($rows).Count -eq 0) {
      try { $statusText.Text = 'No categories available.' } catch {}
      return
    }
    $script:SuppressCategoryCheckEvents = $true
    foreach ($r in @($rows)) {
      if (-not $r) { continue }
      try { $r.SelectChecked = [bool]$Selected } catch {}
    }
    try { Refresh-CategoryList } catch {}
    $script:SuppressCategoryCheckEvents = $false

    Handle-CategoryCheckedChanged -IsChecked:$Selected -CategoryName '' -ColumnKind 'Select'
    Update-ToggleAllSelectCheckState
    if ($Selected) {
      try { $statusText.Text = 'All categories set to Select.' } catch {}
    } else {
      try { $statusText.Text = 'All categories removed from Select.' } catch {}
    }
  } catch {
    try { $script:SuppressCategoryCheckEvents = $false } catch {}
    try { $statusText.Text = ("Select toggle failed: " + [string]$_.Exception.Message) } catch {}
  }
}

function Set-AllCategoriesShown {
  param([bool]$Selected)
  try {
    $rows = @($script:CategoryRows.ToArray())
    if (@($rows).Count -eq 0) {
      try { $statusText.Text = 'No categories available.' } catch {}
      return
    }
    $script:SuppressCategoryCheckEvents = $true
    foreach ($r in @($rows)) {
      if (-not $r) { continue }
      try { $r.ShowChecked = [bool]$Selected } catch {}
      if ($Selected) {
        try { $r.HideChecked = $false } catch {}
      }
    }
    try { Refresh-CategoryList } catch {}
    $script:SuppressCategoryCheckEvents = $false

    Handle-CategoryCheckedChanged -IsChecked:$Selected -CategoryName '' -ColumnKind 'Show'
    Update-ToggleAllCategoriesCheckState
    if ($Selected) {
      try { $statusText.Text = 'All categories set to Show.' } catch {}
    } else {
      try { $statusText.Text = 'All categories removed from Show.' } catch {}
    }
  } catch {
    try { $script:SuppressCategoryCheckEvents = $false } catch {}
    try { $statusText.Text = ("Category toggle failed: " + [string]$_.Exception.Message) } catch {}
  }
}

function Set-AllCategoriesMasked {
  param([bool]$Selected)
  try {
    $rows = @($script:CategoryRows.ToArray())
    if (@($rows).Count -eq 0) {
      try { $statusText.Text = 'No categories available.' } catch {}
      return
    }
    $script:SuppressCategoryCheckEvents = $true
    foreach ($r in @($rows)) {
      if (-not $r) { continue }
      try { $r.HideChecked = [bool]$Selected } catch {}
      if ($Selected) {
        try { $r.ShowChecked = $false } catch {}
      }
    }
    try { Refresh-CategoryList } catch {}
    $script:SuppressCategoryCheckEvents = $false

    Handle-CategoryCheckedChanged -IsChecked:$Selected -CategoryName '' -ColumnKind 'Hide'
    Update-ToggleAllMaskCheckState
    if ($Selected) {
      try { $statusText.Text = 'All categories set to Mask.' } catch {}
    } else {
      try { $statusText.Text = 'All categories removed from Mask.' } catch {}
    }
  } catch {
    try { $script:SuppressCategoryCheckEvents = $false } catch {}
    try { $statusText.Text = ("Mask toggle failed: " + [string]$_.Exception.Message) } catch {}
  }
}

function Refresh-SelectedNamesList {
  $rows = New-Object System.Collections.Generic.List[string]
  $shownSet = Get-ShownCategorySet
  if ($shownSet.Count -gt 0) {
    foreach ($k in @($script:AssignmentsByKey.Keys | Sort-Object)) {
      $a = $null
      try { $a = $script:AssignmentsByKey[$k] } catch { $a = $null }
      if (-not $a) { continue }
      $lbl = ''
      try { $lbl = [string]$script:IconsByKey[$k].Label } catch { $lbl = $k }
      foreach ($cat in @($a.Categories)) {
        $catName = ''
        try { $catName = [string]$cat } catch { $catName = '' }
        $catName = $catName.Trim()
        if ([string]::IsNullOrWhiteSpace($catName)) { continue }
        if (-not $shownSet.ContainsKey($catName.ToLowerInvariant())) { continue }
        [void]$rows.Add(("{0} -> {1}" -f $catName, $lbl))
      }
    }
  }
  $selectedNamesList.ItemsSource = @($rows.ToArray())
}

function Queue-RefreshSelectedNamesList {
  param([switch]$Immediate)
  if ($Immediate) {
    try { if ($script:SelectedNamesRefreshTimer) { $script:SelectedNamesRefreshTimer.Stop() } } catch {}
    Refresh-SelectedNamesList
    return
  }
  if (-not $script:SelectedNamesRefreshTimer) {
    $t = New-Object System.Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromMilliseconds(120)
    $t.Add_Tick({
      try { if ($script:SelectedNamesRefreshTimer) { $script:SelectedNamesRefreshTimer.Stop() } } catch {}
      try { Refresh-SelectedNamesList } catch {}
    })
    $script:SelectedNamesRefreshTimer = $t
  }
  try {
    $script:SelectedNamesRefreshTimer.Stop()
    $script:SelectedNamesRefreshTimer.Start()
  } catch {
    try { Refresh-SelectedNamesList } catch {}
  }
}

function Queue-IconSearchRefresh {
  param([switch]$Immediate)
  if ($Immediate) {
    try { if ($script:IconSearchDebounceTimer) { $script:IconSearchDebounceTimer.Stop() } } catch {}
    try { Refresh-IconListPage } catch {}
    return
  }
  if (-not ($script:IconSearchDebounceTimer -and ($script:IconSearchDebounceTimer -is [System.Windows.Threading.DispatcherTimer]))) {
    $t = New-Object System.Windows.Threading.DispatcherTimer
    try { $t.Interval = [TimeSpan]::FromMilliseconds([double]$script:IconSearchDebounceMs) } catch { $t.Interval = [TimeSpan]::FromMilliseconds(180) }
    $t.Add_Tick({
      try { if ($script:IconSearchDebounceTimer) { $script:IconSearchDebounceTimer.Stop() } } catch {}
      try { Refresh-IconListPage } catch {}
    })
    $script:IconSearchDebounceTimer = $t
  }
  try {
    $script:IconSearchDebounceTimer.Stop()
    $script:IconSearchDebounceTimer.Start()
  } catch {
    try { Refresh-IconListPage } catch {}
  }
}

function Refresh-AssignedVisual {
  param(
    [switch]$ForceRebind,
    [switch]$SkipSelectionSync
  )
  $needRebind = $false
  try {
    $needRebind = [bool]$ForceRebind -or (-not [bool]$script:ShowAllIcons)
  } catch { $needRebind = [bool]$ForceRebind }

  if ($needRebind) {
    try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
    try { Refresh-IconListPage } catch {}
  } else {
    try { Update-VisibleIconAssignedState } catch {}
  }
  try {
    $visible = @()
    try { $visible = @($iconList.ItemsSource) } catch { $visible = @() }
    if (@($visible).Count -gt 0) {
      try { Refresh-IconContainerStylesForItems -Items $visible } catch {}
    }
  } catch {}
  Queue-RefreshSelectedNamesList
}

function Refresh-IconContainerStyleForItem {
  param([object]$Item)
  try {
    if (-not $iconList -or -not $Item) { return }
    $container = $null
    try { $container = $iconList.ItemContainerGenerator.ContainerFromItem($Item) -as [System.Windows.Controls.ListBoxItem] } catch { $container = $null }
    if (-not $container) { return }
    $styleRef = $null
    try { $styleRef = $container.Style } catch { $styleRef = $null }
    if (-not $styleRef) { return }
    try { $container.Style = $null } catch {}
    try { $container.Style = $styleRef } catch {}
    try { $container.InvalidateVisual() } catch {}
  } catch {}
}

function Refresh-IconContainerStylesForItems {
  param([object[]]$Items)
  try {
    if (-not $iconList) { return }
    foreach ($it in @($Items | Where-Object { $_ })) {
      try { Refresh-IconContainerStyleForItem -Item $it } catch {}
    }
  } catch {}
}

function Update-VisibleIconAssignedState {
  try {
    if (-not $iconList) { return }
    $shownSet = Get-ShownCategorySet
    $checkedSet = Get-CheckedCategorySet
    $hasSelectTargets = $false
    try { $hasSelectTargets = ($checkedSet -and $checkedSet.Count -gt 0) } catch { $hasSelectTargets = $false }
    $visible = @()
    try { $visible = @($iconList.ItemsSource) } catch { $visible = @() }
    foreach ($it in @($visible)) {
      if (-not $it) { continue }
      $k = ''
      try { $k = [string]$it.Key } catch { $k = '' }
      if ([string]::IsNullOrWhiteSpace($k)) {
        try { $it.IsAssignedActive = $false } catch {}
        try { $it.IsCategorized = $false } catch {}
        try { $it.HasSelectTargets = [bool]$hasSelectTargets } catch {}
        try { $it.SelectDeltaKind = 'None' } catch {}
        try { $it.IsPendingExport = $false } catch {}
        continue
      }
      $entry = $null
      try { if ($script:AssignmentsByKey.ContainsKey($k)) { $entry = $script:AssignmentsByKey[$k] } } catch { $entry = $null }
      try { $it.IsAssignedActive = [bool](Test-EntryMatchesCheckedSet -Entry $entry -CheckedSet $shownSet) } catch {}
      try {
        if ([bool]$script:ShowUncategorizedOnly) {
          $it.IsCategorized = [bool](Test-IconHasAnyCommittedAssignment -Key $k)
        } else {
          $it.IsCategorized = [bool](Test-IconHasAnyAssignment -Key $k)
        }
      } catch {}
      try { $it.HasSelectTargets = [bool]$hasSelectTargets } catch {}
      try { $it.SelectDeltaKind = [string](Get-SelectDeltaKindByKey -Key $k -CheckedSet $checkedSet) } catch { try { $it.SelectDeltaKind = 'None' } catch {} }
      try { $it.IsPendingExport = [bool](Test-AssignmentPendingByKey -Key $k) } catch {}
      try { $it.IsExtractSelected = ([bool]$script:ExtractIconsMode -and [bool]$script:ExtractSelectedKeys.ContainsKey($k)) } catch {}
    }
    try { Refresh-IconContainerStylesForItems -Items $visible } catch {}
  } catch {}
}

function Sync-SelectionForSpecificIcons {
  param([object[]]$Icons)
  try {
    if (-not $iconList) { return }
    $targets = @($Icons | Where-Object { $_ })
    if (@($targets).Count -eq 0) { return }
    $checkedSet = Get-CheckedCategorySet
    if (-not $checkedSet -or $checkedSet.Count -eq 0) { return }
    foreach ($it in @($targets)) {
      if (-not $it) { continue }
      $k = ''
      try { $k = [string]$it.Key } catch { $k = '' }
      if ([string]::IsNullOrWhiteSpace($k)) { continue }
      $entry = $null
      try { if ($script:AssignmentsByKey.ContainsKey($k)) { $entry = $script:AssignmentsByKey[$k] } } catch { $entry = $null }
      $shouldSelect = $false
      try { $shouldSelect = [bool](Test-EntryMatchesCheckedSet -Entry $entry -CheckedSet $checkedSet) } catch { $shouldSelect = $false }
      if ($shouldSelect) {
        try {
          if (-not $iconList.SelectedItems.Contains($it)) {
            [void]$iconList.SelectedItems.Add($it)
          }
        } catch {}
      } else {
        try { [void]$iconList.SelectedItems.Remove($it) } catch {}
      }
    }
  } catch {}
}

function Sync-IconSelectionToCheckedCategories {
  try {
    if (-not $iconList) { return }
    $checked = @(Get-CheckedCategories)
    if (@($checked).Count -eq 0) {
      try { $iconList.UnselectAll() } catch {}
      return
    }

    $checkedSet = @{}
    foreach ($c in @($checked)) {
      $cn = ''
      try { $cn = [string]$c } catch { $cn = '' }
      if ([string]::IsNullOrWhiteSpace($cn)) { continue }
      $checkedSet[$cn.Trim().ToLowerInvariant()] = $true
    }
    if ($checkedSet.Count -eq 0) { return }

    $wantSet = @{}
    $visible = @()
    try { $visible = @($iconList.ItemsSource) } catch { $visible = @() }
    foreach ($it in @($visible)) {
      if (-not $it) { continue }
      $k = ''
      try { $k = [string]$it.Key } catch { $k = '' }
      if ([string]::IsNullOrWhiteSpace($k)) { continue }
      if (-not $script:AssignmentsByKey.ContainsKey($k)) { continue }
      $entry = $script:AssignmentsByKey[$k]
      if (-not $entry) { continue }
      $hit = $false
      foreach ($cat in @($entry.Categories)) {
        $catName = ''
        try { $catName = [string]$cat } catch { $catName = '' }
        if ([string]::IsNullOrWhiteSpace($catName)) { continue }
        if ($checkedSet.ContainsKey($catName.Trim().ToLowerInvariant())) { $hit = $true; break }
      }
      if (-not $hit) { continue }
      $wantSet[$k] = $it
    }

    # Diff apply: avoid full unselect/reselect churn on each update.
    $selectedNow = @()
    try { $selectedNow = @($iconList.SelectedItems) } catch { $selectedNow = @() }
    foreach ($si in @($selectedNow)) {
      if (-not $si) { continue }
      $sk = ''
      try { $sk = [string]$si.Key } catch { $sk = '' }
      if ([string]::IsNullOrWhiteSpace($sk)) { continue }
      if (-not $wantSet.ContainsKey($sk)) {
        try { [void]$iconList.SelectedItems.Remove($si) } catch {}
      }
    }
    foreach ($wk in @($wantSet.Keys)) {
      $wi = $wantSet[$wk]
      if (-not $wi) { continue }
      try {
        if (-not $iconList.SelectedItems.Contains($wi)) {
          [void]$iconList.SelectedItems.Add($wi)
        }
      } catch {}
    }
  } catch {}
}

function Sync-IconSelectionToExtractMode {
  try {
    if (-not $iconList) { return }
    $visible = @()
    try { $visible = @($iconList.ItemsSource) } catch { $visible = @() }
    $selectedNow = @()
    try { $selectedNow = @($iconList.SelectedItems) } catch { $selectedNow = @() }
    foreach ($si in @($selectedNow)) {
      if (-not $si) { continue }
      $k = ''
      try { $k = [string]$si.Key } catch { $k = '' }
      if ([string]::IsNullOrWhiteSpace($k)) { continue }
      if (-not $script:ExtractSelectedKeys.ContainsKey($k)) {
        try { [void]$iconList.SelectedItems.Remove($si) } catch {}
      }
    }
    foreach ($it in @($visible)) {
      if (-not $it) { continue }
      $k = ''
      try { $k = [string]$it.Key } catch { $k = '' }
      if ([string]::IsNullOrWhiteSpace($k)) { continue }
      if ($script:ExtractSelectedKeys.ContainsKey($k)) {
        try { if (-not $iconList.SelectedItems.Contains($it)) { [void]$iconList.SelectedItems.Add($it) } } catch {}
      }
    }
  } catch {}
}

function Update-ExtractSelectionFlags {
  try {
    $on = [bool]$script:ExtractIconsMode
    foreach ($it in @($script:AllIcons.ToArray())) {
      if (-not $it) { continue }
      $k = ''
      try { $k = [string]$it.Key } catch { $k = '' }
      $isSel = $false
      if ($on -and -not [string]::IsNullOrWhiteSpace($k)) {
        try { $isSel = [bool]$script:ExtractSelectedKeys.ContainsKey($k) } catch { $isSel = $false }
      }
      try { $it.IsExtractSelected = [bool]$isSel } catch {}
    }
  } catch {}
}

function Set-ExtractModeState {
  param([bool]$Enabled)
  try {
    $script:ExtractIconsMode = [bool]$Enabled
    $blocked = [bool]$Enabled

    # Keep original visuals; block only LEFT panel during extract mode.
    try {
      if ($extractLeftOverlay) {
        $extractLeftOverlay.Visibility = $(if($blocked){ [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed })
        $extractLeftOverlay.IsHitTestVisible = $blocked
      }
    } catch {}
    # Right panel stays interactive while extracting.
    try {
      if ($extractRightOverlay) {
        $extractRightOverlay.Visibility = [System.Windows.Visibility]::Collapsed
        $extractRightOverlay.IsHitTestVisible = $false
      }
    } catch {}

    # Top panel action buttons: no overlay, just dim + block clicks.
    foreach ($btn in @($loadJsonBtn,$exportJsonBtn,$deleteSelectedCategoryBtn,$backupIconPackDirBtn,$refreshExternalBtn)) {
      try {
        if ($btn) {
          $btn.Opacity = $(if($blocked){ 0.45 } else { 1.0 })
          $btn.IsHitTestVisible = (-not $blocked)
        }
      } catch {}
    }

    try {
      if ($extractIconsBtn) {
        $extractIconsBtn.IsEnabled = $true
        $extractIconsBtn.Opacity = $(if([bool]$Enabled){ 1.0 } else { 0.45 })
        $extractIconsBtn.IsHitTestVisible = [bool]$Enabled
      }
    } catch {}
    if (-not [bool]$Enabled) {
      $script:ExtractSelectedKeys = @{}
      try { Sync-IconSelectionToCheckedCategories } catch {}
    } else {
      try { $iconList.UnselectAll() } catch {}
      try { Sync-IconSelectionToExtractMode } catch {}
    }
    try { Update-ExtractSelectionFlags } catch {}
    try { Refresh-AssignedVisual -SkipSelectionSync } catch { try { Refresh-AssignedVisual } catch {} }
    try {
      if ([bool]$Enabled) {
        $statusText.Text = 'Select icons to extract: enabled.'
      } else {
        $statusText.Text = 'Select icons to extract: disabled.'
      }
    } catch {}
  } catch {}
}

function Toggle-ExtractSelectionForIcons {
  param([object[]]$Icons)
  try {
    $targets = @($Icons | Where-Object { $_ })
    if (@($targets).Count -eq 0) { return }
    foreach ($it in @($targets)) {
      if (-not $it) { continue }
      $k = ''
      try { $k = [string]$it.Key } catch { $k = '' }
      if ([string]::IsNullOrWhiteSpace($k)) { continue }
      if ($script:ExtractSelectedKeys.ContainsKey($k)) {
        try { $script:ExtractSelectedKeys.Remove($k) } catch {}
      } else {
        $script:ExtractSelectedKeys[$k] = $true
      }
    }
    try { Update-ExtractSelectionFlags } catch {}
    try { Sync-IconSelectionToExtractMode } catch {}
    try { Refresh-AssignedVisual -SkipSelectionSync } catch { try { Refresh-AssignedVisual } catch {} }
    try { $statusText.Text = ("Extract selection: {0} icon(s)." -f [int]$script:ExtractSelectedKeys.Count) } catch {}
  } catch {}
}

function Get-ExtractOutputFormat {
  try {
    $script:ExtractFormatDialogResult = ''
    $dlg = New-Object System.Windows.Window
    $dlg.Title = 'Extract Format'
    $dlg.Width = 250
    $dlg.Height = 150
    $dlg.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $dlg.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterOwner
    $dlg.ShowInTaskbar = $false
    try { if ($window) { $dlg.Owner = $window } } catch {}

    try {
      $icoPath = [Environment]::ExpandEnvironmentVariables('%systemroot%\\system32\\shell32.dll')
      $ico = Get-IconImageSource -IconPath $icoPath -IconIndex 77
      if ($ico) { $dlg.Icon = $ico }
    } catch {}

    $root = New-Object System.Windows.Controls.Grid
    $root.Margin = '12'
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::Auto
    $r2 = New-Object System.Windows.Controls.RowDefinition; $r2.Height = [System.Windows.GridLength]::Auto
    [void]$root.RowDefinitions.Add($r1)
    [void]$root.RowDefinitions.Add($r2)

    $top = New-Object System.Windows.Controls.StackPanel
    $top.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    [System.Windows.Controls.Grid]::SetRow($top,0)

    $img = New-Object System.Windows.Controls.Image
    $img.Width = 24
    $img.Height = 24
    $img.Margin = '0,0,10,0'
    try {
      $imgPath = [Environment]::ExpandEnvironmentVariables('%systemroot%\\system32\\shell32.dll')
      $imgSrc = Get-IconImageSource -IconPath $imgPath -IconIndex 269
      if ($imgSrc) { $img.Source = $imgSrc }
    } catch {}
    [void]$top.Children.Add($img)

    $txt = New-Object System.Windows.Controls.TextBlock
    $txt.Text = 'Choose format for output.'
    $txt.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $txt.TextWrapping = [System.Windows.TextWrapping]::Wrap
    [void]$top.Children.Add($txt)
    [void]$root.Children.Add($top)

    $btnRow = New-Object System.Windows.Controls.StackPanel
    $btnRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $btnRow.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $btnRow.Margin = '0,14,0,0'
    [System.Windows.Controls.Grid]::SetRow($btnRow,1)

    $icoBtn = New-Object System.Windows.Controls.Button
    $icoBtn.Content = '.ico'
    $icoBtn.Width = 50
    $icoBtn.Height = 28
    $icoBtn.Margin = '0,0,8,0'
    $icoBtn.IsDefault = $true
    $icoBtn.Add_Click({ $script:ExtractFormatDialogResult = 'ico'; try { $dlg.DialogResult = $true } catch { $dlg.Close() } })
    [void]$btnRow.Children.Add($icoBtn)

    $pngBtn = New-Object System.Windows.Controls.Button
    $pngBtn.Content = '.png'
    $pngBtn.Width = 50
    $pngBtn.Height = 28
    $pngBtn.Margin = '0,0,30,0'
    $pngBtn.Add_Click({ $script:ExtractFormatDialogResult = 'png'; try { $dlg.DialogResult = $true } catch { $dlg.Close() } })
    [void]$btnRow.Children.Add($pngBtn)

    $cancelBtn = New-Object System.Windows.Controls.Button
    $cancelBtn.Content = 'Cancel'
    $cancelBtn.Width = 70
    $cancelBtn.Height = 28
    $cancelBtn.IsCancel = $true
    $cancelBtn.Add_Click({ $script:ExtractFormatDialogResult = ''; try { $dlg.DialogResult = $false } catch { $dlg.Close() } })
    [void]$btnRow.Children.Add($cancelBtn)

    [void]$root.Children.Add($btnRow)
    $dlg.Content = $root
    $null = $dlg.ShowDialog()
    return [string]$script:ExtractFormatDialogResult
  } catch {
    return ''
  }
}

function Save-IconRowToPng {
  param(
    [Parameter(Mandatory=$true)][object]$IconRow,
    [Parameter(Mandatory=$true)][string]$DestinationPath
  )
  try {
    if (-not $IconRow) { return $false }
    $iconPath = ''
    $iconIndex = 0
    try { $iconPath = [string]$IconRow.IconPath } catch { $iconPath = '' }
    try { $iconIndex = [int]$IconRow.IconIndex } catch { $iconIndex = 0 }
    if ([string]::IsNullOrWhiteSpace($iconPath)) { return $false }
    $src = $null
    try { $src = Get-IconImageSource -IconPath $iconPath -IconIndex $iconIndex } catch { $src = $null }
    if (-not $src) { return $false }
    $destDir = ''
    try { $destDir = [System.IO.Path]::GetDirectoryName([string]$DestinationPath) } catch { $destDir = '' }
    if (-not [string]::IsNullOrWhiteSpace($destDir)) { [void][System.IO.Directory]::CreateDirectory($destDir) }
    $fs = $null
    try {
      $fs = [System.IO.File]::Open($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
      $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
      [void]$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($src))
      $enc.Save($fs)
      return $true
    } finally {
      try { if ($fs) { $fs.Close() } } catch {}
    }
  } catch {
    return $false
  }
}

function Get-CategoryStateCounts {
  try {
    $sel = 0; $show = 0; $mask = 0
    foreach ($r in @($script:CategoryRows.ToArray())) {
      if (-not $r) { continue }
      try { if ([bool]$r.SelectChecked) { $sel++ } } catch {}
      try { if ([bool]$r.ShowChecked)   { $show++ } } catch {}
      try { if ([bool]$r.HideChecked)   { $mask++ } } catch {}
    }
    return [pscustomobject]@{ Select = [int]$sel; Show = [int]$show; Mask = [int]$mask }
  } catch {
    return [pscustomobject]@{ Select = 0; Show = 0; Mask = 0 }
  }
}

function Get-AssignedIconCountForCategories {
  param([string[]]$Categories)
  try {
    $set = @{}
    foreach ($c in @($Categories)) {
      $n = ''
      try { $n = [string]$c } catch { $n = '' }
      $n = $n.Trim()
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $set[$n.ToLowerInvariant()] = $true
    }
    if ($set.Count -le 0) { return 0 }
    $count = 0
    foreach ($k in @($script:AssignmentsByKey.Keys)) {
      $a = $null
      try { $a = $script:AssignmentsByKey[$k] } catch { $a = $null }
      if (-not $a) { continue }
      $matched = $false
      foreach ($cn in @($a.Categories)) {
        $n = ''
        try { $n = [string]$cn } catch { $n = '' }
        $n = $n.Trim()
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        if ($set.ContainsKey($n.ToLowerInvariant())) { $matched = $true; break }
      }
      if ($matched) { $count++ }
    }
    return [int]$count
  } catch {
    return 0
  }
}

function Export-ExtractSelectedIcons {
  try {
    $keys = @()
    try { $keys = @($script:ExtractSelectedKeys.Keys) } catch { $keys = @() }
    if (@($keys).Count -eq 0) {
      try { $statusText.Text = 'No icons selected for extraction.' } catch {}
      return
    }
    $fmt = Get-ExtractOutputFormat
    if ([string]::IsNullOrWhiteSpace($fmt)) { return }
    $ext = if ($fmt -eq 'png') { '.png' } else { '.ico' }

    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = ("Select destination folder for extracted {0} files" -f $ext)
    $dlg.ShowNewFolderButton = $true
    $dr = $dlg.ShowDialog()
    if ($dr -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $dest = ''
    try { $dest = [string]$dlg.SelectedPath } catch { $dest = '' }
    if ([string]::IsNullOrWhiteSpace($dest)) { return }
    if (-not (Test-Path -LiteralPath $dest -PathType Container)) {
      New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }

    $saved = 0
    foreach ($k in @($keys)) {
      $key = ''
      try { $key = [string]$k } catch { $key = '' }
      if ([string]::IsNullOrWhiteSpace($key)) { continue }
      $row = $null
      try { if ($script:IconsByKey.ContainsKey($key)) { $row = $script:IconsByKey[$key] } } catch { $row = $null }
      if (-not $row) { continue }
      $base = ''
      try { $base = Get-SafeFileNameSegment -Name ([string]$row.Label) } catch { $base = '' }
      if ([string]::IsNullOrWhiteSpace($base)) { $base = ('icon_{0}' -f ($saved + 1)) }
      $out = Join-Path $dest ($base + $ext)
      $n = 2
      while (Test-Path -LiteralPath $out -PathType Leaf) {
        $out = Join-Path $dest ("{0}_{1}{2}" -f $base, $n, $ext)
        $n++
      }
      $ok = $false
      if ($fmt -eq 'png') {
        $ok = [bool](Save-IconRowToPng -IconRow $row -DestinationPath $out)
      } else {
        $ok = [bool](Save-IconRowToIco -IconRow $row -DestinationPath $out)
      }
      if ($ok) { $saved++ }
    }
    try { $statusText.Text = ("Extracted {0} icon(s) as {1} to: {2}" -f $saved, $ext, $dest) } catch {}
  } catch {
    try { $statusText.Text = ("Extract failed: " + [string]$_.Exception.Message) } catch {}
  }
}

function Handle-CategoryCheckedChanged {
  param(
    [bool]$IsChecked,
    [string]$CategoryName = '',
    [ValidateSet('Select','Show','Hide','')]
    [string]$ColumnKind = ''
  )
  try {
    # Any Show/Mask toggle can change list membership; always force a full rebind.
    $needRebind = (($ColumnKind -eq 'Show') -or ($ColumnKind -eq 'Hide'))
    if ($needRebind) {
      Refresh-AssignedVisual -ForceRebind
    } else {
      Refresh-AssignedVisual
    }
    try {
      $kind = if ([string]::IsNullOrWhiteSpace($ColumnKind)) { 'category' } else { $ColumnKind.ToLowerInvariant() }
      $verb = if ($IsChecked) { 'checked' } else { 'unchecked' }
      $counts = Get-CategoryStateCounts
      $namePart = ''
      if (-not [string]::IsNullOrWhiteSpace($CategoryName)) { $namePart = (" '{0}'" -f [string]$CategoryName) }
      $statusText.Text = ("{0}{1} {2}. select:{3} show:{4} mask:{5}" -f $kind, $namePart, $verb, [int]$counts.Select, [int]$counts.Show, [int]$counts.Mask)
    } catch {}
  } catch {}
  try { Update-ToggleAllSelectCheckState } catch {}
  try { Update-ToggleAllCategoriesCheckState } catch {}
  try { Update-ToggleAllMaskCheckState } catch {}
  # Persist left-panel checkbox state immediately so exit timing can't lose it.
  try { Save-CategoryPanelState } catch {}
  $savedOk = $false
  try {
    $res = Save-CustomIconSourceDirectories
    try { $savedOk = [bool]$res.Ok } catch { $savedOk = $false }
  } catch { $savedOk = $false }
  if (-not $savedOk) {
    try { Save-CategoryPanelStateToStateFile | Out-Null } catch {}
  }
}

function Test-IconHasAnyAssignment {
  param([string]$Key)
  try {
    if ([string]::IsNullOrWhiteSpace($Key)) { return $false }
    if (-not $script:AssignmentsByKey.ContainsKey($Key)) { return $false }
    $a = $script:AssignmentsByKey[$Key]
    if (-not $a) { return $false }
    return (@($a.Categories).Count -gt 0)
  } catch { return $false }
}

function Test-IconHasAnyCommittedAssignment {
  param([string]$Key)
  try {
    if ([string]::IsNullOrWhiteSpace($Key)) { return $false }
    if (-not $script:BaselineAssignmentCategoriesByKey) { return $false }
    if (-not $script:BaselineAssignmentCategoriesByKey.ContainsKey($Key)) { return $false }
    $cats = @()
    try { $cats = @($script:BaselineAssignmentCategoriesByKey[$Key]) } catch { $cats = @() }
    return (@($cats).Count -gt 0)
  } catch { return $false }
}

function Get-IconPixelHashForRow {
  param([Parameter(Mandatory=$true)][object]$IconRow)
  try {
    $k = ''
    try { $k = [string]$IconRow.Key } catch { $k = '' }
    if (-not [string]::IsNullOrWhiteSpace($k) -and $script:IconPixelHashByKey.ContainsKey($k)) {
      return [string]$script:IconPixelHashByKey[$k]
    }

    $src = $null
    try { $src = $IconRow.Icon } catch { $src = $null }
    if (-not $src) {
      try { $src = Get-IconImageSource -IconPath ([string]$IconRow.IconPath) -IconIndex ([int]$IconRow.IconIndex) } catch { $src = $null }
      if ($src) { try { $IconRow.Icon = $src } catch {} }
    }
    if (-not $src) {
      if (-not [string]::IsNullOrWhiteSpace($k)) { $script:IconPixelHashByKey[$k] = '' }
      return ''
    }

    $bmp = $src -as [System.Windows.Media.Imaging.BitmapSource]
    if (-not $bmp) {
      if (-not [string]::IsNullOrWhiteSpace($k)) { $script:IconPixelHashByKey[$k] = '' }
      return ''
    }

    $fmt = $bmp.Format
    if (-not $fmt -or ($fmt -ne [System.Windows.Media.PixelFormats]::Bgra32)) {
      $conv = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap
      $conv.BeginInit()
      $conv.Source = $bmp
      $conv.DestinationFormat = [System.Windows.Media.PixelFormats]::Bgra32
      $conv.EndInit()
      try { $conv.Freeze() } catch {}
      $bmp = $conv
    }

    $w = [int]$bmp.PixelWidth
    $h = [int]$bmp.PixelHeight
    if ($w -le 0 -or $h -le 0) {
      if (-not [string]::IsNullOrWhiteSpace($k)) { $script:IconPixelHashByKey[$k] = '' }
      return ''
    }
    $stride = $w * 4
    $pixels = New-Object byte[] ($stride * $h)
    $bmp.CopyPixels($pixels, $stride, 0)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
      $hb = $sha.ComputeHash($pixels)
      $hash = [System.BitConverter]::ToString($hb).Replace('-','')
      if (-not [string]::IsNullOrWhiteSpace($k)) { $script:IconPixelHashByKey[$k] = $hash }
      return $hash
    } finally {
      try { if ($sha) { $sha.Dispose() } } catch {}
    }
  } catch {
    return ''
  }
}

function Get-IconSearchBlobForRow {
  param([Parameter(Mandatory=$true)][object]$IconRow)
  try {
    $k = ''
    try { $k = [string]$IconRow.Key } catch { $k = '' }
    if (-not [string]::IsNullOrWhiteSpace($k) -and $script:IconSearchTextByKey.ContainsKey($k)) {
      return [string]$script:IconSearchTextByKey[$k]
    }
    $lbl = ''
    $ip = ''
    try { $lbl = [string]$IconRow.Label } catch { $lbl = '' }
    try { $ip = [string]$IconRow.IconPath } catch { $ip = '' }
    $blob = ''
    try { $blob = ("{0} {1}" -f $lbl, $ip).ToLowerInvariant() } catch { $blob = '' }
    if (-not [string]::IsNullOrWhiteSpace($k)) { $script:IconSearchTextByKey[$k] = $blob }
    return $blob
  } catch {
    return ''
  }
}

function Get-FilteredIcons {
  $q = ''
  try { $q = [string]$iconSearchBox.Text } catch { $q = '' }
  $q = $q.Trim().ToLowerInvariant()
  $showCats = @()
  $hideCats = @()
  $showKey = ''
  $hideKey = ''
  try {
    $showCats = @(Get-ShownCategories)
    $showKey = [string]((@($showCats) | ForEach-Object { try { ([string]$_).Trim().ToLowerInvariant() } catch { '' } } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique) -join ';')
    $hideCats = @(Get-HiddenCategories)
    $hideKey = [string]((@($hideCats) | ForEach-Object { try { ([string]$_).Trim().ToLowerInvariant() } catch { '' } } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique) -join ';')
  } catch { $showCats = @(); $hideCats = @(); $showKey = ''; $hideKey = '' }
  $cacheKey = ''
  try {
    $cacheKey = ("{0}|all={1}|show={2}|hide={3}|dup={4}|uncat={5}|unmask={6}|ver={7}" -f $q, [int]([bool]$script:ShowAllIcons), $showKey, $hideKey, [int]([bool]$script:HidePixelDuplicates), [int]([bool]$script:ShowUncategorizedOnly), [int]([bool]$script:UnmaskSharedIcons), [int]$script:AssignmentVersion)
  } catch { $cacheKey = $q }
  try {
    if ($null -ne $script:IconFilterCacheQuery -and $script:IconFilterCacheQuery -eq $cacheKey) {
      return @($script:IconFilterCacheItems)
    }
  } catch {}

  $allRows = @()
  try {
    $srcSeen = @{}
    $srcRows = New-Object System.Collections.Generic.List[object]
    foreach ($src in @((Get-EffectiveBuiltInSourceEntries) + @($script:CustomIconSourceDirs.ToArray()))) {
      $disp = Normalize-SourcePathForDisplay ([string]$src)
      if ([string]::IsNullOrWhiteSpace($disp)) { continue }
      $skey = Get-SourcePathKey $disp
      if ([string]::IsNullOrWhiteSpace($skey)) { continue }
      if ($srcSeen.ContainsKey($skey)) { continue }
      $srcSeen[$skey] = $true
      $show = $true
      try { $show = [bool](Get-SourcePathVisibility -Path $disp) } catch { $show = $true }
      $resolved = Normalize-Path $disp
      if ([string]::IsNullOrWhiteSpace($resolved) -or -not (Test-Path -LiteralPath $resolved)) { continue }
      $isDir = $false
      try { $isDir = [bool](Test-Path -LiteralPath $resolved -PathType Container) } catch { $isDir = $false }
      [void]$srcRows.Add([pscustomobject]@{
        Path = [string]$resolved
        IsDirectory = [bool]$isDir
        Show = [bool]$show
      })
    }

    if (@($srcRows.ToArray()).Count -eq 0) {
      $allRows = @()
    } else {
      $allVisible = $true
      foreach ($sr in @($srcRows.ToArray())) {
        if (-not $sr) { continue }
        if (-not [bool]$sr.Show) { $allVisible = $false; break }
      }
      if ($allVisible) {
        $allRows = @($script:AllIcons.ToArray())
      } else {
      $enabledFiles = New-Object 'System.Collections.Generic.HashSet[string]'
      $enabledDirPrefixes = New-Object System.Collections.Generic.List[string]
      foreach ($sr in @($srcRows.ToArray())) {
        if (-not $sr) { continue }
        if (-not [bool]$sr.Show) { continue }
        $rp = ''
        $isDir = $false
        try { $rp = [string]$sr.Path } catch { $rp = '' }
        try { $isDir = [bool]$sr.IsDirectory } catch { $isDir = $false }
        if ([string]::IsNullOrWhiteSpace($rp)) { continue }
        if ($isDir) {
          $prefix = ($rp.TrimEnd('\') + '\').ToLowerInvariant()
          [void]$enabledDirPrefixes.Add($prefix)
        } else {
          [void]$enabledFiles.Add($rp.ToLowerInvariant())
        }
      }

      $rows = New-Object System.Collections.Generic.List[object]
      foreach ($row in @($script:AllIcons.ToArray())) {
        if (-not $row) { continue }
        $ip = ''
        try { $ip = [string]$row.IconPath } catch { $ip = '' }
        if ([string]::IsNullOrWhiteSpace($ip)) { continue }
        $ipl = $ip.ToLowerInvariant()
        if ($enabledFiles.Contains($ipl)) {
          [void]$rows.Add($row)
          continue
        }
        $matchedDir = $false
        foreach ($dp in @($enabledDirPrefixes.ToArray())) {
          if ([string]::IsNullOrWhiteSpace($dp)) { continue }
          if ($ipl.StartsWith($dp, [System.StringComparison]::OrdinalIgnoreCase)) { $matchedDir = $true; break }
        }
        if ($matchedDir) { [void]$rows.Add($row) }
      }
        $allRows = @($rows.ToArray())
      }
    }
  } catch {
    $allRows = @()
  }

  $items = @()
  if ([bool]$script:ShowUncategorizedOnly) {
    # Override category visibility filters and show only icons that have no COMMITTED category assignment.
    # Pending edits are not treated as committed until Save Category is executed.
    $items = @(
      @($allRows) | Where-Object {
        $k = ''
        try { $k = [string]$_.Key } catch { $k = '' }
        if ([string]::IsNullOrWhiteSpace($k)) { return $false }
        -not [bool](Test-IconHasAnyCommittedAssignment -Key $k)
      }
    )
  } elseif ([bool]$script:ShowAllIcons) {
    # "Show all" honors hidden categories, with optional unmask override for Show-matched shared icons.
    if (@($hideCats).Count -gt 0) {
      if ([bool]$script:UnmaskSharedIcons -and @($showCats).Count -gt 0) {
        $baseItems = @(Get-FilteredRowsByCategorySelection -ShowCategories @() -HideCategories @($hideCats))
        $showItems = @(Get-FilteredRowsByCategorySelection -ShowCategories @($showCats) -HideCategories @())
        $keep = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($it in @($baseItems)) {
          if (-not $it) { continue }
          $k = ''
          try { $k = [string]$it.Key } catch { $k = '' }
          if ([string]::IsNullOrWhiteSpace($k)) { continue }
          try { [void]$keep.Add($k) } catch {}
        }
        foreach ($it in @($showItems)) {
          if (-not $it) { continue }
          $k = ''
          try { $k = [string]$it.Key } catch { $k = '' }
          if ([string]::IsNullOrWhiteSpace($k)) { continue }
          try { [void]$keep.Add($k) } catch {}
        }
        $merged = New-Object System.Collections.Generic.List[object]
        foreach ($r in @($allRows)) {
          if (-not $r) { continue }
          $k = ''
          try { $k = [string]$r.Key } catch { $k = '' }
          if ([string]::IsNullOrWhiteSpace($k)) { continue }
          if (-not $keep.Contains($k)) { continue }
          [void]$merged.Add($r)
        }
        $items = @($merged.ToArray())
      } else {
        $items = @(Get-FilteredRowsByCategorySelection -ShowCategories @() -HideCategories @($hideCats))
      }
    } else {
      $items = @($allRows)
    }
  } else {
    # Keep base Show/Mask behavior identical to v0.97.
    # Optional unmask mode only affects shared-icon conflicts (Show wins for overlaps).
    if ([bool]$script:UnmaskSharedIcons -and @($showCats).Count -gt 0 -and @($hideCats).Count -gt 0) {
      $items = @(Get-FilteredRowsByCategorySelection -ShowCategories @($showCats) -HideCategories @())
    } else {
      # Fast path: resolve category membership first, then only process matching rows.
      # This avoids scanning every icon row on each category toggle.
      $items = @(Get-FilteredRowsByCategorySelection -ShowCategories @($showCats) -HideCategories @($hideCats))
    }
    # When "Show all" is off, keep pending assignment edits visible so removals do not
    # disappear immediately during selection. Preserve original icon-grid ordering.
    try {
      $pendingKeep = New-Object 'System.Collections.Generic.HashSet[string]'
      foreach ($it in @($items)) {
        if (-not $it) { continue }
        $k = ''
        try { $k = [string]$it.Key } catch { $k = '' }
        if ([string]::IsNullOrWhiteSpace($k)) { continue }
        [void]$pendingKeep.Add($k)
      }
      foreach ($row in @($allRows)) {
        if (-not $row) { continue }
        $rk = ''
        try { $rk = [string]$row.Key } catch { $rk = '' }
        if ([string]::IsNullOrWhiteSpace($rk)) { continue }
        if ($pendingKeep.Contains($rk)) { continue }
        $isPending = $false
        try { $isPending = [bool](Test-AssignmentPendingByKey -Key $rk) } catch { $isPending = $false }
        if (-not $isPending) { continue }
        [void]$pendingKeep.Add($rk)
      }
      $ordered = New-Object System.Collections.Generic.List[object]
      foreach ($row in @($allRows)) {
        if (-not $row) { continue }
        $rk = ''
        try { $rk = [string]$row.Key } catch { $rk = '' }
        if ([string]::IsNullOrWhiteSpace($rk)) { continue }
        if (-not $pendingKeep.Contains($rk)) { continue }
        [void]$ordered.Add($row)
      }
      $items = @($ordered.ToArray())
    } catch {}
  }
  if (-not [string]::IsNullOrWhiteSpace($q)) {
    $matches = New-Object System.Collections.Generic.List[object]
    foreach ($it in @($items)) {
      if (-not $it) { continue }
      $blob = ''
      try { $blob = [string](Get-IconSearchBlobForRow -IconRow $it) } catch { $blob = '' }
      if (-not [string]::IsNullOrWhiteSpace($blob) -and $blob.Contains($q)) {
        [void]$matches.Add($it)
      }
    }
    $items = @($matches.ToArray())
  }

  if ([bool]$script:HidePixelDuplicates) {
    $seenHashes = @{}
    $unique = New-Object System.Collections.Generic.List[object]
    foreach ($it in @($items)) {
      if (-not $it) { continue }
      $h = [string](Get-IconPixelHashForRow -IconRow $it)
      if ([string]::IsNullOrWhiteSpace($h)) {
        [void]$unique.Add($it)
        continue
      }
      if ($seenHashes.ContainsKey($h)) { continue }
      $seenHashes[$h] = $true
      [void]$unique.Add($it)
    }
    $items = @($unique.ToArray())
  }

  try {
    $script:IconFilterCacheQuery = $cacheKey
    $script:IconFilterCacheItems = @($items)
  } catch {}
  return @($items)
}

function Refresh-IconListPage {
  $filtered = @(Get-FilteredIcons)
  $shownSet = Get-ShownCategorySet
  $checkedSet = Get-CheckedCategorySet
  $hasSelectTargets = $false
  try { $hasSelectTargets = ($checkedSet -and $checkedSet.Count -gt 0) } catch { $hasSelectTargets = $false }
  $total = @($filtered).Count
  $pageSize = 800
  try { $pageSize = [Math]::Max(40, [int]$script:IconPageSize) } catch { $pageSize = 600 }
  $pages = 1
  if ($total -gt 0) { $pages = [Math]::Max(1, [int][Math]::Ceiling([double]$total / [double]$pageSize)) }
  $page = 1
  try { $page = [int]$script:IconCurrentPage } catch { $page = 1 }
  if ($page -lt 1) { $page = 1 }
  if ($page -gt $pages) { $page = $pages }
  $script:IconCurrentPage = $page

  $skip = ($page - 1) * $pageSize
  if ($skip -lt 0) { $skip = 0 }
  $src = New-Object System.Collections.Generic.List[object]
  if ($total -gt 0) {
    $endExclusive = [Math]::Min($total, $skip + $pageSize)
    for ($i = $skip; $i -lt $endExclusive; $i++) {
      [void]$src.Add($filtered[$i])
    }
  }

  foreach ($it in @($src.ToArray())) {
    if (-not $it) { continue }
    if (-not $it.Icon) {
      try { $it.Icon = Get-IconImageSource -IconPath ([string]$it.IconPath) -IconIndex ([int]$it.IconIndex) } catch {}
    }
    $k = ''
    try { $k = [string]$it.Key } catch { $k = '' }
    $entry = $null
    try { if (-not [string]::IsNullOrWhiteSpace($k) -and $script:AssignmentsByKey.ContainsKey($k)) { $entry = $script:AssignmentsByKey[$k] } } catch { $entry = $null }
    try { $it.IsAssignedActive = [bool](Test-EntryMatchesCheckedSet -Entry $entry -CheckedSet $shownSet) } catch {}
    try {
      if ([bool]$script:ShowUncategorizedOnly) {
        $it.IsCategorized = [bool](Test-IconHasAnyCommittedAssignment -Key $k)
      } else {
        $it.IsCategorized = [bool](Test-IconHasAnyAssignment -Key $k)
      }
    } catch {}
    try { $it.HasSelectTargets = [bool]$hasSelectTargets } catch {}
    try { $it.SelectDeltaKind = [string](Get-SelectDeltaKindByKey -Key $k -CheckedSet $checkedSet) } catch { try { $it.SelectDeltaKind = 'None' } catch {} }
    try { $it.IsPendingExport = [bool](Test-AssignmentPendingByKey -Key $k) } catch {}
    try { $it.IsExtractSelected = ([bool]$script:ExtractIconsMode -and [bool]$script:ExtractSelectedKeys.ContainsKey($k)) } catch {}
  }

  try { $iconList.ItemsSource = @($src.ToArray()) } catch {}
  try { if ($iconPrevPageBtn) { $iconPrevPageBtn.IsEnabled = ($page -gt 1) } } catch {}
  try { if ($iconNextPageBtn) { $iconNextPageBtn.IsEnabled = ($page -lt $pages) } } catch {}
  try { if ($iconCountText) { $iconCountText.Text = ("showing {0} icons" -f $total) } } catch {}
  try { if ($iconPageText) { $iconPageText.Text = ("Page {0}/{1}" -f $page, $pages) } } catch {}
}

function Add-Category {
  param(
    [string]$Name,
    [bool]$SelectOnlyNew = $true,
    [bool]$RefreshUI = $true
  )
  $n = ''
  try { $n = [string]$Name } catch { $n = '' }
  $n = $n.Trim()
  if ([string]::IsNullOrWhiteSpace($n)) { return $false }
  foreach ($c in @($script:CategoryRows.ToArray())) {
    $cn = ''
    try { $cn = [string]$c.Name } catch { $cn = '' }
    if ($cn.Trim().ToLowerInvariant() -eq $n.ToLowerInvariant()) {
      if ($RefreshUI) {
        Refresh-CategoryList
        Refresh-AssignedVisual
      }
      return $true
    }
  }
  [void]$script:CategoryRows.Add([pscustomobject]@{ Name = $n; SelectChecked = $false; ShowChecked = $false; HideChecked = $false; LastCommittedName = $n })
  if ($RefreshUI) {
    Refresh-CategoryList
    Refresh-AssignedVisual
  }
  return $true
}

function Commit-CategoryRename {
  param(
    [Parameter(Mandatory=$true)]$Row,
    [string]$NewName
  )
  try {
    if (-not $Row) { return $false }
    $old = ''
    try { $old = [string]$Row.LastCommittedName } catch { $old = '' }
    if ([string]::IsNullOrWhiteSpace($old)) {
      try { $old = [string]$Row.Name } catch { $old = '' }
    }
    $old = $old.Trim()
    if ([string]::IsNullOrWhiteSpace($old)) { return $false }

    $new = ''
    try { $new = [string]$NewName } catch { $new = '' }
    $new = $new.Trim()
    if ([string]::IsNullOrWhiteSpace($new)) {
      try { $Row.Name = $old } catch {}
      try { $Row.LastCommittedName = $old } catch {}
      return $false
    }

    foreach ($c in @($script:CategoryRows.ToArray())) {
      if (-not $c -or $c -eq $Row) { continue }
      $cn = ''
      try { $cn = [string]$c.Name } catch { $cn = '' }
      $cn = $cn.Trim()
      if ([string]::IsNullOrWhiteSpace($cn)) { continue }
      if ($cn.ToLowerInvariant() -eq $new.ToLowerInvariant()) {
        try { $Row.Name = $old } catch {}
        try { $Row.LastCommittedName = $old } catch {}
        try { $statusText.Text = ("Category rename blocked: '{0}' already exists." -f $cn) } catch {}
        return $false
      }
    }

    if ($new.ToLowerInvariant() -eq $old.ToLowerInvariant()) {
      try { $Row.Name = $new } catch {}
      try { $Row.LastCommittedName = $new } catch {}
      return $true
    }

    $changedIcons = 0
    foreach ($k in @($script:AssignmentsByKey.Keys)) {
      if (-not $script:AssignmentsByKey.ContainsKey($k)) { continue }
      $entry = $script:AssignmentsByKey[$k]
      if (-not $entry) { continue }
      $cats = @()
      try { $cats = @($entry.Categories) } catch { $cats = @() }
      if (@($cats).Count -eq 0) { continue }

      $newCats = New-Object System.Collections.Generic.List[string]
      $seen = @{}
      $entryChanged = $false
      foreach ($cat in $cats) {
        $catName = ''
        try { $catName = [string]$cat } catch { $catName = '' }
        $catName = $catName.Trim()
        if ([string]::IsNullOrWhiteSpace($catName)) { continue }
        $mapped = $catName
        if ($catName.ToLowerInvariant() -eq $old.ToLowerInvariant()) {
          $mapped = $new
          $entryChanged = $true
        }
        $mk = $mapped.ToLowerInvariant()
        if ($seen.ContainsKey($mk)) { continue }
        $seen[$mk] = $true
        [void]$newCats.Add($mapped)
      }
      if ($entryChanged) {
        $entry.Categories = $newCats
        $changedIcons++
        try {
          if ($script:IconsByKey.ContainsKey($k)) {
            $ri = $script:IconsByKey[$k]
            if ($ri) { try { $ri.IsPendingExport = $true } catch {} }
          }
        } catch {}
      }
    }

    try { $Row.Name = $new } catch {}
    try { $Row.LastCommittedName = $new } catch {}
    if ($changedIcons -gt 0) {
      try { Invalidate-AssignmentDerivedCaches -BumpVersion } catch {}
    }
    try { Refresh-AssignedVisual } catch {}
    try { $statusText.Text = ("Category renamed: '{0}' -> '{1}' ({2} icon assignment row(s) updated)." -f $old, $new, [int]$changedIcons) } catch {}
    return $true
  } catch {
    try { $statusText.Text = ("Category rename failed: " + [string]$_.Exception.Message) } catch {}
    return $false
  }
}

function Remove-AssignmentsForCategory {
  param([string]$CategoryName)
  $n = ''
  try { $n = [string]$CategoryName } catch { $n = '' }
  $n = $n.Trim()
  if ([string]::IsNullOrWhiteSpace($n)) { return 0 }

  $removedFromIcons = 0
  foreach ($k in @($script:AssignmentsByKey.Keys)) {
    $entry = $null
    try { $entry = $script:AssignmentsByKey[$k] } catch { $entry = $null }
    if (-not $entry) { continue }
    $before = @($entry.Categories).Count
    if ($before -le 0) { continue }

    $newCats = New-Object System.Collections.Generic.List[string]
    foreach ($c in @($entry.Categories)) {
      $cn = ''
      try { $cn = [string]$c } catch { $cn = '' }
      if ([string]::IsNullOrWhiteSpace($cn)) { continue }
      if ($cn.Trim().ToLowerInvariant() -eq $n.ToLowerInvariant()) { continue }
      [void]$newCats.Add($cn)
    }

    $after = @($newCats).Count
    if ($after -lt $before) {
      $removedFromIcons++
      if ($after -eq 0) {
        [void]$script:AssignmentsByKey.Remove($k)
      } else {
        $entry.Categories = $newCats
      }
      try {
        if ($script:IconsByKey.ContainsKey($k)) {
          $ri = $script:IconsByKey[$k]
          if ($ri) { try { $ri.IsPendingExport = $true } catch {} }
        }
      } catch {}
    }
  }
  if ($removedFromIcons -gt 0) {
    try { Invalidate-AssignmentDerivedCaches -BumpVersion } catch {}
  }
  return [int]$removedFromIcons
}

function Delete-SelectedCategories {
  try {
    $cats = @(Get-CheckedCategories)
    if (@($cats).Count -le 0) {
      try { $statusText.Text = 'No selected categories to delete.' } catch {}
      return
    }

    $uniq = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($c in @($cats)) {
      $n = ''
      try { $n = [string]$c } catch { $n = '' }
      $n = $n.Trim()
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $k = $n.ToLowerInvariant()
      if ($seen.ContainsKey($k)) { continue }
      $seen[$k] = $true
      [void]$uniq.Add($n)
    }
    if (@($uniq.ToArray()).Count -le 0) {
      try { $statusText.Text = 'No selected categories to delete.' } catch {}
      return
    }

    $listText = [string]::Join([Environment]::NewLine, @($uniq.ToArray()))
    $msg = "Delete selected categories from the list?`n`n" + $listText + "`n`nThis cannot be undone."
    $res = [System.Windows.MessageBox]::Show(
      $msg,
      'Delete Selected Catgory',
      [System.Windows.MessageBoxButton]::YesNo,
      [System.Windows.MessageBoxImage]::Warning
    )
    if ($res -ne [System.Windows.MessageBoxResult]::Yes) {
      try { $statusText.Text = 'Category deletion canceled.' } catch {}
      return
    }

    $removedCats = 0
    $removedAssignments = 0
    $deletedFiles = 0

    foreach ($cn in @($uniq.ToArray())) {
      try { $removedAssignments += [int](Remove-AssignmentsForCategory -CategoryName $cn) } catch {}

      # Remove from in-memory category list.
      for ($i = [int]$script:CategoryRows.Count - 1; $i -ge 0; $i--) {
        $row = $null
        try { $row = $script:CategoryRows[$i] } catch { $row = $null }
        if (-not $row) { continue }
        $rn = ''
        try { $rn = [string]$row.Name } catch { $rn = '' }
        $rn = $rn.Trim()
        if ([string]::IsNullOrWhiteSpace($rn)) { continue }
        if ($rn.ToLowerInvariant() -ne $cn.ToLowerInvariant()) { continue }
        try { $script:CategoryRows.RemoveAt($i) } catch {}
        $removedCats++
      }

      # Remove persisted category profile files so deleted categories do not reappear.
      try {
        $root = Get-IconCategoryProfilesRoot
        if (-not [string]::IsNullOrWhiteSpace($root) -and (Test-Path -LiteralPath $root -PathType Container)) {
          $cands = New-Object System.Collections.Generic.List[string]
          [void]$cands.Add((Join-Path $root ($cn + '.json')))
          try {
            $safe = Get-SafeFileNameSegment -Name $cn
            if (-not [string]::IsNullOrWhiteSpace($safe)) { [void]$cands.Add((Join-Path $root ($safe + '.json'))) }
          } catch {}
          $seenFile = @{}
          foreach ($fp in @($cands.ToArray())) {
            $fk = ''
            try { $fk = [string]$fp } catch { $fk = '' }
            if ([string]::IsNullOrWhiteSpace($fk)) { continue }
            $lk = $fk.ToLowerInvariant()
            if ($seenFile.ContainsKey($lk)) { continue }
            $seenFile[$lk] = $true
            if (Test-Path -LiteralPath $fp -PathType Leaf) {
              try { Remove-Item -LiteralPath $fp -Force -ErrorAction Stop; $deletedFiles++ } catch {}
            }
          }
        }
      } catch {}
    }

    try { Refresh-CategoryList } catch {}
    try { Refresh-AssignedVisual -ForceRebind } catch { try { Refresh-AssignedVisual } catch {} }
    try { Update-ToggleAllSelectCheckState } catch {}
    try { Update-ToggleAllCategoriesCheckState } catch {}
    try { Update-ToggleAllMaskCheckState } catch {}

    try {
      $statusText.Text = ("Deleted categories: {0}. Removed assignment groups: {1}. Deleted profile files: {2}." -f [int]$removedCats, [int]$removedAssignments, [int]$deletedFiles)
    } catch {}
  } catch {
    try { $statusText.Text = ("Delete selected category failed: " + [string]$_.Exception.Message) } catch {}
  }
}

function Assign-IconsToCheckedCategories {
  param(
    [object[]]$Icons,
    [switch]$SkipRefresh
  )
  $cats = @(Get-CheckedCategories)
  if (@($cats).Count -eq 0) { return }
  $changedAny = $false
  foreach ($it in @($Icons)) {
    if (-not $it) { continue }
    $k = [string]$it.Key
    if ([string]::IsNullOrWhiteSpace($k)) { continue }
    if (-not $script:AssignmentsByKey.ContainsKey($k)) {
      $script:AssignmentsByKey[$k] = [pscustomobject]@{
        IconPath = [string]$it.IconPath
        IconIndex = [int]$it.IconIndex
        Categories = New-Object System.Collections.Generic.List[string]
      }
    }
    $entry = $script:AssignmentsByKey[$k]
    $set = @{}
    $changedForThisIcon = $false
    foreach ($c in @($entry.Categories)) { $set[[string]$c] = $true }
    foreach ($c in $cats) {
      if (-not $set.ContainsKey([string]$c)) {
        [void]$entry.Categories.Add([string]$c)
        $set[[string]$c] = $true
        $changedForThisIcon = $true
      }
    }
    if ($changedForThisIcon) {
      $changedAny = $true
      try { $it.IsPendingExport = $true } catch {}
    }
  }
  if ($changedAny) {
    try { Invalidate-AssignmentDerivedCaches -BumpVersion } catch {}
  }
  if (-not $SkipRefresh) {
    Refresh-AssignedVisual
  }
}

function Test-IconAssignedToAllCategories {
  param(
    [Parameter(Mandatory=$true)]$Icon,
    [string[]]$Categories
  )
  try {
    if (-not $Icon) { return $false }
    $k = ''
    try { $k = [string]$Icon.Key } catch { $k = '' }
    if ([string]::IsNullOrWhiteSpace($k)) { return $false }
    if (-not @($Categories) -or @($Categories).Count -eq 0) { return $false }
    if (-not $script:AssignmentsByKey.ContainsKey($k)) { return $false }
    $entry = $script:AssignmentsByKey[$k]
    if (-not $entry) { return $false }
    $set = @{}
    foreach ($c in @($entry.Categories)) {
      $cn = ''
      try { $cn = [string]$c } catch { $cn = '' }
      $cn = $cn.Trim()
      if ([string]::IsNullOrWhiteSpace($cn)) { continue }
      $set[$cn.ToLowerInvariant()] = $true
    }
    foreach ($cat in @($Categories)) {
      $n = ''
      try { $n = [string]$cat } catch { $n = '' }
      $n = $n.Trim()
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      if (-not $set.ContainsKey($n.ToLowerInvariant())) { return $false }
    }
    return $true
  } catch { return $false }
}

function Remove-IconsFromCheckedCategories {
  param(
    [object[]]$Icons,
    [string[]]$Categories
  )
  $changed = 0
  if (-not @($Categories) -or @($Categories).Count -eq 0) { return 0 }
  foreach ($it in @($Icons)) {
    if (-not $it) { continue }
    $k = ''
    try { $k = [string]$it.Key } catch { $k = '' }
    if ([string]::IsNullOrWhiteSpace($k)) { continue }
    if (-not $script:AssignmentsByKey.ContainsKey($k)) { continue }
    $entry = $script:AssignmentsByKey[$k]
    if (-not $entry) { continue }

    $before = @($entry.Categories).Count
    if ($before -le 0) { continue }
    $newCats = New-Object System.Collections.Generic.List[string]
    foreach ($c in @($entry.Categories)) {
      $cn = ''
      try { $cn = [string]$c } catch { $cn = '' }
      $cn = $cn.Trim()
      if ([string]::IsNullOrWhiteSpace($cn)) { continue }
      if (@($Categories) -contains $cn) { continue }
      [void]$newCats.Add($cn)
    }
    $after = @($newCats).Count
    if ($after -lt $before) {
      $changed++
      if ($after -eq 0) {
        [void]$script:AssignmentsByKey.Remove($k)
        try { $it.IsAssignedActive = $false } catch {}
        try { $it.IsPendingExport = $true } catch {}
      } else {
        $entry.Categories = $newCats
        try { $it.IsAssignedActive = $true } catch {}
        try { $it.IsPendingExport = $true } catch {}
      }
    }
  }
  if ($changed -gt 0) {
    try { Invalidate-AssignmentDerivedCaches -BumpVersion } catch {}
  }
  return [int]$changed
}

function Toggle-IconsForCheckedCategories {
  param([object[]]$Icons)
  $cats = @(Get-CheckedCategories)
  $targets = @($Icons | Where-Object { $_ })
  if (@($targets).Count -eq 0) { return }

  if (@($cats).Count -eq 0) {
    # No checked category: reconcile clicked icons back to baseline assignment state.
    # This clears stale pending borders without mutating unchanged baseline-assigned icons.
    $changed = 0
    foreach ($it in @($targets)) {
      if (-not $it) { continue }
      $k = ''
      try { $k = [string]$it.Key } catch { $k = '' }
      if ([string]::IsNullOrWhiteSpace($k)) { continue }

      $baseCats = @()
      try {
        if ($script:BaselineAssignmentCategoriesByKey -and $script:BaselineAssignmentCategoriesByKey.ContainsKey($k)) {
          $baseCats = @($script:BaselineAssignmentCategoriesByKey[$k])
        }
      } catch { $baseCats = @() }

      $currentSig = ''
      $baseSig = ''
      try {
        if ($script:AssignmentsByKey.ContainsKey($k)) {
          $currentSig = [string](Get-AssignmentCategorySignature -Entry $script:AssignmentsByKey[$k])
        }
      } catch { $currentSig = '' }
      try { $baseSig = [string](Get-NormalizedCategorySignature -Categories @($baseCats)) } catch { $baseSig = '' }
      if ($currentSig -eq $baseSig) { continue }

      if (@($baseCats).Count -eq 0) {
        try {
          if ($script:AssignmentsByKey.ContainsKey($k)) {
            [void]$script:AssignmentsByKey.Remove($k)
            $changed++
          }
        } catch {}
      } else {
        if (-not $script:AssignmentsByKey.ContainsKey($k)) {
          $ip = ''
          $ii = 0
          try { $ip = [string]$it.IconPath } catch { $ip = '' }
          try { $ii = [int]$it.IconIndex } catch { $ii = 0 }
          $script:AssignmentsByKey[$k] = [pscustomobject]@{
            IconPath = [string]$ip
            IconIndex = [int]$ii
            Categories = New-Object System.Collections.Generic.List[string]
          }
        }
        try {
          $clean = New-Object System.Collections.Generic.List[string]
          $seen = @{}
          foreach ($c in @($baseCats)) {
            $n = ''
            try { $n = [string]$c } catch { $n = '' }
            $n = $n.Trim()
            if ([string]::IsNullOrWhiteSpace($n)) { continue }
            $lk = $n.ToLowerInvariant()
            if ($seen.ContainsKey($lk)) { continue }
            $seen[$lk] = $true
            [void]$clean.Add($n)
          }
          $script:AssignmentsByKey[$k].Categories = $clean
          $changed++
        } catch {}
      }
    }

    if ($changed -le 0) {
      try { Update-VisibleIconAssignedState } catch {}
      try { Sync-SelectionForSpecificIcons -Icons $targets } catch {}
      try { Refresh-IconContainerStylesForItems -Items $targets } catch {}
      $statusText.Text = 'Nothing to deselect for clicked icon(s).'
      return
    }

    try { Invalidate-AssignmentDerivedCaches -BumpVersion } catch {}
    $needRebindAfterMutate = $false
    try { $needRebindAfterMutate = (-not [bool]$script:ShowAllIcons) -or (@(Get-HiddenCategories).Count -gt 0) } catch { $needRebindAfterMutate = $false }
    if ($needRebindAfterMutate) {
      Refresh-AssignedVisual -ForceRebind -SkipSelectionSync
    } else {
      Refresh-AssignedVisual -SkipSelectionSync
    }
    try { Sync-SelectionForSpecificIcons -Icons $targets } catch {}
    try { Refresh-IconContainerStylesForItems -Items $targets } catch {}
    $statusText.Text = ("Deselected {0} icon(s)." -f [int]$changed)
    return
  }

  $allAssigned = $true
  foreach ($it in @($targets)) {
    if (-not (Test-IconAssignedToAllCategories -Icon $it -Categories @($cats))) {
      $allAssigned = $false
      break
    }
  }

  if ($allAssigned) {
    $removed = Remove-IconsFromCheckedCategories -Icons $targets -Categories @($cats)
    $needRebindAfterMutate = $false
    try { $needRebindAfterMutate = (-not [bool]$script:ShowAllIcons) -or (@(Get-HiddenCategories).Count -gt 0) } catch { $needRebindAfterMutate = $false }
    if ($needRebindAfterMutate) {
      Refresh-AssignedVisual -ForceRebind -SkipSelectionSync
    } else {
      Refresh-AssignedVisual -SkipSelectionSync
    }
    try { Sync-SelectionForSpecificIcons -Icons $targets } catch {}
    try { Refresh-IconContainerStylesForItems -Items $targets } catch {}
    $statusText.Text = ("Deselected {0} icon(s) from {1} categor{2}." -f [int]$removed, @($cats).Count, $(if(@($cats).Count -eq 1){'y'}else{'ies'}))
  } else {
    Assign-IconsToCheckedCategories -Icons $targets -SkipRefresh
    $needRebindAfterMutate = $false
    try { $needRebindAfterMutate = (-not [bool]$script:ShowAllIcons) -or (@(Get-HiddenCategories).Count -gt 0) } catch { $needRebindAfterMutate = $false }
    if ($needRebindAfterMutate) {
      Refresh-AssignedVisual -ForceRebind -SkipSelectionSync
    } else {
      Refresh-AssignedVisual -SkipSelectionSync
    }
    try { Sync-SelectionForSpecificIcons -Icons $targets } catch {}
    try { Refresh-IconContainerStylesForItems -Items $targets } catch {}
    $assignedNow = 0
    try { $assignedNow = [int](Get-AssignedIconCountForCategories -Categories @($cats)) } catch { $assignedNow = [int]@($targets).Count }
    $statusText.Text = ("Selected {0} icon(s) for {1} categor{2}." -f [int]$assignedNow, @($cats).Count, $(if(@($cats).Count -eq 1){'y'}else{'ies'}))
  }
}

function Get-ScrollViewerFromVisual {
  param([Parameter(Mandatory=$true)][System.Windows.DependencyObject]$Root)
  try {
    if ($Root -is [System.Windows.Controls.ScrollViewer]) { return $Root }
    $count = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Root)
    for ($i = 0; $i -lt $count; $i++) {
      $child = [System.Windows.Media.VisualTreeHelper]::GetChild($Root, $i)
      $sv = Get-ScrollViewerFromVisual -Root $child
      if ($sv) { return $sv }
    }
  } catch {}
  return $null
}

function Load-AssignmentsFromJson {
  param(
    [string]$Path,
    [string]$ForcedCategory = ''
  )
  $p = Normalize-Path $Path
  if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { return $false }
  $obj = (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json)
  $loadedAny = $false

  $allowedCats = New-Object System.Collections.Generic.List[string]
  $allowedSet = @{}
  try {
    $fc = ''
    try { $fc = [string]$ForcedCategory } catch { $fc = '' }
    $fc = $fc.Trim()
    if (-not [string]::IsNullOrWhiteSpace($fc)) {
      [void]$allowedCats.Add($fc)
      $allowedSet[$fc.ToLowerInvariant()] = $true
    } else {
      $catRows = @()
      try { $catRows = @($obj.Categories) } catch { $catRows = @() }
      foreach ($cn in @($catRows)) {
        $n = ''
        try { $n = [string]$cn } catch { $n = '' }
        $n = $n.Trim()
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        $k = $n.ToLowerInvariant()
        if ($allowedSet.ContainsKey($k)) { continue }
        $allowedSet[$k] = $true
        [void]$allowedCats.Add($n)
      }
      if (@($allowedCats.ToArray()).Count -eq 0) {
        $base = ''
        try { $base = [System.IO.Path]::GetFileNameWithoutExtension($p) } catch { $base = '' }
        $base = ([string]$base).Trim()
        if (-not [string]::IsNullOrWhiteSpace($base)) {
          [void]$allowedCats.Add($base)
          $allowedSet[$base.ToLowerInvariant()] = $true
        }
      }
    }
    foreach ($cn in @($allowedCats.ToArray())) {
      if (Add-Category -Name ([string]$cn) -SelectOnlyNew:$false -RefreshUI:$false) { $loadedAny = $true }
    }
  } catch {}

  $entries = @()
  try {
    if ($obj.PSObject.Properties.Match('Assignments').Count -gt 0) { $entries = @($obj.Assignments) }
    elseif ($obj.PSObject.Properties.Match('IconAssignments').Count -gt 0) { $entries = @($obj.IconAssignments) }
  } catch { $entries = @() }
  if (@($entries).Count -gt 0) {
    foreach ($e in $entries) {
      if (-not $e) { continue }
      $ip = ''; $ii = 0; $cats = @()
      try { $ip = Normalize-Path ([string]$e.IconPath) } catch { $ip = '' }
      try { $ii = [int]$e.IconIndex } catch { $ii = 0 }
      try { $cats = @($e.Categories) } catch { $cats = @() }
      if ([string]::IsNullOrWhiteSpace($ip)) { continue }
      $normCats = New-Object System.Collections.Generic.List[string]
      try {
        if (-not [string]::IsNullOrWhiteSpace($ForcedCategory)) {
          $forced = ([string]$ForcedCategory).Trim()
          if ([string]::IsNullOrWhiteSpace($forced)) { continue }
          $accept = $true
          # When loading profile files by filename category, only map rows that
          # explicitly contain that category (legacy rows without Categories are accepted).
          if (@($cats).Count -gt 0) {
            $accept = $false
            foreach ($c in @($cats)) {
              $n = ''
              try { $n = [string]$c } catch { $n = '' }
              $n = $n.Trim()
              if ([string]::IsNullOrWhiteSpace($n)) { continue }
              if ($n.ToLowerInvariant() -eq $forced.ToLowerInvariant()) { $accept = $true; break }
            }
          }
          if (-not $accept) { continue }
          [void]$normCats.Add($forced)
        } else {
          foreach ($c in @($cats)) {
            $n = ''
            try { $n = [string]$c } catch { $n = '' }
            $n = $n.Trim()
            if ([string]::IsNullOrWhiteSpace($n)) { continue }
            if (($allowedSet.Count -gt 0) -and (-not $allowedSet.ContainsKey($n.ToLowerInvariant()))) { continue }
            if (@($normCats.ToArray()) -contains $n) { continue }
            [void]$normCats.Add($n)
          }
          if (@($normCats.ToArray()).Count -eq 0 -and @($allowedCats.ToArray()).Count -gt 0) {
            [void]$normCats.Add([string]$allowedCats[0])
          }
        }
      } catch {}
      if (@($normCats.ToArray()).Count -eq 0) { continue }
      $k = Get-IconKey -Path $ip -Index $ii
      if ([string]::IsNullOrWhiteSpace($k)) { continue }
      if (-not $script:AssignmentsByKey.ContainsKey($k)) {
        $script:AssignmentsByKey[$k] = [pscustomobject]@{
          IconPath = [string]$ip
          IconIndex = [int]$ii
          Categories = New-Object System.Collections.Generic.List[string]
        }
      }
      $entry = $script:AssignmentsByKey[$k]
      $set = @{}
      foreach ($x in @($entry.Categories)) { $set[[string]$x] = $true }
      foreach ($c in @($normCats.ToArray())) {
        $n = ([string]$c).Trim()
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        if ($set.ContainsKey($n)) { continue }
        [void]$entry.Categories.Add($n)
        $set[$n] = $true
        $loadedAny = $true
      }
    }
  }
  if ($loadedAny) {
    try { Invalidate-AssignmentDerivedCaches -BumpVersion } catch {}
  }
  try { Capture-AssignmentBaseline } catch {}
  Refresh-CategoryList
  Refresh-AssignedVisual
  return [bool]$loadedAny
}

function Load-AssignmentsFromDirectory {
  param([string]$DirectoryPath)
  $dir = Normalize-Path $DirectoryPath
  if ([string]::IsNullOrWhiteSpace($dir) -or -not (Test-Path -LiteralPath $dir -PathType Container)) { return 0 }
  $loaded = 0
  $files = @()
  try { $files = @(Get-ChildItem -LiteralPath $dir -File -Filter *.json -ErrorAction SilentlyContinue | Sort-Object Name) } catch { $files = @() }
  foreach ($f in @($files)) {
    try {
      $catName = ''
      try { $catName = [System.IO.Path]::GetFileNameWithoutExtension([string]$f.Name) } catch { $catName = '' }
      $catName = ([string]$catName).Trim()
      if ([string]::IsNullOrWhiteSpace($catName)) { continue }
      if ($catName.ToLowerInvariant() -eq 'iconsourcedirectories') { continue }
      if (Load-AssignmentsFromJson -Path ([string]$f.FullName) -ForcedCategory $catName) { $loaded++ }
    } catch {}
  }
  return [int]$loaded
}

function Export-AssignmentsToJson {
  param(
    [string]$Path,
    [string[]]$CategoryFilter = @()
  )
  $filterSet = @{}
  try {
    foreach ($cn in @($CategoryFilter)) {
      $n = ''
      try { $n = [string]$cn } catch { $n = '' }
      $n = $n.Trim()
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $filterSet[$n.ToLowerInvariant()] = $n
    }
  } catch {}
  $rows = New-Object System.Collections.Generic.List[object]
  foreach ($k in @($script:AssignmentsByKey.Keys | Sort-Object)) {
    $a = $script:AssignmentsByKey[$k]
    if (-not $a) { continue }
    $cats = @()
    try {
      $rawCats = @($a.Categories | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)
      if ($filterSet.Count -gt 0) {
        foreach ($c in @($rawCats)) {
          $n = ''
          try { $n = [string]$c } catch { $n = '' }
          $n = $n.Trim()
          if ([string]::IsNullOrWhiteSpace($n)) { continue }
          if (-not $filterSet.ContainsKey($n.ToLowerInvariant())) { continue }
          $cats += $n
        }
      } else {
        $cats = @($rawCats)
      }
    } catch { $cats = @() }
    if (@($cats).Count -eq 0) { continue }
    [void]$rows.Add([pscustomobject]@{
      IconPath = [string]$a.IconPath
      IconIndex = [int]$a.IconIndex
      Categories = @($cats)
    })
  }
  $obj = [pscustomobject]@{
    SchemaVersion = 1
    GeneratedAtUtc = [datetime]::UtcNow.ToString('o')
    Categories = @(
      if ($filterSet.Count -gt 0) {
        @($filterSet.Values | Sort-Object -Unique)
      } else {
        @($script:CategoryRows.ToArray() | ForEach-Object { [string]$_.Name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
      }
    )
    Assignments = @($rows.ToArray())
  }
  $json = $obj | ConvertTo-Json -Depth 8
  Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
  try { Capture-AssignmentBaseline } catch {}
  try { Refresh-AssignedVisual } catch {}
}

function Add-IconsFromSources {
  param(
    [string[]]$Sources,
    [switch]$ShowProgress
  )
  $added = 0
  foreach ($src in @($Sources)) {
    if (Test-StartupMainAbortRequested) { return [int]$added }
    $iconCount = 0
    try { $iconCount = Get-IconCountForFile -Path $src } catch { $iconCount = 0 }
    if ($iconCount -le 0) { continue }
    for ($i = 0; $i -lt $iconCount; $i++) {
      if (Test-StartupMainAbortRequested) { return [int]$added }
      $label = ("{0},{1}" -f ([System.IO.Path]::GetFileName([string]$src)), [int]$i)
      $key = Get-IconKey -Path $src -Index $i
      if ([string]::IsNullOrWhiteSpace($key)) { continue }
      if ($script:IconsByKey.ContainsKey($key)) { continue }
      $row = [pscustomobject]@{
        Key = [string]$key
        IconPath = [string](Normalize-Path $src)
        IconIndex = [int]$i
        Label = [string]$label
        Icon = $null
        IsAssignedActive = $false
        IsCategorized = $false
        HasSelectTargets = $false
        SelectDeltaKind = 'None'
        IsPendingExport = $false
        IsExtractSelected = $false
        RowOrdinal = ([int]$script:IconRowOrdinal)
      }
      [void]$script:AllIcons.Add($row)
      $script:IconsByKey[$key] = $row
      try { $script:IconRowOrdinal = [int]$script:IconRowOrdinal + 1 } catch {}
      $added++
      if ($ShowProgress -and (($added % 500) -eq 0)) {
        try { $statusText.Text = ("Loading icons... +{0}" -f $added) } catch {}
        try { $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background) } catch {}
        if (Test-StartupMainAbortRequested) { return [int]$added }
      }
    }
  }
  return [int]$added
}

$categoryList.ItemTemplate = [Windows.Markup.XamlReader]::Parse(@"
<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
              xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Grid Margin="-5,1,2,1">
    <Grid.Resources>
      <Style x:Key="CategoryColumnCheckStyle" TargetType="{x:Type CheckBox}">
        <Setter Property="Width" Value="22"/>
        <Setter Property="Height" Value="22"/>
        <Setter Property="Margin" Value="0"/>
        <Setter Property="HorizontalAlignment" Value="Center"/>
        <Setter Property="VerticalAlignment" Value="Center"/>
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="BorderBrush" Value="#7A7A7A"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="{x:Type CheckBox}">
              <Grid Width="{TemplateBinding Width}" Height="{TemplateBinding Height}" Background="Transparent">
                <Border x:Name="box"
                        Width="18"
                        Height="18"
                        CornerRadius="2"
                        BorderThickness="{TemplateBinding BorderThickness}"
                        BorderBrush="{TemplateBinding BorderBrush}"
                        Background="Transparent"
                        HorizontalAlignment="Center"
                        VerticalAlignment="Center"/>
                <Path x:Name="mark"
                      Data="M 2,8 L 6,12 L 14,4"
                      Width="16"
                      Height="16"
                      Stretch="Uniform"
                      Stroke="#2F2F2F"
                      StrokeThickness="2"
                      StrokeStartLineCap="Square"
                      StrokeEndLineCap="Square"
                      StrokeLineJoin="Miter"
                      HorizontalAlignment="Center"
                      VerticalAlignment="Center"
                      SnapsToDevicePixels="True"
                      Visibility="Collapsed"/>
              </Grid>
              <ControlTemplate.Triggers>
                <Trigger Property="IsChecked" Value="True">
                  <Setter TargetName="box" Property="Background" Value="#DADADA"/>
                  <Setter TargetName="box" Property="BorderBrush" Value="#666666"/>
                  <Setter TargetName="mark" Property="Visibility" Value="Visible"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                  <Setter TargetName="box" Property="BorderBrush" Value="#595959"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                  <Setter TargetName="box" Property="Opacity" Value="0.55"/>
                  <Setter TargetName="mark" Property="Opacity" Value="0.55"/>
                </Trigger>
              </ControlTemplate.Triggers>
            </ControlTemplate>
          </Setter.Value>
        </Setter>
      </Style>
    </Grid.Resources>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="30"/>
      <ColumnDefinition Width="30"/>
      <ColumnDefinition Width="30"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>
    <CheckBox x:Name="SelectCatCheck"
              Grid.Column="0"
              IsChecked="{Binding SelectChecked, Mode=TwoWay}"
              Style="{StaticResource CategoryColumnCheckStyle}"
              ToolTip="Select"/>
    <CheckBox x:Name="ShowCatCheck"
              Grid.Column="1"
              IsChecked="{Binding ShowChecked, Mode=TwoWay}"
              Style="{StaticResource CategoryColumnCheckStyle}"
              ToolTip="Show"/>
    <CheckBox x:Name="HideCatCheck"
              Grid.Column="2"
              IsChecked="{Binding HideChecked, Mode=TwoWay}"
              Style="{StaticResource CategoryColumnCheckStyle}"
              ToolTip="Hide"/>
    <TextBox Grid.Column="3"
             Text="{Binding Name, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}"
             MinWidth="150"
             Height="24"
             Margin="0,-1,0,0"
             Padding="4,1"
             VerticalContentAlignment="Center"/>
  </Grid>
</DataTemplate>
"@)

$iconList.ItemsSource = @()

$iconSearchBox.Add_TextChanged({
  try { $script:IconCurrentPage = 1 } catch {}
  Queue-IconSearchRefresh
})

if ($iconPageSizeBox) {
  try {
    $wanted = [int]$script:IconPageSize
    foreach ($it in @($iconPageSizeBox.Items)) {
      $v = 0
      try { $v = [int]([string]$it.Content) } catch { $v = 0 }
      if ($v -eq $wanted) {
        $iconPageSizeBox.SelectedItem = $it
        break
      }
    }
  } catch {}
  $iconPageSizeBox.Add_SelectionChanged({
    try {
      $sel = $iconPageSizeBox.SelectedItem
      if (-not $sel) { return }
      $value = 0
      try { $value = [int]([string]$sel.Content) } catch { $value = 0 }
      if ($value -lt 200) { return }
      if ($value -eq [int]$script:IconPageSize) { return }
      $script:IconPageSize = [int]$value
      $script:IconCurrentPage = 1
      try { Refresh-IconListPage } catch {}
      try { $statusText.Text = ("Icons per page: {0}" -f $value) } catch {}
    } catch {}
  })
}

if ($showAllIconsBox) {
  $showAllIconsBox.Add_Click({
    try {
      $isOn = [bool]$showAllIconsBox.IsChecked
      $script:ShowAllIcons = [bool]$isOn
    } catch {
      $script:ShowAllIcons = $true
      try { if ($showAllIconsBox) { $showAllIconsBox.IsChecked = $true } } catch {}
    }
    try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
    try { $script:IconCurrentPage = 1 } catch {}
    try { Refresh-IconListPage } catch {}
    try {
      $statusText.Text = ("Show all icons: {0}" -f $(if([bool]$script:ShowAllIcons){'on'}else{'off'}))
    } catch {}
  })
}

if ($unmaskSharedIconsBox) {
  $unmaskSharedIconsBox.Add_Click({
    try {
      $script:UnmaskSharedIcons = [bool]$unmaskSharedIconsBox.IsChecked
    } catch {
      $script:UnmaskSharedIcons = $false
      try { if ($unmaskSharedIconsBox) { $unmaskSharedIconsBox.IsChecked = $false } } catch {}
    }
    try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
    try { $script:IconCurrentPage = 1 } catch {}
    try { Refresh-IconListPage } catch {}
    try {
      $statusText.Text = ("Unmask shared icons: {0}" -f $(if([bool]$script:UnmaskSharedIcons){'on'}else{'off'}))
    } catch {}
  })
}

if ($hidePixelDuplicatesBox) {
  $hidePixelDuplicatesBox.Add_Click({
    try { $script:HidePixelDuplicates = [bool]$hidePixelDuplicatesBox.IsChecked } catch { $script:HidePixelDuplicates = $false }
    try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
    try { $script:IconCurrentPage = 1 } catch {}
    try { Refresh-IconListPage } catch {}
    try {
      if ([bool]$script:HidePixelDuplicates) {
        $statusText.Text = 'Pixel duplicate hiding enabled.'
      } else {
        $statusText.Text = 'Pixel duplicate hiding disabled.'
      }
    } catch {}
  })
}

if ($iconPrevPageBtn) {
  $iconPrevPageBtn.Add_Click({
    try { $script:IconCurrentPage = [Math]::Max(1, ([int]$script:IconCurrentPage - 1)) } catch { $script:IconCurrentPage = 1 }
    try { Refresh-IconListPage } catch {}
  })
}
if ($iconNextPageBtn) {
  $iconNextPageBtn.Add_Click({
    try { $script:IconCurrentPage = [int]$script:IconCurrentPage + 1 } catch { $script:IconCurrentPage = 2 }
    try { Refresh-IconListPage } catch {}
  })
}

if ($extractIconsModeBox) {
  $extractIconsModeBox.Add_Checked({
    try { Set-ExtractModeState -Enabled:$true } catch {}
  })
  $extractIconsModeBox.Add_Unchecked({
    try { Set-ExtractModeState -Enabled:$false } catch {}
  })
}

if ($extractIconsBtn) {
  $extractIconsBtn.Add_Click({
    try {
      try { $statusText.Text = 'Extract clicked.' } catch {}
      if (-not [bool]$script:ExtractIconsMode) { return }
      Export-ExtractSelectedIcons
    } catch {}
  })
}

$createCategoryBtn.Add_Click({
  [void](Add-Category -Name ([string]$categoryNameBox.Text))
  try { $categoryNameBox.Text = '' } catch {}
  try { $iconList.UnselectAll() } catch {}
})

$categoryNameBox.Add_KeyDown({
  param($s,$e)
  if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
    [void](Add-Category -Name ([string]$categoryNameBox.Text))
    try { $categoryNameBox.Text = '' } catch {}
    try { $iconList.UnselectAll() } catch {}
    $e.Handled = $true
  }
})

if ($showUncategorizedBox) {
  $showUncategorizedBox.Add_Click({
    try { $script:ShowUncategorizedOnly = [bool]$showUncategorizedBox.IsChecked } catch { $script:ShowUncategorizedOnly = $false }
    try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
    try { $script:IconCurrentPage = 1 } catch {}
    try { Refresh-IconListPage } catch {}
    try {
      if ([bool]$script:ShowUncategorizedOnly) {
        $statusText.Text = 'Showing uncategorized icons only.'
      } else {
        $statusText.Text = 'Showing categorized + uncategorized icons.'
      }
    } catch {}
  })
}
if ($deleteSelectedCategoryBtn) {
  $deleteSelectedCategoryBtn.Add_Click({
    try {
      try { $statusText.Text = 'Delete Selected Category clicked.' } catch {}
      Delete-SelectedCategories
    } catch {
      try { $statusText.Text = ("Delete selected category failed: " + [string]$_.Exception.Message) } catch {}
    }
  })
}

if ($toggleAllSelectBox) {
  $toggleAllSelectBox.Add_Checked({
    try { if ($script:SuppressCategoryCheckEvents) { return } } catch {}
    try { Set-AllCategoriesSelected -Selected:$true } catch {}
  })
  $toggleAllSelectBox.Add_Unchecked({
    try { if ($script:SuppressCategoryCheckEvents) { return } } catch {}
    try { Set-AllCategoriesSelected -Selected:$false } catch {}
  })
}
if ($toggleAllCategoriesBox) {
  $toggleAllCategoriesBox.Add_Checked({
    try { if ($script:SuppressCategoryCheckEvents) { return } } catch {}
    try { Set-AllCategoriesShown -Selected:$true } catch {}
  })
  $toggleAllCategoriesBox.Add_Unchecked({
    try { if ($script:SuppressCategoryCheckEvents) { return } } catch {}
    try { Set-AllCategoriesShown -Selected:$false } catch {}
  })
}
if ($toggleAllMaskBox) {
  $toggleAllMaskBox.Add_Checked({
    try { if ($script:SuppressCategoryCheckEvents) { return } } catch {}
    try { Set-AllCategoriesMasked -Selected:$true } catch {}
  })
  $toggleAllMaskBox.Add_Unchecked({
    try { if ($script:SuppressCategoryCheckEvents) { return } } catch {}
    try { Set-AllCategoriesMasked -Selected:$false } catch {}
  })
}

if ($rightPanelToggleBtn) {
  $rightPanelToggleBtn.Add_Click({
    try {
      Set-RightPanelVisibility -Visible:(-not [bool]$script:RightPanelVisible)
    } catch {}
  })
}

$categoryList.AddHandler(
  [System.Windows.Controls.Primitives.ToggleButton]::CheckedEvent,
  [System.Windows.RoutedEventHandler]{
    param($s,$e)
    try { if ($script:SuppressCategoryCheckEvents) { return } } catch {}
    $catName = ''
    $kind = ''
    try {
      $cb = $e.OriginalSource -as [System.Windows.Controls.CheckBox]
      if ($cb -and $cb.DataContext) {
        $cbName = ''
        try { $cbName = [string]$cb.Name } catch { $cbName = '' }
        if ($cbName -eq 'SelectCatCheck') {
          $cb.DataContext.SelectChecked = $true
          $kind = 'Select'
        } elseif ($cbName -eq 'ShowCatCheck') {
          try {
            $parentPanel = $cb.Parent -as [System.Windows.Controls.Panel]
            if ($parentPanel) {
              foreach ($child in @($parentPanel.Children)) {
                if (($child -is [System.Windows.Controls.CheckBox]) -and ([string]$child.Name -eq 'HideCatCheck')) {
                  if ([bool]$child.IsChecked) {
                    $script:SuppressCategoryCheckEvents = $true
                    try { $child.IsChecked = $false } catch {}
                    $script:SuppressCategoryCheckEvents = $false
                  }
                  break
                }
              }
            }
          } catch { try { $script:SuppressCategoryCheckEvents = $false } catch {} }
          $cb.DataContext.ShowChecked = $true
          $cb.DataContext.HideChecked = $false
          try { Enforce-CategoryRowExclusivity -Row $cb.DataContext -Prefer 'Show' } catch {}
          $kind = 'Show'
        } elseif ($cbName -eq 'HideCatCheck') {
          try {
            $parentPanel = $cb.Parent -as [System.Windows.Controls.Panel]
            if ($parentPanel) {
              foreach ($child in @($parentPanel.Children)) {
                if (($child -is [System.Windows.Controls.CheckBox]) -and ([string]$child.Name -eq 'ShowCatCheck')) {
                  if ([bool]$child.IsChecked) {
                    $script:SuppressCategoryCheckEvents = $true
                    try { $child.IsChecked = $false } catch {}
                    $script:SuppressCategoryCheckEvents = $false
                  }
                  break
                }
              }
            }
          } catch { try { $script:SuppressCategoryCheckEvents = $false } catch {} }
          $cb.DataContext.HideChecked = $true
          $cb.DataContext.ShowChecked = $false
          try { Enforce-CategoryRowExclusivity -Row $cb.DataContext -Prefer 'Hide' } catch {}
          $kind = 'Hide'
        } else {
          return
        }
        try { $catName = [string]$cb.DataContext.Name } catch { $catName = '' }
      }
    } catch {}
    if (-not [string]::IsNullOrWhiteSpace($kind)) {
      Handle-CategoryCheckedChanged -IsChecked:$true -CategoryName $catName -ColumnKind $kind
    }
  },
  $true
)

$categoryList.AddHandler(
  [System.Windows.Controls.Primitives.ToggleButton]::UncheckedEvent,
  [System.Windows.RoutedEventHandler]{
    param($s,$e)
    try { if ($script:SuppressCategoryCheckEvents) { return } } catch {}
    $catName = ''
    $kind = ''
    try {
      $cb = $e.OriginalSource -as [System.Windows.Controls.CheckBox]
      if ($cb -and $cb.DataContext) {
        $cbName = ''
        try { $cbName = [string]$cb.Name } catch { $cbName = '' }
        if ($cbName -eq 'SelectCatCheck') {
          $cb.DataContext.SelectChecked = $false
          $kind = 'Select'
        } elseif ($cbName -eq 'ShowCatCheck') {
          $cb.DataContext.ShowChecked = $false
          try { Enforce-CategoryRowExclusivity -Row $cb.DataContext -Prefer 'Show' } catch {}
          $kind = 'Show'
        } elseif ($cbName -eq 'HideCatCheck') {
          $cb.DataContext.HideChecked = $false
          try { Enforce-CategoryRowExclusivity -Row $cb.DataContext -Prefer 'Hide' } catch {}
          $kind = 'Hide'
        } else {
          return
        }
        try { $catName = [string]$cb.DataContext.Name } catch { $catName = '' }
      }
    } catch {}
    if (-not [string]::IsNullOrWhiteSpace($kind)) {
      Handle-CategoryCheckedChanged -IsChecked:$false -CategoryName $catName -ColumnKind $kind
    }
  },
  $true
)

$categoryList.AddHandler(
  [System.Windows.UIElement]::LostKeyboardFocusEvent,
  [System.Windows.RoutedEventHandler]{
    param($s,$e)
    try {
      $tb = $e.OriginalSource -as [System.Windows.Controls.TextBox]
      if (-not $tb -or -not $tb.DataContext) { return }
      [void](Commit-CategoryRename -Row $tb.DataContext -NewName ([string]$tb.Text))
    } catch {}
  },
  $true
)

$categoryList.AddHandler(
  [System.Windows.UIElement]::PreviewKeyDownEvent,
  [System.Windows.Input.KeyEventHandler]{
    param($s,$e)
    try {
      if ($e.Key -ne [System.Windows.Input.Key]::Enter) { return }
      $tb = $e.OriginalSource -as [System.Windows.Controls.TextBox]
      if (-not $tb -or -not $tb.DataContext) { return }
      [void](Commit-CategoryRename -Row $tb.DataContext -NewName ([string]$tb.Text))
      try { $categoryList.Focus() } catch {}
      $e.Handled = $true
    } catch {}
  },
  $true
)

$iconList.Add_PreviewMouseLeftButtonUp({
  param($s,$e)
  try {
    $src = $e.OriginalSource -as [System.Windows.DependencyObject]
    $lbi = $null
    while ($src -and -not ($src -is [System.Windows.Controls.ListBoxItem])) {
      try { $src = [System.Windows.Media.VisualTreeHelper]::GetParent($src) } catch { break }
    }
    if ($src -is [System.Windows.Controls.ListBoxItem]) { $lbi = $src }
    if (-not $lbi) { return }
    $clicked = $lbi.DataContext
    if (-not $clicked) { return }

    $mods = [System.Windows.Input.Keyboard]::Modifiers
    $ctrl = (($mods -band [System.Windows.Input.ModifierKeys]::Control) -ne [System.Windows.Input.ModifierKeys]::None)
    $shift = (($mods -band [System.Windows.Input.ModifierKeys]::Shift) -ne [System.Windows.Input.ModifierKeys]::None)
    $useMulti = ($ctrl -or $shift)

    $targets = @()
    if ($useMulti) {
      try { $targets = @($iconList.SelectedItems) } catch { $targets = @() }
      if (@($targets).Count -eq 0) { $targets = @($clicked) }
      elseif (-not (@($targets) -contains $clicked)) { $targets = @($clicked) }
      try {
        foreach ($ti in @($targets)) {
          if ($ti) { [void]$iconList.SelectedItems.Add($ti) }
        }
      } catch {}
    } else {
      $targets = @($clicked)
      try {
        $iconList.UnselectAll()
        foreach ($ti in @($targets)) {
          if ($ti) { [void]$iconList.SelectedItems.Add($ti) }
        }
      } catch {}
    }
    if ([bool]$script:ExtractIconsMode) {
      Toggle-ExtractSelectionForIcons -Icons $targets
    } else {
      Toggle-IconsForCheckedCategories -Icons $targets
    }
  } catch {
    $statusText.Text = ("Toggle failed: " + [string]$_.Exception.Message)
  }
})

function Copy-ClipboardQuick {
  param(
    [Parameter(Mandatory=$true)][string]$Text
  )
  try {
    if ([string]::IsNullOrWhiteSpace([string]$Text)) { return $false }
    $payload = [string]$Text
    $copied = $false
    try {
      [System.Windows.Clipboard]::SetText($payload)
      $copied = $true
    } catch {
      $copied = $false
    }
    if (-not $copied) {
      try {
        if ($window -and $window.Dispatcher) {
          $copyPayload = [string]$payload
          [void]$window.Dispatcher.BeginInvoke(
            [System.Action]{
              try { [System.Windows.Clipboard]::SetText([string]$copyPayload) } catch {}
            }.GetNewClosure(),
            [System.Windows.Threading.DispatcherPriority]::Background
          )
        }
      } catch {}
    }

    return $true
  } catch {
    return $false
  }
}

function Restore-IconsToBaseline {
  param([object[]]$Icons)
  $changed = 0
  foreach ($it in @($Icons)) {
    if (-not $it) { continue }
    $k = ''
    try { $k = [string]$it.Key } catch { $k = '' }
    if ([string]::IsNullOrWhiteSpace($k)) { continue }

    $baseCats = @()
    try {
      if ($script:BaselineAssignmentCategoriesByKey -and $script:BaselineAssignmentCategoriesByKey.ContainsKey($k)) {
        $baseCats = @($script:BaselineAssignmentCategoriesByKey[$k])
      }
    } catch { $baseCats = @() }

    $currentSig = ''
    $baseSig = ''
    try {
      if ($script:AssignmentsByKey.ContainsKey($k)) {
        $currentSig = [string](Get-AssignmentCategorySignature -Entry $script:AssignmentsByKey[$k])
      }
    } catch { $currentSig = '' }
    try { $baseSig = [string](Get-NormalizedCategorySignature -Categories @($baseCats)) } catch { $baseSig = '' }
    if ($currentSig -eq $baseSig) { continue }

    if (@($baseCats).Count -eq 0) {
      try {
        if ($script:AssignmentsByKey.ContainsKey($k)) {
          [void]$script:AssignmentsByKey.Remove($k)
          $changed++
        }
      } catch {}
      continue
    }

    if (-not $script:AssignmentsByKey.ContainsKey($k)) {
      $ip = ''
      $ii = 0
      try { $ip = [string]$it.IconPath } catch { $ip = '' }
      try { $ii = [int]$it.IconIndex } catch { $ii = 0 }
      $script:AssignmentsByKey[$k] = [pscustomobject]@{
        IconPath = [string]$ip
        IconIndex = [int]$ii
        Categories = New-Object System.Collections.Generic.List[string]
      }
    }

    try {
      $clean = New-Object System.Collections.Generic.List[string]
      $seen = @{}
      foreach ($c in @($baseCats)) {
        $n = ''
        try { $n = [string]$c } catch { $n = '' }
        $n = $n.Trim()
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        $lk = $n.ToLowerInvariant()
        if ($seen.ContainsKey($lk)) { continue }
        $seen[$lk] = $true
        [void]$clean.Add($n)
      }
      $script:AssignmentsByKey[$k].Categories = $clean
      $changed++
    } catch {}
  }
  if ($changed -gt 0) {
    try { Invalidate-AssignmentDerivedCaches -BumpVersion } catch {}
  }
  return [int]$changed
}

function Ensure-IconCopyContextMenu {
  try {
    if ($script:IconCopyContextMenu) { return }
    $cm = New-Object System.Windows.Controls.ContextMenu
    $cm.Placement = [System.Windows.Controls.Primitives.PlacementMode]::MousePoint
    $cm.StaysOpen = $false

    $miName = New-Object System.Windows.Controls.MenuItem
    $miName.Header = 'Copy name'
    $miName.Add_Click({
      try {
        try { if ($script:IconCopyContextMenu) { $script:IconCopyContextMenu.IsOpen = $false } } catch {}
        $txt = ''
        try { $txt = [string]$script:IconCopyContextName } catch { $txt = '' }
        if ([string]::IsNullOrWhiteSpace($txt)) { return }
        [void](Copy-ClipboardQuick -Text $txt)
      } catch {}
    })

    $miPath = New-Object System.Windows.Controls.MenuItem
    $miPath.Header = 'Copy path'
    $miPath.Add_Click({
      try {
        try { if ($script:IconCopyContextMenu) { $script:IconCopyContextMenu.IsOpen = $false } } catch {}
        $txt = ''
        try { $txt = [string]$script:IconCopyContextPath } catch { $txt = '' }
        if ([string]::IsNullOrWhiteSpace($txt)) { return }
        [void](Copy-ClipboardQuick -Text $txt)
      } catch {}
    })

    [void]$cm.Items.Add($miName)
    [void]$cm.Items.Add($miPath)
    $cm.Add_Closed({
      try { $script:IconCopyContextName = '' } catch {}
      try { $script:IconCopyContextPath = '' } catch {}
    })
    $script:IconCopyContextMenu = $cm
  } catch {}
}

function Show-IconCopyContextMenu {
  param(
    [Parameter(Mandatory=$false)]$IconRow,
    [Parameter(Mandatory=$false)][System.Windows.UIElement]$PlacementTarget
  )
  try {
    if (-not $IconRow) { return }
    $copyName = ''
    $copyPath = ''
    try { $copyName = [string]$IconRow.Label } catch { $copyName = '' }
    if ([string]::IsNullOrWhiteSpace($copyName)) {
      $leaf = ''
      $idx = 0
      try { $leaf = [System.IO.Path]::GetFileName([string]$IconRow.IconPath) } catch { $leaf = '' }
      try { $idx = [int]$IconRow.IconIndex } catch { $idx = 0 }
      if (-not [string]::IsNullOrWhiteSpace($leaf)) { $copyName = ("{0},{1}" -f [string]$leaf, [int]$idx) }
    }
    try { $copyPath = [string]$IconRow.IconPath } catch { $copyPath = '' }
    try { $script:IconCopyContextName = [string]$copyName } catch { $script:IconCopyContextName = '' }
    try { $script:IconCopyContextPath = [string]$copyPath } catch { $script:IconCopyContextPath = '' }
    Ensure-IconCopyContextMenu
    if ($script:IconCopyContextMenu) {
      try { $script:IconCopyContextMenu.PlacementTarget = $PlacementTarget } catch {}
      try { $script:IconCopyContextMenu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::MousePoint } catch {}
      try { $script:IconCopyContextMenu.IsOpen = $true } catch {}
    }
  } catch {}
}

$iconList.Add_PreviewMouseRightButtonDown({
  param($s,$e)
  try {
    $src = $e.OriginalSource -as [System.Windows.DependencyObject]
    $lbi = $null
    while ($src -and -not ($src -is [System.Windows.Controls.ListBoxItem])) {
      try { $src = [System.Windows.Media.VisualTreeHelper]::GetParent($src) } catch { break }
    }
    if ($src -is [System.Windows.Controls.ListBoxItem]) { $lbi = $src }
    if (-not $lbi) { return }
    $clicked = $lbi.DataContext
    if (-not $clicked) { return }
    # Right-click copy menu must not alter selection state used by undo/redo logic.
    $selectedSnapshot = @()
    try { $selectedSnapshot = @($iconList.SelectedItems) } catch { $selectedSnapshot = @() }
    Show-IconCopyContextMenu -IconRow $clicked -PlacementTarget $lbi
    try {
      $iconList.UnselectAll()
      foreach ($si in @($selectedSnapshot)) {
        if ($si) { [void]$iconList.SelectedItems.Add($si) }
      }
    } catch {}
    $e.Handled = $true
  } catch {}
})

$iconList.Add_PreviewMouseRightButtonUp({
  param($s,$e)
  try { $e.Handled = $true } catch {}
})

$loadJsonBtn.Add_Click({
  try {
    try { $statusText.Text = 'Load Category clicked.' } catch {}
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Title = 'Load Icon Category JSON'
    $dlg.Filter = 'JSON files (*.json)|*.json|All files (*.*)|*.*'
    if ($dlg.ShowDialog()) {
      $srcFile = ''
      try { $srcFile = Normalize-Path ([string]$dlg.FileName) } catch { $srcFile = '' }
      if ([string]::IsNullOrWhiteSpace($srcFile) -or -not (Test-Path -LiteralPath $srcFile -PathType Leaf)) {
        try { $statusText.Text = 'Load failed: selected JSON file was not found.' } catch {}
        return
      }

      $manualCat = ''
      try { $manualCat = [System.IO.Path]::GetFileNameWithoutExtension([string]$srcFile) } catch { $manualCat = '' }
      if ([string]::IsNullOrWhiteSpace($manualCat)) { $manualCat = 'ImportedCategory' }
      $safeCat = ''
      try { $safeCat = Get-SafeFileNameSegment -Name $manualCat } catch { $safeCat = '' }
      if ([string]::IsNullOrWhiteSpace($safeCat)) { $safeCat = 'ImportedCategory' }

      $destPath = ''
      try {
        $profilesRoot = Get-IconCategoryProfilesRoot
        if ([string]::IsNullOrWhiteSpace($profilesRoot)) { throw 'Icon Categories path unavailable.' }
        $destPath = Join-Path $profilesRoot ($safeCat + '.json')
        if ($srcFile.ToLowerInvariant() -ne $destPath.ToLowerInvariant()) {
          Copy-Item -LiteralPath $srcFile -Destination $destPath -Force
        }
      } catch {
        try { $statusText.Text = ("Load failed: unable to copy JSON to Icon Categories. " + [string]$_.Exception.Message) } catch {}
        return
      }

      if (Load-AssignmentsFromJson -Path ([string]$destPath) -ForcedCategory $manualCat) {
        $statusText.Text = 'Loaded categories JSON.'
      } else {
        $statusText.Text = 'No assignments were loaded.'
      }

      try {
        $msg = "Category file copied to Icon Categories.`n`n$destPath`n`nRefresh app now to update the full list?"
        $refreshNow = [System.Windows.MessageBox]::Show(
          $msg,
          'Load Category',
          [System.Windows.MessageBoxButton]::YesNo,
          [System.Windows.MessageBoxImage]::Information
        )
        if ($refreshNow -eq [System.Windows.MessageBoxResult]::Yes) {
          try { Refresh-ExternalStateIfChanged } catch {}
        }
      } catch {}
    }
  } catch {
    $statusText.Text = ("Load failed: " + [string]$_.Exception.Message)
  }
})

$exportJsonBtn.Add_Click({
  try {
    try { $statusText.Text = 'Save Category clicked.' } catch {}
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Title = 'Export Icon Category JSON'
    $dlg.Filter = 'JSON files (*.json)|*.json|All files (*.*)|*.*'
    $suggested = ''
    try { $suggested = Get-SafeFileNameSegment -Name (Get-PrimaryCategoryNameForSave) } catch { $suggested = '' }
    if ([string]::IsNullOrWhiteSpace($suggested)) {
      $dlg.FileName = [System.IO.Path]::GetFileName((Get-DefaultJsonPath))
    } else {
      $dlg.FileName = ($suggested + '.json')
    }
    $defaultDir = Split-Path -Parent (Get-DefaultJsonPath)
    if (-not [string]::IsNullOrWhiteSpace($defaultDir) -and (Test-Path -LiteralPath $defaultDir -PathType Container)) { $dlg.InitialDirectory = $defaultDir }
    if ($dlg.ShowDialog()) {
      $primaryCat = ''
      try { $primaryCat = [string](Get-PrimaryCategoryNameForSave) } catch { $primaryCat = '' }
      $primaryCat = $primaryCat.Trim()
      if (-not [string]::IsNullOrWhiteSpace($primaryCat)) {
        Export-AssignmentsToJson -Path ([string]$dlg.FileName) -CategoryFilter @($primaryCat)
      } else {
        Export-AssignmentsToJson -Path ([string]$dlg.FileName)
      }
      $statusText.Text = ("Saved: " + [string]$dlg.FileName)
      Show-SaveCompletedDialog -Message 'Save completed.' -Title 'Icon Allocator (v1.77)'
    }
  } catch {
    $statusText.Text = ("Export failed: " + [string]$_.Exception.Message)
  }
})

if ($backupIconPackDirBtn) {
  $backupIconPackDirBtn.Add_Click({
    try {
      try { $statusText.Text = 'Backup Icon Pack Directory clicked.' } catch {}
      Backup-IconSourceDirectoriesState
    } catch {
      try { $statusText.Text = ("Backup failed: " + [string]$_.Exception.Message) } catch {}
    }
  })
}

if ($refreshExternalBtn) {
  $refreshExternalBtn.Add_Click({
    try {
      try { $statusText.Text = 'Refresh clicked.' } catch {}
      Refresh-ExternalStateIfChanged
    } catch {
      try { $statusText.Text = ("Refresh failed: " + [string]$_.Exception.Message) } catch {}
    }
  })
}

if ($clearSelectionBtn) {
  $clearSelectionBtn.Add_Click({
    try {
      $targets = @()
      try { $targets = @($iconList.SelectedItems) } catch { $targets = @() }
      if (@($targets).Count -eq 0) {
        try {
          $targets = @($iconList.ItemsSource | Where-Object {
            try { $_ -and [bool]$_.IsPendingExport } catch { $false }
          })
        } catch { $targets = @() }
      }

      $changed = 0
      if (@($targets).Count -gt 0) {
        try { $changed = [int](Restore-IconsToBaseline -Icons @($targets)) } catch { $changed = 0 }
      }

      try { $iconList.UnselectAll() } catch {}
      if ($changed -gt 0) {
        $needRebindAfterMutate = $false
        try { $needRebindAfterMutate = (-not [bool]$script:ShowAllIcons) -or (@(Get-HiddenCategories).Count -gt 0) } catch { $needRebindAfterMutate = $false }
        if ($needRebindAfterMutate) {
          try { Refresh-AssignedVisual -ForceRebind -SkipSelectionSync } catch { try { Refresh-AssignedVisual } catch {} }
        } else {
          try { Refresh-AssignedVisual -SkipSelectionSync } catch { try { Refresh-AssignedVisual } catch {} }
        }
        try { $statusText.Text = ("Cleared pending selection for {0} icon(s)." -f [int]$changed) } catch {}
      } else {
        try { Refresh-AssignedVisual -SkipSelectionSync } catch { try { Refresh-AssignedVisual } catch {} }
        try { $statusText.Text = 'No pending selection to clear.' } catch {}
      }
    } catch {
      try { $statusText.Text = ("Clear selection failed: " + [string]$_.Exception.Message) } catch {}
    }
  })
}

function Add-CustomIconSourceDirectory {
  param([string]$Path)
  $displayPath = Normalize-SourcePathForDisplay ([string]$Path)
  $p = Normalize-Path $displayPath
  if ([string]::IsNullOrWhiteSpace($p) -or -not (Test-Path -LiteralPath $p)) {
    try { $statusText.Text = 'Invalid icon source path.' } catch {}
    return
  }
  $isDir = $false
  $isFile = $false
  try { $isDir = [bool](Test-Path -LiteralPath $p -PathType Container) } catch { $isDir = $false }
  try { $isFile = [bool](Test-Path -LiteralPath $p -PathType Leaf) } catch { $isFile = $false }
  if (-not $isDir -and -not $isFile) {
    try { $statusText.Text = 'Invalid icon source path.' } catch {}
    return
  }
  if ($isFile) {
    $ext = ''
    try { $ext = [string]([System.IO.Path]::GetExtension($p)).ToLowerInvariant() } catch { $ext = '' }
    if (@('.dll','.exe','.cpl','.icl') -notcontains $ext) {
      try { $statusText.Text = 'Unsupported icon source file. Use .dll, .exe, .cpl, or .icl.' } catch {}
      return
    }
  }
  # Allow adding source folders without recursive pre-scan blocking.
  # Any available icons are indexed after the path is added.
  $exists = $false
  $pKey = Get-SourcePathKey $displayPath
  foreach ($d in @($script:CustomIconSourceDirs.ToArray())) {
    try { if ((Get-SourcePathKey ([string]$d)) -eq $pKey) { $exists = $true; break } } catch {}
  }
  if (-not $exists) {
    [void]$script:CustomIconSourceDirs.Add($displayPath)
    try {
      if ($script:SessionHiddenSourcePathKeys -and $script:SessionHiddenSourcePathKeys.ContainsKey([string]$pKey)) {
        [void]$script:SessionHiddenSourcePathKeys.Remove([string]$pKey)
      }
    } catch {}
    try { Set-SourcePathVisibility -Path $displayPath -Visible:$true } catch {}
    $saveRes = $null
    try { $saveRes = Save-CustomIconSourceDirectories } catch { $saveRes = $null }
    try { Refresh-IconSourceDirectoryList } catch {}
    $statePath = ''
    try { $statePath = [string](Get-IconSourceDirectoriesStatePath) } catch { $statePath = '' }
    $persisted = $false
    try {
      if (-not [string]::IsNullOrWhiteSpace($statePath) -and (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        $raw = [string](Get-Content -LiteralPath $statePath -Raw -Encoding UTF8)
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
          $obj = $raw | ConvertFrom-Json
          foreach ($it in @($obj)) {
            try {
              $pi = Get-SourcePathKey ([string]$it)
              if (-not [string]::IsNullOrWhiteSpace($pi) -and ($pi -eq $pKey)) { $persisted = $true; break }
            } catch {}
          }
        }
      }
    } catch {}
    if ($saveRes -and ($saveRes.PSObject.Properties.Match('Ok').Count -gt 0) -and -not [bool]$saveRes.Ok) {
      $msg = ''
      try { $msg = [string]$saveRes.Error } catch { $msg = '' }
      if ([string]::IsNullOrWhiteSpace($msg)) { $msg = 'Unknown save error.' }
      try { $statusText.Text = ("Added in session, but save failed: " + $msg) } catch {}
    } elseif ($persisted) {
      try { $statusText.Text = ("Directory added and saved: " + $statePath) } catch {}
    } else {
      try { $statusText.Text = 'Directory added in memory, but persistence could not be verified.' } catch {}
    }
  } else {
    try { Refresh-IconSourceDirectoryList } catch {}
    try { $statusText.Text = 'Directory already exists in the source list.' } catch {}
  }

  $sources = @()
  if ($isDir) {
    $sources = @(Get-CreateShortcutSystemIconSources | Where-Object {
      try { ([string]$_).ToLowerInvariant().StartsWith($p.ToLowerInvariant()) } catch { $false }
    })
  } else {
    $sources = @(Get-CreateShortcutSystemIconSources | Where-Object {
      try { ([string]$_).ToLowerInvariant() -eq $p.ToLowerInvariant() } catch { $false }
    })
  }
  $added = 0
  try { $added = [int](Add-IconsFromSources -Sources $sources -ShowProgress) } catch { $added = 0 }
  try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
  try { Refresh-IconListPage } catch {}
  try { Refresh-AssignedVisual } catch {}
  try {
    if (-not [string]::IsNullOrWhiteSpace([string]$statusText.Text) -and $statusText.Text -like 'Directory*') {
      $statusText.Text = ($statusText.Text + (" New icons indexed: {0}" -f $added))
    } else {
      $statusText.Text = ("Added icon source path. New icons indexed: {0}" -f $added)
    }
  } catch {}
}

function Remove-CustomIconSourceDirectories {
  param([object[]]$SelectedItems)
  try {
    $items = @($SelectedItems)
    if (@($items).Count -eq 0) {
      try { $statusText.Text = 'Select one or more source directories to remove.' } catch {}
      return
    }

    $removed = 0
    $blocked = 0
    $cancelled = 0
    foreach ($it in @($items)) {
      $n = ''
      $isBuiltIn = $false
      try { $isBuiltIn = [bool]$it.IsBuiltIn } catch { $isBuiltIn = $false }
      try { $n = [string]$it.Path } catch { $n = '' }
      if ([string]::IsNullOrWhiteSpace($n)) {
        try { $n = [string]$it } catch { $n = '' }
      }
      $n = $n.Trim()
      if ([string]::IsNullOrWhiteSpace($n)) { continue }
      $norm = Get-SourcePathKey $n
      if ([string]::IsNullOrWhiteSpace($norm)) { continue }

      $okDelete = $false
      try {
        $prompt = ("Are you sure you want to delete {0}?" -f $n)
        $dr = [System.Windows.MessageBox]::Show(
          $prompt,
          "Confirm Delete",
          [System.Windows.MessageBoxButton]::YesNo,
          [System.Windows.MessageBoxImage]::Question
        )
        $okDelete = ($dr -eq [System.Windows.MessageBoxResult]::Yes)
      } catch {
        $okDelete = $false
      }
      if (-not $okDelete) {
        $cancelled++
        continue
      }

      if ($isBuiltIn -or (Is-DefaultSourcePathKey $norm)) {
        try {
          $bidx = -1
          for ($bi = 0; $bi -lt $script:BuiltInIconSourceDirs.Count; $bi++) {
            $bk = ''
            try { $bk = Get-SourcePathKey ([string]$script:BuiltInIconSourceDirs[$bi]) } catch { $bk = '' }
            if ([string]::IsNullOrWhiteSpace($bk)) { continue }
            if ($bk -eq $norm) { $bidx = $bi; break }
          }
          if ($bidx -ge 0) { $script:BuiltInIconSourceDirs.RemoveAt($bidx) }
        } catch {}
        try { if ($script:IconSourceVisibilityByKey.ContainsKey($norm)) { [void]$script:IconSourceVisibilityByKey.Remove($norm) } } catch {}
        try { if ($script:SessionHiddenSourcePathKeys -and $script:SessionHiddenSourcePathKeys.ContainsKey([string]$norm)) { [void]$script:SessionHiddenSourcePathKeys.Remove([string]$norm) } } catch {}
        $removed++
        continue
      }

      $idx = -1
      for ($i = 0; $i -lt $script:CustomIconSourceDirs.Count; $i++) {
        $d = ''
        try { $d = Get-SourcePathKey ([string]$script:CustomIconSourceDirs[$i]) } catch { $d = '' }
        if ([string]::IsNullOrWhiteSpace($d)) { continue }
        if ($d -eq $norm) { $idx = $i; break }
      }

      if ($idx -ge 0) {
        try { $script:CustomIconSourceDirs.RemoveAt($idx) } catch {}
        try { if ($script:IconSourceVisibilityByKey.ContainsKey($norm)) { [void]$script:IconSourceVisibilityByKey.Remove($norm) } } catch {}
        try { if ($script:SessionHiddenSourcePathKeys -and $script:SessionHiddenSourcePathKeys.ContainsKey([string]$norm)) { [void]$script:SessionHiddenSourcePathKeys.Remove([string]$norm) } } catch {}
        $removed++
      } else {
        if (-not $isBuiltIn) {
          $dispNorm = ''
          try { $dispNorm = [string](Normalize-SourcePathForDisplay $n) } catch { $dispNorm = '' }
          if (-not [string]::IsNullOrWhiteSpace($dispNorm)) {
            for ($j = 0; $j -lt $script:CustomIconSourceDirs.Count; $j++) {
              $dj = ''
              try { $dj = [string](Normalize-SourcePathForDisplay ([string]$script:CustomIconSourceDirs[$j])) } catch { $dj = '' }
              if ([string]::IsNullOrWhiteSpace($dj)) { continue }
              if ($dj.Equals($dispNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
                $idx = $j
                break
              }
            }
          }
        }
        if ($idx -ge 0) {
          try { $script:CustomIconSourceDirs.RemoveAt($idx) } catch {}
          try { if ($script:IconSourceVisibilityByKey.ContainsKey($norm)) { [void]$script:IconSourceVisibilityByKey.Remove($norm) } } catch {}
          try { if ($script:SessionHiddenSourcePathKeys -and $script:SessionHiddenSourcePathKeys.ContainsKey([string]$norm)) { [void]$script:SessionHiddenSourcePathKeys.Remove([string]$norm) } } catch {}
          $removed++
        } else {
          $blocked++
        }
      }
    }

    if ($removed -gt 0) {
      try { Save-CustomIconSourceDirectories } catch {}
      try { Refresh-IconSourceDirectoryList } catch {}
      try { $script:IconFilterCacheQuery = $null; $script:IconFilterCacheItems = @() } catch {}
      try { $script:IconCurrentPage = 1 } catch {}
      try { Refresh-IconListPage } catch {}
    }

    if ($removed -gt 0 -and ($blocked -gt 0 -or $cancelled -gt 0)) {
      try { $statusText.Text = ("Removed {0} source path(s). Blocked: {1}. Cancelled: {2}." -f $removed, $blocked, $cancelled) } catch {}
    } elseif ($removed -gt 0) {
      try { $statusText.Text = ("Removed {0} source path(s)." -f $removed) } catch {}
    } else {
      try { $statusText.Text = ("No source paths removed. Cancelled: {0}." -f $cancelled) } catch {}
    }
  } catch {
    try { $statusText.Text = ("Remove source failed: " + [string]$_.Exception.Message) } catch {}
  }
}

function Backup-IconSourceDirectoriesState {
  try {
    $src = Get-IconSourceDirectoriesStatePath
    if ([string]::IsNullOrWhiteSpace($src) -or -not (Test-Path -LiteralPath $src -PathType Leaf)) {
      try { $statusText.Text = 'Backup skipped: IconSourceDirectories.json not found.' } catch {}
      return
    }
    $backupRoot = Get-StartMenuBackupsRoot
    if ([string]::IsNullOrWhiteSpace($backupRoot)) {
      try { $statusText.Text = 'Backup failed: Start Menu Backups path unavailable.' } catch {}
      return
    }
    $stamp = ''
    try { $stamp = (Get-Date).ToString('MMddyy.HHmmss') } catch { $stamp = '000000.000000' }
    $dst = Join-Path $backupRoot ("IconSourceDirectories_{0}.json" -f $stamp)
    Copy-Item -LiteralPath $src -Destination $dst -Force
    try { $statusText.Text = ("Backup created: " + [string]$dst) } catch {}
      try { Show-SaveCompletedDialog -Message ("Backup completed.`n" + [string]$dst) -Title 'Icon Allocator (v1.77)' } catch {}
  } catch {
    try { $statusText.Text = ("Backup failed: " + [string]$_.Exception.Message) } catch {}
  }
}

function Reload-CategoryProfilesFromDisk {
  try {
    try { $script:CategoryRows.Clear() } catch { $script:CategoryRows = New-Object System.Collections.Generic.List[object] }
    $script:AssignmentsByKey = @{}
    try { Invalidate-AssignmentDerivedCaches -BumpVersion } catch {}
    try { Refresh-CategoryList } catch {}
    $loaded = 0
    $profilesRoot = Get-IconCategoryProfilesRoot
    if (-not [string]::IsNullOrWhiteSpace($profilesRoot)) {
      try { $loaded = [int](Load-AssignmentsFromDirectory -DirectoryPath $profilesRoot) } catch { $loaded = 0 }
    }
    try { Apply-SavedCategoryPanelState } catch {}
    try { Capture-AssignmentBaseline } catch {}
    try { Refresh-AssignedVisual -ForceRebind } catch { try { Refresh-AssignedVisual } catch {} }
    try { Update-ToggleAllSelectCheckState } catch {}
    try { Update-ToggleAllCategoriesCheckState } catch {}
    try { Update-ToggleAllMaskCheckState } catch {}
    return [int]$loaded
  } catch {
    return 0
  }
}

function Refresh-ExternalStateIfChanged {
  try {
    $newSourceSig = [string](Get-FileStateSignature -Path (Get-IconSourceDirectoriesStatePath))
    $newCatSig = [string](Get-CategoryProfilesStateSignature)

    $sourceChanged = ($newSourceSig -ne [string]$script:IconSourceDirectoriesFileSignature)
    $categoriesChanged = ($newCatSig -ne [string]$script:CategoryProfilesSignature)

    if (-not $sourceChanged -and -not $categoriesChanged) {
      try { $statusText.Text = 'No external changes detected.' } catch {}
      try { Show-SaveCompletedDialog -Message 'Refresh completed. No external changes detected.' -Title 'Icon Allocator (v1.77)' } catch {}
      return
    }

    if ($sourceChanged) {
      try { $script:CustomIconSourceDirs.Clear() } catch { $script:CustomIconSourceDirs = New-Object System.Collections.Generic.List[string] }
      try { $script:BuiltInIconSourceDirs.Clear() } catch { $script:BuiltInIconSourceDirs = New-Object System.Collections.Generic.List[string] }
      try { $script:BuiltInSourcesInitialized = $false } catch {}
      try { $script:SessionHiddenSourcePathKeys = @{} } catch {}
      try { Load-CustomIconSourceDirectories } catch {}
      try { Refresh-IconSourceDirectoryList } catch {}

      try { $script:AllIcons.Clear() } catch { $script:AllIcons = New-Object System.Collections.Generic.List[object] }
      $script:IconsByKey = @{}
      $script:IconPixelHashByKey = @{}
      $script:IconSearchTextByKey = @{}
      $script:IconRowOrdinal = 0
      try { $iconList.ItemsSource = @() } catch {}
      try { Load-AllIcons } catch {}
    }

    $loadedProfiles = -1
    if ($categoriesChanged) {
      $loadedProfiles = [int](Reload-CategoryProfilesFromDisk)
    } elseif ($sourceChanged) {
      try { Refresh-AssignedVisual -ForceRebind } catch { try { Refresh-AssignedVisual } catch {} }
    }

    try { Capture-ExternalConfigSignatures } catch {}

    if ($sourceChanged -and $categoriesChanged) {
      try { $statusText.Text = ("Refreshed icon source directories and category files. Loaded profiles: {0}" -f [int]$loadedProfiles) } catch {}
      try { Show-SaveCompletedDialog -Message ("Refresh completed.`nIcon source directories and category files reloaded.`nLoaded profiles: {0}" -f [int]$loadedProfiles) -Title 'Icon Allocator (v1.77)' } catch {}
    } elseif ($sourceChanged) {
      try { $statusText.Text = 'Refreshed icon source directories.' } catch {}
      try { Show-SaveCompletedDialog -Message 'Refresh completed. Icon source directories reloaded.' -Title 'Icon Allocator (v1.77)' } catch {}
    } else {
      try { $statusText.Text = ("Refreshed category files. Loaded profiles: {0}" -f [int]$loadedProfiles) } catch {}
      try { Show-SaveCompletedDialog -Message ("Refresh completed.`nCategory files reloaded.`nLoaded profiles: {0}" -f [int]$loadedProfiles) -Title 'Icon Allocator (v1.77)' } catch {}
    }
  } catch {
    try { $statusText.Text = ("Refresh failed: " + [string]$_.Exception.Message) } catch {}
  }
}

if ($browseSourceDirBtn) {
  $browseSourceDirBtn.Add_Click({
    try {
      $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
      $dlg.Description = 'Select icon source folder'
      $dlg.ShowNewFolderButton = $false
      $seed = ''
      try { $seed = [string]$customSourceDirBox.Text } catch { $seed = '' }
      if (-not [string]::IsNullOrWhiteSpace($seed)) {
        try {
          $seedPath = Normalize-Path $seed
          if (Test-Path -LiteralPath $seedPath -PathType Container) {
            $dlg.SelectedPath = $seedPath
          } elseif (Test-Path -LiteralPath $seedPath -PathType Leaf) {
            $dlg.SelectedPath = Split-Path -Parent $seedPath
          }
        } catch {}
      }
      $dr = $dlg.ShowDialog()
      if ($dr -eq [System.Windows.Forms.DialogResult]::OK) {
        try { $customSourceDirBox.Text = [string](Normalize-SourcePathForDisplay ([string]$dlg.SelectedPath)) } catch {}
      }
    } catch {
      try { $statusText.Text = ("Browse failed: " + [string]$_.Exception.Message) } catch {}
    }
  })
}

if ($addSourceDirBtn) {
  $addSourceDirBtn.Add_Click({
    try { Add-CustomIconSourceDirectory -Path ([string]$customSourceDirBox.Text) } catch {
      try { $statusText.Text = ("Add source failed: " + [string]$_.Exception.Message) } catch {}
    }
  })
}

if ($removeSourceDirBtn) {
  $removeSourceDirBtn.Add_Click({
    try {
      $sel = @()
      try { $sel = @($iconSourceDirList.SelectedItems) } catch { $sel = @() }
      if (@($sel).Count -eq 0) {
        try {
          if ($iconSourceDirList -and $iconSourceDirList.SelectedItem) {
            $sel = @($iconSourceDirList.SelectedItem)
          }
        } catch {}
      }
      if (@($sel).Count -eq 0) {
        try {
          $cv = [System.Windows.Data.CollectionViewSource]::GetDefaultView($iconSourceDirList.ItemsSource)
          if ($cv -and $cv.CurrentItem) { $sel = @($cv.CurrentItem) }
        } catch {}
      }
      if (@($sel).Count -eq 0) {
        try {
          if ($script:LastSourcePathRow) { $sel = @($script:LastSourcePathRow) }
        } catch {}
      }
      if (@($sel).Count -eq 0) {
        try {
          $fe = [System.Windows.Input.Keyboard]::FocusedElement -as [System.Windows.FrameworkElement]
          if ($fe -and $fe.DataContext) {
            $hasPath = $false
            try { $hasPath = ($fe.DataContext.PSObject.Properties.Match('Path').Count -gt 0) } catch { $hasPath = $false }
            if ($hasPath) { $sel = @($fe.DataContext) }
          }
        } catch {}
      }
      if (@($sel).Count -eq 0) {
        try {
          $picked = @()
          $rows = @($iconSourceDirList.ItemsSource)
          foreach ($r in @($rows)) {
            if (-not $r) { continue }
            $rk = ''
            try { $rk = [string](Get-SourcePathKey ([string]$r.Path)) } catch { $rk = '' }
            if ([string]::IsNullOrWhiteSpace($rk)) { continue }
            $isBuiltIn = $false
            try { $isBuiltIn = [bool]$r.IsBuiltIn } catch { $isBuiltIn = $false }
            if ($script:SourcePathTogglePickKeys -and $script:SourcePathTogglePickKeys.Contains($rk)) {
              $picked += $r
            }
          }
          if (@($picked).Count -gt 0) { $sel = @($picked) }
        } catch {}
      }
      if (@($sel).Count -eq 0) {
        try { $statusText.Text = 'Select a source-path row (or its checkbox) first, then click Del.' } catch {}
        return
      }
      Remove-CustomIconSourceDirectories -SelectedItems $sel
      try { if ($script:SourcePathTogglePickKeys) { $script:SourcePathTogglePickKeys.Clear() } } catch {}
    } catch {
      try { $statusText.Text = ("Remove source failed: " + [string]$_.Exception.Message) } catch {}
    }
  })
}

if ($iconSourceDirList) {
  $iconSourceDirList.AddHandler(
    [System.Windows.UIElement]::PreviewMouseLeftButtonDownEvent,
    [System.Windows.RoutedEventHandler]{
      param($sender,$e)
      try {
        if (-not $iconSourceDirList) { return }
        $d = $e.OriginalSource -as [System.Windows.DependencyObject]
        if (-not $d) { return }
        $fe = $null
        while ($d) {
          $cand = $d -as [System.Windows.FrameworkElement]
          if ($cand -and $cand.DataContext) {
            $hasPath = $false
            try { $hasPath = ($cand.DataContext.PSObject.Properties.Match('Path').Count -gt 0) } catch { $hasPath = $false }
            if ($hasPath) { $fe = $cand; break }
          }
          try { $d = [System.Windows.Media.VisualTreeHelper]::GetParent($d) } catch { $d = $null }
        }
        if (-not $fe) { return }
        $row = $fe.DataContext
        if (-not $row) { return }
        try { $script:LastSourcePathRow = $row } catch {}

        $ctrl = $false; $shift = $false
        try { $ctrl = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftCtrl) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightCtrl) } catch {}
        try { $shift = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift) } catch {}
        if (-not $ctrl -and -not $shift) {
          try { $iconSourceDirList.SelectedItems.Clear() } catch {}
        }
        try {
          if (-not $iconSourceDirList.SelectedItems.Contains($row)) { [void]$iconSourceDirList.SelectedItems.Add($row) }
        } catch {
          try { $iconSourceDirList.SelectedItem = $row } catch {}
        }
        try { $iconSourceDirList.SelectedItem = $row } catch {}
      } catch {}
    },
    $true
  )

  $iconSourceDirList.AddHandler(
    [System.Windows.Controls.Primitives.ToggleButton]::CheckedEvent,
    [System.Windows.RoutedEventHandler]{
      param($sender,$e)
      try {
        if ([bool]$script:SuppressSourcePathUiEvents) { return }
        $cb = $e.OriginalSource -as [System.Windows.Controls.CheckBox]
        if (-not $cb) { return }
        $row = $cb.DataContext
        if (-not $row) { return }
        try { $script:LastSourcePathRow = $row } catch {}
        try {
          if ($iconSourceDirList) {
            if (-not $iconSourceDirList.SelectedItems.Contains($row)) {
              $iconSourceDirList.SelectedItem = $row
            }
          }
        } catch {}
        $path = ''
        try { $path = [string]$row.Path } catch { $path = '' }
        if ([string]::IsNullOrWhiteSpace($path)) { return }
        try {
          $pk = [string](Get-SourcePathKey $path)
          if (-not [string]::IsNullOrWhiteSpace($pk)) {
            if (-not $script:SourcePathTogglePickKeys.Contains($pk)) { [void]$script:SourcePathTogglePickKeys.Add($pk) }
          }
        } catch {}
        $show = $true
        try { $show = [bool]$row.ShowChecked } catch { $show = [bool]$cb.IsChecked }
        $current = $true
        try { $current = [bool](Get-SourcePathVisibility -Path $path) } catch { $current = $show }
        if ($current -eq [bool]$show) { return }
        Set-SourcePathVisibility -Path $path -Visible:$show
        try { Save-CustomIconSourceDirectories } catch {}
        try { Update-ToggleAllSourcePathsCheckState } catch {}
        try { Queue-SourcePathFilterRefresh } catch {}
      } catch {}
    },
    $true
  )
  $iconSourceDirList.AddHandler(
    [System.Windows.Controls.Primitives.ToggleButton]::UncheckedEvent,
    [System.Windows.RoutedEventHandler]{
      param($sender,$e)
      try {
        if ([bool]$script:SuppressSourcePathUiEvents) { return }
        $cb = $e.OriginalSource -as [System.Windows.Controls.CheckBox]
        if (-not $cb) { return }
        $row = $cb.DataContext
        if (-not $row) { return }
        try { $script:LastSourcePathRow = $row } catch {}
        try {
          if ($iconSourceDirList) {
            if (-not $iconSourceDirList.SelectedItems.Contains($row)) {
              $iconSourceDirList.SelectedItem = $row
            }
          }
        } catch {}
        $path = ''
        try { $path = [string]$row.Path } catch { $path = '' }
        if ([string]::IsNullOrWhiteSpace($path)) { return }
        try {
          $pk = [string](Get-SourcePathKey $path)
          if (-not [string]::IsNullOrWhiteSpace($pk)) {
            if (-not $script:SourcePathTogglePickKeys.Contains($pk)) { [void]$script:SourcePathTogglePickKeys.Add($pk) }
          }
        } catch {}
        $show = $false
        try { $show = [bool]$row.ShowChecked } catch { $show = [bool]$cb.IsChecked }
        $current = $true
        try { $current = [bool](Get-SourcePathVisibility -Path $path) } catch { $current = $show }
        if ($current -eq [bool]$show) { return }
        Set-SourcePathVisibility -Path $path -Visible:$show
        try { Save-CustomIconSourceDirectories } catch {}
        try { Update-ToggleAllSourcePathsCheckState } catch {}
        try { Queue-SourcePathFilterRefresh } catch {}
      } catch {}
    },
    $true
  )
}

if ($toggleAllSourcePathsBox) {
  $toggleAllSourcePathsBox.Add_Checked({
    try { if ($script:SuppressSourcePathUiEvents) { return } } catch {}
    try { Set-AllSourcePathsShown -Selected:$true } catch {}
  })
  $toggleAllSourcePathsBox.Add_Unchecked({
    try { if ($script:SuppressSourcePathUiEvents) { return } } catch {}
    try { Set-AllSourcePathsShown -Selected:$false } catch {}
  })
}

function Load-AllIcons {
  if (Test-StartupMainAbortRequested) { return }
  try { Set-StartupSplashStatus -Status "Loading icon sources..." -Value 66 } catch {}
  $statusText.Text = 'Loading icons...'
  $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
  if (Test-StartupMainAbortRequested) { return }
  $sources = @(Get-CreateShortcutSystemIconSources)
  [void](Add-IconsFromSources -Sources $sources -ShowProgress)
  if (Test-StartupMainAbortRequested) { return }
  try { Set-StartupSplashStatus -Status "Building icon list..." -Value 84 } catch {}
  try { $script:IconFilterCacheQuery = $null } catch {}
  try { $script:IconFilterCacheItems = @() } catch {}
  try { $script:IconSearchTextByKey = @{} } catch {}
  try { $script:IconCurrentPage = 1 } catch {}
  try { Refresh-IconListPage } catch {}
  if (Test-StartupMainAbortRequested) { return }
  try { Set-StartupSplashStatus -Status "Preparing first view..." -Value 94 } catch {}
  $statusText.Text = ("Loaded icons: {0}" -f @($script:AllIcons.ToArray()).Count)
}

try { Set-StartupSplashStatus -Status "Loading saved directories..." -Value 44 } catch {}
try { Load-CustomIconSourceDirectories } catch {}
try { Refresh-IconSourceDirectoryList } catch {}

try { Set-StartupSplashStatus -Status "Loading category profiles..." -Value 54 } catch {}
try {
  $profilesRoot = Get-IconCategoryProfilesRoot
  if (-not [string]::IsNullOrWhiteSpace($profilesRoot)) {
    $loadedProfiles = Load-AssignmentsFromDirectory -DirectoryPath $profilesRoot
    try { $statusText.Text = ("Loaded category profile files: {0}" -f [int]$loadedProfiles) } catch {}
  }
} catch {}
try { Apply-SavedCategoryPanelState } catch {}
try { Capture-AssignmentBaseline } catch {}
try { Capture-ExternalConfigSignatures } catch {}
try {
  $isExtractOn = $false
  try { if ($extractIconsModeBox) { $isExtractOn = [bool]$extractIconsModeBox.IsChecked } } catch {}
  Set-ExtractModeState -Enabled:$isExtractOn
} catch {}

$window.Add_ContentRendered({
  try {
    if (Test-StartupMainAbortRequested) {
      try { Close-StartupSplash } catch {}
      return
    }
    try { Set-StartupSplashStatus -Status "Finalizing startup..." -Value 97 } catch {}
    Load-AllIcons
    if (Test-StartupMainAbortRequested) {
      try { Close-StartupSplash } catch {}
      return
    }
    Refresh-AssignedVisual
    if (Test-StartupMainAbortRequested) {
      try { Close-StartupSplash } catch {}
      return
    }
    try { $script:StartupMainReady = $true } catch {}
    try { Set-StartupSplashStatus -Status "Ready" -Value 100 } catch {}
    try { Close-StartupSplash } catch {}
  } catch {
    if (-not (Test-StartupMainAbortRequested)) {
      $statusText.Text = ("Load failed: " + [string]$_.Exception.Message)
    }
    try { Close-StartupSplash } catch {}
  }
})

try {
  $null = $window.ShowDialog()
} finally {
  try { Close-StartupSplash } catch {}
}




















































