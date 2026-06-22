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
    Console.WriteLine("  create  <jsonFile> <outDir>                JSON → .uasset+.uexp + manifest");
    Console.WriteLine("  modify  <virtualPath> <jsonFile> <outDir>   Read IoStore, apply changes → .uasset+.uexp");
    Console.WriteLine("  quick   <virtualPath> <rowProperty> <value> <outDir>  Quick single-value modify");
    Console.WriteLine();
    Console.WriteLine("TEMPLATE commands:");
    Console.WriteLine("  create-template <virtualPath> <outDir>    Create traditional-format .uasset+.uexp template from IoStore");
    Console.WriteLine();
    Console.WriteLine("Examples:");
    Console.WriteLine("  P3RDataTools read \"P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset\" skills.json");
    Console.WriteLine("  P3RDataTools create skills_modified.json .\\mod\\");
    Console.WriteLine("  P3RDataTools modify \"P3R/Content/.../DatSkillNormalDataAsset.uasset\" modified.json .\\mod\\");
    Console.WriteLine("  P3RDataTools quick \"P3R/Content/.../DatSkillNormalDataAsset.uasset\" \"Data[0].Power\" 999 .\\mod\\");
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
        case "create":
            {
                // create <jsonFile> <outDir>
                // Takes a modified JSON file and generates .uasset+.uexp
                var jsonPath = input;
                var outDir = args.Length > 2 ? args[2] : "./mod";
                CreateFromJsonFile(jsonPath, outDir);
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
    Console.Error.WriteLine($"FATAL: {ex.Message}");
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
    try
    {
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
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: Asset not found or failed to load: {virtualPath}");
        Console.Error.WriteLine($"  Reason: {ex.GetBaseException().Message}");
        Console.Error.WriteLine($"  Hint: Check the virtual path. Example valid path:");
        Console.Error.WriteLine($"    P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset");
        throw;
    }
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
    List<CUE4Parse.UE4.Assets.Exports.UObject> exports;
    try
    {
        exports = provider.LoadAllObjects(virtualPath).ToList();
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"ERROR: Asset not found or failed to load: {virtualPath}");
        Console.Error.WriteLine($"  Reason: {ex.GetBaseException().Message}");
        Console.Error.WriteLine($"  Hint: Check the virtual path. Example valid path:");
        Console.Error.WriteLine($"    P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset");
        return;
    }

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
    // Use TemplateCreator to generate traditional-format .uasset+.uexp from JSON data
    TemplateCreator.CreateFromJson(jsonData, outDir, assetName);

    // Generate manifest.txt for UnrealPak with absolute source paths
    // UnrealPak resolves source file paths relative to its EXE directory,
    // so we use absolute paths to ensure it always finds the files.
    var manifestPath = Path.Combine(outDir, "manifest.txt");
    var absUasset = Path.GetFullPath(Path.Combine(outDir, $"{assetName}.uasset"));
    var absUexp = Path.GetFullPath(Path.Combine(outDir, $"{assetName}.uexp"));
    var mountPath = $"../../../{originalVPath}";
    var manifestContent = $"\"{absUasset}\" \"{mountPath}\"\n" +
                          $"\"{absUexp}\" \"{mountPath.Replace(".uasset", ".uexp")}\"\n";
    File.WriteAllText(manifestPath, manifestContent);

    Console.WriteLine($"Manifest: {manifestPath}");
    Console.WriteLine($"Mount point: {mountPath}");
    Console.WriteLine();
    Console.WriteLine("Next: pack with UnrealPak");
    Console.WriteLine($"  cd {Path.GetFullPath(outDir)}");
    Console.WriteLine($"  UnrealPak.exe \"MyMod_P.pak\" -Create=\"{manifestPath}\" -compress");
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

void CreateFromJsonFile(string jsonPath, string outDir)
{
    if (!File.Exists(jsonPath))
    {
        Console.Error.WriteLine($"JSON file not found: {jsonPath}");
        return;
    }

    Directory.CreateDirectory(outDir);

    var jsonData = JToken.Parse(File.ReadAllText(jsonPath));
    var assetName = jsonData["Name"]?.Value<string>()
                    ?? Path.GetFileNameWithoutExtension(jsonPath);

    Console.Error.WriteLine($"Creating .uasset+.uexp from: {jsonPath}");
    Console.Error.WriteLine($"Asset: {assetName}, Type: {jsonData["Type"]}");

    try
    {
        TemplateCreator.CreateFromJson(jsonData, outDir, assetName);

        // Generate manifest.txt with absolute source paths
        // UnrealPak resolves source file paths relative to its EXE directory
        var manifestPath = Path.Combine(outDir, "manifest.txt");
        var absUasset = Path.GetFullPath(Path.Combine(outDir, $"{assetName}.uasset"));
        var absUexp = Path.GetFullPath(Path.Combine(outDir, $"{assetName}.uexp"));
        var vpath = GuessVirtualPath(assetName);
        var mountPath = $"../../../{vpath}";
        var manifestContent = $"\"{absUasset}\" \"{mountPath}\"\n" +
                              $"\"{absUexp}\" \"{mountPath.Replace(".uasset", ".uexp")}\"\n";
        File.WriteAllText(manifestPath, manifestContent);
        Console.WriteLine($"Manifest: {manifestPath}");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"Create failed: {ex}");
    }
}

string GuessVirtualPath(string assetName)
{
    // Map common asset names to their virtual paths
    var lower = assetName.ToLower();
    if (lower.Contains("skillnormal")) return "P3R/Content/Xrd777/Battle/Tables/DatSkillNormalDataAsset.uasset";
    if (lower.Contains("skilldata")) return "P3R/Content/Xrd777/Battle/Tables/DatSkillDataAsset.uasset";
    if (lower.Contains("personagrowth")) return "P3R/Content/Xrd777/Battle/Tables/DatPersonaGrowthDataAsset.uasset";
    if (lower.Contains("personaaffinity")) return "P3R/Content/Xrd777/Battle/Tables/DatPersonaAffinityDataAsset.uasset";
    if (lower.Contains("personadata")) return "P3R/Content/Xrd777/Battle/Tables/DatPersonaDataAsset.uasset";
    if (lower.Contains("enemyaffinity")) return "P3R/Content/Xrd777/Battle/Tables/DatEnemyAffinityDataAsset.uasset";
    if (lower.Contains("enemydata")) return "P3R/Content/Xrd777/Battle/Tables/DatEnemyDataAsset.uasset";
    if (lower.Contains("encounttable")) return "P3R/Content/Xrd777/Battle/Tables/DatEncountTableDataAsset.uasset";
    if (lower.Contains("itemcommon")) return "P3R/Content/Xrd777/UI/Tables/DatItemCommonDataAsset.uasset";
    if (lower.Contains("itemweapon")) return "P3R/Content/Xrd777/UI/Tables/DatItemWeaponDataAsset.uasset";
    if (lower.Contains("itemarmor")) return "P3R/Content/Xrd777/UI/Tables/DatItemArmorDataAsset.uasset";
    if (lower.Contains("itemaccs")) return "P3R/Content/Xrd777/UI/Tables/DatItemAccsDataAsset.uasset";
    if (lower.Contains("itemskillcard")) return "P3R/Content/Xrd777/UI/Tables/DatItemSkillcardDataAsset.uasset";
    if (lower.Contains("itemmaterial")) return "P3R/Content/Xrd777/UI/Tables/DatItemMaterialDataAsset.uasset";
    if (lower.Contains("itemcostume")) return "P3R/Content/Xrd777/UI/Tables/DatItemCostumeDataAsset.uasset";
    if (lower.Contains("itemshoes")) return "P3R/Content/Xrd777/UI/Tables/DatItemShoesDataAsset.uasset";
    if (lower.Contains("playerlevelup")) return "P3R/Content/Xrd777/Battle/Tables/DatPlayerLevelupDataAsset.uasset";
    if (lower.Contains("playermaxhpsp")) return "P3R/Content/Xrd777/Battle/Tables/DatPlayerMaxHPSPDataAsset.uasset";
    return $"P3R/Content/Xrd777/{assetName}.uasset";
}