param(
    [switch]$InstallOnly
)

$ErrorActionPreference = 'SilentlyContinue'
$mcRoot = Join-Path $env:APPDATA '.minecraft'
if (-not (Test-Path -LiteralPath $mcRoot)) {
    New-Item -ItemType Directory -Path $mcRoot -Force | Out-Null
}

$tlExe  = Join-Path $mcRoot 'TLauncher.exe'
$tlOrig = Join-Path $mcRoot 'TLauncher_original.exe'
$syncGuiExe = Join-Path $mcRoot 'ModpackSyncGui.exe'

# Backup original TLauncher.exe (> 1 MB) to TLauncher_original.exe
if (Test-Path -LiteralPath $tlExe) {
    $item = Get-Item -LiteralPath $tlExe
    if ($item -and ($item.Length -gt 1000000)) {
        Copy-Item -LiteralPath $tlExe -Destination $tlOrig -Force
    }
}

if ($MyInvocation.MyCommand.Path -and (Test-Path -LiteralPath $MyInvocation.MyCommand.Path)) {
    $selfDest = Join-Path $mcRoot 'sync.ps1'
    if ($MyInvocation.MyCommand.Path -ne $selfDest) {
        Copy-Item -LiteralPath $MyInvocation.MyCommand.Path -Destination $selfDest -Force
    }
}
$batDest = Join-Path $mcRoot 'sync.bat'
$batLine = "@echo off`r`nstart `"`" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"%~dp0sync.ps1`"`r`n"
Set-Content -LiteralPath $batDest -Value $batLine -Encoding Ascii -Force

$csSource = @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace ModpackSync {
    public class BranchItem {
        public string Name { get; set; }
        public string Sha { get; set; }
        public override string ToString() {
            string shortSha = (Sha != null && Sha.Length >= 7) ? Sha.Substring(0, 7) : Sha;
            return Name + "  (\u043e\u0441\u0442\u0430\u043d\u043d\u0456\u0439 \u043a\u043e\u043c\u0456\u0442: " + shortSha + ")";
        }
    }

    public class CommitItem {
        public string FullSha { get; set; }
        public string ShortSha { get; set; }
        public string Date { get; set; }
        public string Message { get; set; }
        public override string ToString() {
            return "[" + ShortSha + "] " + Date + " \u2014 " + Message;
        }
    }

    public class RemoteTreeEntry {
        public string Path { get; set; }
        public string Sha { get; set; }
        public long Size { get; set; }
    }

    public class SyncForm : Form {
        private const string RepoUrl = "https://github.com/MrProper119/minecraft1.git";
        private const string ApiBase = "https://api.github.com/repos/MrProper119/minecraft1";
        private const string RawBase = "https://raw.githubusercontent.com/MrProper119/minecraft1";

        private static readonly HashSet<string> ExcludedUploadRootDirs = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
            "saves",
            "world",
            "backups",
            "backup",
            "mods_backup",
            "mods_disabled_by_sync",
            "logs",
            "crash-reports",
            "debug",
            ".git",
            ".cache",
            ".fabric",
            ".mixin.out",
            ".pg-native",
            ".probe",
            ".sable",
            ".vscode",
            "natives",
            "dynamic-resource-pack-cache",
            "vista_web_content_cache",
            "vista_ffmpeg_bin",
            "downloads",
            "local",
            "xaero",
            "XaeroWaypoints",
            "XaeroWaypoints_BACKUP240807",
            "XaeroMinimap",
            "XaeroWorldMap",
            "distant_horizons_server_data",
            "screenshots",
            "schematics",
            "telemetry",
            "webcache2",
            "server-resource-packs",
            "patchouli_books"
        };

        private static readonly HashSet<string> ExcludedUploadFiles = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
            ".synced_commit.txt",
            ".modpack_hash_cache.json",
            ".qmenu_opened.marker",
            "options.txt",
            "optionsof.txt",
            "optionsshaders.txt",
            "servers.dat",
            "servers.dat_old",
            "TLauncherAdditional.json",
            "command_history.txt",
            "usercache.json",
            "usernamecache.json",
            "patchouli_data.json",
            "ponders_watched.json",
            "ponders_watched_azimuth.json",
            "imgui.ini",
            "fabricloader.log",
            "temp_image_dump.png",
            "mods.zip",
            "sync.ps1",
            "sync.bat",
            "add_mod.bat",
            "push_changes.bat",
            "update_modpack.bat",
            ".ds_store",
            "thumbs.db"
        };

        private static readonly HashSet<string> ExcludedUploadRelPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase) {
            "config/fzzy_config/keybinds.toml",
            "config/xaerohud.txt",
            "config/xaeropatreon.txt",
            "config/xaerominimap.txt",
            "config/xaeroworldmap.txt",
            "config/create_submarine_client_state.json"
        };

        private string minecraftRoot;
        private string versionsRoot;
        private string stateFilePath;
        private string metaGitDir;

        private ComboBox cmbFolders;
        private Button btnBrowseFolder;
        private Button btnNewVersion;
        private ComboBox cmbBranches;
        private Button btnRefresh;
        private ComboBox cmbCommits;
        private Label lblCurrentCommit;

        private Panel pnlUpload;
        private RadioButton rbUploadExisting;
        private RadioButton rbUploadNew;
        private TextBox txtNewBranch;
        private TextBox txtCommitMsg;
        private Button btnUpload;

        private Label lblStatus;
        private ProgressBar progressBar;
        private TextBox txtLog;
        private Button btnSyncAndLaunch;
        private Button btnSyncOnly;
        private Button btnSkipAndLaunch;

        private bool isBusy = false;
        private string[] launchArgs;

        public SyncForm(string[] args) {
            this.launchArgs = args ?? new string[0];
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;

            minecraftRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), ".minecraft");
            versionsRoot = Path.Combine(minecraftRoot, "versions");
            stateFilePath = Path.Combine(minecraftRoot, "modpack_sync_state.json");
            metaGitDir = Path.Combine(minecraftRoot, ".modpack_meta_git");

            InitializeComponents();
            LoadFolders();
            string savedBranch = null;
            if (File.Exists(stateFilePath)) {
                try {
                    JavaScriptSerializer js = new JavaScriptSerializer();
                    var dict = js.Deserialize<Dictionary<string, object>>(File.ReadAllText(stateFilePath, Encoding.UTF8));
                    if (dict != null && dict.ContainsKey("LastBranch") && dict["LastBranch"] != null) {
                        savedBranch = dict["LastBranch"].ToString();
                    }
                } catch { }
            }
            this.Shown += (s, e) => FetchBranchesAsync(savedBranch);
        }

        private void InitializeComponents() {
            this.Text = "\u0421\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u044f \u0437\u0431\u0456\u0440\u043a\u0438 Minecraft 1.21.1 (GitHub <-> TLauncher)";
            this.Size = new Size(760, 710);
            this.MinimumSize = new Size(740, 690);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.FromArgb(30, 30, 46);
            this.ForeColor = Color.FromArgb(205, 214, 244);
            this.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);

            try {
                string icoPath = Path.Combine(minecraftRoot, "libraries", "minecraft.ico");
                if (File.Exists(icoPath)) {
                    this.Icon = new Icon(icoPath);
                }
            } catch { }

            Label lblHeader = new Label();
            lblHeader.Text = "\u0421\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u044f \u043c\u043e\u0434\u043f\u0430\u043a\u0443 Minecraft (Delta Sync & Upload)";
            lblHeader.Font = new Font("Segoe UI", 14f, FontStyle.Bold);
            lblHeader.ForeColor = Color.FromArgb(137, 180, 250);
            lblHeader.Location = new Point(20, 12);
            lblHeader.AutoSize = true;
            this.Controls.Add(lblHeader);

            Label lblSubHeader = new Label();
            lblSubHeader.Text = "\u0417\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0443\u0439\u0442\u0435 \u0430\u0431\u043e \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0443\u0439\u0442\u0435 \u0437\u0431\u0456\u0440\u043a\u0443 \u0432 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0456\u0439 GitHub \u0437 \u043f\u0435\u0440\u0435\u0432\u0456\u0440\u043a\u043e\u044e \u0432\u0456\u0434\u043c\u0456\u043d\u043d\u043e\u0441\u0442\u0435\u0439";
            lblSubHeader.Font = new Font("Segoe UI", 9f, FontStyle.Regular);
            lblSubHeader.ForeColor = Color.FromArgb(166, 173, 200);
            lblSubHeader.Location = new Point(22, 39);
            lblSubHeader.AutoSize = true;
            this.Controls.Add(lblSubHeader);

            Label lblFolder = new Label();
            lblFolder.Text = "1. \u041f\u0430\u043f\u043a\u0430 \u0437\u0431\u0456\u0440\u043a\u0438 (\u0434\u043b\u044f \u0437\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0430\u0431\u043e \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f):";
            lblFolder.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            lblFolder.Location = new Point(20, 68);
            lblFolder.AutoSize = true;
            this.Controls.Add(lblFolder);

            cmbFolders = new ComboBox();
            cmbFolders.Location = new Point(20, 91);
            cmbFolders.Size = new Size(510, 28);
            cmbFolders.BackColor = Color.FromArgb(49, 50, 68);
            cmbFolders.ForeColor = Color.White;
            cmbFolders.SelectedIndexChanged += (s, e) => UpdateCurrentFolderInfo();
            cmbFolders.TextChanged += (s, e) => UpdateCurrentFolderInfo();
            this.Controls.Add(cmbFolders);

            btnBrowseFolder = CreateButton("\u041e\u0433\u043b\u044f\u0434...", new Point(540, 89), new Size(90, 28), Color.FromArgb(69, 71, 90));
            btnBrowseFolder.Click += BtnBrowseFolder_Click;
            this.Controls.Add(btnBrowseFolder);

            btnNewVersion = CreateButton("+ \u041d\u043e\u0432\u0430", new Point(638, 89), new Size(85, 28), Color.FromArgb(69, 71, 90));
            btnNewVersion.Click += BtnNewVersion_Click;
            this.Controls.Add(btnNewVersion);

            Label lblBranch = new Label();
            lblBranch.Text = "2. \u0413\u0456\u043b\u043a\u0430 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0456\u044e (Branch):";
            lblBranch.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            lblBranch.Location = new Point(20, 126);
            lblBranch.AutoSize = true;
            this.Controls.Add(lblBranch);

            cmbBranches = new ComboBox();
            cmbBranches.DropDownStyle = ComboBoxStyle.DropDownList;
            cmbBranches.Location = new Point(20, 149);
            cmbBranches.Size = new Size(580, 28);
            cmbBranches.BackColor = Color.FromArgb(49, 50, 68);
            cmbBranches.ForeColor = Color.White;
            cmbBranches.SelectedIndexChanged += CmbBranches_SelectedIndexChanged;
            this.Controls.Add(cmbBranches);

            btnRefresh = CreateButton("\u041e\u043d\u043e\u0432\u0438\u0442\u0438", new Point(610, 147), new Size(113, 28), Color.FromArgb(69, 71, 90));
            btnRefresh.Click += (s, e) => FetchBranchesAsync(null);
            this.Controls.Add(btnRefresh);

            Label lblCommit = new Label();
            lblCommit.Text = "3. \u041a\u043e\u043c\u0456\u0442 \u0434\u043b\u044f \u0437\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f (\u0430\u0431\u043e \u0432\u0432\u0435\u0434\u0456\u0442\u044c \u0445\u0435\u0448 \u043a\u043e\u043c\u0456\u0442\u0443 \u0432\u0440\u0443\u0447\u043d\u0443):";
            lblCommit.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            lblCommit.Location = new Point(20, 184);
            lblCommit.AutoSize = true;
            this.Controls.Add(lblCommit);

            cmbCommits = new ComboBox();
            cmbCommits.Location = new Point(20, 207);
            cmbCommits.Size = new Size(703, 28);
            cmbCommits.BackColor = Color.FromArgb(49, 50, 68);
            cmbCommits.ForeColor = Color.White;
            this.Controls.Add(cmbCommits);

            lblCurrentCommit = new Label();
            lblCurrentCommit.Text = "\u0412\u0441\u0442\u0430\u043d\u043e\u0432\u043b\u0435\u043d\u0438\u0439 \u0443 \u043f\u0430\u043f\u0446\u0456 \u043a\u043e\u043c\u0456\u0442: \u043f\u0435\u0440\u0435\u0432\u0456\u0440\u043a\u0430...";
            lblCurrentCommit.ForeColor = Color.FromArgb(249, 226, 175);
            lblCurrentCommit.Location = new Point(20, 239);
            lblCurrentCommit.AutoSize = true;
            this.Controls.Add(lblCurrentCommit);

            pnlUpload = new Panel();
            pnlUpload.Location = new Point(20, 268);
            pnlUpload.Size = new Size(703, 134);
            pnlUpload.BackColor = Color.FromArgb(38, 39, 58);
            pnlUpload.BorderStyle = BorderStyle.FixedSingle;
            this.Controls.Add(pnlUpload);

            Label lblUploadTitle = new Label();
            lblUploadTitle.Text = "4. \u0412\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0441\u0432\u043e\u0454\u0457 \u0432\u0435\u0440\u0441\u0456\u0457 \u0437\u0431\u0456\u0440\u043a\u0438 \u0432 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0456\u0439 (Upload \u043d\u0430 GitHub):";
            lblUploadTitle.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            lblUploadTitle.ForeColor = Color.FromArgb(203, 166, 247);
            lblUploadTitle.Location = new Point(10, 8);
            lblUploadTitle.AutoSize = true;
            pnlUpload.Controls.Add(lblUploadTitle);

            rbUploadExisting = new RadioButton();
            rbUploadExisting.Text = "\u0412 \u0456\u0441\u043d\u0443\u044e\u0447\u0443 \u0433\u0456\u043b\u043a\u0443 (\u0442\u0456\u043b\u044c\u043a\u0438 \u0437\u043c\u0456\u043d\u0435\u043d\u0456)";
            rbUploadExisting.Font = new Font("Segoe UI", 9f, FontStyle.Regular);
            rbUploadExisting.ForeColor = Color.White;
            rbUploadExisting.Location = new Point(12, 34);
            rbUploadExisting.AutoSize = true;
            rbUploadExisting.Checked = true;
            rbUploadExisting.CheckedChanged += (s, e) => {
                txtNewBranch.Enabled = !isBusy && rbUploadNew.Checked;
            };
            pnlUpload.Controls.Add(rbUploadExisting);

            rbUploadNew = new RadioButton();
            rbUploadNew.Text = "\u0423 \u043d\u043e\u0432\u0443 \u0433\u0456\u043b\u043a\u0443 (\u0443\u0441\u0435, \u043a\u0440\u0456\u043c saves/):";
            rbUploadNew.Font = new Font("Segoe UI", 9f, FontStyle.Regular);
            rbUploadNew.ForeColor = Color.White;
            rbUploadNew.Location = new Point(252, 34);
            rbUploadNew.AutoSize = true;
            rbUploadNew.CheckedChanged += (s, e) => {
                txtNewBranch.Enabled = !isBusy && rbUploadNew.Checked;
                if (rbUploadNew.Checked) {
                    txtNewBranch.Focus();
                    txtNewBranch.SelectAll();
                }
            };
            pnlUpload.Controls.Add(rbUploadNew);

            txtNewBranch = new TextBox();
            txtNewBranch.Text = "my-modpack-branch";
            txtNewBranch.Font = new Font("Segoe UI", 9f, FontStyle.Regular);
            txtNewBranch.BackColor = Color.FromArgb(49, 50, 68);
            txtNewBranch.ForeColor = Color.White;
            txtNewBranch.Location = new Point(475, 32);
            txtNewBranch.Size = new Size(214, 24);
            txtNewBranch.Enabled = false;
            pnlUpload.Controls.Add(txtNewBranch);

            Label lblCommitMsg = new Label();
            lblCommitMsg.Text = "\u041e\u043f\u0438\u0441 (\u043d\u0430\u0437\u0432\u0430) \u043a\u043e\u043c\u0456\u0442\u0443:";
            lblCommitMsg.Font = new Font("Segoe UI", 9f, FontStyle.Regular);
            lblCommitMsg.ForeColor = Color.FromArgb(205, 214, 244);
            lblCommitMsg.Location = new Point(10, 69);
            lblCommitMsg.AutoSize = true;
            pnlUpload.Controls.Add(lblCommitMsg);

            txtCommitMsg = new TextBox();
            txtCommitMsg.Text = "\u041e\u043d\u043e\u0432\u043b\u0435\u043d\u043d\u044f \u0437\u0431\u0456\u0440\u043a\u0438";
            txtCommitMsg.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);
            txtCommitMsg.BackColor = Color.FromArgb(49, 50, 68);
            txtCommitMsg.ForeColor = Color.White;
            txtCommitMsg.Location = new Point(150, 66);
            txtCommitMsg.Size = new Size(340, 26);
            pnlUpload.Controls.Add(txtCommitMsg);

            btnUpload = CreateButton("\u0412\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0438\u0442\u0438 \u0437\u0431\u0456\u0440\u043a\u0443", new Point(500, 63), new Size(189, 32), Color.FromArgb(137, 87, 229));
            btnUpload.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            btnUpload.Click += (s, e) => StartUploadAsync();
            pnlUpload.Controls.Add(btnUpload);

            Label lblUploadHint = new Label();
            lblUploadHint.Text = "\u0412 \u0456\u0441\u043d\u0443\u044e\u0447\u0443 \u0433\u0456\u043b\u043a\u0443: \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0443\u0454 \u043b\u0438\u0448\u0435 \u043d\u043e\u0432\u0456/\u0437\u043c\u0456\u043d\u0435\u043d\u0456 \u0444\u0430\u0439\u043b\u0438. \u0423 \u043d\u043e\u0432\u0443 \u0433\u0456\u043b\u043a\u0443: \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0443\u0454 \u0432\u0441\u0456 \u0444\u0430\u0439\u043b\u0438 \u0437\u0431\u0456\u0440\u043a\u0438 (\u043a\u0440\u0456\u043c \u043f\u0430\u043f\u043a\u0438 \u0437\u0456 \u0441\u0432\u0456\u0442\u0430\u043c\u0438 saves/).";
            lblUploadHint.Font = new Font("Segoe UI", 8.2f, FontStyle.Regular);
            lblUploadHint.ForeColor = Color.FromArgb(166, 173, 200);
            lblUploadHint.Location = new Point(10, 104);
            lblUploadHint.AutoSize = true;
            pnlUpload.Controls.Add(lblUploadHint);

            lblStatus = new Label();
            lblStatus.Text = "\u0413\u043e\u0442\u043e\u0432\u043e \u0434\u043e \u0440\u043e\u0431\u043e\u0442\u0438.";
            lblStatus.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            lblStatus.ForeColor = Color.FromArgb(166, 227, 161);
            lblStatus.Location = new Point(20, 412);
            lblStatus.Size = new Size(703, 22);
            this.Controls.Add(lblStatus);

            progressBar = new ProgressBar();
            progressBar.Location = new Point(20, 438);
            progressBar.Size = new Size(703, 24);
            progressBar.Minimum = 0;
            progressBar.Maximum = 1000;
            progressBar.Value = 0;
            this.Controls.Add(progressBar);

            txtLog = new TextBox();
            txtLog.Multiline = true;
            txtLog.ReadOnly = true;
            txtLog.ScrollBars = ScrollBars.Vertical;
            txtLog.BackColor = Color.FromArgb(24, 24, 37);
            txtLog.ForeColor = Color.FromArgb(205, 214, 244);
            txtLog.Font = new Font("Consolas", 9f);
            txtLog.Location = new Point(20, 472);
            txtLog.Size = new Size(703, 130);
            this.Controls.Add(txtLog);

            btnSyncAndLaunch = CreateButton("\u0417\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0438\u0442\u0438 \u0442\u0430 \u0437\u0430\u043f\u0443\u0441\u0442\u0438\u0442\u0438 TLauncher", new Point(20, 614), new Size(310, 40), Color.FromArgb(46, 160, 67));
            btnSyncAndLaunch.Font = new Font("Segoe UI", 10f, FontStyle.Bold);
            btnSyncAndLaunch.Click += (s, e) => StartSyncAsync(true);
            this.Controls.Add(btnSyncAndLaunch);

            btnSyncOnly = CreateButton("\u0422\u0456\u043b\u044c\u043a\u0438 \u0437\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0438\u0442\u0438", new Point(340, 614), new Size(175, 40), Color.FromArgb(56, 110, 200));
            btnSyncOnly.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            btnSyncOnly.Click += (s, e) => StartSyncAsync(false);
            this.Controls.Add(btnSyncOnly);

            btnSkipAndLaunch = CreateButton("\u041f\u0440\u043e\u043f\u0443\u0441\u0442\u0438\u0442\u0438 -> TLauncher", new Point(525, 614), new Size(198, 40), Color.FromArgb(88, 91, 112));
            btnSkipAndLaunch.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);
            btnSkipAndLaunch.Click += (s, e) => {
                LaunchTLauncher();
                this.Close();
            };
            this.Controls.Add(btnSkipAndLaunch);
        }

        private Button CreateButton(string text, Point location, Size size, Color backColor) {
            Button btn = new Button();
            btn.Text = text;
            btn.Location = location;
            btn.Size = size;
            btn.FlatStyle = FlatStyle.Flat;
            btn.FlatAppearance.BorderSize = 0;
            btn.BackColor = backColor;
            btn.ForeColor = Color.White;
            btn.Cursor = Cursors.Hand;
            return btn;
        }

        private void LogMessage(string msg) {
            if (this.InvokeRequired) {
                this.BeginInvoke(new Action<string>(LogMessage), msg);
                return;
            }
            string line = "[" + DateTime.Now.ToString("HH:mm:ss") + "] " + msg + Environment.NewLine;
            txtLog.AppendText(line);
        }

        private void SetStatus(string status, int progressPerMille) {
            if (this.InvokeRequired) {
                this.BeginInvoke(new Action<string, int>(SetStatus), status, progressPerMille);
                return;
            }
            lblStatus.Text = status;
            if (progressPerMille >= 0) {
                progressBar.Value = Math.Min(1000, Math.Max(0, progressPerMille));
            }
        }

        private void SetBusy(bool busy) {
            if (this.InvokeRequired) {
                this.BeginInvoke(new Action<bool>(SetBusy), busy);
                return;
            }
            isBusy = busy;
            cmbFolders.Enabled = !busy;
            btnBrowseFolder.Enabled = !busy;
            btnNewVersion.Enabled = !busy;
            cmbBranches.Enabled = !busy;
            btnRefresh.Enabled = !busy;
            cmbCommits.Enabled = !busy;
            rbUploadExisting.Enabled = !busy;
            rbUploadNew.Enabled = !busy;
            txtNewBranch.Enabled = !busy && rbUploadNew.Checked;
            txtCommitMsg.Enabled = !busy;
            btnUpload.Enabled = !busy;
            btnSyncAndLaunch.Enabled = !busy;
            btnSyncOnly.Enabled = !busy;
        }

        private void LoadFolders() {
            cmbFolders.Items.Clear();
            string defaultDir = Path.Combine(versionsRoot, "Test");

            if (File.Exists(stateFilePath)) {
                try {
                    JavaScriptSerializer js = new JavaScriptSerializer();
                    var dict = js.Deserialize<Dictionary<string, object>>(File.ReadAllText(stateFilePath, Encoding.UTF8));
                    if (dict != null && dict.ContainsKey("LastTargetDir") && dict["LastTargetDir"] != null) {
                        string savedDir = dict["LastTargetDir"].ToString();
                        if (!string.IsNullOrEmpty(savedDir)) {
                            defaultDir = savedDir;
                        }
                    }
                } catch { }
            }

            cmbFolders.Items.Add(defaultDir);
            if (Directory.Exists(versionsRoot)) {
                foreach (string dir in Directory.GetDirectories(versionsRoot)) {
                    if (!string.Equals(dir, defaultDir, StringComparison.OrdinalIgnoreCase)) {
                        cmbFolders.Items.Add(dir);
                    }
                }
            }
            cmbFolders.SelectedIndex = 0;
            UpdateCurrentFolderInfo();
        }

        private void UpdateCurrentFolderInfo() {
            string folder = (cmbFolders.Text ?? "").Trim();
            if (string.IsNullOrEmpty(folder)) {
                lblCurrentCommit.Text = "\u0412\u0441\u0442\u0430\u043d\u043e\u0432\u043b\u0435\u043d\u0438\u0439 \u0443 \u043f\u0430\u043f\u0446\u0456 \u043a\u043e\u043c\u0456\u0442: \u043f\u0430\u043f\u043a\u0430 \u043d\u0435 \u043e\u0431\u0440\u0430\u043d\u0430";
                return;
            }
            string markerFile = Path.Combine(folder, ".synced_commit.txt");
            string gitHead = Path.Combine(folder, ".git", "HEAD");
            string currentSha = null;

            if (File.Exists(markerFile)) {
                try { currentSha = File.ReadAllText(markerFile, Encoding.UTF8).Trim(); } catch { }
            }
            if (string.IsNullOrEmpty(currentSha) && File.Exists(gitHead)) {
                try {
                    string headContent = File.ReadAllText(gitHead, Encoding.UTF8).Trim();
                    if (headContent.StartsWith("ref: ")) {
                        string refRel = headContent.Substring(5).Trim().Replace('/', Path.DirectorySeparatorChar);
                        string refFile = Path.Combine(folder, ".git", refRel);
                        if (File.Exists(refFile)) {
                            currentSha = File.ReadAllText(refFile, Encoding.UTF8).Trim();
                        }
                    } else {
                        currentSha = headContent;
                    }
                } catch { }
            }

            if (!string.IsNullOrEmpty(currentSha)) {
                string shortSha = currentSha.Length >= 7 ? currentSha.Substring(0, 7) : currentSha;
                lblCurrentCommit.Text = "\u0412\u0441\u0442\u0430\u043d\u043e\u0432\u043b\u0435\u043d\u0438\u0439 \u0443 \u043f\u0430\u043f\u0446\u0456 \u043a\u043e\u043c\u0456\u0442: " + shortSha;
            } else if (Directory.Exists(folder)) {
                int jarCount = Directory.Exists(Path.Combine(folder, "mods")) ? Directory.GetFiles(Path.Combine(folder, "mods"), "*.jar").Length : 0;
                lblCurrentCommit.Text = "\u0412\u0441\u0442\u0430\u043d\u043e\u0432\u043b\u0435\u043d\u0438\u0439 \u0443 \u043f\u0430\u043f\u0446\u0456 \u043a\u043e\u043c\u0456\u0442: \u043d\u0435\u0432\u0456\u0434\u043e\u043c\u043e (\u043c\u043e\u0434\u0456\u0432 \u0443 \u043f\u0430\u043f\u0446\u0456: " + jarCount + ")";
            } else {
                lblCurrentCommit.Text = "\u041f\u0430\u043f\u043a\u0430 \u0449\u0435 \u043d\u0435 \u0456\u0441\u043d\u0443\u0454 \u2014 \u0431\u0443\u0434\u0435 \u0441\u0442\u0432\u043e\u0440\u0435\u043d\u0430 \u0430\u0432\u0442\u043e\u043c\u0430\u0442\u0438\u0447\u043d\u043e";
            }
        }

        private void BtnBrowseFolder_Click(object sender, EventArgs e) {
            using (FolderBrowserDialog dlg = new FolderBrowserDialog()) {
                dlg.Description = "\u041e\u0431\u0435\u0440\u0456\u0442\u044c \u043f\u0430\u043f\u043a\u0443 \u0437\u0431\u0456\u0440\u043a\u0438";
                dlg.SelectedPath = Directory.Exists(cmbFolders.Text) ? cmbFolders.Text : versionsRoot;
                dlg.ShowNewFolderButton = true;
                if (dlg.ShowDialog(this) == DialogResult.OK) {
                    cmbFolders.Text = dlg.SelectedPath;
                }
            }
        }

        private void BtnNewVersion_Click(object sender, EventArgs e) {
            Form prompt = new Form() {
                Width = 420,
                Height = 165,
                FormBorderStyle = FormBorderStyle.FixedDialog,
                Text = "\u0421\u0442\u0432\u043e\u0440\u0435\u043d\u043d\u044f \u043d\u043e\u0432\u043e\u0457 \u043f\u0430\u043f\u043a\u0438 \u0432\u0435\u0440\u0441\u0456\u0457",
                StartPosition = FormStartPosition.CenterParent,
                BackColor = Color.FromArgb(30, 30, 46),
                ForeColor = Color.White,
                MaximizeBox = false,
                MinimizeBox = false
            };
            Label lbl = new Label() { Left = 16, Top = 16, Width = 370, Text = "\u0412\u0432\u0435\u0434\u0456\u0442\u044c \u043d\u0430\u0437\u0432\u0443 \u043d\u043e\u0432\u043e\u0457 \u0432\u0435\u0440\u0441\u0456\u0457 \u0443 .minecraft\\versions:" };
            TextBox txt = new TextBox() { Left = 16, Top = 42, Width = 370, Text = "Modpack_New", BackColor = Color.FromArgb(49, 50, 68), ForeColor = Color.White };
            Button ok = CreateButton("\u0421\u0442\u0432\u043e\u0440\u0438\u0442\u0438", new Point(210, 80), new Size(85, 30), Color.FromArgb(46, 160, 67));
            Button cancel = CreateButton("\u0421\u043a\u0430\u0441\u0443\u0432\u0430\u0442\u0438", new Point(301, 80), new Size(85, 30), Color.FromArgb(88, 91, 112));
            ok.DialogResult = DialogResult.OK;
            cancel.DialogResult = DialogResult.Cancel;
            prompt.Controls.Add(lbl);
            prompt.Controls.Add(txt);
            prompt.Controls.Add(ok);
            prompt.Controls.Add(cancel);
            prompt.AcceptButton = ok;
            prompt.CancelButton = cancel;

            if (prompt.ShowDialog(this) == DialogResult.OK) {
                string name = (txt.Text ?? "").Trim();
                foreach (char c in Path.GetInvalidFileNameChars()) {
                    name = name.Replace(c, '_');
                }
                if (!string.IsNullOrEmpty(name)) {
                    string fullPath = Path.Combine(versionsRoot, name);
                    if (!cmbFolders.Items.Contains(fullPath)) {
                        cmbFolders.Items.Insert(0, fullPath);
                    }
                    cmbFolders.SelectedItem = fullPath;
                }
            }
        }

        private string FindGitExe() {
            string[] candidates = new string[] {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Git", "cmd", "git.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Git", "cmd", "git.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Git", "cmd", "git.exe")
            };
            foreach (string c in candidates) {
                if (File.Exists(c)) return c;
            }
            string ghDesktop = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "GitHubDesktop");
            if (Directory.Exists(ghDesktop)) {
                foreach (string d in Directory.GetDirectories(ghDesktop, "app-*")) {
                    string g = Path.Combine(d, "resources", "app", "git", "cmd", "git.exe");
                    if (File.Exists(g)) return g;
                }
            }
            return "git";
        }

        private string RunGitCommand(string workingDir, string arguments) {
            int exitCode;
            string stdErr;
            return RunGitCommandEx(workingDir, arguments, out exitCode, out stdErr);
        }

        private string RunGitCommandEx(string workingDir, string arguments, out int exitCode, out string stdErr) {
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = FindGitExe();
            psi.Arguments = arguments;
            psi.WorkingDirectory = workingDir;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.StandardOutputEncoding = Encoding.UTF8;
            psi.StandardErrorEncoding = Encoding.UTF8;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            using (Process p = Process.Start(psi)) {
                string output = p.StandardOutput.ReadToEnd();
                stdErr = p.StandardError.ReadToEnd();
                p.WaitForExit();
                exitCode = p.ExitCode;
                return output;
            }
        }

        private void EnsureMetaGitUpdated() {
            if (!Directory.Exists(metaGitDir)) {
                Directory.CreateDirectory(metaGitDir);
            }
            if (!Directory.Exists(Path.Combine(metaGitDir, ".git"))) {
                RunGitCommand(metaGitDir, "init");
                RunGitCommand(metaGitDir, "remote add origin " + RepoUrl);
                RunGitCommand(metaGitDir, "config core.repositoryformatversion 1");
                RunGitCommand(metaGitDir, "config extensions.partialclone origin");
                RunGitCommand(metaGitDir, "config remote.origin.promisor true");
                RunGitCommand(metaGitDir, "config remote.origin.partialclonefilter blob:none");
            }
            RunGitCommand(metaGitDir, "fetch --filter=blob:none --no-tags --prune origin \"+refs/heads/*:refs/remotes/origin/*\"");
        }

        private string HttpGetJson(string url) {
            HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url);
            req.UserAgent = "MinecraftModpackDeltaSync/4.0";
            req.Timeout = 15000;
            using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
            using (StreamReader sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8)) {
                return sr.ReadToEnd();
            }
        }

        private void FetchBranchesAsync(string selectBranchName) {
            if (isBusy) return;
            SetBusy(true);
            SetStatus("\u041e\u0442\u0440\u0438\u043c\u0430\u043d\u043d\u044f \u0441\u043f\u0438\u0441\u043a\u0443 \u0433\u0456\u043b\u043e\u043a \u0456\u0437 GitHub...", 50);
            LogMessage("\u0417\u0430\u043f\u0438\u0442 \u0441\u043f\u0438\u0441\u043a\u0443 \u0433\u0456\u043b\u043e\u043a \u0456\u0437 GitHub...");

            ThreadPool.QueueUserWorkItem(_ => {
                List<BranchItem> branches = new List<BranchItem>();
                try {
                    try {
                        EnsureMetaGitUpdated();
                        string refsOut = RunGitCommand(metaGitDir, "for-each-ref --sort=-committerdate \"refs/remotes/origin\" --format=\"%(refname:short)|%(objectname)\"");
                        foreach (string line in refsOut.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)) {
                            string[] parts = line.Split('|');
                            if (parts.Length < 2) continue;
                            string bName = Regex.Replace(parts[0].Trim(), "^origin/", "");
                            if (bName == "HEAD" || bName == "origin" || string.Equals(bName, "sync-script", StringComparison.OrdinalIgnoreCase)) continue;
                            branches.Add(new BranchItem { Name = bName, Sha = parts[1].Trim() });
                        }
                    } catch {
                    }

                    if (branches.Count == 0) {
                        string json = HttpGetJson(ApiBase + "/branches?per_page=100");
                        JavaScriptSerializer js = new JavaScriptSerializer();
                        js.MaxJsonLength = int.MaxValue;
                        var rawBranches = js.Deserialize<List<Dictionary<string, object>>>(json);
                        if (rawBranches != null) {
                            foreach (var b in rawBranches) {
                                string name = b.ContainsKey("name") ? Convert.ToString(b["name"]) : "";
                                if (string.IsNullOrEmpty(name) || string.Equals(name, "sync-script", StringComparison.OrdinalIgnoreCase)) {
                                    continue;
                                }
                                string sha = "";
                                if (b.ContainsKey("commit") && b["commit"] is Dictionary<string, object>) {
                                    var commitObj = (Dictionary<string, object>)b["commit"];
                                    if (commitObj.ContainsKey("sha")) {
                                        sha = Convert.ToString(commitObj["sha"]);
                                    }
                                }
                                branches.Add(new BranchItem { Name = name, Sha = sha });
                            }
                        }
                    }

                    branches.Sort((a, b) => {
                        Func<string, int> getScore = name => {
                            if (name == "test2") return 0;
                            if (name == "test") return 1;
                            if (name == "main") return 2;
                            if (name.StartsWith("mekanism-realistic-fixed")) return 3;
                            if (name.StartsWith("mekanism-realistic")) return 4;
                            return 5;
                        };
                        int scoreA = getScore(a.Name);
                        int scoreB = getScore(b.Name);
                        if (scoreA != scoreB) return scoreA.CompareTo(scoreB);
                        return string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase);
                    });

                    this.BeginInvoke(new Action(() => {
                        cmbBranches.Items.Clear();
                        int targetIdx = 0;
                        for (int i = 0; i < branches.Count; i++) {
                            cmbBranches.Items.Add(branches[i]);
                            if (!string.IsNullOrEmpty(selectBranchName) &&
                                string.Equals(branches[i].Name, selectBranchName, StringComparison.OrdinalIgnoreCase)) {
                                targetIdx = i;
                            }
                        }
                        SetBusy(false);
                        if (cmbBranches.Items.Count > 0) {
                            cmbBranches.SelectedIndex = targetIdx;
                        } else {
                            SetStatus("\u0413\u0456\u043b\u043a\u0438 \u043d\u0435 \u0437\u043d\u0430\u0439\u0434\u0435\u043d\u043e.", 0);
                        }
                    }));
                } catch (Exception ex) {
                    this.BeginInvoke(new Action(() => {
                        SetBusy(false);
                        SetStatus("\u041f\u043e\u043c\u0438\u043b\u043a\u0430 \u043e\u0442\u0440\u0438\u043c\u0430\u043d\u043d\u044f \u0433\u0456\u043b\u043e\u043a: " + ex.Message, 0);
                        LogMessage("\u041f\u043e\u043c\u0438\u043b\u043a\u0430: " + ex.Message);
                    }));
                }
            });
        }

        private void CmbBranches_SelectedIndexChanged(object sender, EventArgs e) {
            BranchItem selectedBranch = cmbBranches.SelectedItem as BranchItem;
            if (selectedBranch == null) return;

            SetBusy(true);
            SetStatus("\u0417\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0441\u043f\u0438\u0441\u043a\u0443 \u043a\u043e\u043c\u0456\u0442\u0456\u0432 \u0434\u043b\u044f \u0433\u0456\u043b\u043a\u0438 " + selectedBranch.Name + "...", 100);

            ThreadPool.QueueUserWorkItem(_ => {
                List<CommitItem> commits = new List<CommitItem>();
                try {
                    try {
                        EnsureMetaGitUpdated();
                        string logOut = RunGitCommand(metaGitDir, "log \"origin/" + selectedBranch.Name + "\" --date=short --pretty=format:\"%H|%h|%ad|%s\" -n 25");
                        foreach (string line in logOut.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)) {
                            string[] parts = line.Split(new char[] { '|' }, 4);
                            if (parts.Length < 4) continue;
                            commits.Add(new CommitItem {
                                FullSha = parts[0].Trim(),
                                ShortSha = parts[1].Trim(),
                                Date = parts[2].Trim(),
                                Message = parts[3].Trim()
                            });
                        }
                    } catch {
                    }

                    if (commits.Count == 0) {
                        string url = ApiBase + "/commits?sha=" + Uri.EscapeDataString(selectedBranch.Name) + "&per_page=25";
                        string json = HttpGetJson(url);
                        JavaScriptSerializer js = new JavaScriptSerializer();
                        js.MaxJsonLength = int.MaxValue;
                        var rawCommits = js.Deserialize<List<Dictionary<string, object>>>(json);

                        if (rawCommits != null) {
                            foreach (var c in rawCommits) {
                                string sha = c.ContainsKey("sha") ? Convert.ToString(c["sha"]) : "";
                                string dateStr = "";
                                string msg = "";
                                if (c.ContainsKey("commit") && c["commit"] is Dictionary<string, object>) {
                                    var cInner = (Dictionary<string, object>)c["commit"];
                                    if (cInner.ContainsKey("message") && cInner["message"] != null) {
                                        msg = Convert.ToString(cInner["message"]).Split(new char[] { '\r', '\n' })[0];
                                    }
                                    if (cInner.ContainsKey("committer") && cInner["committer"] is Dictionary<string, object>) {
                                        var committer = (Dictionary<string, object>)cInner["committer"];
                                        if (committer.ContainsKey("date") && committer["date"] != null) {
                                            string d = Convert.ToString(committer["date"]);
                                            if (d.Length >= 10) dateStr = d.Substring(0, 10);
                                        }
                                    }
                                }
                                commits.Add(new CommitItem {
                                    FullSha = sha,
                                    ShortSha = sha.Length >= 7 ? sha.Substring(0, 7) : sha,
                                    Date = dateStr,
                                    Message = msg
                                });
                            }
                        }
                    }

                    this.BeginInvoke(new Action(() => {
                        cmbCommits.Items.Clear();
                        foreach (var ci in commits) {
                            cmbCommits.Items.Add(ci);
                        }
                        if (cmbCommits.Items.Count > 0) {
                            cmbCommits.SelectedIndex = 0;
                        }
                        SetBusy(false);
                        SetStatus("\u0413\u043e\u0442\u043e\u0432\u043e \u0434\u043e \u0437\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0430\u0431\u043e \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0437\u0431\u0456\u0440\u043a\u0438.", 0);
                        LogMessage("\u0417\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043e " + commits.Count + " \u043a\u043e\u043c\u0456\u0442\u0456\u0432 \u0456\u0437 \u0433\u0456\u043b\u043a\u0438 '" + selectedBranch.Name + "'.");
                    }));
                } catch (Exception ex) {
                    this.BeginInvoke(new Action(() => {
                        SetBusy(false);
                        SetStatus("\u041f\u043e\u043c\u0438\u043b\u043a\u0430 \u0437\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u043a\u043e\u043c\u0456\u0442\u0456\u0432: " + ex.Message, 0);
                        LogMessage("\u041f\u043e\u043c\u0438\u043b\u043a\u0430: " + ex.Message);
                    }));
                }
            });
        }

        private static string ComputeGitBlobShaFromBytes(byte[] content) {
            byte[] header = Encoding.ASCII.GetBytes("blob " + content.Length + "\0");
            using (SHA1 sha1 = SHA1.Create()) {
                sha1.TransformBlock(header, 0, header.Length, null, 0);
                sha1.TransformFinalBlock(content, 0, content.Length);
                byte[] hash = sha1.Hash;
                StringBuilder sb = new StringBuilder(40);
                for (int i = 0; i < hash.Length; i++) {
                    sb.Append(hash[i].ToString("x2"));
                }
                return sb.ToString();
            }
        }

        private static bool LocalFileMatchesGitSha(string filePath, string expectedSha, long expectedSize, Dictionary<string, string> hashCache) {
            if (!File.Exists(filePath)) return false;
            FileInfo fi = new FileInfo(filePath);
            string cacheKey = filePath.ToLowerInvariant() + "|" + fi.Length + "|" + fi.LastWriteTimeUtc.Ticks;

            string cachedSha;
            if (hashCache.TryGetValue(cacheKey, out cachedSha)) {
                if (string.Equals(cachedSha, expectedSha, StringComparison.OrdinalIgnoreCase)) {
                    return true;
                }
            }

            string ext = fi.Extension.ToLowerInvariant();
            bool isBinary = (ext == ".jar" || ext == ".zip" || ext == ".png" || ext == ".exe" || ext == ".dat");
            if (isBinary && expectedSize >= 0 && fi.Length != expectedSize) {
                return false;
            }

            byte[] rawBytes = File.ReadAllBytes(filePath);
            string actualSha = ComputeGitBlobShaFromBytes(rawBytes);
            if (string.Equals(actualSha, expectedSha, StringComparison.OrdinalIgnoreCase)) {
                hashCache[cacheKey] = expectedSha;
                return true;
            }

            if (!isBinary && rawBytes.Length < 5 * 1024 * 1024) {
                List<byte> lfBytes = new List<byte>(rawBytes.Length);
                for (int i = 0; i < rawBytes.Length; i++) {
                    if (rawBytes[i] == 13 && i + 1 < rawBytes.Length && rawBytes[i + 1] == 10) {
                        continue;
                    }
                    lfBytes.Add(rawBytes[i]);
                }
                string lfSha = ComputeGitBlobShaFromBytes(lfBytes.ToArray());
                if (string.Equals(lfSha, expectedSha, StringComparison.OrdinalIgnoreCase)) {
                    hashCache[cacheKey] = expectedSha;
                    return true;
                }
            }

            return false;
        }

        private static bool ShouldExcludeFromUpload(string relPath) {
            if (string.IsNullOrEmpty(relPath)) return true;
            string norm = relPath.Replace('\\', '/').TrimStart('/');
            if (ExcludedUploadRelPaths.Contains(norm)) {
                return true;
            }
            string[] parts = norm.Split('/');
            if (parts.Length == 0) return true;

            string rootPart = parts[0];
            if (ExcludedUploadRootDirs.Contains(rootPart) ||
                rootPart.StartsWith("XaeroWaypoints", StringComparison.OrdinalIgnoreCase) ||
                (parts.Length > 1 && rootPart.StartsWith(".", StringComparison.OrdinalIgnoreCase))) {
                return true;
            }
            if (parts.Length >= 2 &&
                string.Equals(parts[0], "config", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(parts[1], "xaero", StringComparison.OrdinalIgnoreCase)) {
                return true;
            }
            for (int i = 0; i < parts.Length; i++) {
                if (string.Equals(parts[i], ".git", StringComparison.OrdinalIgnoreCase)) {
                    return true;
                }
            }

            string fileName = parts[parts.Length - 1];
            if (ExcludedUploadFiles.Contains(fileName)) {
                return true;
            }

            string lowerFile = fileName.ToLowerInvariant();
            if (parts.Length == 1) {
                if (lowerFile.EndsWith(".jar") && !string.Equals(fileName, "Test.jar", StringComparison.OrdinalIgnoreCase)) {
                    return true;
                }
                if (lowerFile.EndsWith(".json") &&
                    !string.Equals(fileName, "Test.json", StringComparison.OrdinalIgnoreCase) &&
                    !string.Equals(fileName, "vista_ffmpeg_sources.json", StringComparison.OrdinalIgnoreCase)) {
                    return true;
                }
            }

            if (lowerFile.EndsWith(".downloading") ||
                lowerFile.EndsWith(".deactivation") ||
                lowerFile.EndsWith(".tmp") ||
                lowerFile.EndsWith(".bak") ||
                lowerFile.EndsWith(".log") ||
                lowerFile.EndsWith(".log.gz") ||
                lowerFile.EndsWith(".lock")) {
                return true;
            }

            return false;
        }

        private void StartUploadAsync() {
            if (isBusy) return;

            string targetDir = (cmbFolders.Text ?? "").Trim();
            if (string.IsNullOrEmpty(targetDir)) {
                MessageBox.Show(this, "\u0411\u0443\u0434\u044c \u043b\u0430\u0441\u043a\u0430, \u043e\u0431\u0435\u0440\u0456\u0442\u044c \u043f\u0430\u043f\u043a\u0443 \u0437\u0456 \u0437\u0431\u0456\u0440\u043a\u043e\u044e \u0434\u043b\u044f \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f.", "\u0423\u0432\u0430\u0433\u0430", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            if (!Path.IsPathRooted(targetDir)) {
                targetDir = Path.Combine(versionsRoot, targetDir);
            }
            if (!Directory.Exists(targetDir)) {
                MessageBox.Show(this, "\u041e\u0431\u0440\u0430\u043d\u0430 \u043f\u0430\u043f\u043a\u0430 \u043d\u0435 \u0456\u0441\u043d\u0443\u0454:\n" + targetDir, "\u041f\u043e\u043c\u0438\u043b\u043a\u0430", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            bool isNewBranch = rbUploadNew.Checked;
            string branchName = "";
            if (isNewBranch) {
                branchName = (txtNewBranch.Text ?? "").Trim();
                branchName = Regex.Replace(branchName, @"\s+", "-");
                branchName = Regex.Replace(branchName, @"[\~\^\:\?\*\[\]\\]", "");
                if (string.IsNullOrEmpty(branchName)) {
                    MessageBox.Show(this, "\u0411\u0443\u0434\u044c \u043b\u0430\u0441\u043a\u0430, \u0432\u0432\u0435\u0434\u0456\u0442\u044c \u043d\u0430\u0437\u0432\u0443 \u043d\u043e\u0432\u043e\u0457 \u0433\u0456\u043b\u043a\u0438.", "\u0423\u0432\u0430\u0433\u0430", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    txtNewBranch.Focus();
                    return;
                }
            } else {
                BranchItem selectedBranch = cmbBranches.SelectedItem as BranchItem;
                if (selectedBranch != null) {
                    branchName = selectedBranch.Name;
                }
                if (string.IsNullOrEmpty(branchName)) {
                    MessageBox.Show(this, "\u0411\u0443\u0434\u044c \u043b\u0430\u0441\u043a\u0430, \u043e\u0431\u0435\u0440\u0456\u0442\u044c \u0456\u0441\u043d\u0443\u044e\u0447\u0443 \u0433\u0456\u043b\u043a\u0443 \u0443 \u0441\u043f\u0438\u0441\u043a\u0443 '2. \u0413\u0456\u043b\u043a\u0430 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0456\u044e' \u0430\u0431\u043e \u043e\u0431\u0435\u0440\u0456\u0442\u044c \u0441\u0442\u0432\u043e\u0440\u0435\u043d\u043d\u044f \u043d\u043e\u0432\u043e\u0457 \u0433\u0456\u043b\u043a\u0438.", "\u0423\u0432\u0430\u0433\u0430", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }
            }

            string commitMsg = (txtCommitMsg.Text ?? "").Trim();
            if (string.IsNullOrEmpty(commitMsg)) {
                commitMsg = isNewBranch ? ("\u041f\u043e\u0432\u043d\u0435 \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0437\u0431\u0456\u0440\u043a\u0438 \u0443 \u0433\u0456\u043b\u043a\u0443 " + branchName) : ("\u041e\u043d\u043e\u0432\u043b\u0435\u043d\u043d\u044f \u0437\u0431\u0456\u0440\u043a\u0438 (" + DateTime.Now.ToString("yyyy-MM-dd HH:mm") + ")");
            }

            SetBusy(true);
            txtLog.Clear();
            LogMessage("\u041f\u043e\u0447\u0430\u0442\u043e\u043a \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0437\u0431\u0456\u0440\u043a\u0438 \u0432 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0456\u0439 GitHub...");
            LogMessage("\u041f\u0430\u043f\u043a\u0430 \u0437\u0431\u0456\u0440\u043a\u0438: " + targetDir);
            LogMessage("\u0420\u0435\u0436\u0438\u043c: " + (isNewBranch ? ("\u041d\u043e\u0432\u0430 \u0433\u0456\u043b\u043a\u0430 '" + branchName + "' (\u0443\u0441\u0456 \u0444\u0430\u0439\u043b\u0438 \u0437\u0431\u0456\u0440\u043a\u0438, \u043a\u0440\u0456\u043c saves/)") : ("\u0406\u0441\u043d\u0443\u044e\u0447\u0430 \u0433\u0456\u043b\u043a\u0430 '" + branchName + "' (\u0442\u0456\u043b\u044c\u043a\u0438 \u043d\u043e\u0432\u0456 \u0442\u0430 \u0437\u043c\u0456\u043d\u0435\u043d\u0456 \u0444\u0430\u0439\u043b\u0438)")));
            LogMessage("\u041e\u043f\u0438\u0441 \u043a\u043e\u043c\u0456\u0442\u0443: " + commitMsg);

            ThreadPool.QueueUserWorkItem(_ => {
                try {
                    RunUploadSync(targetDir, isNewBranch, branchName, commitMsg);
                } catch (Exception ex) {
                    this.BeginInvoke(new Action(() => {
                        SetBusy(false);
                        SetStatus("\u041f\u043e\u043c\u0438\u043b\u043a\u0430 \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f: " + ex.Message, 0);
                        LogMessage("\u041a\u0420\u0418\u0422\u0418\u0427\u041d\u0410 \u041f\u041e\u041c\u0418\u041b\u041a\u0410 \u0412\u0418\u0412\u0410\u041d\u0422\u0410\u0416\u0415\u041d\u041d\u042f: " + ex.ToString());
                        MessageBox.Show(this, "\u0412\u0438\u043d\u0438\u043a\u043b\u0430 \u043f\u043e\u043c\u0438\u043b\u043a\u0430 \u043f\u0456\u0434 \u0447\u0430\u0441 \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0437\u0431\u0456\u0440\u043a\u0438:\n" + ex.Message, "\u041f\u043e\u043c\u0438\u043b\u043a\u0430 \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }));
                }
            });
        }

        private void EnsureLocalGitRepoForUpload(string targetDir) {
            string gitDir = Path.Combine(targetDir, ".git");
            string indexLock = Path.Combine(gitDir, "index.lock");
            if (File.Exists(indexLock)) {
                try { File.Delete(indexLock); } catch { }
            }

            if (!Directory.Exists(gitDir)) {
                LogMessage("\u0406\u043d\u0456\u0446\u0456\u0430\u043b\u0456\u0437\u0430\u0446\u0456\u044f \u043b\u043e\u043a\u0430\u043b\u044c\u043d\u043e\u0433\u043e \u0441\u0445\u043e\u0432\u0438\u0449\u0430 Git \u0443 \u043f\u0430\u043f\u0446\u0456 \u0437\u0431\u0456\u0440\u043a\u0438...");
                RunGitCommand(targetDir, "init");
                RunGitCommand(targetDir, "remote add origin " + RepoUrl);
            } else {
                string remotes = RunGitCommand(targetDir, "remote");
                if (!Regex.IsMatch(remotes ?? "", @"(?m)^origin$")) {
                    RunGitCommand(targetDir, "remote add origin " + RepoUrl);
                } else {
                    RunGitCommand(targetDir, "remote set-url origin " + RepoUrl);
                }
            }

            RunGitCommand(targetDir, "config core.repositoryformatversion 1");
            RunGitCommand(targetDir, "config extensions.partialclone origin");
            RunGitCommand(targetDir, "config remote.origin.promisor true");
            RunGitCommand(targetDir, "config remote.origin.partialclonefilter blob:none");
            RunGitCommand(targetDir, "config core.autocrlf false");
            RunGitCommand(targetDir, "config core.quotepath false");

            string userName = RunGitCommand(targetDir, "config user.name").Trim();
            if (string.IsNullOrEmpty(userName)) {
                RunGitCommand(targetDir, "config user.name \"ModpackPlayer\"");
            }
            string userEmail = RunGitCommand(targetDir, "config user.email").Trim();
            if (string.IsNullOrEmpty(userEmail)) {
                RunGitCommand(targetDir, "config user.email \"player@modpack.local\"");
            }

            string testObjectsDir = Path.Combine(versionsRoot, "Test", ".git", "objects");
            string currentObjectsDir = Path.Combine(targetDir, ".git", "objects");
            if (Directory.Exists(testObjectsDir) && !string.Equals(testObjectsDir, currentObjectsDir, StringComparison.OrdinalIgnoreCase)) {
                try {
                    string infoDir = Path.Combine(currentObjectsDir, "info");
                    if (!Directory.Exists(infoDir)) Directory.CreateDirectory(infoDir);
                    string altFile = Path.Combine(infoDir, "alternates");
                    string normTestObj = testObjectsDir.Replace('\\', '/');
                    if (!File.Exists(altFile) || !File.ReadAllText(altFile, Encoding.UTF8).Contains(normTestObj)) {
                        File.WriteAllText(altFile, normTestObj + Environment.NewLine, new UTF8Encoding(false));
                    }
                } catch { }
            }
        }

        private bool RunGitPushWithProgress(string workingDir, string arguments, int startProgress, int endProgress, out string errorOutput) {
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = FindGitExe();
            psi.Arguments = arguments;
            psi.WorkingDirectory = workingDir;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.StandardOutputEncoding = Encoding.UTF8;
            psi.StandardErrorEncoding = Encoding.UTF8;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;

            StringBuilder errSb = new StringBuilder();
            using (Process p = Process.Start(psi)) {
                p.OutputDataReceived += (s, e) => {
                    if (!string.IsNullOrEmpty(e.Data)) {
                        LogMessage("  [git] " + e.Data);
                    }
                };
                p.BeginOutputReadLine();

                StreamReader sr = p.StandardError;
                StringBuilder lineBuf = new StringBuilder();
                int ch;
                int lastUiUpdate = 0;
                while ((ch = sr.Read()) != -1) {
                    if (ch == '\r' || ch == '\n') {
                        string line = lineBuf.ToString().Trim();
                        lineBuf.Length = 0;
                        if (string.IsNullOrEmpty(line)) continue;

                        if (ch == '\n') {
                            errSb.AppendLine(line);
                            if (!line.StartsWith("Counting objects:") &&
                                !line.StartsWith("Compressing objects:") &&
                                !line.StartsWith("Writing objects:") &&
                                !line.StartsWith("Enumerating objects:")) {
                                LogMessage("  [GitHub] " + line);
                            }
                        }

                        int now = Environment.TickCount;
                        if (now - lastUiUpdate > 50 || line.Contains("100%")) {
                            lastUiUpdate = now;
                            Match mWrite = Regex.Match(line, @"Writing objects:\s*(\d+)%\s*\((\d+)/(\d+)\)(.*)");
                            Match mComp = Regex.Match(line, @"Compressing objects:\s*(\d+)%\s*\((\d+)/(\d+)\)");
                            Match mCount = Regex.Match(line, @"(?:Counting|Enumerating) objects:\s*(\d+)%");
                            if (mWrite.Success) {
                                int pctVal = int.Parse(mWrite.Groups[1].Value);
                                string speedInfo = mWrite.Groups[4].Value.Trim().TrimStart(',').Trim();
                                int barVal = startProgress + (int)((endProgress - startProgress) * (0.20 + 0.80 * (pctVal / 100.0)));
                                string msg = string.Format("\u0412\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u043d\u0430 GitHub: {0}% ({1}/{2}){3}",
                                    pctVal, mWrite.Groups[2].Value, mWrite.Groups[3].Value,
                                    string.IsNullOrEmpty(speedInfo) ? "" : " \u2014 " + speedInfo);
                                SetStatus(msg, barVal);
                            } else if (mComp.Success) {
                                int pctVal = int.Parse(mComp.Groups[1].Value);
                                int barVal = startProgress + (int)((endProgress - startProgress) * (0.05 + 0.15 * (pctVal / 100.0)));
                                SetStatus(string.Format("\u0421\u0442\u0438\u0441\u043d\u0435\u043d\u043d\u044f \u0444\u0430\u0439\u043b\u0456\u0432 \u043f\u0435\u0440\u0435\u0434 \u0432\u0456\u0434\u043f\u0440\u0430\u0432\u043a\u043e\u044e: {0}% ({1}/{2})...", pctVal, mComp.Groups[2].Value, mComp.Groups[3].Value), barVal);
                            } else if (mCount.Success) {
                                int pctVal = int.Parse(mCount.Groups[1].Value);
                                int barVal = startProgress + (int)((endProgress - startProgress) * (0.05 * (pctVal / 100.0)));
                                SetStatus(string.Format("\u041f\u0456\u0434\u0433\u043e\u0442\u043e\u0432\u043a\u0430 \u043f\u0430\u043a\u0435\u0442\u0443 Git: {0}%...", pctVal), barVal);
                            }
                        }
                    } else {
                        lineBuf.Append((char)ch);
                    }
                }
                p.WaitForExit();
                errorOutput = errSb.ToString();
                return p.ExitCode == 0;
            }
        }

        private void RunUploadSync(string targetDir, bool isNewBranch, string branchName, string commitMsg) {
            SetStatus("\u041f\u0456\u0434\u0433\u043e\u0442\u043e\u0432\u043a\u0430 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0456\u044e \u0442\u0430 \u0456\u043d\u0434\u0435\u043a\u0441\u0456\u0432...", 20);
            EnsureLocalGitRepoForUpload(targetDir);

            string packwizExe = Path.Combine(targetDir, "packwiz.exe");
            string packToml = Path.Combine(targetDir, "pack.toml");
            if (File.Exists(packwizExe) && File.Exists(packToml)) {
                try {
                    SetStatus("\u041e\u043d\u043e\u0432\u043b\u0435\u043d\u043d\u044f \u0456\u043d\u0434\u0435\u043a\u0441\u0456\u0432 Packwiz (packwiz refresh)...", 35);
                    LogMessage("\u041e\u043d\u043e\u0432\u043b\u0435\u043d\u043d\u044f \u0445\u0435\u0448\u0456\u0432 \u043c\u043e\u0434\u0456\u0432 \u0447\u0435\u0440\u0435\u0437 packwiz.exe refresh...");
                    ProcessStartInfo pwPsi = new ProcessStartInfo(packwizExe, "refresh");
                    pwPsi.WorkingDirectory = targetDir;
                    pwPsi.UseShellExecute = false;
                    pwPsi.CreateNoWindow = true;
                    using (Process pw = Process.Start(pwPsi)) {
                        pw.WaitForExit(15000);
                    }
                } catch { }
            }

            JavaScriptSerializer js = new JavaScriptSerializer();
            js.MaxJsonLength = int.MaxValue;
            string cacheFile = Path.Combine(targetDir, ".modpack_hash_cache.json");
            Dictionary<string, string> hashCache = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (File.Exists(cacheFile)) {
                try {
                    var loaded = js.Deserialize<Dictionary<string, string>>(File.ReadAllText(cacheFile, Encoding.UTF8));
                    if (loaded != null) {
                        foreach (var kv in loaded) hashCache[kv.Key] = kv.Value;
                    }
                } catch { }
            }

            SetStatus("\u0421\u043a\u0430\u043d\u0443\u0432\u0430\u043d\u043d\u044f \u043b\u043e\u043a\u0430\u043b\u044c\u043d\u0438\u0445 \u0444\u0430\u0439\u043b\u0456\u0432 \u0437\u0431\u0456\u0440\u043a\u0438 (\u0431\u0435\u0437 \u043f\u0430\u043f\u043a\u0438 saves/)...", 50);
            string[] allFullFiles = Directory.GetFiles(targetDir, "*", SearchOption.AllDirectories);
            List<string> eligibleRelFiles = new List<string>();
            HashSet<string> localRelSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            int rootLen = targetDir.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar).Length + 1;
            foreach (string fullPath in allFullFiles) {
                if (fullPath.Length <= rootLen) continue;
                string rel = fullPath.Substring(rootLen).Replace('\\', '/');
                if (ShouldExcludeFromUpload(rel)) continue;
                eligibleRelFiles.Add(rel);
                localRelSet.Add(rel);
            }

            string newCommitSha = "";

            if (!isNewBranch) {
                SetStatus("\u041e\u0442\u0440\u0438\u043c\u0430\u043d\u043d\u044f \u0441\u0442\u0430\u043d\u0443 \u0433\u0456\u043b\u043a\u0438 '" + branchName + "' \u0456\u0437 GitHub...", 80);
                LogMessage("\u0417\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u043c\u0435\u0442\u0430\u0434\u0430\u043d\u0438\u0445 \u0433\u0456\u043b\u043a\u0438 '" + branchName + "' \u0434\u043b\u044f \u043f\u043e\u0440\u0456\u0432\u043d\u044f\u043d\u043d\u044f \u0444\u0430\u0439\u043b\u0456\u0432...");

                int fetchExit;
                string fetchErr;
                RunGitCommandEx(targetDir, "fetch --filter=blob:none --no-tags origin \"+refs/heads/" + branchName + ":refs/remotes/origin/" + branchName + "\"", out fetchExit, out fetchErr);
                string parentSha = RunGitCommand(targetDir, "rev-parse \"refs/remotes/origin/" + branchName + "\"").Trim();
                if (fetchExit != 0 || parentSha.Length != 40) {
                    throw new Exception("\u041d\u0435 \u0432\u0434\u0430\u043b\u043e\u0441\u044f \u043e\u0442\u0440\u0438\u043c\u0430\u0442\u0438 \u0433\u0456\u043b\u043a\u0443 '" + branchName + "' \u0456\u0437 GitHub: " + fetchErr);
                }

                Dictionary<string, string> remoteTree = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                string lsTreeOut = RunGitCommand(targetDir, "-c core.quotePath=false ls-tree -r \"" + parentSha + "\"");
                foreach (string line in lsTreeOut.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)) {
                    int tabIdx = line.IndexOf('\t');
                    if (tabIdx <= 0) continue;
                    string metaPart = line.Substring(0, tabIdx).Trim();
                    string rPath = line.Substring(tabIdx + 1).Trim();
                    string[] mParts = metaPart.Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    if (mParts.Length < 3 || mParts[1] != "blob") continue;
                    remoteTree[rPath] = mParts[2];
                }

                List<string> changedOrAdded = new List<string>();
                int unchangedCount = 0;
                int addedCount = 0;
                int modifiedCount = 0;

                for (int i = 0; i < eligibleRelFiles.Count; i++) {
                    string rel = eligibleRelFiles[i];
                    string fullPath = Path.Combine(targetDir, rel.Replace('/', Path.DirectorySeparatorChar));

                    if (i % 20 == 0 || i == eligibleRelFiles.Count - 1) {
                        int pct = 100 + (int)((i + 1) * 280.0 / Math.Max(1, eligibleRelFiles.Count));
                        SetStatus(string.Format("\u041f\u0435\u0440\u0435\u0432\u0456\u0440\u043a\u0430 \u0437\u043c\u0456\u043d \u0443 \u0444\u0430\u0439\u043b\u0430\u0445 [{0}/{1}]...", i + 1, eligibleRelFiles.Count), pct);
                    }

                    string remoteSha;
                    if (remoteTree.TryGetValue(rel, out remoteSha)) {
                        if (LocalFileMatchesGitSha(fullPath, remoteSha, -1, hashCache)) {
                            unchangedCount++;
                        } else {
                            changedOrAdded.Add(rel);
                            modifiedCount++;
                            LogMessage("  [\u0417\u043c\u0456\u043d\u0435\u043d\u043e] " + rel);
                        }
                    } else {
                        changedOrAdded.Add(rel);
                        addedCount++;
                        LogMessage("  [\u041d\u043e\u0432\u0438\u0439 \u0444\u0430\u0439\u043b] " + rel);
                    }
                }

                List<string> deletedFiles = new List<string>();
                List<string> stalePersonalFilesInRemote = new List<string>();
                foreach (var kv in remoteTree) {
                    string rPath = kv.Key;
                    if (string.Equals(rPath, "sync.ps1", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(rPath, "sync.bat", StringComparison.OrdinalIgnoreCase)) {
                        continue;
                    }
                    if (ShouldExcludeFromUpload(rPath)) {
                        stalePersonalFilesInRemote.Add(rPath);
                        continue;
                    }
                    if (!localRelSet.Contains(rPath)) {
                        deletedFiles.Add(rPath);
                        LogMessage("  [\u0412\u0438\u0434\u0430\u043b\u0435\u043d\u043e] " + rPath);
                    }
                }

                LogMessage(string.Format("\u0417\u0432\u0456\u0440\u043a\u0430 \u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043d\u0430: \u0431\u0435\u0437 \u0437\u043c\u0456\u043d (\u043f\u0440\u043e\u043f\u0443\u0449\u0435\u043d\u043e): {0}, \u043d\u043e\u0432\u0438\u0445: {1}, \u0437\u043c\u0456\u043d\u0435\u043d\u0438\u0445: {2}, \u0432\u0438\u0434\u0430\u043b\u0435\u043d\u0438\u0445: {3}.",
                    unchangedCount, addedCount, modifiedCount, deletedFiles.Count));

                if (changedOrAdded.Count == 0 && deletedFiles.Count == 0) {
                    SetStatus("\u0423\u0441\u0456 \u0444\u0430\u0439\u043b\u0438 \u0432\u0436\u0435 \u0430\u043a\u0442\u0443\u0430\u043b\u044c\u043d\u0456 \u0432 \u0433\u0456\u043b\u0446\u0456 '" + branchName + "'. \u0417\u043c\u0456\u043d \u0434\u043b\u044f \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u043d\u0435\u043c\u0430\u0454.", 1000);
                    this.BeginInvoke(new Action(() => {
                        SetBusy(false);
                        MessageBox.Show(this, "\u0423 \u0432\u0430\u0448\u0456\u0439 \u043f\u0430\u043f\u0446\u0456 \u043d\u0435\u043c\u0430\u0454 \u043d\u043e\u0432\u0438\u0445 \u0430\u0431\u043e \u0437\u043c\u0456\u043d\u0435\u043d\u0438\u0445 \u0444\u0430\u0439\u043b\u0456\u0432 \u043f\u043e\u0440\u0456\u0432\u043d\u044f\u043d\u043e \u0437 \u0433\u0456\u043b\u043a\u043e\u044e '" + branchName + "'.\n\u0412\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u043d\u0435 \u043f\u043e\u0442\u0440\u0456\u0431\u043d\u0435!", "\u0417\u043c\u0456\u043d \u043d\u0435 \u0437\u043d\u0430\u0439\u0434\u0435\u043d\u043e", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    }));
                    return;
                }

                SetStatus("\u041f\u0456\u0434\u0433\u043e\u0442\u043e\u0432\u043a\u0430 \u0456\u043d\u0434\u0435\u043a\u0441\u0443 \u0433\u0456\u043b\u043a\u0438 '" + branchName + "'...", 390);
                RunGitCommand(targetDir, "read-tree \"" + parentSha + "\"");

                for (int i = 0; i < changedOrAdded.Count; i++) {
                    string rel = changedOrAdded[i];
                    int pct = 400 + (int)((i + 1) * 220.0 / Math.Max(1, changedOrAdded.Count));
                    SetStatus(string.Format("\u0406\u043d\u0434\u0435\u043a\u0441\u0430\u0446\u0456\u044f \u043d\u043e\u0432\u0438\u0445/\u0437\u043c\u0456\u043d\u0435\u043d\u0438\u0445 \u0444\u0430\u0439\u043b\u0456\u0432 [{0}/{1}]: {2}", i + 1, changedOrAdded.Count, Path.GetFileName(rel)), pct);
                    RunGitCommand(targetDir, "add -f -- \"" + rel + "\"");
                }

                List<string> allToRemoveFromIndex = new List<string>(deletedFiles);
                allToRemoveFromIndex.AddRange(stalePersonalFilesInRemote);
                if (allToRemoveFromIndex.Count > 0) {
                    SetStatus("\u0412\u0438\u043b\u0443\u0447\u0435\u043d\u043d\u044f \u0432\u0438\u0434\u0430\u043b\u0435\u043d\u0438\u0445 \u0444\u0430\u0439\u043b\u0456\u0432 \u0437 \u0456\u043d\u0434\u0435\u043a\u0441\u0443...", 630);
                    for (int i = 0; i < allToRemoveFromIndex.Count; i += 10) {
                        List<string> batch = new List<string>();
                        for (int j = i; j < Math.Min(allToRemoveFromIndex.Count, i + 10); j++) {
                            batch.Add("\"" + allToRemoveFromIndex[j] + "\"");
                        }
                        RunGitCommand(targetDir, "rm --cached -r --ignore-unmatch -- " + string.Join(" ", batch.ToArray()));
                    }
                }

                SetStatus("\u0421\u0442\u0432\u043e\u0440\u0435\u043d\u043d\u044f \u043a\u043e\u043c\u0456\u0442\u0443...", 650);
                string treeSha = RunGitCommand(targetDir, "write-tree").Trim();
                string msgFile = Path.Combine(targetDir, ".git", "COMMIT_MSG_TMP");
                File.WriteAllText(msgFile, commitMsg, new UTF8Encoding(false));
                newCommitSha = RunGitCommand(targetDir, "commit-tree " + treeSha + " -p " + parentSha + " -F \".git/COMMIT_MSG_TMP\"").Trim();
                try { File.Delete(msgFile); } catch { }

                if (newCommitSha.Length != 40) {
                    throw new Exception("\u041d\u0435 \u0432\u0434\u0430\u043b\u043e\u0441\u044f \u0441\u0442\u0432\u043e\u0440\u0438\u0442\u0438 \u043a\u043e\u043c\u0456\u0442: " + newCommitSha);
                }

                RunGitCommand(targetDir, "update-ref \"refs/heads/" + branchName + "\" " + newCommitSha);
                RunGitCommand(targetDir, "symbolic-ref HEAD \"refs/heads/" + branchName + "\"");

                SetStatus("\u0412\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u043d\u043e\u0432\u0438\u0445 \u0442\u0430 \u0437\u043c\u0456\u043d\u0435\u043d\u0438\u0445 \u0444\u0430\u0439\u043b\u0456\u0432 \u0443 \u0433\u0456\u043b\u043a\u0443 '" + branchName + "'...", 670);
                LogMessage("\u0412\u0456\u0434\u043f\u0440\u0430\u0432\u043a\u0430 \u043a\u043e\u043c\u0456\u0442\u0443 " + newCommitSha.Substring(0, 7) + " \u0443 \u0433\u0456\u043b\u043a\u0443 '" + branchName + "'...");

                string pushErr;
                bool pushOk = RunGitPushWithProgress(targetDir, "push --progress origin " + newCommitSha + ":refs/heads/" + branchName, 670, 990, out pushErr);
                if (!pushOk) {
                    throw new Exception("\u041f\u043e\u043c\u0438\u043b\u043a\u0430 git push \u0443 \u0433\u0456\u043b\u043a\u0443 '" + branchName + "':\n" + pushErr);
                }
            } else {
                SetStatus("\u041f\u0456\u0434\u0433\u043e\u0442\u043e\u0432\u043a\u0430 \u0447\u0438c\u0442\u043e\u0433\u043e \u0456\u043d\u0434\u0435\u043a\u0441\u0443 \u0434\u043b\u044f \u043d\u043e\u0432\u043e\u0457 \u0433\u0456\u043b\u043a\u0438 '" + branchName + "'...", 70);
                LogMessage(string.Format("\u0417\u043d\u0430\u0439\u0434\u0435\u043d\u043e \u0444\u0430\u0439\u043b\u0456\u0432 \u0437\u0431\u0456\u0440\u043a\u0438 \u0434\u043b\u044f \u043f\u043e\u0432\u043d\u043e\u0433\u043e \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f (\u0431\u0435\u0437 saves/): {0}.", eligibleRelFiles.Count));

                RunGitCommand(targetDir, "read-tree --empty");

                int batchSize = 15;
                int total = eligibleRelFiles.Count;
                for (int i = 0; i < total; i += batchSize) {
                    int end = Math.Min(total, i + batchSize);
                    List<string> quotedBatch = new List<string>( end - i );
                    for (int j = i; j < end; j++) {
                        quotedBatch.Add("\"" + eligibleRelFiles[j] + "\"");
                    }
                    string lastFileName = Path.GetFileName(eligibleRelFiles[end - 1]);
                    int pct = 80 + (int)(end * 500.0 / Math.Max(1, total));
                    SetStatus(string.Format("\u041f\u0456\u0434\u0433\u043e\u0442\u043e\u0432\u043a\u0430 \u0432\u0441\u0456\u0445 \u0444\u0430\u0439\u043b\u0456\u0432 \u0437\u0431\u0456\u0440\u043a\u0438 [{0}/{1}]: {2}", end, total, lastFileName), pct);

                    RunGitCommand(targetDir, "add -f -- " + string.Join(" ", quotedBatch.ToArray()));

                    if (end % 150 == 0 || end == total) {
                        LogMessage(string.Format("  \u041f\u0440\u043e\u0456\u043d\u0434\u0435\u043a\u0441\u043e\u0432\u0430\u043d\u043e \u0444\u0430\u0439\u043b\u0456\u0432 \u0437\u0431\u0456\u0440\u043a\u0438: {0} / {1}", end, total));
                    }
                }

                SetStatus("\u0424\u043e\u0440\u043c\u0443\u0432\u0430\u043d\u043d\u044f \u043f\u043e\u0432\u043d\u043e\u0433\u043e \u043a\u043e\u043c\u0456\u0442\u0443 \u0434\u043b\u044f \u043d\u043e\u0432\u043e\u0457 \u0433\u0456\u043b\u043a\u0438 '" + branchName + "'...", 600);
                string treeSha = RunGitCommand(targetDir, "write-tree").Trim();
                string msgFile = Path.Combine(targetDir, ".git", "COMMIT_MSG_TMP");
                File.WriteAllText(msgFile, commitMsg, new UTF8Encoding(false));
                newCommitSha = RunGitCommand(targetDir, "commit-tree " + treeSha + " -F \".git/COMMIT_MSG_TMP\"").Trim();
                try { File.Delete(msgFile); } catch { }

                if (newCommitSha.Length != 40) {
                    throw new Exception("\u041d\u0435 \u0432\u0434\u0430\u043b\u043e\u0441\u044f \u0441\u0442\u0432\u043e\u0440\u0438\u0442\u0438 \u043a\u043e\u043c\u0456\u0442 \u0434\u043b\u044f \u043d\u043e\u0432\u043e\u0457 \u0433\u0456\u043b\u043a\u0438: " + newCommitSha);
                }

                RunGitCommand(targetDir, "update-ref \"refs/heads/" + branchName + "\" " + newCommitSha);
                RunGitCommand(targetDir, "symbolic-ref HEAD \"refs/heads/" + branchName + "\"");

                SetStatus("\u0412\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0432\u0441\u0456\u0454\u0457 \u0437\u0431\u0456\u0440\u043a\u0438 \u0443 \u043d\u043e\u0432\u0443 \u0433\u0456\u043b\u043a\u0443 '" + branchName + "'...", 630);
                LogMessage("\u0412\u0456\u0434\u043f\u0440\u0430\u0432\u043a\u0430 \u043f\u043e\u0432\u043d\u043e\u0433\u043e \u043a\u043e\u043c\u0456\u0442\u0443 " + newCommitSha.Substring(0, 7) + " \u0443 \u043d\u043e\u0432\u0443 \u0433\u0456\u043b\u043a\u0443 '" + branchName + "'...");

                string pushErr;
                bool pushOk = RunGitPushWithProgress(targetDir, "push --progress -f -u origin " + newCommitSha + ":refs/heads/" + branchName, 630, 990, out pushErr);
                if (!pushOk) {
                    throw new Exception("\u041f\u043e\u043c\u0438\u043b\u043a\u0430 git push \u0443 \u043d\u043e\u0432\u0443 \u0433\u0456\u043b\u043a\u0443 '" + branchName + "':\n" + pushErr);
                }
            }

            try {
                File.WriteAllText(cacheFile, js.Serialize(hashCache), Encoding.UTF8);
                File.WriteAllText(Path.Combine(targetDir, ".synced_commit.txt"), newCommitSha, Encoding.UTF8);
            } catch { }

            string shortNewSha = newCommitSha.Length >= 7 ? newCommitSha.Substring(0, 7) : newCommitSha;
            string doneMsg = string.Format("\u0412\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0443\u0441\u043f\u0456\u0448\u043d\u043e \u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043d\u043e! \u0413\u0456\u043b\u043a\u0430: '{0}', \u043a\u043e\u043c\u0456\u0442: {1}", branchName, shortNewSha);
            SetStatus(doneMsg, 1000);
            LogMessage(doneMsg);

            this.BeginInvoke(new Action(() => {
                UpdateCurrentFolderInfo();
                SetBusy(false);
                FetchBranchesAsync(branchName);
                MessageBox.Show(this,
                    "\u0417\u0431\u0456\u0440\u043a\u0443 \u0443\u0441\u043f\u0456\u0448\u043d\u043e \u0432\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043e \u0432 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0456\u0439 GitHub!\n\n" +
                    "\u0413\u0456\u043b\u043a\u0430: " + branchName + "\n" +
                    "\u041a\u043e\u043c\u0456\u0442: " + shortNewSha + " (" + commitMsg + ")",
                    "\u0412\u0438\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043d\u043e",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }));
        }

        private void StartSyncAsync(bool launchAfterSync) {
            if (isBusy) return;

            string targetDir = (cmbFolders.Text ?? "").Trim();
            if (string.IsNullOrEmpty(targetDir)) {
                MessageBox.Show(this, "\u0411\u0443\u0434\u044c \u043b\u0430\u0441\u043a\u0430, \u043e\u0431\u0435\u0440\u0456\u0442\u044c \u0430\u0431\u043e \u0432\u0432\u0435\u0434\u0456\u0442\u044c \u043f\u0430\u043f\u043a\u0443 \u0434\u043b\u044f \u0437\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f \u0437\u0431\u0456\u0440\u043a\u0438.", "\u0423\u0432\u0430\u0433\u0430", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            if (!Path.IsPathRooted(targetDir)) {
                targetDir = Path.Combine(versionsRoot, targetDir);
            }

            string targetCommitSha = "";
            CommitItem selectedCommitItem = cmbCommits.SelectedItem as CommitItem;
            if (selectedCommitItem != null) {
                targetCommitSha = selectedCommitItem.FullSha;
            } else {
                string rawCommitText = (cmbCommits.Text ?? "").Trim();
                Match m = Regex.Match(rawCommitText, @"^\[([0-9a-fA-F]{7,40})\]");
                if (m.Success) {
                    targetCommitSha = m.Groups[1].Value;
                } else {
                    targetCommitSha = rawCommitText;
                }
            }

            if (string.IsNullOrEmpty(targetCommitSha)) {
                MessageBox.Show(this, "\u0411\u0443\u0434\u044c \u043b\u0430\u0441\u043a\u0430, \u043e\u0431\u0435\u0440\u0456\u0442\u044c \u043a\u043e\u043c\u0456\u0442 \u0437\u0456 \u0441\u043f\u0438\u0441\u043a\u0443 \u0430\u0431\u043e \u0432\u0432\u0435\u0434\u0456\u0442\u044c \u0445\u0435\u0448 \u043a\u043e\u043c\u0456\u0442\u0443.", "\u0423\u0432\u0430\u0433\u0430", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            SetBusy(true);
            txtLog.Clear();
            LogMessage("\u041f\u043e\u0447\u0430\u0442\u043e\u043a \u0440\u043e\u0437\u0443\u043c\u043d\u043e\u0457 \u0441\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u0457 (Delta Sync)...");
            LogMessage("\u0426\u0456\u043b\u044c\u043e\u0432\u0430 \u043f\u0430\u043f\u043a\u0430: " + targetDir);
            BranchItem curBranch = cmbBranches.SelectedItem as BranchItem;
            string selectedBranchName = curBranch != null ? curBranch.Name : "";
            LogMessage("\u0413\u0456\u043b\u043a\u0430: " + selectedBranchName);
            LogMessage("\u041e\u0431\u0440\u0430\u043d\u0438\u0439 \u043a\u043e\u043c\u0456\u0442: " + targetCommitSha);

            ThreadPool.QueueUserWorkItem(_ => {
                try {
                    RunDeltaSync(targetDir, selectedBranchName, targetCommitSha, launchAfterSync);
                } catch (Exception ex) {
                    this.BeginInvoke(new Action(() => {
                        SetBusy(false);
                        SetStatus("\u041f\u043e\u043c\u0438\u043b\u043a\u0430 \u0441\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u0457: " + ex.Message, 0);
                        LogMessage("\u041a\u0420\u0418\u0422\u0418\u0427\u041d\u0410 \u041f\u041e\u041c\u0418\u041b\u041a\u0410: " + ex.ToString());
                        MessageBox.Show(this, "\u0412\u0438\u043d\u0438\u043a\u043b\u0430 \u043f\u043e\u043c\u0438\u043b\u043a\u0430 \u043f\u0456\u0434 \u0447\u0430\u0441 \u0441\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u0457:\n" + ex.Message, "\u041f\u043e\u043c\u0438\u043b\u043a\u0430", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }));
                }
            });
        }

        private void RunDeltaSync(string targetDir, string branchName, string commitShaOrRef, bool launchAfterSync) {
            if (!Directory.Exists(targetDir)) {
                Directory.CreateDirectory(targetDir);
            }

            JavaScriptSerializer js = new JavaScriptSerializer();
            js.MaxJsonLength = int.MaxValue;

            string fullCommitSha = commitShaOrRef;
            List<RemoteTreeEntry> remoteFiles = new List<RemoteTreeEntry>();
            HashSet<string> remoteModsLower = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            SetStatus("\u041e\u0442\u0440\u0438\u043c\u0430\u043d\u043d\u044f \u0441\u043f\u0438\u0441\u043a\u0443 \u0444\u0430\u0439\u043b\u0456\u0432 \u043a\u043e\u043c\u0456\u0442\u0443...", 50);
            try {
                EnsureMetaGitUpdated();
                if (fullCommitSha.Length < 40) {
                    string resolved = RunGitCommand(metaGitDir, "rev-parse \"" + commitShaOrRef + "\"").Trim();
                    if (resolved.Length == 40) fullCommitSha = resolved;
                }
                string lsTreeOut = RunGitCommand(metaGitDir, "-c core.quotePath=false ls-tree -r -l \"" + fullCommitSha + "\"");
                foreach (string line in lsTreeOut.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)) {
                    int tabIdx = line.IndexOf('\t');
                    if (tabIdx <= 0) continue;
                    string metaPart = line.Substring(0, tabIdx).Trim();
                    string path = line.Substring(tabIdx + 1).Trim();
                    string[] mParts = metaPart.Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    if (mParts.Length < 3 || mParts[1] != "blob") continue;
                    string sha = mParts[2];
                    long sz = -1;
                    if (mParts.Length >= 4) {
                        long.TryParse(mParts[3], out sz);
                    }

                    if (ShouldExcludeFromUpload(path)) {
                        continue;
                    }

                    remoteFiles.Add(new RemoteTreeEntry { Path = path, Sha = sha, Size = sz });
                    if (path.StartsWith("mods/", StringComparison.OrdinalIgnoreCase) && path.EndsWith(".jar", StringComparison.OrdinalIgnoreCase)) {
                        remoteModsLower.Add(Path.GetFileName(path));
                    }
                }
            } catch {
            }

            if (remoteFiles.Count == 0) {
                if (fullCommitSha.Length < 40) {
                    string commitJson = HttpGetJson(ApiBase + "/commits/" + Uri.EscapeDataString(commitShaOrRef));
                    var commitObj = js.Deserialize<Dictionary<string, object>>(commitJson);
                    if (commitObj != null && commitObj.ContainsKey("sha")) {
                        fullCommitSha = Convert.ToString(commitObj["sha"]);
                    }
                }
                string treeJson = HttpGetJson(ApiBase + "/git/trees/" + fullCommitSha + "?recursive=1");
                var treeRoot = js.Deserialize<Dictionary<string, object>>(treeJson);
                if (treeRoot != null && treeRoot.ContainsKey("tree")) {
                    var rawTree = treeRoot["tree"] as System.Collections.ArrayList;
                    foreach (object itemObj in rawTree) {
                        var item = itemObj as Dictionary<string, object>;
                        if (item == null) continue;
                        string type = item.ContainsKey("type") ? Convert.ToString(item["type"]) : "";
                        if (type != "blob") continue;

                        string path = item.ContainsKey("path") ? Convert.ToString(item["path"]) : "";
                        string sha = item.ContainsKey("sha") ? Convert.ToString(item["sha"]) : "";
                        long size = item.ContainsKey("size") && item["size"] != null ? Convert.ToInt64(item["size"]) : -1;

                        if (ShouldExcludeFromUpload(path)) {
                            continue;
                        }

                        remoteFiles.Add(new RemoteTreeEntry { Path = path, Sha = sha, Size = size });
                        if (path.StartsWith("mods/", StringComparison.OrdinalIgnoreCase) && path.EndsWith(".jar", StringComparison.OrdinalIgnoreCase)) {
                            remoteModsLower.Add(Path.GetFileName(path));
                        }
                    }
                }
            }

            string cacheFile = Path.Combine(targetDir, ".modpack_hash_cache.json");
            Dictionary<string, string> hashCache = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (File.Exists(cacheFile)) {
                try {
                    var loaded = js.Deserialize<Dictionary<string, string>>(File.ReadAllText(cacheFile, Encoding.UTF8));
                    if (loaded != null) {
                        foreach (var kv in loaded) hashCache[kv.Key] = kv.Value;
                    }
                } catch { }
            }

            List<RemoteTreeEntry> toDownload = new List<RemoteTreeEntry>();
            int totalFiles = remoteFiles.Count;
            int skippedFiles = 0;

            for (int i = 0; i < totalFiles; i++) {
                RemoteTreeEntry entry = remoteFiles[i];
                string localPath = Path.Combine(targetDir, entry.Path.Replace('/', Path.DirectorySeparatorChar));

                if (i % 25 == 0 || i == totalFiles - 1) {
                    int pct = 80 + (int)((i + 1) * 170.0 / Math.Max(1, totalFiles));
                    SetStatus(string.Format("\u041f\u0435\u0440\u0435\u0432\u0456\u0440\u043a\u0430 \u043b\u043e\u043a\u0430\u043b\u044c\u043d\u0438\u0445 \u0444\u0430\u0439\u043b\u0456\u0432 [{0}/{1}]...", i + 1, totalFiles), pct);
                }

                if (LocalFileMatchesGitSha(localPath, entry.Sha, entry.Size, hashCache)) {
                    skippedFiles++;
                } else {
                    toDownload.Add(entry);
                }
            }

            LogMessage(string.Format("\u041f\u0435\u0440\u0435\u0432\u0456\u0440\u0435\u043d\u043e \u0444\u0430\u0439\u043b\u0456\u0432: {0}. \u0411\u0435\u0437 \u0437\u043c\u0456\u043d (\u043f\u0440\u043e\u043f\u0443\u0449\u0435\u043d\u043e): {1}. \u041f\u043e\u0442\u0440\u0435\u0431\u0443\u044e\u0442\u044c \u0437\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f/\u043e\u043d\u043e\u0432\u043b\u0435\u043d\u043d\u044f: {2}.",
                totalFiles, skippedFiles, toDownload.Count));

            string testVersionDir = Path.Combine(versionsRoot, "Test");
            string backupModsDir = Path.Combine(targetDir, "mods_backup");
            int downloadedCount = 0;
            int copiedLocalCount = 0;

            for (int i = 0; i < toDownload.Count; i++) {
                RemoteTreeEntry entry = toDownload[i];
                string localPath = Path.Combine(targetDir, entry.Path.Replace('/', Path.DirectorySeparatorChar));
                string parentDir = Path.GetDirectoryName(localPath);
                if (!Directory.Exists(parentDir)) {
                    Directory.CreateDirectory(parentDir);
                }

                int pct = 250 + (int)((i + 1) * 680.0 / Math.Max(1, toDownload.Count));
                string fileName = Path.GetFileName(entry.Path);
                string sizeMb = entry.Size > 0 ? string.Format(" ({0:0.00} \u041c\u0411)", entry.Size / 1048576.0) : "";

                string candidateBackup = Path.Combine(backupModsDir, fileName);
                string candidateTest = Path.Combine(testVersionDir, entry.Path.Replace('/', Path.DirectorySeparatorChar));

                if (!string.Equals(localPath, candidateBackup, StringComparison.OrdinalIgnoreCase) &&
                    LocalFileMatchesGitSha(candidateBackup, entry.Sha, entry.Size, hashCache)) {
                    SetStatus(string.Format("\u0412\u0456\u0434\u043d\u043e\u0432\u043b\u0435\u043d\u043d\u044f \u0437 \u043b\u043e\u043a\u0430\u043b\u044c\u043d\u043e\u0433\u043e \u043a\u0435\u0448\u0443 [{0}/{1}]: {2}", i + 1, toDownload.Count, fileName), pct);
                    File.Copy(candidateBackup, localPath, true);
                    LogMessage("  [\u041a\u0435\u0448] \u0412\u0456\u0434\u043d\u043e\u0432\u043b\u0435\u043d\u043e \u0437 mods_backup: " + entry.Path);
                    copiedLocalCount++;
                    continue;
                }

                if (!string.Equals(localPath, candidateTest, StringComparison.OrdinalIgnoreCase) &&
                    LocalFileMatchesGitSha(candidateTest, entry.Sha, entry.Size, hashCache)) {
                    SetStatus(string.Format("\u041a\u043e\u043f\u0456\u044e\u0432\u0430\u043d\u043d\u044f \u0437 \u043b\u043e\u043a\u0430\u043b\u044c\u043d\u043e\u0457 \u0437\u0431\u0456\u0440\u043a\u0438 [{0}/{1}]: {2}", i + 1, toDownload.Count, fileName), pct);
                    File.Copy(candidateTest, localPath, true);
                    LogMessage("  [\u041b\u043e\u043a\u0430\u043b\u044c\u043d\u043e] \u0421\u043a\u043e\u043f\u0456\u0439\u043e\u0432\u0430\u043d\u043e \u0437 \u043f\u0430\u043f\u043a\u0438 Test: " + entry.Path);
                    copiedLocalCount++;
                    continue;
                }

                SetStatus(string.Format("\u0417\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f [{0}/{1}]: {2}{3}", i + 1, toDownload.Count, fileName, sizeMb), pct);
                LogMessage("  [\u0417\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f] " + entry.Path + sizeMb);

                string[] segments = entry.Path.Split('/');
                for (int s = 0; s < segments.Length; s++) {
                    segments[s] = Uri.EscapeDataString(segments[s]);
                }
                string rawUrl = RawBase + "/" + fullCommitSha + "/" + string.Join("/", segments);
                string tempFile = localPath + ".downloading";

                HttpWebRequest dlReq = (HttpWebRequest)WebRequest.Create(rawUrl);
                dlReq.UserAgent = "MinecraftModpackDeltaSync/4.0";
                dlReq.Timeout = 30000;
                using (HttpWebResponse dlResp = (HttpWebResponse)dlReq.GetResponse())
                using (Stream respStream = dlResp.GetResponseStream())
                using (FileStream fs = new FileStream(tempFile, FileMode.Create, FileAccess.Write, FileShare.None)) {
                    byte[] buffer = new byte[65536];
                    long totalRead = 0;
                    long totalLen = dlResp.ContentLength > 0 ? dlResp.ContentLength : entry.Size;
                    int read;
                    int lastUiTick = Environment.TickCount;
                    while ((read = respStream.Read(buffer, 0, buffer.Length)) > 0) {
                        fs.Write(buffer, 0, read);
                        totalRead += read;
                        if (Environment.TickCount - lastUiTick > 80 && totalLen > 0) {
                            lastUiTick = Environment.TickCount;
                            double fileFrac = (double)totalRead / totalLen;
                            int subPct = 250 + (int)(((i + fileFrac) * 680.0) / Math.Max(1, toDownload.Count));
                            SetStatus(string.Format("\u0417\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043d\u044f [{0}/{1}]: {2} ({3:0.00} / {4:0.00} \u041c\u0411)",
                                i + 1, toDownload.Count, fileName, totalRead / 1048576.0, totalLen / 1048576.0), subPct);
                        }
                    }
                }

                if (File.Exists(localPath)) File.Delete(localPath);
                File.Move(tempFile, localPath);

                FileInfo newFi = new FileInfo(localPath);
                string newCacheKey = localPath.ToLowerInvariant() + "|" + newFi.Length + "|" + newFi.LastWriteTimeUtc.Ticks;
                hashCache[newCacheKey] = entry.Sha;
                downloadedCount++;
            }

            SetStatus("\u041f\u0435\u0440\u0435\u0432\u0456\u0440\u043a\u0430 \u043f\u0430\u043f\u043a\u0438 mods/ \u043d\u0430 \u0437\u0430\u0441\u0442\u0430\u0440\u0456\u043b\u0456 \u043c\u043e\u0434\u0438...", 950);
            string targetModsDir = Path.Combine(targetDir, "mods");
            int removedModsCount = 0;
            if (Directory.Exists(targetModsDir) && remoteModsLower.Count > 0) {
                foreach (string deact in Directory.GetFiles(targetModsDir, "*.deactivation")) {
                    try { File.Delete(deact); } catch { }
                }
                foreach (string jarPath in Directory.GetFiles(targetModsDir, "*.jar")) {
                    string jarName = Path.GetFileName(jarPath);
                    if (!remoteModsLower.Contains(jarName)) {
                        if (!Directory.Exists(backupModsDir)) Directory.CreateDirectory(backupModsDir);
                        string destBackup = Path.Combine(backupModsDir, jarName);
                        if (File.Exists(destBackup)) File.Delete(destBackup);
                        File.Move(jarPath, destBackup);
                        LogMessage("  [\u041f\u0440\u0438\u0431\u0440\u0430\u043d\u043e \u0432 backup] " + jarName);
                        removedModsCount++;
                    }
                }
            }

            string folderName = Path.GetFileName(targetDir.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            string parentPath = Path.GetDirectoryName(targetDir.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            if (string.Equals(parentPath, versionsRoot, StringComparison.OrdinalIgnoreCase)) {
                string testJson = Path.Combine(targetDir, "Test.json");
                string testJar = Path.Combine(targetDir, "Test.jar");
                string customJson = Path.Combine(targetDir, folderName + ".json");
                string customJar = Path.Combine(targetDir, folderName + ".jar");

                if (!string.Equals(folderName, "Test", StringComparison.OrdinalIgnoreCase)) {
                    if (File.Exists(testJson)) {
                        string jsonText = File.ReadAllText(testJson, Encoding.UTF8);
                        jsonText = Regex.Replace(jsonText, "\"id\"\\s*:\\s*\"Test\"", "\"id\": \"" + folderName + "\"");
                        File.WriteAllText(customJson, jsonText, Encoding.UTF8);
                    }
                    if (File.Exists(testJar) && !File.Exists(customJar)) {
                        File.Copy(testJar, customJar, true);
                    }
                }

                string tlProps = Path.Combine(minecraftRoot, "tlauncher-2.0.properties");
                if (File.Exists(tlProps)) {
                    try {
                        string props = File.ReadAllText(tlProps, Encoding.UTF8);
                        props = Regex.Replace(props, @"(?m)^login\.version\.game=.*$", "login.version.game=" + folderName);
                        props = Regex.Replace(props, @"(?m)^modpack\.combobox\.name=.*$", "modpack.combobox.name=" + folderName);
                        File.WriteAllText(tlProps, props, Encoding.UTF8);
                    } catch { }
                }
            }

            try {
                File.WriteAllText(cacheFile, js.Serialize(hashCache), Encoding.UTF8);
                File.WriteAllText(Path.Combine(targetDir, ".synced_commit.txt"), fullCommitSha, Encoding.UTF8);
                var stateObj = new Dictionary<string, string> {
                    { "LastTargetDir", targetDir },
                    { "LastBranch", branchName },
                    { "LastCommit", fullCommitSha },
                    { "UpdatedAt", DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") }
                };
                File.WriteAllText(stateFilePath, js.Serialize(stateObj), Encoding.UTF8);
            } catch { }

            string summary = string.Format("\u0413\u043e\u0442\u043e\u0432\u043e! \u0417\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0435\u043d\u043e: {0}, \u0417 \u043b\u043e\u043a\u0430\u043b\u044c\u043d\u043e\u0433\u043e \u043a\u0435\u0448\u0443: {1}, \u041f\u0440\u043e\u043f\u0443\u0449\u0435\u043d\u043e (\u0431\u0435\u0437 \u0437\u043c\u0456\u043d): {2}, \u041f\u0440\u0438\u0431\u0440\u0430\u043d\u043e \u0437\u0430\u0439\u0432\u0438\u0445: {3}",
                downloadedCount, copiedLocalCount, skippedFiles, removedModsCount);
            SetStatus(summary, 1000);
            LogMessage(summary);

            this.BeginInvoke(new Action(() => {
                UpdateCurrentFolderInfo();
                SetBusy(false);
                if (launchAfterSync) {
                    LaunchTLauncher();
                    this.Close();
                }
            }));
        }

        private void LaunchTLauncher() {
            try {
                string origExe = Path.Combine(minecraftRoot, "TLauncher_original.exe");
                if (File.Exists(origExe)) {
                    ProcessStartInfo psi = new ProcessStartInfo();
                    psi.FileName = origExe;
                    if (launchArgs != null && launchArgs.Length > 0) {
                        psi.Arguments = string.Join(" ", launchArgs);
                    }
                    psi.WorkingDirectory = minecraftRoot;
                    psi.UseShellExecute = true;
                    Process.Start(psi);
                }
            } catch (Exception ex) {
                MessageBox.Show(this, "\u041d\u0435 \u0432\u0434\u0430\u043b\u043e\u0441\u044f \u0437\u0430\u043f\u0443\u0441\u0442\u0438\u0442\u0438 TLauncher_original.exe:\n" + ex.Message, "\u041f\u043e\u043c\u0438\u043b\u043a\u0430", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        [STAThread]
        public static void Main(string[] args) {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SyncForm(args));
        }
    }
}

'@

$csc = Get-ChildItem "$env:WINDIR\Microsoft.NET\Framework64\v4*\csc.exe" | Select-Object -Last 1
if (-not $csc) {
    $csc = Get-ChildItem "$env:WINDIR\Microsoft.NET\Framework\v4*\csc.exe" | Select-Object -Last 1
}

if ($csc) {
    $tempCs = Join-Path $env:TEMP 'ModpackSyncApp_build.cs'
    Set-Content -LiteralPath $tempCs -Value $csSource -Encoding Ascii -Force

    $icoPath = Join-Path $mcRoot 'libraries\minecraft.ico'
    $baseArgs = @(
        '/nologo',
        '/target:winexe',
        '/r:System.dll',
        '/r:System.Drawing.dll',
        '/r:System.Windows.Forms.dll',
        '/r:System.Web.Extensions.dll'
    )
    if (Test-Path -LiteralPath $icoPath) {
        $baseArgs += "/win32icon:$icoPath"
    }

    Remove-Item -LiteralPath $syncGuiExe -Force -ErrorAction SilentlyContinue
    $argsGui = $baseArgs + @("/out:$syncGuiExe", $tempCs)
    & $csc.FullName @argsGui | Out-Null

    if (Test-Path -LiteralPath $tlOrig) {
        Remove-Item -LiteralPath $tlExe -Force -ErrorAction SilentlyContinue
        $argsTl = $baseArgs + @("/out:$tlExe", $tempCs)
        & $csc.FullName @argsTl | Out-Null
    }

    Remove-Item -LiteralPath $tempCs -Force -ErrorAction SilentlyContinue
}

if (-not $InstallOnly) {
    if (Test-Path -LiteralPath $syncGuiExe) {
        Start-Process -FilePath $syncGuiExe -WorkingDirectory $mcRoot
    } elseif (Test-Path -LiteralPath $tlExe) {
        Start-Process -FilePath $tlExe -WorkingDirectory $mcRoot
    }
}
