import QtQuick
ListModel {
    id: root
    dynamicRoles: true
    property var rows: []
    property var identity: function(row){return String(row.id);}
    property bool ready: false
    onRowsChanged: if(ready)sync()
    function sync(){
        for(let i=0;i<rows.length;i++){
            const row=rows[i],key=identity(row);
            if(i<count && identity(get(i).modelData)===key)set(i,{modelData:row});
            else {
                let found=-1;for(let j=i+1;j<count;j++)if(identity(get(j).modelData)===key){found=j;break;}
                if(found>=0){remove(i,found-i);set(i,{modelData:row});}
                else insert(i,{modelData:row});
            }
        }
        if(count>rows.length)remove(rows.length,count-rows.length);
    }
    Component.onCompleted:{ready=true;sync();}
}
