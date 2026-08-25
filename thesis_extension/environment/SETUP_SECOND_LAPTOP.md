# Set up the Lenovo with the validated HP R 3.4.3 library

Use the same 64-bit Windows R 3.4.3 installation and copy the validated library. Do not independently resolve or install packages on the Lenovo.

## 1. Copy from HP to transfer media

Run on the HP, replacing `E:` with the transfer drive. The destination must be new or empty.

```powershell
$HpEnvironment = 'C:\Users\User\master_thesis\thesis_extension\environment'
$TransferEnvironment = 'E:\DML_IVQR_R343\environment'
if (Test-Path -LiteralPath $TransferEnvironment) {
    throw "Choose a new empty transfer destination: $TransferEnvironment"
}
New-Item -ItemType Directory -Path $TransferEnvironment | Out-Null
Copy-Item -LiteralPath (Join-Path $HpEnvironment 'legacy_R343_library') -Destination $TransferEnvironment -Recurse
Copy-Item -LiteralPath (Join-Path $HpEnvironment 'library_manifest_R343.csv') -Destination $TransferEnvironment
Copy-Item -LiteralPath (Join-Path $HpEnvironment 'package_archive_hashes_R343.csv') -Destination $TransferEnvironment
Copy-Item -LiteralPath (Join-Path $HpEnvironment 'check_author_environment.R') -Destination $TransferEnvironment
```

## 2. Install/copy R 3.4.3 on Lenovo

The required executable path is:

`C:\Program Files\R\R-3.4.3\bin\x64\Rscript.exe`

Verify it directly:

```powershell
& 'C:\Program Files\R\R-3.4.3\bin\x64\Rscript.exe' --version
```

It must report R 3.4.3 dated 2017-11-30.

## 3. Copy the library into the Lenovo project

```powershell
$TransferEnvironment = 'E:\DML_IVQR_R343\environment'
$LenovoEnvironment = 'C:\Users\User\master_thesis\thesis_extension\environment'
$LenovoLibrary = Join-Path $LenovoEnvironment 'legacy_R343_library'
if (Test-Path -LiteralPath $LenovoLibrary) {
    throw "Do not merge libraries. Move the existing target aside and review it first: $LenovoLibrary"
}
New-Item -ItemType Directory -Path $LenovoEnvironment -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $TransferEnvironment 'legacy_R343_library') -Destination $LenovoEnvironment -Recurse
Copy-Item -LiteralPath (Join-Path $TransferEnvironment 'library_manifest_R343.csv') -Destination $LenovoEnvironment
Copy-Item -LiteralPath (Join-Path $TransferEnvironment 'package_archive_hashes_R343.csv') -Destination $LenovoEnvironment
Copy-Item -LiteralPath (Join-Path $TransferEnvironment 'check_author_environment.R') -Destination $LenovoEnvironment
```

## 4. Verify every package DESCRIPTION hash

```powershell
$LenovoEnvironment = 'C:\Users\User\master_thesis\thesis_extension\environment'
$LenovoLibrary = Join-Path $LenovoEnvironment 'legacy_R343_library'
$ManifestRows = Import-Csv -LiteralPath (Join-Path $LenovoEnvironment 'library_manifest_R343.csv')
foreach ($ManifestRow in $ManifestRows) {
    $DescriptionPath = Join-Path $LenovoLibrary $ManifestRow.relative_path
    if (-not (Test-Path -LiteralPath $DescriptionPath)) {
        throw "Missing DESCRIPTION: $DescriptionPath"
    }
    $ActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $DescriptionPath).Hash
    if ($ActualHash -ne $ManifestRow.description_sha256) {
        throw "Hash mismatch: $DescriptionPath"
    }
}
Write-Output 'R343 LIBRARY DESCRIPTION HASHES: PASS'
```

## 5. Run the strict environment checker

```powershell
$LenovoLibrary = 'C:\Users\User\master_thesis\thesis_extension\environment\legacy_R343_library'
$env:R_LIBS_USER = $LenovoLibrary
& 'C:\Program Files\R\R-3.4.3\bin\x64\Rscript.exe' `
  'C:\Users\User\master_thesis\thesis_extension\environment\check_author_environment.R'
```

Require `AUTHOR R343 ENVIRONMENT CHECK: PASS`. Also verify Node remains 5 in `config/extension_config.R`. Do not start the n=1000 R=500 run until the Lenovo hash check, environment check, and a separate authorization are complete.
