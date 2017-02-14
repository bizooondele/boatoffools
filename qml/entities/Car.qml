import QtQuick 2.0
import VPlay 2.0

EntityBase {
  id: car
  // the enityId should be set by the level file!
  entityType: "car"

  property alias inputActionsToKeyCode: twoAxisController.inputActionsToKeyCode
  property alias image: image

  // gets accessed to insert the input when touching the HUDController
  property alias controller: twoAxisController

  readonly property real forwardForce: 8000 * world.pixelsPerMeter

  //rafal
  property real colliderRadius: 4*scene.gridSize
  property QtObject targetEntity: null
  property bool emitAimingAtTargetSignal: true
  property bool isEntityAI: true;
  signal aimingAtTargetChanged(bool aimingAtTarget)
  signal targetRemoved

  Component.onCompleted: {
    console.debug("car.onCompleted()")
    console.debug("car.x:", x)
    var mapped = mapToItem(world.debugDraw, x, y)
    console.debug("car.x world:", mapped.x)
  }

  Image {
    id: image
    source: "../../assets/img/car_red.png"

    anchors.centerIn: parent
    width: boxCollider.width
    height: boxCollider.height

    property list<Item> imagePoints: [
      // this imagePoint can be used for creation of the rocket
      // it must be far enough in front of the car that they don't collide upon creation
      // the +30 might have to be adapted if the size of the rocket is changed
      Item {x: image.width/2+30}
    ]

  }

  // this is used as input for the BoxCollider force & torque properties
  TwoAxisController {
    id: twoAxisController

    // call the logic function when an input press (possibly the fire event) is received
    onInputActionPressed: handleInputAction(actionName)
  }

  BoxCollider {
    id: boxCollider

    // the image and the physics will use this size; this is important as it specifies the mass of the body! it is in respect to the world size
    width: 60
    height: 40

    anchors.centerIn: parent

    density: 0.02
    friction: 0.4
    restitution: 0.5
    body.bullet: true
    body.linearDamping: 10
    body.angularDamping: 15
//Rafal new:
    // move forwards and backwards, with a multiplication factor for the desired speed

       //force: Qt.point(moveToPointHelper.outputYAxis*1000, 0)
       // rotate left and right
       //torque: moveToPointHelper.outputXAxis*300
    // this is applied every physics update tick
//old
   // force: Qt.point(twoAxisController.yAxis*forwardForce, 0)
   // torque: twoAxisController.xAxis*2000 * world.pixelsPerMeter * world.pixelsPerMeter
//combined:
       force: isEntityAI ? Qt.point(moveToPointHelper.outputYAxis*20000, 0) :
                           Qt.point(twoAxisController.yAxis*forwardForce, 0)
       torque: isEntityAI ? moveToPointHelper.outputXAxis*15000 :
                            twoAxisController.xAxis*2000 * world.pixelsPerMeter * world.pixelsPerMeter
    Component.onCompleted: {
      console.debug("car.physics.x:", x)
      var mapped = mapToItem(world.debugDraw, x, y)
      console.debug("car.physics.x world:", mapped.x)
    }

    //rafal
    Connections {
        id: targetEntityConnection
        // this gets set when a Car1 collides with the Car2
        target: targetEntity

        // this signal was manually added in EntityBase
        //onEntityDestroyed: {
        //   console.debug("entityDestroyed received in targetEntityConnection, set target to 0");
        //     removeTarget();
        //}

    }

    fixture.onBeginContact: {
      var fixture = other
      var body = other.getBody()
      var component = other.getBody().target
      var collidingType = component.entityType

      //var
      console.debug("car contact with: ", other, body, component)
      console.debug("car collided entity type:", collidingType)

      console.debug("car contactNormal:", contactNormal, "x:", contactNormal.x, "y:", contactNormal.y)

    }
  }

  //Rafal
  CircleCollider {
      id: collider
      radius: colliderRadius // this is the radius car nailgun has at firing, set the default value to 2x squares, because the nailgun itself is x squares, and x further away it should collide
//        width: 64
//        height: 64
      x: -radius
      y: -radius

      // this is a performance optimization (position of body is not propagated back to entity) and sets the sensor-flag to true
      // by setting collisionTestingOnlyMode to true, body.sleepingAllowed and fixture.isSensor get modified!
      collisionTestingOnlyMode: true

      // ATTENTION: setting body.sleepingAllowed to false is VERY important if the positions get set from outside! otherwise no BeginContact and EndContact events are received!
      // it would be enough to set this flag for one of the two colliding bodies though as a performance improvement
//        body.sleepingAllowed: false
//        fixture.sensor: true

      // set a categories, but don't set collidesWith, because when a tower is dragged into the playground, the towers should collide with each other!
      // category 2 are the towers, so squabies don't collide with each other, but with towers
      categories: Box.Category2
      // towers should only collide with Car, not with rockets!
      fixture.collidesWith: Box.Category2


      Component.onCompleted: {
          console.debug("isSensor of car is", collider.fixture.sensor);

      }

      fixture.onBeginContact: {
          // if there already is a target, return immediately
          if(targetEntity)
              return;

          var fixture = other;
          var body = other.getBody();
          //var component = body.parent;
          var entity = body.target;
          //var collidedEntityType = entity.entityType;

          // look here for information about connectings signals in QML: https://qt-project.org/doc/qt-4.8/qmlevents.html
          // this doesn't work with the default destroyed-signal! only with signals defined in QML!
          //entity.destroyed.connect(targetDestroyed);
          // -> to solve this issue, a custom signal entityDestroyed was created for EntityBase!
          // with this entityDestroyed is called whenever the target gets destroyed! this is the same like done in the Connection element! so use the Connections-approach
          //entity.entityDestroyed.connect(targetDestroyed);

          setTarget(entity);
      }

      // only receive the contactChanged signals, when there is no target assigned (so when the target was removed once it was inside)
      Connections {
        target: targetEntity ? null : collider.fixture
          onContactChanged: {
              if(targetEntity) {
                  // this IS gonna be called! not clear yet when exactly! probably sometime in between removeTarget()
                  console.debug("car: onContactChanged() - this should never be called, because the connection shouldnt be enabled when no targetEntity exists!")
                  return;
              }

              console.debug("target of tower got removed, set to new one...")
              var entity = other.getBody().target;
              setTarget(entity);
          }
      }

      fixture.onEndContact: {
          var entity = other.getBody().target;

          // only remove the target, if this was the one assigned before in onBeginContact
          if(entity === targetEntity)
              removeTarget();
      }
  }

  //rafal
  // this is a C++ item, which sets its output xAxis & yAxis properties based on the target position
  MoveToPointHelper {
      id: moveToPointHelper
      targetObject: targetEntity

      // distanceToTargetThreshold is not used for the towers - they only need to rotate left/right not move forward/backward
      // so it doesnt matter what value is set for that - the targetReached() signal is emitted if the distanceToTarget is smaller than distanceToTargetThreshold
      //rafal
      distanceToTargetThreshold: 75

      allowSteerForward: true //rafal

      property real aimingAngleThreshold: 10

      property bool aimingAtTarget: false

      onAimingAtTargetChanged: {
          console.debug("car: aimintAtTarget changed to", aimingAtTarget);

          // emit the car signal
          if(emitAimingAtTargetSignal) {
            car.aimingAtTargetChanged(aimingAtTarget);
          }
      }

      onTargetObjectChanged: {
          console.debug("car: targetObject changed to", targetObject);
          if(!targetObject)
              aimingAtTarget = false;
      }

      onAbsoluteRotationDifferenceChanged: {
          //console.debug("car: absoluteRotationDifference:", absoluteRotationDifference)
          if(absoluteRotationDifference < aimingAngleThreshold && !aimingAtTarget) {
              // set the aimingAtTarget to true, but only when previously it was not aiming
              aimingAtTarget = true;
          } else if(absoluteRotationDifference > aimingAngleThreshold && aimingAtTarget) {
              // set the aimingAtTarget to false, but only when it was aiming before
              aimingAtTarget = false;
          }
      }
      //onOutputXAxisChanged: console.debug("outputXAxis changed to", outputXAxis)
  }

  //rafal
  MovementAnimation {
    target: car
    property: "rotation"
    // the tower should only rotate, when the target is not reached
    // this must be set to "targetEntity ? true : false" when velocity is changed!
    // i.e. when there is a target set, take the input from the STPB - but this would not work for the acceleration, because then the velocity is still modified when the acceleration gets set to 0!
    running: targetEntity ? true : false
    // when acceleration should be modified - if output changes to 0, the acc gets 0 but the velocity still exists!
    // NOTE: this is an issue in Squaby only, because the targetEntity is still set, even if the squaby was "logically" removed!
    // if the entityDestroyed-signal of targetEntity would be connected, the above should be able to use!?
    // but it IS connected, so no idea why the animation works too long, even when targetEntity is unset!?
    //running: moveToPointHelper.outputXAxis!=0 ? true : false

    // setting the acceleration makes the tower rotate slower (so it takes longer to reach the desired targetRotation)
//      acceleration: 500*moveToPointHelper.outputXAxis
    velocity: 300*moveToPointHelper.outputXAxis


    // this avoids over-rotating, so rotating further than allowed
    maxPropertyValueDifference: moveToPointHelper.absoluteRotationDifference
  }

  //rafal
  function setTarget(target) {
      console.debug("car: setTarget() called for", target);
      console.debug("car: previous targetEntity (should be 0!):", targetEntity);
      if(isEntityAI)
      {
        targetEntity = target;
      }
//        steeringUpdateTimer.running = true;

      //steerToPointBehavior.targetObject = target; // this gets set from the targetEntityConnection.target
  }
  function removeTarget() {
      console.debug("car.removeTarget() called");
      // set the target to 0
      targetEntity = null;

      // setting running to false has the bad effect that it stops in the middle of the animation!
      // thus control the animation manually by calling playShootAnimation, which will run to the end of the animation
      //sprite.running = false;

//        steeringUpdateTimer.running = false;

      // this is also necessary, otherwise the onAimingAtTargetChanged would never be triggered and shooting would not start!
//        steerToPointBehavior.aimingAtTarget = false;

      // emit the signal which gets connected in the derived classes
      car.targetRemoved();
  }
  function handleInputAction(action) {
    if( action === "fire") {
      // x&y of this component are 0..
      console.debug("creating weapon at current position x", car.x, "y", car.y)
      console.debug("image.imagePoints[0].x:", image.imagePoints[0].x, ", image.imagePoints[0].y:", image.imagePoints[0].y)

      // this is the point that we defined in Car.qml for the rocket to spawn
      var imagePointInWorldCoordinates = mapToItem(level,image.imagePoints[0].x, image.imagePoints[0].y)
      console.debug("imagePointInWorldCoordinates x", imagePointInWorldCoordinates.x, " y:", imagePointInWorldCoordinates.y)

      // create the rocket at the specified position with the rotation of the car that fires it
      entityManager.createEntityFromUrlWithProperties(Qt.resolvedUrl("Rocket.qml"), {"x": imagePointInWorldCoordinates.x, "y": imagePointInWorldCoordinates.y, "rotation": car.rotation})

    }
  }
}
