import UIKit

protocol TimelineSliderViewDelegate: AnyObject {
    func timelineSliderView(_ view: TimelineSliderView, didSelectDotAt index: Int)
}

final class TimelineSliderView: UIView {
    // MARK: - Properties
    private var leftDot: UIView?
    private var middleDot: UIView?
    private var rightDot: UIView?
    private var dotLine: UIView?
    private var containerView: UIView?
    private var selectionRing: UIView?
    
    private var currentDotIndex: Int = 1  // Track current dot index (0: left, 1: middle, 2: right)
    
    // Constraint for animating the selection ring
    private var ringCenterXToLeft: NSLayoutConstraint?
    private var ringCenterXToMiddle: NSLayoutConstraint?
    private var ringCenterXToRight: NSLayoutConstraint?
    
    weak var delegate: TimelineSliderViewDelegate?
    
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
        container.layer.cornerRadius = 27.5
        addSubview(container)
        self.containerView = container
        
        // Create the line
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = .firstColor
        container.addSubview(line)
        self.dotLine = line
        
        // Create the dots
        let dot1 = createDot()
        let dot2 = createDot()
        let dot3 = createDot()
        
        dot1.accessibilityIdentifier = "left_dot"
        dot2.accessibilityIdentifier = "middle_dot"
        dot3.accessibilityIdentifier = "right_dot"
        
        container.addSubview(dot1)
        container.addSubview(dot2)
        container.addSubview(dot3)
        
        self.leftDot = dot1
        self.middleDot = dot2
        self.rightDot = dot3
        
        // Create the selection ring (sits on top of dots)
        let ring = UIView()
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.backgroundColor = .clear
        ring.layer.borderWidth = 2
        ring.layer.borderColor = UIColor.firstColor.cgColor
        ring.layer.cornerRadius = 15
        ring.isUserInteractionEnabled = false
        container.addSubview(ring)
        self.selectionRing = ring
        
        // Add tap gestures to dots
        [dot1, dot2, dot3].enumerated().forEach { index, dot in
            let tap = UITapGestureRecognizer(target: self, action: #selector(dotTapped(_:)))
            dot.tag = index
            dot.addGestureRecognizer(tap)
        }
        
        // Add swipe gestures to container
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
            line.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            line.leadingAnchor.constraint(equalTo: dot1.centerXAnchor),
            line.trailingAnchor.constraint(equalTo: dot3.centerXAnchor),
            line.heightAnchor.constraint(equalToConstant: 2),
            
            // Dot constraints
            dot1.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot1.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            dot1.widthAnchor.constraint(equalToConstant: 30),
            dot1.heightAnchor.constraint(equalToConstant: 30),
            
            dot2.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot2.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            dot2.widthAnchor.constraint(equalToConstant: 30),
            dot2.heightAnchor.constraint(equalToConstant: 30),
            
            dot3.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot3.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            dot3.widthAnchor.constraint(equalToConstant: 30),
            dot3.heightAnchor.constraint(equalToConstant: 30),
            
            // Selection ring constraints (size and Y position)
            ring.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ring.widthAnchor.constraint(equalToConstant: 30),
            ring.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Create X position constraints for the ring (one for each dot)
        ringCenterXToLeft = ring.centerXAnchor.constraint(equalTo: dot1.centerXAnchor)
        ringCenterXToMiddle = ring.centerXAnchor.constraint(equalTo: dot2.centerXAnchor)
        ringCenterXToRight = ring.centerXAnchor.constraint(equalTo: dot3.centerXAnchor)
        
        // Start with middle dot selected
        ringCenterXToMiddle?.isActive = true
    }
    
    private func createDot() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = true
        
        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = .firstColor
        dot.layer.cornerRadius = 8
        dot.isUserInteractionEnabled = false
        
        container.addSubview(dot)
        
        NSLayoutConstraint.activate([
            dot.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 16),
            dot.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        return container
    }
    
    // MARK: - Actions
    @objc private func dotTapped(_ gesture: UITapGestureRecognizer) {
        guard let dot = gesture.view else { return }
        selectDot(at: dot.tag, animated: true)
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
            selectDot(at: newIndex, animated: true)
        }
    }
    
    private func selectDot(at index: Int, animated: Bool) {
        guard index >= 0 && index <= 2, index != currentDotIndex else { return }
        
        // Deactivate all X constraints
        ringCenterXToLeft?.isActive = false
        ringCenterXToMiddle?.isActive = false
        ringCenterXToRight?.isActive = false
        
        // Activate the correct constraint
        switch index {
        case 0:
            ringCenterXToLeft?.isActive = true
        case 1:
            ringCenterXToMiddle?.isActive = true
        case 2:
            ringCenterXToRight?.isActive = true
        default:
            break
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Animate the change
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                self.layoutIfNeeded()
            }
        }
        
        // Update state and notify delegate
        currentDotIndex = index
        delegate?.timelineSliderView(self, didSelectDotAt: index)
    }
}
