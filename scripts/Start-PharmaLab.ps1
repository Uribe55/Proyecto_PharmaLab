param(
    [ValidateSet('Real', 'Demo', 'Emulator', 'EmulatorTests')][string]$Mode = 'Real',
    [string]$Device,
    [string]$ImportPath
)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Join-Path $PSScriptRoot '..')
if ($Mode -in @('Emulator', 'EmulatorTests')) {
    if (!(Test-Path -LiteralPath 'functions/node_modules/firebase-admin/package.json')) {
        & npm.cmd --prefix functions ci
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    $firebaseArgs = @('--config', 'firebase.emulator.json', '--project', 'demo-pharmalab', '--only', 'auth,firestore,functions')
    if ($Mode -eq 'EmulatorTests') {
        # Sin importación: las pruebas limpian su base local, nunca un respaldo.
        & firebase.cmd emulators:exec @firebaseArgs 'npm.cmd --prefix functions test'
    } else {
        if ($ImportPath) { $firebaseArgs += @('--import', $ImportPath, '--export-on-exit', $ImportPath) }
        & firebase.cmd emulators:start @firebaseArgs
    }
    exit $LASTEXITCODE
}
$entrypoint = if ($Mode -eq 'Real') { 'lib/main.dart' } else { 'lib/main_demo.dart' }
$flutterArgs = @('run', '-t', $entrypoint)
if ($Device) { $flutterArgs += @('-d', $Device) }
& flutter @flutterArgs
exit $LASTEXITCODE
