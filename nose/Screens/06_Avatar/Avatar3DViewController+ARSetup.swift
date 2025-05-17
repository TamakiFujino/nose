import UIKit
import RealityKit
import Combine

extension Avatar3DViewController {

    func setupARView() {
        arView = ARView(frame: .zero)
        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.backgroundColor = .clear
        view.addSubview(arView)
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func setupEnvironmentBackground() {
        view.backgroundColor = .secondColor
        arView.environment.background = .color(.secondColor)
    }

    func setupCameraPosition(position: SIMD3<Float> = SIMD3<Float>(0.0, -4.0, 16.0)) {
        let cameraEntity = PerspectiveCamera()
        cameraEntity.transform.translation = position
        let cameraAnchor = AnchorEntity()
        cameraAnchor.addChild(cameraEntity)
        arView.scene.anchors.append(cameraAnchor)
    }

    /// Only add the base entity once
    func setupBaseEntity() {
        guard let baseEntity = baseEntity else { return }
        // Remove existing 'Avatar' children from all anchors
        for anchor in arView.scene.anchors {
            for child in anchor.children {
                if child.name == "Avatar" {
                    anchor.removeChild(child)
                }
            }
        }
        baseEntity.transform.rotation = simd_quatf(angle: .pi / 6, axis: [0, -0.8, 0])
        let anchor = AnchorEntity(world: [0, 0, 0])
        anchor.addChild(baseEntity)
        arView.scene.anchors.append(anchor)
    }

    func addGroundPlaneWithShadow() {
        let planeMesh = MeshResource.generatePlane(width: 1.0, depth: 1.0)
        var material = SimpleMaterial()
        material.baseColor = .color(.clear)
        let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
        planeEntity.position = SIMD3<Float>(0, -0.5, 0)
        let groundAnchor = AnchorEntity(world: [0, 0, 0])
        groundAnchor.addChild(planeEntity)
        arView.scene.anchors.append(groundAnchor)
    }

    func addDirectionalLight() {
        let lightAnchor = AnchorEntity(world: [0, 2.0, 0])
        let light = DirectionalLight()
        light.light.intensity = 1000
        light.light.color = .fourthColor
        light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 10.0, depthBias: 0.005)
        light.orientation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
        lightAnchor.addChild(light)
        arView.scene.anchors.append(lightAnchor)
    }
} 