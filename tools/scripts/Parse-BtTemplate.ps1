# Parse-BtTemplate.ps1 — 010-Editor binary template parser (PowerShell prototype)
#
# Sprint 1.5 T1.5.2 deliverable. Parses the static syntax subset used by godofknife's
# p3re_*.bt templates (no if/while/for/local/FSeek) and emits a JSON field-offset table.
#
# Usage:
#   .\Parse-BtTemplate.ps1 -TemplatePath tools\templates-010\p3re_skillNormal.bt
#   .\Parse-BtTemplate.ps1 -TemplatePath tools\templates-010\p3re_skillNormal.bt -OutputPath schema.json
#
# Output JSON schema:
#   {
#     "templateFile": "p3re_skillNormal.bt",
#     "asset":        "DatSkillNormalDataAsset.uasset",
#     "rootStructName": "fileData",
#     "rowStructName": "skillData",
#     "rowCount":     700,
#     "rowSize":      769,
#     "headerSizeHint": 98,    // from `byte unk[98]` — must be calibrated against real file
#     "fields": [
#       { "name": "use",  "offset": 42,  "size": 2, "type": "ushort" },
#       { "name": "hpn",  "offset": 458, "size": 2, "type": "ushort" },
#       ...
#     ]
#   }
#
# The "fields" array flattens nested structs/unions/bitfields into a single list keyed
# by the field's display name (the right-hand identifier in the typedef). Fields marked
# <hidden=true> in the template (typically property tag padding) are excluded.
#
# Limits / unsupported:
#   - Control flow (if/while/for/Switch/local): the p3re templates don't use any
#   - Variable-length fields (TArray<T>, FString, dynamic strings): not present in p3re
#   - Conditional layout: not present in p3re

param(
    [Parameter(Mandatory=$true)] [string] $TemplatePath,
    [string] $OutputPath,
    [string] $TemplatesDir = "$PSScriptRoot\..\templates-010",
    [switch] $ShowTrace
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------------------
# 1. Type-size resolver
# --------------------------------------------------------------------------------------

# Built-in scalar sizes
$Script:ScalarSizes = @{
    'byte'   = 1; 'ubyte'  = 1; 'uint8' = 1; 'int8' = 1; 'char' = 1; 'uchar' = 1;
    'short'  = 2; 'ushort' = 2; 'uint16'= 2; 'int16'= 2;
    'int'    = 4; 'uint'   = 4; 'int32' = 4; 'uint32'= 4; 'float'= 4; 'u32' = 4;
    'int64'  = 8; 'uint64' = 8; 'double'= 8; 'u64' = 8;
    'Bool'   = 1;
    'wchar_t'= 2;
}

# Enum definitions discovered from #included files (e.g., p3re_enums.bt).
# Maps EnumName -> byte size (from `enum<TYPE>` declarator).
$Script:EnumSizes = @{}

# Struct definitions discovered from typedef struct ... or inline struct definitions.
# Maps StructName -> @{ rawBody = string; size = int (computed lazily); fields = [...] }
$Script:Structs = @{}

# Files already #included (to prevent infinite loop on circular includes).
$Script:SeenIncludes = @{}

# --------------------------------------------------------------------------------------
# 2. Lexing / preprocessing helpers
# --------------------------------------------------------------------------------------

function Remove-Comment {
    param([string] $Text)
    # Remove /* ... */ block comments (greedy across lines)
    $Text = [regex]::Replace($Text, '/\*[\s\S]*?\*/', '')
    # Remove // line comments
    $Text = [regex]::Replace($Text, '//[^\r\n]*', '')
    return $Text
}

function Remove-Annotation {
    # Remove 010-Editor field annotations like <name="X", hidden=true, comment="...">
    # Returns the cleaned text + a hashtable of detected flags per line
    param([string] $Line)
    $annotation = ''
    if ($Line -match '(<[^>]+>)') {
        $annotation = $matches[1]
        $Line = $Line -replace '<[^>]+>', ''
    }
    return @{ line = $Line.Trim(); annotation = $annotation }
}

# --------------------------------------------------------------------------------------
# 3. #include resolver — recursively load enum/struct defs from included files
# --------------------------------------------------------------------------------------

function Resolve-Include {
    param([string] $IncludeName, [string] $CurrentDir)
    $candidate = Join-Path $CurrentDir $IncludeName
    if (-not (Test-Path $candidate)) {
        $candidate = Join-Path $TemplatesDir $IncludeName
    }
    if (-not (Test-Path $candidate)) {
        Write-Warning "Cannot resolve #include `"$IncludeName`""
        return
    }
    $abs = (Resolve-Path $candidate).Path
    if ($Script:SeenIncludes.ContainsKey($abs)) { return }
    $Script:SeenIncludes[$abs] = $true
    if ($ShowTrace) { Write-Host "  Loading include: $abs" -ForegroundColor DarkGray }
    Read-TemplateFile -Path $abs -CollectOnly:$true
}

# --------------------------------------------------------------------------------------
# 4. Enum + struct discovery (collect-only pass for #included files)
# --------------------------------------------------------------------------------------

function Read-TemplateFile {
    param([string] $Path, [switch] $CollectOnly)

    $raw = Get-Content $Path -Raw -Encoding UTF8
    $text = Remove-Comment $raw
    $dir  = Split-Path $Path -Parent

    # Pass 1: resolve includes
    foreach ($m in [regex]::Matches($text, '^\s*#include\s+"([^"]+)"', 'Multiline')) {
        Resolve-Include -IncludeName $m.Groups[1].Value -CurrentDir $dir
    }

    # Pass 2: discover enum definitions
    # Pattern: enum<TYPE>Name { ... };  or  enum<TYPE> Name { ... };
    foreach ($m in [regex]::Matches($text, 'enum\s*<\s*(\w+)\s*>\s*(\w+)\s*\{', 'Singleline')) {
        $base = $m.Groups[1].Value
        $name = $m.Groups[2].Value
        if ($Script:ScalarSizes.ContainsKey($base)) {
            $Script:EnumSizes[$name] = $Script:ScalarSizes[$base]
        } else {
            Write-Warning "Enum '$name' has unknown base type '$base'; defaulting to 1"
            $Script:EnumSizes[$name] = 1
        }
    }

    # Pass 3: discover typedef struct definitions
    # Pattern: typedef struct { ... } Name [<...>] ; OR Name[N] [<...>] ;
    # When the typedef declarator has `[N]`, treat as "intrinsic array typedef" —
    # the typedef's own size is body × N, and the typedef effectively wraps an array
    # (used by p3re_btlTheurgiaBoost.bt: }theurgyBoostData[18];)
    $pos = 0
    while ($pos -lt $text.Length) {
        $m = [regex]::Match($text.Substring($pos), 'typedef\s+struct\s*(?:\w+\s*)?\{', 'Singleline')
        if (-not $m.Success) { break }
        $structStart = $pos + $m.Index + $m.Length - 1  # position of '{'
        $body = Read-BracedBody -Text $text -OpenIndex $structStart
        if ($null -eq $body) { break }
        # After body.closeIndex, expect:  Name [N]? [<...>]? ;
        $afterClose = $body.closeIndex + 1
        $remainder = $text.Substring($afterClose)
        $nm = [regex]::Match($remainder, '^\s*(\w+)\s*(?:\[\s*(\d+)\s*\])?\s*[^;]*;')
        if ($nm.Success) {
            $structName = $nm.Groups[1].Value
            $intrinsicCount = if ($nm.Groups[2].Success) { [int]$nm.Groups[2].Value } else { 1 }
            $Script:Structs[$structName] = @{
                rawBody = $body.body
                size = $null
                fields = $null
                intrinsicCount = $intrinsicCount   # >1 means the typedef wraps an array
            }
            $pos = $afterClose + $nm.Index + $nm.Length
            if ($ShowTrace) {
                $arr = if ($intrinsicCount -gt 1) { "[$intrinsicCount]" } else { '' }
                Write-Host "  Discovered typedef struct: $structName$arr" -ForegroundColor DarkGray
            }
        } else {
            $pos = $afterClose
        }
    }

    if ($CollectOnly) { return }

    # Pass 4 (only for the entry file): find the top-level struct { ... } fileData;
    # In all p3re templates, the root struct is the LAST `struct {` in the file
    # (typedef structs precede it). Walk all matches and pick the last that
    # isn't immediately preceded by "typedef".
    $allStructs = [regex]::Matches($text, '(\btypedef\s+)?\bstruct\s*\{', 'Singleline')
    $rootMatch = $null
    foreach ($m in $allStructs) {
        if (-not $m.Groups[1].Success) {
            # No leading 'typedef' → this is a candidate root struct
            $rootMatch = $m
        }
    }
    if (-not $rootMatch) {
        throw "Cannot find root 'struct { ... }' in $Path"
    }
    $openIdx = $rootMatch.Index + $rootMatch.Length - 1
    $rootBody = Read-BracedBody -Text $text -OpenIndex $openIdx
    if ($null -eq $rootBody) { throw "Cannot match braces of root struct in $Path" }

    # Parse root struct's fields to find which inner type is the "row struct"
    $rootFields = Read-StructFields -Body $rootBody.body
    return @{
        rootFields = $rootFields
        text = $text
    }
}

# --------------------------------------------------------------------------------------
# 5. Brace matcher: returns the body inside { ... } given the position of the open brace.
# --------------------------------------------------------------------------------------

function Read-BracedBody {
    param([string] $Text, [int] $OpenIndex)
    if ($Text[$OpenIndex] -ne '{') { return $null }
    $depth = 1
    $i = $OpenIndex + 1
    while ($i -lt $Text.Length -and $depth -gt 0) {
        $c = $Text[$i]
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') { $depth-- }
        $i++
    }
    if ($depth -ne 0) { return $null }
    $closeIndex = $i - 1
    $body = $Text.Substring($OpenIndex + 1, $closeIndex - $OpenIndex - 1)
    return @{ body = $body; closeIndex = $closeIndex }
}

# --------------------------------------------------------------------------------------
# 6. Type-size resolver (for parsed field types).
# --------------------------------------------------------------------------------------

function Get-TypeSize {
    param([string] $Type)
    if ($Script:ScalarSizes.ContainsKey($Type)) { return $Script:ScalarSizes[$Type] }
    if ($Script:EnumSizes.ContainsKey($Type))   { return $Script:EnumSizes[$Type] }
    if ($Script:Structs.ContainsKey($Type)) {
        $s = $Script:Structs[$Type]
        if ($null -eq $s.size) {
            # Recursively compute size of one body unit
            $fields = Read-StructFields -Body $s.rawBody
            $unit = 0
            foreach ($f in $fields) { $unit += $f.totalSize }
            $intrinsic = if ($s.ContainsKey('intrinsicCount')) { $s.intrinsicCount } else { 1 }
            $s.size = $unit * $intrinsic
            $s.unitSize = $unit
            $s.fields = $fields
        }
        return $s.size
    }
    throw "Unknown type: '$Type'"
}

# --------------------------------------------------------------------------------------
# 7. Struct-body field parser. Returns an array of field descriptors:
#    @{ kind = 'scalar|struct|union|bitfield_group';
#       name = string;       (the right-hand identifier)
#       type = string;       (scalar type or struct name; 'bitfield_group' / 'union' / 'anon_struct' for composites)
#       count = int;         (1 for non-array)
#       elementSize = int;
#       totalSize = int;
#       hidden = bool;       (from <hidden=true>)
#       nested = array       (for struct/union/bitfield_group children, flattened)
#     }
# --------------------------------------------------------------------------------------

function Read-StructFields {
    param([string] $Body, [int] $TraceDepth = 0)

    $fields = New-Object System.Collections.Generic.List[hashtable]
    $i = 0
    $len = $Body.Length
    $indent = '  ' * $TraceDepth

    while ($i -lt $len) {
        # Skip whitespace
        while ($i -lt $len -and $Body[$i] -match '\s') { $i++ }
        if ($i -ge $len) { break }

        # Try inline struct or union: "struct {" or "union {"
        $remaining = $Body.Substring($i)
        if ($remaining -match '^(struct|union)\s*\{') {
            $kind = $matches[1]
            $openIdx = $i + $remaining.IndexOf('{')
            if ($ShowTrace) { Write-Host "$indent[trace] inline $kind at i=$i openIdx=$openIdx" -ForegroundColor DarkYellow }
            $bodyResult = Read-BracedBody -Text $Body -OpenIndex $openIdx
            if ($null -eq $bodyResult) { throw "Mismatched braces in inline $kind" }
            # After }, expect:  Name [<...>] ;
            $afterClose = $bodyResult.closeIndex + 1
            $rest = $Body.Substring($afterClose)
            $nm = [regex]::Match($rest, '^\s*(\w+)([^;]*);')
            if (-not $nm.Success) {
                if ($ShowTrace) { Write-Host "$indent[trace] FAIL: rest[0..40]='$($rest.Substring(0, [Math]::Min(40, $rest.Length)))'" -ForegroundColor Red }
                throw "Cannot find name after inline $kind at afterClose=$afterClose; rest starts: '$($rest.Substring(0, [Math]::Min(40, $rest.Length)))'"
            }
            $fieldName = $nm.Groups[1].Value
            $annot = $nm.Groups[2].Value
            $hidden = $annot -match 'hidden\s*=\s*true'

            $childFields = Read-StructFields -Body $bodyResult.body -TraceDepth ($TraceDepth + 1)
            # Ensure array shape (single-element returns object, not array)
            $childFields = @($childFields)

            if ($kind -eq 'union') {
                # Union: size = max of children's totalSize
                $size = 0
                foreach ($cf in $childFields) {
                    if ($cf.totalSize -gt $size) { $size = $cf.totalSize }
                }
                $fields.Add(@{
                    kind = 'union'; name = $fieldName; type = 'union';
                    count = 1; elementSize = $size; totalSize = $size;
                    hidden = $hidden; nested = $childFields
                })
            } else {
                # Anonymous struct: detect bitfield group (all members are `Bool x : 1`)
                $bitChildren = @($childFields | Where-Object { $_.kind -eq 'bitfield' })
                $allBitfield = ($childFields.Count -gt 0) -and ($bitChildren.Count -eq $childFields.Count)
                if ($allBitfield) {
                    # Bitfield group — size = bits/8 rounded up; for our templates always 32 bits = 4 bytes
                    $totalBits = 0
                    foreach ($bc in $bitChildren) { $totalBits += $bc.bitWidth }
                    $size = [int][math]::Ceiling($totalBits / 8.0)
                    $fields.Add(@{
                        kind = 'bitfield_group'; name = $fieldName; type = 'bitfield_group';
                        count = 1; elementSize = $size; totalSize = $size;
                        hidden = $hidden; nested = $childFields; totalBits = $totalBits
                    })
                } else {
                    # Anon struct = sum of children's totalSize
                    $size = 0
                    foreach ($cf in $childFields) { $size += $cf.totalSize }
                    $fields.Add(@{
                        kind = 'anon_struct'; name = $fieldName; type = 'anon_struct';
                        count = 1; elementSize = $size; totalSize = $size;
                        hidden = $hidden; nested = $childFields
                    })
                }
            }
            $i = $afterClose + $nm.Index + $nm.Length
            continue
        }

        # Bitfield member: "Bool name : 1 <name="X">;"
        if ($remaining -match '^(\w+)\s+(\w+)\s*:\s*(\d+)\s*([^;]*);') {
            $btype = $matches[1]
            $bname = $matches[2]
            $bwidth = [int]$matches[3]
            $annot = $matches[4]
            $hidden = $annot -match 'hidden\s*=\s*true'
            $fields.Add(@{
                kind = 'bitfield'; name = $bname; type = $btype;
                count = 1; elementSize = 0; totalSize = 0;
                hidden = $hidden; bitWidth = $bwidth
            })
            $consumed = $matches[0].Length
            $i += $consumed
            continue
        }

        # Regular field: "type name [N] <...>;" or "type name <...>;"
        if ($remaining -match '^(\w+)\s+(\w+)\s*(?:\[\s*(\d+)\s*\])?\s*([^;]*);') {
            $type = $matches[1]
            $name = $matches[2]
            $count = if ($matches[3]) { [int]$matches[3] } else { 1 }
            $annot = $matches[4]
            $hidden = $annot -match 'hidden\s*=\s*true'

            # Skip non-field constructs (typedef/const/return/etc. — shouldn't happen inside struct body, but defensive)
            if ($type -in @('typedef','const','return','case','void','enum')) {
                $consumed = $matches[0].Length
                $i += $consumed
                continue
            }

            $elemSize = Get-TypeSize -Type $type
            $totalSize = $elemSize * $count
            $isStruct = $Script:Structs.ContainsKey($type)
            $nested = if ($isStruct -and $count -ge 1) { $Script:Structs[$type].fields } else { @() }
            $fields.Add(@{
                kind = if ($isStruct) { 'struct' } else { 'scalar' };
                name = $name; type = $type;
                count = $count; elementSize = $elemSize; totalSize = $totalSize;
                hidden = $hidden; nested = $nested
            })
            $consumed = $matches[0].Length
            $i += $consumed
            continue
        }

        # If nothing matched, advance one char (defensive)
        $i++
    }
    return $fields.ToArray()
}

# --------------------------------------------------------------------------------------
# 8. Output flattening — turn a struct's field tree into (name, offset, size, type) records.
# --------------------------------------------------------------------------------------

function ConvertTo-FlatFieldList {
    param([array] $Fields, [int] $BaseOffset, [string] $Prefix = '')
    $out = @()
    $offset = $BaseOffset
    foreach ($f in $Fields) {
        $qname = if ($Prefix) { "$Prefix.$($f.name)" } else { $f.name }
        if (-not $f.hidden) {
            $out += @{
                name = $qname
                offset = $offset
                size = $f.totalSize
                type = $f.type
                kind = $f.kind
                count = $f.count
            }
            # Drill into nested struct (scalar struct, anon_struct, union) — for visibility,
            # but only ONE level deep (mod-scripts can reference by dot-path).
            if ($f.kind -in @('struct','anon_struct','union') -and $f.nested.Count -gt 0 -and $f.count -eq 1) {
                $out += ConvertTo-FlatFieldList -Fields $f.nested -BaseOffset $offset -Prefix $qname
            }
            # Bitfield group: emit each bit-named member at the group's offset (mod-scripts can reference by name)
            if ($f.kind -eq 'bitfield_group' -and $f.nested.Count -gt 0) {
                $bitOffset = 0
                foreach ($bit in $f.nested) {
                    $out += @{
                        name = "$qname.$($bit.name)"
                        offset = $offset
                        size = $f.totalSize
                        type = 'bit'
                        kind = 'bitfield'
                        bitOffset = $bitOffset
                        bitWidth = $bit.bitWidth
                    }
                    $bitOffset += $bit.bitWidth
                }
            }
        }
        $offset += $f.totalSize
    }
    return $out
}

# --------------------------------------------------------------------------------------
# 9. Main
# --------------------------------------------------------------------------------------

if ($ShowTrace) { Write-Host "Parsing: $TemplatePath" -ForegroundColor Cyan }

$entry = Read-TemplateFile -Path $TemplatePath
if ($null -eq $entry) {
    throw "Failed to parse $TemplatePath"
}

# A p3re template's root struct uses one of THREE shapes:
#
#   1. indexed_rows  — `unk unknown; SomeRow data[N];`
#                      Each row addressed by integer index 0..N-1, all rows share the same schema.
#                      Examples: p3re_skillNormal, p3re_personaGrowth.
#
#   2. single_record — `unk unknown; SomeType somedata;`
#                      The single named struct is the body; its inner fields/arrays are the real schema.
#                      We drill one level into `SomeType` and expose its fields directly.
#                      Examples: p3re_combineMisc, p3re_itemSkillCard, p3re_btlTheurgiaBoost
#                      (the latter uses intrinsicCount in its typedef declarator).
#
#   3. named_rows    — `unk unknown; T1 safety; T2 easy; T3 normal; T4 hard; T5 risky;`
#                      Each named root field is a row keyed by NAME (not integer index). All Ti
#                      structs typically share the same field schema (per-difficulty).
#                      Example: p3re_DT_BtlDIfficultyParam.
#
# Classification: a root field is "header" if its TYPE name starts with 'unk' (e.g. `unk`,
# `unk2`, `unk3` — all the templates use this convention). Everything else is "body".

$rootFields = @($entry.rootFields)
$header  = @($rootFields | Where-Object { $_.type -match '^unk\d*$' })
$body    = @($rootFields | Where-Object { $_.type -notmatch '^unk\d*$' })

if ($body.Count -eq 0) {
    throw "Root struct has no body fields (only header) — unsupported shape in $TemplatePath"
}

$headerHint = 0
foreach ($f in $header) { $headerHint += $f.totalSize }

# Derive asset name from template filename (best effort)
$tmplBase  = [System.IO.Path]::GetFileNameWithoutExtension($TemplatePath)
$assetName = $tmplBase -replace '^p3re_', '' -replace '^Dat','Dat'

# Build schema based on shape
$schema = [ordered]@{
    templateFile    = [System.IO.Path]::GetFileName($TemplatePath)
    asset           = "$assetName.uasset"
    rootStructName  = 'fileData'
    headerSizeHint  = $headerHint
    enumSizes       = $Script:EnumSizes
}

# Detect shape:
#   - If exactly 1 body field, kind=struct, count>1 → indexed_rows
#   - If exactly 1 body field, kind=struct, count=1 → single_record (drill into it)
#   - If >1 body fields, all kind=struct, count=1 → named_rows
$firstBody = $body[0]
$bodyStructCount = @($body | Where-Object { $_.kind -eq 'struct' -and $_.count -eq 1 }).Count

if ($body.Count -eq 1 -and $firstBody.kind -eq 'struct' -and $firstBody.count -gt 1) {
    # ---- Shape 1: indexed_rows ----
    $schema.tableShape    = 'indexed_rows'
    $schema.rowStructName = $firstBody.type
    $schema.rowCount      = $firstBody.count
    $schema.rowSize       = $firstBody.elementSize
    $schema.fields        = @(ConvertTo-FlatFieldList -Fields $Script:Structs[$firstBody.type].fields -BaseOffset 0)

    Write-Host "" ; Write-Host "=== Parsed: $tmplBase ===" -ForegroundColor Cyan
    Write-Host "  shape         : indexed_rows"
    Write-Host "  rowStructName : $($schema.rowStructName)"
    Write-Host "  rowCount      : $($schema.rowCount)"
    Write-Host "  rowSize       : $($schema.rowSize) bytes"
}
elseif ($body.Count -eq 1 -and $firstBody.kind -eq 'struct' -and $firstBody.count -eq 1) {
    # ---- Shape 2: single_record (drill into the named struct) ----
    $schema.tableShape    = 'single_record'
    $schema.recordType    = $firstBody.type
    $schema.recordName    = $firstBody.name
    $schema.recordSize    = $firstBody.elementSize
    # Drill: the schema fields are the named struct's own fields, at offset 0 within the record.
    $innerFields = $Script:Structs[$firstBody.type].fields
    $schema.fields = @(ConvertTo-FlatFieldList -Fields $innerFields -BaseOffset 0)

    # Detect intrinsic-array typedefs (e.g. `}theurgyBoostData[18];`) and surface their period
    $intrinsic = if ($Script:Structs[$firstBody.type].ContainsKey('intrinsicCount')) {
                     $Script:Structs[$firstBody.type].intrinsicCount } else { 1 }
    if ($intrinsic -gt 1) {
        $schema.repeatCount  = $intrinsic
        $schema.repeatStride = $Script:Structs[$firstBody.type].unitSize
        $schema.tableShape   = 'single_record_array'  # subtype
    }

    Write-Host "" ; Write-Host "=== Parsed: $tmplBase ===" -ForegroundColor Cyan
    Write-Host "  shape         : $($schema.tableShape)"
    Write-Host "  recordType    : $($schema.recordType)"
    Write-Host "  recordSize    : $($schema.recordSize) bytes"
    if ($intrinsic -gt 1) {
        Write-Host "  repeatCount   : $intrinsic (stride $($schema.repeatStride))"
    }
}
elseif ($body.Count -gt 1 -and $bodyStructCount -eq $body.Count) {
    # ---- Shape 3: named_rows ----
    $schema.tableShape = 'named_rows'
    $schema.rowKeys    = @($body | ForEach-Object { $_.name })
    # Cumulative offset for each named row
    $rowEntries = @()
    $offset = 0
    foreach ($f in $body) {
        # All rows share the same field schema (per the DT pattern)
        $rowFields = @(ConvertTo-FlatFieldList -Fields $Script:Structs[$f.type].fields -BaseOffset 0)
        $rowEntries += [ordered]@{
            name      = $f.name
            type      = $f.type
            offset    = $offset
            size      = $f.totalSize
            fields    = $rowFields
        }
        $offset += $f.totalSize
    }
    $schema.rows = $rowEntries
    # For convenience, also flatten a fields-template from the first row (they should match)
    $schema.fields = $rowEntries[0].fields

    Write-Host "" ; Write-Host "=== Parsed: $tmplBase ===" -ForegroundColor Cyan
    Write-Host "  shape         : named_rows"
    Write-Host "  rowKeys       : $($schema.rowKeys -join ', ')"
    Write-Host "  rows          : $($schema.rows.Count) (each $($schema.rows[0].size) bytes)"
    Write-Host "  fields/row    : $($schema.fields.Count)"
}
else {
    throw "Cannot classify root layout in $TemplatePath (body has $($body.Count) fields, $bodyStructCount struct-count-1)"
}

Write-Host "  headerHint    : $headerHint bytes (calibrate with real file)"
Write-Host "  fields        : $(if ($schema.Contains('fields') -and $schema.fields) { $schema.fields.Count } else { '-' }) (visible)"
Write-Host "  enums known   : $($Script:EnumSizes.Count)"

# Output
$json = $schema | ConvertTo-Json -Depth 12
if ($OutputPath) {
    [System.IO.File]::WriteAllText($OutputPath, $json)
    Write-Host "Schema written to $OutputPath" -ForegroundColor Green
} else {
    Write-Output $json
}
