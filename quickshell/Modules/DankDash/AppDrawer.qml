import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    implicitHeight: 410
    property var appList: []
    property int appCount: 0
    property var appImageApps: []
    property var desktopAppsList: []

    onAppListChanged: {
        appImageApps = appList.filter((a) => !a.isDesktop);
        desktopAppsList = appList.filter((a) => a.isDesktop);
    }
    property string homeDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation))
    property string iconCacheDir: homeDir + "/Software/AppIcon"
    property var cachedIcons: ({})
    property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/DankMaterialShell"
    property string savedAppsFile: configDir + "/desktop_apps.json"
    property string desktopCacheFile: configDir + "/desktop_cache.json"
    property bool initialized: false
    property int iconSize: 36
    property string iconSizeFile: configDir + "/appdrawer_iconsize.json"

    // Cell height adapts to icon size with room for text + padding
    readonly property int _cellHeight: Math.round(iconSize * 2.0 + 30)
    // Columns shrink with icon size but stay between 4 and 8
    readonly property int _columns: Math.max(4, Math.min(8, Math.round(700 / (iconSize + 16))))
    // Source image resolution = 2x icon for retina
    readonly property int _sourceSize: iconSize * 2
        const lowerName = appName.toLowerCase();
        if (cachedIcons[lowerName]) {
            return cachedIcons[lowerName];
        }
        // Try stripping trailing version-like suffixes for icon matching
        var stripped = lowerName.replace(/[-_]\d+([-_.]\d+)*([-_]\d+)?$/, "");
        if (stripped !== lowerName && cachedIcons[stripped]) {
            return cachedIcons[stripped];
        }
        // Try progressively stripping trailing segments (separated by - or _)
        var current = stripped;
        while (true) {
            const lastSep = Math.max(current.lastIndexOf("-"), current.lastIndexOf("_"));
            if (lastSep <= 0) break;
            current = current.substring(0, lastSep);
            if (cachedIcons[current]) {
                return cachedIcons[current];
            }
        }
        // Normalize: remove dots and separators, then try prefix match
        const normalized = lowerName.replace(/[.\-_\s]+/g, "");
        for (var key in cachedIcons) {
            const keyNorm = key.replace(/[.\-_\s]+/g, "");
            if (normalized.startsWith(keyNorm) || keyNorm.startsWith(normalized)) {
                return cachedIcons[key];
            }
        }
        // Finally try each cached icon key as a prefix of the app name
        for (var key2 in cachedIcons) {
            if (lowerName.startsWith(key2) || key2.startsWith(lowerName)) {
                return cachedIcons[key2];
            }
        }
        return null;
    }

    function getIconPath(appName) {
        const found = findIconFile(appName);
        if (found) {
            return found;
        }
        return iconCacheDir + "/" + appName + ".png";
    }

    function getAppNameFromFilename(filename) {
        let name = filename.replace(/\.AppImage$/i, "");
        // Remove arch suffixes (x86_64, amd64, aarch64, arm64, i686, etc.)
        // with optional version before them like -1.2.3-amd64 or _2.1.2_amd64
        name = name.replace(/[-_]\d+([-_.]\d+)*[-_](x86_64|amd64|aarch64|arm64|i686)$/, "");
        name = name.replace(/[-_](x86_64|amd64|aarch64|arm64|i686)$/, "");
        name = name.replace(/[-_]\d+([-_.]\d+)*[-_]linux[-_](amd64|x86_64)$/, "");
        name = name.replace(/[-_]linux[-_](amd64|x86_64)$/, "");
        name = name.replace(/[-_]linux-(amd64|x86_64)$/, "");
        // Strip trailing version numbers like -3.2.27 or _3.2.30-50828
        name = name.replace(/[-_]\d+([-_.]\d+)*([-_][a-z]*\d*)?$/i, "");
        // Also strip dot-separated trailing version like .v0.1.37
        name = name.replace(/(\.v?\d+([-_.]\d+)*([-_.][a-z]+\d*)?)$/i, "");
        return name;
    }

    function getDisplayName(appName) {
        if (appName.length === 0) return "";
        let name = appName;
        // Remove trailing qualifier words like -fixed, -stable etc.
        name = name.replace(/[-_](fixed|stable|beta|alpha|rc|patch|debug|release|final|portable|setup|linux)$/i, "");
        // Remove dots (treat as mere word joiners between name parts)
        name = name.replace(/\./g, "");
        // Replace remaining -_ with nothing (camelCase join)
        name = name.replace(/[-_]+/g, "");
        if (name.length === 0) return appName;
        // Capitalize first letter
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    function loadCachedIcons(callback) {
        Proc.runCommand(
            "load-icon-cache",
            ["sh", "-c", "ls -1 '" + iconCacheDir + "' 2>/dev/null || true"],
            function(output, exitCode) {
                if (exitCode === 0 && output && output.trim().length > 0) {
                    const files = output.trim().split("\n").filter(f => f.length > 0);
                    for (let i = 0; i < files.length; i++) {
                        const name = files[i].replace(/\.(png|svg)$/i, "").toLowerCase();
                        cachedIcons[name] = iconCacheDir + "/" + files[i];
                    }
                }
                if (callback) callback();
            },
            0,
            5000
        );
    }

    function extractAppImageIcon(appPath, appName, callback) {
        const tmpDir = iconCacheDir + "/tmp-" + appName;

        Proc.runCommand(
            "extract-icon-" + appName,
            ["sh", "-c",
                "mkdir -p '" + iconCacheDir + "' && " +
                "rm -rf '" + tmpDir + "' && " +
                "mkdir -p '" + tmpDir + "' && " +
                "cd '" + tmpDir + "' && " +
                "timeout 45 '" + appPath + "' --appimage-extract 2>/dev/null; " +
                "FOUND_ICON=0; " +
                "for icon in $(find squashfs-root -maxdepth 5 -name '*.png' 2>/dev/null | head -5); do " +
                "  REAL_FILE=$(readlink -f \"$icon\" 2>/dev/null || echo \"$icon\"); " +
                "  if [ -f \"$REAL_FILE\" ]; then " +
                "    cp \"$REAL_FILE\" '" + iconCacheDir + "/" + appName + ".png' 2>/dev/null && FOUND_ICON=1 && break; " +
                "  fi; " +
                "done; " +
                "if [ \"$FOUND_ICON\" = 0 ]; then " +
                "  for icon in $(find squashfs-root -maxdepth 5 -name '*.svg' -o -name '.DirIcon' 2>/dev/null | head -5); do " +
                "    REAL_FILE=$(readlink -f \"$icon\" 2>/dev/null || echo \"$icon\"); " +
                "    if [ -f \"$REAL_FILE\" ]; then " +
                "      EXT=\"${REAL_FILE##*.}\"; " +
                "      cp \"$REAL_FILE\" '" + iconCacheDir + "/" + appName + ".$EXT' 2>/dev/null && FOUND_ICON=1 && break; " +
                "    fi; " +
                "  done; " +
                "fi; " +
                "rm -rf '" + tmpDir + "'; " +
                "ls -1 '" + iconCacheDir + "'/" + appName + ".* 2>/dev/null | head -1 || echo 'failed'"
            ],
            function(output, exitCode) {
                if (output && output.trim().length > 0 && !output.includes("failed")) {
                    const lowerName = appName.toLowerCase();
                    cachedIcons[lowerName] = output.trim();
                }
                if (callback) callback(exitCode);
            },
            0,
            90000
        );
    }

    function scanApps() {
        loadCachedIcons(function() {
            Proc.runCommand(
                "scan-appimages",
                ["sh", "-c", "ls -1 ~/Software/*.AppImage 2>/dev/null || true"],
                function(output, exitCode) {
                    const newList = [];

                    if (exitCode === 0 && output && output.trim().length > 0) {
                        const files = output.trim().split("\n").filter(f => f.length > 0);
                        const needExtract = [];

                        for (let i = 0; i < files.length; i++) {
                            const filePath = files[i];
                            const filename = filePath.split("/").pop();
                            const appName = getAppNameFromFilename(filename);
                            const displayName = getDisplayName(appName);
                            const iconPath = getIconPath(appName);
                            const iconFile = findIconFile(appName);
                            const hasIcon = iconFile !== null;
                            // Use icon filename as display name when available
                            var itemName = displayName;
                            if (hasIcon) {
                                const iconBase = iconFile.split("/").pop().replace(/\.\w+$/, "").replace(/\./g, "");
                                if (iconBase.length > 0)
                                    itemName = iconBase.charAt(0).toUpperCase() + iconBase.slice(1);
                            }

                            newList.push({
                                name: itemName,
                                appName: appName,
                                path: filePath,
                                iconPath: iconPath,
                                iconExtracted: hasIcon,
                                isDesktop: false
                            });

                            if (!hasIcon) {
                                needExtract.push({
                                    index: i,
                                    appName: appName,
                                    path: filePath
                                });
                            }
                        }

                        if (needExtract.length > 0) {
                            extractIconsInBackground(needExtract);
                        }
                    }

                    loadSavedDesktopApps((saved) => {
                        const allList = newList.concat(saved);
                        appList = allList;
                        appCount = appList.length;
                        console.log("Total apps:", appCount);
                    });
                },
                0,
                10000
            );
        });
    }

    function extractIconsInBackground(apps) {
        if (apps.length === 0) return;

        const app = apps[0];
        const remaining = apps.slice(1);

        extractAppImageIcon(app.path, app.appName, function(exitCode) {
            const iconPath = getIconPath(app.appName);
            const iconFile = findIconFile(app.appName);
            const newList = appList.slice();
            for (let i = 0; i < newList.length; i++) {
                if (newList[i].path === app.path && !newList[i].isDesktop) {
                    newList[i].iconPath = iconPath;
                    newList[i].iconExtracted = true;
                    // Update display name to match the extracted icon filename
                    if (iconFile) {
                        const iconBase = iconFile.split("/").pop().replace(/\.\w+$/, "").replace(/\./g, "");
                        if (iconBase.length > 0)
                            newList[i].name = iconBase.charAt(0).toUpperCase() + iconBase.slice(1);
                    }
                    break;
                }
            }
            appList = newList;
            appCount = appList.length;
            extractIconsInBackground(remaining);
        });
    }

    function launchApp(app) {
        if (app.isDesktop) {
            Proc.runCommand(
                "desktop-launch",
                ["sh", "-c", "gtk-launch " + app.path.split("/").pop().replace(".desktop", "") + " 2>/dev/null || kioclient exec '" + app.path + "' 2>/dev/null || sh -c \"$(grep -m1 '^Exec=' '" + app.path + "' | sed 's/^Exec=//' | sed 's/%.//g')\" & disown"],
                (output, exitCode) => {
                    console.log("Desktop app launched:", exitCode);
                },
                0,
                Proc.noTimeout
            );
        } else {
            Proc.runCommand(
                "appimage-launch",
                ["sh", "-c", "chmod +x '" + app.path + "' && nohup '" + app.path + "' > /dev/null 2>&1 & disown"],
                (output, exitCode) => {
                    console.log("AppImage launched:", exitCode);
                },
                0,
                Proc.noTimeout
            );
        }
    }

    function loadIconSize() {
        Proc.runCommand(
            "load-iconsize",
            ["sh", "-c", "cat '" + iconSizeFile + "' 2>/dev/null || echo '36'"],
            (output, exitCode) => {
                const val = parseInt(output.trim());
                if (!isNaN(val) && val >= 20 && val <= 64)
                    iconSize = val;
            },
            0,
            3000
        );
    }

    function saveIconSize() {
        Proc.runCommand(
            "save-iconsize",
            ["sh", "-c", "mkdir -p '" + configDir + "' && echo '" + iconSize + "' > '" + iconSizeFile + "'"],
            (output, exitCode) => {},
            0,
            3000
        );
    }

    Component.onCompleted: {
        loadIconSize();
        if (visible) {
            initialized = true;
            scanApps();
        }
    }

    onIconSizeChanged: saveIconSize()

    onVisibleChanged: {
        if (visible && !initialized) {
            initialized = true;
            scanApps();
        }
    }

    function saveDesktopCache() {
        if (!cachedDesktopApps || cachedDesktopApps.length === 0) return;
        const json = JSON.stringify(cachedDesktopApps);
        Proc.runCommand(
            "save-desktop-cache",
            ["sh", "-c", "mkdir -p '" + configDir + "' && echo '" + json.replace(/'/g, "'\\''") + "' > '" + desktopCacheFile + "'"],
            (output, exitCode) => {
                console.log("Desktop cache saved:", exitCode);
            },
            0,
            5000
        );
    }

    function saveDesktopApps() {
        const desktopApps = appList.filter((a) => a.isDesktop);
        if (desktopApps.length === 0) return;
        const json = JSON.stringify(desktopApps);
        Proc.runCommand(
            "save-desktop-apps",
            ["sh", "-c", "mkdir -p '" + configDir + "' && echo '" + json.replace(/'/g, "'\\''") + "' > '" + savedAppsFile + "'"],
            (output, exitCode) => {
                console.log("Saved desktop apps:", exitCode);
            },
            0,
            5000
        );
    }

    function loadSavedDesktopApps(callback) {
        Proc.runCommand(
            "load-saved-desktop-apps",
            ["sh", "-c", "cat '" + savedAppsFile + "' 2>/dev/null || echo ''"],
            (output, exitCode) => {
                if (exitCode === 0 && output && output.trim().length > 0) {
                    try {
                        const saved = JSON.parse(output.trim());
                        if (Array.isArray(saved)) {
                            callback(saved);
                            return;
                        }
                    } catch (e) {
                        console.log("Failed to parse saved desktop apps:", e);
                    }
                }
                callback([]);
            },
            0,
            5000
        );
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingS

        DankFlickable {
            width: parent.width
            height: parent.height - 40
            clip: true
            contentHeight: appImageSection.height + desktopSection.height + Theme.spacingL

            Column {
                id: appImageSection
                width: parent.width
                spacing: Theme.spacingXS
                visible: appImageList.count > 0

                Row {
                    width: parent.width
                    height: 20

                    StyledText {
                        text: I18n.tr("AppImages") + " (" + appImageList.count + ")"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        leftPadding: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 1; height: 1 }

                    DankActionButton {
                        width: 20
                        height: 20
                        circular: false
                        iconName: "format_size"
                        iconSize: 14
                        iconColor: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            const sizes = [28, 36, 48];
                            const idx = sizes.indexOf(iconSize);
                            iconSize = sizes[(idx + 1) % sizes.length];
                        }
                    }
                }

                GridView {
                    id: appImageList
                    width: parent.width
                    height: Math.ceil(count / root._columns) * root._cellHeight
                    clip: true
                    cellWidth: width / root._columns
                    cellHeight: root._cellHeight
                    model: appImageApps

                    delegate: Item {
                        width: appImageList.cellWidth
                        height: appImageList.cellHeight

                        Rectangle {
                            id: appCard1
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXS
                            color: Theme.nestedSurface
                            border.color: Theme.outlineMedium
                            border.width: 1
                            radius: Theme.cornerRadius

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: 4

                                Item {
                                    id: appIconContainer1
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: root.iconSize
                                    height: root.iconSize
                                    property bool iconLoaded: false

                                    Image {
                                        id: appIcon1
                                        anchors.fill: parent
                                        source: modelData.iconPath || ""
                                        smooth: true
                                        mipmap: true
                                        asynchronous: true
                                        sourceSize.width: root._sourceSize
                                        sourceSize.height: root._sourceSize
                                        fillMode: Image.PreserveAspectFit

                                        onStatusChanged: {
                                            if (status === Image.Ready) {
                                                appIconContainer1.iconLoaded = true;
                                            } else if (status === Image.Error || status === Image.Null) {
                                                appIconContainer1.iconLoaded = false;
                                            }
                                        }
                                    }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "application-x-executable"
                                        size: root.iconSize
                                        color: Theme.primary
                                        visible: !appIconContainer1.iconLoaded
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    text: modelData.name
                                    font.pixelSize: Math.min(11, Math.round(root.iconSize * 0.3))
                                    color: Theme.surfaceText
                                    opacity: 0.8
                                    elide: Text.ElideMiddle
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.NoWrap
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: appCard1.color = Theme.withAlpha(Theme.primary, 0.15)
                                onExited: appCard1.color = Theme.nestedSurface
                                onClicked: launchApp(modelData)
                            }
                        }
                    }
                }
            }

            Column {
                id: desktopSection
                width: parent.width
                anchors.top: appImageSection.visible ? appImageSection.bottom : parent.top
                anchors.topMargin: appImageSection.visible ? Theme.spacingM : 0
                spacing: Theme.spacingXS
                visible: desktopListGrid.count > 0

                Row {
                    width: parent.width
                    height: 20

                    StyledText {
                        text: I18n.tr("Desktop Apps") + " (" + desktopListGrid.count + ")"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        leftPadding: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 1; height: parent.height }

                    DankActionButton {
                        width: 28
                        height: 28
                        circular: false
                        iconName: "refresh"
                        iconSize: 18
                        iconColor: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            desktopAppsDirty = true;
                            cachedDesktopApps = null;
                            Proc.runCommand(
                                "clear-desktop-cache",
                                ["sh", "-c", "rm -f '" + desktopCacheFile + "' 2>/dev/null"],
                                (output, exitCode) => {},
                                0,
                                3000
                            );
                            scanApps();
                        }
                    }

                    DankActionButton {
                        width: 28
                        height: 28
                        circular: false
                        iconName: "add"
                        iconSize: 18
                        iconColor: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: addDesktopApps()
                    }

                    Item { width: Theme.spacingM; height: 1 }

                    DankActionButton {
                        width: 28
                        height: 28
                        circular: false
                        iconName: "format_size"
                        iconSize: 16
                        iconColor: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            const sizes = [28, 36, 48];
                            const idx = sizes.indexOf(iconSize);
                            iconSize = sizes[(idx + 1) % sizes.length];
                        }
                    }
                }

                GridView {
                    id: desktopListGrid
                    width: parent.width
                    height: Math.ceil(count / root._columns) * root._cellHeight
                    clip: true
                    cellWidth: width / root._columns
                    cellHeight: root._cellHeight
                    model: desktopAppsList

                    delegate: Item {
                        width: desktopListGrid.cellWidth
                        height: desktopListGrid.cellHeight

                        Rectangle {
                            id: appCard2
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXS
                            color: Theme.nestedSurface
                            border.color: Theme.outlineMedium
                            border.width: 1
                            radius: Theme.cornerRadius

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: 4

                                Item {
                                    id: appIconContainer2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: root.iconSize
                                    height: root.iconSize
                                    property bool iconLoaded: false

                                    IconImage {
                                        id: appIcon2
                                        anchors.fill: parent
                                        source: modelData.iconPath || ""
                                        smooth: true
                                        mipmap: true
                                        asynchronous: true
                                        implicitSize: root._sourceSize
                                        backer.sourceSize.width: root._sourceSize
                                        backer.sourceSize.height: root._sourceSize

                                        onStatusChanged: {
                                            if (status === Image.Ready) {
                                                appIconContainer2.iconLoaded = true;
                                            } else if (status === Image.Error || status === Image.Null) {
                                                appIconContainer2.iconLoaded = false;
                                            }
                                        }
                                    }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: modelData.iconName || "application-desktop"
                                        size: root.iconSize
                                        color: Theme.primary
                                        visible: !appIconContainer2.iconLoaded
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    text: modelData.name
                                    font.pixelSize: Math.min(11, Math.round(root.iconSize * 0.3))
                                    color: Theme.surfaceText
                                    opacity: 0.8
                                    elide: Text.ElideMiddle
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.NoWrap
                                }
                            }

                            DankIcon {
                                id: removeIcon2
                                name: "close"
                                size: 14
                                color: Theme.error
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 4
                                visible: false
                                z: 10

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    radius: Theme.cornerRadius
                                    color: Theme.withAlpha(Theme.surfaceContainer, 0.9)
                                    z: -1
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    appCard2.color = Theme.withAlpha(Theme.primary, 0.15);
                                    removeIcon2.visible = true;
                                }
                                onExited: {
                                    appCard2.color = Theme.nestedSurface;
                                    removeIcon2.visible = false;
                                }
                                onClicked: launchApp(modelData)
                            }

                            MouseArea {
                                id: removeArea2
                                width: 24
                                height: 24
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 0
                                visible: removeIcon2.visible
                                z: 20
                                cursorShape: Qt.PointingHandCursor
                                onClicked: removeDesktopApp(modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: appCount === 0
        text: I18n.tr("No apps found")
        font.pixelSize: 14
        color: Theme.outline
        horizontalAlignment: Text.AlignHCenter
    }

    function addDesktopApps() {
        if (desktopSearchField) desktopSearchField.text = "";
        desktopPickerRect.visible = true;
        loadDesktopApps();
    }

    function removeDesktopApp(path) {
        let newList = appList.filter((a) => a.path !== path);
        appList = newList;
        appCount = appList.length;
        saveDesktopApps();
    }

    property var cachedDesktopApps: null
    property bool desktopAppsDirty: true

    function loadDesktopApps() {
        if (!desktopAppsDirty && cachedDesktopApps !== null) {
            desktopAppsModel.clear();
            const existingPaths = appList.map((a) => a.path);
            for (let i = 0; i < cachedDesktopApps.length; i++) {
                if (existingPaths.indexOf(cachedDesktopApps[i].path) >= 0) continue;
                desktopAppsModel.append(cachedDesktopApps[i]);
            }
            filterDesktopApps();
            return;
        }

        Proc.runCommand(
            "load-desktop-cache",
            ["sh", "-c", "cat '" + desktopCacheFile + "' 2>/dev/null || echo ''"],
            (output, exitCode) => {
                if (exitCode === 0 && output && output.trim().length > 0) {
                    try {
                        const cached = JSON.parse(output.trim());
                        if (Array.isArray(cached) && cached.length > 0) {
                            cachedDesktopApps = cached;
                            desktopAppsDirty = false;
                            desktopAppsModel.clear();
                            const existingPaths = appList.map((a) => a.path);
                            for (let i = 0; i < cached.length; i++) {
                                if (existingPaths.indexOf(cached[i].path) >= 0) continue;
                                desktopAppsModel.append(cached[i]);
                            }
                            filterDesktopApps();
                            console.log("Loaded desktop apps from cache:", cached.length);
                            return;
                        }
                    } catch (e) {}
                }
                scanDesktopAppsForPicker();
            },
            0,
            5000
        );
    }

    function scanDesktopAppsForPicker() {
        const locale = Qt.locale().name;
        const langCode = locale.split("_")[0];

        Proc.runCommand(
            "scan-desktop",
            ["sh", "-c",
                "LANG_CODE='" + langCode + "'; " +
                "FULL_LOCALE='" + locale + "'; " +
                "find /usr/share/applications /usr/local/share/applications /usr/local/share/applications/apm \"$HOME/.local/share/applications\" -name '*.desktop' 2>/dev/null | while read f; do " +
                "  LOCAL_NAME=$(grep -m1 \"^Name\\[$LANG_CODE\\]=\" \"$f\" | sed \"s/^Name\\[$LANG_CODE\\]=//\"); " +
                "  if [ -z \"$LOCAL_NAME\" ]; then LOCAL_NAME=$(grep -m1 \"^Name\\[$FULL_LOCALE\\]=\" \"$f\" | sed \"s/^Name\\[$FULL_LOCALE\\]=//\"); fi; " +
                "  NAME=$(grep -m1 '^Name=' \"$f\" | sed 's/^Name=//'); " +
                "  ICON=$(grep -m1 '^Icon=' \"$f\" | sed 's/^Icon=//'); " +
                "  FILENAME=$(basename \"$f\" .desktop); " +
                "  if [ -n \"$NAME\" ]; then " +
                "    echo \"$NAME|$LOCAL_NAME|$FILENAME|$ICON|$f\"; " +
                "  fi; " +
                "done"
            ],
            (output, exitCode) => {
                desktopAppsModel.clear();
                if (exitCode === 0 && output && output.trim().length > 0) {
                    const lines = output.trim().split("\n");
                    const existingPaths = appList.map((a) => a.path);

                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].trim();
                        if (!line) continue;
                        const parts = line.split("|");
                        if (parts.length >= 5) {
                            const name = parts[0];
                            const localName = parts[1];
                            const fileName = parts[2];
                            const icon = parts[3];
                            const path = parts[4];
                            if (existingPaths.indexOf(path) >= 0) continue;

                            let iconPath = "";
                            if (icon && icon.startsWith("/")) {
                                iconPath = icon;
                            } else if (icon) {
                                iconPath = Quickshell.iconPath(icon, true) || DesktopService.resolveIconPath(icon) || "";
                            }

                            desktopAppsModel.append({
                                name: localName || name,
                                displayName: name,
                                localName: localName,
                                fileName: fileName,
                                exec: path,
                                path: path,
                                iconPath: iconPath,
                                iconName: icon || "",
                                selected: false
                            });
                        }
                    }
                }
                cachedDesktopApps = [];
                for (let i = 0; i < desktopAppsModel.count; i++) {
                    cachedDesktopApps.push(desktopAppsModel.get(i));
                }
                desktopAppsDirty = false;
                filterDesktopApps();
                saveDesktopCache();
            },
            0,
            15000
        );
    }

    function addSelectedDesktopApps() {
        let newList = appList.slice();
        for (let i = 0; i < desktopAppsModel.count; i++) {
            const item = desktopAppsModel.get(i);
            if (item.selected) {
                newList.push({
                    name: item.name,
                    appName: item.name.replace(/\s+/g, "-").toLowerCase(),
                    path: item.path,
                    exec: item.exec,
                    iconPath: item.iconPath || "",
                    iconName: item.iconName || "",
                    isDesktop: true
                });
            }
        }
        appList = newList;
        appCount = appList.length;
        saveDesktopApps();
        desktopPickerRect.visible = false;
    }

    ListModel {
        id: desktopAppsModel
    }

    ListModel {
        id: filteredDesktopModel
    }

    function filterDesktopApps() {
        const query = desktopSearchField ? desktopSearchField.text.toLowerCase() : "";
        let items = [];
        for (let i = 0; i < desktopAppsModel.count; i++) {
            const item = desktopAppsModel.get(i);
            if (!query ||
                item.name.toLowerCase().indexOf(query) >= 0 ||
                (item.displayName && item.displayName.toLowerCase().indexOf(query) >= 0) ||
                (item.localName && item.localName.toLowerCase().indexOf(query) >= 0) ||
                (item.fileName && item.fileName.toLowerCase().indexOf(query) >= 0)) {
                items.push({
                    name: item.name,
                    displayName: item.displayName || "",
                    localName: item.localName || "",
                    fileName: item.fileName || "",
                    exec: item.exec,
                    path: item.path,
                    iconPath: item.iconPath || "",
                    iconName: item.iconName || "",
                    selected: item.selected
                });
            }
        }
        items.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
        filteredDesktopModel.clear();
        for (let i = 0; i < items.length; i++) {
            filteredDesktopModel.append(items[i]);
        }
    }

    Rectangle {
        id: desktopPickerRect
        visible: false
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceContainer, 0.98)
        radius: Theme.cornerRadius
        z: 1000

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    text: I18n.tr("Add Desktop Apps")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: 1; height: parent.height }

                DankActionButton {
                    width: 28
                    height: 28
                    circular: false
                    iconName: "close"
                    iconSize: 18
                    iconColor: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: desktopPickerRect.visible = false
                }
            }

            DankTextField {
                id: desktopSearchField
                width: parent.width
                placeholderText: I18n.tr("Search apps...")
                leftIconName: "search"
                onTextChanged: filterDesktopApps()
            }

            DankListView {
                id: desktopList
                width: parent.width
                height: parent.height - 140
                clip: true
                model: filteredDesktopModel
                cacheBuffer: 2000

                delegate: Rectangle {
                    width: desktopList.width
                    height: 40
                    color: ma.containsMouse ? Theme.withAlpha(Theme.primary, 0.1) : "transparent"
                    radius: Theme.cornerRadius

                    Row {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingS

                        Item {
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            IconImage {
                                id: pickerIcon
                                anchors.fill: parent
                                source: model.iconPath || ""
                                smooth: true
                                mipmap: true
                                asynchronous: true
                                onStatusChanged: {
                                    if (status === Image.Error || status === Image.Null) {
                                        pickerIcon.visible = false;
                                        pickerFallback.visible = true;
                                    }
                                }
                            }

                            DankIcon {
                                id: pickerFallback
                                name: model.iconName || "application-desktop"
                                size: 24
                                color: Theme.primary
                                anchors.centerIn: parent
                                visible: !pickerIcon.visible || !model.iconPath
                            }
                        }

                        StyledText {
                            text: model.name
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80
                            elide: Text.ElideRight
                        }

                        DankIcon {
                            name: model.selected ? "check_box" : "check_box_outline_blank"
                            size: 20
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            for (let i = 0; i < desktopAppsModel.count; i++) {
                                if (desktopAppsModel.get(i).path === model.path) {
                                    desktopAppsModel.setProperty(i, "selected", !model.selected);
                                    break;
                                }
                            }
                            for (let j = 0; j < filteredDesktopModel.count; j++) {
                                if (filteredDesktopModel.get(j).path === model.path) {
                                    filteredDesktopModel.setProperty(j, "selected", !model.selected);
                                    break;
                                }
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                anchors.horizontalCenter: parent.horizontalCenter

                DankButton {
                    text: I18n.tr("Cancel")
                    buttonHeight: 36
                    backgroundColor: Theme.surfaceContainer
                    textColor: Theme.surfaceText
                    onClicked: desktopPickerRect.visible = false
                }

                DankButton {
                    text: I18n.tr("Add")
                    buttonHeight: 36
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: addSelectedDesktopApps()
                }
            }
        }
    }
}
