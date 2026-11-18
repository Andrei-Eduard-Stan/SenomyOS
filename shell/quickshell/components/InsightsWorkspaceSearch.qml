import QtQuick
import "calendar" as CalendarUi
import "../config" as Config
CalendarUi.CalendarTextField {
 implicitHeight:Math.max(Config.DirectoryStyle.controlTarget,contentHeight+2*Config.DirectoryStyle.controlVerticalInset)
 topPadding:Config.DirectoryStyle.controlVerticalInset;bottomPadding:Config.DirectoryStyle.controlVerticalInset
 verticalAlignment:TextInput.AlignVCenter
 Accessible.name:placeholderText
}
