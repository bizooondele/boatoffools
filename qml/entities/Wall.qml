import QtQuick 2.0

import VPlay 2.0

EntityBase {
    id: entity
    entityType: "wall"

    BoxCollider {
        id: boxCollider
        bodyType: Body.Static
        // the size of the collider is the same as the one from entity by default
    }

    Rectangle {        
        anchors.fill: parent
        color: "brown"
        // this could be set to true for debugging
        visible: false
    }
}
