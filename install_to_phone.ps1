$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
Write-Host "Checking connected mobile device..." -ForegroundColor Cyan
& $adb devices
Write-Host "Installing fresh build with Real Wi-Fi feature..." -ForegroundColor Yellow
& $adb install -r build\app\outputs\flutter-apk\app-debug.apk
Write-Host "Launching iBots Remote..." -ForegroundColor Green
& $adb shell am start -n com.ibots.ibots_remote_app/.MainActivity
