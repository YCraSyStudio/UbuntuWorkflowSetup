using System.Diagnostics;
using System.Reflection;

const string resourcePrefix = "installer/";
const string entryPoint = "main.sh";

DirectoryInfo? staging = null;
try
{
    staging = Directory.CreateTempSubdirectory("ubuntu-workflow-setup-");
    var assembly = Assembly.GetExecutingAssembly();

    foreach (var name in assembly.GetManifestResourceNames())
    {
        if (!name.StartsWith(resourcePrefix, StringComparison.Ordinal))
            continue;

        var destination = Path.Combine(staging.FullName, name[resourcePrefix.Length..]);
        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
        using var resource = assembly.GetManifestResourceStream(name)
            ?? throw new InvalidOperationException($"No se encontró el recurso {name}.");
        using var file = File.Create(destination);
        resource.CopyTo(file);
    }

    var command = new ProcessStartInfo("/bin/bash");
    command.ArgumentList.Add(Path.Combine(staging.FullName, entryPoint));
    foreach (var argument in args)
        command.ArgumentList.Add(argument);

    // The terminal also delivers Ctrl+C to Bash. Keep the launcher alive for cleanup.
    Console.CancelKeyPress += (_, eventArgs) => eventArgs.Cancel = true;
    using var installer = Process.Start(command)
        ?? throw new InvalidOperationException("No se pudo iniciar el instalador.");
    installer.WaitForExit();
    return installer.ExitCode;
}
catch (Exception exception) when (exception is IOException or UnauthorizedAccessException
    or System.ComponentModel.Win32Exception or InvalidOperationException)
{
    Console.Error.WriteLine($"No se pudo ejecutar el instalador. {exception.Message}");
    return 1;
}
finally
{
    if (staging is not null)
    {
        try
        {
            staging.Delete(recursive: true);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            Console.Error.WriteLine($"No se pudo limpiar {staging.FullName}. {exception.Message}");
        }
    }
}
