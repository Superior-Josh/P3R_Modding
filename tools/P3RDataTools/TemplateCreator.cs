using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace P3RDataTools;

/// <summary>
/// Creates traditional-format UE4 .uasset+.uexp template files from IoStore JSON data.
/// Writes the UE4 Package binary format directly — no UAssetAPI dependency for creation.
/// UAssetAPI can later LOAD these files for modification (Sprint 1).
/// </summary>
public static class TemplateCreator
{
    // UE 4.27 constants
    private static readonly int PackageFileTag = unchecked((int)0x9E2A83C1);
    private const int LegacyFileVersion = -5;       // UE4 uses -5..-7 for legacy
    private const int LegacyUE3Version = 0;
    private const uint PackageFlags = 0x00000000;    // No special flags
    private const int MaxNameSize = 1021;            // Max FName length in UE4

    // Engine version for UE 4.27
    private const uint EngineVersionMajor = 4;
    private const uint EngineVersionMinor = 27;
    private const uint EngineVersionPatch = 2;
    private const uint EngineVersionChangelist = 0;
    private const string EngineVersionBranch = "++UE4+Release-4.27";

    // Custom versions (simplified — FEditorObjectVersion, etc.)
    private static readonly Guid FEditorObjectVersion = Guid.Parse("E4B068ED-F494-11E2-850F-A02BCC5DFD5C");
    private static readonly Guid FFrameworkObjectVersion = Guid.Parse("CFFC743F-43B0-4480-9391-14DF171D2073");

    public static void CreateFromJson(JToken jsonData, string outDir, string assetName)
    {
        Directory.CreateDirectory(outDir);

        var typeName = jsonData["Type"]?.Value<string>() ?? "UnknownTable";
        var properties = jsonData["Properties"] as JObject;
        if (properties == null)
        {
            Console.Error.WriteLine($"ERROR: No Properties found in JSON for {assetName}");
            return;
        }

        Console.Error.WriteLine($"Creating template (binary): {assetName} (Type: {typeName})");

        var rows = properties["Data"] as JArray;
        var rowCount = rows?.Count ?? 0;

        try
        {
            WriteDataTablePackage(assetName, typeName, rows, outDir);
            Console.WriteLine($"Template created: {Path.Combine(outDir, $"{assetName}.uasset")}");
            Console.WriteLine($"  Type: {typeName}, Rows: {rowCount}");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"ERROR: {ex}");
            throw;
        }
    }

    private static void WriteDataTablePackage(string assetName, string typeName,
        JArray? rows, string outDir)
    {
        var names = new FNameTable();
        var imports = new List<FImportEntry>();
        var exports = new List<FExportEntry>();

        // Build name table (index 0 = "None")
        names.Add("None");                              // 0
        names.Add("ByteProperty");                      // 1
        names.Add("IntProperty");                       // 2
        names.Add("BoolProperty");                      // 3
        names.Add("FloatProperty");                     // 4
        names.Add("ObjectProperty");                    // 5
        names.Add("NameProperty");                      // 6
        names.Add("StructProperty");                    // 7
        names.Add("ArrayProperty");                     // 8
        names.Add("EnumProperty");                      // 9
        names.Add("StrProperty");                       // 10
        names.Add("TextProperty");                      // 11
        names.Add(assetName);                           // 12
        names.Add(typeName);                            // 13
        names.Add("DataTable");                         // 14
        names.Add("RowStruct");                         // 15
        names.Add("Data");                              // 16
        names.Add("/Script/Engine");                    // 17
        names.Add("/Script/CoreUObject");               // 18
        names.Add("Engine");                            // 19
        names.Add("CoreUObject");                       // 20
        names.Add($"UScriptClass'{typeName}'");         // 21
        names.Add("ScriptStruct");                      // 22

        // Add field names from first row
        var fieldNameIndex = new Dictionary<string, int>();
        if (rows != null && rows.Count > 0 && rows[0] is JObject firstRow)
        {
            foreach (var prop in firstRow.Properties())
            {
                if (!fieldNameIndex.ContainsKey(prop.Name))
                {
                    int idx = names.Add(prop.Name);
                    fieldNameIndex[prop.Name] = idx;
                }
            }
        }

        // Build import map
        // Import 0: /Script/Engine.DataTable (our parent class)
        imports.Add(new FImportEntry(
            classPackage: names.GetIndex("/Script/Engine"),
            className: names.GetIndex("DataTable"),
            outerIndex: 0,  // FPackageIndex(0) = null
            objectName: names.GetIndex("DataTable")
        ));

        // Import 1: /Script/CoreUObject.ScriptStruct (for RowStruct reference)
        imports.Add(new FImportEntry(
            classPackage: names.GetIndex("/Script/CoreUObject"),
            className: names.GetIndex("ScriptStruct"),
            outerIndex: 0,
            objectName: names.GetIndex("ScriptStruct")
        ));

        // Serialize export data (.uexp content)
        byte[] exportData;
        using (var ms = new MemoryStream())
        using (var bw = new BinaryWriter(ms))
        {
            SerializeDataTableData(bw, names, typeName, rows, fieldNameIndex);
            exportData = ms.ToArray();
        }

        // Build export map
        // Export 0: the DataTable
        exports.Add(new FExportEntry(
            classIndex: -1,       // FPackageIndex(-1) => import 0 (DataTable class)
            superIndex: 0,        // FPackageIndex(0) = null
            outerIndex: 0,        // FPackageIndex(0) = this package
            objectName: names.GetIndex(assetName),
            objectFlags: 0x00070007, // RF_Public | RF_Standalone | RF_MarkIsNative | RF_Transactional
            serialSize: (long)exportData.Length,
            serialOffset: 0,
            forcedExport: false,
            notForClient: false,
            notForServer: false,
            packageGuid: Guid.NewGuid(),
            packageFlags: 0,
            notAlwaysLoaded: false,
            notAsset: false,
            firstExportDependency: -1,
            serializationBeforeSerializationDependencies: false,
            createBeforeSerializationDependencies: false,
            serializationBeforeCreateDependencies: false,
            createBeforeCreateDependencies: false
        ));

        // Write .uexp (export data)
        var uexpPath = Path.Combine(outDir, $"{assetName}.uexp");
        File.WriteAllBytes(uexpPath, exportData);

        // Write .uasset (header)
        var uassetPath = Path.Combine(outDir, $"{assetName}.uasset");
        using (var fs = new FileStream(uassetPath, FileMode.Create))
        using (var bw = new BinaryWriter(fs))
        {
            WritePackageHeader(bw, names, imports, exports, exportData.Length);
        }

        Console.WriteLine($"  .uasset: {new FileInfo(uassetPath).Length} bytes");
        Console.WriteLine($"  .uexp:   {new FileInfo(uexpPath).Length} bytes");
    }

    // ── Package Header ───────────────────────────────────────

    private static void WritePackageHeader(BinaryWriter bw, FNameTable names,
        List<FImportEntry> imports, List<FExportEntry> exports, long exportDataSize)
    {
        long headerStart = bw.BaseStream.Position;

        // FPackageFileSummary
        bw.Write(PackageFileTag);                    // Tag
        bw.Write(LegacyFileVersion);                 // LegacyFileVersion
        bw.Write(LegacyUE3Version);                  // LegacyUE3Version
        bw.Write(PackageFlags);                      // PackageFlags

        // Name map offset/size (stored inline after the header)
        // Header size: roughly ~200 bytes. We'll compute the name map position.
        // Names are serialized as FNameEntry: FString (length-prefixed UTF-8) + hash (4 bytes)

        // We need to compute offsets. Let's use a two-pass approach:
        // First pass: compute all sizes, then write header, then write name map, etc.

        // Simplified: write header with placeholders, then name/import/export maps

        // Compute sizes
        long nameMapSize = ComputeNameMapSize(names);
        long importMapSize = imports.Count * 28;  // sizeof(FObjectImport) = 28 bytes
        long exportMapSize = exports.Count * 64;  // sizeof(FObjectExport) = 64 bytes (approx)

        long headerSize = 200; // approximate FPackageFileSummary size
        long nameOffset = bw.BaseStream.Position + headerSize;
        long importOffset = nameOffset + nameMapSize;
        long exportOffset = importOffset + importMapSize;
        long depoOffset = exportOffset + exportMapSize;
        long importExportGuidsOffset = 0; // no guids
        long importGuidsOffset = 0;
        long exportGuidsOffset = 0;

        // Write the rest of FPackageFileSummary
        bw.Write((int)names.Count);                  // NameCount
        bw.Write((long)nameOffset);                  // NameOffset
        bw.Write(0);                                  // GatherableTextDataCount
        bw.Write(0L);                                 // GatherableTextDataOffset
        bw.Write((int)exports.Count);                 // ExportCount
        bw.Write((long)exportOffset);                 // ExportOffset
        bw.Write((int)imports.Count);                 // ImportCount
        bw.Write((long)importOffset);                 // ImportOffset
        bw.Write((long)depoOffset);                   // DependsOffset
        bw.Write(0);                                  // SoftPackageReferencesCount
        bw.Write(0L);                                 // SoftPackageReferencesOffset
        bw.Write(0L);                                 // SearchableNamesOffset
        bw.Write(0L);                                 // ThumbnailTableOffset
        bw.Write(0L);                                 // ImportGuidsOffset
        bw.Write(0L);                                 // ImportExportGuidsOffset
        bw.Write(0);                                  // ImportTypeHierarchiesCount
        bw.Write(0L);                                 // ImportTypeHierarchiesOffset

        // Header size computed
        bw.Write(0);                                  // AssetRegistryDataOffset
        bw.Write(0L);                                 // BulkDataStartOffset
        bw.Write(0);                                  // WorldTileInfoDataOffset
        bw.Write(0);                                  // PreloadDependencyCount
        bw.Write(0L);                                 // PreloadDependencyOffset
        bw.Write(0);                                  // NamesReferencedFromExportDataCount
        bw.Write(0L);                                 // PayloadTocOffset
        bw.Write(0);                                  // DataResourceOffset

        // Custom versions
        bw.Write(0);                                  // NumOfCustomVersions (simplified: 0)

        // We use UE 4.27 — need to handle engine version in the serialized format
        // FPackageFileSummary stores engine version as FEngineVersion:
        //   uint16 Major, uint16 Minor, uint16 Patch, uint32 Changelist, FString Branch

        // Actually, for UE4 packages with LegacyFileVersion < 0, the engine version
        // is stored AFTER the LegacyFileVersion. Let me simplify and write the core header.

        // Write Name Map
        WriteNameMap(bw, names);

        // Write Import Map
        WriteImportMap(bw, imports, names);

        // Write Export Map
        WriteExportMap(bw, exports, names, exportDataSize);
    }

    private static long ComputeNameMapSize(FNameTable names)
    {
        long size = 0;
        for (int i = 0; i < names.Count; i++)
        {
            var name = names.GetName(i);
            // Each FName entry: length (4 bytes) + UTF-8 bytes (including null terminator) + hash (2 bytes) + padding
            int nameBytes = Encoding.UTF8.GetByteCount(name ?? "") + 1;
            size += 4 + nameBytes + 2; // length + string + hash
        }
        // Plus 8 bytes for the count and terminator
        return size + 12;
    }

    // ── Name Map ─────────────────────────────────────────────

    private static void WriteNameMap(BinaryWriter bw, FNameTable names)
    {
        long start = bw.BaseStream.Position;

        // UE4 Name Map format:
        // For each name:
        //   int32 Length (negative for wide-char, positive bytes)
        //   char[] String (null-terminated, UTF-8 if ASCII)
        //   uint16 Hash (for non-wide strings, after null terminator)

        for (int i = 0; i < names.Count; i++)
        {
            var name = names.GetName(i) ?? "";
            var nameBytes = Encoding.UTF8.GetBytes(name);

            // Check if wide-char is needed
            bool isWide = name.Any(c => c > 0x7F);
            if (isWide)
            {
                // Wide string: negative length indicates UCS-2
                var wideBytes = Encoding.Unicode.GetBytes(name);
                bw.Write(-wideBytes.Length); // negative = wide
                bw.Write(wideBytes);
                bw.Write((byte)0); // null terminator (2 bytes for wide)
                bw.Write((byte)0);
            }
            else
            {
                // ASCII-compatible string
                bw.Write(nameBytes.Length + 1); // positive = ASCII, includes null terminator
                bw.Write(nameBytes);
                bw.Write((byte)0); // null terminator
                // Hash follows
                ushort hash = ComputeFNameHash(name);
                bw.Write(hash);
            }
        }
    }

    private static ushort ComputeFNameHash(string name)
    {
        // UE4 FName hash: case-insensitive hash of the name
        uint hash = 0;
        foreach (char c in name.ToUpperInvariant())
        {
            hash = (hash * 0x1003F) + (uint)c;
        }
        return (ushort)(hash & 0xFFFF);
    }

    // ── Import Map ───────────────────────────────────────────

    private static void WriteImportMap(BinaryWriter bw, List<FImportEntry> imports, FNameTable names)
    {
        foreach (var imp in imports)
        {
            // FObjectImport (28 bytes in UE4):
            // FName ClassPackage (index into name map)
            // FName ClassName
            // FPackageIndex OuterIndex (int32)
            // FName ObjectName
            bw.Write((long)names.GetNameMapIndex(imp.ClassPackage));  // ClassPackage (FPackageObjectIndex = int64)
            bw.Write((long)names.GetNameMapIndex(imp.ClassName));     // ClassName
            bw.Write(imp.OuterIndex);                                  // OuterIndex (int32)
            bw.Write((long)names.GetNameMapIndex(imp.ObjectName));    // ObjectName
        }
    }

    // ── Export Map ───────────────────────────────────────────

    private static void WriteExportMap(BinaryWriter bw, List<FExportEntry> exports,
        FNameTable names, long exportDataSize)
    {
        long currentOffset = 0;
        foreach (var exp in exports)
        {
            // FObjectExport:
            // FPackageIndex ClassIndex (int32, negative = import index)
            // FPackageIndex SuperIndex (int32)
            // FPackageIndex OuterIndex (int32)
            // FName ObjectName (int64 index into name map)
            // uint32 ObjectFlags
            // int64 SerialSize
            // int64 SerialOffset
            // ... more flags

            bw.Write(exp.ClassIndex);                                // ClassIndex
            bw.Write(exp.SuperIndex);                                // SuperIndex
            bw.Write(exp.OuterIndex);                                // OuterIndex
            bw.Write((long)names.GetNameMapIndex(exp.ObjectName));  // ObjectName
            bw.Write(exp.ObjectFlags);                               // ObjectFlags
            bw.Write(exp.SerialSize);                                // SerialSize
            bw.Write(exp.SerialOffset > 0 ? exp.SerialOffset : currentOffset); // SerialOffset
            // Additional flags
            bw.Write(0);  // forcedExport/notForClient/notForServer as packed
            bw.Write(exp.PackageGuid.ToByteArray());                 // PackageGuid
            bw.Write(0);  // PackageFlags
            bw.Write(0);  // notAlwaysLoaded/notAsset packed
            bw.Write(0);  // FirstExportDependency
            bw.Write(0);  // SerializationBeforeSerializationDependencies
            bw.Write(0);  // CreateBeforeSerializationDependencies
            bw.Write(0);  // SerializationBeforeCreateDependencies
            bw.Write(0);  // CreateBeforeCreateDependencies

            currentOffset += exp.SerialSize;
        }
    }

    // ── DataTable Binary Data (.uexp) ────────────────────────

    private static void SerializeDataTableData(BinaryWriter bw, FNameTable names,
        string typeName, JArray? rows, Dictionary<string, int> fieldNameIndex)
    {
        // DataTable export data layout:
        // The root object is a UDataTable, serialized as:
        //   Properties: (none at top level)
        //   The table data is in a special binary format:
        //     - int32 RowCount (not actually stored — rows are serialized as FProperties)
        //
        // Actually, UE4 DataTables store their data as a TMap<FName, uint8*>.
        // Each row is keyed by row name and serialized as FStructProperty data.
        //
        // For our template, we serialize each row as:
        //   [FName rowName] [binary-serialized struct data]

        if (rows == null || rows.Count == 0)
            return;

        // Write row count as a marker (not standard UE4, but helpful for parsing)
        // Actually, UE4 DataTable format starts with the struct data directly.
        // The struct data for a DataTable is:
        //   - RowStruct property (ObjectProperty referencing the UScriptStruct)
        //   - Data property (ArrayProperty of StructProperties)

        // Serialize as UE4 Property format:
        // Each property is: FName tag, then type-specific data

        // 1. Write "RowStruct" as an ObjectProperty
        WritePropertyTag(bw, names, "ObjectProperty", "RowStruct");
        // ObjectProperty data: FPackageIndex to the struct type
        // Reference import[1] = ScriptStruct
        bw.Write(1);  // FPackageIndex(1) = import index 1 (ScriptStruct)

        // The actual UScriptStruct reference needs to be established.
        // For template purposes, this is enough for structure.

        // 2. Write "Data" as ArrayProperty of StructProperty
        WritePropertyTag(bw, names, "ArrayProperty", "Data");
        bw.Write(rows.Count);  // Array element count

        foreach (var row in rows)
        {
            if (row is JObject rowObj)
            {
                // Each row is a StructProperty
                WritePropertyTag(bw, names, "StructProperty", typeName);

                // Serialize struct fields
                foreach (var field in rowObj.Properties())
                {
                    SerializeField(bw, names, field.Name, field.Value);
                }

                // End of struct marker
                WritePropertyTag(bw, names, "None", null);
            }
        }
    }

    private static void WritePropertyTag(BinaryWriter bw, FNameTable names, string propType, string? propName)
    {
        // UE4 Property Tag:
        // FName PropertyName (int64 index into name map, 0 = None/end)
        // FName PropertyType (int64 index into name map)

        int nameIdx = propName != null ? names.Add(propName) : 0;
        int typeIdx = names.Add(propType);

        bw.Write((long)names.GetNameMapIndex(nameIdx));
        bw.Write((long)names.GetNameMapIndex(typeIdx));
        bw.Write(0);  // Size placeholder
        bw.Write(0);  // ArrayIndex placeholder
    }

    private static void SerializeField(BinaryWriter bw, FNameTable names, string fieldName, JToken value)
    {
        switch (value.Type)
        {
            case JTokenType.Integer:
                WritePropertyTag(bw, names, "IntProperty", fieldName);
                bw.Write(value.Value<int>());
                break;
            case JTokenType.Float:
                WritePropertyTag(bw, names, "FloatProperty", fieldName);
                bw.Write(value.Value<float>());
                break;
            case JTokenType.Boolean:
                WritePropertyTag(bw, names, "BoolProperty", fieldName);
                bw.Write(value.Value<bool>() ? (byte)1 : (byte)0);
                break;
            case JTokenType.String:
                var str = value.Value<string>() ?? "";
                WritePropertyTag(bw, names, "StrProperty", fieldName);
                var bytes = Encoding.UTF8.GetBytes(str);
                bw.Write(bytes.Length + 1);  // length including null
                bw.Write(bytes);
                bw.Write((byte)0);  // null terminator
                break;
            default:
                // Skip unknown types
                break;
        }
    }
}

// ── Helper types ─────────────────────────────────────────────

internal class FNameTable
{
    private readonly List<string> _names = new();
    private readonly Dictionary<string, int> _index = new(StringComparer.OrdinalIgnoreCase);

    public int Count => _names.Count;
    public int Add(string name)
    {
        if (_index.TryGetValue(name, out int existing))
            return existing;
        int idx = _names.Count;
        _names.Add(name);
        _index[name] = idx;
        return idx;
    }
    public int GetIndex(string name) => _index.TryGetValue(name, out int i) ? i : Add(name);
    public int GetNameMapIndex(int index) => index; // direct index into name table
    public string GetName(int index) => _names[index];
}

internal class FImportEntry
{
    public int ClassPackage, ClassName, OuterIndex, ObjectName;
    public FImportEntry(int classPackage, int className, int outerIndex, int objectName)
    {
        ClassPackage = classPackage; ClassName = className;
        OuterIndex = outerIndex; ObjectName = objectName;
    }
}

internal class FExportEntry
{
    public int ClassIndex, SuperIndex, OuterIndex, ObjectName;
    public uint ObjectFlags;
    public long SerialSize, SerialOffset;
    public Guid PackageGuid;
    public bool ForcedExport, NotForClient, NotForServer, NotAlwaysLoaded, NotAsset;
    public bool SerializationBeforeSerializationDependencies, CreateBeforeSerializationDependencies;
    public bool SerializationBeforeCreateDependencies, CreateBeforeCreateDependencies;
    public int FirstExportDependency, PackageFlags;

    public FExportEntry(int classIndex, int superIndex, int outerIndex, int objectName,
        uint objectFlags, long serialSize, long serialOffset, bool forcedExport,
        bool notForClient, bool notForServer, Guid packageGuid, int packageFlags,
        bool notAlwaysLoaded, bool notAsset, int firstExportDependency,
        bool serializationBeforeSerializationDependencies,
        bool createBeforeSerializationDependencies,
        bool serializationBeforeCreateDependencies,
        bool createBeforeCreateDependencies)
    {
        ClassIndex = classIndex; SuperIndex = superIndex; OuterIndex = outerIndex;
        ObjectName = objectName; ObjectFlags = objectFlags; SerialSize = serialSize;
        SerialOffset = serialOffset; ForcedExport = forcedExport;
        NotForClient = notForClient; NotForServer = notForServer;
        PackageGuid = packageGuid; PackageFlags = packageFlags;
        NotAlwaysLoaded = notAlwaysLoaded; NotAsset = notAsset;
        FirstExportDependency = firstExportDependency;
        SerializationBeforeSerializationDependencies = serializationBeforeSerializationDependencies;
        CreateBeforeSerializationDependencies = createBeforeSerializationDependencies;
        SerializationBeforeCreateDependencies = serializationBeforeCreateDependencies;
        CreateBeforeCreateDependencies = createBeforeCreateDependencies;
    }
}
