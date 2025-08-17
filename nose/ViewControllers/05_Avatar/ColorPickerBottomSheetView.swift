// import UIKit

// // MARK: - Model
// struct ColorModel: Codable {
//     let name: String
//     let hex: String
// }

// class ColorPickerBottomSheetView: UIView {
//     // MARK: - Properties
//     var onColorSelected: ((UIColor) -> Void)?
//     private var colors: [String] = [] // Store hex strings directly
//     private var scrollView: UIScrollView!
//     private var contentView: UIView!
//     private var colorButtons: [UIButton] = []
//     private var selectedButton: UIButton?

//     // MARK: - Initialization
//     override init(frame: CGRect) {
//         super.init(frame: frame)
//         setupView()
//         loadColors()
//     }

//     required init?(coder: NSCoder) {
//         super.init(coder: coder)
//         setupView()
//         loadColors()
//     }

//     // MARK: - Setup
//     private func setupView() {
//         backgroundColor = .white
//         clipsToBounds = true
        
//         // Setup scroll view first
//         scrollView = UIScrollView()
//         scrollView.translatesAutoresizingMaskIntoConstraints = false
//         scrollView.showsHorizontalScrollIndicator = false
//         addSubview(scrollView)
        
//         // Setup content view
//         contentView = UIView()
//         contentView.translatesAutoresizingMaskIntoConstraints = false
//         scrollView.addSubview(contentView)
        
//         // Setup constraints
//         NSLayoutConstraint.activate([
//             // Scroll view constraints
//             scrollView.topAnchor.constraint(equalTo: topAnchor),
//             scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
//             scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
//             scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
//             // Content view constraints
//             contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
//             contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
//             contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
//             contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
//             contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
//         ])
//     }

//     // MARK: - Data Loading
//     @MainActor
//     private func loadColors() {
//         Task {
//             do {
//                 // Get colors from AvatarResourceManager
//                 colors = AvatarResourceManager.shared.colorModels
                
//                 // If colors are empty, try to preload resources
//                 if colors.isEmpty {
//                     try await AvatarResourceManager.shared.preloadAllResources()
//                     colors = AvatarResourceManager.shared.colorModels
//                 }
                
//                 // Setup UI with loaded colors
//                 setupColorButtons()
//             } catch {
//                 print("❌ Failed to load colors: \(error)")
//             }
//         }
//     }

//     // MARK: - UI Setup
//     private func setupColorButtons() {
//         // Clear existing buttons
//         colorButtons.forEach { $0.removeFromSuperview() }
//         colorButtons.removeAll()
//         selectedButton = nil
        
//         let buttonSize: CGFloat = 40
//         let padding: CGFloat = 12 // Reduced from 16 to 12
//         var lastButton: UIButton?

//         // Create a container view for buttons
//         let buttonContainer = UIView()
//         buttonContainer.translatesAutoresizingMaskIntoConstraints = false
//         contentView.addSubview(buttonContainer)
        
//         // Constrain button container
//         NSLayoutConstraint.activate([
//             buttonContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
//             buttonContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
//             buttonContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
//             buttonContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
//             buttonContainer.heightAnchor.constraint(equalTo: contentView.heightAnchor)
//         ])

//         for (index, hexColor) in colors.enumerated() {
//             guard let color = UIColor(hex: hexColor) else { 
//                 print("⚠️ Failed to create color from hex: \(hexColor)")
//                 continue 
//             }
            
//             let button = createColorButton(color: color, size: buttonSize, index: index, container: buttonContainer)
//             colorButtons.append(button)
//             lastButton = button
            
//             // Select first button by default
//             if index == 0 {
//                 selectButton(button)
//             }
//         }

//         // Update content view width based on last button
//         if let lastButton = lastButton {
//             contentView.trailingAnchor.constraint(equalTo: lastButton.trailingAnchor, constant: padding).isActive = true
//         }
//     }

//     private func createColorButton(color: UIColor, size: CGFloat, index: Int, container: UIView) -> UIButton {
//         let button = UIButton(type: .system)
//         button.backgroundColor = color
//         button.tag = index
//         button.layer.cornerRadius = size / 2
//         button.layer.borderWidth = 1
//         button.layer.borderColor = UIColor.secondColor.cgColor
//         button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
//         button.translatesAutoresizingMaskIntoConstraints = false
//         container.addSubview(button)

//         NSLayoutConstraint.activate([
//             button.widthAnchor.constraint(equalToConstant: size),
//             button.heightAnchor.constraint(equalToConstant: size),
//             button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
//             button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12 + CGFloat(index) * (size + 12)) // Reduced padding
//         ])

//         return button
//     }
    
//     private func selectButton(_ button: UIButton) {
//         // Deselect previous button
//         selectedButton?.layer.borderColor = UIColor.secondColor.cgColor
        
//         // Select new button
//         button.layer.borderColor = UIColor.fourthColor.cgColor
//         selectedButton = button
//     }

//     // MARK: - Actions
//     @objc private func colorButtonTapped(_ sender: UIButton) {
//         guard sender.tag >= 0 && sender.tag < colors.count else { return }
//         let hexColor = colors[sender.tag]
//         if let color = UIColor(hex: hexColor) {
//             selectButton(sender)
//             onColorSelected?(color)
//         }
//     }
// }
