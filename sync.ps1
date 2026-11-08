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
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace ModpackSync {
    public static class WinCred {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct CREDENTIAL {
            public uint Flags;
            public uint Type;
            public string TargetName;
            public string Comment;
            public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
            public uint CredentialBlobSize;
            public IntPtr CredentialBlob;
            public uint Persist;
            public uint AttributeCount;
            public IntPtr Attributes;
            public string TargetAlias;
            public string UserName;
        }

        [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CredRead(string target, uint type, int reservedFlag, out IntPtr credentialPtr);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool CredFree(IntPtr cred);

        public static string GetGitHubToken() {
            string[] targets = new string[] {
                "git:https://github.com",
                "git:https://MrProper119@github.com",
                "git:https://kn253dis-cmyk@github.com"
            };
            foreach (string t in targets) {
                IntPtr ptr;
                if (CredRead(t, 1, 0, out ptr)) {
                    try {
                        CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
                        if (c.CredentialBlob != IntPtr.Zero && c.CredentialBlobSize > 0) {
                            byte[] bytes = new byte[c.CredentialBlobSize];
                            Marshal.Copy(c.CredentialBlob, bytes, 0, (int)c.CredentialBlobSize);
                            string s = Encoding.Unicode.GetString(bytes).Trim('\0', '\r', '\n', ' ');
                            if (s.IndexOf('\0') >= 0 || (!s.StartsWith("gh") && !s.StartsWith("github_"))) {
                                s = Encoding.UTF8.GetString(bytes).Replace("\0", "").Trim();
                            }
                            if (!string.IsNullOrEmpty(s)) return s;
                        }
                    } catch {
                    } finally {
                        CredFree(ptr);
                    }
                }
            }
            return null;
        }
    }

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

        private string minecraftRoot;
        private string versionsRoot;
        private string stateFilePath;
        private string metaGitDir;
        private string gitToken;

        private ComboBox cmbFolders;
        private Button btnBrowseFolder;
        private Button btnNewVersion;
        private ComboBox cmbBranches;
        private Button btnRefresh;
        private ComboBox cmbCommits;
        private Label lblCurrentCommit;
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
            gitToken = WinCred.GetGitHubToken();

            InitializeComponents();
            LoadFolders();
            this.Shown += (s, e) => FetchBranchesAsync();
        }

        private void InitializeComponents() {
            this.Text = "\u0421\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u044f \u0437\u0431\u0456\u0440\u043a\u0438 Minecraft 1.21.1 (GitHub -> TLauncher)";
            this.Size = new Size(760, 560);
            this.MinimumSize = new Size(720, 520);
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
            lblHeader.Text = "\u0421\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u044f \u043c\u043e\u0434\u043f\u0430\u043a\u0443 Minecraft (Delta Sync)";
            lblHeader.Font = new Font("Segoe UI", 14f, FontStyle.Bold);
            lblHeader.ForeColor = Color.FromArgb(137, 180, 250);
            lblHeader.Location = new Point(20, 14);
            lblHeader.AutoSize = true;
            this.Controls.Add(lblHeader);

            Label lblSubHeader = new Label();
            lblSubHeader.Text = "\u041f\u0435\u0440\u0435\u0432\u0456\u0440\u044f\u0454 \u043b\u0438\u0448\u0435 \u0432\u0456\u0434\u043c\u0456\u043d\u043d\u043e\u0441\u0442\u0456 \u0439 \u0434\u043e\u0432\u0430\u043d\u0442\u0430\u0436\u0443\u0454 \u0442\u0456\u043b\u044c\u043a\u0438 \u043d\u043e\u0432\u0456 \u0430\u0431\u043e \u0437\u043c\u0456\u043d\u0435\u043d\u0456 \u043c\u043e\u0434\u0438 \u0442\u0430 \u043a\u043e\u043d\u0444\u0456\u0433\u0438";
            lblSubHeader.Font = new Font("Segoe UI", 9f, FontStyle.Regular);
            lblSubHeader.ForeColor = Color.FromArgb(166, 173, 200);
            lblSubHeader.Location = new Point(22, 42);
            lblSubHeader.AutoSize = true;
            this.Controls.Add(lblSubHeader);

            Label lblFolder = new Label();
            lblFolder.Text = "1. \u041f\u0430\u043f\u043a\u0430 \u0437\u0431\u0456\u0440\u043a\u0438 (\u043a\u0443\u0434\u0438 \u0437\u0430\u0432\u0430\u043d\u0442\u0430\u0436\u0443\u0432\u0430\u0442\u0438):";
            lblFolder.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            lblFolder.Location = new Point(20, 74);
            lblFolder.AutoSize = true;
            this.Controls.Add(lblFolder);

            cmbFolders = new ComboBox();
            cmbFolders.Location = new Point(20, 98);
            cmbFolders.Size = new Size(510, 28);
            cmbFolders.BackColor = Color.FromArgb(49, 50, 68);
            cmbFolders.ForeColor = Color.White;
            cmbFolders.SelectedIndexChanged += (s, e) => UpdateCurrentFolderInfo();
            cmbFolders.TextChanged += (s, e) => UpdateCurrentFolderInfo();
            this.Controls.Add(cmbFolders);

            btnBrowseFolder = CreateButton("\u041e\u0433\u043b\u044f\u0434...", new Point(540, 96), new Size(90, 28), Color.FromArgb(69, 71, 90));
            btnBrowseFolder.Click += BtnBrowseFolder_Click;
            this.Controls.Add(btnBrowseFolder);

            btnNewVersion = CreateButton("+ \u041d\u043e\u0432\u0430", new Point(638, 96), new Size(85, 28), Color.FromArgb(69, 71, 90));
            btnNewVersion.Click += BtnNewVersion_Click;
            this.Controls.Add(btnNewVersion);

            Label lblBranch = new Label();
            lblBranch.Text = "2. \u0413\u0456\u043b\u043a\u0430 \u0440\u0435\u043f\u043e\u0437\u0438\u0442\u043e\u0440\u0456\u044e (Branch):";
            lblBranch.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            lblBranch.Location = new Point(20, 136);
            lblBranch.AutoSize = true;
            this.Controls.Add(lblBranch);

            cmbBranches = new ComboBox();
            cmbBranches.DropDownStyle = ComboBoxStyle.DropDownList;
            cmbBranches.Location = new Point(20, 160);
            cmbBranches.Size = new Size(580, 28);
            cmbBranches.BackColor = Color.FromArgb(49, 50, 68);
            cmbBranches.ForeColor = Color.White;
            cmbBranches.SelectedIndexChanged += CmbBranches_SelectedIndexChanged;
            this.Controls.Add(cmbBranches);

            btnRefresh = CreateButton("\u041e\u043d\u043e\u0432\u0438\u0442\u0438", new Point(610, 158), new Size(113, 28), Color.FromArgb(69, 71, 90));
            btnRefresh.Click += (s, e) => FetchBranchesAsync();
            this.Controls.Add(btnRefresh);

            Label lblCommit = new Label();
            lblCommit.Text = "3. \u041a\u043e\u043c\u0456\u0442 \u0434\u043b\u044f \u0441\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u0457 (\u0430\u0431\u043e \u0432\u0432\u0435\u0434\u0456\u0442\u044c \u0445\u0435\u0448 \u043a\u043e\u043c\u0456\u0442\u0443 \u0432\u0440\u0443\u0447\u043d\u0443):";
            lblCommit.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            lblCommit.Location = new Point(20, 198);
            lblCommit.AutoSize = true;
            this.Controls.Add(lblCommit);

            cmbCommits = new ComboBox();
            cmbCommits.Location = new Point(20, 222);
            cmbCommits.Size = new Size(703, 28);
            cmbCommits.BackColor = Color.FromArgb(49, 50, 68);
            cmbCommits.ForeColor = Color.White;
            this.Controls.Add(cmbCommits);

            lblCurrentCommit = new Label();
            lblCurrentCommit.Text = "\u0412\u0441\u0442\u0430\u043d\u043e\u0432\u043b\u0435\u043d\u0438\u0439 \u0443 \u043f\u0430\u043f\u0446\u0456 \u043a\u043e\u043c\u0456\u0442: \u043f\u0435\u0440\u0435\u0432\u0456\u0440\u043a\u0430...";
            lblCurrentCommit.ForeColor = Color.FromArgb(249, 226, 175);
            lblCurrentCommit.Location = new Point(20, 254);
            lblCurrentCommit.AutoSize = true;
            this.Controls.Add(lblCurrentCommit);

            lblStatus = new Label();
            lblStatus.Text = "\u0413\u043e\u0442\u043e\u0432\u043e \u0434\u043e \u0441\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u0457.";
            lblStatus.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            lblStatus.ForeColor = Color.FromArgb(166, 227, 161);
            lblStatus.Location = new Point(20, 282);
            lblStatus.Size = new Size(703, 22);
            this.Controls.Add(lblStatus);

            progressBar = new ProgressBar();
            progressBar.Location = new Point(20, 308);
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
            txtLog.Location = new Point(20, 342);
            txtLog.Size = new Size(703, 115);
            this.Controls.Add(txtLog);

            btnSyncAndLaunch = CreateButton("\u0421\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0443\u0432\u0430\u0442\u0438 \u0442\u0430 \u0437\u0430\u043f\u0443\u0441\u0442\u0438\u0442\u0438 TLauncher", new Point(20, 468), new Size(310, 40), Color.FromArgb(46, 160, 67));
            btnSyncAndLaunch.Font = new Font("Segoe UI", 10f, FontStyle.Bold);
            btnSyncAndLaunch.Click += (s, e) => StartSyncAsync(true);
            this.Controls.Add(btnSyncAndLaunch);

            btnSyncOnly = CreateButton("\u0422\u0456\u043b\u044c\u043a\u0438 \u0441\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0443\u0432\u0430\u0442\u0438", new Point(340, 468), new Size(175, 40), Color.FromArgb(56, 110, 200));
            btnSyncOnly.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
            btnSyncOnly.Click += (s, e) => StartSyncAsync(false);
            this.Controls.Add(btnSyncOnly);

            btnSkipAndLaunch = CreateButton("\u041f\u0440\u043e\u043f\u0443\u0441\u0442\u0438\u0442\u0438 -> TLauncher", new Point(525, 468), new Size(198, 40), Color.FromArgb(88, 91, 112));
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
                dlg.Description = "\u041e\u0431\u0435\u0440\u0456\u0442\u044c \u043f\u0430\u043f\u043a\u0443 \u0434\u043b\u044f \u0432\u0441\u0442\u0430\u043d\u043e\u0432\u043b\u0435\u043d\u043d\u044f / \u0441\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u0457 \u0437\u0431\u0456\u0440\u043a\u0438";
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
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = FindGitExe();
            psi.Arguments = arguments;
            psi.WorkingDirectory = workingDir;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            psi.StandardOutputEncoding = Encoding.UTF8;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            using (Process p = Process.Start(psi)) {
                string output = p.StandardOutput.ReadToEnd();
                p.WaitForExit();
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
            req.UserAgent = "MinecraftModpackDeltaSync/3.0";
            req.Timeout = 15000;
            if (!string.IsNullOrEmpty(gitToken)) {
                req.Headers.Add("Authorization", "Bearer " + gitToken);
            }
            using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
            using (StreamReader sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8)) {
                return sr.ReadToEnd();
            }
        }

        private void FetchBranchesAsync() {
            if (isBusy) return;
            SetBusy(true);
            SetStatus("\u041e\u0442\u0440\u0438\u043c\u0430\u043d\u043d\u044f \u0441\u043f\u0438\u0441\u043a\u0443 \u0433\u0456\u043b\u043e\u043a \u0456\u0437 GitHub...", 50);
            LogMessage("\u0417\u0430\u043f\u0438\u0442 \u0441\u043f\u0438\u0441\u043a\u0443 \u0433\u0456\u043b\u043e\u043a \u0456\u0437 GitHub...");

            ThreadPool.QueueUserWorkItem(_ => {
                List<BranchItem> branches = new List<BranchItem>();
                try {
                    try {
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
                    } catch {

                        EnsureMetaGitUpdated();
                        string refsOut = RunGitCommand(metaGitDir, "for-each-ref --sort=-committerdate \"refs/remotes/origin\" --format=\"%(refname:short)|%(objectname)\"");
                        foreach (string line in refsOut.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)) {
                            string[] parts = line.Split('|');
                            if (parts.Length < 2) continue;
                            string bName = Regex.Replace(parts[0].Trim(), "^origin/", "");
                            if (bName == "HEAD" || bName == "origin" || string.Equals(bName, "sync-script", StringComparison.OrdinalIgnoreCase)) continue;
                            branches.Add(new BranchItem { Name = bName, Sha = parts[1].Trim() });
                        }
                    }

                    branches.Sort((a, b) => {
                        int scoreA = a.Name.StartsWith("mekanism-realistic-fixed") ? 0 : (a.Name.StartsWith("mekanism-realistic") ? 1 : (a.Name == "main" ? 2 : 3));
                        int scoreB = b.Name.StartsWith("mekanism-realistic-fixed") ? 0 : (b.Name.StartsWith("mekanism-realistic") ? 1 : (b.Name == "main" ? 2 : 3));
                        if (scoreA != scoreB) return scoreA.CompareTo(scoreB);
                        return string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase);
                    });

                    this.BeginInvoke(new Action(() => {
                        cmbBranches.Items.Clear();
                        foreach (var br in branches) {
                            cmbBranches.Items.Add(br);
                        }
                        SetBusy(false);
                        if (cmbBranches.Items.Count > 0) {
                            cmbBranches.SelectedIndex = 0;
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
                    } catch {
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
                        SetStatus("\u0413\u043e\u0442\u043e\u0432\u043e \u0434\u043e \u0441\u0438\u043d\u0445\u0440\u043e\u043d\u0456\u0437\u0430\u0446\u0456\u0457. \u041e\u0431\u0435\u0440\u0456\u0442\u044c \u043a\u043e\u043c\u0456\u0442 \u0456 \u043d\u0430\u0442\u0438\u0441\u043d\u0456\u0442\u044c \u043a\u043d\u043e\u043f\u043a\u0443 \u043d\u0438\u0436\u0447\u0435.", 0);
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
            LogMessage("\u041e\u0431\u0440\u0430\u043d\u0438\u0439 \u043a\u043e\u043c\u0456\u0442: " + targetCommitSha);

            ThreadPool.QueueUserWorkItem(_ => {
                try {
                    RunDeltaSync(targetDir, targetCommitSha, launchAfterSync);
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

        private void RunDeltaSync(string targetDir, string commitShaOrRef, bool launchAfterSync) {
            if (!Directory.Exists(targetDir)) {
                Directory.CreateDirectory(targetDir);
            }

            JavaScriptSerializer js = new JavaScriptSerializer();
            js.MaxJsonLength = int.MaxValue;

            string fullCommitSha = commitShaOrRef;
            List<RemoteTreeEntry> remoteFiles = new List<RemoteTreeEntry>();
            HashSet<string> remoteModsLower = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            SetStatus("\u041e\u0442\u0440\u0438\u043c\u0430\u043d\u043d\u044f \u0441\u043f\u0438\u0441\u043a\u0443 \u0444\u0430\u0439\u043b\u0456\u0432 \u043a\u043e\u043c\u0456\u0442\u0443...", 50);
            bool treeLoadedViaApi = false;

            try {
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

                        if (string.Equals(path, "sync.ps1", StringComparison.OrdinalIgnoreCase) ||
                            string.Equals(path, "sync.bat", StringComparison.OrdinalIgnoreCase)) {
                            continue;
                        }

                        remoteFiles.Add(new RemoteTreeEntry { Path = path, Sha = sha, Size = size });
                        if (path.StartsWith("mods/", StringComparison.OrdinalIgnoreCase) && path.EndsWith(".jar", StringComparison.OrdinalIgnoreCase)) {
                            remoteModsLower.Add(Path.GetFileName(path));
                        }
                    }
                    treeLoadedViaApi = true;
                }
            } catch {
                treeLoadedViaApi = false;
            }

            if (!treeLoadedViaApi) {
                LogMessage("\u0412\u0438\u043a\u043e\u0440\u0438\u0441\u0442\u0430\u043d\u043d\u044f \u0448\u0432\u0438\u0434\u043a\u043e\u0433\u043e \u043c\u0435\u0442\u0430-\u043a\u0435\u0448\u0443 Git (200 \u041a\u0411) \u0434\u043b\u044f \u0441\u043f\u0438\u0441\u043a\u0443 \u0444\u0430\u0439\u043b\u0456\u0432...");
                EnsureMetaGitUpdated();
                if (fullCommitSha.Length < 40) {
                    string resolved = RunGitCommand(metaGitDir, "rev-parse \"" + commitShaOrRef + "\"").Trim();
                    if (resolved.Length == 40) fullCommitSha = resolved;
                }
                string lsTreeOut = RunGitCommand(metaGitDir, "-c core.quotePath=false ls-tree -r \"" + fullCommitSha + "\"");
                foreach (string line in lsTreeOut.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)) {
                    int tabIdx = line.IndexOf('\t');
                    if (tabIdx <= 0) continue;
                    string metaPart = line.Substring(0, tabIdx).Trim();
                    string path = line.Substring(tabIdx + 1).Trim();
                    string[] mParts = metaPart.Split(new char[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    if (mParts.Length < 3 || mParts[1] != "blob") continue;
                    string sha = mParts[2];

                    if (string.Equals(path, "sync.ps1", StringComparison.OrdinalIgnoreCase) ||
                        string.Equals(path, "sync.bat", StringComparison.OrdinalIgnoreCase)) {
                        continue;
                    }

                    remoteFiles.Add(new RemoteTreeEntry { Path = path, Sha = sha, Size = -1 });
                    if (path.StartsWith("mods/", StringComparison.OrdinalIgnoreCase) && path.EndsWith(".jar", StringComparison.OrdinalIgnoreCase)) {
                        remoteModsLower.Add(Path.GetFileName(path));
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
                dlReq.UserAgent = "MinecraftModpackDeltaSync/3.0";
                dlReq.Timeout = 30000;
                if (!string.IsNullOrEmpty(gitToken)) {
                    dlReq.Headers.Add("Authorization", "Bearer " + gitToken);
                }
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
    $tempExe = Join-Path $env:TEMP 'ModpackSyncGui_build.exe'
    Set-Content -LiteralPath $tempCs -Value $csSource -Encoding Ascii -Force

    $icoPath = Join-Path $mcRoot 'libraries\minecraft.ico'
    $cscArgs = @(
        '/nologo',
        '/target:winexe',
        '/r:System.dll',
        '/r:System.Drawing.dll',
        '/r:System.Windows.Forms.dll',
        '/r:System.Web.Extensions.dll',
        "/out:$tempExe"
    )
    if (Test-Path -LiteralPath $icoPath) {
        $cscArgs += "/win32icon:$icoPath"
    }
    $cscArgs += $tempCs

    & $csc.FullName @cscArgs | Out-Null
    if (Test-Path -LiteralPath $tempExe) {
        Copy-Item -LiteralPath $tempExe -Destination $syncGuiExe -Force
        if (Test-Path -LiteralPath $tlOrig) {
            Copy-Item -LiteralPath $tempExe -Destination $tlExe -Force
        }
        Remove-Item -LiteralPath $tempExe -Force
    }
    Remove-Item -LiteralPath $tempCs -Force
}

if (-not $InstallOnly) {
    if (Test-Path -LiteralPath $syncGuiExe) {
        Start-Process -FilePath $syncGuiExe -WorkingDirectory $mcRoot
    } elseif (Test-Path -LiteralPath $tlExe) {
        Start-Process -FilePath $tlExe -WorkingDirectory $mcRoot
    }
}
