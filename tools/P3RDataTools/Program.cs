using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Versions;
using CUE4Parse.UE4.Objects.Core.Misc;
using CUE4Parse.Encryption.Aes;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using P3RDataTools;

if (args.Length < 2)
{
    Console.WriteLine("P3R Data Tools - Read/Write UE4 DataTables without GUI");
    Console.WriteLine();
    Console.WriteLine("READ commands:");
    Console.WriteLine("  read    <virtualPath> [outputJson]    Export DataTable to JSON");
    Console.WriteLine("  batch   <pathFilter> <outputDir>      Batch export to JSON");
    Console.WriteLine();
    Console.WriteLine("WRITE commands:");
    Console.WriteLine("  modify  <virtualPath> <jsonFile> <outDir>   Apply JSON changes → new .uasset");
    Console.WriteLine("  quick   <virtualPath> <rowProperty> <value> <outDir>  Quick single-value modify");
    Console.WriteLine();
    Console.WriteLine("TEMPLATE commands:");
    Console.WriteLine("  create-template <virtualPath> <outDir>    Create traditional-format .uasset+.uexp template from IoStore");
    Console.WriteLine();
    Console.WriteLine("Examples:");
    Console.WriteLine("  P3RDataTools read \"P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset\" skills.json");
    Console.WriteLine("  P3RDataTools modify \"P3R/Content/.../DatSkillNormalDataAsset.uasset\" modified.json .\\mod\\");
    Console.WriteLine("  P3RDataTools quick \"P3R/Content/.../DatSkillNormalDataAsset.uasset\" \"Data[0].Power\" 999 .\\mod\\");
    Console.WriteLine("  P3RDataTools create-template \"P3R/Content/.../DatSkillNormalDataAsset.uasset\" .\\templates\\");
    return 1;
}

var command = args[0].ToLower();
var input = args[1];
var gameDir = @"C:\Users\91698\Code\P3R_Modding\Paks";
var aesKey = "0x92BADFE2921B376069D3DE8541696D230BA06B5E4320084DD34A26D117D2FFEE";

try
{
    switch (command)
    {
        case "read":
        case "batch":
            {
                var provider = CreateProvider(gameDir, aesKey);
                if (command == "read")
                    ReadToJson(provider, input, args.Length > 2 ? args[2] : null);
                else
                    BatchExport(provider, input, args.Length > 2 ? args[2] : "./output");
                break;
            }
        case "modify":
        case "quick":
            {
                var provider = CreateProvider(gameDir, aesKey);
                var outDir = command == "modify" ? (args.Length > 3 ? args[3] : "./mod") : (args.Length > 4 ? args[4] : "./mod");
                ModifyAsset(provider, input, args[2], args.Length > 3 ? args[3] : null, outDir, command == "quick");
                break;
            }
        case "create-template":
            {
                var provider = CreateProvider(gameDir, aesKey);
                var outDir = args.Length > 2 ? args[2] : "./templates";
                CreateTemplate(provider, input, outDir);
                break;
            }
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

DefaultFileProvider CreateProvider(string dir, string key)
{
    var p = new DefaultFileProvider(dir, SearchOption.TopDirectoryOnly, true, new VersionContainer(EGame.GAME_UE4_27));
    p.Initialize();
    p.SubmitKey(new FGuid(), new FAesKey(key));
    Console.Error.WriteLine($"Provider ready, {p.Files.Count} files mounted");
    return p;
}

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
            if (ok % 10 == 0) Console.Error.WriteLine($"  {ok}/{matching.Count}");
        }
        catch (Exception ex) { Console.Error.WriteLine($"  FAIL: {name} - {ex.Message}"); }
    }
    Console.WriteLine($"Done. {ok} OK. Output: {outDir}");
}

void ModifyAsset(DefaultFileProvider provider, string virtualPath, string jsonOrProperty, string? value, string outDir, bool isQuick)
{
    Directory.CreateDirectory(outDir);

    // Step 1: Read the original asset to get the schema
    Console.Error.WriteLine($"Reading original: {virtualPath}");
    var exports = provider.LoadAllObjects(virtualPath).ToList();
    if (!exports.Any()) { Console.Error.WriteLine("No exports found"); return; }

    var originalObj = exports[0];
    var typeName = originalObj.Name;
    var exportType = originalObj.ExportType;

    // Serialize original to JSON
    var originalJson = JToken.Parse(JsonConvert.SerializeObject(originalObj, new JsonSerializerSettings
    {
        ReferenceLoopHandling = ReferenceLoopHandling.Ignore, MaxDepth = 8,
        Error = (_, e) => e.ErrorContext.Handled = true
    }));
    var originalPath = Path.Combine(outDir, typeName + "_original.json");
    File.WriteAllText(originalPath, originalJson.ToString(Formatting.Indented));
    Console.Error.WriteLine($"Original schema saved: {originalPath}");

    // Step 2: Read or apply modifications
    JToken modifiedData;
    if (isQuick)
    {
        // Quick mode: jsonOrProperty = "Data[0].Power", value = "999"
        modifiedData = originalJson.DeepClone();
        var token = modifiedData.SelectToken(jsonOrProperty);
        if (token == null) { Console.Error.WriteLine($"Path not found: {jsonOrProperty}"); return; }
        if (double.TryParse(value, out var d)) token.Replace(d);
        else if (int.TryParse(value, out var i)) token.Replace(i);
        else token.Replace(value);
        Console.Error.WriteLine($"Modified {jsonOrProperty}: {value}");
    }
    else
    {
        // Modify mode: load modified JSON from file
        if (!File.Exists(jsonOrProperty)) { Console.Error.WriteLine($"JSON file not found: {jsonOrProperty}"); return; }
        modifiedData = JToken.Parse(File.ReadAllText(jsonOrProperty));
    }

    // Step 3: Use UAssetAPI to create new .uasset from modified data
    try
    {
        CreateUassetFromJson(modifiedData, exportType, outDir, typeName, virtualPath);
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"UAssetAPI write failed: {ex.Message}");
        Console.Error.WriteLine("Falling back to JSON-only output (use UAssetGUI fromjson manually)");

        // Fallback: save modified JSON
        var modPath = Path.Combine(outDir, typeName + "_modified.json");
        File.WriteAllText(modPath, modifiedData.ToString(Formatting.Indented));
        Console.Error.WriteLine($"Modified JSON saved: {modPath}");

        // Generate manifest entry hint
        var gamePath = virtualPath.StartsWith("P3R/") ? virtualPath["P3R/".Length..] : virtualPath;
        var manifestHint = $"\"{typeName}.uasset\" \"../../../{virtualPath}\"";
        if (File.Exists(Path.Combine(outDir, typeName + ".uexp")))
            manifestHint += $"\n\"{typeName}.uexp\" \"../../../{virtualPath.Replace(".uasset", ".uexp")}\"";
        Console.Error.WriteLine($"Manifest hint: {manifestHint}");
    }
}

void CreateUassetFromJson(JToken jsonData, string exportType, string outDir, string assetName, string originalVPath)
{
    // Save modified JSON, schema, and manifest for manual/scripted .uasset creation
    var modPath = Path.Combine(outDir, assetName + "_modified.json");
    File.WriteAllText(modPath, jsonData.ToString(Formatting.Indented));

    var manifestPath = Path.Combine(outDir, "manifest.txt");
    var mountPath = $"../../../{originalVPath}";
    var manifestContent = $"\"{assetName}.uasset\" \"{mountPath}\"\n" +
                          $"\"{assetName}.uexp\" \"{mountPath.Replace(".uasset", ".uexp")}\"\n";
    File.WriteAllText(manifestPath, manifestContent);

    Console.WriteLine($"Modified JSON: {modPath}");
    Console.WriteLine($"Manifest: {manifestPath}");
    Console.WriteLine($"Mount path: {mountPath}");
    Console.WriteLine();
    Console.WriteLine("NOTE: .uasset+.uexp creation requires a traditional UE package template.");
    Console.WriteLine("P3R uses IoStore format exclusively for game DataTables.");
    Console.WriteLine("To create the .uasset: use FModel GUI to re-export the original asset");
    Console.WriteLine("in traditional format, then use UAssetGUI to merge changes.");
}

void CreateTemplate(DefaultFileProvider provider, string virtualPath, string outDir)
{
    Directory.CreateDirectory(outDir);

    Console.Error.WriteLine($"Reading IoStore DataTable: {virtualPath}");
    var exports = provider.LoadAllObjects(virtualPath).ToList();
    if (!exports.Any())
    {
        Console.Error.WriteLine("No exports found");
        return;
    }

    var originalObj = exports[0];
    var assetName = originalObj.Name;

    // Serialize the full object to JSON (preserves all type info)
    var json = JToken.Parse(JsonConvert.SerializeObject(originalObj, new JsonSerializerSettings
    {
        ReferenceLoopHandling = ReferenceLoopHandling.Ignore,
        MaxDepth = 8,
        Error = (_, e) => e.ErrorContext.Handled = true
    }));

    // Save the JSON for reference
    var jsonPath = Path.Combine(outDir, $"{assetName}_template.json");
    File.WriteAllText(jsonPath, json.ToString(Formatting.Indented));
    Console.Error.WriteLine($"JSON saved: {jsonPath}");

    // Create traditional format .uasset+.uexp from JSON
    try
    {
        TemplateCreator.CreateFromJson(json, outDir, assetName);
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"Template creation failed: {ex}");
        Console.Error.WriteLine("Falling back to JSON-only output.");
        Console.Error.WriteLine("You can manually convert using UAssetGUI.");
    }
}