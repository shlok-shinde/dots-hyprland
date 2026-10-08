import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

BarPopover {
    id: root
    name: "resources"

    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1);
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12

        PopoverHeader {
            Layout.fillWidth: true
            icon: "monitoring"
            title: Translation.tr("System")
            detail: Translation.tr("Up %1").arg(DateTime.uptime)
        }

        GridLayout {
            // In one row up to three, two by two for four, then rows of three
            columns: visibleChildren.length === 4 ? 2 : Math.min(3, visibleChildren.length)
            columnSpacing: 8
            rowSpacing: 8

            PopoverTile {
                icon: "planner_review"
                label: "CPU"
                value: ResourceUsage.cpuUsage
                history: ResourceUsage.cpuUsageHistory
                detail: ResourceUsage.maxAvailableCpuString !== "--" ? Translation.tr("up to %1").arg(ResourceUsage.maxAvailableCpuString) : ""
                warning: value * 100 >= Config.options.bar.resources.cpuWarningThreshold
            }
            PopoverTile {
                icon: "memory"
                label: Translation.tr("Memory")
                value: ResourceUsage.memoryUsedPercentage
                history: ResourceUsage.memoryUsageHistory
                detail: Translation.tr("%1 of %2 GB").arg(root.formatKB(ResourceUsage.memoryUsed)).arg(root.formatKB(ResourceUsage.memoryTotal))
                warning: value * 100 >= Config.options.bar.resources.memoryWarningThreshold
            }
            PopoverTile {
                visible: ResourceUsage.swapTotal > 1
                icon: "swap_horiz"
                label: Translation.tr("Swap")
                value: ResourceUsage.swapUsedPercentage
                history: ResourceUsage.swapUsageHistory
                detail: Translation.tr("%1 of %2 GB").arg(root.formatKB(ResourceUsage.swapUsed)).arg(root.formatKB(ResourceUsage.swapTotal))
                warning: value * 100 >= Config.options.bar.resources.swapWarningThreshold
            }
        }

        PopoverAction {
            Layout.fillWidth: true
            symbol: "open_in_new"
            text: Translation.tr("Open system monitor")
            onClicked: {
                Quickshell.execDetached(["bash", "-c", Config.options.apps.taskManager]);
                root.close();
            }
        }
    }
}
