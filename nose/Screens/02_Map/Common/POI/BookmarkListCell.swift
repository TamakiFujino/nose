import UIKit

class BookmarkListCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Customize cell UI if needed
        textLabel?.numberOfLines = 2 // Allow textLabel to have multiple lines
    }
    
    func configure(with list: BookmarkList) {
        let nameText = NSAttributedString(string: "\(list.name)\n", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 16)])
        
        let bookmarkIcon = UIImage(systemName: "bookmark.fill")?.withTintColor(.fourthColor, renderingMode: .alwaysOriginal)
        let friendsIcon = UIImage(systemName: "person.fill")?.withTintColor(.fourthColor, renderingMode: .alwaysOriginal)
        
        let bookmarkIconAttachment = NSTextAttachment()
        bookmarkIconAttachment.image = bookmarkIcon
        bookmarkIconAttachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
        
        let friendsIconAttachment = NSTextAttachment()
        friendsIconAttachment.image = friendsIcon
        friendsIconAttachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
        
        let infoText = NSMutableAttributedString()
        infoText.append(NSAttributedString(attachment: bookmarkIconAttachment))
        infoText.append(NSAttributedString(string: " \(list.bookmarks.count)  ", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]))
        infoText.append(NSAttributedString(attachment: friendsIconAttachment))
        infoText.append(NSAttributedString(string: " \(list.sharedWithFriends.count)", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]))
        infoText.addAttribute(.foregroundColor, value: UIColor.black, range: NSMakeRange(0, infoText.length))
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(nameText)
        attributedText.append(infoText)
        
        textLabel?.attributedText = attributedText
    }
}
