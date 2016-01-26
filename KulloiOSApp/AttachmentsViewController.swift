/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit

struct AttachmentMeta {
    let filename: String
    let size: Int64
}

protocol AttachmentsViewDataSource: class {
    func attachmentsViewNumberOfAttachments() -> Int
    func attachmentsViewMetadataForAttachment(attachmentIndex: Int) -> AttachmentMeta
    func attachmentsViewSaveAttachment(attachmentIndex: Int, path: String)
    func attachmentsViewRemoveAttachment(attachmentIndex: Int)
}

protocol AttachmentsViewDelegate: class {
    func attachmentsViewWillOpenAttachment(attachmentIndex: Int)
}

class AttachmentsViewController: UITableViewController {

    //MARK: public interface

    weak var delegate: AttachmentsViewDelegate?
    var removable = false

    var scrollable = true {
        didSet {
            tableView.scrollEnabled = scrollable
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
        get {
            if let dataSource = dataSource where dataSource.attachmentsViewNumberOfAttachments() > 0 {
                return tableView.contentSize.height
            } else {
                return 0
            }
        }
    }

    func reloadData() {
        tableView.reloadData()
    }

    func saveToFinished(path: String) {
        openingAlertDialog?.dismissViewControllerAnimated(true, completion: {
            self.documentInteractionController.URL = NSURL(fileURLWithPath: path)
            self.documentInteractionController.presentPreviewAnimated(true)
        })
    }

    func saveToError(path: String, error: String) {
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

        documentInteractionController.delegate = self
    }

    private func getIconForFilename(filename: String) -> UIImage {
        // set a well-formed URL which doesn't need to exist
        documentInteractionController.URL = NSURL(fileURLWithPath: "~/\(filename)")
        return documentInteractionController.icons.first!.resizeImage(CGSizeMake(32, 32))
    }

    private func fileExistsInTempDirectory(filename: String) -> Bool {
        let path = getTempPathForFilename(filename)
        return NSFileManager.defaultManager().fileExistsAtPath(path)
    }

    private func getTempDir() -> String {
        return StorageManager.getTempPathForView(viewStorageIdentifier)
    }

    private func getTempPathForFilename(filename: String) -> String {
        return StorageManager.getTempPathForView(viewStorageIdentifier, filename: filename)
    }

    private func openAttachment(attachmentIndex: Int) {
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

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource?.attachmentsViewNumberOfAttachments() ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath)

        if let meta = dataSource?.attachmentsViewMetadataForAttachment(indexPath.row) {
            cell.imageView!.image = getIconForFilename(meta.filename)
            cell.textLabel!.text = meta.filename
            cell.detailTextLabel!.text = KulloConnector.friendlyFileSize(meta.size)

            if attachmentsAreDownloaded {
                cell.accessoryType = .DisclosureIndicator
                cell.selectionStyle = .Gray
                cell.textLabel!.textColor = UIColor.darkTextColor()
                cell.detailTextLabel!.textColor = UIColor.darkTextColor()
            } else {
                cell.accessoryType = .None
                cell.selectionStyle = .None
                cell.textLabel!.textColor = UIColor.lightGrayColor()
                cell.detailTextLabel!.textColor = UIColor.lightGrayColor()
            }
        }

        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return removable
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            dataSource?.attachmentsViewRemoveAttachment(indexPath.row)
        }
    }

}

extension AttachmentsViewController { // UITableViewDelegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        if attachmentsAreDownloaded {
            openAttachment(indexPath.row)
        }
    }

}

extension AttachmentsViewController : UIDocumentInteractionControllerDelegate {

    func documentInteractionControllerViewControllerForPreview(controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }

    func documentInteractionControllerDidEndPreview(controller: UIDocumentInteractionController) {
        do {
            try NSFileManager.defaultManager().removeItemAtPath(getTempDir())
        } catch {
            log.error("Could not delete temp directory.")
        }
    }

}
