# 재설치 없이 폰에 반영되는 내용 갱신을 배포한다 - 윈도우판 (tools/publish-update.sh 와 같은 일을 한다).
#
#   powershell -File tools\publish-update.ps1 0.1.251
#   $env:GODOT = 'C:\Tools\godot43\Godot_v4.3-stable_win64_console.exe'  (기본값)
#
# 1. project.godot 버전을 올린다  2. update/quple.pck 를 만든다
# 3. update/manifest.json 에 버전·크기·sha256 을 적는다  4. 커밋하고 push 한다
param([Parameter(Mandatory = $true)][string]$Version, [string]$Notes = "")
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "버전 형식은 X.Y.Z (받은 값: $Version)" }
$godot = $env:GODOT
if (-not $godot) { $godot = 'C:\Tools\godot43\Godot_v4.3-stable_win64_console.exe' }
if (-not (Test-Path $godot)) { throw "godot 을 찾을 수 없다: $godot" }

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
$proj = [IO.File]::ReadAllText("project.godot")
$cur = [regex]::Match($proj, 'config/version="([^"]+)"').Groups[1].Value
Write-Output "현재 $cur → 새 버전 $Version  (브랜치 $branch)"

# 앱이 보는 브랜치와 다르면 폰은 영영 못 받는다
$au = [IO.File]::ReadAllText("scripts\systems\auto_update.gd")
$m = [regex]::Match($au, 'quple-episode-0/(.+?)/update/manifest\.json')
if ($m.Success -and $m.Groups[1].Value -ne $branch) { throw "앱은 '$($m.Groups[1].Value)' 를 보는데 지금 브랜치는 '$branch'" }

$utf8 = New-Object Text.UTF8Encoding $false
[IO.File]::WriteAllText("project.godot", $proj.Replace("config/version=`"$cur`"", "config/version=`"$Version`""), $utf8)

New-Item -ItemType Directory -Force update | Out-Null
# 내보내기 설정은 git 에 없다(서명 비밀번호가 들어가서). 팩만 만들 땐 서명이 필요 없어 템플릿을 그대로 쓴다.
if (-not (Test-Path "export_presets.cfg")) { Copy-Item "export_presets.template.cfg" "export_presets.cfg" }
Write-Output "→ 리소스 팩 생성"
$pck = Join-Path (Get-Location) "update\quple.pck"
$before = if (Test-Path $pck) { (Get-Item $pck).LastWriteTime } else { [datetime]::MinValue }
& $godot --headless --path . --export-pack "Android arm64" $pck | Out-Null
# 옛 팩이 남아 있으면 '만들어졌다' 로 속는다 - 시각이 바뀌었는지 본다 (0.1.251 이 이렇게 옛 팩으로 나갔다)
if (-not (Test-Path $pck) -or (Get-Item $pck).Length -eq 0 -or (Get-Item $pck).LastWriteTime -le $before) {
	git checkout -- project.godot
	throw "팩이 새로 만들어지지 않았다"
}

$sha = (Get-FileHash $pck -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $pck).Length
$url = "https://raw.githubusercontent.com/keun4jang/quple-episode-0/$branch/update/quple.pck"
$json = "{`n  `"version`": `"$Version`",`n  `"url`": `"$url`",`n  `"sha256`": `"$sha`",`n  `"size`": $size,`n  `"notes`": `"$Notes`"`n}`n"
[IO.File]::WriteAllText("update\manifest.json", $json, $utf8)
Write-Output ("→ 팩 {0:N1} MB / sha256 {1}…" -f ($size / 1MB), $sha.Substring(0, 16))

git add project.godot update/quple.pck update/manifest.json
git commit -q -m "Publish content update $Version"
git push -q -u origin $branch
Write-Output "✓ $Version 배포 완료. 폰에서 앱을 껐다 켜면 받아서 그 다음 실행에 적용된다."
