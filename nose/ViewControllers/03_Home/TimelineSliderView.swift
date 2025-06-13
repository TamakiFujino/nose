import UIKit

protocol TimelineSliderViewDelegate: AnyObject {
    func timelineSliderView(_ view: TimelineSliderView, didSelectDotAt index: Int)
}

final class TimelineSliderView: UIView {
    
    // MARK: - Constants
    private enum Constants {
        static let dotSize: CGFloat = 12
        static let dotSpacing: CGFloat = 8
        static let sliderHeight: CGFloat = 4
        static let animationDuration: TimeInterval = 0.3
        static let dotCount: Int = 3
    }
    
    // MARK: - Properties
    private var dots: [UIView] = []
    private var slider: UIView!
    private var selectedIndex: Int = 1 {
        didSet {
            updateSliderPosition()
        }
    }
    
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
        setupDots()
        setupSlider()
        setupGestures()
    }
    
    private func setupDots() {
        for i in 0..<Constants.dotCount {
            let dot = createDot()
            dot.tag = i
            dots.append(dot)
            addSubview(dot)
        }
    }
    
    private func setupSlider() {
        slider = UIView()
        slider.backgroundColor = .systemBlue
        slider.layer.cornerRadius = Constants.sliderHeight / 2
        addSubview(slider)
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutDots()
        updateSliderPosition()
    }
    
    private func layoutDots() {
        let totalWidth = CGFloat(Constants.dotCount - 1) * (Constants.dotSize + Constants.dotSpacing)
        let startX = (bounds.width - totalWidth) / 2
        
        for (index, dot) in dots.enumerated() {
            let x = startX + CGFloat(index) * (Constants.dotSize + Constants.dotSpacing)
            let y = (bounds.height - Constants.dotSize) / 2
            dot.frame = CGRect(x: x, y: y, width: Constants.dotSize, height: Constants.dotSize)
        }
    }
    
    private func updateSliderPosition() {
        guard let selectedDot = dots[safe: selectedIndex] else { return }
        
        UIView.animate(withDuration: Constants.animationDuration) {
            self.slider.frame = CGRect(
                x: selectedDot.frame.minX,
                y: (self.bounds.height - Constants.sliderHeight) / 2,
                width: Constants.dotSize,
                height: Constants.sliderHeight
            )
        }
    }
    
    // MARK: - Helper Methods
    private func createDot() -> UIView {
        let dot = UIView()
        dot.backgroundColor = .systemGray4
        dot.layer.cornerRadius = Constants.dotSize / 2
        return dot
    }
    
    private func selectDot(at index: Int) {
        guard index >= 0 && index < Constants.dotCount else { return }
        
        selectedIndex = index
        delegate?.timelineSliderView(self, didSelectDotAt: index)
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        if let index = dots.firstIndex(where: { $0.frame.contains(location) }) {
            selectDot(at: index)
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        
        switch gesture.state {
        case .changed:
            if let index = dots.firstIndex(where: { $0.frame.contains(location) }) {
                selectDot(at: index)
            }
        case .ended:
            // Snap to nearest dot
            let nearestIndex = dots.enumerated().min(by: { dot1, dot2 in
                let distance1 = abs(dot1.element.center.x - location.x)
                let distance2 = abs(dot2.element.center.x - location.x)
                return distance1 < distance2
            })?.offset ?? selectedIndex
            
            selectDot(at: nearestIndex)
        default:
            break
        }
    }
}

// MARK: - Array Extension
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
} 
