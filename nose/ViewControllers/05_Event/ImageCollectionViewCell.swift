import UIKit

// MARK: - ImageCollectionViewCellDelegate
protocol ImageCollectionViewCellDelegate: AnyObject {
    func imageCollectionViewCell(_ cell: ImageCollectionViewCell, didTapAddButtonAt indexPath: IndexPath)
    func imageCollectionViewCell(_ cell: ImageCollectionViewCell, didTapRemoveButtonAt indexPath: IndexPath)
}

class ImageCollectionViewCell: UICollectionViewCell {
    weak var delegate: ImageCollectionViewCellDelegate?
    var indexPath: IndexPath?
    var isAddButton: Bool = false

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray6
        return imageView
    }()

    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .fourthColor
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 8
        return button
    }()

    private let removeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .firstColor
        button.backgroundColor = .fourthColor
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 0
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(addButton)
        contentView.addSubview(removeButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            addButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            addButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            addButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            addButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            removeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            removeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -3),
            removeButton.widthAnchor.constraint(equalToConstant: 20),
            removeButton.heightAnchor.constraint(equalToConstant: 20)
        ])

        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        removeButton.addTarget(self, action: #selector(removeButtonTapped), for: .touchUpInside)
    }

    func configure(with image: UIImage) {
        imageView.image = image
        imageView.isHidden = false
        addButton.isHidden = true
        removeButton.isHidden = false
    }

    func configureAddButton() {
        imageView.isHidden = true
        addButton.isHidden = false
        removeButton.isHidden = true
    }

    @objc private func addButtonTapped() {
        guard let indexPath = indexPath else { return }
        delegate?.imageCollectionViewCell(self, didTapAddButtonAt: indexPath)
    }

    @objc private func removeButtonTapped() {
        guard let indexPath = indexPath else { return }
        delegate?.imageCollectionViewCell(self, didTapRemoveButtonAt: indexPath)
    }
}
