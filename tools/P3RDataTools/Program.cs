using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Versions;
using CUE4Parse.UE4.Objects.Core.Misc;
using CUE4Parse.Encryption.Aes;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

if (args.Length < 2)
{
    Console.WriteLine("P3R Data Tools - CUE4Parse 1.1.1");
    Console.WriteLine("  read    <virtualPath> [outputJson]");
    Console.WriteLine("  batch   <pathFilter> <outputDir>");
    Console.WriteLine("Example:");
    Console.WriteLine("  P3RDataTools read \"P3R/Content/Xrd777/Battle/Tables/DatSkillDataAsset.uasset\" skills.json");
    return 1;
}

var command = args[0].ToLower();
var input = args[1];
var gameDir = @"C:\Users\91698\Code\P3R_Modding\Paks";
var aesKey = "0x92BADFE2921B376069D3DE8541696D230BA06B5E4320084DD34A26D117D2FFEE";

try
{
    var provider = new DefaultFileProvider(gameDir, SearchOption.TopDirectoryOnly, true, new VersionContainer(EGame.GAME_UE4_27));
    provider.Initialize();
    provider.SubmitKey(new FGuid(), new FAesKey(aesKey));

    Console.Error.WriteLine("Provider initialized successfully");

    switch (command)
    {
        case "read":
            ReadToJson(provider, input, args.Length > 2 ? args[2] : null);
            break;
        case "batch":
            BatchExport(provider, input, args.Length > 2 ? args[2] : "./output");
            break;
        default:
            Console.WriteLine($"Unknown command: {command}");
            return 1;
    }
}
catch (Exception ex)
{
    Console.Error.WriteLine($"FATAL: {ex}");
    return 1;
}

return 0;

void ReadToJson(DefaultFileProvider provider, string virtualPath, string? outputPath)
{
    Console.Error.WriteLine($"Loading: {virtualPath}");
    var exports = provider.LoadAllObjects(virtualPath);
    var result = new JArray();
    foreach (var obj in exports)
    {
        try
        {
            var json = JsonConvert.SerializeObject(obj, new JsonSerializerSettings
            {
                ReferenceLoopHandling = ReferenceLoopHandling.Ignore, MaxDepth = 8,
                Error = (_, e) => e.ErrorContext.Handled = true
            });
            result.Add(JToken.Parse(json));
        }
        catch (Exception ex) { result.Add(new JObject { ["error"] = ex.Message, ["name"] = obj.Name }); }
    }
    var final = result.Count == 1 ? result[0].ToString(Formatting.Indented) : result.ToString(Formatting.Indented);
    if (outputPath != null) { File.WriteAllText(outputPath, final); Console.WriteLine($"Saved: {outputPath} ({final.Length} chars)"); }
    else Console.WriteLine(final);
}

void BatchExport(DefaultFileProvider provider, string filter, string outDir)
{
    Directory.CreateDirectory(outDir);
    // Access Files using dynamic typing to handle different CUE4Parse versions
    dynamic filesDict = provider.Files;
    var matching = new List<string>();
    foreach (var kvp in filesDict)
    {
        string key = kvp.Key;
        if (key.Contains(filter, StringComparison.OrdinalIgnoreCase) && key.EndsWith(".uasset"))
            matching.Add(key);
    }

    Console.WriteLine($"Found {matching.Count} files matching '{filter}'");
    int ok = 0;
    foreach (var p in matching)
    {
        var name = Path.GetFileNameWithoutExtension(p);
        try
        {
            var exports = provider.LoadAllObjects(p);
            var arr = new JArray();
            foreach (var o in exports)
                arr.Add(JToken.Parse(JsonConvert.SerializeObject(o,
                    new JsonSerializerSettings { ReferenceLoopHandling = ReferenceLoopHandling.Ignore, MaxDepth = 8,
                    Error = (_, e) => e.ErrorContext.Handled = true })));
            File.WriteAllText(Path.Combine(outDir, name + ".json"),
                arr.Count == 1 ? arr[0].ToString(Formatting.Indented) : arr.ToString(Formatting.Indented));
            ok++;
            if (ok % 5 == 0) Console.Error.WriteLine($"  {ok}/{matching.Count}");
        }
        catch (Exception ex) { Console.Error.WriteLine($"  FAIL: {name} - {ex.Message}"); }
    }
    Console.WriteLine($"Done. {ok} OK. Output: {outDir}");
}
