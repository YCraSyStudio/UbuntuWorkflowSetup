using System.Text.Json;
using System.Text.RegularExpressions;

internal sealed class Installer
{
    private readonly string user = Environment.GetEnvironmentVariable("SUDO_USER") ?? Commands.Output("id", ["-un"]);
    private readonly string architecture = Commands.Output("dpkg", ["--print-architecture"]);
    private string home = "";
    private HashSet<string> selected = [];
    private readonly Dictionary<string, string> versions = new();
    private bool Has(string app) => selected.Contains(app);
    private static string Setting(string name, string fallback) =>
        Environment.GetEnvironmentVariable(name) is { Length: > 0 } value ? value : fallback;
    private static void Log(string message) => Console.WriteLine($"\n==> {message}");
    private static void Sudo(params string[] args) => Commands.Run("sudo", args);
    private static void Apt(params string[] args) => Sudo(["apt", .. args]);

    private string[] UserArgs(string executable, string[] args) =>
        ["-u", user, "-H", "env",
            .. new[] { "DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "XDG_RUNTIME_DIR" }
                .Select(name => $"{name}={Setting(name, name == "XDG_RUNTIME_DIR" ? $"/run/user/{Commands.Output("id", ["-u", user])}" : "")}"),
            executable, .. args];

    private void AsUser(string executable, params string[] args)
    {
        if (user == Environment.UserName) Commands.Run(executable, args);
        else Sudo(UserArgs(executable, args));
    }

    private string UserOutput(string executable, string[] args, bool required = true) =>
        user == Environment.UserName ? Commands.Output(executable, args, required)
            : Commands.Output("sudo", UserArgs(executable, args), required);

    private void UserWrite(string input, string executable, params string[] args)
    {
        if (user == Environment.UserName) Commands.Write(input, executable, args);
        else Commands.Write(input, "sudo", UserArgs(executable, args));
    }

    internal void Run()
    {
        var release = File.ReadLines("/etc/os-release")
            .Where(line => !line.StartsWith('#') && line.Contains('='))
            .Select(line => line.Split('=', 2))
            .ToDictionary(parts => parts[0], parts => parts[1].Trim('"', '\''));
        if (release.GetValueOrDefault("ID") != "ubuntu" ||
            !int.TryParse(release.GetValueOrDefault("VERSION_ID")?.Split('.')[0], out var major) || major < 24)
            throw new InvalidOperationException("Se requiere Ubuntu 24.04 o posterior.");

        var account = Commands.Output("getent", ["passwd", user]).Split(':');
        if (account.Length < 7 || !Directory.Exists(account[5]))
            throw new InvalidOperationException($"No se pudo detectar HOME para {user}.");
        home = account[5];

        selected = Selector.Read();
        if (architecture != "amd64")
        {
            foreach (var app in new[] { "chrome", "unity" })
                if (selected.Remove(app))
                    Console.WriteLine($"Se omite {Selector.Apps.Single(item => item.Id == app).Label} en {architecture}.");
        }

        Sudo("-v");
        Log("Actualizar Ubuntu");
        Apt("update");
        Apt("upgrade", "-y");
        CleanupPreinstalled();
        Apt("install", "-y", "ca-certificates", "curl", "git", "git-lfs", "gnupg", "jq", "snapd", "unzip");
        if (Has("node")) Apt("install", "-y", "libatomic1");
        if (Has("gnome"))
            Apt("install", "-y", "gir1.2-gda-5.0", "gir1.2-gsound-1.0", "gnome-browser-connector", "gnome-shell-extension-manager");
        Sudo("install", "-m", "0755", "-d", "/etc/apt/keyrings", "/usr/share/keyrings");

        Log("Configurar repositorios seleccionados");
        ConfigureRepositories(release.GetValueOrDefault("UBUNTU_CODENAME") ?? release["VERSION_CODENAME"]);
        Log("Instalar aplicaciones seleccionadas");
        InstallPackages();
        foreach (var (app, package) in new[] { ("chromium", "chromium"), ("telegram", "telegram-desktop"), ("dbeaver", "dbeaver-ce"), ("bruno", "bruno") })
        {
            if (!Has(app)) continue;
            if (Commands.Output("snap", ["list", package], false).Length == 0)
                Sudo(app == "dbeaver" ? ["snap", "install", package, "--classic"] : ["snap", "install", package]);
            versions[app] = Commands.Output("snap", ["list", package], false).Split('\n').ElementAtOrDefault(1)?
                .Split(' ', StringSplitOptions.RemoveEmptyEntries).ElementAtOrDefault(1) ?? "";
        }

        if (Has("node")) InstallNode();
        if (Has("chatgpt")) InstallChatGpt();
        if (Has("yed")) InstallYed();
        if (Has("copyous") || Has("dash")) InstallExtensions();
        ConfigureServices();
        Apt("autoremove", "--purge", "-y");
        Apt("autoclean", "-y");
        PrintSummary();
        Console.Write("¿Quieres reiniciar el equipo ahora? [s/N] ");
        if (Console.ReadLine()?.Trim().ToLowerInvariant() is "s" or "y" or "si" or "sí" or "yes")
            Sudo("systemctl", "reboot");
        else
            Log("No se reiniciará el equipo");
    }

    private static void CleanupPreinstalled()
    {
        Log("Eliminar aplicaciones preinstaladas no deseadas");
        if (Commands.Output("snap", ["list", "firefox"], false).Length > 0)
            Sudo("snap", "remove", "--purge", "firefox");
        var installed = new[] { "firefox", "gnome-user-docs", "vim", "vim-common", "vim-runtime", "vim-tiny", "yelp" }
            .Where(package => Commands.Output("dpkg-query", ["-W", "-f=${db:Status-Abbrev}", package], false).StartsWith("ii"))
            .ToArray();
        if (installed.Length > 0) Apt(["purge", "-y", .. installed]);
    }

    private void ConfigureRepositories(string codename)
    {
        var changed = false;
        Add("docker", "docker", "https://download.docker.com/linux/ubuntu/gpg", "/etc/apt/keyrings/docker.asc",
            "https://download.docker.com/linux/ubuntu", codename, architecture, false);
        Add("chrome", "google-chrome", "https://dl.google.com/linux/linux_signing_key.pub", "/usr/share/keyrings/google-chrome.gpg",
            "https://dl.google.com/linux/chrome-stable/deb/", "stable", "amd64", true);
        Add("vscode", "vscode", "https://packages.microsoft.com/keys/microsoft.asc", "/usr/share/keyrings/microsoft.gpg",
            "https://packages.microsoft.com/repos/code", "stable", architecture, true);
        Add("github", "github-cli", "https://cli.github.com/packages/githubcli-archive-keyring.gpg", "/etc/apt/keyrings/github-cli-archive-keyring.gpg",
            "https://cli.github.com/packages", "stable", null, false);
        Add("atlassian", "acli", "https://acli.atlassian.com/gpg/public-key.asc", "/etc/apt/keyrings/acli-archive-keyring.gpg",
            "https://acli.atlassian.com/linux/deb", "stable", null, true);
        Add("unity", "unityhub", "https://hub.unity3d.com/linux/keys/public", "/usr/share/keyrings/Unity_Technologies_ApS.gpg",
            "https://hub.unity3d.com/linux/repos/deb", "stable", null, true);
        if (changed) Apt("update");

        void Add(string app, string source, string keyUrl, string key, string uri, string suite, string? arch, bool dearmor)
        {
            if (!Has(app)) return;
            var path = $"/etc/apt/sources.list.d/{source}.sources";
            if (File.Exists(path) && new FileInfo(path).Length > 0 &&
                File.Exists(key) && new FileInfo(key).Length > 0 &&
                (arch is null || File.ReadLines(path).Contains($"Architectures: {arch}")))
                return;
            InTemporaryDirectory(directory =>
            {
                var downloaded = Path.Combine(directory, "key");
                Download(keyUrl, downloaded);
                var ready = downloaded;
                if (dearmor)
                {
                    ready = Path.Combine(directory, "key.gpg");
                    Commands.Run("gpg", "--batch", "--dearmor", "--output", ready, downloaded);
                }
                Sudo("install", "-m", "0644", ready, key);
            });
            var archLine = arch is null ? "" : $"Architectures: {arch}\n";
            Commands.Write($"Types: deb\nURIs: {uri}\nSuites: {suite}\nComponents: {(app == "docker" ? "stable" : "main")}\n{archLine}Signed-By: {key}\n",
                "sudo", "tee", path);
            changed = true;
        }
    }

    private void InstallPackages()
    {
        var packages = new List<string>();
        Add("docker", "docker-ce", "containerd.io", "docker-buildx-plugin", "docker-ce-cli", "docker-compose-plugin");
        Add("dotnet", $"dotnet-sdk-{Setting("DOTNET_VERSION", "10.0")}");
        Add("chrome", "google-chrome-stable");
        Add("vscode", "code");
        Add("github", "gh");
        Add("atlassian", "acli");
        Add("mysql", "mysql-server", "mysql-client", "default-libmysqlclient-dev");
        Add("postgresql", "postgresql", "postgresql-client");
        Add("unity", "unityhub");
        Add("yed", "default-jre");
        if (Has("qemu")) Add("qemu", QemuPackage(), "qemu-utils", "libvirt-daemon-system", "libvirt-clients", "virt-manager");
        if (packages.Count > 0) Apt(["install", "-y", .. packages]);

        void Add(string app, params string[] dependencies)
        {
            if (!Has(app)) return;
            packages.AddRange(dependencies);
            versions[app] = dependencies[0];
        }
    }

    private string QemuPackage()
    {
        var primary = architecture == "arm64" ? "qemu-system-arm" : "qemu-system-x86";
        foreach (var package in new[] { primary, $"{primary}-hwe", "qemu-kvm" })
        {
            var policy = Commands.Output("apt-cache", ["policy", package], false);
            if (Regex.IsMatch(policy, @"(?m)^\s*Candidate:\s+(?!\(none\))\S+")) return package;
        }
        return primary;
    }

    private void InstallNode()
    {
        var nvmVersion = Setting("NVM_VERSION", "v0.40.8");
        var nodeVersion = Setting("NODE_VERSION", "26");
        var directory = Path.Combine(home, ".nvm");
        const string nvm = """
            export NVM_DIR="$1"
            shift
            source "$NVM_DIR/nvm.sh" --no-use || exit
            nvm "$@"
            """;
        string[] Args(params string[] args) => ["-c", nvm, "nvm", directory, .. args];

        Log($"Instalar Node.js {nodeVersion} y herramientas JavaScript");
        if (!File.Exists(Path.Combine(directory, "nvm.sh")) ||
            UserOutput("/bin/bash", Args("--version"), false) != nvmVersion.TrimStart('v'))
        {
            var script = Commands.Output("curl", ["-fsSL", $"https://raw.githubusercontent.com/nvm-sh/nvm/{nvmVersion}/install.sh"]);
            UserWrite(script + "\n", "env", $"NVM_DIR={directory}", "/bin/bash", "-s");
        }
        AsUser("/bin/bash", Args("install", nodeVersion));
        AsUser("/bin/bash", Args("alias", "default", nodeVersion));
        var executable = UserOutput("/bin/bash", Args("which", nodeVersion));
        var path = $"{Path.GetDirectoryName(executable)}:{Environment.GetEnvironmentVariable("PATH")}";
        versions["node"] = UserOutput("env", [$"PATH={path}", "node", "--version"]);

        if (Has("npm"))
        {
            var major = Setting("NPM_MAJOR_VERSION", "12");
            if (!Npm("--version").StartsWith($"{major}."))
                AsUser("env", $"PATH={path}", "npm", "install", "-g", $"npm@{major}");
            versions["npm"] = Npm("--version");
        }
        InstallGlobal("angular", "@angular/cli", Setting("ANGULAR_MAJOR_VERSION", "22"));
        InstallGlobal("ncu", "npm-check-updates", Setting("NCU_MAJOR_VERSION", "23"));

        string Npm(params string[] args) => UserOutput("env", [$"PATH={path}", "npm", .. args]);
        string Version(string package)
        {
            var manifest = Path.Combine(Npm("root", "-g"), package, "package.json");
            if (!File.Exists(manifest)) return "";
            using var json = JsonDocument.Parse(File.ReadAllText(manifest));
            return json.RootElement.GetProperty("version").GetString() ?? "";
        }
        void InstallGlobal(string app, string package, string major)
        {
            if (!Has(app)) return;
            if (!Version(package).StartsWith($"{major}."))
                AsUser("env", $"PATH={path}", "npm", "install", "-g", $"{package}@{major}");
            versions[app] = Version(package);
        }
    }

    private void InstallChatGpt()
    {
        if (Commands.Output("dpkg-query", ["-W", "-f=${Status}", "chatgpt"], false) != "install ok installed")
        {
            if (architecture is not ("amd64" or "arm64"))
                throw new InvalidOperationException($"ChatGPT no admite {architecture}.");
            InTemporaryDirectory(directory =>
            {
                var package = Path.Combine(directory, $"chatgpt_{architecture}.deb");
                Download($"https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_{architecture}.deb", package);
                Commands.Run("chmod", "0644", package);
                Apt("install", "-y", package);
            }, shared: true);
        }
        versions["chatgpt"] = "chatgpt";
    }

    private void InstallYed()
    {
        var version = Setting("YED_VERSION", "3.25.1");
        var root = Path.Combine(home, ".local", "opt");
        var install = Path.Combine(root, $"yed-{version}");
        var jar = Path.Combine(install, "yed.jar");
        var launcher = Path.Combine(home, ".local", "bin", "yed");
        var applications = Path.Combine(home, ".local", "share", "applications");
        AsUser("install", "-d", root, Path.GetDirectoryName(launcher)!, applications);
        if (!File.Exists(jar))
            InTemporaryDirectory(directory =>
            {
                var archive = Path.Combine(directory, "yed.zip");
                Download(Setting("YED_ARCHIVE_URL", $"https://www.yworks.com/resources/yed/demo/yEd-{version}.zip"), archive);
                Commands.Run("chmod", "0644", archive);
                AsUser("unzip", "-oq", archive, "-d", root);
            }, shared: true);
        if (!File.Exists(jar)) throw new InvalidOperationException($"No se encontró {jar}.");
        UserWrite($"#!/bin/sh\nexec java -jar '{jar.Replace("'", "'\"'\"'")}' \"$@\"\n", "tee", launcher);
        AsUser("chmod", "0755", launcher);
        UserWrite($"[Desktop Entry]\nType=Application\nName=yEd Graph Editor\nExec=\"{launcher}\" %F\nIcon={install}/icons/yed128.png\nTerminal=false\nCategories=Graphics;Office;\nMimeType=application/x-yed;\n",
            "tee", Path.Combine(applications, "yed.desktop"));
        UserOutput("update-desktop-database", [applications], false);
        versions["yed"] = $"v{version}";
    }

    private void InstallExtensions()
    {
        var version = Regex.Match(Commands.Output("gnome-shell", ["--version"]), @"\d+").Value;
        if (version.Length == 0) throw new InvalidOperationException("No se pudo detectar la versión de GNOME Shell.");
        Add("copyous", "8834", "copyous@boerdereinar.dev");
        Add("dash", "1160", "dash-to-panel@jderose9.github.com");

        void Add(string app, string id, string uuid)
        {
            if (!Has(app)) return;
            using var info = JsonDocument.Parse(Commands.Output("curl", ["-fsSL", "--get", "--data-urlencode", $"pk={id}",
                "--data-urlencode", $"shell_version={version}", "https://extensions.gnome.org/extension-info/"]));
            var url = info.RootElement.GetProperty("download_url").GetString();
            if (info.RootElement.GetProperty("uuid").GetString() != uuid || url is null || !url.StartsWith('/') || url.StartsWith("//"))
                throw new InvalidOperationException($"Respuesta inesperada para la extensión {uuid}.");
            InTemporaryDirectory(directory =>
            {
                var archive = Path.Combine(directory, "extension.zip");
                Download($"https://extensions.gnome.org{url}", archive);
                Commands.Run("chmod", "0644", archive);
                AsUser("gnome-extensions", "install", "--force", archive);
            }, shared: true);
            UserOutput("gnome-extensions", ["enable", uuid], false);
            var metadata = Path.Combine(home, ".local", "share", "gnome-shell", "extensions", uuid, "metadata.json");
            if (File.Exists(metadata))
            {
                using var json = JsonDocument.Parse(File.ReadAllText(metadata));
                if (json.RootElement.TryGetProperty("version", out var installed))
                    versions[app] = $"v{installed}";
            }
        }
    }

    private void ConfigureServices()
    {
        Log("Configurar servicios");
        AsUser("git", "lfs", "install", "--skip-repo");
        foreach (var (app, service) in new[] { ("docker", "docker"), ("mysql", "mysql"), ("postgresql", "postgresql"), ("qemu", "libvirtd.socket") })
            if (Has(app)) Sudo("systemctl", "enable", "--now", service);
        if (Has("docker")) Sudo("usermod", "-aG", "docker", user);
        if (Has("qemu")) Sudo("usermod", "-aG", "libvirt,kvm", user);
    }

    private void PrintSummary()
    {
        Log("Versiones instaladas");
        if (Has("gnome")) versions["gnome"] = "gnome-shell-extension-manager";
        foreach (var app in Selector.Apps.Where(app => Has(app.Id)))
        {
            var value = versions.GetValueOrDefault(app.Id, "");
            if (app.Id is "docker" or "dotnet" or "mysql" or "postgresql" or "unity" or "vscode" or "github" or "atlassian" or "qemu" or "chrome" or "chatgpt" or "gnome")
                value = Commands.Output("dpkg-query", ["-W", "-f=${Version}", value], false);
            Console.WriteLine($"  {app.Label,-26} {(value.Length == 0 ? "no detectada" : value)}");
        }
        Log("Instalación terminada");
        if (Has("docker") || Has("qemu") || Has("copyous") || Has("dash"))
            Console.WriteLine("- Cierra sesión para aplicar los cambios de grupos y cargar las extensiones de GNOME.");
        if (Has("vscode")) Console.WriteLine("- Inicia sesión en VS Code para sincronizar la configuración.");
        if (Has("unity")) Console.WriteLine("- Instala el editor desde Unity Hub.");
        if (Has("postgresql")) Console.WriteLine("- Abre PostgreSQL con sudo -u postgres psql.");
    }

    private static void Download(string url, string path) => Commands.Run("curl", "-fsSL", "-o", path, "--", url);

    private static void InTemporaryDirectory(Action<string> action, bool shared = false)
    {
        var directory = Directory.CreateTempSubdirectory("ubuntu-setup-");
        try
        {
            if (shared) Commands.Run("chmod", "0755", directory.FullName);
            action(directory.FullName);
        }
        finally
        {
            directory.Delete(recursive: true);
        }
    }
}
