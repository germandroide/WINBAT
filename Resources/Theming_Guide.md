# WinBat Theming Guide

This guide explains how to create themes compatible with WinBat Console Mode (RetroBat/EmulationStation).

## Folder Structure

Create a folder for your theme in `C:\RetroBat\emulationstation\.emulationstation\themes\MyWinBatTheme`.

Inside, you need specific folders for the custom WinBat systems:

*   `vod` (Video On Demand)
*   `cloudgaming` (Cloud Gaming services)
*   `multimedia` (Media apps)
*   `windows` (Standard Windows games)

## Required Assets

For each system folder, provide:

*   `background.png` (1920x1080 recommended)
*   `logo.png` (Transparent PNG)
*   `icon.png` (System icon)

## XML Configuration

Your `theme.xml` should include views for `system`, `basic`, and `detailed`.

Example structure:

```xml
<theme>
    <formatVersion>4</formatVersion>

    <view name="system">
        <image name="background" extra="true">
            <path>./assets/background.png</path>
        </image>
    </view>

    <view name="basic, detailed">
        <image name="logo">
            <path>./assets/logo.png</path>
        </image>
    </view>
</theme>
```

## Specific System Theming

To theme the 'vod' system, create a `<feature supported="vod">` block or simply organize your folder structure so EmulationStation finds the assets in the `vod` subfolder.
