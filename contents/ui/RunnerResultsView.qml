import QtQuick 2.15
import QtQuick.Controls 2.15

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kquickcontrolsaddons 2.0
import org.kde.kirigami 2.16 as Kirigami

import "../code/tools.js" as Tools

FocusScope {
    id: searchResults

    signal keyNavLeft
    signal keyNavRight
    signal keyNavUp
    signal keyNavDown

    width: PlasmaCore.Units.gridUnit * 20
    height: PlasmaCore.Units.gridUnit * 60

    property bool usesPlasmaTheme: true

    property alias model: runnerSectionsList.model
    property alias currentSectionIndex: runnerSectionsList.currentIndex
    property alias currentSection: runnerSectionsList.currentItem
    readonly property var currentMatch: currentSection ? currentSection.currentItem : null
    property alias sectionsCount: runnerSectionsList.count

    property int iconSize: units.iconSizes.huge
    property bool shrinkIconsToNative: false

    function selectFirst() {
        if (sectionsCount > 0) {
            runnerSectionsList.positionViewAtBeginning();
            runnerSectionsList.itemAtIndex(0).currentIndex = 0;
        }
    }

    function selectLast() {
        if (sectionsCount > 0) {
            runnerSectionsList.positionViewAtEnd();
            let lastList = runnerSectionsList.itemAtIndex(sectionsCount - 1);
            if (lastList && lastList.count > 0) {
                lastList.currentIndex = lastList.lastVisibleIndex;
            }
        }
    }

    function removeSelection() {
        if (currentSection) {
            currentSection.currentIndex = -1;
        }
    }

    function triggerSelected() {
        if (currentSection && currentSection.currentIndex != -1) {
            currentSection.matchesList.trigger(currentSection.currentIndex);
        }
    }

    PC3.ScrollView {
        id: scrollView
        // Add spacing on the left by right adjusting the ScrollView, which
        // centers the runnerSectionsList
        width: parent.width - ScrollBar.vertical.width
        height: parent.height
        anchors.right: parent.right

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.interactive: true

        focus: true

        ListView {
            id: runnerSectionsList
            
            // ScrollView automatically sizes its child
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            // TODO - Find a better way to provide scrollbar content height without buffering delegates
            cacheBuffer: height * 100

            focus: true
            currentIndex: -1

            keyNavigationEnabled: false
            boundsBehavior: Flickable.StopAtBounds

            highlightFollowsCurrentItem: false
            highlightMoveDuration: 0
            highlightResizeDuration: 0

            function moveUp() {
                if (currentIndex <= 0) {
                    keyNavUp();
                    return;
                }

                decrementCurrentIndex();
                if (currentItem && "count" in currentItem) {
                    currentItem.currentIndex = currentItem.lastVisibleIndex;
                }
            }

            function moveDown() {
                if (currentIndex >= count - 1) {
                    keyNavDown();
                    return;
                }

                incrementCurrentIndex();
                if (currentItem && "count" in currentItem) {
                    currentItem.currentIndex = 0;
                }
            }

            function ensureCurrentMatchInView() {
                let section = currentItem;
                if (!section) {
                    return;
                }
                let match = section.currentItem;
                if (!match) {
                    return;
                }

                let headerHeight = section.matchesList.mapToItem(section, 0, 0).y;
                let matchY = section.y + match.y + headerHeight + units.smallSpacing; // Match's y relative to runnerSectionsList's start
                let mappedY = matchY - contentY; // Match's y adjusted to scrolled position

                if (mappedY < 0) {
                    contentY += mappedY;
                } else if (mappedY + section.matchesList.rowHeight > height) {
                    contentY += ((mappedY + section.matchesList.rowHeight) - height);
                }
            }

            delegate: FocusScope {
                width: scrollView.width - scrollView.ScrollBar.vertical.width - units.smallSpacing
                height: matchesList.height + sectionHeader.height + units.smallSpacing * 5

                visible: matchesList.model && matchesList.model.count > 0

                property alias count: matchesList.count
                property alias expanded: matchesList.expanded
                property alias expandable: matchesList.expandable
                property alias lastVisibleIndex: matchesList.lastVisibleIndex

                property alias currentIndex: matchesList.currentIndex
                property alias currentItem: matchesList.currentItem
                property alias matchesList: matchesList

                Item {
                    id: sectionHeader
                    width: parent.width
                    height: runnerName.height
                    anchors.top: parent.top

                    PlasmaExtras.Heading {
                        id: runnerName
                        
                        // This MouseArea is used for handle mouse back button 
                        // click event on search result heading area
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.BackButton

                            onReleased: {
                                mouse.accepted = true;
                                backOrClose();
                                return;
                            }
                        }
                        text: model.display ?? ""
                        level: 2
                    }

                    Button {
                        id: showMoreButton
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom

                        visible: matchesList.expandable

                        contentItem: PlasmaComponents.Label {
                            id: showMoreLabel
                            verticalAlignment: Text.AlignBottom
                            text: matchesList.expanded ? i18n("Show Less") : i18n("Show More")
                            color: Qt.darker(theme.disabledTextColor, showMoreButton.hovered ? 1.5: 1);
                            // https://github.com/P-Connor/plasma-drawer/pull/48
                            font.pointSize: fontPointSize
                        }
                        background: Rectangle {         
                            id: showMoreButtonHighlight
                            height: 1 * units.devicePixelRatio
                            anchors.bottom: showMoreLabel.bottom
                            color: theme.disabledTextColor

                            visible: showMoreButton.activeFocus
                        }

                        onPressed: {
                            matchesList.focus = true;
                            matchesList.expanded = !matchesList.expanded;
                        }

                        Keys.onPressed: {
                            if ((event.key == Qt.Key_Enter || event.key == Qt.Key_Return)) {
                                // matchesList.focus = true;
                                matchesList.expanded = !matchesList.expanded;
                                event.accepted = true;
                                return;
                            }
                            
                            if (event.key == Qt.Key_Up) {
                                focus = false;
                                matchesList.focus = true;
                                runnerSectionsList.moveUp();
                                event.accepted = true;
                                return;
                            }

                            if (event.key == Qt.Key_Down || event.key == Qt.Key_Left) {
                                focus = false;
                                matchesList.focus = true;
                                matchesList.currentIndex = 0;
                                event.accepted = true;
                                return;
                            }
                        }
                    }
                }

                // Rectangle {
                //     id: sectionSeparator
                //     anchors.left: runnerName.right
                //     anchors.right: parent.right
                //     anchors.verticalCenter: runnerName.verticalCenter
                //     anchors.leftMargin: units.smallSpacing * 2
                //     // width: root.width
                //     height: 2 * units.devicePixelRatio
                //     color: theme.textColor
                //     opacity: .05
                // }

                ItemListView {
                    id: matchesList
                    width: parent.width
                    anchors.top: sectionHeader.bottom
                    anchors.topMargin: units.smallSpacing * 2

                    focus: true

                    iconSize: searchResults.iconSize
                    shrinkIconsToNative: searchResults.shrinkIconsToNative

                    maxVisibleRows: 5

                    interactive: false

                    // currentIndex: index == 0 ? 0 : -1
                    onCurrentIndexChanged: {
                        if (currentIndex != -1) {
                            runnerSectionsList.currentIndex = index;
                            runnerSectionsList.ensureCurrentMatchInView();
                        }
                    }

                    model: runnerSectionsList.model.modelForRow(index)

                    onKeyNavUp: {
                        runnerSectionsList.moveUp();
                    }

                    onKeyNavDown: {
                        runnerSectionsList.moveDown();
                    }

                    onKeyNavRight: {
                        if (showMoreButton.visible) {
                            showMoreButton.focus = true;
                        }
                    }

                    Component.onCompleted: {
                        keyNavRight.connect(searchResults.keyNavRight);
                        keyNavLeft.connect(searchResults.keyNavLeft);
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "blue"
                        opacity: 0.05
                        visible: root.debugFocus && parent.activeFocus
                        z: 100
                    }
                }
            }
        }
    }

    Keys.onPressed: {
        if (event.key == Qt.Key_Up || event.key == Qt.Key_Down || event.key == Qt.Key_Left || event.key == Qt.Key_Right) {
            if (currentSectionIndex == -1) {
                event.accepted = true;
                runnerSectionsList.moveDown();
            }
        }
    }
}