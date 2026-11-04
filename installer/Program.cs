using System.ComponentModel;
using System.Diagnostics;

try
{
    new Installer().Run();
    return 0;
}
catch (OperationCanceledException)
{
    return 130;
}
catch (Exception exception) when (exception is IOException or InvalidOperationException
    or UnauthorizedAccessException or Win32Exception or System.Text.Json.JsonException)
{
    Console.Error.WriteLine($"Error de instalación: {exception.Message}");
    return 1;
}

internal sealed record App(string Id, string Label, string? Parent = null);

internal static class Selector
{
    internal static readonly App[] Apps =
    [
        new("docker", "Docker"), new("dotnet", ".NET SDK"), new("mysql", "MySQL"),
        new("postgresql", "PostgreSQL"), new("unity", "Unity Hub"), new("vscode", "Visual Studio Code"),
        new("dbeaver", "DBeaver"), new("bruno", "Bruno"), new("node", "Node.js"),
        new("npm", "npm", "node"), new("angular", "Angular CLI", "node"),
        new("ncu", "npm-check-updates", "node"), new("chatgpt", "ChatGPT"),
        new("github", "GitHub CLI"), new("atlassian", "Atlassian CLI"),
        new("qemu", "QEMU/KVM (Virtual Machine Manager)"), new("yed", "yEd"),
        new("chromium", "Chromium"), new("chrome", "Google Chrome"),
        new("telegram", "Telegram Desktop"), new("gnome", "GNOME Extension Manager"),
        new("copyous", "Copyous", "gnome"), new("dash", "Dash to Panel", "gnome")
    ];

    internal static HashSet<string> Read()
    {
        var selected = Apps.Select(app => app.Id).ToHashSet();
        if (Console.IsInputRedirected || Console.IsOutputRedirected)
        {
            Console.WriteLine("Entrada no interactiva: se instalarán todas las aplicaciones compatibles.");
            return selected;
        }

        var index = 0;
        Console.Write("\u001b[?1049h\u001b[?25l");
        try
        {
            while (true)
            {
                var rows = Math.Max(1, Console.WindowHeight - 3);
                var start = Math.Max(0, index - rows + 1);
                Console.Write("\u001b[2J\u001b[H");
                Console.WriteLine("Selecciona las aplicaciones");
                for (var i = start; i < Math.Min(start + rows, Apps.Length); i++)
                {
                    var app = Apps[i];
                    Console.WriteLine($"{(i == index ? ">" : " ")} [{(selected.Contains(app.Id) ? "x" : " ")}] {(app.Parent is null ? "" : "  ")}{app.Label}");
                }
                Console.WriteLine("↑/↓ mover · Espacio seleccionar · T todo · N nada · Enter continuar · Esc salir");

                switch (Console.ReadKey(intercept: true).Key)
                {
                    case ConsoleKey.UpArrow: index = (index + Apps.Length - 1) % Apps.Length; break;
                    case ConsoleKey.DownArrow: index = (index + 1) % Apps.Length; break;
                    case ConsoleKey.T: selected.UnionWith(Apps.Select(app => app.Id)); break;
                    case ConsoleKey.N: selected.Clear(); break;
                    case ConsoleKey.Spacebar:
                        var current = Apps[index];
                        if (selected.Remove(current.Id))
                            selected.ExceptWith(Apps.Where(app => app.Parent == current.Id).Select(app => app.Id));
                        else
                        {
                            selected.Add(current.Id);
                            selected.UnionWith(Apps.Where(app => app.Parent == current.Id).Select(app => app.Id));
                            if (current.Parent is not null)
                                selected.Add(current.Parent);
                        }
                        break;
                    case ConsoleKey.Enter: return selected;
                    case ConsoleKey.Escape: throw new OperationCanceledException();
                }
            }
        }
        finally
        {
            Console.Write("\u001b[?25h\u001b[?1049l");
        }
    }
}

internal static class Commands
{
    internal static void Run(string file, params string[] args) =>
        Invoke(file, args, capture: false, required: true);

    internal static string Output(string file, string[] args, bool required = true) =>
        Invoke(file, args, capture: true, required);

    internal static void Write(string input, string file, params string[] args) =>
        Invoke(file, args, capture: true, required: true, input);

    private static string Invoke(string file, string[] args, bool capture, bool required, string? input = null)
    {
        var start = new ProcessStartInfo(file)
        {
            RedirectStandardOutput = capture,
            RedirectStandardError = capture,
            RedirectStandardInput = input is not null
        };
        foreach (var arg in args)
            start.ArgumentList.Add(arg);
        start.Environment["DEBIAN_FRONTEND"] = "noninteractive";

        try
        {
            using var process = Process.Start(start) ?? throw new InvalidOperationException($"No se pudo iniciar {file}.");
            var output = capture ? process.StandardOutput.ReadToEndAsync() : Task.FromResult("");
            var error = capture ? process.StandardError.ReadToEndAsync() : Task.FromResult("");
            if (input is not null)
            {
                process.StandardInput.Write(input);
                process.StandardInput.Close();
            }

            process.WaitForExit();
            if (process.ExitCode == 0)
                return output.GetAwaiter().GetResult().Trim();
            if (!required)
                return "";
            throw new InvalidOperationException($"{file} {string.Join(' ', args)} terminó con código {process.ExitCode}. {error.GetAwaiter().GetResult().Trim()}");
        }
        catch (Win32Exception) when (!required)
        {
            return "";
        }
    }
}
