import UIKit

protocol DotSliderViewDelegate: AnyObject {
    func dotSliderView(_ view: DotSliderView, didSelectDotAt index: Int)
}

final class DotSliderView: UIView {
    // MARK: - Properties
    private var leftDot: UIView? {
        didSet {
            leftDot?.accessibilityIdentifier = "left_dot"
        }
    }

    private var middleDot: UIView? {
        didSet {
            middleDot?.accessibilityIdentifier = "middle_dot"
        }
    }

    private var rightDot: UIView? {
        didSet {
            rightDot?.accessibilityIdentifier = "right_dot"
        }
    }

    private var dotLine: UIView?
    private var containerView: UIView?
    private var currentDotIndex: Int = 1  // Track current dot index (0: left, 1: middle, 2: right)
    
    weak var delegate: DotSliderViewDelegate?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        // Create container view for dots and line
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.fourthColor.withAlphaComponent(0.3)
        container.layer.cornerRadius = 27.5  // Half of height for perfect round
        addSubview(container)
        self.containerView = container
        
        // Create the line
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = .firstColor
        container.addSubview(line)
        self.dotLine = line
        
        // Create the dots - middle one selected by default
        let dot1 = createDot(isSelected: false)
        let dot2 = createDot(isSelected: true)  // Middle dot selected
        let dot3 = createDot(isSelected: false)
        
        // Add tap gestures to individual dots
        let tap1 = UITapGestureRecognizer(target: self, action: #selector(dotTapped(_:)))
        let tap2 = UITapGestureRecognizer(target: self, action: #selector(dotTapped(_:)))
        let tap3 = UITapGestureRecognizer(target: self, action: #selector(dotTapped(_:)))
        
        dot1.addGestureRecognizer(tap1)
        dot2.addGestureRecognizer(tap2)
        dot3.addGestureRecognizer(tap3)
        
        container.addSubview(dot1)
        container.addSubview(dot2)
        container.addSubview(dot3)
        
        // Store references to dots
        self.leftDot = dot1
        self.middleDot = dot2
        self.rightDot = dot3
        
        // Add swipe gesture recognizers
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        leftSwipe.direction = .left
        container.addGestureRecognizer(leftSwipe)
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipe.direction = .right
        container.addGestureRecognizer(rightSwipe)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            container.heightAnchor.constraint(equalToConstant: 55),
            
            // Line constraints
            dotLine!.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dotLine!.leadingAnchor.constraint(equalTo: leftDot!.centerXAnchor),
            dotLine!.trailingAnchor.constraint(equalTo: rightDot!.centerXAnchor),
            dotLine!.heightAnchor.constraint(equalToConstant: 2),
            
            // Dot constraints
            leftDot!.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            leftDot!.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            leftDot!.widthAnchor.constraint(equalToConstant: 20),
            leftDot!.heightAnchor.constraint(equalToConstant: 20),
            
            middleDot!.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            middleDot!.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            middleDot!.widthAnchor.constraint(equalToConstant: 20),
            middleDot!.heightAnchor.constraint(equalToConstant: 20),
            
            rightDot!.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            rightDot!.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            rightDot!.widthAnchor.constraint(equalToConstant: 20),
            rightDot!.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func createDot(isSelected: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = true
        
        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = .firstColor
        dot.layer.cornerRadius = 6
        dot.isUserInteractionEnabled = true
        
        container.addSubview(dot)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        if isSelected {
            container.layer.borderWidth = 2
            container.layer.borderColor = UIColor.firstColor.cgColor
            container.layer.cornerRadius = 10
        }
        
        return container
    }
    
    // MARK: - Actions
    @objc private func dotTapped(_ gesture: UITapGestureRecognizer) {
        guard let dot = gesture.view else { return }
        
        // Determine which dot was tapped
        let segment: Int
        if dot == leftDot {
            segment = 0
        } else if dot == middleDot {
            segment = 1
        } else if dot == rightDot {
            segment = 2
        } else {
            return
        }
        
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Update current index
        currentDotIndex = segment
        
        // Update dots using stored references
        leftDot?.layer.borderWidth = segment == 0 ? 2 : 0
        leftDot?.layer.borderColor = segment == 0 ? UIColor.firstColor.cgColor : nil
        leftDot?.layer.cornerRadius = segment == 0 ? 10 : 0
        
        middleDot?.layer.borderWidth = segment == 1 ? 2 : 0
        middleDot?.layer.borderColor = segment == 1 ? UIColor.firstColor.cgColor : nil
        middleDot?.layer.cornerRadius = segment == 1 ? 10 : 0
        
        rightDot?.layer.borderWidth = segment == 2 ? 2 : 0
        rightDot?.layer.borderColor = segment == 2 ? UIColor.firstColor.cgColor : nil
        rightDot?.layer.cornerRadius = segment == 2 ? 10 : 0
        
        // Notify delegate
        delegate?.dotSliderView(self, didSelectDotAt: segment)
    }
    
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        let newIndex: Int
        
        switch gesture.direction {
        case .left:
            newIndex = min(currentDotIndex + 1, 2)
        case .right:
            newIndex = max(currentDotIndex - 1, 0)
        default:
            return
        }
        
        if newIndex != currentDotIndex {
            // Simulate tap on the new dot
            let dot: UIView?
            switch newIndex {
            case 0: dot = leftDot
            case 1: dot = middleDot
            case 2: dot = rightDot
            default: return
            }
            
            if let dot = dot {
                dotTapped(UITapGestureRecognizer(target: self, action: #selector(dotTapped(_:))))
            }
        }
    }
} 
