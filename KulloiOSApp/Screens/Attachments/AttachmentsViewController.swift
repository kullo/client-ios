/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit

struct AttachmentMeta {
    let filename: String
    let size: Int64
}

protocol AttachmentsViewDataSource: class {
    func attachmentsViewNumberOfAttachments() -> Int
    func attachmentsViewMetadataForAttachment(_ attachmentIndex: Int) -> AttachmentMeta
    func attachmentsViewSaveAttachment(_ attachmentIndex: Int, path: String)
    func attachmentsViewRemoveAttachment(_ attachmentIndex: Int)
}

protocol AttachmentsViewDelegate: class {
    func attachmentsViewLaidOut(contentHeight: CGFloat)
    func attachmentsViewWillOpenAttachment(_ attachmentIndex: Int)
}

class AttachmentsViewController: UITableViewController {

    //MARK: public interface

    weak var delegate: AttachmentsViewDelegate?
    var removable = false

    var scrollable = true {
        didSet {
            tableView.isScrollEnabled = scrollable
        }
    }

    var attachmentsAreDownloaded = false {
        didSet {
            reloadData()
        }
    }

    weak var dataSource: AttachmentsViewDataSource? {
        didSet {
            reloadData()
        }
    }

    var contentHeight: CGFloat {
        if let dataSource = dataSource, dataSource.attachmentsViewNumberOfAttachments() > 0 {
            return tableView.contentSize.height
        } else {
            return 0
        }
    }

    func reloadData() {
        tableView.reloadData()
    }

    func saveToFinished(_ path: String) {
        openingAlertDialog?.dismiss(animated: true, completion: {
            self.documentInteractionController.url = URL(fileURLWithPath: path)
            self.documentInteractionController.presentPreview(animated: true)
        })
    }

    func saveToError(_ path: String, error: String) {
        if let alertDialog = openingAlertDialog {
            alertDialog.title = NSLocalizedString("Error opening file", comment: "")
            alertDialog.message = error
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
    }

    //MARK: private implementation

    private let viewStorageIdentifier = "Attachments"
    private let cellIdentifier = "AttachmentTableViewCell"
    private var documentInteractionController = UIDocumentInteractionController()
    private weak var openingAlertDialog: UIAlertController?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(AttachmentTableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        documentInteractionController.delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        delegate?.attachmentsViewLaidOut(contentHeight: contentHeight)
    }

    private func getIconForFilename(_ filename: String) -> UIImage {
        // create empty file for DocumentInteractionController to check out
        let cachesPath = NSSearchPathForDirectoriesInDomains(
            .cachesDirectory, .userDomainMask, true).first!
        let tempFilename = "\(cachesPath)/\(filename)"
        try? Data().write(to: URL(fileURLWithPath: tempFilename), options: [])

        documentInteractionController.url = URL(fileURLWithPath: tempFilename)
        let icon = documentInteractionController.icons.first
        StorageManager.removeFileOrDirectoryIfPossible(tempFilename)

        return icon?.resized(CGSize(width: 32, height: 32)) ?? UIImage()
    }

    private func fileExistsInTempDirectory(_ filename: String) -> Bool {
        let path = getTempPathForFilename(filename)
        return FileManager.default.fileExists(atPath: path)
    }

    private func getTempDir() -> String {
        return StorageManager.getTempPathForView(viewStorageIdentifier)
    }

    private func getTempPathForFilename(_ filename: String) -> String {
        return StorageManager.getTempPathForView(viewStorageIdentifier, filename: filename)
    }

    private func openAttachment(_ attachmentIndex: Int) {
        if let meta = dataSource?.attachmentsViewMetadataForAttachment(attachmentIndex) {
            delegate?.attachmentsViewWillOpenAttachment(attachmentIndex)
            openingAlertDialog = showWaitingDialog(
                NSLocalizedString("Opening file", comment: ""),
                message: NSLocalizedString("Please wait...", comment: "")
            )

            let path = getTempPathForFilename(meta.filename)
            if fileExistsInTempDirectory(meta.filename) {
                saveToFinished(path)
            } else {
                dataSource?.attachmentsViewSaveAttachment(attachmentIndex, path: path)
            }
        }
    }

}

extension AttachmentsViewController { // UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource?.attachmentsViewNumberOfAttachments() ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)

        if let meta = dataSource?.attachmentsViewMetadataForAttachment(indexPath.row) {
            cell.imageView!.image = getIconForFilename(meta.filename)
            cell.textLabel!.text = meta.filename
            cell.detailTextLabel!.text = KulloConnector.friendlyFileSize(meta.size)

            if attachmentsAreDownloaded {
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .gray
                cell.textLabel!.textColor = UIColor.darkText
                cell.detailTextLabel!.textColor = UIColor.darkText
            } else {
                cell.accessoryType = .none
                cell.selectionStyle = .none
                cell.textLabel!.textColor = UIColor.lightGray
                cell.detailTextLabel!.textColor = UIColor.lightGray
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return removable
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            dataSource?.attachmentsViewRemoveAttachment(indexPath.row)
        }
    }

}

extension AttachmentsViewController { // UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if attachmentsAreDownloaded {
            openAttachment(indexPath.row)
        }
    }

}

extension AttachmentsViewController: UIDocumentInteractionControllerDelegate {

    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }

    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        do {
            try FileManager.default.removeItem(atPath: getTempDir())
        } catch {
            log.error("Could not delete temp directory.")
        }
    }

}
