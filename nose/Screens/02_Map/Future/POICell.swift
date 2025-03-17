import UIKit

class POICell: UITableViewCell {

    let checkbox: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "circle"), for: .normal)
        button.tintColor = .fourthColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return button
    }()

    let poiLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var poi: BookmarkedPOI? {
        didSet {
            guard let poi = poi else { return }
            poiLabel.attributedText = getAttributedText(for: poi)
            checkbox.setImage(poi.visited ? UIImage(systemName: "checkmark.circle.fill") : UIImage(systemName: "circle"), for: .normal)
            contentView.backgroundColor = poi.visited ? UIColor.fourthColor.withAlphaComponent(0.1) : .clear
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(checkbox)
        contentView.addSubview(poiLabel)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            checkbox.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            poiLabel.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 10),
            poiLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            poiLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            poiLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    private func getAttributedText(for poi: BookmarkedPOI) -> NSAttributedString {
        let rating = poi.rating ?? 0.0
        let ratingText = getRatingText(rating: rating)
        let text = "\(poi.name)\n\(ratingText)"
        let attributedText = NSMutableAttributedString(string: text)

        let nameRange = (text as NSString).range(of: poi.name)
        let ratingRange = (text as NSString).range(of: ratingText)
        attributedText.addAttributes([.font: UIFont.systemFont(ofSize: 17)], range: nameRange)
        attributedText.addAttributes([.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.fourthColor], range: ratingRange)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedText.length))

        return attributedText
    }

    private func getRatingText(rating: Double) -> String {
        var ratingText = ""
        let fullStars = Int(rating)
        for _ in 0..<fullStars {
            ratingText += "●"
        }
        if rating - Double(fullStars) >= 0.5 {
            ratingText += "◐"
        }
        let emptyStars = 5 - fullStars - (ratingText.count > fullStars ? 1 : 0)
        for _ in 0..<emptyStars {
            ratingText += "○"
        }
        return ratingText
    }
}
