@echo off
echo ===============================================
echo    Git配置修复脚本 - Git Configuration Fix
echo ===============================================
echo.

echo [1/6] 检查Git是否安装...
git --version
if errorlevel 1 (
    echo 错误: Git未安装或不在PATH中
    pause
    exit /b 1
)
echo.

echo [2/6] 配置Git用户信息...
echo 请输入您的姓名:
set /p git_name=
echo 请输入您的邮箱:
set /p git_email=

git config --global user.name "%git_name%"
git config --global user.email "%git_email%"
echo 用户信息配置完成
echo.

echo [3/6] 配置Git基础设置...
git config --global core.editor "code --wait"
git config --global pull.rebase false
git config --global credential.helper manager
echo 基础设置配置完成
echo.

echo [4/6] 测试GitHub连接...
ping -n 1 github.com >nul
if errorlevel 1 (
    echo 警告: 无法ping到GitHub，请检查网络连接
) else (
    echo GitHub连接正常
)
echo.

echo [5/6] 当前Git配置信息:
echo -----------------------------------------
git config --list | findstr /C:"user.name" /C:"user.email" /C:"credential.helper"
echo -----------------------------------------
echo.

echo [6/6] 生成Git状态报告...
echo 当前仓库: %CD%
git status --porcelain
echo.

echo ===============================================
echo              修复完成！
echo ===============================================
echo.
echo 接下来您可以执行以下命令:
echo   git add .
echo   git commit -m "您的提交信息"
echo   git push origin master
echo.
pause