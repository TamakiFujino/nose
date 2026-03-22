import UIKit

protocol ImagePickerViewControllerDelegate: AnyObject {
    func imagePickerViewController(_ controller: ImagePickerViewController, didSelectImage imageName: String, imageUrl: String)
}

class ImagePickerViewController: UIViewController {
    weak var delegate: ImagePickerViewControllerDelegate?

    private var sections: [EmojiCategorySection] = []
    private var selectedCategory: EmojiCategory = .smileys

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Close"
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "collection_modal_select_icon")
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()

    private lazy var categoryTabScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        return scrollView
    }()

    private lazy var categoryTabStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .systemBackground
        cv.alwaysBounceVertical = true
        cv.delegate = self
        cv.dataSource = self
        cv.keyboardDismissMode = .onDrag
        cv.register(EmojiGridCell.self, forCellWithReuseIdentifier: EmojiGridCell.reuseId)
        return cv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        loadEmojisAsync()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateItemSize()
    }

    private func setupLayout() {
        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(categoryTabScrollView)
        categoryTabScrollView.addSubview(categoryTabStackView)
        view.addSubview(collectionView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            categoryTabScrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 12),
            categoryTabScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryTabScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryTabScrollView.heightAnchor.constraint(equalToConstant: 36),

            categoryTabStackView.leadingAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            categoryTabStackView.trailingAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            categoryTabStackView.topAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.topAnchor),
            categoryTabStackView.bottomAnchor.constraint(equalTo: categoryTabScrollView.contentLayoutGuide.bottomAnchor),
            categoryTabStackView.heightAnchor.constraint(equalTo: categoryTabScrollView.frameLayoutGuide.heightAnchor),

            collectionView.topAnchor.constraint(equalTo: categoryTabScrollView.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func loadEmojisAsync() {
        activityIndicator.startAnimating()
        collectionView.alpha = 0.35
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loaded = EmojiCatalog.categorizedSections
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sections = loaded
                self.buildCategoryTabs()
                self.collectionView.reloadData()
                self.activityIndicator.stopAnimating()
                self.collectionView.alpha = 1
            }
        }
    }

    private func buildCategoryTabs() {
        categoryTabStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, section) in sections.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(section.category.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            button.layer.cornerRadius = 16
            button.layer.masksToBounds = true
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            button.tag = index
            button.addTarget(self, action: #selector(categoryTabTapped(_:)), for: .touchUpInside)
            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            categoryTabStackView.addArrangedSubview(button)
        }
        updateTabStyles()
    }

    private func updateTabStyles() {
        for (index, subview) in categoryTabStackView.arrangedSubviews.enumerated() {
            guard let button = subview as? UIButton,
                  index < sections.count else { continue }
            let cat = sections[index].category
            let isSelected = cat == selectedCategory
            button.backgroundColor = isSelected ? .themeBlue : .secondColor
            button.setTitleColor(isSelected ? .white : .label, for: .normal)
        }
    }

    @objc private func categoryTabTapped(_ sender: UIButton) {
        guard sender.tag >= 0, sender.tag < sections.count else { return }
        selectedCategory = sections[sender.tag].category
        updateTabStyles()
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)

        if let buttonFrame = sender.superview?.convert(sender.frame, to: categoryTabScrollView) {
            let rect = buttonFrame.insetBy(dx: -8, dy: 0)
            categoryTabScrollView.scrollRectToVisible(rect, animated: true)
        }
    }

    private var currentEmojis: [String] {
        sections.first(where: { $0.category == selectedCategory })?.emojis ?? []
    }

    private func updateItemSize() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let itemsPerRow: CGFloat = 6
        let sectionHorizontal = layout.sectionInset.left + layout.sectionInset.right
        let spacing = layout.minimumInteritemSpacing * (itemsPerRow - 1)
        let width = collectionView.bounds.width - sectionHorizontal - spacing
        let itemWidth = floor(width / itemsPerRow)
        guard itemWidth > 0 else { return }
        if layout.itemSize.width != itemWidth {
            layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
            layout.invalidateLayout()
        }
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - Collection view

extension ImagePickerViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        currentEmojis.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiGridCell.reuseId, for: indexPath) as! EmojiGridCell
        let list = currentEmojis
        guard indexPath.item < list.count else { return cell }
        cell.configure(emoji: list[indexPath.item])
        cell.accessibilityIdentifier = "emoji_cell_\(indexPath.item)"
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let list = currentEmojis
        guard indexPath.item < list.count else { return }
        let emoji = list[indexPath.item]
        delegate?.imagePickerViewController(self, didSelectImage: emoji, imageUrl: "")
        dismiss(animated: true)
    }
}

// MARK: - Cell (no tile background)

private final class EmojiGridCell: UICollectionViewCell {
    static let reuseId = "EmojiGridCell"

    private let label: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 28)
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.5
        l.backgroundColor = .clear
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = nil
    }

    func configure(emoji: String) {
        label.text = emoji
    }

    override var isHighlighted: Bool {
        didSet {
            contentView.alpha = isHighlighted ? 0.55 : 1
        }
    }
}
