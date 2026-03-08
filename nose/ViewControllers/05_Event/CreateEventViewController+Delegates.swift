import UIKit
import GooglePlaces

// MARK: - UITextFieldDelegate
extension CreateEventViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == titleTextField {
            let currentText = textField.text ?? ""
            let newText = (currentText as NSString).replacingCharacters(in: range, with: string)

            if newText.count <= 25 {
                titleCharCountLabel.text = "\(newText.count)/25"
                titleCharCountLabel.textColor = newText.count > 20 ? .systemRed : .secondaryLabel
                return true
            }
            return false
        }

        if textField == locationTextField {
            let currentText = textField.text ?? ""
            let newText = (currentText as NSString).replacingCharacters(in: range, with: string)

            // Debounce the search to reduce API calls
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performLocationSearch), object: nil)
            perform(#selector(performLocationSearch), with: newText, afterDelay: 0.5)

            return true
        }

        return true
    }

    @objc func performLocationSearch(_ query: String) {
        searchLocations(query: query)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == locationTextField && !locationPredictions.isEmpty {
            locationTableView.isHidden = false
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == locationTextField {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.locationTableView.isHidden = true
            }
        }
    }
}

// MARK: - UITextViewDelegate
extension CreateEventViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        detailsPlaceholderLabel.isHidden = !textView.text.isEmpty

        let count = textView.text.count
        detailsCharCountLabel.text = "\(count)/1000"
        detailsCharCountLabel.textColor = count > 900 ? .systemRed : .secondaryLabel

        if count > 1000 {
            textView.text = String(textView.text.prefix(1000))
        }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension CreateEventViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locationPredictions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath)

        // Safety check to prevent index out of bounds crash
        guard indexPath.row < locationPredictions.count else {
            var content = cell.defaultContentConfiguration()
            content.text = "Loading..."
            cell.contentConfiguration = content
            return cell
        }

        let prediction = locationPredictions[indexPath.row]

        // Use the attributed text directly to preserve Google's formatting (bold matching parts)
        let primaryAttributedString = prediction.attributedPrimaryText
        let secondaryAttributedString = prediction.attributedSecondaryText

        var content = cell.defaultContentConfiguration()

        // Create a mutable attributed string for the primary text
        let mutablePrimary = NSMutableAttributedString(attributedString: primaryAttributedString)
        mutablePrimary.addAttribute(.font, value: UIFont.systemFont(ofSize: 16, weight: .medium), range: NSRange(location: 0, length: mutablePrimary.length))
        content.attributedText = mutablePrimary

        // Add secondary text if available
        if let secondary = secondaryAttributedString {
            let mutableSecondary = NSMutableAttributedString(attributedString: secondary)
            mutableSecondary.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location: 0, length: mutableSecondary.length))
            mutableSecondary.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: NSRange(location: 0, length: mutableSecondary.length))
            content.secondaryAttributedText = mutableSecondary
        }

        cell.contentConfiguration = content

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Safety check to prevent index out of bounds crash
        guard indexPath.row < locationPredictions.count else {
            return
        }

        let prediction = locationPredictions[indexPath.row]

        // Fetch place details
        PlacesAPIManager.shared.fetchPlaceDetailsForUserInteraction(
            placeID: prediction.placeID,
            fields: PlacesAPIManager.FieldConfig.search
        ) { [weak self] place in
            DispatchQueue.main.async {
                if let place = place {
                    self?.selectedLocation = EventLocation(
                        name: place.name ?? "",
                        address: place.formattedAddress ?? "",
                        coordinates: place.coordinate
                    )
                    self?.locationTextField.text = place.name
                    self?.locationTableView.isHidden = true
                }
            }
        }
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension CreateEventViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Show add button only if we have fewer than 1 image
        return selectedImages.count < 1 ? selectedImages.count + 1 : selectedImages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCollectionViewCell

        if indexPath.item < selectedImages.count {
            cell.configure(with: selectedImages[indexPath.item])
            cell.isAddButton = false
        } else {
            // This is the add button (only shown when selectedImages.count < 1)
            cell.configureAddButton()
            cell.isAddButton = true
        }

        cell.delegate = self
        cell.indexPath = indexPath

        return cell
    }
}

// MARK: - ImageCollectionViewCellDelegate
extension CreateEventViewController: ImageCollectionViewCellDelegate {
    func imageCollectionViewCell(_ cell: ImageCollectionViewCell, didTapAddButtonAt indexPath: IndexPath) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
        present(imagePicker, animated: true)
    }

    func imageCollectionViewCell(_ cell: ImageCollectionViewCell, didTapRemoveButtonAt indexPath: IndexPath) {
        selectedImages.remove(at: indexPath.item)
        imagesCollectionView.reloadData()
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension CreateEventViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)

        if let editedImage = info[.editedImage] as? UIImage {
            selectedImages.append(editedImage)
        } else if let originalImage = info[.originalImage] as? UIImage {
            selectedImages.append(originalImage)
        }

        imagesCollectionView.reloadData()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
